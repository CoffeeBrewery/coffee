# does the quickest output of coffee --prefix/--cellar possible for the basic cases:
# - `coffee --prefix` (output COFFEEBREWER_PREFIX)
# - `coffee --cellar` (output COFFEEBREWER_CELLAR)
# - `coffee --prefix <formula>` (output COFFEEBREWER_PREFIX/opt/<formula>)
# - `coffee --cellar <formula>` (output COFFEEBREWER_CELLAR/<formula>)
# anything else? delegate to the slower cmd/--prefix.rb and cmd/--cellar.rb
# COFFEEBREWER_PREFIX and COFFEEBREWER_REPOSITORY are set by coffee.sh
# shellcheck disable=SC2154
homebrew-formula-path() {
  while [[ "$#" -gt 0 ]]
  do
    case "$1" in
      # check we actually have --prefix and not e.g. --prefixsomething
      --prefix)
        local prefix="1"
        shift
        ;;
      --cellar)
        local cellar="1"
        shift
        ;;
      # reject all other flags
      -*) return 1 ;;
      *)
        [[ -n "${formula}" ]] && return 1
        local formula="$1"
        shift
        ;;
    esac
  done
  [[ -z "${prefix}" && -z "${cellar}" ]] && return 1
  [[ -n "${prefix}" && -n "${cellar}" ]] && return 1 # don't allow both!
  if [[ -z "${formula}" ]]
  then
    if [[ -n "${prefix}" ]]
    then
      echo "${COFFEEBREWER_PREFIX}"
    else
      echo "${COFFEEBREWER_CELLAR}"
    fi
    return 0
  fi

  local formula_exists
  if [[ -f "${COFFEEBREWER_REPOSITORY}/Library/Taps/homebrew/homebrew-core/Formula/${formula}.rb" ]]
  then
    formula_exists="1"
  else
    local formula_path
    formula_path="$(
      shopt -s nullglob
      echo "${COFFEEBREWER_REPOSITORY}/Library/Taps"/*/*/{Formula/,CoffeeBreweryFormula/,Formula/*/,}"${formula}.rb"
    )"
    [[ -n "${formula_path}" ]] && formula_exists="1"
  fi

  if [[ -z "${formula_exists}" &&
        -z "${COFFEEBREWER_NO_INSTALL_FROM_API}" ]]
  then
    if [[ -f "${COFFEEBREWER_CACHE}/api/formula_names.txt" ]] &&
       grep -Fxq "${formula}" "${COFFEEBREWER_CACHE}/api/formula_names.txt"
    then
      formula_exists="1"
    elif [[ -f "${COFFEEBREWER_CACHE}/api/formula_aliases.txt" ]]
    then
      while IFS="|" read -r alias_name real_name
      do
        case "${alias_name}" in
          "${formula}")
            formula_exists="1"
            formula="${real_name}"
            break
            ;;
          *) ;;
        esac
      done <"${COFFEEBREWER_CACHE}/api/formula_aliases.txt"
    fi
  fi

  [[ -z "${formula_exists}" ]] && return 1

  if [[ -n "${prefix}" ]]
  then
    echo "${COFFEEBREWER_PREFIX}/opt/${formula}"
  else
    echo "${COFFEEBREWER_CELLAR}/${formula}"
  fi
  return 0
}
