# typed: strict
# frozen_string_literal: true

module CoffeeBrewery
  module TestBot
    class Setup < Test
      sig { params(args: CoffeeBrewery::Cmd::TestBotCmd::Args).returns(Step) }
      def run!(args:)
        test_header(:Setup)

        test "coffee", "install-bundler-gems", "--add-groups=ast,audit,bottle,formula_test,livecheck,style"

        # Always output `coffee config` output even when it doesn't fail.
        test "coffee", "config", verbose: true

        ignore_doctor_failure = ENV["COFFEEBREWER_TEST_BOT_IGNORE_DOCTOR_FAILURE"].present?
        if ENV["COFFEEBREWER_TEST_BOT_VERBOSE_DOCTOR"]
          test "coffee", "doctor", "--debug", verbose: true, ignore_failures: ignore_doctor_failure
        else
          test "coffee", "doctor", ignore_failures: ignore_doctor_failure
        end
      end
    end
  end
end
