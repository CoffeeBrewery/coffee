# typed: strict
# frozen_string_literal: true

require "trust"

module CoffeeBrewery
  module TestBot
    class CleanupBefore < TestCleanup
      sig { params(args: CoffeeBrewery::Cmd::TestBotCmd::Args).void }
      def run!(args:)
        test_header(:CleanupBefore)

        if tap.to_s != CoreTap.instance.name && CoreTap.instance.installed?
          reset_if_needed(CoreTap.instance.path.to_s)
        end

        Pathname.glob("*.bottle*.*").each(&:unlink)

        if ENV["COFFEEBREWER_GITHUB_ACTIONS"] && !ENV["GITHUB_ACTIONS_COFFEEBREWER_SELF_HOSTED"]
          # minimally fix coffee doctor failures (a full clean takes ~5m)
          cleanup_github_actions_hosted_runner
          untap_untrusted_taps
          test "coffee", "cleanup", "--prune-prefix"
        end

        # Keep all "coffee" invocations after cleanup_shared
        # (which cleans up CoffeeBrewery/coffee)
        cleanup_shared
        CoffeeBrewery::TestBot.trust_test_tap!(tap)
      end

      sig { void }
      def cleanup_github_actions_hosted_runner; end

      sig { void }
      def untap_untrusted_taps
        taps_to_untap = CoffeeBrewery::Trust.untrusted_taps.reject { |untrusted_tap| untrusted_tap.name == tap&.name }
        return if taps_to_untap.empty?

        test "coffee", "untap", "--force", *taps_to_untap.map(&:name)
      end
    end
  end
end
