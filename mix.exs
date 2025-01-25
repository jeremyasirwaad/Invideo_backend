defmodule InvideoBackend.MixProject do
  use Mix.Project

  def project do
    [
      app: :invideo_backend,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Define the application behavior
  def application do
    [
      extra_applications: [:logger],
      mod: {InvideoBackend.Application, []} # Add this line to ensure the application starts your supervision tree
    ]
  end

  # Add necessary dependencies for Plug, Tesla, and Jason
  defp deps do
    [
      {:plug_cowboy, "~> 2.0"},  # For routing and HTTP server
      {:tesla, "~> 1.4"},        # For making HTTP requests
      {:jason, "~> 1.2"},         # For JSON encoding and decoding
      {:httpoison, "~> 1.5"}
    ]
  end
end
