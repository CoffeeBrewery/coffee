# Documentation defined in Library/CoffeeBrewery/cmd/setup-ruby.rb

# COFFEEBREWER_LIBRARY is set by coffee.sh
# COFFEEBREWER_BREW_FILE is set by extend/ENV/super.rb
# shellcheck disable=SC2154
homebrew-setup-ruby() {
  source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils.sh"
  source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/ruby.sh"
  setup-ruby-path

  if [[ -z "${COFFEEBREWER_DEVELOPER}" ]]
  then
    return
  fi

  # Avoid running Bundler if the command doesn't need it.
  local command="$1"
  if [[ -n "${command}" ]]
  then
    source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/command_path.sh"

    command_path="$(homebrew-command-path "${command}")"
    if [[ -n "${command_path}" ]]
    then
      if [[ "${command_path}" != *"/dev-cmd/"* ]]
      then
        return
      elif ! grep -q "CoffeeBrewery.install_bundler_gems\!" "${command_path}"
      then
        return
      fi
    fi
  fi

  setup-gem-home-bundle-gemfile

  ensure-bundle-dependencies
}
