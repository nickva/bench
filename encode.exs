encode_jobs = %{
  "jiffy"     => &:jiffy.encode/1,
  "OTP json"  => &:json.encode/1,
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

Benchee.run(encode_jobs,
  warmup: 2,
  time: 5,
  memory_time: 0,
  inputs: for name <- encode_inputs, into: %{} do
            name
            |> read_data.()
            |> :json.decode()
            |> (&{name, &1}).()
          end,
  formatters: [Benchee.Formatters.Console]
)
