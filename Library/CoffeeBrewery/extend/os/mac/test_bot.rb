# typed: strict
# frozen_string_literal: true

module OS
  module Mac
    module TestBot
      module ClassMethods
        extend T::Helpers

        requires_ancestor { T.class_of(::CoffeeBrewery::TestBot) }

        sig { returns(String) }
        def runner_os_title
          title = "macOS #{MacOS.version.pretty_name} (#{MacOS.version})"
          title << " on Apple Silicon" if ::Hardware::CPU.arm?

          title
        end
      end

      module TestFormulae
        extend T::Helpers

        requires_ancestor { ::CoffeeBrewery::TestBot::TestFormulae }

        sig { returns(String) }
        def previous_run_artifact_specifier
          "{macos-#{MacOS.version},#{MacOS.version}-#{::Hardware::CPU.arch}}"
        end
      end

      module Formulae
        extend T::Helpers

        requires_ancestor { ::CoffeeBrewery::TestBot::Formulae }

        sig { params(args: ::CoffeeBrewery::Cmd::TestBotCmd::Args).void }
        def setup_bottle_sudo_purge!(args:)
          # This is needed where sparse files may be handled (bsdtar >=3.0).
          # We use gnu-tar with sparse files disabled when --only-json-tab is passed.
          ENV["COFFEEBREWER_BOTTLE_SUDO_PURGE"] = "1" unless args.only_json_tab?
        end

        sig { returns(T::Boolean) }
        def integration_test_portable_ruby?
          # tests fail on macOS when currently running portable Ruby is replaced using same path
          portable_ruby_version = (COFFEEBREWER_LIBRARY_PATH/"vendor/portable-ruby-version").read.chomp
          portable_ruby_version != ::Formula["portable-ruby"].pkg_version.to_s
        end
      end

      module CleanupBefore
        extend T::Helpers

        requires_ancestor { ::CoffeeBrewery::TestBot::CleanupBefore }

        sig { void }
        def cleanup_github_actions_hosted_runner
          delete_or_move COFFEEBREWER_CELLAR.glob("*")
          delete_or_move COFFEEBREWER_CASKROOM.glob("*")

          delete_or_move %w[
            Mono.framework
            PluginManager.framework
            Python.framework
            R.framework
            Xamarin.Android.framework
            Xamarin.Mac.framework
            Xamarin.iOS.framework
          ].map { |framework| ::Pathname.new("/Library/Frameworks")/framework }, sudo: true
        end
      end
    end
  end
end

CoffeeBrewery::TestBot.singleton_class.prepend(OS::Mac::TestBot::ClassMethods)
CoffeeBrewery::TestBot::TestFormulae.prepend(OS::Mac::TestBot::TestFormulae)
CoffeeBrewery::TestBot::Formulae.prepend(OS::Mac::TestBot::Formulae)
CoffeeBrewery::TestBot::CleanupBefore.prepend(OS::Mac::TestBot::CleanupBefore)
