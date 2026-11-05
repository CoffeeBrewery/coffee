# typed: true
# frozen_string_literal: true

raise "COFFEEBREWER_BREW_FILE was not exported! Please call bin/coffee directly!" unless ENV["COFFEEBREWER_BREW_FILE"]

COFFEEBREWER_BREW_FILE = Pathname.new(ENV.fetch("COFFEEBREWER_BREW_FILE")).freeze

TEST_TMPDIR = ENV.fetch("COFFEEBREWER_TEST_TMPDIR") do |k|
  dir = Dir.mktmpdir("homebrew-tests-", ENV.fetch("COFFEEBREWER_TEMP"))
  at_exit do
    # Child processes inherit this at_exit handler, but we don't want them
    # to clean TEST_TMPDIR up prematurely (i.e. when they exit early for a test).
    FileUtils.remove_entry(dir) unless ENV["COFFEEBREWER_TEST_NO_EXIT_CLEANUP"]
  end
  ENV[k] = dir
end.freeze

# Paths pointing into the CoffeeBrewery code base that persist across test runs
COFFEEBREWER_SHIMS_PATH = (COFFEEBREWER_LIBRARY_PATH/"shims").freeze

# Where external data that has been incorporated into CoffeeBrewery is stored
COFFEEBREWER_DATA_PATH = (COFFEEBREWER_LIBRARY_PATH/"data").freeze

# Paths redirected to a temporary directory and wiped at the end of the test run
COFFEEBREWER_PREFIX        = (Pathname(TEST_TMPDIR)/"prefix").freeze
COFFEEBREWER_ALIASES       = (Pathname(TEST_TMPDIR)/"aliases").freeze
COFFEEBREWER_REPOSITORY    = COFFEEBREWER_PREFIX.dup.freeze
COFFEEBREWER_LIBRARY       = (COFFEEBREWER_REPOSITORY/"Library").freeze
COFFEEBREWER_CACHE         = (COFFEEBREWER_PREFIX.parent/"cache").freeze
COFFEEBREWER_CACHE_FORMULA = (COFFEEBREWER_PREFIX.parent/"formula_cache").freeze
COFFEEBREWER_LINKED_KEGS   = (COFFEEBREWER_PREFIX/"var/homebrew/linked").freeze
COFFEEBREWER_PINNED_KEGS   = (COFFEEBREWER_PREFIX/"var/homebrew/pinned").freeze
COFFEEBREWER_PINNED_CASKS  = (COFFEEBREWER_PREFIX/"var/homebrew/pinned_casks").freeze
COFFEEBREWER_LOCKS         = (COFFEEBREWER_PREFIX/"var/homebrew/locks").freeze
COFFEEBREWER_TEMP_CELLAR   = (COFFEEBREWER_PREFIX/"var/homebrew/tmp/.cellar").freeze
COFFEEBREWER_TEMP_CASKROOM = (COFFEEBREWER_PREFIX/"var/homebrew/tmp/.caskroom").freeze
COFFEEBREWER_CELLAR        = (COFFEEBREWER_PREFIX/"Cellar").freeze
COFFEEBREWER_LOGS          = (COFFEEBREWER_PREFIX.parent/"logs").freeze
COFFEEBREWER_TEMP          = Pathname(
  # Match Sandbox::INHERITANCE_FD before sandbox.rb can be loaded during startup.
  begin
    ENV.fetch("COFFEEBREWER_TEMP") if File.identical?(IO.new(198, autoclose: false),
                                                  COFFEEBREWER_LIBRARY_PATH/"sandbox.rb")
  rescue Errno::EBADF
    nil
  end || (COFFEEBREWER_PREFIX.parent/"temp"),
).freeze
COFFEEBREWER_TAP_DIRECTORY = (COFFEEBREWER_LIBRARY/"Taps").freeze
COFFEEBREWER_RUBY_EXEC_ARGS = [
  RUBY_PATH,
  ENV.fetch("COFFEEBREWER_RUBY_WARNINGS"),
  ENV.fetch("COFFEEBREWER_RUBY_DISABLE_OPTIONS"),
  "-I", COFFEEBREWER_LIBRARY_PATH/"test/support/lib"
].freeze

TEST_FIXTURE_DIR = (COFFEEBREWER_LIBRARY_PATH/"test/support/fixtures").freeze

TESTBALL_SHA256 = "91e3f7930c98d7ccfb288e115ed52d06b0e5bc16fec7dce8bdda86530027067b"

TEST_SHA256 = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
