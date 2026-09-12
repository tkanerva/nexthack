defmodule Nexthack.MixProject do
  use Mix.Project

  def project do
    [
      app: :nexthack,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex_cldc, "~> 1.1", only: [:dev, :test]}, # For terminal clearing
      {:mix_test_watch, "~> 1.1", only: [:dev, :test]}
    ]
  end
end