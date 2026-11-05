# typed: strict
# frozen_string_literal: true

module OS
  module Mac
    module SimulateSystem
      module ClassMethods
        sig { returns(T::Boolean) }
        def simulating_or_running_on_macos?
          return true if CoffeeBrewery::SimulateSystem.os.blank?

          [:macos, *MacOSVersion::SYMBOLS.keys].include?(CoffeeBrewery::SimulateSystem.os)
        end

        sig { returns(Symbol) }
        def current_os
          ::CoffeeBrewery::SimulateSystem.os || MacOS.version.to_sym
        end
      end
    end
  end
end

CoffeeBrewery::SimulateSystem.singleton_class.prepend(OS::Mac::SimulateSystem::ClassMethods)
