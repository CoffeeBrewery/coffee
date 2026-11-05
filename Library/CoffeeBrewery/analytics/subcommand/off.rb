# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"
require "utils/analytics"

module CoffeeBrewery
  module Cmd
    class Analytics < CoffeeBrewery::AbstractCommand
      class OffSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args do
          usage_banner <<~EOS
            `coffee analytics off`:
            Turn CoffeeBrewery's analytics off.
          EOS
          named_args :none
        end

        sig { override.void }
        def run
          Utils::Analytics.disable!
        end
      end
    end
  end
end
