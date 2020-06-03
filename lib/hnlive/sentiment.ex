defmodule HNLive.Sentiment.Score do
  File.read!("#{__DIR__}/afinn-165.json")
  |> Jason.decode!()
  |> (fn map ->
        def word_list(), do: unquote(Map.keys(map))
        map
      end).()
  |> Enum.each(fn {word, score} ->
    def score_word(unquote(word)), do: unquote(score)
  end)

  def score_word(_), do: nil
end

defmodule HNLive.Sentiment do
  alias HNLive.Sentiment.Score

  def score_sample(sample) do
    sample = String.downcase(sample)

    {positive, neutral, negative, score} =
      :binary.matches(sample, Score.word_list())
      |> Enum.filter(fn {start, length} -> is_word?(sample, start, length) end)
      |> Enum.map(fn {start, length} -> binary_part(sample, start, length) end)
      |> Enum.map(fn word -> {word, Score.score_word(word)} end)
      |> Enum.reduce({[], [], [], 0}, fn {word, score}, {positive, neutral, negative, sum} ->
        cond do
          score > 0 -> {[{word, score} | positive], neutral, negative, sum + score}
          score == 0 -> {positive, [{word, score} | neutral], negative, sum}
          score < 0 -> {positive, neutral, [{word, score} | negative], sum + score}
        end
      end)

    %{positive: positive, neutral: neutral, negative: negative, score: score}
  end

  defp is_word?(binary, start, length) do
    !Regex.match?(~r/[a-zA-Z]/, safe_binary_part(binary, start, -1)) &&
      !Regex.match?(~r/[a-zA-Z]/, safe_binary_part(binary, start + length, 1))
  end

  defp safe_binary_part(binary, start, length) do
    try do
      binary_part(binary, start, length)
    rescue
      ArgumentError -> ""
    end
  end
end

defmodule HNLive.TopSentiment do
  alias HNLive.Api
  alias HNLive.Sentiment

  def run() do
    Api.get_newest_stories()
    |> Enum.map(fn {id, story} ->
      Task.async(fn ->
        comments = Api.get_comments_for_story(story)

        score =
          Enum.map(comments, fn {_, comment} ->
            Sentiment.score_sample(comment.text).score
          end)
          |> Enum.sum()

        IO.puts("Got #{map_size(comments)} comments for #{id} with score #{score}")
        {id, score}
      end)
    end)
    |> Enum.into(%{}, &Task.await(&1, :infinity))
  end
end