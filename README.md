# HNLive

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

DONE: add Phoenix.Presence to see how many people are currently on the page!

remote: Starting zero-downtime rolling deploy.
remote: Please wait a minute for the new instance(s) to roll out and pass health checks.
remote: For troubleshooting, See:      http://gigalixir.readthedocs.io/en/latest/main.html#troubleshooting
remote: For help, contact:             help@gigalixir.com
remote: Try hitting your app with:     curl https://jagged-grubby-leafwing.gigalixirapp.com/
remote: Check your app logs with:      gigalixir logs -a jagged-grubby-leafwing
remote: Check deploy status with:      gigalixir ps -a jagged-grubby-leafwing
remote: Updated property [core/account].
To https://git.gigalixir.com/jagged-grubby-leafwing.git/
 * [new branch]      master -> master