# Helpers for CoffeeBrewery's Bash command option parsing.

# COFFEEBREWER_LIBRARY is set by bin/coffee.
# shellcheck disable=SC2154
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils.sh"

homebrew-command-help() {
  local command="$1"
  local option="$2"

  case "${option}" in
    -\? | -h | --help | --usage)
      coffee help "${command}"
      ;;
    --*)
      return 1
      ;;
    -*h*)
      coffee help "${command}"
      ;;
    *)
      return 1
      ;;
  esac
}

homebrew-command-common-option() {
  local option="$1"

  case "${option}" in
    --verbose)
      COFFEEBREWER_VERBOSE=1
      ;;
    --quiet)
      COFFEEBREWER_QUIET=1
      ;;
    --debug)
      COFFEEBREWER_DEBUG=1
      ;;
    --*)
      return 1
      ;;
    -*)
      local other_options="${option#-}"
      other_options="${other_options//[dqv]/}"
      [[ -n "${option#-}" && -z "${other_options}" ]] || return 1

      # `COFFEEBREWER_VERBOSE` is read by caller command code after this helper returns.
      # shellcheck disable=SC2034
      [[ "${option#-}" == *v* ]] && COFFEEBREWER_VERBOSE=1
      # `COFFEEBREWER_QUIET` is read by caller command code after this helper returns.
      # shellcheck disable=SC2034
      [[ "${option#-}" == *q* ]] && COFFEEBREWER_QUIET=1
      [[ "${option#-}" == *d* ]] && COFFEEBREWER_DEBUG=1
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

homebrew-command-common-short-options() {
  local options="$1"

  case "${options}" in
    --*)
      return 1
      ;;
    -*) ;;
    *)
      return 1
      ;;
  esac

  options="${options#-}"
  [[ -n "${options}" ]] || return 1
  options="${options//[!dqv]/}"
  [[ -z "${options}" ]] || homebrew-command-common-option "-${options}"
}

homebrew-command-enable-debug() {
  [[ -n "${COFFEEBREWER_DEBUG:-}" ]] && set -x
}
