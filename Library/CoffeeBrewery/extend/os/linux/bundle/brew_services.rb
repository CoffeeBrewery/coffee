# typed: strict
# frozen_string_literal: true

module OS
  module Linux
    module Bundle
      module BrewServices
        module ClassMethods
          sig { returns(T::Array[String]) }
          def started_services_without_daemon_manager
            CoffeeBrewery::Bundle::Brew::Services.opoo "Skipping `coffee services list` due to missing systemctl"
            []
          end
        end
      end
    end
  end
end

CoffeeBrewery::Bundle::Brew::Services.singleton_class.prepend(OS::Linux::Bundle::BrewServices::ClassMethods)
