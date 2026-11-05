# typed: strict
# frozen_string_literal: true

require "utils/editor"

require "abstract_subcommand"

module CoffeeBrewery
  module Cmd
    class Bundle < CoffeeBrewery::AbstractCommand
      class EditSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args do
          usage_banner <<~EOS
            `coffee bundle edit`:
            Edit the `Brewfile` in your editor.
          EOS
          named_args :none
          switch "--install",
                 description: "Run `install` before editing the `Brewfile`."
        end

        sig { override.void }
        def run
          require "bundle/brewfile"

          Utils::Editor.open(CoffeeBrewery::Bundle::Brewfile.path(global: context.global, file: context.file))
        end
      end
    end
  end
end
