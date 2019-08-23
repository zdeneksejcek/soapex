defmodule Soapex.MixProject do
  use Mix.Project

  def project do
    [
      app: :soapex,
      version: "0.1.2",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
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

  defp description() do
    "This library offers implementation of SOAP1.1 and SOAP1.2 client. It downloads WSDL ang generates proxy module."
  end

  defp package() do
    [
      name: "soapex",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/zdeneksejcek/soapex"}
    ]
  end
end
