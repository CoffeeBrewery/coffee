# typed: true
# frozen_string_literal: true

module CoffeeBrewery
  module Diagnostic
    class Checks
      def check_integration_test
        Finding.new("This is an integration test") if ENV["COFFEEBREWER_INTEGRATION_TEST"]
      end
    end
  end

  def exec(*args)
    if ENV["COFFEEBREWER_TESTS_COVERAGE"] && ENV["COFFEEBREWER_INTEGRATION_TEST"]
      # Ensure we get coverage results before replacing the current process.
      CoffeeBrewery::TestIntegrationCoverage.dump!
    end
    Kernel.exec(*args)
  end
end
