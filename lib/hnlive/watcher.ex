defmodule HNLive.Watcher do
  use GenServer
  alias HNLive.{Api, Presence}
  alias Phoenix.PubSub

  # time after which initial HN API call to get newest stories
  # will be retried if it fails
  @retry_init_after 5000
  # interval between HN API calls to get updated story IDs
  @update_interval 10000
  # number of top stories returned by get_top_newest_stories
  @top_story_count 10
  # name of PubSub service used for broadcasting updates
  @pub_sub HNLive.PubSub
  # topic of PubSub channel used for broadcasting updates
  @pub_sub_topic "hackernews_watcher"

  # Client

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def get_top_newest_stories_by(sort_by) do
    GenServer.call(__MODULE__, {:get_top_newest_stories_by, sort_by})
  end

  def get_current_subscriber_count() do
    map_size(Presence.list(@pub_sub_topic))
  end

  def subscribe(socket_id) do
    :ok = PubSub.subscribe(@pub_sub, @pub_sub_topic)
    {:ok, _} = Presence.track(self(), @pub_sub_topic, socket_id, %{})
  end

  # Server

  @impl true
  def init(_) do
    run_init()
    run_get_updated_ids()
    {:ok, %{stories: %{}, last_updated_ids: [], top_newest_by: %{}}}
  end

  @impl true
  def handle_call(
        {:get_top_newest_stories_by, sort_by},
        _from,
        %{top_newest_by: top_newest_by} = state
      ) do
    {:reply, Map.get(top_newest_by, sort_by, []), state}
  end

  @impl true
  def handle_info({:init, stories}, state) do
    if map_size(stories) == 0, do: run_init(@retry_init_after)

    {:noreply,
     %{
       state
       | stories: stories,
         top_newest_by: update_top_newest_by(stories)
     }}
  end

  @impl true
  def handle_info(
        {:get_updated_ids, updated_ids},
        %{stories: stories, last_updated_ids: last_updated_ids} = state
      ) do
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

          %{state | last_updated_ids: updated_ids}

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
        %{stories: stories, top_newest_by: top_newest_by} = state
      ) do
    stories =
      Map.merge(stories, updated_stories)
      |> Enum.sort_by(&elem(&1, 0), :desc)
      |> Enum.take(500)
      |> Enum.into(%{})

    {:noreply,
     %{
       state
       | stories: stories,
         top_newest_by: update_top_newest_by(stories, top_newest_by)
     }}
  end

  defp run_api_task(name, api_fn, timeout \\ 0) do
    pid = self()

    Task.start_link(fn ->
      Process.sleep(timeout)
      send(pid, {name, api_fn.()})
    end)
  end

  defp run_init(timeout \\ 0) do
    run_api_task(:init, &Api.get_newest_stories/0, timeout)
  end

  defp run_get_updated_ids(timeout \\ 0) do
    run_api_task(:get_updated_ids, &Api.get_updates/0, timeout)
  end

  defp update_top_newest_by(stories, previous_top_newest_by \\ %{}) do
    {top_newest_by_score, changes_by_score} =
      get_top_newest_and_changes_by(:score, stories, Map.get(previous_top_newest_by, :score, []))

    {top_newest_by_comments, changes_by_comments} =
      get_top_newest_and_changes_by(
        :comments,
        stories,
        Map.get(previous_top_newest_by, :comments, [])
      )

    if length(changes_by_score) > 0 || length(changes_by_comments) > 0,
      do:
        PubSub.broadcast!(
          @pub_sub,
          @pub_sub_topic,
          {:update_top_newest_by, %{score: changes_by_score, comments: changes_by_comments}}
        )

    %{score: top_newest_by_score, comments: top_newest_by_comments}
  end

  defp get_top_newest_and_changes_by(sort_by, stories, previous_top_newest) do
    top_newest =
      stories
      |> Enum.map(fn {
                       id,
                       %{
                         score: score,
                         title: title,
                         comments: comments,
                         url: url
                       }
                     } ->
        %{
          id: id,
          score: score,
          title: title,
          comments: comments,
          url: url,
          updated: false
        }
      end)
      |> Enum.sort_by(&Map.fetch!(&1, sort_by), :desc)
      |> Enum.take(@top_story_count)

    current_time = DateTime.utc_now() |> DateTime.to_unix()

    top_newest =
      Enum.map(top_newest, fn story ->
        creation_time = get_in(stories, [story.id, :creation_time])
        Map.put(story, :creation_time, humanize_time(current_time - creation_time))
      end)

    # we compare new and previous top stories and mark changes by setting
    # :updated in the story map
    mark_updated =
      Enum.zip(top_newest, previous_top_newest)
      |> Enum.map(fn {%{id: new_id, score: new_score, comments: new_comments} = new,
                      %{id: old_id, score: old_score, comments: old_comments}} ->
        Map.put(
          new,
          :updated,
          new_id != old_id || new_score != old_score || new_comments != old_comments
        )
      end)

    changes =
      if mark_updated == [] do
        # mark_updated will be [] if previous_top_newest == [] because
        # the Enum.zip above will result in an empty list then
        top_newest
      else
        # at least one updated entry required
        if Enum.any?(mark_updated, &Map.fetch!(&1, :updated)) do
          mark_updated
        else
          []
        end
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
