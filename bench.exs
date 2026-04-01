#
# Jiffy benchmark driver for benchee
#
# Config via env vars. These are set from bench.sh script usually.
#
#   BENCH_COMPARE   "all" or comma-separated list of: json, simdjsone,
#                   jsone, jsx. Default is "" (nothing)
#   BENCH_SAVE      path to save benchee results (for branch comparisons).
#   BENCH_LOAD      ':'-separated list of benchee files to load as
#                   baselines for comparison.
#   BENCH_TAG       tag applied to saved jiffy results; also used to
#                   label the current jiffy run when loading baselines.
#

inputs_list = [
  "GitHub",
  "Giphy",
  "GovTrack",
  "Blockchain",
  "Pokedex",
  "JSON Generator",
  "UTF-8 escaped",
  "UTF-8 unescaped",
  "Issue 90",
  "Canada",
  "Twitter",
  "CITM Catalog",
  "Semanticscholar Corpus",
  "GSoC 2018",
  "Numbers",
  "Marine IK",
]

read_json = fn name ->
  file =
    name
    |> String.downcase()
    |> String.replace(~r/([^\w]|-|_)+/, "-")
    |> String.trim("-")

  File.read!(Path.expand("data/#{file}.json", __DIR__))
end

inputs =
  Enum.flat_map(inputs_list, fn name ->
    json = read_json.(name)
    term = :jiffy.decode(json, [:return_maps])
    [{"Decode " <> name, {:decode, json}},
     {"Encode " <> name, {:encode, term}}]
  end)
  |> Map.new()

# Benchmark cases. Jiffy is always included, others are opt-ins
jiffy_fn = fn
  {:decode, j} -> :jiffy.decode(j, [:return_maps])
  {:encode, t} -> :jiffy.encode(t)
end

otp_version = String.to_integer(System.otp_release())
have_otp_json? = otp_version >= 27

alternatives = %{
  "json" => have_otp_json? && fn
    {:decode, j} -> :json.decode(j)
    {:encode, t} -> :json.encode(t)
  end,
  "simdjsone" => fn
    {:decode, j} -> :simdjson.decode(j)
    {:encode, t} -> :simdjson.encode(t)
  end,
  "jsone" => fn
    {:decode, j} -> :jsone.decode(j)
    {:encode, t} -> :jsone.encode(t)
  end,
  "jsx" => fn
    {:decode, j} -> :jsx.decode(j)
    {:encode, t} -> :jsx.encode(t)
  end,
}

# Save runs are the per-branch baselines for bench.sh. The branch/native tag
# only means something for jiffy, so skip alternatives during save runs. THis
# is so we compare say jiffy master vs jiffy 1.1.3.
saving? = System.get_env("BENCH_SAVE") != nil

requested =
  case System.get_env("BENCH_COMPARE", "") |> String.trim() do
    ""       -> MapSet.new()
    "all"    -> MapSet.new(Map.keys(alternatives))
    csv      -> csv |> String.split(",", trim: true) |> MapSet.new()
  end

tag = System.get_env("BENCH_TAG")
loading? = System.get_env("BENCH_LOAD") != nil
# Label current jiffy run only when we're loading baselines
jiffy_name = if tag && loading? && not saving?, do: "jiffy (#{tag})", else: "jiffy"

jobs =
  if saving? do
    %{jiffy_name => jiffy_fn}
  else
    alternatives
    |> Map.take(MapSet.to_list(requested))
    |> Enum.reject(fn {_, fun} -> fun == false end)
    |> Map.new()
    |> Map.put(jiffy_name, jiffy_fn)
  end

IO.puts("Smoke tests..")
for {input_name, input} <- inputs, {job, fun} <- jobs do
  IO.puts("Testing #{job} #{input_name}")
  fun.(input)
end
IO.puts("")

bench_opts =
  [
    warmup: 1,
    time: 3,
    inputs: inputs,
    exclude_outliers: true,
    formatters:
      if(saving?,
        do: [Benchee.Formatters.Console],
        else: [Benchee.Formatters.HTML, Benchee.Formatters.Console])
  ]
  |> Keyword.merge(
    case System.get_env("BENCH_SAVE") do
      nil  -> []
      path -> [save: [path: path, tag: tag || "jiffy"]]
    end
  )
  |> Keyword.merge(
    case System.get_env("BENCH_LOAD") do
      nil  -> []
      path -> [load: String.split(path, ":", trim: true)]
    end
  )

Benchee.run(jobs, bench_opts)
