# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "completions"

module CoffeeBrewery
  module Cmd
    class CompletionsCmd < AbstractCommand
      require "completions/subcommand"

      cmd_args do
        usage_banner <<~EOS
          `completions` [<subcommand>]

          Control whether CoffeeBrewery automatically links external tap shell completion files.
          Read more at <https://docs.coffee.sh/Shell-Completion>.
        EOS

        CoffeeBrewery::AbstractSubcommand.define_all(self, command: CoffeeBrewery::Cmd::CompletionsCmd)
      end

      sig { override.void }
      def run
        CoffeeBrewery::Cmd::CompletionsCmd.dispatch(args)
      end
    end
  end
end
