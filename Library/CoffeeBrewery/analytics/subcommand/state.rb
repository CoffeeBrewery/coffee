# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"
require "utils/analytics"

module CoffeeBrewery
  module Cmd
    class Analytics < CoffeeBrewery::AbstractCommand
      class StateSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args default: true do
          usage_banner <<~EOS
            `coffee analytics` [`state`]:
            Display the current state of CoffeeBrewery's analytics.
          EOS
          named_args :none
        end

        sig { override.void }
        def run
          if Utils::Analytics.disabled?
            puts "InfluxDB analytics are disabled."
          else
            puts "InfluxDB analytics are enabled."
          end
          puts "Google Analytics were destroyed."
        end
      end
    end
  end
end
