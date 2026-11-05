# typed: true
# frozen_string_literal: true

raise "COFFEEBREWER_BREW_FILE was not exported! Please call bin/coffee directly!" unless ENV["COFFEEBREWER_BREW_FILE"]

# The path to the executable that should be used to run `coffee`.
# Favour this instead of running `coffee` and expecting it to be in the `PATH`.
# @api public
COFFEEBREWER_BREW_FILE = Pathname(ENV.fetch("COFFEEBREWER_BREW_FILE")).freeze

# Where CoffeeBrewery is installed and files are linked to.
# @api public
COFFEEBREWER_PREFIX = Pathname(ENV.fetch("COFFEEBREWER_PREFIX")).freeze

# Where CoffeeBrewery stores built formulae packages, linking (non-keg-only) ones
# back to `COFFEEBREWER_PREFIX`.
# @api public
COFFEEBREWER_CELLAR = Pathname(ENV.fetch("COFFEEBREWER_CELLAR")).freeze

# Where CoffeeBrewery downloads (bottles, source tarballs, casks etc.) are cached.
# @api public
COFFEEBREWER_CACHE = Pathname(ENV.fetch("COFFEEBREWER_CACHE")).freeze

# Where CoffeeBrewery stores temporary files.
# We use `/tmp` instead of `TMPDIR` because long paths break Unix domain
# sockets.
# @api public
COFFEEBREWER_TEMP = Pathname(ENV.fetch("COFFEEBREWER_TEMP")).then do |tmp|
  tmp.mkpath unless tmp.exist?
  tmp.realpath
end.freeze

# Where `.git` is found
COFFEEBREWER_REPOSITORY = Pathname(ENV.fetch("COFFEEBREWER_REPOSITORY")).freeze

# Where we store most of CoffeeBrewery, taps and various metadata
COFFEEBREWER_LIBRARY = Pathname(ENV.fetch("COFFEEBREWER_LIBRARY")).freeze

# Where shim scripts for various build and SCM tools are stored
COFFEEBREWER_SHIMS_PATH = (COFFEEBREWER_LIBRARY/"CoffeeBrewery/shims").freeze

# Where external data that has been incorporated into CoffeeBrewery is stored
COFFEEBREWER_DATA_PATH = (COFFEEBREWER_LIBRARY/"CoffeeBrewery/data").freeze

# Where we store symlinks to currently linked kegs
COFFEEBREWER_LINKED_KEGS = (COFFEEBREWER_PREFIX/"var/homebrew/linked").freeze

# Where we store symlinks to currently version-pinned kegs
COFFEEBREWER_PINNED_KEGS = (COFFEEBREWER_PREFIX/"var/homebrew/pinned").freeze

# Where we store symlinks to currently version-pinned casks
COFFEEBREWER_PINNED_CASKS = (COFFEEBREWER_PREFIX/"var/homebrew/pinned_casks").freeze

# Where we store lock files
COFFEEBREWER_LOCKS = (COFFEEBREWER_PREFIX/"var/homebrew/locks").freeze

# Where we store temporary cellar files that must be in the prefix
COFFEEBREWER_TEMP_CELLAR = (COFFEEBREWER_PREFIX/"var/homebrew/tmp/.cellar").freeze

# Where we store temporary cask files that must be in the prefix
COFFEEBREWER_TEMP_CASKROOM = (COFFEEBREWER_PREFIX/"var/homebrew/tmp/.caskroom").freeze

# Where we store Casks
COFFEEBREWER_CASKROOM = Pathname(ENV.fetch("COFFEEBREWER_CASKROOM")).freeze

# Where formulae installed via URL are cached
COFFEEBREWER_CACHE_FORMULA = (COFFEEBREWER_CACHE/"Formula").freeze

# Where build, postinstall and test logs of formulae are written to
COFFEEBREWER_LOGS = Pathname(ENV.fetch("COFFEEBREWER_LOGS")).expand_path.freeze

# Where installed taps live
COFFEEBREWER_TAP_DIRECTORY = (COFFEEBREWER_LIBRARY/"Taps").freeze

# The Ruby path and args to use for forked Ruby calls
COFFEEBREWER_RUBY_EXEC_ARGS = [
  RUBY_PATH,
  ENV.fetch("COFFEEBREWER_RUBY_WARNINGS"),
  ENV.fetch("COFFEEBREWER_RUBY_DISABLE_OPTIONS"),
].freeze

# Location for `coffee alias` and `coffee unalias` commands.
#
# Unix-Like systems store config in $HOME/.config whose location can be
# overridden by the XDG_CONFIG_HOME environment variable. Unfortunately
# CoffeeBrewery strictly filters environment variables in BuildEnvironment.
COFFEEBREWER_ALIASES = if (path = Pathname.new("~/.config/coffee-aliases").expand_path).exist? ||
                      (path = Pathname.new("~/.coffee-aliases").expand_path).exist?
  path.realpath
else
  path
end.freeze
