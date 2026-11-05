# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"
require "env_config"
require "utils/tty"

module CoffeeBrewery
  module Cmd
    class Developer < CoffeeBrewery::AbstractCommand
      class StateSubcommand < CoffeeBrewery::AbstractSubcommand
        subcommand_args default: true do
          usage_banner <<~EOS
            `coffee developer` [`state`]:
            Display the current state of CoffeeBrewery's developer mode.
          EOS
          named_args :none
        end

        sig { override.void }
        def run
          if CoffeeBrewery::EnvConfig.developer?
            puts "Developer mode is enabled because #{Tty.bold}COFFEEBREWER_DEVELOPER#{Tty.reset} is set."
          elsif CoffeeBrewery::EnvConfig.devcmdrun?
            puts "Developer mode is enabled because a developer command or `coffee developer on` was run."
          else
            puts "Developer mode is disabled."
          end

          if CoffeeBrewery::EnvConfig.developer? || CoffeeBrewery::EnvConfig.devcmdrun?
            if CoffeeBrewery::EnvConfig.update_to_tag?
              puts "However, `coffee update` will update to the latest stable tag because " \
                   "#{Tty.bold}COFFEEBREWER_UPDATE_TO_TAG#{Tty.reset} is set."
            else
              puts "`coffee update` will update to the latest commit on the `main` branch."
            end
          else
            puts "`coffee update` will update to the latest stable tag."
          end
        end
      end
    end
  end
end
