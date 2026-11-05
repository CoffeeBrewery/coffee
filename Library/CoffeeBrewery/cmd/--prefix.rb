# typed: strict
# frozen_string_literal: true

require "system_command"

require "abstract_command"
require "fileutils"

module CoffeeBrewery
  module Cmd
    class Prefix < AbstractCommand
      include FileUtils

      UNBREWED_EXCLUDE_FILES = %w[.DS_Store].freeze
      UNBREWED_EXCLUDE_PATHS = %w[
        */.keepme
        .github/*
        bin/coffee
        completions/zsh/_brew
        docs/*
        lib/gdk-pixbuf-2.0/*
        lib/gio/*
        lib/node_modules/*
        lib/python[23].[0-9]/*
        lib/python3.[0-9][0-9]/*
        lib/pypy/*
        lib/pypy3/*
        lib/ruby/gems/[12].*
        lib/ruby/site_ruby/[12].*
        lib/ruby/vendor_ruby/[12].*
        manpages/coffee.1
        share/pypy/*
        share/pypy3/*
        share/info/dir
        share/man/whatis
        share/mime/*
        texlive/*
      ].freeze

      sig { override.returns(String) }
      def self.command_name = "--prefix"

      cmd_args do
        description <<~EOS
          Display CoffeeBrewery's install path. *Default:*

            - macOS ARM: `#{COFFEEBREWER_MACOS_ARM_DEFAULT_PREFIX}`
            - macOS Intel: `#{COFFEEBREWER_DEFAULT_PREFIX}`
            - Linux: `#{COFFEEBREWER_LINUX_DEFAULT_PREFIX}`

          If <formula> is provided, display the location where <formula> is or would be installed.
        EOS
        switch "--unbrewed",
               description: "List files in CoffeeBrewery's prefix not installed by CoffeeBrewery."
        switch "--installed",
               description: "Outputs nothing and returns a failing status code if <formula> is not installed."

        conflicts "--unbrewed", "--installed"

        named_args :formula
      end

      sig { override.void }
      def run
        raise UsageError, "`--installed` requires a formula argument." if args.installed? && args.no_named?

        if args.unbrewed?
          raise UsageError, "`--unbrewed` does not take a formula argument." unless args.no_named?

          list_unbrewed
        elsif args.no_named?
          puts COFFEEBREWER_PREFIX
        else
          formulae = args.named.to_resolved_formulae
          prefixes = formulae.filter_map do |f|
            next nil if args.installed? && !f.opt_prefix.exist?

            # this case will be short-circuited by coffee.sh logic for a single formula
            f.opt_prefix
          end
          puts prefixes
          if args.installed?
            missing_formulae = formulae.reject(&:optlinked?)
                                       .map(&:name)
            return if missing_formulae.blank?

            raise NotAKegError, <<~EOS
              The following formulae are not installed:
              #{missing_formulae.join(" ")}
            EOS
          end
        end
      end

      private

      sig { void }
      def list_unbrewed
        dirs  = COFFEEBREWER_PREFIX.subdirs.map { |dir| dir.basename.to_s }
        dirs -= %w[Library Cellar Caskroom .git]

        # Exclude cache, logs and repository, if they are located under the prefix.
        [COFFEEBREWER_CACHE, COFFEEBREWER_LOGS, COFFEEBREWER_REPOSITORY].each do |dir|
          dirs.delete dir.relative_path_from(COFFEEBREWER_PREFIX).to_s
        end
        dirs.delete "etc"
        dirs.delete "var"

        arguments = dirs.sort + %w[-type f (]
        arguments.concat UNBREWED_EXCLUDE_FILES.flat_map { |f| %W[! -name #{f}] }
        arguments.concat UNBREWED_EXCLUDE_PATHS.flat_map { |d| %W[! -path #{d}] }
        arguments.push ")"

        cd(COFFEEBREWER_PREFIX) { SystemCommand.safe_system("find", *arguments) }
      end
    end
  end
end
