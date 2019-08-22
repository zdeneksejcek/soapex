defmodule Soapex.MixProject do
  use Mix.Project

  def project do
    [
      app: :soapex,
      version: "0.1.2",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:sweet_xml, "~> 0.6.5"},
      {:httpoison, "~> 1.5"},
      {:xml_builder, "~> 2.1"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end
end
