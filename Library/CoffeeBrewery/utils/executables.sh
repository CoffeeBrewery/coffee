# Helpers for CoffeeBrewery's executables.txt database.

# COFFEEBREWER_CACHE is set by utils/ruby.sh
# COFFEEBREWER_BREW_FILE and COFFEEBREWER_LIBRARY are set by bin/coffee
# shellcheck disable=SC2153,SC2154
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils.sh"

COFFEEBREWER_EXECUTABLES_TXT_ENDPOINT="internal/executables.txt"

executables_txt_cache_file() {
  echo "${COFFEEBREWER_CACHE}/api/${COFFEEBREWER_EXECUTABLES_TXT_ENDPOINT}"
}

executables_file_fresh() {
  local database_file
  database_file="$(executables_txt_cache_file)"

  local -a stat_printf
  local stat_format
  if [[ -n "${COFFEEBREWER_MACOS}" ]]
  then
    stat_printf=("/usr/bin/stat" "-f")
    stat_format="%m"
  else
    stat_printf=("/usr/bin/stat" "-c")
    stat_format="%Y"
  fi

  local file_mtime
  local current_time
  local auto_update_secs
  file_mtime="$("${stat_printf[@]}" "${stat_format}" "${database_file}")"
  current_time=$(date +%s)
  auto_update_secs=${COFFEEBREWER_API_AUTO_UPDATE_SECS:-450}

  [[ $((current_time - auto_update_secs)) -lt ${file_mtime} ]]
}

ensure_executables_file() {
  local database_file
  database_file="$(executables_txt_cache_file)"

  if [[ -n "${COFFEEBREWER_NO_INSTALL_FROM_API}" ]]
  then
    odie "COFFEEBREWER_NO_INSTALL_FROM_API must be unset to use \`coffee which-formula\` or \`coffee exec\`."
  fi

  if [[ -s "${database_file}" ]] && executables_file_fresh
  then
    return
  fi

  "${COFFEEBREWER_BREW_FILE}" update --auto-update &>/dev/null || true
  [[ -s "${database_file}" ]] || odie "The CoffeeBrewery executables database is unavailable. Run \`coffee update\` and try again."
}

formulae_containing_executable() {
  local executable="$1"
  local formula cmds_text

  while IFS=':' read -r formula cmds_text
  do
    [[ -z "${formula}" ]] && continue
    [[ -z "${cmds_text}" ]] && continue

    # `executables.txt` lines are `formula(version):exe exe...`. Keep the
    # executable list as one string for whole-word matching below.
    # Padding both sides with spaces avoids matching `foo` inside `foobar`.
    if [[ " ${cmds_text} " == *" ${executable} "* ]]
    then
      echo "${formula%\(*}"
    fi
  done <"$(executables_txt_cache_file)" 2>/dev/null
}
