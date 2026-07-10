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

  defp jiffy_root() do
    candidates = [
      System.get_env("JIFFY_ROOT", ""),
      Path.join(__DIR__, "jiffy"),
      Path.expand("..", __DIR__)
    ]

    Enum.find(candidates, fn dir ->
      # Meh, kind of a hack
      dir != "" and File.exists?(Path.join(dir, "src/jiffy.erl"))
    end) ||
      Mix.raise(
        "jiffy not found, set JIFFY_ROOT=..path.. or " <>
          "symlink into #{Path.join(__DIR__, "jiffy")}"
      )
  end

  defp deps do
    [
      {:benchee, "~> 1.0"},
      {:benchee_html, "~> 1.0"},
      {:jiffy, path: jiffy_root(), override: true},
      {:glazer, "~> 0.5", manager: :rebar3},
      {:jsone, "~> 1.9"},
      {:jsx, "~> 3.1"},
    ]
  end
end
