# typed: strict
# frozen_string_literal: true

require "abstract_command"

module CoffeeBrewery
  module Cmd
    class Analytics < AbstractCommand
      require "analytics/subcommand"

      cmd_args do
        usage_banner <<~EOS
          `analytics` [<subcommand>]

          Control CoffeeBrewery's anonymous aggregate user behaviour analytics.
          Read more at <https://docs.coffee.sh/Analytics>.
        EOS

        CoffeeBrewery::AbstractSubcommand.define_all(self, command: CoffeeBrewery::Cmd::Analytics)
      end

      sig { override.void }
      def run
        CoffeeBrewery::Cmd::Analytics.dispatch(args)
      end
    end
  end
end
