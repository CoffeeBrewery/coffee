# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"
require "env_config"
require "settings"
require "utils/tty"

module CoffeeBrewery
  module Cmd
    class Developer < CoffeeBrewery::AbstractCommand
      class OffSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args do
          usage_banner <<~EOS
            `coffee developer off`:
            Turn CoffeeBrewery's developer mode off.
          EOS
          named_args :none
        end

        sig { override.void }
        def run
          CoffeeBrewery::Settings.delete "devcmdrun"
          return unless CoffeeBrewery::EnvConfig.developer?

          puts "To fully disable developer mode, you must unset #{Tty.bold}COFFEEBREWER_DEVELOPER#{Tty.reset}."
        end
      end
    end
  end
end
