# typed: strict
# frozen_string_literal: true

require "utils/shell"

require "abstract_subcommand"

require "English"
require "exceptions"
require "extend/ENV"
require "utils"
require "PATH"
require "utils/output"
module CoffeeBrewery
  module Cmd
    class Bundle < CoffeeBrewery::AbstractCommand
      class ExecSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args do
          usage_banner <<~EOS
            `coffee bundle exec` [`--check`] [`--no-secrets`] [`--sandbox=`<path>] [`--deny-network`] <command>:
            Run an external command in an isolated build environment based on the `Brewfile` dependencies.

            This sanitised build environment ignores unrequested dependencies, which makes sure that things you didn't specify in your `Brewfile` won't get picked up by commands like `bundle install`, `npm install`, etc. It will also add compiler flags which will help with finding keg-only dependencies like `openssl`, `icu4c`, etc.
          EOS
          named_args :command
          switch "--install",
                 description: "Run `install` before executing the command."
          switch "--services",
                 description: "Temporarily start services while executing the command.",
                 env:         :bundle_services
          switch "--check",
                 description: "Check that all dependencies in the Brewfile are installed before " \
                              "executing the command.",
                 env:         :bundle_check
          switch "--no-secrets",
                 description: "Attempt to remove secrets from the environment before executing the command.",
                 env:         :bundle_no_secrets
          flag "--sandbox=",
               description: "Run <command> in CoffeeBrewery's sandbox, allowing writes to <path> and CoffeeBrewery's " \
                            "temporary and cache directories."
          switch "--deny-network",
                 description: "Deny network access from inside the sandbox.",
                 depends_on:  "--sandbox="
        end

        sig { override.void }
        def run
          self.class.run_command(*args.named, args:, context:)
        end

        sig { params(named_args: String, args: T.untyped, context: CoffeeBrewery::Cmd::Bundle::SubcommandContext).void }
        def self.run_command(*named_args, args:, context:)
          sandbox_path = args.sandbox
          sandbox_options = {}
          if sandbox_path
            sandbox_options[:sandbox_path] = sandbox_path
            sandbox_options[:deny_network] = args.deny_network?
          end

          run_external_command(
            *named_args,
            global:     context.global,
            file:       context.file,
            subcommand: context.subcommand,
            services:   args.services?,
            check:      args.check?,
            no_secrets: args.no_secrets?,
            **sandbox_options,
          )
        end

        extend Utils::Output::Mixin

        PATH_LIKE_ENV_REGEX = /.+#{File::PATH_SEPARATOR}/

        sig {
          params(
            args:         String,
            global:       T::Boolean,
            file:         T.nilable(String),
            subcommand:   String,
            services:     T::Boolean,
            check:        T::Boolean,
            no_secrets:   T::Boolean,
            sandbox_path: T.nilable(String),
            deny_network: T::Boolean,
          ).void
        }
        def self.run_external_command(
          *args,
          global: false,
          file: nil,
          subcommand: "",
          services: false,
          check: false,
          no_secrets: false,
          sandbox_path: nil,
          deny_network: false
        )
          if check
            require "bundle/subcommand/check"
            CheckSubcommand.new(CoffeeBrewery::Cmd::Bundle.parser.args, context: SubcommandContext.new(
              subcommand:   "check",
              global:,
              file:,
              no_upgrade:   false,
              verbose:      false,
              force:        false,
              ask:          false,
              zap:          false,
              no_type_args: true,
              extensions:   CoffeeBrewery::Bundle.extensions,
            ), quiet: true).run
          end

          # Store the old environment so we can check if things were already set
          # before we start mutating it.
          old_env = ENV.to_h
          ENV.clear_sensitive_environment! if no_secrets

          # Setup CoffeeBrewery's ENV extensions
          ENV.activate_extensions!

          command = args.first
          raise UsageError, "No command to execute was specified!" if command.blank?
          raise UsageError, "`--sandbox` requires a writable path." if sandbox_path == ""
          raise UsageError, "`--deny-network` requires `--sandbox`." if deny_network && sandbox_path.blank?

          require "bundle/brewfile"
          @dsl ||= T.let(nil, T.nilable(CoffeeBrewery::Bundle::Dsl))
          @dsl = CoffeeBrewery::Bundle::Brewfile.read(global:, file:)

          require "formula"
          require "formulary"

          ENV.deps = @dsl.entries.filter_map do |entry|
            next if entry.type != :coffee

            Formulary.factory(entry.name)
          end

          # Allow setting all dependencies to be keg-only
          # (i.e. should be explicitly in COFFEEBREWER_*PATHs ahead of COFFEEBREWER_PREFIX)
          ENV.keg_only_deps = if ENV["COFFEEBREWER_BUNDLE_EXEC_ALL_KEG_ONLY_DEPS"].present?
            ENV.delete("COFFEEBREWER_BUNDLE_EXEC_ALL_KEG_ONLY_DEPS")
            ENV.deps
          else
            ENV.deps.select(&:keg_only?)
          end
          ENV.setup_build_environment

          # Enable compiler flag filtering
          ENV.refurbish_args

          # Add variable to detect being inside a `coffee bundle exec` environment
          ENV["COFFEEBREWER_INSIDE_BUNDLE"] = "1"

          # Set up `nodenv`, `pyenv` and `rbenv` if present.
          env_formulae = %w[nodenv pyenv rbenv]
          ENV.deps.each do |dep|
            dep_name = dep.name
            next unless env_formulae.include?(dep_name)

            dep_root = ENV.fetch("COFFEEBREWER_#{dep_name.upcase}_ROOT", "#{Dir.home}/.#{dep_name}")
            ENV.prepend_path "PATH", Pathname.new(dep_root)/"shims"
          end

          # Setup pkgconf, if needed, to help locate packages
          CoffeeBrewery::Bundle.prepend_pkgconf_path_if_needed!

          # For commands which aren't either absolute or relative
          # Add the command directory to PATH, since it may get blown away by superenv
          if command.exclude?("/") && (which_command = which(command))
            ENV.prepend_path "PATH", which_command.dirname.to_s
          end

          # Replace the formula versions from the environment variables
          ENV.deps.each do |formula|
            formula_name = formula.name
            formula_version = CoffeeBrewery::Bundle.formula_versions_from_env(formula_name)
            next unless formula_version

            ENV.each do |key, value|
              opt = %r{/opt/#{formula_name}([/:$])}
              next unless value.match(opt)

              cellar = "/Cellar/#{formula_name}/#{formula_version}\\1"

              # Look for PATH-like environment variables
              ENV[key] = if key.include?("PATH") && value.match?(PATH_LIKE_ENV_REGEX)
                rejected_opts = []
                path = PATH.new(ENV.fetch("PATH"))
                           .reject do |path_value|
                  rejected_opts << path_value if path_value.match?(opt)
                end
                rejected_opts.each do |path_value|
                  path.prepend(path_value.gsub(opt, cellar))
                end
                path.to_s
              else
                value.gsub(opt, cellar)
              end
            end
          end

          # Ensure coffee bundle exec/sh/env commands have access to other tools in the PATH
          if (homebrew_path = ENV.fetch("COFFEEBREWER_PATH", nil))
            ENV.append_path "PATH", homebrew_path
          end

          # For commands which aren't either absolute or relative
          raise "command was not found in your PATH: #{command}" if command.exclude?("/") && which(command).nil?

          %w[COFFEEBREWER_TEMP TMPDIR COFFEEBREWER_TMPDIR].each do |var|
            value = ENV.fetch(var, nil)
            next if value.blank?
            next if File.writable?(value)

            ENV.delete(var)
          end

          ENV.each do |key, value|
            # Look for PATH-like environment variables
            next if key.exclude?("PATH") || !value.match?(PATH_LIKE_ENV_REGEX)

            # Exclude CoffeeBrewery shims from the PATH as they don't work
            # without all CoffeeBrewery environment variables and can interfere with
            # non-CoffeeBrewery builds.
            ENV[key] = PATH.new(value)
                           .reject do |path_value|
              path_value.include?("/CoffeeBrewery/shims/")
            end.to_s
          end

          if subcommand == "env"
            ENV.sort.each do |key, value|
              # Skip exporting CoffeeBrewery internal variables that won't be used by other tools.
              # Those CoffeeBrewery needs have already been set to global constants and/or are exported again later.
              # Setting these globally can interfere with nested CoffeeBrewery invocations/environments.
              if key.start_with?("COFFEEBREWER_", "PORTABLE_RUBY_")
                ENV.delete(key)
                next
              end

              # No need to export empty values.
              next if value.blank?

              # Skip exporting things that were the same in the old environment.
              old_value = old_env[key]
              next if old_value == value

              # Look for PATH-like environment variables
              if key.include?("PATH") && value.match?(PATH_LIKE_ENV_REGEX)
                old_values = old_value.to_s.split(File::PATH_SEPARATOR)
                path = PATH.new(value)
                           .reject do |path_value|
                  # Exclude existing/old values as they've already been exported.
                  old_values.include?(path_value)
                end
                next if path.blank?

                puts "export #{key}=\"#{Utils::Shell.sh_quote(path.to_s)}:${#{key}:-}\""
              else
                puts "export #{key}=\"#{Utils::Shell.sh_quote(value)}\""
              end
            end
            return
          elsif subcommand == "sh"
            preferred_path = Utils::Shell.preferred_path(default: "/bin/bash")
            notice = unless CoffeeBrewery::EnvConfig.no_env_hints?
              <<~EOS
                Your shell has been configured to use a build environment from your `Brewfile`.
                This should help you build stuff.
                Hide these hints with `COFFEEBREWER_NO_ENV_HINTS=1` (see `man coffee`).
                When done, type `exit`.
              EOS
            end
            ENV["COFFEEBREWER_FORCE_API_AUTO_UPDATE"] = nil
            args = [Utils::Shell.shell_with_prompt("coffee bundle", preferred_path:, notice:)]
          end

          require "sandbox" if sandbox_path

          if services
            require "bundle/brew_services"

            exit_code = T.let(0, Integer)
            run_services(@dsl.entries) do
              if sandbox_path
                begin
                  Sandbox.run_command(*args, writable_path: sandbox_path, deny_network:)
                rescue ErrorDuringExecution => e
                  exit_code = e.exitstatus || 1
                end
              else
                Kernel.system(*args)
                if (system_exit_code = $CHILD_STATUS&.exitstatus)
                  exit_code = system_exit_code
                end
              end
            end
            exit!(exit_code)
          elsif sandbox_path
            Sandbox.run_command(*args, writable_path: sandbox_path, deny_network:)
          else
            exec(*args)
          end
        end

        sig {
          params(
            entries: T::Array[CoffeeBrewery::Bundle::Dsl::Entry],
            _block:  T.proc.params(
              entry:                CoffeeBrewery::Bundle::Dsl::Entry,
              info:                 T::Hash[String, T.untyped],
              service_file:         Pathname,
              conflicting_services: T::Array[T::Hash[String, T.untyped]],
            ).void,
          ).void
        }
        private_class_method def self.map_service_info(entries, &_block)
          entries_formulae = entries.filter_map do |entry|
            next if entry.type != :coffee

            formula = Formula[entry.name]
            next unless formula.any_version_installed?

            [entry, formula]
          end.to_h

          return if entries_formulae.empty?

          conflicts = entries_formulae.to_h do |entry, formula|
            [
              entry,
              (
                formula.versioned_formulae_names +
                  formula.conflicts.map(&:name) +
                  Array(entry.options[:conflicts_with])
              ).uniq,
            ]
          end

          # The formula + everything that could possible conflict with the service
          names_to_query = entries_formulae.flat_map do |entry, formula|
            [
              formula.name,
              *conflicts.fetch(entry),
            ]
          end

          # We parse from a command invocation so that coffee wrappers can invoke special actions
          # for the elevated nature of `coffee services`
          services_info = JSON.parse(
            Utils.safe_popen_read(COFFEEBREWER_BREW_FILE, "services", "info", "--json", *names_to_query),
          )

          entries_formulae.filter_map do |entry, formula|
            service_file = CoffeeBrewery::Bundle::Brew::Services.versioned_service_file(entry.name)

            if service_file.nil?
              prefix = formula.any_installed_prefix
              next if prefix.nil?

              service_file = CoffeeBrewery::Bundle::Brew::Services.service_file_for(formula, prefix)
            end

            next if service_file.nil?

            info = services_info.find { |candidate| candidate["name"] == formula.name }
            conflicting_services = services_info.select do |candidate|
              next unless candidate["running"]

              conflicts.fetch(entry).include?(candidate["name"])
            end

            raise "Failed to get service info for #{entry.name}" if info.nil?

            yield entry, info, service_file, conflicting_services
          end
        end

        sig { params(entries: T::Array[CoffeeBrewery::Bundle::Dsl::Entry], _block: T.nilable(T.proc.void)).void }
        private_class_method def self.run_services(entries, &_block)
          entries_to_stop = []
          services_to_restart = []

          map_service_info(entries) do |entry, info, service_file, conflicting_services|
            # Don't restart if already running this version
            loaded_file = Pathname.new(info["loaded_file"].to_s)
            next if info["running"] && loaded_file.file? && loaded_file.realpath == service_file.realpath

            if info["running"] && !CoffeeBrewery::Bundle::Brew::Services.stop(info["name"], keep: true)
              opoo "Failed to stop #{info["name"]} service"
            end

            conflicting_services.each do |conflict|
              if CoffeeBrewery::Bundle::Brew::Services.stop(conflict["name"], keep: true)
                services_to_restart << conflict["name"] if conflict["registered"]
              else
                opoo "Failed to stop #{conflict["name"]} service"
              end
            end

            unless CoffeeBrewery::Bundle::Brew::Services.run(info["name"], file: service_file)
              opoo "Failed to start #{info["name"]} service"
            end

            entries_to_stop << entry
          end

          return unless block_given?

          begin
            yield
          ensure
            # Do a full re-evaluation of services instead state has changed
            stop_services(entries_to_stop)

            services_to_restart.each do |service|
              next if CoffeeBrewery::Bundle::Brew::Services.run(service)

              opoo "Failed to restart #{service} service"
            end
          end
        end

        sig { params(entries: T::Array[CoffeeBrewery::Bundle::Dsl::Entry]).void }
        private_class_method def self.stop_services(entries)
          map_service_info(entries) do |_, info, _, _|
            next unless info["loaded"]

            # Try avoid services not started by `coffee bundle services`
            next if CoffeeBrewery::Services::System.launchctl? && info["registered"]

            if info["running"] && !CoffeeBrewery::Bundle::Brew::Services.stop(info["name"], keep: true)
              opoo "Failed to stop #{info["name"]} service"
            end
          end
        end
      end
    end
  end
end
