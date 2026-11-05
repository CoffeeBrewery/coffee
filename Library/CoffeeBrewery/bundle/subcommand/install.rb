# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"

require "bundle/brewfile"
require "bundle/installer"
module CoffeeBrewery
  module Cmd
    class Bundle < CoffeeBrewery::AbstractCommand
      class InstallSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args alias_options: { "upgrade" => "--upgrade" }, default: true do
          usage_banner <<~EOS
            `coffee bundle` [`install`|`upgrade`]:
            Install and upgrade (by default) all dependencies from the `Brewfile`.

            Use this to restore a recorded installed state from a `Brewfile`.

            `coffee bundle upgrade` is shorthand for `coffee bundle install --upgrade`.

            You can specify the `Brewfile` location using `--file` or by setting the `$COFFEEBREWER_BUNDLE_FILE` environment variable.

            You can skip the installation of dependencies by adding space-separated values to one or more of the following environment variables: `$COFFEEBREWER_BUNDLE_BREW_SKIP`, `$COFFEEBREWER_BUNDLE_CASK_SKIP`, `$COFFEEBREWER_BUNDLE_MAS_SKIP`, `$COFFEEBREWER_BUNDLE_TAP_SKIP`.
          EOS
          named_args :none
          switch "-v", "--verbose",
                 description: "Print output from commands as they are run."
          switch "--no-upgrade",
                 description: "Do not run `coffee upgrade` on outdated dependencies. " \
                              "Note they may still be upgraded by `coffee install` if needed.",
                 env:         :bundle_no_upgrade
          switch "--upgrade",
                 description: "Run `coffee upgrade` on outdated dependencies, " \
                              "even if `$COFFEEBREWER_BUNDLE_NO_UPGRADE` is set."
          flag   "--upgrade-formulae=", "--upgrade-formula=",
                 description: "Run `coffee upgrade` on any of these comma-separated formulae, " \
                              "even if `$COFFEEBREWER_BUNDLE_NO_UPGRADE` is set."
          flag "--jobs=",
               replacement: "the default behaviour",
               odeprecated: true
          switch "-f", "--force",
                 description: "Run with `--force`/`--overwrite`."
          switch "--cleanup",
                 description: "Ask to perform cleanup after installing dependencies. Requires `--force`, " \
                              "`--force-cleanup` or `$COFFEEBREWER_ASK`.",
                 env:         [:bundle_install_cleanup, "--global"],
                 odisabled:   true
          switch "--force-cleanup",
                 description: "Perform cleanup after installing dependencies without asking.",
                 env:         [:bundle_force_install_cleanup, "--global"]
          switch "--zap",
                 description: "Use `zap` instead of `uninstall` when cleaning up casks after " \
                              "installing dependencies."
        end

        sig { override.void }
        def run
          cleanup_requested = false
          if cleanup
            cleanup_requested = args.force_cleanup? || CoffeeBrewery::EnvConfig.bundle_install_cleanup?
            if args.zap? && !cleanup_requested
              raise UsageError,
                    "`--zap` cannot be passed without `--force-cleanup` or `$COFFEEBREWER_BUNDLE_INSTALL_CLEANUP`."
            end

            if cleanup_requested && !context.force && !args.force_cleanup? && !context.ask
              raise UsageError, "`coffee bundle install` cleanup requires `--force`, `--force-cleanup` " \
                                "or `$COFFEEBREWER_ASK`."
            end
          end

          if args.jobs.present?
            opoo "`--jobs` is ignored: installations use package managers' native batching."
          end

          @dsl = CoffeeBrewery::Bundle::Brewfile.read(global: context.global, file: context.file)
          result = CoffeeBrewery::Bundle::Installer.install!(
            @dsl.entries,
            global:     context.global,
            file:       context.file,
            no_lock:    false,
            no_upgrade: context.no_upgrade,
            verbose:    context.verbose,
            force:      context.force,
            quiet:      quiet || args.quiet?,
          )

          # Mark Brewfile formulae as installed_on_request to prevent autoremove
          # from removing them when their dependents are uninstalled
          CoffeeBrewery::Bundle.mark_as_installed_on_request!(@dsl.entries)

          result || exit(1)

          return unless cleanup

          return unless cleanup_requested

          require "bundle/subcommand/cleanup"

          # Don't need to reset cleanup specifically but this resets all the dumper modules.
          CoffeeBrewery::Cmd::Bundle::CleanupSubcommand.reset!
          CoffeeBrewery::Cmd::Bundle::CleanupSubcommand.cleanup(
            global: context.global, file: context.file, zap: context.zap,
            force: context.force || args.force_cleanup?,
            ask: context.ask, dsl:
          )
        end

        sig { returns(T.nilable(CoffeeBrewery::Bundle::Dsl)) }
        def dsl
          @dsl ||= T.let(nil, T.nilable(CoffeeBrewery::Bundle::Dsl))
          @dsl
        end
      end
    end
  end
end
