# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"

require "services/cli"
module CoffeeBrewery
  module Cmd
    class Services < CoffeeBrewery::AbstractCommand
      class CleanupSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args aliases: %w[clean cl rm] do
          usage_banner <<~EOS
            [`sudo`] `coffee services cleanup`:
            Remove all unused services.
          EOS
          named_args :none
        end

        sig { override.void }
        def run
          cleaned = []

          cleaned += CoffeeBrewery::Services::Cli.kill_orphaned_services
          cleaned += CoffeeBrewery::Services::Cli.remove_unused_service_files

          return if cleaned.any?

          service_type = if CoffeeBrewery::Services::System.root?
            "root"
          else
            "user-space"
          end
          puts "All #{service_type} services OK, nothing cleaned..."
        end
      end
    end
  end
end
