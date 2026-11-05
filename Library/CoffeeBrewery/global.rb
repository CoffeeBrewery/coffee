# typed: strict
# frozen_string_literal: true

require_relative "startup"

COFFEEBREWER_HELP_MESSAGE = T.let(ENV.fetch("COFFEEBREWER_HELP_MESSAGE").freeze, String)

COFFEEBREWER_API_DEFAULT_DOMAIN = T.let(ENV.fetch("COFFEEBREWER_API_DEFAULT_DOMAIN").freeze, String)
COFFEEBREWER_BOTTLE_DEFAULT_DOMAIN = T.let(ENV.fetch("COFFEEBREWER_BOTTLE_DEFAULT_DOMAIN").freeze, String)
COFFEEBREWER_BREW_DEFAULT_GIT_REMOTE = T.let(ENV.fetch("COFFEEBREWER_BREW_DEFAULT_GIT_REMOTE").freeze, String)
COFFEEBREWER_CORE_DEFAULT_GIT_REMOTE = T.let(ENV.fetch("COFFEEBREWER_CORE_DEFAULT_GIT_REMOTE").freeze, String)

COFFEEBREWER_DEFAULT_CACHE = T.let(ENV.fetch("COFFEEBREWER_DEFAULT_CACHE").freeze, String)
COFFEEBREWER_DEFAULT_LOGS = T.let(ENV.fetch("COFFEEBREWER_DEFAULT_LOGS").freeze, String)
COFFEEBREWER_DEFAULT_TEMP = T.let(ENV.fetch("COFFEEBREWER_DEFAULT_TEMP").freeze, String)
COFFEEBREWER_REQUIRED_RUBY_VERSION = T.let(ENV.fetch("COFFEEBREWER_REQUIRED_RUBY_VERSION").freeze, String)
COFFEEBREWER_VERSION = T.let(ENV.fetch("COFFEEBREWER_VERSION").freeze, String)

COFFEEBREWER_WWW = "https://coffee.sh"
COFFEEBREWER_API_WWW = "https://formulae.coffee.sh"
COFFEEBREWER_DOCS_WWW = "https://docs.coffee.sh"

COFFEEBREWER_SYSTEM = T.let(ENV.fetch("COFFEEBREWER_SYSTEM").freeze, String)
COFFEEBREWER_PROCESSOR = T.let(ENV.fetch("COFFEEBREWER_PROCESSOR").freeze, String)
COFFEEBREWER_PHYSICAL_PROCESSOR = T.let(ENV.fetch("COFFEEBREWER_PHYSICAL_PROCESSOR").freeze, String)

COFFEEBREWER_BREWED_CURL_PATH = Pathname.new(ENV.fetch("COFFEEBREWER_BREWED_CURL_PATH")).freeze
COFFEEBREWER_CURL_SUPPORTS_ETAGS = T.let(ENV["COFFEEBREWER_CURL_SUPPORTS_ETAGS"] == "1", T::Boolean)
COFFEEBREWER_USER_AGENT_CURL = T.let(ENV.fetch("COFFEEBREWER_USER_AGENT_CURL").freeze, String)
COFFEEBREWER_USER_AGENT_FAKE_SAFARI =
  # Don't update this beyond 10.15.7 until Safari actually updates their
  # user agent to be beyond 10.15.7 (not the case as-of macOS 26)
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " \
  "(KHTML, like Gecko) Version/27.0 Safari/605.1.15"
COFFEEBREWER_GITHUB_PACKAGES_AUTH = T.let(ENV.fetch("COFFEEBREWER_GITHUB_PACKAGES_AUTH", "").freeze, String)
COFFEEBREWER_DEFAULT_PREFIX = T.let(ENV.fetch("COFFEEBREWER_GENERIC_DEFAULT_PREFIX").freeze, String)

COFFEEBREWER_MACOS_ARM_DEFAULT_PREFIX = T.let(ENV.delete("COFFEEBREWER_MACOS_ARM_DEFAULT_PREFIX").freeze, T.nilable(String))
COFFEEBREWER_LINUX_DEFAULT_PREFIX = T.let(ENV.delete("COFFEEBREWER_LINUX_DEFAULT_PREFIX").freeze, T.nilable(String))

COFFEEBREWER_PREFIX_PLACEHOLDER = "$COFFEEBREWER_PREFIX"
COFFEEBREWER_CELLAR_PLACEHOLDER = "$COFFEEBREWER_CELLAR"
# Needs a leading slash to avoid `File.expand.path` complaining about non-absolute home.
COFFEEBREWER_HOME_PLACEHOLDER = "/$HOME"
COFFEEBREWER_CASK_APPDIR_PLACEHOLDER = "$APPDIR"

COFFEEBREWER_MACOS_NEWEST_UNSUPPORTED = T.let(ENV.fetch("COFFEEBREWER_MACOS_NEWEST_UNSUPPORTED").freeze, String)
COFFEEBREWER_MACOS_NEWEST_SUPPORTED = T.let(ENV.fetch("COFFEEBREWER_MACOS_NEWEST_SUPPORTED").freeze, String)
COFFEEBREWER_MACOS_OLDEST_SUPPORTED = T.let(ENV.fetch("COFFEEBREWER_MACOS_OLDEST_SUPPORTED").freeze, String)
COFFEEBREWER_MACOS_OLDEST_ALLOWED = T.let(ENV.fetch("COFFEEBREWER_MACOS_OLDEST_ALLOWED").freeze, String)

COFFEEBREWER_PULL_OR_COMMIT_URL_REGEX =
  %r[https://github\.com/([\w-]+)/([\w-]+)?/(?:pull/(\d+)|commit/[0-9a-fA-F]{4,40})]
COFFEEBREWER_BOTTLES_EXTNAME_REGEX = /\.([a-z0-9_]+)\.bottle\.(?:(\d+)\.)?tar\.gz$/

module CoffeeBrewery
  DEFAULT_PREFIX = T.let(ENV.fetch("COFFEEBREWER_DEFAULT_PREFIX").freeze, String)
  DEFAULT_REPOSITORY = T.let(ENV.fetch("COFFEEBREWER_DEFAULT_REPOSITORY").freeze, String)
  DEFAULT_CELLAR = T.let("#{DEFAULT_PREFIX}/Cellar".freeze, String)
  DEFAULT_MACOS_CELLAR = T.let("#{COFFEEBREWER_DEFAULT_PREFIX}/Cellar".freeze, String)
  DEFAULT_MACOS_ARM_CELLAR = T.let("#{COFFEEBREWER_MACOS_ARM_DEFAULT_PREFIX}/Cellar".freeze, String)
  DEFAULT_LINUX_CELLAR = T.let("#{COFFEEBREWER_LINUX_DEFAULT_PREFIX}/Cellar".freeze, String)

  # A pinned bottle built at one of these 64-byte prefixes can be patched for any shorter prefix.
  MACOS_ARM64_BOTTLE_PREFIX = T.let("/opt/homebrew/.coffee-padded-arm64".ljust(64, "_").freeze, String)
  LINUX_ARM64_BOTTLE_PREFIX = T.let("/home/linuxbrew/.linuxbrew/.coffee-padded-arm64".ljust(64, "_").freeze, String)
  LINUX_X86_64_BOTTLE_PREFIX = T.let("/home/linuxbrew/.linuxbrew/.coffee-padded-x86_64".ljust(64, "_").freeze, String)

  class << self
    sig { params(failed: T::Boolean).returns(T::Boolean) }
    attr_writer :failed

    sig { params(raise_deprecation_exceptions: T::Boolean).returns(T::Boolean) }
    attr_writer :raise_deprecation_exceptions

    sig { params(auditing: T::Boolean).returns(T::Boolean) }
    attr_writer :auditing

    # Check whether CoffeeBrewery is using the default prefix.
    #
    # @api internal
    sig { params(prefix: T.any(Pathname, String)).returns(T::Boolean) }
    def default_prefix?(prefix = COFFEEBREWER_PREFIX)
      prefix.to_s == DEFAULT_PREFIX
    end

    sig { returns(T::Boolean) }
    def failed?
      @failed ||= T.let(false, T.nilable(T::Boolean))
      @failed == true
    end

    sig { returns(Messages) }
    def messages
      @messages ||= T.let(Messages.new, T.nilable(Messages))
    end

    sig { returns(T::Boolean) }
    def raise_deprecation_exceptions?
      @raise_deprecation_exceptions = T.let(@raise_deprecation_exceptions, T.nilable(T::Boolean))
      @raise_deprecation_exceptions == true
    end

    sig { returns(T::Boolean) }
    def auditing?
      @auditing = T.let(@auditing, T.nilable(T::Boolean))
      @auditing == true
    end

    sig { returns(T::Boolean) }
    def running_as_root?
      @process_euid ||= T.let(Process.euid, T.nilable(Integer))
      @process_euid.zero?
    end

    sig { returns(Integer) }
    def owner_uid
      @owner_uid ||= T.let(COFFEEBREWER_BREW_FILE.stat.uid, T.nilable(Integer))
    end

    sig { returns(T::Boolean) }
    def running_as_root_but_not_owned_by_root?
      running_as_root? && !owner_uid.zero?
    end

    sig { returns(T::Boolean) }
    def auto_update_command?
      ENV.fetch("COFFEEBREWER_AUTO_UPDATE_COMMAND", false).present?
    end

    sig { returns(T.nilable(String)) }
    attr_reader :running_command

    sig { params(cmd: T.nilable(String)).void }
    def running_command=(cmd)
      @running_command = T.let(cmd, T.nilable(String))
      @running_command_with_args = T.let("#{cmd} #{ARGV.join(" ")}", T.nilable(String))
    end

    sig { returns String }
    def running_command_with_args
      "coffee #{@running_command_with_args}".strip
    end
  end
end

require "PATH"
ENV["COFFEEBREWER_PATH"] ||= ENV.fetch("PATH")
ORIGINAL_PATHS = T.let(PATH.new(ENV.fetch("COFFEEBREWER_PATH")).filter_map do |p|
  Pathname.new(p).expand_path
rescue
  nil
end.freeze, T::Array[Pathname])

require "extend/blank"
require "extend/kernel"
require "os"

require "extend/array"
require "cacheable"
require "extend/enumerable"
require "extend/string"
require "extend/pathname"

require "exceptions"

require "tap_constants"
require "official_taps"
