defmodule HNLive.Api do
  def get_newest_stories() do
    case get_new_story_ids() do
      {:ok, ids} ->
        get_many_stories(ids)

      _ ->
        %{}
    end
  end

  def get_updates() do
    with {:ok, json} <- get_and_decode("https://hacker-news.firebaseio.com/v0/updates.json"),
         {:ok, updates} <- Map.fetch(json, "items") do
      {:ok, updates}
    end
  end

  def get_many_stories(ids) do
    get_many_items(ids)
    |> Enum.flat_map(&parse_story/1)
    |> Enum.into(%{})
  end

  defp parse_story(
         %{"id" => id, "score" => score, "title" => title, "descendants" => comments} = item
       ) do
    [
      {
        id,
        %{
          score: score,
          title: title,
          comments: comments,
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
             # since OTP23 has removed support for SSLv3
             ssl: [{:versions, [:"tlsv1.2", :"tlsv1.1", :tlsv1]}]
           ),
         {:ok, decoded} <- Jason.decode(response.body) do
      {:ok, decoded}
    end
  end
end
