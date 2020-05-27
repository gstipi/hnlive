defmodule HNLiveWeb.PageLive do
  use HNLiveWeb, :live_view
  alias HNLive.Watcher

  @impl true
  def mount(_params, _session, socket) do
    current_visitor_count = HNLive.Watcher.get_current_subscriber_count()

    if connected?(socket), do: HNLive.Watcher.subscribe(socket.id)

    socket =
      assign(socket,
        top_newest: Watcher.get_top_newest_stories(),
        current_visitor_count: current_visitor_count
      )

    {:ok, socket, temporary_assigns: [top_newest: []]}
  end

  @impl true
  def render(assigns) do
    ~L"""
    <div class="page-container">
      <div class="page-header">
        <span>HN Top 10 Newest Posts Live</span>
      </div>
      <%= if length(@top_newest) > 0 do %>
      <%= for {{id, score, title, comments, url, updated},idx} <- Enum.with_index(@top_newest) do %>
      <div class="row <%= class_update_animation(updated) %>">
        <div class="rank"><%= idx + 1 %>.</div>
        <div class="info-col">
          <a class="title" href="<%= url %>"><%= title %></a>
          <div class="subtext"><%= score %> points | <a href="https://news.ycombinator.com/item?id=<%= id %>"><%= comments %> comments</a>
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
  def handle_info({:update_top_newest, top_newest}, socket) do
    {:noreply, assign(socket, :top_newest, top_newest)}
  end

  @impl true
  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
        %{assigns: %{current_visitor_count: count}} = socket
      ) do
    current_visitor_count = count + map_size(joins) - map_size(leaves)

    {:noreply, assign(socket, :current_visitor_count, current_visitor_count)}
  end

  defp class_update_animation(show) do
    case show do
      true -> "update-animation"
      false -> ""
    end
  end
end
