defmodule ChannelLock.Mixfile do
    use Mix.Project

    def project do
        [
            app: :channel_lock,
            version: "0.1.0",
            elixir: "~> 1.5",
            start_permanent: Mix.env == :prod,
            description: description(),
            package: package(),
            deps: [{:ex_doc, ">= 0.0.0", only: :dev}],
            name: "ChannelLock",
            source_url: "https://github.com/aaruel/channel_lock"
        ]
    end

    def application do
        [
            extra_applications: [:logger],
            mod: {ChannelLock, []}
        ]
    end

    defp package do
        [
            files: ["lib", "mix.exs", "LICENSE", "README.md"],
            maintainers: ["aaruel"],
            licenses: ["MIT"],
            links: %{"GitHub" => "https://github.com/aaruel/channel_lock"}
        ]
    end

    defp description do
        "Enables the ability to create channels with process synchronization"
    end
end
