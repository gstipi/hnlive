defmodule HNLiveWeb.PageLive do
  use HNLiveWeb, :live_view
  alias HNLive.{Watcher, Watcher.TopStory}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Watcher.subscribe(socket.id)

    socket =
      assign(socket,
        stories: Watcher.get_top_newest_stories(:score),
        current_visitor_count: 0,
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
            stories: Watcher.get_top_newest_stories(sort_by)
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
      <%= for {%TopStory{
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
      <div class="footer-text subtext">Current visitor count: <%= @current_visitor_count %></div>
      <% end %>
      <div class="footer-text subtext">
        <a href="https://github.com/gstipi/hnlive">View on GitHub <svg version="1.1" width="14" height="14" viewBox="0 0 16 16" fill="#8c96ac" aria-hidden="true"><path fill-rule="evenodd" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z"></path></svg></a>
      </div>
      <div class="page-footer"></div>

    </div>
    """
  end

  @impl true
  def handle_info(
        {:update_top_newest, stories},
        socket
      ) do
    stories = stories[socket.assigns.sort_by]

    socket =
      if length(stories) > 0 do
        assign(socket, :stories, stories)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:subscriber_count, subscriber_count}, socket) do
    {:noreply, assign(socket, :current_visitor_count, subscriber_count)}
  end

  defp class_update_animation(show), do: if(show, do: "update-animation", else: "")
end
