# Documentation defined in Library/CoffeeBrewery/cmd/update.rb

# COFFEEBREWER_API_DOMAIN, COFFEEBREWER_CURLRC, COFFEEBREWER_DEBUG, COFFEEBREWER_DEVELOPER, COFFEEBREWER_GIT_EMAIL, COFFEEBREWER_GIT_NAME,
# COFFEEBREWER_GITHUB_API_TOKEN, COFFEEBREWER_NO_ENV_HINTS, COFFEEBREWER_NO_INSTALL_CLEANUP, COFFEEBREWER_NO_INSTALL_FROM_API,
# COFFEEBREWER_UPDATE_TO_TAG are from the user environment
# COFFEEBREWER_LIBRARY, COFFEEBREWER_PREFIX, COFFEEBREWER_REPOSITORY, COFFEEBREWER_USER_SET_VARS are set by bin/coffee
# COFFEEBREWER_API_DEFAULT_DOMAIN, COFFEEBREWER_AUTO_UPDATE_CASK_TAP, COFFEEBREWER_AUTO_UPDATE_CORE_TAP,
# COFFEEBREWER_AUTO_UPDATE_SECS, COFFEEBREWER_BREW_DEFAULT_GIT_REMOTE, COFFEEBREWER_BREW_GIT_REMOTE, COFFEEBREWER_CACHE,
# COFFEEBREWER_CASK_REPOSITORY, COFFEEBREWER_CELLAR, COFFEEBREWER_CORE_DEFAULT_GIT_REMOTE, COFFEEBREWER_CORE_GIT_REMOTE,
# COFFEEBREWER_CORE_REPOSITORY, COFFEEBREWER_CURL, COFFEEBREWER_DEV_CMD_RUN, COFFEEBREWER_FORCE_BREWED_CA_CERTIFICATES,
# COFFEEBREWER_FORCE_BREWED_CURL, COFFEEBREWER_FORCE_BREWED_GIT,
# COFFEEBREWER_CURL_SUPPORTS_ETAGS, COFFEEBREWER_SYSTEM_CURL_TOO_OLD, COFFEEBREWER_USER_AGENT_CURL are set by coffee.sh
# shellcheck disable=SC2154
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/cmd.sh"
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/api.sh"
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/curl.sh"
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/lock.sh"

macos_version_name() {
  # NOTE: Changes to this list must match `SYMBOLS` in `macos_version.rb`.
  if [[ "${COFFEEBREWER_MACOS_VERSION_NUMERIC}" -ge "270000" ]]
  then
    echo "golden_gate"
  elif [[ "${COFFEEBREWER_MACOS_VERSION_NUMERIC}" -ge "260000" ]]
  then
    echo "tahoe"
  elif [[ "${COFFEEBREWER_MACOS_VERSION_NUMERIC}" -ge "150000" ]]
  then
    echo "sequoia"
  elif [[ "${COFFEEBREWER_MACOS_VERSION_NUMERIC}" -ge "140000" ]]
  then
    echo "sonoma"
  elif [[ "${COFFEEBREWER_MACOS_VERSION_NUMERIC}" -ge "130000" ]]
  then
    echo "ventura"
  elif [[ "${COFFEEBREWER_MACOS_VERSION_NUMERIC}" -ge "120000" ]]
  then
    echo "monterey"
  elif [[ "${COFFEEBREWER_MACOS_VERSION_NUMERIC}" -ge "110000" ]]
  then
    # odisabled: remove support for Big Sur and macOS x86_64 September (or later) 2027
    echo "big_sur"
  fi
}

bottle_tag() {
  if [[ -n "${COFFEEBREWER_MACOS}" && "${COFFEEBREWER_PHYSICAL_PROCESSOR}" == "x86_64" ]]
  then
    macos_version_name
  elif [[ -n "${COFFEEBREWER_MACOS}" ]]
  then
    echo "${COFFEEBREWER_PHYSICAL_PROCESSOR}_$(macos_version_name)"
  elif [[ -n "${COFFEEBREWER_LINUX}" ]]
  then
    echo "${COFFEEBREWER_PHYSICAL_PROCESSOR}_linux"
  fi
}

# Replaces the function in Library/CoffeeBrewery/coffee.sh to cache the Curl/Git executable to
# provide speedup when using Curl/Git repeatedly (as update.sh does).
curl() {
  if [[ -z "${CURL_EXECUTABLE}" ]]
  then
    CURL_EXECUTABLE="$("${COFFEEBREWER_LIBRARY}/CoffeeBrewery/shims/shared/curl" --homebrew=print-path)"
    if [[ -z "${CURL_EXECUTABLE}" ]]
    then
      odie "Can't find a working Curl!"
    fi
  fi
  "${CURL_EXECUTABLE}" "$@"
}

git() {
  if [[ -z "${GIT_EXECUTABLE}" ]]
  then
    GIT_EXECUTABLE="$("${COFFEEBREWER_LIBRARY}/CoffeeBrewery/shims/shared/git" --homebrew=print-path)"
    if [[ -z "${GIT_EXECUTABLE}" ]]
    then
      odie "Can't find a working Git!"
    fi
  fi
  # Disable Git hooks (e.g. a core.hooksPath set by `git lfs install`),
  # which can break CoffeeBrewery's Git operations.
  # Keep in sync with `Tap#git_command!` in Library/CoffeeBrewery/tap.rb.
  "${GIT_EXECUTABLE}" -c core.hooksPath=/dev/null "$@"
}

git_init_if_necessary() {
  safe_cd "${COFFEEBREWER_REPOSITORY}"
  if [[ ! -d ".git" ]]
  then
    set -e
    trap '{ rm -rf .git; exit 1; }' EXIT
    git init
    git config --bool core.autocrlf false
    git config --bool core.symlinks true
    if [[ "${COFFEEBREWER_BREW_DEFAULT_GIT_REMOTE}" != "${COFFEEBREWER_BREW_GIT_REMOTE}" ]]
    then
      echo "COFFEEBREWER_BREW_GIT_REMOTE set: using ${COFFEEBREWER_BREW_GIT_REMOTE} as the CoffeeBrewery/coffee Git remote." >&2
    fi
    git config remote.origin.url "${COFFEEBREWER_BREW_GIT_REMOTE}"
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git config fetch.prune true
    git fetch --force --tags origin
    git remote set-head origin --auto >/dev/null
    git reset --hard origin/HEAD
    SKIP_FETCH_BREW_REPOSITORY=1
    set +e
    trap - EXIT
  fi

  [[ -d "${COFFEEBREWER_CORE_REPOSITORY}" ]] || return
  safe_cd "${COFFEEBREWER_CORE_REPOSITORY}"
  if [[ ! -d ".git" ]]
  then
    set -e
    trap '{ rm -rf .git; exit 1; }' EXIT
    git init
    git config --bool core.autocrlf false
    git config --bool core.symlinks true
    if [[ "${COFFEEBREWER_CORE_DEFAULT_GIT_REMOTE}" != "${COFFEEBREWER_CORE_GIT_REMOTE}" ]]
    then
      echo "COFFEEBREWER_CORE_GIT_REMOTE set: using ${COFFEEBREWER_CORE_GIT_REMOTE} as the CoffeeBrewery/homebrew-core Git remote." >&2
    fi
    git config remote.origin.url "${COFFEEBREWER_CORE_GIT_REMOTE}"
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git config fetch.prune true
    git fetch --force origin
    git remote set-head origin --auto >/dev/null
    git reset --hard origin/HEAD
    SKIP_FETCH_CORE_REPOSITORY=1
    set +e
    trap - EXIT
  fi
}

repository_var_suffix() {
  local repository_directory="${1}"
  local repository_var_suffix

  if [[ "${repository_directory}" == "${COFFEEBREWER_REPOSITORY}" ]]
  then
    repository_var_suffix=""
  else
    repository_var_suffix="${repository_directory#"${COFFEEBREWER_LIBRARY}/Taps"}"
    repository_var_suffix="$(echo -n "${repository_var_suffix}" | tr -C "A-Za-z0-9" "_" | tr "[:lower:]" "[:upper:]")"
  fi
  echo "${repository_var_suffix}"
}

upstream_branch() {
  local upstream_branch

  upstream_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null)"
  if [[ -z "${upstream_branch}" ]]
  then
    git remote set-head origin --auto >/dev/null
    upstream_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null)"
  fi
  upstream_branch="${upstream_branch#refs/remotes/origin/}"
  [[ -z "${upstream_branch}" ]] && upstream_branch="main"
  echo "${upstream_branch}"
}

read_current_revision() {
  git rev-parse -q --verify HEAD
}

# Keep in sync with `GitRepository#shallow?` in `git_repository.rb`.
shallow_repository() {
  [[ -d "$1" && "$(git -C "$1" rev-parse --is-shallow-repository 2>/dev/null)" == "true" ]]
}

pop_stash() {
  [[ -z "${STASHED}" ]] && return
  if [[ -n "${COFFEEBREWER_VERBOSE}" ]]
  then
    echo "Restoring your stashed changes to ${DIR}..."
    git stash pop
  else
    git stash pop "${QUIET_ARGS[@]}" 1>/dev/null
  fi
  unset STASHED
}

pop_stash_message() {
  [[ -z "${STASHED}" ]] && return
  echo "To restore the stashed changes to ${DIR}, run:" >&2
  echo "  cd ${DIR} && git stash pop" >&2
  unset STASHED
}

reset_on_interrupt() {
  if [[ "${INITIAL_BRANCH}" != "${UPSTREAM_BRANCH}" && -n "${INITIAL_BRANCH}" ]]
  then
    git checkout "${INITIAL_BRANCH}" "${QUIET_ARGS[@]}"
  fi

  if [[ -n "${INITIAL_REVISION}" ]]
  then
    git rebase --abort &>/dev/null
    git merge --abort &>/dev/null
    git reset --hard "${INITIAL_REVISION}" "${QUIET_ARGS[@]}"
  fi

  if [[ -n "${COFFEEBREWER_NO_UPDATE_CLEANUP}" ]]
  then
    pop_stash
  else
    pop_stash_message
  fi

  exit 130
}

# Used for testing purposes, e.g. for testing formula migration after
# renaming it in the currently checked-out branch. To test run
# "coffee update --simulate-from-current-branch"
simulate_from_current_branch() {
  local DIR
  local TAP_VAR
  local UPSTREAM_BRANCH
  local CURRENT_REVISION

  DIR="$1"
  cd "${DIR}" || return
  TAP_VAR="$2"
  UPSTREAM_BRANCH="$3"
  CURRENT_REVISION="$4"

  INITIAL_REVISION="$(git rev-parse -q --verify "${UPSTREAM_BRANCH}")"
  export COFFEEBREWER_UPDATE_BEFORE"${TAP_VAR}"="${INITIAL_REVISION}"
  export COFFEEBREWER_UPDATE_AFTER"${TAP_VAR}"="${CURRENT_REVISION}"
  if [[ "${INITIAL_REVISION}" != "${CURRENT_REVISION}" ]]
  then
    COFFEEBREWER_UPDATED="1"
  fi
  if ! git merge-base --is-ancestor "${INITIAL_REVISION}" "${CURRENT_REVISION}"
  then
    odie "Your ${DIR} HEAD is not a descendant of ${UPSTREAM_BRANCH}!"
  fi
}

merge_or_rebase() {
  if [[ -n "${COFFEEBREWER_VERBOSE}" ]]
  then
    echo "Updating ${DIR}..."
  fi

  local DIR
  local TAP_VAR
  local UPSTREAM_BRANCH

  DIR="$1"
  cd "${DIR}" || return
  TAP_VAR="$2"
  UPSTREAM_BRANCH="$3"
  unset STASHED

  trap reset_on_interrupt SIGINT

  if [[ "${DIR}" == "${COFFEEBREWER_REPOSITORY}" && -n "${COFFEEBREWER_UPDATE_TO_TAG}" ]]
  then
    UPSTREAM_TAG="$(
      git tag --list --sort=-version:refname |
        grep -m 1 '^[0-9]*\.[0-9]*\.[0-9]*$'
    )"
  else
    UPSTREAM_TAG=""
  fi

  if [[ -n "${UPSTREAM_TAG}" ]]
  then
    REMOTE_REF="refs/tags/${UPSTREAM_TAG}"
    UPSTREAM_BRANCH="stable"
  else
    REMOTE_REF="origin/${UPSTREAM_BRANCH}"
  fi

  if [[ -n "$(git status --untracked-files=all --porcelain 2>/dev/null)" ]]
  then
    if [[ -n "${COFFEEBREWER_VERBOSE}" ]]
    then
      echo "Stashing uncommitted changes to ${DIR}..."
    fi
    git merge --abort &>/dev/null
    git rebase --abort &>/dev/null
    git reset --mixed "${QUIET_ARGS[@]}"
    if ! git -c "user.email=coffee-update@localhost" \
       -c "user.name=coffee update" \
       stash save --include-untracked "${QUIET_ARGS[@]}"
    then
      odie <<EOS
Could not 'git stash' in ${DIR}!
Please stash/commit manually if you need to keep your changes or, if not, run:
  cd ${DIR}
  git reset --hard origin/HEAD
EOS
    fi
    git reset --hard "${QUIET_ARGS[@]}"
    STASHED="1"
  fi

  INITIAL_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null)"
  MAIN_MIGRATION_REQUIRED=
  if [[ "${INITIAL_BRANCH}" == "master" &&
        ("${DIR}" == "${COFFEEBREWER_REPOSITORY}" || "${DIR}" == "${COFFEEBREWER_CORE_REPOSITORY}" || "${DIR}" == "${COFFEEBREWER_CASK_REPOSITORY}") ]]
  then
    # Migrate master to main for CoffeeBrewery/coffee, homebrew-core or homebrew-cask
    MAIN_MIGRATION_REQUIRED="1"
  fi

  if [[ -n "${UPSTREAM_TAG}" ]] ||
     [[ "${INITIAL_BRANCH}" != "${UPSTREAM_BRANCH}" && -n "${INITIAL_BRANCH}" ]]
  then
    # Recreate and check out `#{upstream_branch}` if unable to fast-forward
    # it to `origin/#{@upstream_branch}`. Otherwise, just check it out.
    if [[ -z "${UPSTREAM_TAG}" ]] &&
       git merge-base --is-ancestor "${UPSTREAM_BRANCH}" "${REMOTE_REF}" &>/dev/null
    then
      git checkout --force "${UPSTREAM_BRANCH}" "${QUIET_ARGS[@]}"
    else
      if [[ -n "${UPSTREAM_TAG}" && "${UPSTREAM_BRANCH}" != "master" && "${UPSTREAM_BRANCH}" != "main" ]] &&
         [[ "${INITIAL_BRANCH}" != "master" && "${INITIAL_BRANCH}" != "main" ]]
      then
        local detected_upstream_branch
        detected_upstream_branch="$(upstream_branch)"
        git branch --force "${detected_upstream_branch}" "origin/${detected_upstream_branch}" "${QUIET_ARGS[@]}"
      fi

      git checkout --force -B "${UPSTREAM_BRANCH}" "${REMOTE_REF}" "${QUIET_ARGS[@]}"
    fi
  fi

  INITIAL_REVISION="$(read_current_revision)"
  export COFFEEBREWER_UPDATE_BEFORE"${TAP_VAR}"="${INITIAL_REVISION}"

  # ensure we don't munge line endings on checkout
  git config --bool core.autocrlf false

  # make sure symlinks are saved as-is
  git config --bool core.symlinks true

  if [[ -z "${COFFEEBREWER_MERGE}" ]]
  then
    # Work around bug where git rebase --quiet is not quiet
    if [[ -z "${COFFEEBREWER_VERBOSE}" ]]
    then
      git rebase "${QUIET_ARGS[@]}" "${REMOTE_REF}" >/dev/null
    else
      git rebase "${QUIET_ARGS[@]}" "${REMOTE_REF}"
    fi
  else
    git merge --no-edit --ff "${QUIET_ARGS[@]}" "${REMOTE_REF}" \
      --strategy=recursive \
      --strategy-option=ours \
      --strategy-option=ignore-all-space
  fi

  CURRENT_REVISION="$(read_current_revision)"
  export COFFEEBREWER_UPDATE_AFTER"${TAP_VAR}"="${CURRENT_REVISION}"

  if [[ "${INITIAL_REVISION}" != "${CURRENT_REVISION}" ]]
  then
    COFFEEBREWER_UPDATED="1"
  fi

  trap '' SIGINT

  if [[ -n "${COFFEEBREWER_NO_UPDATE_CLEANUP}" ]]
  then
    if [[ -z "${MAIN_MIGRATION_REQUIRED}" && "${INITIAL_BRANCH}" != "${UPSTREAM_BRANCH}" && -n "${INITIAL_BRANCH}" ]] &&
       [[ ! "${INITIAL_BRANCH}" =~ ^v[0-9]+\.[0-9]+\.[0-9]|stable$ ]]
    then
      git checkout "${INITIAL_BRANCH}" "${QUIET_ARGS[@]}"
    fi

    pop_stash
  else
    pop_stash_message
  fi

  if [[ -n "${MAIN_MIGRATION_REQUIRED}" ]]
  then
    if [[ -n "$(git config branch.main.remote 2>/dev/null || true)" ]]
    then
      git branch -d "${QUIET_ARGS[@]}" master
    else
      opoo "$(
        cat <<EOWARN
Failed to migrate ${DIR} from the deprecated "master" branch to "main"!
The "master" branch sync will stop and this warning will become an error when
CoffeeBrewery 5.2.0 is released (no earlier than 2026-06-10).
Re-run \`coffee update\` to try again.
EOWARN
      )"
    fi
  fi

  trap - SIGINT
}

api_curl_download() {
  local json_url="$1"
  local cache_path="$2"
  shift 2

  curl \
    "${CURL_DISABLE_CURLRC_ARGS[@]}" \
    --fail --compressed --silent \
    --speed-limit "${COFFEEBREWER_CURL_SPEED_LIMIT}" --speed-time "${COFFEEBREWER_CURL_SPEED_TIME}" \
    --location --remote-time --output "${cache_path}" \
    --write-out "%{http_code}" \
    "$@" \
    --user-agent "${COFFEEBREWER_USER_AGENT_CURL}" \
    "${json_url}"
}

fetch_api_file() {
  local filename="$1"
  local update_failed_file="$2"

  local api_cache="${COFFEEBREWER_CACHE}/api"

  local cache_path="${api_cache}/${filename}"
  mkdir -p "$(dirname "${cache_path}")"

  # Match DownloadLock in CoffeeBrewery::API.fetch_json_api_file (api.rb).
  local lock_path="${COFFEEBREWER_PREFIX}/var/homebrew/locks/${cache_path##*/}.download.lock"
  if ! { mkdir -p "${lock_path%/*}" && exec 201>"${lock_path}"; } || ! _create_lock 201 "API download ${filename}"
  then
    echo "Cannot lock ${filename} for download!" >>"${update_failed_file}"
    exec 201>&-
    return 1
  fi

  if [[ "${filename}" == "formula.jws.json" ]] || [[ "${filename}" == "internal/packages.$(bottle_tag).jws.json" ]]
  then
    local is_formula_file=1
  fi

  if [[ "${filename}" == "cask.jws.json" ]] || [[ "${filename}" == "internal/packages.$(bottle_tag).jws.json" ]]
  then
    local is_cask_file=1
  fi

  if [[ -f "${cache_path}" ]]
  then
    INITIAL_JSON_BYTESIZE="$(wc -c "${cache_path}")"
  fi

  if [[ -n "${COFFEEBREWER_VERBOSE}" ]]
  then
    echo "Checking if we need to fetch ${filename}..."
  fi

  local etag_path="${cache_path}.etag"
  local new_etag_path="${cache_path}.etag.new"
  local new_cache_path="${cache_path}.new"
  local compare_etag_path curl_exit_code http_code json_url last_json_url
  local -a etag_args conditional_args
  while read -r json_url
  do
    # Keep conditional requests in sync with CoffeeBrewery::API.fetch_json_api_file in api.rb.
    compare_etag_path=""
    etag_args=()
    if [[ "${COFFEEBREWER_CURL_SUPPORTS_ETAGS}" == "1" && -z "${last_json_url}" ]]
    then
      compare_etag_path="${etag_path}"
      etag_args=(--etag-save "${new_etag_path}")
    fi
    conditional_args=()
    if [[ -z "${last_json_url}" ]]
    then
      api_conditional_args "${cache_path}" "${compare_etag_path}" "${json_url}"
    fi
    rm -f "${new_cache_path}" "${new_etag_path}"
    http_code="$(api_curl_download "${json_url}" "${new_cache_path}" "${etag_args[@]}" "${conditional_args[@]}")"
    curl_exit_code=$?
    # A conditional request can fail with a receive error (curl exit code 56) when
    # an unconditional request for the same URL succeeds, so retry exactly once.
    if [[ ${curl_exit_code} -eq 56 ]] && [[ ${#conditional_args[@]} -gt 0 ]]
    then
      rm -f "${new_cache_path}" "${new_etag_path}"
      http_code="$(api_curl_download "${json_url}" "${new_cache_path}" "${etag_args[@]}")"
      curl_exit_code=$?
    fi
    last_json_url="${json_url}"
    [[ ${curl_exit_code} -eq 0 ]] && break
  done < <(api_urls "${filename}")

  if [[ ${curl_exit_code} -eq 0 ]]
  then
    if [[ -f "${new_cache_path}" ]]
    then
      rm -f "${etag_path}" "${etag_path}.url"
      if ! mv -f "${new_cache_path}" "${cache_path}"
      then
        echo "Failed to replace ${cache_path}!" >>"${update_failed_file}"
        rm -f "${new_cache_path}" "${new_etag_path}"
        exec 201>&-
        return 1
      fi
    fi
    if [[ -s "${new_etag_path}" ]]
    then
      mv -f "${new_etag_path}" "${etag_path}"
      printf '%s' "${last_json_url}" >"${etag_path}.url"
    elif [[ "${http_code}" != "304" ]]
    then
      rm -f "${etag_path}" "${etag_path}.url"
    fi
  fi
  rm -f "${new_cache_path}" "${new_etag_path}"

  if [[ -n ${is_formula_file} ]] && [[ -f "${api_cache}/formula_names.txt" ]]
  then
    mv -f "${api_cache}/formula_names.txt" "${api_cache}/formula_names.before.txt"
  fi
  if [[ -n ${is_cask_file} ]] && [[ -f "${api_cache}/cask_names.txt" ]]
  then
    mv -f "${api_cache}/cask_names.txt" "${api_cache}/cask_names.before.txt"
  fi

  if [[ ${curl_exit_code} -eq 0 ]]
  then
    touch "${cache_path}"

    CURRENT_JSON_BYTESIZE="$(wc -c "${cache_path}")"
    if [[ "${INITIAL_JSON_BYTESIZE}" != "${CURRENT_JSON_BYTESIZE}" ]]
    then

      if [[ -n ${is_formula_file} ]]
      then
        rm -f "${api_cache}/formula_aliases.txt"
      fi
      COFFEEBREWER_UPDATED="1"

      if [[ -n "${COFFEEBREWER_VERBOSE}" ]]
      then
        echo "Updated ${filename}."
      fi
    fi
  else
    echo "Failed to download ${last_json_url}!" >>"${update_failed_file}"
  fi
  exec 201>&-
}

homebrew-update() {
  local option
  local DIR
  local UPSTREAM_BRANCH

  for option in "$@"
  do
    if homebrew-command-help update "${option}"
    then
      exit $?
    fi
    if homebrew-command-common-option "${option}"
    then
      continue
    fi

    case "${option}" in
      # Keep in sync with the `Cmd::Update` parser in `cmd/update.rb`.
      --merge)
        odie "Calling the \`--merge\` switch is disabled! There is no replacement."
        ;;
      --force) COFFEEBREWER_UPDATE_FORCE=1 ;;
      --simulate-from-current-branch)
        shift
        COFFEEBREWER_SIMULATE_FROM_CURRENT_BRANCH=1
        ;;
      --auto-update) export COFFEEBREWER_UPDATE_AUTO=1 ;;
      --*)
        onoe "Unknown option: ${option}"
        coffee help update
        exit 1
        ;;
      -*)
        homebrew-command-common-short-options "${option}"
        [[ "${option}" == *f* ]] && COFFEEBREWER_UPDATE_FORCE=1
        ;;
      *)
        opoo "Use \`coffee upgrade $*\` to upgrade formulae; running it instead."
        exec "${COFFEEBREWER_BREW_FILE}" upgrade "$@"
        ;;
    esac
  done

  homebrew-command-enable-debug

  if [[ -z "${COFFEEBREWER_UPDATE_TO_TAG}" ]]
  then
    if [[ -n "${COFFEEBREWER_DEVELOPER}" || -n "${COFFEEBREWER_DEV_CMD_RUN}" ]]
    then
      export COFFEEBREWER_NO_UPDATE_CLEANUP="1"
    else
      export COFFEEBREWER_UPDATE_TO_TAG="1"
    fi
  fi

  # check permissions
  if [[ -e "${COFFEEBREWER_CELLAR}" && ! -w "${COFFEEBREWER_CELLAR}" ]]
  then
    odie <<EOS
${COFFEEBREWER_CELLAR} is not writable. You should change the
ownership and permissions of ${COFFEEBREWER_CELLAR} back to your
user account:
  sudo chown -R ${USER-\$(whoami)} ${COFFEEBREWER_CELLAR}
EOS
  fi

  if [[ -d "${COFFEEBREWER_CORE_REPOSITORY}" ]] ||
     [[ -z "${COFFEEBREWER_NO_INSTALL_FROM_API}" ]]
  then
    COFFEEBREWER_CORE_AVAILABLE="1"
  fi

  if [[ ! -w "${COFFEEBREWER_REPOSITORY}" ]]
  then
    odie <<EOS
${COFFEEBREWER_REPOSITORY} is not writable. You should change the
ownership and permissions of ${COFFEEBREWER_REPOSITORY} back to your
user account:
  sudo chown -R ${USER-\$(whoami)} ${COFFEEBREWER_REPOSITORY}
EOS
  fi

  # we may want to use CoffeeBrewery CA certificates
  if [[ -n "${COFFEEBREWER_FORCE_BREWED_CA_CERTIFICATES}" && ! -f "${COFFEEBREWER_PREFIX}/etc/ca-certificates/cert.pem" ]]
  then
    # we cannot install CoffeeBrewery CA certificates if homebrew/core is unavailable.
    if [[ -n "${COFFEEBREWER_CORE_AVAILABLE}" ]]
    then
      coffee install ca-certificates
      setup_ca_certificates
    fi
  fi

  # we may want to use a CoffeeBrewery curl
  if [[ -n "${COFFEEBREWER_FORCE_BREWED_CURL}" && "${COFFEEBREWER_CURL}" != "${COFFEEBREWER_PREFIX}/opt/curl/bin/curl" ]]
  then
    install_tool curl "${COFFEEBREWER_MINIMUM_CURL_VERSION}"
  fi

  if ! (git --version) &>/dev/null ||
     [[ -n "${COFFEEBREWER_FORCE_BREWED_GIT}" && "${COFFEEBREWER_GIT}" != "${COFFEEBREWER_PREFIX}/opt/git/bin/git" ]]
  then
    # Keep Git bootstrapping in sync with utils/git.rb.
    install_tool git "${COFFEEBREWER_MINIMUM_GIT_VERSION}"
  fi

  shallow_repository "${COFFEEBREWER_CORE_REPOSITORY}" && COFFEEBREWER_CORE_SHALLOW=1
  shallow_repository "${COFFEEBREWER_CASK_REPOSITORY}" && COFFEEBREWER_CASK_SHALLOW=1
  if [[ -n "${COFFEEBREWER_CORE_SHALLOW}" && -n "${COFFEEBREWER_CASK_SHALLOW}" ]]
  then
    SHALLOW_COMMAND_PHRASE="These commands"
    SHALLOW_REPO_PHRASE="repositories"
  else
    SHALLOW_COMMAND_PHRASE="This command"
    SHALLOW_REPO_PHRASE="repository"
  fi

  if [[ -n "${COFFEEBREWER_CORE_SHALLOW}" || -n "${COFFEEBREWER_CASK_SHALLOW}" ]]
  then
    odie <<EOS
${COFFEEBREWER_CORE_SHALLOW:+
  homebrew-core is a shallow clone.}${COFFEEBREWER_CASK_SHALLOW:+
  homebrew-cask is a shallow clone.}
To \`coffee update\`, first run:${COFFEEBREWER_CORE_SHALLOW:+
  git -C "${COFFEEBREWER_CORE_REPOSITORY}" fetch --unshallow}${COFFEEBREWER_CASK_SHALLOW:+
  git -C "${COFFEEBREWER_CASK_REPOSITORY}" fetch --unshallow}
${SHALLOW_COMMAND_PHRASE} may take a few minutes to run due to the large size of the ${SHALLOW_REPO_PHRASE}.
This restriction has been made on GitHub's request because updating shallow
clones is an extremely expensive operation due to the tree layout and traffic of
CoffeeBrewery/homebrew-core and CoffeeBrewery/homebrew-cask. We don't do this for you
automatically to avoid repeatedly performing an expensive unshallow operation in
CI systems (which should instead be fixed to not use shallow clones). Sorry for
the inconvenience!
EOS
  fi

  export GIT_TERMINAL_PROMPT="0"
  export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -oBatchMode=yes"

  if [[ -n "${COFFEEBREWER_GIT_NAME}" ]]
  then
    export GIT_AUTHOR_NAME="${COFFEEBREWER_GIT_NAME}"
    export GIT_COMMITTER_NAME="${COFFEEBREWER_GIT_NAME}"
  fi

  if [[ -n "${COFFEEBREWER_GIT_EMAIL}" ]]
  then
    export GIT_AUTHOR_EMAIL="${COFFEEBREWER_GIT_EMAIL}"
    export GIT_COMMITTER_EMAIL="${COFFEEBREWER_GIT_EMAIL}"
  fi

  if [[ -z "${COFFEEBREWER_VERBOSE}" ]]
  then
    export GIT_ADVICE="false"
    QUIET_ARGS=(-q)
  else
    QUIET_ARGS=()
  fi

  setup_curl_args

  # only allow one instance of coffee update
  lock update

  git_init_if_necessary

  if [[ "${COFFEEBREWER_BREW_DEFAULT_GIT_REMOTE}" != "${COFFEEBREWER_BREW_GIT_REMOTE}" ||
        " ${COFFEEBREWER_USER_SET_VARS} " == *" COFFEEBREWER_BREW_GIT_REMOTE "* ]]
  then
    safe_cd "${COFFEEBREWER_REPOSITORY}"
    echo "COFFEEBREWER_BREW_GIT_REMOTE set: using ${COFFEEBREWER_BREW_GIT_REMOTE} as the CoffeeBrewery/coffee Git remote." >&2
    git remote set-url origin --end-of-options "${COFFEEBREWER_BREW_GIT_REMOTE}"
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git fetch --force --tags origin
    SKIP_FETCH_BREW_REPOSITORY=1
  fi

  if [[ -d "${COFFEEBREWER_CORE_REPOSITORY}" ]] &&
     [[ "${COFFEEBREWER_CORE_DEFAULT_GIT_REMOTE}" != "${COFFEEBREWER_CORE_GIT_REMOTE}" ||
        " ${COFFEEBREWER_USER_SET_VARS} " == *" COFFEEBREWER_CORE_GIT_REMOTE "* ]]
  then
    safe_cd "${COFFEEBREWER_CORE_REPOSITORY}"
    echo "COFFEEBREWER_CORE_GIT_REMOTE set: using ${COFFEEBREWER_CORE_GIT_REMOTE} as the CoffeeBrewery/homebrew-core Git remote." >&2
    git remote set-url origin --end-of-options "${COFFEEBREWER_CORE_GIT_REMOTE}"
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git config fetch.prune true
    git fetch --force origin
    SKIP_FETCH_CORE_REPOSITORY=1
  fi

  safe_cd "${COFFEEBREWER_REPOSITORY}"

  # if an older system had a newer curl installed, change each repo's remote URL from git to https
  if [[ -n "${COFFEEBREWER_SYSTEM_CURL_TOO_OLD}" && -x "${COFFEEBREWER_PREFIX}/opt/curl/bin/curl" ]] &&
     [[ "$(git config remote.origin.url)" =~ ^git:// ]]
  then
    git config remote.origin.url "${COFFEEBREWER_BREW_GIT_REMOTE}"
    git config -f "${COFFEEBREWER_CORE_REPOSITORY}/.git/config" remote.origin.url "${COFFEEBREWER_CORE_GIT_REMOTE}"
  fi

  # kill all of subprocess on interrupt
  trap '{ /usr/bin/pkill -P $$; wait; exit 130; }' SIGINT

  local update_failed_file="${COFFEEBREWER_REPOSITORY}/.git/UPDATE_FAILED"
  local missing_remote_ref_dirs_file="${COFFEEBREWER_REPOSITORY}/.git/FAILED_FETCH_DIRS"
  local redirected_remotes_file="${COFFEEBREWER_REPOSITORY}/.git/REDIRECTED_REMOTES"
  rm -f "${update_failed_file}"
  rm -f "${missing_remote_ref_dirs_file}"
  rm -f "${redirected_remotes_file}"

  # Keep hidden-directory exclusion in sync with Tap.installed in tap.rb.
  for DIR in "${COFFEEBREWER_REPOSITORY}" "${COFFEEBREWER_LIBRARY}"/Taps/*/*
  do
    if [[ -z "${COFFEEBREWER_NO_INSTALL_FROM_API}" ]] &&
       [[ -n "${COFFEEBREWER_UPDATE_AUTO}" || (-z "${COFFEEBREWER_DEVELOPER}" && -z "${COFFEEBREWER_DEV_CMD_RUN}") ]] &&
       [[ -n "${COFFEEBREWER_UPDATE_AUTO}" &&
          (("${DIR}" == "${COFFEEBREWER_CORE_REPOSITORY}" && -z "${COFFEEBREWER_AUTO_UPDATE_CORE_TAP}") ||
          ("${DIR}" == "${COFFEEBREWER_CASK_REPOSITORY}" && -z "${COFFEEBREWER_AUTO_UPDATE_CASK_TAP}")) ]]
    then
      continue
    fi

    [[ -d "${DIR}/.git" ]] || continue
    cd "${DIR}" || continue

    if [[ "${DIR}" = "${COFFEEBREWER_REPOSITORY}" && "${COFFEEBREWER_REPOSITORY}" = "${COFFEEBREWER_PREFIX}" ]]
    then
      # Git's fsmonitor prevents the release of our locks
      git config --bool core.fsmonitor false
    fi

    if ! git config --local --get remote.origin.url &>/dev/null
    then
      opoo "No remote 'origin' in ${DIR}, skipping update!"
      continue
    fi

    if [[ -n "${COFFEEBREWER_VERBOSE}" ]]
    then
      echo "Checking if we need to fetch ${DIR}..."
    fi

    TAP_VAR="$(repository_var_suffix "${DIR}")"
    UPSTREAM_BRANCH_DIR="$(upstream_branch)"
    declare UPSTREAM_BRANCH"${TAP_VAR}"="${UPSTREAM_BRANCH_DIR}"
    declare PREFETCH_REVISION"${TAP_VAR}"="$(git rev-parse -q --verify refs/remotes/origin/"${UPSTREAM_BRANCH_DIR}")"

    if [[ -n "${GITHUB_ACTIONS}" && -n "${COFFEEBREWER_UPDATE_SKIP_BREW}" && "${DIR}" == "${COFFEEBREWER_REPOSITORY}" ]]
    then
      continue
    fi

    # Force a full update if we don't have any tags.
    if [[ "${DIR}" == "${COFFEEBREWER_REPOSITORY}" && -z "$(git tag --list)" ]]
    then
      COFFEEBREWER_UPDATE_FORCE=1
    fi

    if [[ -z "${COFFEEBREWER_UPDATE_FORCE}" ]]
    then
      [[ -n "${SKIP_FETCH_BREW_REPOSITORY}" && "${DIR}" == "${COFFEEBREWER_REPOSITORY}" ]] && continue
      [[ -n "${SKIP_FETCH_CORE_REPOSITORY}" && "${DIR}" == "${COFFEEBREWER_CORE_REPOSITORY}" ]] && continue
    fi

    if [[ -z "${UPDATING_MESSAGE_SHOWN}" ]]
    then
      if [[ -n "${COFFEEBREWER_UPDATE_AUTO}" ]]
      then
        # Outputting a command but don't want to run it, hence single quotes.
        # shellcheck disable=SC2016
        ohai 'Auto-updating CoffeeBrewery...' >&2
        if [[ -z "${COFFEEBREWER_NO_ENV_HINTS}" && -z "${COFFEEBREWER_AUTO_UPDATE_SECS}" ]]
        then
          # shellcheck disable=SC2016
          echo 'Adjust how often this is run with `$COFFEEBREWER_AUTO_UPDATE_SECS` or disable with' >&2
          # shellcheck disable=SC2016
          echo '`$COFFEEBREWER_NO_AUTO_UPDATE=1`. Hide these hints with `$COFFEEBREWER_NO_ENV_HINTS=1` (see `man coffee`).' >&2
        fi
      else
        ohai 'Updating CoffeeBrewery...' >&2
      fi
      UPDATING_MESSAGE_SHOWN=1
    fi

    # The upstream repository's default branch may not be main or master;
    # check refs/remotes/origin/HEAD to see what the default
    # origin branch name is, and use that. If not set, fall back to "main".
    # the refspec ensures that the default upstream branch gets updated
    (
      UPSTREAM_REPOSITORY_URL="$(git config remote.origin.url)"
      unset UPSTREAM_REPOSITORY
      unset UPSTREAM_REPOSITORY_TOKEN

      # COFFEEBREWER_UPDATE_FORCE and COFFEEBREWER_UPDATE_AUTO aren't modified here so ignore subshell warning.
      # shellcheck disable=SC2030
      if [[ "${UPSTREAM_REPOSITORY_URL}" == "https://github.com/"* ]]
      then
        UPSTREAM_REPOSITORY="${UPSTREAM_REPOSITORY_URL#https://github.com/}"
        UPSTREAM_REPOSITORY="${UPSTREAM_REPOSITORY%.git}"
      elif [[ "${DIR}" != "${COFFEEBREWER_REPOSITORY}" ]] &&
           [[ "${UPSTREAM_REPOSITORY_URL}" =~ https://([[:alnum:]_:]+)@github.com/(.*)$ ]]
      then
        UPSTREAM_REPOSITORY="${BASH_REMATCH[2]%.git}"
        UPSTREAM_REPOSITORY_TOKEN="${BASH_REMATCH[1]#*:}"
      fi

      MAIN_MIGRATION_REQUIRED=
      if [[ "${UPSTREAM_BRANCH_DIR}" == "master" &&
            ("${DIR}" == "${COFFEEBREWER_REPOSITORY}" || "${DIR}" == "${COFFEEBREWER_CORE_REPOSITORY}" || "${DIR}" == "${COFFEEBREWER_CASK_REPOSITORY}") ]]
      then
        # Migrate master to main for CoffeeBrewery/coffee, homebrew-core or homebrew-cask
        MAIN_MIGRATION_REQUIRED=1
        UPSTREAM_BRANCH_DIR="main"
        declare UPSTREAM_BRANCH"${TAP_VAR}"="main"
      fi

      if [[ -n "${UPSTREAM_REPOSITORY}" ]] &&
         [[ -z "${COFFEEBREWER_UPDATE_FORCE}" || "${DIR}" == "${COFFEEBREWER_LIBRARY}"/Taps/*/* ]]
      then
        # UPSTREAM_REPOSITORY_TOKEN is parsed (if exists) from UPSTREAM_REPOSITORY_URL
        # COFFEEBREWER_GITHUB_API_TOKEN is optionally defined in the user environment.
        # shellcheck disable=SC2153
        if [[ -n "${UPSTREAM_REPOSITORY_TOKEN}" ]]
        then
          CURL_GITHUB_API_ARGS=("--header" "Authorization: token ${UPSTREAM_REPOSITORY_TOKEN}")
        elif [[ -n "${COFFEEBREWER_GITHUB_API_TOKEN}" ]]
        then
          CURL_GITHUB_API_ARGS=("--header" "Authorization: token ${COFFEEBREWER_GITHUB_API_TOKEN}")
        else
          CURL_GITHUB_API_ARGS=()
        fi

        if [[ "${DIR}" == "${COFFEEBREWER_REPOSITORY}" && -n "${COFFEEBREWER_UPDATE_TO_TAG}" ]]
        then
          # Only try to `git fetch` when the upstream tags have changed
          # (so the API does not return 304: unmodified).
          GITHUB_API_ETAG="$(sed -n 's/^ETag: "\([a-f0-9]\{32\}\)".*/\1/p' ".git/GITHUB_HEADERS" 2>/dev/null)"
          GITHUB_API_ACCEPT="application/vnd.github+json"
          GITHUB_API_ENDPOINT="tags"
        else
          # Only try to `git fetch` when the upstream branch is at a different SHA
          # (so the API does not return 304: unmodified).
          GITHUB_API_ETAG="$(git rev-parse "refs/remotes/origin/${UPSTREAM_BRANCH_DIR}")"
          GITHUB_API_ACCEPT="application/vnd.github.sha"
          GITHUB_API_ENDPOINT="commits/${UPSTREAM_BRANCH_DIR}"
        fi

        local upstream_api_url="https://api.github.com/repos/${UPSTREAM_REPOSITORY}/${GITHUB_API_ENDPOINT}"

        # COFFEEBREWER_CURL is set by coffee.sh (and isn't misspelt here)
        # shellcheck disable=SC2153
        UPSTREAM_SHA_HTTP_RESPONSE="$(
          curl \
            "${CURL_DISABLE_CURLRC_ARGS[@]}" \
            "${CURL_GITHUB_API_ARGS[@]}" \
            --silent --max-time 3 \
            --location --no-remote-time --output /dev/null --write-out "%{http_code} %{url_effective}" \
            --dump-header "${DIR}/.git/GITHUB_HEADERS" \
            --user-agent "${COFFEEBREWER_USER_AGENT_CURL}" \
            --header "X-GitHub-Api-Version:2022-11-28" \
            --header "Accept: ${GITHUB_API_ACCEPT}" \
            --header "If-None-Match: \"${GITHUB_API_ETAG}\"" \
            "${upstream_api_url}"
        )"
        UPSTREAM_SHA_HTTP_CODE="${UPSTREAM_SHA_HTTP_RESPONSE%% *}"
        UPSTREAM_SHA_HTTP_EFFECTIVE_URL="${UPSTREAM_SHA_HTTP_RESPONSE#* }"

        if [[ "${DIR}" == "${COFFEEBREWER_LIBRARY}"/Taps/*/* ]] &&
           [[ -n "${UPSTREAM_SHA_HTTP_EFFECTIVE_URL}" ]] &&
           [[ "${UPSTREAM_SHA_HTTP_EFFECTIVE_URL}" != "${upstream_api_url}" ]]
        then
          redirected_remote="$(
            curl \
              "${CURL_DISABLE_CURLRC_ARGS[@]}" \
              "${CURL_GITHUB_API_ARGS[@]}" \
              --silent --max-time 3 \
              --location --no-remote-time \
              --user-agent "${COFFEEBREWER_USER_AGENT_CURL}" \
              --header "X-GitHub-Api-Version:2022-11-28" \
              --header "Accept: application/vnd.github+json" \
              "https://api.github.com/repos/${UPSTREAM_REPOSITORY}" |
              sed -n 's/^[[:space:]]*"clone_url": "\(.*\)",$/\1/p' |
              head -n1
          )"
          if [[ -n "${redirected_remote}" ]]
          then
            printf "%s\t%s\n" "${DIR}" "${redirected_remote}" >>"${redirected_remotes_file}"
          fi
        fi

        # Touch FETCH_HEAD to confirm we've checked for an update.
        [[ -f "${DIR}/.git/FETCH_HEAD" ]] && touch "${DIR}/.git/FETCH_HEAD"
        if [[ -z "${COFFEEBREWER_UPDATE_FORCE}" ]] &&
           [[ "${UPSTREAM_SHA_HTTP_CODE}" == "304" ]] &&
           [[ "${DIR}" != "${COFFEEBREWER_LIBRARY}"/Taps/*/* ||
              "${UPSTREAM_SHA_HTTP_EFFECTIVE_URL}" == "${upstream_api_url}" ]]
        then
          exit
        fi
      fi

      # COFFEEBREWER_VERBOSE isn't modified here so ignore subshell warning.
      # shellcheck disable=SC2030
      if [[ -n "${COFFEEBREWER_VERBOSE}" ]]
      then
        echo "Fetching ${DIR}..."
      fi

      local tmp_failure_file="${DIR}/.git/TMP_FETCH_FAILURES"
      rm -f "${tmp_failure_file}"

      if ! git fetch --tags --force "${QUIET_ARGS[@]}" origin \
         "refs/heads/${UPSTREAM_BRANCH_DIR}:refs/remotes/origin/${UPSTREAM_BRANCH_DIR}" 2>>"${tmp_failure_file}"
      then
        if [[ -f "${tmp_failure_file}" ]]
        then
          local git_errors
          git_errors="$(cat "${tmp_failure_file}")"
          # Attempt migration from master to main branch.
          if [[ "${git_errors}" == *"couldn't find remote ref refs/heads/master"* ]]
          then
            if git fetch --tags --force "${QUIET_ARGS[@]}" origin \
               "refs/heads/main:refs/remotes/origin/main" 2>>"${tmp_failure_file}"
            then
              rm -f "${DIR}/.git/refs/remotes/origin/HEAD" "${DIR}/.git/refs/remotes/origin/master"
              UPSTREAM_BRANCH_DIR="$(upstream_branch)"
              declare UPSTREAM_BRANCH"${TAP_VAR}"="${UPSTREAM_BRANCH_DIR}"
              git branch -m master main "${QUIET_ARGS[@]}"
              git branch -u origin/main main "${QUIET_ARGS[@]}"
              rm -f "${tmp_failure_file}"
              exit
            fi
          fi

          rm -f "${tmp_failure_file}"
        fi

        # Don't output errors if COFFEEBREWER_UPDATE_AUTO is set.
        if [[ -n "${COFFEEBREWER_UPDATE_AUTO}" ]]
        then
          exit
        fi

        # Reprint fetch errors to stderr
        [[ -n "${git_errors}" ]] && echo "${git_errors}" 1>&2

        if [[ "${UPSTREAM_SHA_HTTP_CODE}" == "404" ]]
        then
          TAP="${DIR#"${COFFEEBREWER_LIBRARY}"/Taps/}"
          echo "${TAP} does not exist! Run \`coffee untap ${TAP}\` to remove it." >>"${update_failed_file}"
        else
          echo "Fetching ${DIR} failed!" >>"${update_failed_file}"

          if [[ -f "${tmp_failure_file}" ]] &&
             [[ "$(cat "${tmp_failure_file}")" == "fatal: couldn't find remote ref refs/heads/${UPSTREAM_BRANCH_DIR}" ]]
          then
            echo "${DIR}" >>"${missing_remote_ref_dirs_file}"
          fi
        fi
      elif [[ "${DIR}" == "${COFFEEBREWER_LIBRARY}"/Taps/*/* ]] &&
           [[ -s "${tmp_failure_file}" ]]
      then
        redirected_remote="$(sed -n 's/.*redirecting to //p' "${tmp_failure_file}" | tail -n1)"
        if [[ -n "${redirected_remote}" ]]
        then
          printf "%s\t%s\n" "${DIR}" "${redirected_remote}" >>"${redirected_remotes_file}"
        fi
      fi

      if [[ -n "${MAIN_MIGRATION_REQUIRED}" ]]
      then
        git remote set-head origin --auto >/dev/null
      fi

      rm -f "${tmp_failure_file}"
    ) &
  done

  wait
  trap - SIGINT

  if [[ -f "${missing_remote_ref_dirs_file}" ]]
  then
    COFFEEBREWER_MISSING_REMOTE_REF_DIRS="$(cat "${missing_remote_ref_dirs_file}")"
    rm -f "${missing_remote_ref_dirs_file}"
    export COFFEEBREWER_MISSING_REMOTE_REF_DIRS
  fi

  if [[ -f "${redirected_remotes_file}" ]]
  then
    export COFFEEBREWER_REDIRECTED_REMOTES_FILE="${redirected_remotes_file}"
  fi

  for DIR in "${COFFEEBREWER_REPOSITORY}" "${COFFEEBREWER_LIBRARY}"/Taps/*/*
  do
    if [[ -z "${COFFEEBREWER_NO_INSTALL_FROM_API}" ]] &&
       [[ -n "${COFFEEBREWER_UPDATE_AUTO}" || (-z "${COFFEEBREWER_DEVELOPER}" && -z "${COFFEEBREWER_DEV_CMD_RUN}") ]] &&
       [[ -n "${COFFEEBREWER_UPDATE_AUTO}" &&
          (("${DIR}" == "${COFFEEBREWER_CORE_REPOSITORY}" && -z "${COFFEEBREWER_AUTO_UPDATE_CORE_TAP}") ||
          ("${DIR}" == "${COFFEEBREWER_CASK_REPOSITORY}" && -z "${COFFEEBREWER_AUTO_UPDATE_CASK_TAP}")) ]]
    then
      continue
    fi

    [[ -d "${DIR}/.git" ]] || continue
    cd "${DIR}" || continue
    if ! git config --local --get remote.origin.url &>/dev/null
    then
      # No need to display a (duplicate) warning here
      continue
    fi

    TAP_VAR="$(repository_var_suffix "${DIR}")"
    UPSTREAM_BRANCH_VAR="UPSTREAM_BRANCH${TAP_VAR}"
    UPSTREAM_BRANCH="${!UPSTREAM_BRANCH_VAR}"
    export COFFEEBREWER_UPDATE_BRANCH"${TAP_VAR}"="${UPSTREAM_BRANCH}"
    CURRENT_REVISION="$(read_current_revision)"

    PREFETCH_REVISION_VAR="PREFETCH_REVISION${TAP_VAR}"
    PREFETCH_REVISION="${!PREFETCH_REVISION_VAR}"
    POSTFETCH_REVISION="$(git rev-parse -q --verify refs/remotes/origin/"${UPSTREAM_BRANCH}")"

    # COFFEEBREWER_UPDATE_FORCE and COFFEEBREWER_VERBOSE weren't modified in subshell.
    # shellcheck disable=SC2031
    if [[ -n "${COFFEEBREWER_SIMULATE_FROM_CURRENT_BRANCH}" ]]
    then
      simulate_from_current_branch "${DIR}" "${TAP_VAR}" "${UPSTREAM_BRANCH}" "${CURRENT_REVISION}"
    elif [[ -z "${COFFEEBREWER_UPDATE_FORCE}" &&
            "${PREFETCH_REVISION}" == "${POSTFETCH_REVISION}" &&
            "${CURRENT_REVISION}" == "${POSTFETCH_REVISION}" ]] ||
         [[ -n "${GITHUB_ACTIONS}" && -n "${COFFEEBREWER_UPDATE_SKIP_BREW}" && "${DIR}" == "${COFFEEBREWER_REPOSITORY}" ]]
    then
      export COFFEEBREWER_UPDATE_BEFORE"${TAP_VAR}"="${CURRENT_REVISION}"
      export COFFEEBREWER_UPDATE_AFTER"${TAP_VAR}"="${CURRENT_REVISION}"
    else
      merge_or_rebase "${DIR}" "${TAP_VAR}" "${UPSTREAM_BRANCH}"
    fi
  done

  if [[ -z "${COFFEEBREWER_NO_INSTALL_FROM_API}" ]]
  then
    api_files=("internal/packages.$(bottle_tag)")

    for json in "${api_files[@]}"
    do
      local filename="${json}.jws.json"
      fetch_api_file "${filename}" "${update_failed_file}"
    done

    rm -f "${COFFEEBREWER_CACHE}/api/formula.jws.json" "${COFFEEBREWER_CACHE}/api/cask.jws.json"
    rm -f "${COFFEEBREWER_CACHE}/api/formula_tap_migrations.jws.json" "${COFFEEBREWER_CACHE}/api/cask_tap_migrations.jws.json"

    # Not a typo, these are the files we used to download that no longer need so should cleanup.
    rm -f "${COFFEEBREWER_CACHE}/api/formula.json" "${COFFEEBREWER_CACHE}/api/cask.json"
    rm -f "${COFFEEBREWER_CACHE}"/api/internal/formula.*.jws.json
    rm -f "${COFFEEBREWER_CACHE}"/api/internal/cask.*.jws.json

    # Remove API files (and their sidecars)
    # from previous OS versions, keeping the current OS's so `coffee
    # update-report`'s API data load stays or becomes prewarmed. Keep in
    # sync with `cache_files` in Library/CoffeeBrewery/cleanup.rb.
    for f in "${COFFEEBREWER_CACHE}"/api/internal/packages.*.jws.json*
    do
      case "${f}" in
        "${COFFEEBREWER_CACHE}/api/internal/packages.$(bottle_tag).jws.json") ;;
        "${COFFEEBREWER_CACHE}/api/internal/packages.$(bottle_tag).jws.json.payload") ;;
        "${COFFEEBREWER_CACHE}/api/internal/packages.$(bottle_tag).jws.json.payload.index") ;;
        "${COFFEEBREWER_CACHE}/api/internal/packages.$(bottle_tag).jws.json.etag") ;;
        "${COFFEEBREWER_CACHE}/api/internal/packages.$(bottle_tag).jws.json.etag.url") ;;
        *) rm -f "${f}" ;;
      esac
    done
  else
    if [[ -n "${COFFEEBREWER_VERBOSE}" ]]
    then
      echo "COFFEEBREWER_NO_INSTALL_FROM_API set: skipping API JSON downloads."
    fi
  fi

  if [[ -f "${update_failed_file}" ]]
  then
    onoe <"${update_failed_file}"
    rm -f "${update_failed_file}"
    export COFFEEBREWER_UPDATE_FAILED="1"
  fi

  safe_cd "${COFFEEBREWER_REPOSITORY}"

  # COFFEEBREWER_UPDATE_AUTO wasn't modified in subshell.
  # shellcheck disable=SC2031
  if [[ -n "${COFFEEBREWER_UPDATED}" ]] ||
     [[ -n "${COFFEEBREWER_UPDATE_FAILED}" ]] ||
     [[ -n "${COFFEEBREWER_MISSING_REMOTE_REF_DIRS}" ]] ||
     [[ -n "${COFFEEBREWER_REDIRECTED_REMOTES_FILE}" ]] ||
     [[ -n "${COFFEEBREWER_UPDATE_FORCE}" ]] ||
     [[ -d "${COFFEEBREWER_LIBRARY}/LinkedKegs" ]] ||
     [[ ! -f "${COFFEEBREWER_CACHE}/all_commands_list.txt" ]] ||
     [[ -n "${COFFEEBREWER_DEVELOPER}" && -z "${COFFEEBREWER_UPDATE_AUTO}" ]]
  then
    coffee update-report "$@"
    return $?
  elif [[ -z "${COFFEEBREWER_UPDATE_AUTO}" && -z "${COFFEEBREWER_QUIET}" ]]
  then
    echo "Already up-to-date."
  fi
}
