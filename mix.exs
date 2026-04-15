defmodule JiffyBench.MixProject do
  use Mix.Project

  def project do
    [
      app: :jiffy_bench,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp aliases() do
    [
      bench: ["run bench.exs"]
    ]
  end

  defp deps do
    [
      {:benchee, "~> 1.0"},
      {:benchee_html, "~> 1.0"},
      {:jiffy, path: "..", override: true},
    ]
  end
end
