defmodule EXSM.MixProject do
  use Mix.Project

  def project do
    [
      app: :exsm,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env)
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
      {:mock, "~> 0.3.0", only: :test}
    ]
  end

  defp elixirc_paths(env_name) do
    case env_name do
      :test -> ["lib", "test"]
      _ -> ["lib"]
    end
  end
end
