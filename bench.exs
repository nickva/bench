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
]

read_json = fn name ->
  file =
    name
    |> String.downcase
    |> String.replace(~r/([^\w]|-|_)+/, "-")
    |> String.trim("-")

  File.read!(Path.expand("data/#{file}.json", __DIR__))
end

otp_json? =
  case Integer.parse(System.otp_release()) do
    {version, ""} when version >= 27 -> true
    _ -> false
  end

# Build one benchee input per (op, document)
inputs =
  inputs_list
  |> Enum.flat_map(fn name ->
    json = read_json.(name)
    term = :jiffy.decode(json, [:return_maps])
    [
      {"Decode " <> name, {:decode, json}},
      {"Encode " <> name, {:encode, term}},
    ]
  end)
  |> Map.new()

# When we're loading and not saving, label the job. Otherwise,
# benchee will only tag runs loaded from save file and leave this
# run as "bare"
job_name =
  case {System.get_env("BENCH_TAG"), System.get_env("BENCH_SAVE"), System.get_env("BENCH_LOAD")} do
    {tag, nil, load} when is_binary(tag) and is_binary(load) -> "jiffy (#{tag})"
    _ -> "jiffy"
  end

jobs =
  %{
    job_name => fn
      {:decode, json} -> :jiffy.decode(json, [:return_maps])
      {:encode, term} -> :jiffy.encode(term)
    end,
  }

jobs =
  if otp_json? and System.get_env("BENCH_COMPARE_OTP_JSON") == "1" do
    Map.put(jobs, "otp json", fn
      {:decode, json} -> :json.decode(json)
      {:encode, term} -> :json.encode(term)
    end)
  else
    jobs
  end

IO.puts("Checking jobs don't crash")
for {name, input} <- inputs, {job, fun} <- jobs do
  IO.puts("Testing #{job} #{name}")
  fun.(input)
end
IO.puts("")

bench_opts = [
  warmup: 1,
  time: 3,
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
    nil ->
      bench_opts
    path ->
      # ':' separated list of paths (so we can load multiple baselines)
      paths = path |> String.split(":", trim: true)
      Keyword.put(bench_opts, :load, paths)
  end

Benchee.run(jobs, bench_opts)
