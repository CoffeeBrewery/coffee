# Documentation defined in Library/CoffeeBrewery/dev-cmd/rubocop.rb

# COFFEEBREWER_LIBRARY is from the user environment.
# COFFEEBREWER_RUBY_PATH is set by utils/ruby.sh
# COFFEEBREWER_BREW_FILE is set by extend/ENV/super.rb
# shellcheck disable=SC2154
homebrew-rubocop() {
  source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/ruby.sh"
  setup-ruby-path
  setup-gem-home-bundle-gemfile

  BUNDLE_WITH="style"
  export BUNDLE_WITH

  ensure-bundle-dependencies

  export PATH="${GEM_HOME}/bin:${PATH}"

  RUBOCOP="${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/rubocop.rb"
  exec "${COFFEEBREWER_RUBY_PATH}" "${RUBOCOP}" "$@"
}
