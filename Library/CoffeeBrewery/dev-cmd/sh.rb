# typed: strict
# frozen_string_literal: true

require "extend/ENV/super"
require "system_command"

require "abstract_command"
require "extend/ENV"
require "formula"
require "utils/gem_setup"
require "utils/shell"

module CoffeeBrewery
  module DevCmd
    class Sh < AbstractCommand
      cmd_args do
        description <<~EOS
          Enter an interactive shell for CoffeeBrewery's build environment. Use years-battle-hardened
          build logic to help your `./configure && make && make install`
          and even your `gem install` succeed. Especially handy if you run CoffeeBrewery
          in an Xcode-only configuration since it adds tools like `make` to your `$PATH`
          which build systems would not find otherwise.

          With `--ruby`, enter an interactive shell for CoffeeBrewery's Ruby environment.
          This sets up the correct Ruby paths, `$GEM_HOME` and bundle
          configuration used by CoffeeBrewery's development tools.
          The environment includes gems from the installed groups,
          making tools like RuboCop, Sorbet and RSpec available via `bundle exec`.
        EOS
        switch "-r", "--ruby",
               description: "Set up CoffeeBrewery's Ruby environment."
        flag   "--env=",
               description: "Use the standard `$PATH` instead of superenv's when `std` is passed."
        flag   "-c=", "--cmd=",
               description: "Execute commands in a non-interactive shell."

        conflicts "--ruby", "--env="

        named_args :file, max: 1
      end

      sig { override.void }
      def run
        prompt, notice = if args.ruby?
          setup_ruby_environment!
        else
          setup_build_environment!
        end

        preferred_path = Utils::Shell.preferred_path(default: "/bin/bash")

        if args.cmd.present?
          SystemCommand.safe_system(preferred_path, "-c", args.cmd)
        elsif args.named.present?
          SystemCommand.safe_system(preferred_path, args.named.first)
        else
          system Utils::Shell.shell_with_prompt(prompt, preferred_path:, notice:)
        end
      end

      private

      sig { returns([String, T.nilable(String)]) }
      def setup_ruby_environment!
        Utils::GemSetup.install_bundler_gems!(setup_path: true)

        notice = unless CoffeeBrewery::EnvConfig.no_env_hints?
          <<~EOS
            Your shell has been configured to use CoffeeBrewery's Ruby environment.
            This includes the correct Ruby version, GEM_HOME, and bundle configuration.
            Tools like RuboCop, Sorbet, and RSpec are available via `bundle exec`.
            Hide these hints with `COFFEEBREWER_NO_ENV_HINTS=1` (see `man coffee`).
            When done, type `exit`.
          EOS
        end

        ["coffee ruby", notice]
      end

      sig { returns([String, T.nilable(String)]) }
      def setup_build_environment!
        ENV.activate_extensions!(env: args.env)

        if Superenv.enabled_for?(args.env)
          ENV.deps = Formula.installed.select do |f|
            f.keg_only? && f.opt_prefix.directory?
          end
        end
        ENV.setup_build_environment
        if Superenv.enabled_for?(args.env)
          # superenv stopped adding coffee's bin but generally users will want it
          ENV["PATH"] = PATH.new(ENV.fetch("PATH")).insert(1, COFFEEBREWER_PREFIX/"bin").to_s
        end

        ENV["VERBOSE"] = "1" if args.verbose?

        notice = unless CoffeeBrewery::EnvConfig.no_env_hints?
          <<~EOS
            Your shell has been configured to use CoffeeBrewery's build environment;
            this should help you build stuff. Notably though, the system versions of
            gem and pip will ignore our configuration and insist on using the
            environment they were built under (mostly). Sadly, scons will also
            ignore our configuration.
            Hide these hints with `COFFEEBREWER_NO_ENV_HINTS=1` (see `man coffee`).
            When done, type `exit`.
          EOS
        end

        ["coffee", notice]
      end
    end
  end
end
