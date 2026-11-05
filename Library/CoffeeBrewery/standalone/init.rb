# typed: true
# frozen_string_literal: true

# This file is included before any other files.
# It intentionally has typing disabled and uses `CoffeeBrewery::FastBootRequire`
# or `require_relative` to load all files
# (except "rbconfig" which is needed by `CoffeeBrewery::FastBootRequire`)

required_ruby_major, required_ruby_minor, = ENV.fetch("COFFEEBREWER_REQUIRED_RUBY_VERSION", "").split(".").map(&:to_i)
gems_vendored = if required_ruby_minor.nil?
  # We're likely here if running RuboCop etc, so just assume we don't need to install gems as we likely already have
  true
else
  ruby_major, ruby_minor, = RUBY_VERSION.split(".").map(&:to_i)
  raise "Could not parse Ruby requirements" if !ruby_major || !ruby_minor || !required_ruby_major

  if ruby_major < required_ruby_major || (ruby_major == required_ruby_major && ruby_minor < required_ruby_minor)
    raise "CoffeeBrewery must be run under Ruby #{required_ruby_major}.#{required_ruby_minor}! " \
          "You're running #{RUBY_VERSION}."
  end

  # This list should match .gitignore
  vendored_versions = ["4.0"].freeze
  vendored_versions.include?("#{ruby_major}.#{ruby_minor}")
end.freeze

if ENV["COFFEEBREWER_DEVELOPER"]
  Warning.categories.each do |category|
    Warning[category] = true
  end
end

# Setup CoffeeBrewery::FastBootRequire for faster boot requires.
# Inspired by https://github.com/Shopify/bootsnap/wiki/Bootlib::Require
require "rbconfig"

module CoffeeBrewery
  module FastBootRequire
    ARCHDIR    = RbConfig::CONFIG["archdir"].freeze
    RUBYLIBDIR = RbConfig::CONFIG["rubylibdir"].freeze

    def self.from_archdir(feature)
      require(File.join(ARCHDIR, feature.to_s))
    end

    def self.from_rubylibdir(feature)
      require(File.join(RUBYLIBDIR, "#{feature}.rb"))
    end
  end
end

# We trust base Ruby to provide what we need.
# Don't look into the user-installed sitedir, which may contain older versions of RubyGems.
$LOAD_PATH.reject! { |path| path.start_with?(RbConfig::CONFIG["sitedir"]) }

CoffeeBrewery::FastBootRequire.from_rubylibdir("pathname")
dir = __dir__ || raise("__dir__ is not defined")
COFFEEBREWER_LIBRARY_PATH = Pathname(dir).parent.realpath.freeze
COFFEEBREWER_USING_PORTABLE_RUBY = RbConfig.ruby.include?("/vendor/portable-ruby/").freeze

COFFEEBREWER_BUNDLER_VERSION = ENV.fetch("COFFEEBREWER_BUNDLER_VERSION").freeze

require_relative "../utils/gem_setup"
Utils::GemSetup.setup_gem_environment!(setup_path: false)

# Install gems for Rubies we don't vendor for.
if !gems_vendored && !ENV["COFFEEBREWER_SKIP_INITIAL_GEM_INSTALL"]
  Utils::GemSetup.install_bundler_gems!(setup_path: false)
  ENV["COFFEEBREWER_SKIP_INITIAL_GEM_INSTALL"] = "1"
end

unless $LOAD_PATH.include?(COFFEEBREWER_LIBRARY_PATH.to_s)
  # Insert the path after any existing CoffeeBrewery paths (e.g. those inserted by tests and parent processes)
  last_homebrew_path_idx = $LOAD_PATH.rindex do |path|
    path.start_with?(COFFEEBREWER_LIBRARY_PATH.to_s) && !path.include?("vendor/portable-ruby")
  end || -1
  $LOAD_PATH.insert(last_homebrew_path_idx + 1, COFFEEBREWER_LIBRARY_PATH.to_s)
end
require_relative "../vendor/bundle/bundler/setup"
CoffeeBrewery::FastBootRequire.from_archdir("portable_ruby_gems") if COFFEEBREWER_USING_PORTABLE_RUBY
$LOAD_PATH.unshift "#{COFFEEBREWER_LIBRARY_PATH}/vendor/bundle/#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/" \
                   "bundler-#{COFFEEBREWER_BUNDLER_VERSION}/lib"
$LOAD_PATH.uniq!

# These warnings are nice but often flag problems that are not even our responsibly,
# including in some cases from other Ruby standard library gems.
# We strictly only allow one version of Ruby at a time so future compatibility
# doesn't need to be handled ahead of time.
if defined?(Gem::BUNDLED_GEMS)
  [Kernel.singleton_class, Kernel].each do |kernel_class|
    next unless kernel_class.respond_to?(:no_warning_require, true)

    kernel_class.alias_method :require, :no_warning_require
  end
end
