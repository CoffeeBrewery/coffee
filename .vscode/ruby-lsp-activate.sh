#!/bin/bash
# This might be sourced from zsh, so support both
if [[ -n "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_PATH="${BASH_SOURCE[0]}"
elif [[ -n "${ZSH_VERSION}" ]]; then
    # This is zsh-specific syntax.
    # shellcheck disable=SC2296
    SCRIPT_PATH="${(%):-%x}"
else
    SCRIPT_PATH="$0"
fi
COFFEEBREWER_PREFIX="$(cd "$(dirname "${SCRIPT_PATH}")"/../ && pwd)"

# These are used by the functions needed from utils/ruby.sh
export COFFEEBREWER_BREW_FILE="${COFFEEBREWER_PREFIX}/bin/coffee"
export COFFEEBREWER_LIBRARY="${COFFEEBREWER_PREFIX}/Library"
export BUNDLE_WITH="style:typecheck:vscode"

# shellcheck source=../Library/CoffeeBrewery/utils/ruby.sh
source "${COFFEEBREWER_PREFIX}/Library/CoffeeBrewery/utils/ruby.sh"

setup-ruby-path
setup-gem-home-bundle-gemfile
ensure-bundle-dependencies

# setup-ruby-path doesn't add CoffeeBrewery's ruby to PATH
homebrew_ruby_bin="$(dirname "${COFFEEBREWER_RUBY_PATH}")"
export PATH="${homebrew_ruby_bin}:${PATH}"
