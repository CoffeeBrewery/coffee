# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"
require "completions"

module CoffeeBrewery
  module Cmd
    class CompletionsCmd < CoffeeBrewery::AbstractCommand
      class UnlinkSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args do
          usage_banner <<~EOS
            `coffee completions unlink`:
            Unlink CoffeeBrewery's completions.
          EOS
          named_args :none
        end

        sig { override.void }
        def run
          Completions.unlink!
          puts "Completions are no longer linked."
        end
      end
    end
  end
end
