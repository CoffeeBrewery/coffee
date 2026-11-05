# typed: strict
# frozen_string_literal: true

require "abstract_command"

module CoffeeBrewery
  module Cmd
    class Developer < AbstractCommand
      require "developer/subcommand"

      cmd_args do
        usage_banner <<~EOS
          `developer` [<subcommand>]

          Control CoffeeBrewery's developer mode. When developer mode is enabled,
          `coffee update` will update CoffeeBrewery to the latest commit on the `main`
          branch instead of the latest stable version along with some other behaviour changes.
        EOS

        CoffeeBrewery::AbstractSubcommand.define_all(self, command: CoffeeBrewery::Cmd::Developer)
      end

      sig { override.void }
      def run
        CoffeeBrewery::Cmd::Developer.dispatch(args)
      end
    end
  end
end
