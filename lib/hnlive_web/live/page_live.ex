defmodule HNLiveWeb.PageLive do
  use HNLiveWeb, :live_view
  alias HNLive.Watcher

  @impl true
  def mount(_params, _session, socket) do
    current_visitor_count = Watcher.get_current_subscriber_count()

    if connected?(socket), do: Watcher.subscribe(socket.id)

    socket =
      assign(socket,
        stories: Watcher.get_top_newest_stories_by(:score),
        current_visitor_count: current_visitor_count,
        sort_by: :score
      )

    {:ok, socket, temporary_assigns: [stories: []]}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case params["sort_by"] do
        sort_by when sort_by in ~w(score comments) ->
          sort_by = String.to_atom(sort_by)

          assign(socket,
            sort_by: sort_by,
            stories: Watcher.get_top_newest_stories_by(sort_by)
          )

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~L"""
    <div class="page-container">
      <div class="page-header">
        <div class="page-title">HN Top 10 Newest Posts Live</div>
        <div>
        <a><%= live_patch "sort by score", to: Routes.page_path(@socket, :index, %{sort_by: "score"}) %></a>
        | <a><%= live_patch "sort by number of comments", to: Routes.page_path(@socket, :index, %{sort_by: "comments"}) %></a>
      </div>
      </div>
      <%= if length(@stories) > 0 do %>
      <%= for {%{
                  id: id,
                  score: score,
                  title: title,
                  comments: comments,
                  url: url,
                  updated: updated,
                  creation_time: creation_time
                },
                idx
              } <- Enum.with_index(@stories) do %>
      <div class="row <%= class_update_animation(updated) %>">
        <div class="rank"><%= idx + 1 %>.</div>
        <div class="info-col">
          <a class="title" href="<%= url %>"><%= title %></a>
          <div class="subtext"><%= score %> points | <%= creation_time %> |
            <a href="https://news.ycombinator.com/item?id=<%= id %>"><%= comments %> comments</a>
          </div>
        </div>
      </div>
      <% end %>
      <% else %>
      <div class="subtext"> No data available yet. </div>
      <% end %>
      <%= if @current_visitor_count > 0 do %>
      <div class="visitor-count">Current visitor count: <%= @current_visitor_count %></div>
      <% end %>
      <div class="page-footer"></div>
    </div>
    """
  end

  @impl true
  def handle_info(
        {:update_top_newest_by, stories},
        socket
      ) do
    stories = Map.fetch!(stories, socket.assigns.sort_by)

    socket =
      if length(stories) > 0 do
        assign(socket, :stories, stories)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
        %{assigns: %{current_visitor_count: count}} = socket
      ) do
    current_visitor_count = count + map_size(joins) - map_size(leaves)

    {:noreply, assign(socket, :current_visitor_count, current_visitor_count)}
  end

  defp class_update_animation(show), do: if(show, do: "update-animation", else: "")
end
