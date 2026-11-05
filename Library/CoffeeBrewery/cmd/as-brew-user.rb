# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "shell_command"

module CoffeeBrewery
  module Cmd
    # Dispatches commands as the CoffeeBrewery prefix owner.
    class AsBrewUser < AbstractCommand
      include ShellCommand

      cmd_args do
        usage_banner <<~EOS
          `as-coffee-user` <command> [<args> ...]

          Run a CoffeeBrewery command as the owner of `COFFEEBREWER_PREFIX` on macOS or Linux.

          Use this in administrative scripts and scheduled jobs to manage an
          existing installation, including when no user is logged in.

          Uses the owner's home and a clean environment, then loads `coffee.env`
          for that account. Changing users requires permission to use `sudo` or an
          already-root process; running as the owner does not. When `sudo` is
          disabled or unavailable, root can switch users directly.

          Use `coffee as-coffee-user install --yes` <formula> for unattended installation.
          On macOS, use `as-console-user` to select the active desktop user instead.
        EOS

        named_args min: 1
      end
    end
  end
end
