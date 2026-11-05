# Documentation defined in Library/CoffeeBrewery/cmd/formulae.rb

# COFFEEBREWER_LIBRARY is set by bin/coffee
# shellcheck disable=SC2154
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/items.sh"

homebrew-formulae() {
  local find_include_filter='*\.rb'
  local sed_filter='s|/Formula/(.+/)?|/|'
  local grep_filter='^homebrew/core'

  if homebrew-tap-trust-required
  then
    if homebrew-trusted-items-with-api-names "${find_include_filter}" '.*Casks(/.*|$)' \
       "trustedformulae" "homebrew/core" "Formula" "formula_names.txt"
    then
      return
    fi
    opoo "jq is unavailable; falling back to Ruby to apply tap trust."
    COFFEEBREWER_FORCE_RUBY_COMMAND=1 "${COFFEEBREWER_BREW_FILE}" formulae
    return
  fi

  # COFFEEBREWER_CACHE is set by coffee.sh
  # shellcheck disable=SC2154
  if [[ -z "${COFFEEBREWER_NO_INSTALL_FROM_API}" &&
        -f "${COFFEEBREWER_CACHE}/api/formula_names.txt" ]]
  then
    {
      cat "${COFFEEBREWER_CACHE}/api/formula_names.txt"
      echo
      homebrew-items "${find_include_filter}" '.*Casks(/.*|$)|.*/homebrew/homebrew-core/.*' "${sed_filter}" "${grep_filter}"
    } | sort -uf
  else
    homebrew-items "${find_include_filter}" '.*Casks(/.*|$)' "${sed_filter}" "${grep_filter}"
  fi
}
