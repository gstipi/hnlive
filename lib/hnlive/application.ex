defmodule HNLive.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      HNLiveWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: HNLive.PubSub},
      # Start the Endpoint (http/https)
      HNLiveWeb.Endpoint,
      # Hackney pool used for httpoison requests
      :hackney_pool.child_spec(:httpoison_pool, timeout: 15000, max_connections: 30),
      # Start HackerNews watcher
      HNLive.Watcher
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HNLive.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    HNLiveWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
