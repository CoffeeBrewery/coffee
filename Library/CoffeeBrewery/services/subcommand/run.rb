# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"

require "services/cli"
module CoffeeBrewery
  module Cmd
    class Services < CoffeeBrewery::AbstractCommand
      class RunSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args do
          usage_banner <<~EOS
            [`sudo`] `coffee services run` (<formula>|`--all`) [`--file=`]:
            Run the service <formula> without registering to launch at login (or boot).
          EOS
          named_args :service
          flag "--file=",
               description: "Use the service file from this location to `run` the service."
          switch "--all",
                 description: "Run all services without registering them to launch at login (or boot)."
        end

        sig { override.void }
        def run
          CoffeeBrewery::Services::Cli.check!(targets)
          CoffeeBrewery::Services::Cli.run(targets, args.file, verbose: args.verbose?)
        end
      end
    end
  end
end
