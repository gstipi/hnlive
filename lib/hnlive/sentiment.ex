defmodule HNLive.Sentiment do
  def run() do
    valence_map = File.read!("afinn-165.json") |> Jason.decode!()
    word_list = Map.keys(valence_map)
    sample = File.read!("samples.txt")

    {positive, neutral, negative, score} =
      :binary.matches(sample, word_list)
      |> Enum.filter(fn {start, length} -> is_word?(sample, start, length) end)
      |> Enum.map(fn {start, length} -> binary_part(sample, start, length) end)
      |> Enum.map(fn word -> {word, Map.fetch!(valence_map, word)} end)
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
