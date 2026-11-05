# Does the quickest output of coffee tap possible for no arguments.
# COFFEEBREWER_LIBRARY is set by bin/coffee
# shellcheck disable=SC2154

normalise_tap_name() {
  local directory="$1"
  local user
  local repository

  user="$(tr '[:upper:]' '[:lower:]' <<<"${directory%%/*}")"
  repository="$(tr '[:upper:]' '[:lower:]' <<<"${directory#*/}")"
  repository="${repository#@(home|linux)coffee-}"
  echo "${user}/${repository}"
}

homebrew-tap() {
  local taplib="${COFFEEBREWER_LIBRARY}/Taps"
  (
    shopt -s extglob

    for directory in "${taplib}"/*/*
    do
      [[ -d "${directory}" ]] || continue
      normalise_tap_name "${directory#"${taplib}"/}"
    done | sort
  )
}
