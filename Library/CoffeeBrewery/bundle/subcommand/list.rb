# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"
require "bundle/extensions/extension"

require "bundle/brewfile"
require "bundle/lister"
module CoffeeBrewery
  module Cmd
    class Bundle < CoffeeBrewery::AbstractCommand
      class ListSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args do
          usage_banner <<~EOS
            `coffee bundle list`:
            List all dependencies present in the `Brewfile`.

            By default, only CoffeeBrewery formula dependencies are listed.
          EOS
          named_args :none
          switch "--install",
                 description: "Run `install` before listing dependencies."
          switch "--all",
                 description: "List all dependencies."
          switch "--formula", "--formulae", "--brews",
                 description: "List CoffeeBrewery formula dependencies."
          switch "--cask", "--casks",
                 description: "List CoffeeBrewery cask dependencies."
          switch "--tap", "--taps",
                 description: "List CoffeeBrewery tap dependencies."
          CoffeeBrewery::Bundle.extensions.each do |extension|
            switch "--#{extension.flag}",
                   description: extension.switch_description("List #{extension.banner_name}.")
          end
        end

        sig { override.void }
        def run
          CoffeeBrewery::Bundle::Lister.list(
            CoffeeBrewery::Bundle::Brewfile.read(global: context.global, file: context.file).entries,
            formulae:        args.formulae? || args.all? || context.no_type_args,
            casks:           args.casks? || args.all?,
            taps:            args.taps? || args.all?,
            extension_types: context.extensions.to_h do |extension|
              [extension.type, context.extension_selected?(args, extension) || args.all?]
            end,
          )
        end
      end
    end
  end
end
