# Documentation defined in Library/CoffeeBrewery/cmd/update-reset.rb

# COFFEEBREWER_LIBRARY is set by bin/coffee
# shellcheck disable=SC2154
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/cmd.sh"

# Replaces the function in Library/CoffeeBrewery/coffee.sh to cache the Git executable to provide
# speedup when using Git repeatedly and prevent errors if the shim changes mid-update.
git() {
  if [[ -z "${GIT_EXECUTABLE}" ]]
  then
    # COFFEEBREWER_LIBRARY is set by bin/coffee
    # shellcheck disable=SC2154
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

homebrew-update-reset() {
  local option
  local DIR
  local -a REPOS=()

  for option in "$@"
  do
    if homebrew-command-help update-reset "${option}"
    then
      exit $?
    fi
    if homebrew-command-common-option "${option}"
    then
      continue
    fi

    case "${option}" in
      -*) homebrew-command-common-short-options "${option}" ;;
      *)
        if [[ -d "${option}/.git" ]]
        then
          REPOS+=("${option}")
        else
          onoe "${option} is not a Git repository!"
          coffee help update-reset
          exit 1
        fi
        ;;
    esac
  done

  homebrew-command-enable-debug

  if [[ -z "${REPOS[*]}" ]]
  then
    # COFFEEBREWER_REPOSITORY is set by bin/coffee
    # shellcheck disable=SC2154
    REPOS+=("${COFFEEBREWER_REPOSITORY}" "${COFFEEBREWER_LIBRARY}"/Taps/*/*)
  fi

  for DIR in "${REPOS[@]}"
  do
    [[ -d "${DIR}/.git" ]] || continue
    if ! git -C "${DIR}" config --local --get remote.origin.url &>/dev/null
    then
      opoo "No remote 'origin' in ${DIR}, skipping update and reset!"
      continue
    fi
    git -C "${DIR}" config --bool core.autocrlf false
    git -C "${DIR}" config --bool core.symlinks true
    ohai "Fetching ${DIR}..."
    git -C "${DIR}" fetch --force --tags origin
    git -C "${DIR}" remote set-head origin --auto >/dev/null
    echo

    ohai "Resetting ${DIR}..."
    # COFFEEBREWER_* variables here may all be set by bin/coffee or the user
    # shellcheck disable=SC2154
    if [[ "${DIR}" == "${COFFEEBREWER_REPOSITORY}" &&
       (-n "${COFFEEBREWER_UPDATE_TO_TAG}" ||
       (-z "${COFFEEBREWER_DEVELOPER}" && -z "${COFFEEBREWER_DEV_CMD_RUN}")) ]]
    then
      local latest_git_tag
      latest_git_tag="$(git -C "${DIR}" tag --list --sort="-version:refname" | head -n1)"

      git -C "${DIR}" checkout --force -B stable "refs/tags/${latest_git_tag}"
    else
      head="$(git -C "${DIR}" symbolic-ref refs/remotes/origin/HEAD)"
      head="${head#refs/remotes/origin/}"
      git -C "${DIR}" checkout --force -B "${head}" origin/HEAD
    fi
    rm -rf "${DIR}/.git/describe-cache"
    echo
  done
}
