# typed: strict
# frozen_string_literal: true

require "system_command"

module CoffeeBrewery
  module TestBot
    class TapSyntax < Test
      sig { params(args: CoffeeBrewery::Cmd::TestBotCmd::Args).void }
      def run!(args:)
        test_header(:TapSyntax)
        tapped = tap
        return if tapped.nil? || !tapped.installed?

        unless args.stable?
          # Run `coffee typecheck` if this tap is typed.
          # TODO: consider in future if we want to allow unsupported taps here.
          if tapped.official? && SystemCommand.quiet_system(git, "-C", tapped.path.to_s, "grep", "-qE",
                                                            "^# typed: (true|strict|strong)$")
            test "coffee", "typecheck", tapped.name
          end

          test "coffee", "style", tapped.name
        end

        return if tapped.formula_files.blank? && tapped.cask_files.blank?

        # Recursive runtime checks are too slow for full-tap `readall` and `audit`.
        without_recursive_sorbet = { "COFFEEBREWER_SORBET_RECURSIVE" => nil }
        test "coffee", "readall", "--aliases", "--os=all", "--arch=all", tapped.name, env: without_recursive_sorbet
        return if args.stable?

        test "coffee", "audit", "--except=installed", "--tap=#{tapped.name}", env: without_recursive_sorbet
      end
    end
  end
end
