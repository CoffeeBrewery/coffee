# Setup analytics and delete old analytics UUIDs.
# COFFEEBREWER_GIT_CONFIG_FILE and COFFEEBREWER_GIT_CONFIG_ANALYTICS_* are parsed from
# the repository Git configuration by coffee.sh.
# COFFEEBREWER_NO_ANALYTICS is from the user environment.
# shellcheck disable=SC2154
setup-analytics() {
  local legacy_uuid_file="${HOME}/.homebrew_analytics_user_uuid"
  if [[ -f "${legacy_uuid_file}" ]]
  then
    rm -f "${legacy_uuid_file}"
  fi

  if [[ -n "${COFFEEBREWER_GIT_CONFIG_ANALYTICS_UUID}" ]]
  then
    git config --file="${COFFEEBREWER_GIT_CONFIG_FILE}" --unset-all homebrew.analyticsuuid 2>/dev/null
  fi

  if [[ -n "${COFFEEBREWER_NO_ANALYTICS}" ]]
  then
    return
  fi

  if [[ "${COFFEEBREWER_GIT_CONFIG_ANALYTICS_MESSAGE_SEEN}" != "true" ||
        "${COFFEEBREWER_GIT_CONFIG_ANALYTICS_DISABLED}" == "true" ]]
  then
    # Internal variable for coffee's use, to differentiate from user-supplied setting
    export COFFEEBREWER_NO_ANALYTICS_THIS_RUN="1"
    return
  fi
}
