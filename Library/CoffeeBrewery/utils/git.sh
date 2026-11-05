# git selection and version checks plus helpers to read CoffeeBrewery's repository
# Git state, avoiding `git` forks wherever possible as they are slow enough to
# matter on every invocation.

# COFFEEBREWER_* variables set here are used across CoffeeBrewery's Bash scripts.
# shellcheck disable=SC2034
# These variables are set by bin/coffee, coffee.sh or the user environment.
# shellcheck disable=SC2154

# Some Git versions are too old for some CoffeeBrewery functionality we rely on.
COFFEEBREWER_MINIMUM_GIT_VERSION="2.30.0"

setup_git() {
  local system_git="/usr/bin/git" developer_dir
  if [[ -n "${COFFEEBREWER_MACOS}" && -x /usr/bin/xcode-select ]]
  then
    # /usr/bin/git opens an installation prompt without developer tools.
    developer_dir="$(/usr/bin/xcode-select -print-path 2>/dev/null)"
    system_git=""
    if [[ -n "${developer_dir}" && "${developer_dir}" != / ]]
    then
      system_git="${developer_dir}/usr/bin/git"
    fi
  fi
  select_tool git "${COFFEEBREWER_MINIMUM_GIT_VERSION}" "${COFFEEBREWER_PREFIX}/opt/git/bin/git" \
    "${system_git}" "${COFFEEBREWER_GIT_PATH}" "${COFFEEBREWER_FORCE_BREWED_GIT}"
  COFFEEBREWER_GIT="${COFFEEBREWER_SELECTED_TOOL:-/usr/bin/false}"
  COFFEEBREWER_GIT_VERSION="${COFFEEBREWER_SELECTED_TOOL_VERSION}"
}

check-git-version() {
  [[ -z "${COFFEEBREWER_GIT_VERSION}" ]] || return 0
  COFFEEBREWER_FORCE_BREWED_GIT=1
  install_tool git "${COFFEEBREWER_MINIMUM_GIT_VERSION}"
}

# Read all the `homebrew.*` values from CoffeeBrewery's repository Git configuration
# in one pass rather than forking `git config` for each. Section and variable
# names are case-insensitive in Git configuration files, hence `nocasematch`.
# The matching Ruby is CoffeeBrewery::Settings in Library/CoffeeBrewery/settings.rb.
read-homebrew-git-config() {
  COFFEEBREWER_GIT_CONFIG_FILE="${COFFEEBREWER_REPOSITORY}/.git/config"
  COFFEEBREWER_GIT_CONFIG_DEVCMDRUN=""
  COFFEEBREWER_GIT_CONFIG_ANALYTICS_UUID=""
  COFFEEBREWER_GIT_CONFIG_ANALYTICS_MESSAGE_SEEN=""
  COFFEEBREWER_GIT_CONFIG_ANALYTICS_DISABLED=""
  [[ -f "${COFFEEBREWER_GIT_CONFIG_FILE}" ]] || return 0

  local nocasematch_enabled=""
  shopt -q nocasematch && nocasematch_enabled="1"
  shopt -s nocasematch

  local line key value in_homebrew_section=""
  while IFS= read -r line || [[ -n "${line}" ]]
  do
    # Strip leading whitespace.
    line="${line#"${line%%[![:space:]]*}"}"
    case "${line}" in
      # The escaped closing bracket must match directly after the section
      # name so e.g. [homebrew-cask] or [homebrew "cask"] don't.
      \[homebrew\]*)
        in_homebrew_section="1"
        ;;
      \[*)
        in_homebrew_section=""
        ;;
      *=*)
        [[ -n "${in_homebrew_section}" ]] || continue
        key="${line%%=*}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${line#*=}"
        value="${value#"${value%%[![:space:]]*}"}"
        # Strip any trailing comment and whitespace like `git config` does.
        value="${value%%[#;]*}"
        value="${value%"${value##*[![:space:]]}"}"
        case "${key}" in
          devcmdrun) COFFEEBREWER_GIT_CONFIG_DEVCMDRUN="${value}" ;;
          analyticsuuid) COFFEEBREWER_GIT_CONFIG_ANALYTICS_UUID="${value}" ;;
          analyticsmessage) COFFEEBREWER_GIT_CONFIG_ANALYTICS_MESSAGE_SEEN="${value}" ;;
          analyticsdisabled) COFFEEBREWER_GIT_CONFIG_ANALYTICS_DISABLED="${value}" ;;
          *) ;;
        esac
        ;;
      *) ;;
    esac
  done <"${COFFEEBREWER_GIT_CONFIG_FILE}"

  [[ -z "${nocasematch_enabled}" ]] && shopt -u nocasematch
  return 0
}

# Set COFFEEBREWER_VERSION from `git describe`, cached in .git/describe-cache
# keyed by the HEAD revision. Leaves COFFEEBREWER_VERSION unchanged when the
# revision cannot be determined e.g. in a shallow or non-Git repository.
set-homebrew-version-from-git() {
  local git_directory="${COFFEEBREWER_REPOSITORY}/.git"
  local git_describe_cache="${git_directory}/describe-cache"
  local git_directory_owned_by_user
  [[ -O "${git_directory}/." ]] && git_directory_owned_by_user="1"

  # Read HEAD and its ref directly rather than through `git rev-parse HEAD`
  # to avoid a fork on every invocation.
  local git_head="" git_revision="" git_ref
  local git_revision_regex="^([0-9a-f]{40}|[0-9a-f]{64})$"
  read -r git_head 2>/dev/null <"${git_directory}/HEAD"
  if [[ "${git_head}" == "ref: "* ]]
  then
    git_ref="${git_head#ref: }"
    if [[ -f "${git_directory}/${git_ref}" ]]
    then
      read -r git_revision 2>/dev/null <"${git_directory}/${git_ref}"
    elif [[ -f "${git_directory}/packed-refs" ]]
    then
      local packed_revision packed_ref
      while read -r packed_revision packed_ref
      do
        if [[ "${packed_ref}" == "${git_ref}" ]]
        then
          git_revision="${packed_revision}"
          break
        fi
      done <"${git_directory}/packed-refs"
    fi
  elif [[ "${git_head}" =~ ${git_revision_regex} ]]
  then
    # HEAD is detached.
    git_revision="${git_head}"
  fi
  [[ "${git_revision}" =~ ${git_revision_regex} ]] || git_revision=""

  # Fall back to git for anything unusual e.g. a worktree where .git is a file.
  if [[ -z "${git_revision}" && -e "${git_directory}" ]]
  then
    git_revision=$("${COFFEEBREWER_GIT}" -C "${COFFEEBREWER_REPOSITORY}" rev-parse HEAD 2>/dev/null)
  fi

  if [[ -z "${git_revision}" ]]
  then
    if [[ -n "${git_directory_owned_by_user}" && -d "${git_describe_cache}" ]]
    then
      # Don't care about permission errors here.
      rm -rf "${git_describe_cache}" 2>/dev/null
    fi
    return 0
  fi

  local git_describe_cache_file="${git_describe_cache}/${git_revision}"
  local cached_version
  # Almost only developers ever have a dirty repository so only they pay for
  # the (slow) Git dirty working tree check that invalidates this cache.
  if [[ -r "${git_describe_cache_file}" ]] &&
     { [[ -z "${COFFEEBREWER_DEVELOPER}" && -z "${COFFEEBREWER_DEV_CMD_RUN}" && "${COFFEEBREWER_GIT_CONFIG_DEVCMDRUN}" != "true" ]] ||
     "${COFFEEBREWER_GIT}" -C "${COFFEEBREWER_REPOSITORY}" diff --quiet --no-ext-diff 2>/dev/null; }
  then
    read -r cached_version <"${git_describe_cache_file}"
    if [[ -n "${cached_version}" && "${cached_version}" != *"-dirty" ]]
    then
      COFFEEBREWER_VERSION="${cached_version}"
    fi
  fi

  if [[ -z "${COFFEEBREWER_VERSION}" ]]
  then
    COFFEEBREWER_VERSION="$("${COFFEEBREWER_GIT}" -C "${COFFEEBREWER_REPOSITORY}" describe --tags --dirty --abbrev=7 2>/dev/null)"
    if [[ -n "${git_directory_owned_by_user}" ]]
    then
      # Don't output any permissions errors here. The user may not have write
      # permissions to the cache but we don't care because it's an optional
      # performance improvement.
      rm -rf "${git_describe_cache}" 2>/dev/null
      mkdir -p "${git_describe_cache}" 2>/dev/null
      { echo "${COFFEEBREWER_VERSION}" >"${git_describe_cache_file}"; } 2>/dev/null
    fi
  fi
  return 0
}
