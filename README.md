# HNLive

HNLive is a small Elixir/Phoenix/LiveView web app showing the top 10 (by score or number of comments) newest [HackerNews](https://news.ycombinator.com/) stories in "real time" (i.e. as quickly as updates become available via the [HackerNews API](https://github.com/HackerNews/API)).

The app should be running on https://hntop10.gigalixirapp.com - please note that this is running on the free tier with limited memory and resources.

![A screenshot of the HNLive app, showing the top 10 newest HN posts sorted by score](screenshot1.png)

As seen in the screenshot above, updated rows (i.e. position, score or number of comments has changed) are briefly highlighted using a green background. The app uses a dark theme inspired by a [discussion on HackerNews](https://news.ycombinator.com/item?id=23197966). 

The motivation for building HNLive was twofold:
  * I had read and heard many good things about [Elixir](https://elixir-lang.org/), [Phoenix](https://www.phoenixframework.org/) and [LiveView](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html), and after watching Chris McCord`s demo ["Build a real-time Twitter clone in 15 minutes with LiveView and Phoenix 1.5"](https://www.youtube.com/watch?v=MZvmYaFkNJI), I finally said to myself: "That looks awesome, time to learn Elixir and Phoenix!" HNLive is the app I built over the last couple of days while on this learning journey, so don't expect idiomatic or bug-free code - feel free to point out potential improvements!
  * I love browsing [HackerNews](https://news.ycombinator.com/), but the selection of stories on the front page, the ["newest" page](https://news.ycombinator.com/newest) and the ["best" page](https://news.ycombinator.com/best) is not ideal if you want to see at a glance which new stories (say, submitted over the course of the last 12 hours) have received the most upvotes or are discussed particularly controversially (as judged by the number of comments). HNLive attempts to address this using data from the [HackerNews API](https://github.com/HackerNews/API) to provide the top 10 submissions, sorted by score or number of comments, taking into account only the last 500 submissions. I also wanted to see updates to the top 10 (and scores and number of comments) in real time, which was made easy by using LiveView. 

To start hacking on HNLive:

  * Make sure that Erlang, Elixir and Node.JS are installed, see the [Phoenix installation instructions](https://hexdocs.pm/phoenix/installation.html) for a guide. HNLive does not require PostgreSQL.
  * Clone the git repository with `git clone https://github.com/gstipi/hnlive.git`
  * Setup the project with `mix setup`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

How would you run this in production? Please [check the official Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

In order to get this up and running on [Gigalixir](https://www.gigalixir.com/), I used the [official Gigalixir documentation](https://gigalixir.readthedocs.io/en/latest/index.html).

## Some remarks on the the project structure and Elixir/Phoenix/LiveView features used

[`HNLive.Api`](lib/hnlive/api.ex)

## Additional notes

Initial project created with the Phoenix generator: `mix phx.new hnlive --module HNLive --live --no-ecto`

I also had to update to latest Phoenix and LiveView versions in `mix.exs`:

``` 
{:phoenix, "~> 1.5.3"},
{:phoenix_live_view, "~> 0.13.0"},
```

The only additional dependency I needed was [HTTPoison](https://hexdocs.pm/httpoison/HTTPoison.html), which I also added in `mix.exs`:

`{:httpoison, "~> 1.6"}`

To the supervision tree in `HNLive.Application`, add 

```
# Hackney pool used for HTTPoison requests
:hackney_pool.child_spec(:httpoison_pool, timeout: 15000, max_connections: 30)
```

Run `mix deps.get` to retrieve updated dependencies.

Add `/.elixir_ls/` to .gitignore if using ElixirLS.


