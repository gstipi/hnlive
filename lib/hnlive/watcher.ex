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

  def get_top_newest_stories() do
    GenServer.call(__MODULE__, :get_top_newest_stories)
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
    {:ok, %{stories: %{}, top_newest: [], last_updated_ids: []}}
  end

  @impl true
  def handle_call(:get_top_newest_stories, _from, %{top_newest: top_newest} = state) do
    {:reply, top_newest, state}
  end

  @impl true
  def handle_info({:init, stories}, state) do
    if map_size(stories) == 0, do: run_init(@retry_init_after)
    {:noreply, %{state | stories: stories, top_newest: update_top_newest(stories)}}
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
        %{stories: stories, top_newest: top_newest} = state
      ) do
    stories =
      Map.merge(stories, updated_stories)
      |> Enum.sort_by(&elem(&1, 0), :desc)
      |> Enum.take(500)
      |> Enum.into(%{})

    {:noreply, %{state | stories: stories, top_newest: update_top_newest(stories, top_newest)}}
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

  defp update_top_newest(stories, previous_top_newest \\ []) do
    top_newest =
      stories
      |> Enum.map(fn {
                       id,
                       %{score: score, title: title, comments: comments, url: url}
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
      |> Enum.sort_by(&Map.fetch!(&1, :score), :desc)
      |> Enum.take(@top_story_count)

    # we compare new and previous top stories and mark changes by setting
    # :updated in the story map
    mark_updated =
      Enum.zip(top_newest, previous_top_newest)
      |> Enum.map(fn {new, old} ->
        Map.put(new, :updated, Map.delete(new, :updated) != Map.delete(old, :updated))
      end)

    # check whether we should broadcast updates, no need if no changes
    # where made to the top stories
    {broadcast, to_broadcast} =
      if mark_updated == [] do
        # mark_updated will be [] if previous_top_newest == [] because
        # the Enum.zip above will result in an empty list then,
        # so we broadcast top_newest
        {true, top_newest}
      else
        # at least one update required to broadcast
        {Enum.any?(mark_updated, &Map.fetch!(&1, :updated)), mark_updated}
      end

    if broadcast,
      do: PubSub.broadcast!(@pub_sub, @pub_sub_topic, {:update_top_newest, to_broadcast})

    top_newest
  end
end
