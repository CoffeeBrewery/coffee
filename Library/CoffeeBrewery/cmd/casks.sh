# Documentation defined in Library/CoffeeBrewery/cmd/casks.rb

# COFFEEBREWER_LIBRARY is set in bin/coffee
# shellcheck disable=SC2154
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/items.sh"

homebrew-casks() {
  local find_include_filter='*/Casks/*\.rb'
  local sed_filter='s|/Casks/(.+/)?|/|'
  local grep_filter='^homebrew/cask'

  if homebrew-tap-trust-required
  then
    if homebrew-trusted-items-with-api-names "${find_include_filter}" '^\b$' \
       "trustedcasks" "homebrew/cask" "Casks" "cask_names.txt"
    then
      return
    fi
    opoo "jq is unavailable; falling back to Ruby to apply tap trust."
    COFFEEBREWER_FORCE_RUBY_COMMAND=1 "${COFFEEBREWER_BREW_FILE}" casks
    return
  fi

  # COFFEEBREWER_CACHE is set by coffee.sh
  # shellcheck disable=SC2154
  if [[ -z "${COFFEEBREWER_NO_INSTALL_FROM_API}" &&
        -f "${COFFEEBREWER_CACHE}/api/cask_names.txt" ]]
  then
    {
      cat "${COFFEEBREWER_CACHE}/api/cask_names.txt"
      echo
      homebrew-items "${find_include_filter}" '.*/homebrew/homebrew-cask/.*' "${sed_filter}" "${grep_filter}"
    } | sort -uf
  else
    homebrew-items "${find_include_filter}" '^\b$' "${sed_filter}" "${grep_filter}"
  fi
}
