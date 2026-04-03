decode_jobs = %{
  "jiffy"    => fn {json, _} -> :jiffy.decode(json, [:return_maps, :use_nil]) end,
}

decode_inputs = [
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
]

read_data = fn (name) ->
  file =
    name
    |> String.downcase
    |> String.replace(~r/([^\w]|-|_)+/, "-")
    |> String.trim("-")

  json = File.read!(Path.expand("data/#{file}.json", __DIR__))
  etf = :erlang.term_to_binary(:jiffy.decode(json, [:return_maps, :use_nil]))

  {json, etf}
end

inputs = for name <- decode_inputs, into: %{}, do: {name, read_data.(name)}

IO.puts("Checking jobs don't crash")
for {name, input} <- inputs, {job, decode_job} <- decode_jobs do
  IO.puts("Testing #{job} #{name}")
  decode_job.(input)
end
IO.puts("\n")

bench_opts = [
  warmup: 2,
  time: 5,
  memory_time: 0,
  inputs: inputs,
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

Benchee.run(decode_jobs, bench_opts)
