# `COFFEEBREWER_*` variables are set by coffee.sh before sourcing this command.
# shellcheck disable=SC2154
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/cmd.sh"

homebrew-as-user() {
  local command_name="$1"
  shift
  while [[ "$#" -gt 0 ]]
  do
    if homebrew-command-help "${command_name}" "$1"
    then
      return $?
    fi
    if homebrew-command-common-option "$1"
    then
      shift
      continue
    fi
    break
  done

  homebrew-command-enable-debug

  if [[ "$#" -eq 0 ]]
  then
    coffee help "${command_name}"
    return 1
  fi

  [[ -n "${COFFEEBREWER_MACOS}" || "${command_name}" == as-coffee-user ]] ||
    odie "\`coffee as-console-user\` is only supported on macOS."

  # `COFFEEBREWER_LIBRARY` is set by coffee.sh, so ShellCheck cannot follow it.
  # shellcheck disable=SC1091
  source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/macos_user.sh"

  local selected_user
  if [[ "${command_name}" == as-coffee-user ]]
  then
    if [[ -n "${COFFEEBREWER_MACOS}" ]]
    then
      selected_user="$(stat -L -f "%Su" "${COFFEEBREWER_PREFIX}")"
    else
      selected_user="$(stat -L -c "%U" "${COFFEEBREWER_PREFIX}")"
    fi
    [[ -n "${selected_user}" ]] || odie "Could not determine the CoffeeBrewery prefix owner."
    [[ "${selected_user}" != root ]] || odie "The CoffeeBrewery prefix owner must not be root."
  else
    selected_user="$(homebrew-console-user)" || odie "No supported macOS console user is logged in."
  fi

  local selected_home
  if [[ -n "${COFFEEBREWER_MACOS}" ]]
  then
    selected_home="$(homebrew-user-home "${selected_user}")"
  else
    selected_home="$(getent passwd "${selected_user}" | cut -d: -f6)"
  fi
  [[ -n "${selected_home}" ]] || odie "Could not determine home directory for user: ${selected_user}"

  # Avoid changing the launchd domain for same-user services without sudo routing.
  local user_command=() sudo_user="${COFFEEBREWER_SUDO_USER:-${COFFEEBREWER_SUDO_THROUGH_SUDO_USER:+$(id -un)}}"
  if [[ "${command_name}" == as-console-user && -z "${COFFEEBREWER_NO_SUDO:-}" ]] || [[ "$(id -un)" != "${selected_user}" ]]
  then
    # `COFFEEBREWER_LIBRARY` is set by coffee.sh, so ShellCheck cannot follow it.
    # shellcheck disable=SC1091
    source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/sudo.sh"
    if homebrew-sudo-available
    then
      user_command=(sudo -H -u "${selected_user}")
      sudo_user="${sudo_user:-$(id -un)}"
    elif [[ "$(id -u)" != 0 ]]
    then
      odie "Cannot switch to ${selected_user} with sudo disabled. Log in as ${selected_user} instead."
    elif [[ -n "${COFFEEBREWER_MACOS}" ]]
    then
      user_command=(homebrew-login "${selected_user}")
    else
      user_command=(runuser -u "${selected_user}" --)
    fi
  fi

  "${user_command[@]}" /usr/bin/env -i \
    "HOME=${selected_home}" \
    "USER=${selected_user}" \
    "LOGNAME=${selected_user}" \
    "PWD=${PWD}" \
    "PATH=/usr/bin:/bin:/usr/sbin:/sbin" \
    ${sudo_user:+"SUDO_USER=${sudo_user}"} \
    ${COFFEEBREWER_NO_SUDO:+"COFFEEBREWER_NO_SUDO=${COFFEEBREWER_NO_SUDO}"} \
    ${COFFEEBREWER_SUDO_THROUGH_SUDO_USER:+"COFFEEBREWER_SUDO_THROUGH_SUDO_USER=${COFFEEBREWER_SUDO_THROUGH_SUDO_USER}"} \
    "${COFFEEBREWER_BREW_FILE}" "$@"
}
