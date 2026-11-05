# typed: strict
# frozen_string_literal: true

require "utils/text"

require "abstract_subcommand"
require "bundle/extensions/extension"

require "bundle/adder"
module CoffeeBrewery
  module Cmd
    class Bundle < CoffeeBrewery::AbstractCommand
      class AddSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args do
          extensions = CoffeeBrewery::Bundle.extensions
          usage_banner <<~EOS
            `coffee bundle add` <name> [...]:
            Add entries to your `Brewfile`. Adds formulae by default. Use #{Utils::Text.to_sentence(["`--cask`", "`--tap`", *extensions.select(&:add_supported?).map { |extension| "`--#{extension.flag}`" }])} to add the corresponding entry instead.
          EOS
          named_args min: 1
          switch "--install",
                 description: "Run `install` before adding entries."
          switch "--formula", "--formulae", "--brews",
                 description: "Add CoffeeBrewery formula entries."
          switch "--cask", "--casks",
                 description: "Add CoffeeBrewery cask entries."
          switch "--tap", "--taps",
                 description: "Add CoffeeBrewery tap entries."
          extensions.select(&:add_supported?).each do |extension|
            switch "--#{extension.flag}",
                   description: extension.switch_description("Add entries for #{extension.banner_name}.")
          end
          switch "--no-describe",
                 description: "Do not add description comments above each line. Description comments are " \
                              "the default.",
                 env:         :bundle_no_describe
          switch "--describe",
                 description: "Add a description comment above each line, unless the " \
                              "dependency does not have a description. This is the default unless " \
                              "`$COFFEEBREWER_BUNDLE_NO_DESCRIBE` is set.",
                 env:         :bundle_describe,
                 replacement: "the default behaviour",
                 odisabled:   true
          conflicts "--describe", "--no-describe"
        end

        sig { override.void }
        def run
          selected_types = context.selected_types(args)
          raise UsageError, "`add` supports only one type of entry at a time." if selected_types.count != 1

          type = case (t = selected_types.first)
          when :none then :coffee
          when :mas then raise UsageError, "`add` does not support `--mas`."
          else t
          end

          extension = CoffeeBrewery::Bundle.extension(type)
          if extension && !extension.add_supported?
            raise UsageError,
                  "`add` does not support `--#{extension.flag}`."
          end

          CoffeeBrewery::Bundle::Adder.add(
            *args.named,
            type:,
            global:   context.global,
            file:     context.file,
            describe: !args.no_describe?,
          )
        end
      end
    end
  end
end
