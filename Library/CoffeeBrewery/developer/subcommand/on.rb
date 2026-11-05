# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"
require "env_config"
require "settings"
require "utils/tty"

module CoffeeBrewery
  module Cmd
    class Developer < CoffeeBrewery::AbstractCommand
      class OnSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args do
          usage_banner <<~EOS
            `coffee developer on`:
            Turn CoffeeBrewery's developer mode on.
          EOS
          named_args :none
        end

        sig { override.void }
        def run
          CoffeeBrewery::Settings.write "devcmdrun", true
          return unless CoffeeBrewery::EnvConfig.update_to_tag?

          puts "To fully enable developer mode, you must unset #{Tty.bold}COFFEEBREWER_UPDATE_TO_TAG#{Tty.reset}."
        end
      end
    end
  end
end
