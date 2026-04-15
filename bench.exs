inputs_list = [
  "GitHub",
  "Giphy",
  "GovTrack",
  "Blockchain",
  "Pokedex",
  "JSON Generator",
  "JSON Generator (Pretty)",
  "UTF-8 escaped",
  "UTF-8 unescaped",
  "Issue 90",
  "Large Numbers",
  "Canada",
  # From https://github.com/simdjson/simdjson-data
  "Twitter",
  "CITM Catalog",
  "Semanticscholar Corpus",
]

read_json = fn name ->
  file =
    name
    |> String.downcase
    |> String.replace(~r/([^\w]|-|_)+/, "-")
    |> String.trim("-")

  File.read!(Path.expand("data/#{file}.json", __DIR__))
end

# Build one benchee input per (op, document)
inputs =
  inputs_list
  |> Enum.flat_map(fn name ->
    json = read_json.(name)
    term = :jiffy.decode(json, [:return_maps, :use_nil])
    [
      {"Decode " <> name, {:decode, json}},
      {"Encode " <> name, {:encode, term}},
    ]
  end)
  |> Map.new()

jobs = %{
  "jiffy" => fn
    {:decode, json} -> :jiffy.decode(json, [:return_maps, :use_nil])
    {:encode, term} -> :jiffy.encode(term)
  end,
}

IO.puts("Checking jobs don't crash")
for {name, input} <- inputs, {job, fun} <- jobs do
  IO.puts("Testing #{job} #{name}")
  fun.(input)
end
IO.puts("")

bench_opts = [
  warmup: 2,
  time: 5,
  inputs: inputs,
  exclude_outliers: true
]

bench_opts =
  case System.get_env("BENCH_SAVE") do
    nil -> Keyword.put(bench_opts, :formatters, [Benchee.Formatters.HTML, Benchee.Formatters.Console])
    path -> Keyword.put(bench_opts, :save, [path: path, tag: System.get_env("BENCH_TAG", "jiffy")])
  end

bench_opts =
  case System.get_env("BENCH_LOAD") do
    nil -> bench_opts
    path -> Keyword.put(bench_opts, :load, path)
  end

Benchee.run(jobs, bench_opts)
