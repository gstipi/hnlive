defmodule HNLiveWeb.PageLive do
  use HNLiveWeb, :live_view
  alias HNLive.Watcher

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      HNLive.Watcher.subscribe()
    end

    socket = assign(socket, :top_newest, Watcher.get_top_newest_stories())
    {:ok, socket, temporary_assigns: [top_newest: []]}
  end

  @impl true
  def render(assigns) do
    ~L"""
    <section class="section">
    <h1 class="title is-hidden-mobile">Hacker News Live</h1>
    <%= if length(@top_newest) > 0 do %>
    <table class="table is-striped is-fullwidth is-narrow">
      <thead>
        <tr>
          <th>Score</th>
          <th>Title</th>
          <th>Comments</th>
        </tr>
      </thead>
      <tbody>
        <%= for {id, score, title, comments, url, updated} <- @top_newest do %>
          <tr class="<%= class_update_animation(updated) %>" >
            <td><%= score %></td>
            <td><a href="<%= url %>"> <%= title %></a> </td>
            <td><a href="https://news.ycombinator.com/item?id=<%= id %>"><%= comments %></a></td>
          </tr>
        <% end %>
      </tbody>
    </table>
    <% else %>
      <p> No data available yet. </p>
    <% end %>
    </section>
    """
  end

  @impl true
  def handle_info({:update_top_newest, top_newest}, socket) do
    {:noreply, assign(socket, :top_newest, top_newest)}
  end

  defp class_update_animation(show) do
    case show do
      true -> "update-animation"
      false -> ""
    end
  end
end
