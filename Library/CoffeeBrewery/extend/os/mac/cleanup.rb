# typed: strict
# frozen_string_literal: true

module OS
  module Mac
    module Cleanup
      sig { returns(T::Boolean) }
      def use_system_ruby?
        return false if CoffeeBrewery::EnvConfig.force_vendor_ruby?

        ::CoffeeBrewery::EnvConfig.developer? && ENV["COFFEEBREWER_USE_RUBY_FROM_PATH"].present?
      end
    end
  end
end

CoffeeBrewery::Cleanup.prepend(OS::Mac::Cleanup)
