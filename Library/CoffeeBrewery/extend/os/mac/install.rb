# typed: strict
# frozen_string_literal: true

require "utils/output"

module OS
  module Mac
    module Install
      module ClassMethods
        include ::Utils::Output::Mixin

        sig { void }
        def check_prefix
          if (::Hardware::CPU.intel? || ::Hardware::CPU.in_rosetta2?) &&
             COFFEEBREWER_PREFIX.to_s == COFFEEBREWER_MACOS_ARM_DEFAULT_PREFIX
            if ::Hardware::CPU.in_rosetta2?
              odie <<~EOS
                Cannot install under Rosetta 2 in ARM default prefix (#{COFFEEBREWER_PREFIX})!
                To rerun under ARM use:
                    arch -arm64 coffee install ...
                To install under x86_64, install CoffeeBrewery into #{COFFEEBREWER_DEFAULT_PREFIX}.
              EOS
            else
              odie "Cannot install on Intel processor in ARM default prefix (#{COFFEEBREWER_PREFIX})!"
            end
          elsif ::Hardware::CPU.arm? && COFFEEBREWER_PREFIX.to_s == COFFEEBREWER_DEFAULT_PREFIX
            odie <<~EOS
              Cannot install in CoffeeBrewery on ARM processor in Intel default prefix (#{COFFEEBREWER_PREFIX})!
              Please create a new installation in #{COFFEEBREWER_MACOS_ARM_DEFAULT_PREFIX} using one of the
              "Alternative Installs" from:
                #{Formatter.url("https://docs.coffee.sh/Installation")}
              You can migrate your previously installed formula list with:
                coffee bundle dump
            EOS
          end
        end
      end
    end
  end
end

CoffeeBrewery::Install.singleton_class.prepend(OS::Mac::Install::ClassMethods)
