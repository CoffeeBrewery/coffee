# Documentation defined in Library/CoffeeBrewery/cmd/which-formula.rb

# shellcheck disable=SC2154
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/cmd.sh"
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/executables.sh"

homebrew-which-formula() {
  local args=()

  while [[ "$#" -gt 0 ]]
  do
    if homebrew-command-help which-formula "$1"
    then
      return $?
    fi
    if homebrew-command-common-option "$1"
    then
      shift
      continue
    fi

    case "$1" in
      --explain)
        COFFEEBREWER_EXPLAIN=1
        ;;
      --*)
        onoe "Unknown option: $1"
        coffee help which-formula
        return 1
        ;;
      -*) homebrew-command-common-short-options "$1" ;;
      *) args+=("$1") ;;
    esac
    shift
  done

  homebrew-command-enable-debug

  if [[ ${#args[@]} -eq 0 ]]
  then
    coffee help which-formula
    exit 1
  fi

  for cmd in "${args[@]}"
  do
    ensure_executables_file

    local formulae=()
    local formula
    while read -r formula
    do
      formulae+=("${formula}")
    done < <(formulae_containing_executable "${cmd}")

    [[ ${#formulae[@]} -eq 0 ]] && return 1

    if [[ -n ${COFFEEBREWER_EXPLAIN} ]]
    then
      local filtered_formulae=()
      for formula in "${formulae[@]}"
      do
        if [[ ! -d "${COFFEEBREWER_CELLAR}/${formula}" ]]
        then
          filtered_formulae+=("${formula}")
        fi
      done

      if [[ ${#filtered_formulae[@]} -eq 0 ]]
      then
        return 1
      fi

      if [[ ${#filtered_formulae[@]} -eq 1 ]]
      then
        echo "The program '${cmd}' is currently not installed. You can install it by typing:"
        echo "  coffee install ${filtered_formulae[0]}"
      else
        echo "The program '${cmd}' can be found in the following formulae:"
        printf "  * %s\n" "${filtered_formulae[@]}"
        echo "Try: coffee install <selected formula>"
      fi
    else
      for formula in "${formulae[@]}"
      do
        print_formula_install_status "${formula}"
      done
    fi
  done
}
