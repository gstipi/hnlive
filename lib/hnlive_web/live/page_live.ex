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
    <center>
      <table id="hnmain">
        <tbody>
          <tr>
            <td class="orange-bg header">
              <span class="pagetop">
                HN Top 10 Newest Posts Live
              </span>
            </td>
          </tr>
          <tr class="spacer"></tr>
          <tr>
            <td>
              <%= if length(@top_newest) > 0 do %>
              <table class="itemlist">
                <%= for {{id, score, title, comments, url, updated},idx} <- Enum.with_index(@top_newest) do %>
                  <tr class="<%= class_update_animation(updated) %>">
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
          <%= if @current_visitor_count > 0 do %>
          <tr>
            <td class="subtext" style="text-align: center;">Current visitor count: <%= @current_visitor_count %></td>
          </tr>
          <tr class="spacer"></tr>
          <% end %>
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
