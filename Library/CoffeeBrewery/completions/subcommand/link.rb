# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"
require "completions"

module CoffeeBrewery
  module Cmd
    class CompletionsCmd < CoffeeBrewery::AbstractCommand
      class LinkSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args do
          usage_banner <<~EOS
            `coffee completions link`:
            Link CoffeeBrewery's completions.
          EOS
          named_args :none
        end

        sig { override.void }
        def run
          Completions.link!
          puts "Completions are now linked."
        end
      end
    end
  end
end
