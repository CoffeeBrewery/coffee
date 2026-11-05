# typed: strict
# frozen_string_literal: true

require "system_command"

module CoffeeBrewery
  module TestBot
    class CleanupAfter < TestCleanup
      sig { params(args: CoffeeBrewery::Cmd::TestBotCmd::Args).void }
      def run!(args:)
        if ENV["COFFEEBREWER_GITHUB_ACTIONS"].present? && ENV["GITHUB_ACTIONS_COFFEEBREWER_SELF_HOSTED"].blank? &&
           # don't need to do post-build cleanup unless testing test-bot itself.
           !args.test_default_formula?
          return
        end

        test_header(:CleanupAfter)

        pkill_if_needed

        cleanup_shared

        # Keep all "coffee" invocations after cleanup_shared
        # (which cleans up CoffeeBrewery/coffee)
        return unless local?(args)

        FileUtils.rm_rf ENV.fetch("COFFEEBREWER_HOME")
        FileUtils.rm_rf ENV.fetch("COFFEEBREWER_LOGS")
      end

      private

      sig { void }
      def pkill_if_needed
        pgrep = ["pgrep", "-f", COFFEEBREWER_CELLAR.to_s]

        return unless SystemCommand.quiet_system(*pgrep)

        test "pkill", "-f", COFFEEBREWER_CELLAR.to_s

        return unless SystemCommand.quiet_system(*pgrep)

        sleep 1
        test "pkill", "-9", "-f", COFFEEBREWER_CELLAR.to_s if system(*pgrep)
      end
    end
  end
end
