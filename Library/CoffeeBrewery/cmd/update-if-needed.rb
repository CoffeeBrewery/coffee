# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "shell_command"

module CoffeeBrewery
  module Cmd
    class UpdateIfNeeded < AbstractCommand
      include ShellCommand

      cmd_args do
        description <<~EOS
          Runs `coffee update --auto-update` only if needed.
          This is a good replacement for `coffee update` in scripts where you want
          the no-op case to be both possible and really fast.
        EOS

        named_args :none
      end
    end
  end
end
