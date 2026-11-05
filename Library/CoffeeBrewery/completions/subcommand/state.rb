# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"
require "completions"

module CoffeeBrewery
  module Cmd
    class CompletionsCmd < CoffeeBrewery::AbstractCommand
      class StateSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args default: true do
          usage_banner <<~EOS
            `coffee completions` [`state`]:
            Display the current state of CoffeeBrewery's completions.
          EOS
          named_args :none
        end

        sig { override.void }
        def run
          if Completions.link_completions?
            puts "Completions are linked."
          else
            puts "Completions are not linked."
          end
        end
      end
    end
  end
end
