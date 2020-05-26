# Hnlive

To start your Phoenix server:

  * Setup the project with `mix setup`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

## How this was built

`mix phx.new hnlive --module HNLive --live --no-ecto`

Confirm installation of dependencies.

Update to latest Phoenix and LiveView versions in mix.exs:

``` 
{:phoenix, "~> 1.5.3"},
{:phoenix_live_view, "~> 0.13.0"},
```

Add HTTPoison dependency:

`{:httpoison, "~> 1.6"}`

Run `mix deps.get`.

`cd hnlive`

`mix setup`

`mix phx.server`

Add `/.elixir_ls/` to .gitignore if using ElixirLS.

To the supervision tree in `HNLive.Application`, add 

```
# Hackney pool used for httpoison requests
:hackney_pool.child_spec(:httpoison_pool, timeout: 15000, max_connections: 30)
```

