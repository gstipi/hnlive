defmodule HNLive.Api do
  @moduledoc """
  The `HNLive.Api` module provides a small selection of functions for querying the
  official Hacker News API (https://github.com/HackerNews/API).

  The module does not cover all the functionality offered by the Hacker News API, but
  just the features required to retrieve the 500 newest stories as well as recently updated items.

  None of the functions in this module are supposed to crash on failure, but will return empty
  results or errors instead.
  """

  @doc """
  Gets the 500 newest stories from the offical Hacker News API (via the `/v0/newstories` endpoint).

  Returns a map of story IDs to a story information map with the keys `score`, `title`, `comments`,
  and `url`, e.g.

  ```
  %{
    23319901 => %{
      comments: 197,
      score: 551,
      title: "Supabase (YC S20) – An open source Firebase alternative",
      url: "https://supabase.io/"
    },
  ...
  }
  ```

  If the story is an "Ask HN" or "Show HN" item, the `url` will point to the associated Hacker News
  comments thread. For regular stories, the `url` will point to the submitted story, as expected.

  Please note that `comments` contains the number of comments currently associated with this story.

  If the function fails, an empty map `%{}` is returned.
  """
  def get_newest_stories() do
    case get_new_story_ids() do
      {:ok, ids} ->
        get_many_stories(ids)

      _ ->
        %{}
    end
  end

  @doc """
  Gets recently changed items from the `/v0/updates` endpoint.any()

  Returns `{:ok, [IDs of changed items]}` or an `{:error, ...}` encountered during the function call.
  """
  def get_updates() do
    with {:ok, json} <- get_and_decode("https://hacker-news.firebaseio.com/v0/updates.json"),
         {:ok, updates} <- Map.fetch(json, "items") do
      {:ok, updates}
    end
  end

  @doc """
  Gets the stories corresponding to the given list of IDs.

  Returns a map of story IDs to a story information map with the keys `score`, `title`, `comments`,
  and `url`, similar to `get_newest_stories/0`.

  The function deals with IDs which do not correspond to stories by simply ignoring the results.

  If the function fails or no stories could be retrieved for the given IDs, an empty map `%{}` is returned.
  """
  def get_many_stories(ids) do
    get_many_items(ids)
    |> Enum.flat_map(&parse_story/1)
    |> Enum.into(%{})
  end

  defp parse_story(
         %{
           "type" => "story",
           "id" => id,
           "score" => score,
           "title" => title,
           "descendants" => comments
         } = item
       ) do
    [
      {
        id,
        %{
          score: score,
          title: title,
          comments: comments,
          # if no url is present, insert a url pointing to the corresponding
          # Hacker News comments thread
          url: Map.get(item, "url", "https://news.ycombinator.com/item?id=#{id}")
        }
      }
    ]
  end

  defp parse_story(_) do
    []
  end

  defp get_new_story_ids() do
    get_and_decode("https://hacker-news.firebaseio.com/v0/newstories.json")
  end

  defp get_item(id) do
    get_and_decode("https://hacker-news.firebaseio.com/v0/item/#{id}.json")
  end

  defp get_many_items(ids) do
    Enum.map(ids, &Task.async(fn -> get_item(&1) end))
    |> Enum.map(&Task.await/1)
    |> Enum.flat_map(fn item ->
      case item do
        {:ok, item} -> [item]
        # this results in errors returned by get_item to be filtered
        _ -> []
      end
    end)
  end

  defp get_and_decode(url) do
    with {:ok, response} <-
           HTTPoison.get(url, [],
             hackney: [pool: :httpoison_pool],
             # fix for https://github.com/edgurgel/httpoison/issues/411
             # since support for SSLv0 was removed in OTP23
             ssl: [{:versions, [:"tlsv1.2", :"tlsv1.1", :tlsv1]}]
           ),
         {:ok, decoded} <- Jason.decode(response.body) do
      {:ok, decoded}
    end
  end
end
