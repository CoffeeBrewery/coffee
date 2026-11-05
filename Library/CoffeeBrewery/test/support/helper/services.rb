# typed: strict
# frozen_string_literal: true

require "services/system"
require "services/system/systemctl"

module Test
  module Helper
    # Helpers for the `CoffeeBrewery::Services` specs.
    module Services
      # `CoffeeBrewery::Services::System.launchctl` and
      # `CoffeeBrewery::Services::System::Systemctl.executable` memoize their lookups
      # for the life of the process. Examples that manipulate `PATH` to probe
      # discovery must clear those caches so they don't leak across examples.
      sig { void }
      def reset_services_memoization!
        CoffeeBrewery::Services::System.launchctl = nil
        CoffeeBrewery::Services::System::Systemctl.executable = nil
      end
    end
  end
end
