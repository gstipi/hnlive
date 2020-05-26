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
    <center>
      <table id="hnmain">
        <tbody>
          <tr>
            <td class="orange-bg header"><span class="pagetop">HN Top 10 Newest Posts Live</span></td>
          </tr>
          <tr class="spacer"></tr>
          <tr>
            <td>
              <%= if length(@top_newest) > 0 do %>
              <table class="itemlist">
                <%= for {{id, score, title, comments, url, updated},idx} <- Enum.with_index(@top_newest) do %>
                  <tr class="athing <%= class_update_animation(updated) %>">
                    <td class="title align-right-top"><span class="rank"><%= idx + 1 %>.</span></td>
                    <td class="title">
                      <a class="storylink" href="<%= url %>"><%= title %></a>
                    </td>
                  </tr>
                  <tr class="<%= class_update_animation(updated) %>">
                    <td></td>
                    <td class="subtext">
                      <span class="score"><%= score %> points</span>
                      |
                      <a href="https://news.ycombinator.com/item?id=<%= id %>"><%= comments %> comments</a>
                    </td>
                  </tr>
                  <tr class="spacer"></tr>
                <% end %>
                </tbody>
              </table>
              <% else %>
              <p> No data available yet. </p>
              <% end %>
            </td>
          </tr>
          <tr>
            <td class="bottom-ruler orange-bg"></td>
          </tr>
        </tbody>
      </table>
    </center>
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
