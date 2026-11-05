# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"

module CoffeeBrewery
  module Cmd
    class Bundle < CoffeeBrewery::AbstractCommand
      class EnvSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args do
          usage_banner <<~EOS
            `coffee bundle env` [`--check`] [`--no-secrets`]:
            Print the environment variables that would be set in a `coffee bundle exec` environment.
          EOS
          named_args :none
          switch "--install",
                 description: "Run `install` before printing the environment."
          switch "--check",
                 description: "Check that all dependencies in the Brewfile are installed before " \
                              "printing the environment.",
                 env:         :bundle_check
          switch "--no-secrets",
                 description: "Attempt to remove secrets from the environment before printing it.",
                 env:         :bundle_no_secrets
        end

        sig { override.void }
        def run
          ExecSubcommand.run_command("env", args:, context:)
        end
      end
    end
  end
end
