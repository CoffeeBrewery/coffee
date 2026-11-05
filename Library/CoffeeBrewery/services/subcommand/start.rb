# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"

require "services/cli"
module CoffeeBrewery
  module Cmd
    class Services < CoffeeBrewery::AbstractCommand
      class StartSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args aliases: %w[launch load s l] do
          usage_banner <<~EOS
            [`sudo`] `coffee services start` (<formula>|`--all`) [`--file=`]:
            Start the service <formula> immediately and register it to launch at login (or boot).
          EOS
          named_args :service
          flag "--file=",
               description: "Use the service file from this location to `start` the service."
          switch "--all",
                 description: "Start all services and register them to launch at login (or boot)."
        end

        sig { override.void }
        def run
          CoffeeBrewery::Services::Cli.check!(targets)
          CoffeeBrewery::Services::Cli.start(targets, args.file, verbose: args.verbose?)
        end
      end
    end
  end
end
