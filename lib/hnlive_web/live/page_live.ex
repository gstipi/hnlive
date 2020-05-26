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
    <table id="hnmain" border="0" cellpadding="0" cellspacing="0" width="85%" bgcolor="#f6f6ef">
      <tbody>
      <tr>
        <td bgcolor="#ff6600">
          <table border="0" cellpadding="0" cellspacing="0" width="100%" style="padding:2px">
            <tr>
              <td style="width:18px;padding-right:4px"></td>
              <td style="line-height:12pt; height:10px;">
               <span class="pagetop"><b class="hnname">HN Top 10 Newest Posts Live</b></span>
              </td>
            </tr>
          </table>
        </td>
      </tr>
      <tr id="pagespace" title="" style="height:10px"></tr>
      <tr>
      <td>
    <%= if length(@top_newest) > 0 do %>
    <table border="0" cellpadding="0" cellspacing="0" class="itemlist">
      <%= for {{id, score, title, comments, url, updated},idx} <- Enum.with_index(@top_newest) do %>
      <tr class="athing <%= class_update_animation(updated) %>" >
        <td align="right" valign="top" class="title"><span class="rank"><%= idx + 1 %>.</span></td>
        <td class="votelinks" valign="top">
        <div class="votearrow" title="upvote"></div>
        </td>
        <td class="title">
          <a class="storylink" href="<%= url %>"><%= title %></a>
        </td>
      </tr>
      <tr class="<%= class_update_animation(updated) %>">
        <td colspan="2"></td>
        <td class="subtext">
          <span class="score"><%= score %> points</span>
          |
          <a href="https://news.ycombinator.com/item?id=<%= id %>"><%= comments %> comments</a>
        </td>
      </tr>
      <tr class="spacer" style="height:5px"></tr>
      <% end %>
      </tbody>
    </table>
    <% else %>
    <p> No data available yet. </p>
    <% end %>
    </td>
    </tr>
    <tr>
    <td bgcolor="#ff6600">
      <table border="0" cellpadding="0" cellspacing="0" width="100%">
        <tr>
          <td style="line-height:2px; height:2px;">
          </td>
        </tr>
      </table>
    </td>
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
