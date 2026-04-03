encode_jobs = %{
  "jiffy"     => &:jiffy.encode/1,
}

encode_inputs = [
  "GitHub",
  "Giphy",
  "GovTrack",
  "Blockchain",
  "Pokedex",
  "JSON Generator",
  "UTF-8 unescaped",
  "Issue 90",
  "Canada",
]

read_data = fn (name) ->
  name
  |> String.downcase
  |> String.replace(~r/([^\w]|-|_)+/, "-")
  |> String.trim("-")
  |> (&"data/#{&1}.json").()
  |> Path.expand(__DIR__)
  |> File.read!
end

bench_opts = [
  warmup: 2,
  time: 5,
  memory_time: 0,
  inputs: for name <- encode_inputs, into: %{} do
            name
            |> read_data.()
            |> :jiffy.decode([:return_maps, :use_nil])
            |> (&{name, &1}).()
          end,
  formatters: [Benchee.Formatters.Console]
]

bench_opts =
  case System.get_env("BENCH_SAVE") do
    nil -> bench_opts
    path -> Keyword.put(bench_opts, :save, [path: path, tag: System.get_env("BENCH_TAG", "jiffy")])
  end

bench_opts =
  case System.get_env("BENCH_LOAD") do
    nil -> bench_opts
    path -> Keyword.put(bench_opts, :load, path)
  end

Benchee.run(encode_jobs, bench_opts)
