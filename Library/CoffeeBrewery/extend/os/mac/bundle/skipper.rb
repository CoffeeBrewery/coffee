# typed: strict
# frozen_string_literal: true

module OS
  module Mac
    module Bundle
      module Skipper
        module ClassMethods
          sig { params(entry: CoffeeBrewery::Bundle::Dsl::Entry).returns(T.nilable(String)) }
          def unsupported_reason(entry)
            case entry.type
            when :winget then "requires WSL"
            when :flatpak then "unsupported on macOS"
            else super
            end
          end
        end
      end
    end
  end
end

CoffeeBrewery::Bundle::Skipper.singleton_class.prepend(OS::Mac::Bundle::Skipper::ClassMethods)
