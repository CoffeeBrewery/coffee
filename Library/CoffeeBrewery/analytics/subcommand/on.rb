# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"
require "utils/analytics"

module CoffeeBrewery
  module Cmd
    class Analytics < CoffeeBrewery::AbstractCommand
      class OnSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args do
          usage_banner <<~EOS
            `coffee analytics on`:
            Turn CoffeeBrewery's analytics on.
          EOS
          named_args :none
        end

        sig { override.void }
        def run
          Utils::Analytics.enable!
        end
      end
    end
  end
end
