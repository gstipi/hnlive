defmodule HNLive.Sentiment do
  def run() do
    valence_map = File.read!("afinn-165.json") |> Jason.decode!()
    word_list = Map.keys(valence_map)
    sample = File.read!("samples.txt")

    {positive, neutral, negative} =
      :binary.matches(sample, word_list)
      |> Enum.filter(fn {start, length} -> is_word?(sample, start, length) end)
      |> Enum.map(fn {start, length} -> binary_part(sample, start, length) end)
      |> Enum.map(fn word -> {word, Map.fetch!(valence_map, word)} end)
      |> Enum.reduce({[], [], []}, fn {word, score}, {positive, neutral, negative} ->
        cond do
          score > 0 -> {[{word, score} | positive], neutral, negative}
          score == 0 -> {positive, [{word, score} | neutral], negative}
          score < 0 -> {positive, neutral, [{word, score} | negative]}
        end
      end)

    %{positive: positive, neutral: neutral, negative: negative}
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
