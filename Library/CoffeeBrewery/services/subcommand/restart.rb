# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"

require "services/cli"
module CoffeeBrewery
  module Cmd
    class Services < CoffeeBrewery::AbstractCommand
      class RestartSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args aliases: %w[relaunch reload r] do
          usage_banner <<~EOS
            [`sudo`] `coffee services restart` (<formula>|`--all`) [`--file=`]:
            Stop (if necessary) and start the service <formula> immediately and register it to launch at login (or boot).
          EOS
          named_args :service
          flag "--file=",
               description: "Use the service file from this location to `start` the service."
          switch "--all",
                 description: "Restart all services."
        end

        sig { override.void }
        def run
          CoffeeBrewery::Services::Cli.check!(targets)

          ran = []
          started = []
          targets.each do |service|
            if service.loaded? && !service.service_file_present?
              ran << service
            else
              # group not-started services with started ones for restart
              started << service
            end
            CoffeeBrewery::Services::Cli.stop([service], verbose: args.verbose?) if service.loaded?
          end

          CoffeeBrewery::Services::Cli.run(targets, args.file, verbose: args.verbose?) if ran.present?
          CoffeeBrewery::Services::Cli.start(started, args.file, verbose: args.verbose?) if started.present?
        end

        # NOTE: The restart command is used to update service files
        # after a package gets updated through `coffee upgrade`.
        # This works by removing the old file with `coffee services stop`
        # and installing the new one with `coffee services start|run`.
      end
    end
  end
end
