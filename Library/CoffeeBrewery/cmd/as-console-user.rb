# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "shell_command"

module CoffeeBrewery
  module Cmd
    class AsConsoleUser < AbstractCommand
      include ShellCommand

      cmd_args do
        usage_banner <<~EOS
          `as-console-user` <command> [<args> ...]

          Run a CoffeeBrewery command as the user logged in to the macOS desktop.

          Use this from administrative scripts when the desktop user manages
          CoffeeBrewery, for example `coffee as-console-user install --yes` <formula>.
          Fails if no supported desktop user is logged in.

          Uses the user's home and a clean environment, then loads `coffee.env` for
          that account. Uses `sudo` when enabled and available; root can also switch
          users when `sudo` is disabled or unavailable.

          Use `as-coffee-user` to select the installation's owner on macOS or Linux,
          including when no user is logged in.
        EOS

        named_args min: 1
      end
    end
  end
end
