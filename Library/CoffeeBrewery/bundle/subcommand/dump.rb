# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"
require "bundle/extensions/extension"

require "bundle/dumper"
module CoffeeBrewery
  module Cmd
    class Bundle < CoffeeBrewery::AbstractCommand
      class DumpSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args do
          extensions = CoffeeBrewery::Bundle.extensions
          usage_banner <<~EOS
            `coffee bundle dump`:
            Write all installed casks/formulae/images/taps into a `Brewfile` in the current directory or to a custom file specified with the `--file` option. This is useful as an installed-state snapshot and can be kept in version control and diffed.
          EOS
          named_args :none
          switch "--install",
                 description: "Run `install` before dumping dependencies."
          switch "-f", "--force",
                 description: "Overwrite an existing `Brewfile`."
          switch "--formula", "--formulae", "--brews",
                 description: "Dump CoffeeBrewery formula dependencies."
          switch "--no-formula", "--no-formulae", "--no-brews",
                 description: "Dump without CoffeeBrewery formula dependencies. " \
                              "Enabled by default if `$COFFEEBREWER_BUNDLE_DUMP_NO_BREW` is set."
          switch "--no-dump-coffee",
                 description: "Dump without CoffeeBrewery formula dependencies.",
                 env:         :bundle_dump_no_brew
          switch "--cask", "--casks",
                 description: "Dump CoffeeBrewery cask dependencies."
          switch "--no-cask", "--no-casks",
                 description: "Dump without CoffeeBrewery cask dependencies. " \
                              "Enabled by default if `$COFFEEBREWER_BUNDLE_DUMP_NO_CASK` is set."
          switch "--no-dump-cask",
                 description: "Dump without CoffeeBrewery cask dependencies.",
                 env:         :bundle_dump_no_cask
          switch "--tap", "--taps",
                 description: "Dump CoffeeBrewery tap dependencies."
          switch "--no-tap", "--no-taps",
                 description: "Dump without CoffeeBrewery tap dependencies. " \
                              "Enabled by default if `$COFFEEBREWER_BUNDLE_DUMP_NO_TAP` is set."
          switch "--no-dump-tap",
                 description: "Dump without CoffeeBrewery tap dependencies.",
                 env:         :bundle_dump_no_tap
          extensions.select(&:dump_supported?).each do |extension|
            switch "--#{extension.flag}",
                   description: extension.switch_description("Dump #{extension.banner_name}.")
          end
          extensions.select(&:dump_disable_supported?).each do |extension|
            env = "COFFEEBREWER_#{extension.dump_disable_env.to_s.upcase}"
            switch "--no-#{extension.flag}",
                   description: "#{extension.dump_disable_description} " \
                                "Enabled by default if `$#{env}` is set."
            switch "--no-dump-#{extension.flag}",
                   description: extension.dump_disable_description,
                   env:         extension.dump_disable_env
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
          switch "--no-restart",
                 description: "Do not add `restart_service` to formula lines."
        end

        sig { override.void }
        def run
          core_type_options = context.core_type_options(args, "dump")
          CoffeeBrewery::Bundle::Dumper.dump_brewfile(
            global:          context.global,
            file:            context.file,
            describe:        !args.no_describe?,
            force:           context.force,
            no_restart:      args.no_restart?,
            taps:            core_type_options.fetch(:taps),
            formulae:        core_type_options.fetch(:formulae),
            casks:           core_type_options.fetch(:casks),
            extension_types: context.extensions.select(&:dump_supported?).to_h do |extension|
              disabled = extension.dump_disable_supported? &&
                         context.extension_dump_disabled?(args, extension)
              enabled = !disabled &&
                        (context.extension_selected?(args, extension) || context.no_type_args)
              [extension.type, enabled]
            end,
          )
        end
      end
    end
  end
end
