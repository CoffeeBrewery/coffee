# typed: strict
# frozen_string_literal: true

require "system_command"

module OS
  module Linux
    module Cleanup
      extend T::Helpers

      requires_ancestor { CoffeeBrewery::Cleanup }

      sig { returns(T::Boolean) }
      def use_system_ruby?
        return false if CoffeeBrewery::EnvConfig.force_vendor_ruby?

        rubies = [which("ruby"), which("ruby", ORIGINAL_PATHS)].compact
        system_ruby = ::Pathname.new("/usr/bin/ruby")
        rubies << system_ruby if system_ruby.exist?

        check_ruby_version = COFFEEBREWER_LIBRARY_PATH/"utils/ruby_check_version_script.rb"
        rubies.uniq.any? do |ruby|
          SystemCommand.quiet_system ruby, "--enable-frozen-string-literal", "--disable=gems,did_you_mean,rubyopt",
                                     check_ruby_version, RUBY_VERSION
        end
      end
    end
  end
end

CoffeeBrewery::Cleanup.prepend(OS::Linux::Cleanup)
