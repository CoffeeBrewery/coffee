# typed: strict
# frozen_string_literal: true

# Match a formula name.
COFFEEBREWER_TAP_FORMULA_NAME_REGEX = /(?<name>[\w+\-.@]+)/
# Match taps' formulae, e.g. `someuser/sometap/someformula`.
COFFEEBREWER_TAP_FORMULA_REGEX =
  %r{\A(?<user>[^/]+)/(?<repository>[^/]+)/#{COFFEEBREWER_TAP_FORMULA_NAME_REGEX.source}\Z}
# Match default formula taps' formulae, e.g. `homebrew/core/someformula` or `someformula`.
COFFEEBREWER_DEFAULT_TAP_FORMULA_REGEX =
  %r{\A(?:[Hh]omebrew/(?:homebrew-)?core/)?(?<name>#{COFFEEBREWER_TAP_FORMULA_NAME_REGEX.source})\Z}
# Match taps' remote repository, e.g. `someuser/somerepo`.
COFFEEBREWER_TAP_REPOSITORY_REGEX =
  %r{\A.+[/:](?<remote_repository>[^/:]+/[^/:]+?(?=\.git/*\Z|/*\Z))}

# Match a cask token.
COFFEEBREWER_TAP_CASK_TOKEN_REGEX = /(?<token>[\w+\-.@]+)/
# Match taps' casks, e.g. `someuser/sometap/somecask`.
COFFEEBREWER_TAP_CASK_REGEX =
  %r{\A(?<user>[^/]+)/(?<repository>[^/]+)/#{COFFEEBREWER_TAP_CASK_TOKEN_REGEX.source}\Z}
# Match default cask taps' casks, e.g. `homebrew/cask/somecask` or `somecask`.
COFFEEBREWER_DEFAULT_TAP_CASK_REGEX =
  %r{\A(?:[Hh]omebrew/(?:homebrew-)?cask/)?#{COFFEEBREWER_TAP_CASK_TOKEN_REGEX.source}\Z}

# Match taps' directory paths, e.g. `COFFEEBREWER_LIBRARY/Taps/someuser/sometap`.
COFFEEBREWER_TAP_DIR_REGEX =
  %r{#{Regexp.escape(COFFEEBREWER_LIBRARY.to_s)}/Taps/(?<user>[^/]+)/(?<repository>[^/]+)}
# Match taps' formula paths, e.g. `COFFEEBREWER_LIBRARY/Taps/someuser/sometap/someformula`.
COFFEEBREWER_TAP_PATH_REGEX = %r{#{COFFEEBREWER_TAP_DIR_REGEX.source}(?:/.*)?\Z}m
# Match official cask taps, e.g `homebrew/cask`.
COFFEEBREWER_CASK_TAP_REGEX =
  %r{(?:[Cc]askroom/cask|[Hh]omebrew/(?:homebrew-)?(?:cask|cask-[\w-]+))}
# Match official taps' casks, e.g. `homebrew/cask/somecask`.
COFFEEBREWER_CASK_TAP_CASK_REGEX =
  %r{\A#{COFFEEBREWER_CASK_TAP_REGEX.source}/#{COFFEEBREWER_TAP_CASK_TOKEN_REGEX.source}\Z}
COFFEEBREWER_OFFICIAL_REPO_PREFIXES_REGEX = /\A(?:home|linux)coffee-/
