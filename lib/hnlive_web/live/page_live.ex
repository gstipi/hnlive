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
    <%= if length(@top_newest) > 0 do %>
    <table id="hnmain" border="0" cellpadding="0" cellspacing="0" width="85%" bgcolor="#f6f6ef">
      <tbody>
      <tr>
        <td bgcolor="#ff6600">
          <table border="0" cellpadding="0" cellspacing="0" width="100%" style="padding:2px">
            <tr>
              <td style="width:18px;padding-right:4px"></td>
              <td style="line-height:12pt; height:10px;">
               <span class="pagetop"><b class="hnname">Hacker News Live</b></span>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    <tr id="pagespace" title="" style="height:10px">
    </tr>
    <tr>
    <td>
    <table border="0" cellpadding="0" cellspacing="0" class="itemlist">

        <%= for {id, score, title, comments, url, updated} <- @top_newest do %>
          <tr class="athing <%= class_update_animation(updated) %>" >
          <td align="right" valign="top" class="title"><span class="rank">1.</span></td>
            <td><%= score %></td>
            <td><a href="<%= url %>"> <%= title %></a> </td>
            <td><a href="https://news.ycombinator.com/item?id=<%= id %>"><%= comments %></a></td>
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
