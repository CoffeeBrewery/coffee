# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "shell_command"

module CoffeeBrewery
  module DevCmd
    class Rubocop < AbstractCommand
      include ShellCommand

      cmd_args do
        description <<~EOS
          Installs, configures and runs CoffeeBrewery's `rubocop`.
        EOS
      end
    end
  end
end
