defmodule HNLive.Watcher do
  @moduledoc """
  `HNLive.Watcher` is a long-running `GenServer`, which should be started as
  part of the application supervision tree.

  `HNLive.Watcher` provides updates via `Phoenix.PubSub`
  when the top stories change. Subscribe to the updates via `subscribe/1`.

  These updates are broadcast as
  `{:update_top_newest, %{score: [%TopStory{}] , comments: [%TopStory{}]}}`

  The `score` and `comments` entries are sorted by score, and number of comments,
  respectively. Please note that either of the entries may be `[]` which indicates
  that no updates were available for this particular entry.

  The watcher also broadcasts updates when the number of subscribers to the corresponding
  PubSub topic changes.

  These updates are broadcast as `{:subscriber_count, subscriber_count}`, where
  `subscriber_count` is a non-negative integer.
  """
  use GenServer
  alias HNLive.{Api, Api.Story}
  alias Phoenix.PubSub

  # time after which initial HN API call to get newest stories
  # will be retried if it fails
  @retry_init_after 5000
  # interval between HN API calls to get updated story IDs
  @update_interval 10000
  # number of top stories returned by get_top_newest_stories
  @top_story_count 10
  # name of PubSub service used for broadcasting updates
  @pubsub_server HNLive.PubSub
  # topic of PubSub channel used for broadcasting updates
  @pubsub_topic "hackernews_watcher"

  defmodule SubscriberCountTracker do
    @moduledoc """
    Originally used `Phoenix.Presence` to track the number of subscribers, which meant recalculating
    this individually in each connected LiveView (since "presence_diff" events are sent to the LiveView).
    Using a simple `Phoenix.Tracker`, we keep track of this information centrally in the Watcher and
    only broadcast the resulting subscriber count.
    """
    use Phoenix.Tracker

    def start_link(opts) do
      opts = Keyword.merge([name: __MODULE__], opts)
      Phoenix.Tracker.start_link(__MODULE__, opts, opts)
    end

    @impl true
    def init(opts) do
      pubsub_server = Keyword.fetch!(opts, :pubsub_server)
      pubsub_topic = Keyword.fetch!(opts, :pubsub_topic)
      {:ok, %{pubsub_server: pubsub_server, pubsub_topic: pubsub_topic, subscriber_count: 0}}
    end

    @impl true
    def handle_diff(
          diff,
          %{
            pubsub_server: pubsub_server,
            pubsub_topic: pubsub_topic,
            subscriber_count: subscriber_count
          } = state
        ) do
      {joins, leaves} = Map.get(diff, pubsub_topic, {[], []})
      subscriber_count = subscriber_count + length(joins) - length(leaves)
      PubSub.broadcast!(pubsub_server, pubsub_topic, {:subscriber_count, subscriber_count})
      {:ok, %{state | subscriber_count: subscriber_count}}
    end
  end

  defmodule TopStory do
    @type t() :: %TopStory{
            id: non_neg_integer(),
            score: non_neg_integer(),
            title: String.t(),
            comments: non_neg_integer(),
            creation_time: String.t(),
            url: String.t(),
            updated: boolean()
          }
    defstruct id: 0, score: 0, title: "", comments: 0, url: "", creation_time: "", updated: false
  end

  # Client

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @doc """
  Returns the top (sorted by `:score` of number of `:comments`) newest stories.
  """
  @spec get_top_newest_stories(:score | :comments) :: [TopStory.t()]
  def get_top_newest_stories(sort_by \\ :score) do
    GenServer.call(__MODULE__, {:get_top_newest_stories, sort_by})
  end

  @doc """
  Subscribes to notifications when top stories are updated or subscriber count changes,
  see module documentation for event format. Expects a LiveView socket ID as argument.
  """
  def subscribe(socket_id) do
    :ok = PubSub.subscribe(@pubsub_server, @pubsub_topic)

    {:ok, _} =
      Phoenix.Tracker.track(SubscriberCountTracker, self(), @pubsub_topic, socket_id, %{})
  end

  # Server

  defmodule State do
    defstruct stories: %{}, last_updated_ids: [], top_newest: %{}, comments: %{}
  end

  @impl true
  def init(_) do
    SubscriberCountTracker.start_link(pubsub_server: @pubsub_server, pubsub_topic: @pubsub_topic)
    send(self(), :initial_api_calls)
    {:ok, %State{}}
  end

  @impl true
  def handle_call(
        {:get_top_newest_stories, sort_by},
        _from,
        %State{top_newest: top_newest} = state
      ) do
    {:reply, Map.get(top_newest, sort_by, []), state}
  end

  @impl true
  def handle_info(:initial_api_calls, %State{} = state) do
    run_init()
    run_get_updated_ids()
    {:noreply, state}
  end

  @impl true
  def handle_info({:init, stories}, %State{} = state) do
    # When the watcher starts, the 500 newest stories are initially retrieved using
    # `HNLive.Api.get_newest_stories/0`. We handle the result here.

    if map_size(stories) == 0, do: run_init(@retry_init_after)

    {:noreply,
     %State{
       state
       | stories: stories,
         top_newest: update_top_newest(stories)
     }}
  end

  @impl true
  def handle_info(
        {:get_updated_ids, updated_ids},
        %State{stories: stories, last_updated_ids: last_updated_ids} = state
      ) do
    # every comment should have one parent story
    # every store may have zero or more associated comments
    # when a new comment is detected, we calculate its sentiment score and
    # check its parent, if parent is a comment (check whether ID in comment map),
    # we retrieve parent's story ID and set new comment's story ID to the same story ID
    # if parent is a story (check whether ID in story map), we set comment's story ID to
    # this ID

    # Every 10 seconds updates are downloaded
    # using `HNLive.Api.get_updates/0`. We handle the result here.
    new_state =
      case updated_ids do
        # same ids retrieved as last time around? nothing to be done
        {:ok, ^last_updated_ids} ->
          state

        {:ok, updated_ids} ->
          # get smallest story id, or 0 if stories is empty
          {min_id, _} = Enum.min_by(stories, &elem(&1, 0), fn -> {0, nil} end)

          filtered_ids = Enum.filter(updated_ids, &(&1 >= min_id))

          run_api_task(:updates, fn -> Api.get_many_stories(filtered_ids) end)

          %State{state | last_updated_ids: updated_ids}

        # ignore errors
        _ ->
          state
      end

    run_get_updated_ids(@update_interval)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(
        {:updates, updated_stories},
        %State{stories: stories, top_newest: top_newest} = state
      ) do
    # Updated stories were downloaded using `HNLive.Api.get_many_stories/1.`
    # The updated stories are now merged with the previously retrieved stories.
    stories =
      Map.merge(stories, updated_stories)
      |> Enum.sort_by(&elem(&1, 0), :desc)
      # Only the 500 newest stories are considered (and kept in memory) when updating
      # the top 10 stories by score and number of comments.
      |> Enum.take(500)
      |> Enum.into(%{})

    {:noreply,
     %State{
       state
       | stories: stories,
         top_newest: update_top_newest(stories, top_newest)
     }}
  end

  # Helper which runs `api_fn` as linked `Task` after an optional `timeout`
  # (which defaults to 0) and sends the result to the calling process
  # as a `{name, result}` tuple.
  defp run_api_task(name, api_fn, timeout \\ 0) do
    pid = self()

    Task.start_link(fn ->
      Process.sleep(timeout)
      send(pid, {name, api_fn.()})
    end)
  end

  defp run_init(timeout \\ 0),
    do: run_api_task(:init, &Api.get_newest_stories/0, timeout)

  defp run_get_updated_ids(timeout \\ 0),
    do: run_api_task(:get_updated_ids, &Api.get_updates/0, timeout)

  defp update_top_newest(stories, previous_top_newest \\ %{}) do
    [{top_newest_by_score, changes_by_score}, {top_newest_by_comments, changes_by_comments}] =
      Enum.map(
        [:score, :comments],
        &get_top_newest_and_changes(&1, stories, Map.get(previous_top_newest, &1, []))
      )

    # only broadcast updates if any changes were found
    if length(changes_by_score) > 0 || length(changes_by_comments) > 0,
      do:
        PubSub.broadcast!(
          @pubsub_server,
          @pubsub_topic,
          {:update_top_newest, %{score: changes_by_score, comments: changes_by_comments}}
        )

    %{score: top_newest_by_score, comments: top_newest_by_comments}
  end

  defp get_top_newest_and_changes(sort_by, stories, previous_top_newest) do
    top_newest =
      stories
      |> Enum.map(fn {story_id, %Story{} = story} ->
        %TopStory{
          id: story_id,
          score: story.score,
          title: story.title,
          comments: story.comments,
          url: story.url
        }
      end)
      |> Enum.sort_by(&Map.fetch!(&1, sort_by), :desc)
      |> Enum.take(@top_story_count)

    current_time = DateTime.utc_now() |> DateTime.to_unix()

    # convert the time elapsed since creation of the story into
    # a human-readable string
    top_newest =
      Enum.map(top_newest, fn story ->
        creation_time = stories[story.id].creation_time
        Map.put(story, :creation_time, humanize_time(current_time - creation_time))
      end)

    # compare new and previous top stories and mark changes by setting
    # :updated in the story map
    mark_updated =
      Enum.zip(top_newest, previous_top_newest)
      |> Enum.map(fn {new, old} ->
        Map.put(
          new,
          :updated,
          new.id != old.id || new.score != old.score || new.comments != old.comments
        )
      end)

    changes =
      cond do
        # mark_updated will be [] if previous_top_newest == [] because
        # the Enum.zip above will result in an empty list then
        mark_updated == [] -> top_newest
        Enum.any?(mark_updated, & &1.updated) -> mark_updated
        true -> []
      end

    {top_newest, changes}
  end

  defp humanize_time(seconds) do
    cond do
      seconds == 1 -> "1 second ago"
      seconds < 60 -> "#{seconds} seconds ago"
      seconds < 120 -> "1 minute ago"
      seconds < 3600 -> "#{div(seconds, 60)} minutes ago"
      seconds < 7200 -> "1 hour ago"
      seconds < 3600 * 24 -> "#{div(seconds, 3600)} hours ago"
      true -> "> 1 day ago"
    end
  end
end
