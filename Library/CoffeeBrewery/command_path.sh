# does the quickest output of coffee command possible for the basic cases of an
# official Bash or Ruby normal or dev-cmd command.
# COFFEEBREWER_LIBRARY is set by coffee.sh
# shellcheck disable=SC2154
homebrew-command-path() {
  case "$1" in
    # check we actually have command and not e.g. commandsomething
    command) ;;
    command*) return 1 ;;
    *) ;;
  esac

  local first_command found_command
  for arg in "$@"
  do
    if [[ -z "${first_command}" && "${arg}" == "command" ]]
    then
      first_command=1
      continue
    elif [[ -f "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/${arg}.sh" ]]
    then
      echo "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/${arg}.sh"
      found_command=1
    elif [[ -f "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/dev-cmd/${arg}.sh" ]]
    then
      echo "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/dev-cmd/${arg}.sh"
      found_command=1
    elif [[ -f "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/${arg}.rb" ]]
    then
      echo "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/${arg}.rb"
      found_command=1
    elif [[ -f "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/dev-cmd/${arg}.rb" ]]
    then
      echo "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/dev-cmd/${arg}.rb"
      found_command=1
    else
      return 1
    fi
  done

  if [[ -n "${found_command}" ]]
  then
    return 0
  else
    return 1
  fi
}
