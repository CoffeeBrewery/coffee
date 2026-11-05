# typed: strict
# frozen_string_literal: true

require "system_command"

require "abstract_subcommand"
require "cli/parser"
require "services/cli"
require "services/formulae"
require "services/system"
require "utils/output"

Dir["#{__dir__}/subcommand/*.rb"].each do |subcommand|
  require "services/subcommand/#{File.basename(subcommand, ".rb")}"
end

module CoffeeBrewery
  module Cmd
    class Services < CoffeeBrewery::AbstractCommand
      extend Utils::Output::Mixin

      class << self
        sig { params(args: T.untyped).void }
        def dispatch(args)
          # pbpaste's exit status is a proxy for detecting the use of reattach-to-user-namespace
          if ENV.fetch("COFFEEBREWER_TMUX",
                       nil) && File.exist?("/usr/bin/pbpaste") && !SystemCommand.quiet_system("/usr/bin/pbpaste")
            raise UsageError,
                  "`coffee services` cannot run under tmux!"
          end

          # Keep this after the .parse to keep --help fast.
          require "utils"

          if !CoffeeBrewery::Services::System.launchctl? && !CoffeeBrewery::Services::System.systemctl?
            raise UsageError, CoffeeBrewery::Services::System::MISSING_DAEMON_MANAGER_EXCEPTION_MESSAGE
          end

          if (sudo_service_user = args.sudo_service_user)
            unless CoffeeBrewery::Services::System.root?
              raise UsageError,
                    "`coffee services --sudo-service-user` is supported only when running as root!"
            end

            unless CoffeeBrewery::Services::System.launchctl?
              raise UsageError,
                    "`coffee services --sudo-service-user` is currently supported only on macOS " \
                    "(but we'd love a PR to add Linux support)!"
            end

            CoffeeBrewery::Services::Cli.sudo_service_user = sudo_service_user
          end

          subcommand = args.subcommand
          formulae = args.named

          opoo "The `--all` argument overrides provided formula argument!" if formulae.present? && args.all?

          targets = targets(args, subcommand:, formulae:)

          # Exit successfully if --all was used but there is nothing to do
          return if args.all? && targets.empty?

          if CoffeeBrewery::Services::System.systemctl?
            ENV["DBUS_SESSION_BUS_ADDRESS"] = ENV.fetch("COFFEEBREWER_DBUS_SESSION_BUS_ADDRESS", nil)
            ENV["XDG_RUNTIME_DIR"] = ENV.fetch("COFFEEBREWER_XDG_RUNTIME_DIR", nil)
          end

          subcommand_class = CoffeeBrewery::AbstractSubcommand.subcommands_for(CoffeeBrewery::Cmd::Services).find do |candidate|
            candidate.subcommand_name == subcommand
          end
          raise UsageError, "Unknown `coffee services` subcommand: #{subcommand}" if subcommand_class.nil?

          subcommand_class.new(args, targets:).run
        end

        sig {
          params(args: T.untyped, subcommand: String,
                 formulae: T::Array[String]).returns(T::Array[CoffeeBrewery::Services::FormulaWrapper])
        }
        def targets(args, subcommand:, formulae:)
          if args.all?
            if subcommand == "start"
              CoffeeBrewery::Services::Formulae.available_services(
                loaded:    false,
                skip_root: !CoffeeBrewery::Services::System.root?,
              )
            elsif subcommand == "stop"
              CoffeeBrewery::Services::Formulae.available_services(
                loaded:    true,
                skip_root: !CoffeeBrewery::Services::System.root?,
              )
            else
              CoffeeBrewery::Services::Formulae.available_services
            end
          elsif formulae.present?
            formulae.map { |formula| CoffeeBrewery::Services::FormulaWrapper.new(Formulary.factory(formula)) }
          else
            []
          end
        end
      end
    end
  end
end
