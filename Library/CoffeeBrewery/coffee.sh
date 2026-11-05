#####
##### First do the essential, fast things to ensure commands like `coffee --prefix` and others that we want
##### to be able to `source` in shell configurations run quickly.
#####

# COFFEEBREWER_LIBRARY is set by bin/coffee
# shellcheck disable=SC2154
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/os.sh"

# Prevent other staff members from modifying new files, including subprocess output.
# Keep in sync with CoffeeBrewery/install's install.sh and package/scripts/postinstall.
if [[ -n "${COFFEEBREWER_MACOS}" && "$(id -gn)" == staff && " $(id -Gn) " != *" admin "* ]]
then
  umask go-w
fi

realpath() {
  (cd "$1" &>/dev/null && pwd -P)
}

# Support systems where COFFEEBREWER_PREFIX is the default,
# but a parent directory is a symlink.
# Example: Fedora Silverblue symlinks /home -> /var/home
if [[ "${COFFEEBREWER_PREFIX}" != "${COFFEEBREWER_DEFAULT_PREFIX}" && "$(realpath "${COFFEEBREWER_DEFAULT_PREFIX}")" == "${COFFEEBREWER_PREFIX}" ]]
then
  COFFEEBREWER_PREFIX="${COFFEEBREWER_DEFAULT_PREFIX}"
fi

# Support systems where COFFEEBREWER_REPOSITORY is the default,
# but a parent directory is a symlink.
# Example: Fedora Silverblue symlinks /home -> var/home
if [[ "${COFFEEBREWER_REPOSITORY}" != "${COFFEEBREWER_DEFAULT_REPOSITORY}" && "$(realpath "${COFFEEBREWER_DEFAULT_REPOSITORY}")" == "${COFFEEBREWER_REPOSITORY}" ]]
then
  COFFEEBREWER_REPOSITORY="${COFFEEBREWER_DEFAULT_REPOSITORY}"
fi

# Where we store built products; a Cellar in COFFEEBREWER_PREFIX (often /usr/local
# for bottles) unless there's already a Cellar in COFFEEBREWER_REPOSITORY.
# These variables are set by bin/coffee
# shellcheck disable=SC2154
if [[ -d "${COFFEEBREWER_REPOSITORY}/Cellar" ]]
then
  COFFEEBREWER_CELLAR="${COFFEEBREWER_REPOSITORY}/Cellar"
else
  COFFEEBREWER_CELLAR="${COFFEEBREWER_PREFIX}/Cellar"
fi

# Support systems where COFFEEBREWER_CELLAR's parent directory is a symlink.
# Example: Fedora Silverblue symlinks /home -> /var/home
COFFEEBREWER_CELLAR_DEFAULT_PREFIX="${COFFEEBREWER_DEFAULT_PREFIX}/Cellar"
if [[ "${COFFEEBREWER_CELLAR}" != "${COFFEEBREWER_CELLAR_DEFAULT_PREFIX}" && "$(realpath "${COFFEEBREWER_CELLAR_DEFAULT_PREFIX}")" == "${COFFEEBREWER_CELLAR}" ]]
then
  COFFEEBREWER_CELLAR="${COFFEEBREWER_CELLAR_DEFAULT_PREFIX}"
fi

COFFEEBREWER_CASKROOM="${COFFEEBREWER_PREFIX}/Caskroom"

COFFEEBREWER_CACHE="${COFFEEBREWER_CACHE:-${COFFEEBREWER_DEFAULT_CACHE}}"
COFFEEBREWER_LOGS="${COFFEEBREWER_LOGS:-${COFFEEBREWER_DEFAULT_LOGS}}"
COFFEEBREWER_TEMP="${COFFEEBREWER_TEMP:-${COFFEEBREWER_DEFAULT_TEMP}}"
if [[ ! -w "${COFFEEBREWER_TEMP}" ]]
then
  COFFEEBREWER_TEMP="${COFFEEBREWER_DEFAULT_TEMP}"
fi

# commands that take a single or no arguments.
# COFFEEBREWER_LIBRARY set by bin/coffee
# shellcheck disable=SC2154
# doesn't need a default case as other arguments handled elsewhere.
# shellcheck disable=SC2249
case "$1" in
  formulae)
    if [[ -z "${COFFEEBREWER_FORCE_RUBY_COMMAND:-}" ]]
    then
      source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/formulae.sh"
      homebrew-formulae
      exit 0
    fi
    ;;
  casks)
    if [[ -z "${COFFEEBREWER_FORCE_RUBY_COMMAND:-}" ]]
    then
      source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/casks.sh"
      homebrew-casks
      exit 0
    fi
    ;;
  shellenv)
    source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/shellenv.sh"
    shift
    homebrew-shellenv "$1"
    exit 0
    ;;
esac

source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/help.sh"

# functions that take multiple arguments or handle multiple commands.
# doesn't need a default case as other arguments handled elsewhere.
# shellcheck disable=SC2249
case "$@" in
  --cellar)
    echo "${COFFEEBREWER_CELLAR}"
    exit 0
    ;;
  --repository | --repo)
    echo "${COFFEEBREWER_REPOSITORY}"
    exit 0
    ;;
  --caskroom)
    echo "${COFFEEBREWER_CASKROOM}"
    exit 0
    ;;
  --cache)
    echo "${COFFEEBREWER_CACHE}"
    exit 0
    ;;
  --taps)
    source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/--taps.sh"
    homebrew---taps "$@" && exit 0
    ;;
  # falls back to cmd/--prefix.rb and cmd/--cellar.rb on a non-zero return
  --prefix* | --cellar*)
    source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/formula_path.sh"
    homebrew-formula-path "$@" && exit 0
    ;;
  # falls back to cmd/command.rb on a non-zero return
  command*)
    source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/command_path.sh"
    homebrew-command-path "$@" && exit 0
    ;;
  # falls back to cmd/list.rb on a non-zero return
  list* | ls*)
    source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/list.sh"
    homebrew-list "$@" && exit 0
    ;;
  # homebrew-tap only handles invocations with no arguments
  tap)
    source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/tap.sh"
    homebrew-tap "$@"
    exit 0
    ;;
  # falls back to cmd/help.rb on a non-zero return
  help | --help | -h | --usage | "-?" | "")
    homebrew-help "$@" && exit 0
    ;;
esac

# commands that take a single or no arguments and need to write to COFFEEBREWER_PREFIX.
# COFFEEBREWER_LIBRARY set by bin/coffee
# shellcheck disable=SC2154
# doesn't need a default case as other arguments handled elsewhere.
# shellcheck disable=SC2249
case "$1" in
  setup-ruby)
    source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/setup-ruby.sh"
    shift
    homebrew-setup-ruby "$1"
    exit 0
    ;;
esac

#####
##### Next, define all other helper functions.
#####

source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils.sh"

check-run-command-as-root() {
  [[ "${EUID}" == 0 ]] || return

  # Allow Azure Pipelines/GitHub Actions/Docker/Podman/Concourse/Kubernetes to do everything as root (as it's normal there)
  [[ -f /.dockerenv ]] && return
  [[ -f /run/.containerenv ]] && return
  [[ -f /proc/1/cgroup ]] && grep -E "azpl_job|actions_job|docker|garden|kubepods" -q /proc/1/cgroup && return

  # These commands immediately dispatch as the selected user, including when
  # invoked by root-owned MDM/Munki/Jamf workflows.
  [[ "${COFFEEBREWER_COMMAND}" == "as-console-user" || "${COFFEEBREWER_COMMAND}" == "as-coffee-user" ]] && return

  # `coffee setup-sandbox` is intended to be run with `sudo` to prepare the
  # CoffeeBrewery sandbox.
  [[ "${COFFEEBREWER_COMMAND}" == "setup-sandbox" ]] && return

  # `coffee services` may need `sudo` for system-wide daemons.
  if [[ "${COFFEEBREWER_COMMAND}" == "services" ]]
  then
    # Need to disable Bootsnap when running as root to avoid permission errors:
    # https://github.com/CoffeeBrewery/coffee/issues/19904
    export COFFEEBREWER_NO_BOOTSNAP="1"

    return
  fi

  # It's fine to run this as root as it's not changing anything.
  [[ "${COFFEEBREWER_COMMAND}" == "--prefix" ]] && return

  odie <<EOS
Running CoffeeBrewery as root is extremely dangerous and no longer supported.
As CoffeeBrewery does not drop privileges on installation you would be giving all
build scripts full access to your system.
EOS
}

check-prefix-is-not-tmpdir() {
  [[ -z "${COFFEEBREWER_MACOS}" ]] && return

  if [[ "${COFFEEBREWER_PREFIX}" == "${COFFEEBREWER_TEMP}"* ]]
  then
    odie <<EOS
Your COFFEEBREWER_PREFIX is in the CoffeeBrewery temporary directory, which CoffeeBrewery
uses to store downloads and builds. You can resolve this by installing CoffeeBrewery
to either the standard prefix for your platform or to a non-standard prefix that
is not in the CoffeeBrewery temporary directory.
EOS
  fi
}

source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/auto-update.sh"

# Only `coffee update-if-needed` should be handled here.
# We want it as fast as possible but it needs auto-update() defined above.
# COFFEEBREWER_LIBRARY set by bin/coffee
# shellcheck disable=SC2154
# doesn't need a default case as other arguments handled elsewhere.
# shellcheck disable=SC2249
# Don't need to pass through any arguments.
# shellcheck disable=SC2119
case "$@" in
  update-if-needed)
    source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/update-if-needed.sh"
    homebrew-update-if-needed
    exit 0
    ;;
esac

#####
##### Setup output so e.g. odie looks as nice as possible.
#####

# Colorize output on GitHub Actions.
# This is set by the user environment.
# shellcheck disable=SC2154
if [[ -n "${GITHUB_ACTIONS}" ]]
then
  export COFFEEBREWER_COLOR="1"
fi

setup-locale

#####
##### odie as quickly as possible.
#####

if [[ "${COFFEEBREWER_PREFIX}" == "/" || "${COFFEEBREWER_PREFIX}" == "/usr" ]]
then
  # it may work, but I only see pain this route and don't want to support it
  odie "Cowardly refusing to continue at this prefix: ${COFFEEBREWER_PREFIX}"
fi

#####
##### Now, do everything else (that may be a bit slower).
#####

# Docker image deprecation
if [[ -f "${COFFEEBREWER_REPOSITORY}/.docker-deprecate" && -z "${COFFEEBREWER_TESTS}" ]]
then
  read -r DOCKER_DEPRECATION_MESSAGE <"${COFFEEBREWER_REPOSITORY}/.docker-deprecate"
  if [[ -n "${GITHUB_ACTIONS}" ]]
  then
    echo "::warning::${DOCKER_DEPRECATION_MESSAGE}" >&2
  else
    opoo "${DOCKER_DEPRECATION_MESSAGE}"
  fi
fi

# USER isn't always set so provide a fall back for `coffee` and subprocesses.
export USER="${USER:-$(id -un)}"

# A depth of 1 means this command was directly invoked by a user.
# Higher depths mean this command was invoked by another CoffeeBrewery command.
export COFFEEBREWER_COMMAND_DEPTH="$((COFFEEBREWER_COMMAND_DEPTH + 1))"

source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/curl.sh"
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/git.sh"

setup_git
read-homebrew-git-config
set-homebrew-version-from-git

COFFEEBREWER_USER_AGENT_VERSION="${COFFEEBREWER_VERSION}"
if [[ -z "${COFFEEBREWER_VERSION}" ]]
then
  COFFEEBREWER_VERSION=">=4.3.0 (shallow or no git repository)"
  COFFEEBREWER_USER_AGENT_VERSION="4.X.Y"
fi

COFFEEBREWER_CORE_REPOSITORY="${COFFEEBREWER_LIBRARY}/Taps/coffeebrewery/coffeebrewery-core"
# Used in --version.sh
# shellcheck disable=SC2034
COFFEEBREWER_CASK_REPOSITORY="${COFFEEBREWER_LIBRARY}/Taps/coffeebrewery/coffeebrewery-cask"

# Shift the -v to the end of the parameter list
if [[ "$1" == "-v" ]]
then
  shift
  set -- "$@" -v
fi

# commands that take a single or no arguments.
# doesn't need a default case as other arguments handled elsewhere.
# shellcheck disable=SC2249
case "$1" in
  --version | -v)
    source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/--version.sh"
    homebrew-version
    exit 0
    ;;
  mcp-server)
    source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/mcp-server.sh"
    homebrew-mcp-server "$@"
    exit 0
    ;;
esac

setup_curl

COFFEEBREWER_API_DEFAULT_DOMAIN="https://formulae.brew.sh/api"
COFFEEBREWER_BOTTLE_DEFAULT_DOMAIN="https://l1cr.lusd1.org/homebrew/core"

# TODO: bump version when new macOS is released or announced and update references in:
# - docs/Installation.md
# - https://github.com/CoffeeBrewery/install/blob/HEAD/install.sh
# - Library/CoffeeBrewery/os/mac.rb (latest_sdk_version)
# - Library/CoffeeBrewery/os/mac/xcode.rb (latest_version), (minimum_version)
# - Library/CoffeeBrewery/os/mac/xcode.rb (latest_clang_version)
# and, if needed:
# - MacOSVersion::RELEASES
COFFEEBREWER_MACOS_NEWEST_UNSUPPORTED="28"
# TODO: bump version when new macOS is released
COFFEEBREWER_MACOS_NEWEST_SUPPORTED="27"
# TODO: bump version when new macOS is released and update references in:
# - docs/Installation.md
# - COFFEEBREWER_MACOS_OLDEST_SUPPORTED in .github/workflows/release.yml
# - `os-version min` in package/Distribution.xml
# - https://github.com/CoffeeBrewery/install/blob/HEAD/install.sh
COFFEEBREWER_MACOS_OLDEST_SUPPORTED="15"
COFFEEBREWER_MACOS_OLDEST_ALLOWED="11"

setup-os-details
check-curl-version
check-git-version

setup_ca_certificates

# Redetermine curl and git paths as we may have forced some options above.
setup_curl
setup_git

# A bug in the auto-update process prior to 3.1.2 means $COFFEEBREWER_BOTTLE_DOMAIN
# could be passed down with the default domain.
# This is problematic as this is will be the old bottle domain.
# This workaround is necessary for many CI images starting on old version,
# and will only be unnecessary when updating from <3.1.2 is not a concern.
# That will be when macOS 12 is the minimum required version.
# COFFEEBREWER_BOTTLE_DOMAIN is set from the user environment
# shellcheck disable=SC2154
if [[ -n "${COFFEEBREWER_BOTTLE_DEFAULT_DOMAIN}" ]] &&
   [[ "${COFFEEBREWER_BOTTLE_DOMAIN}" == "${COFFEEBREWER_BOTTLE_DEFAULT_DOMAIN}" ]]
then
  unset COFFEEBREWER_BOTTLE_DOMAIN
fi

setup-user-agents

export COFFEEBREWER_HELP_MESSAGE
export COFFEEBREWER_VERSION
export COFFEEBREWER_MACOS_ARM_DEFAULT_PREFIX
export COFFEEBREWER_LINUX_DEFAULT_PREFIX
export COFFEEBREWER_GENERIC_DEFAULT_PREFIX
export COFFEEBREWER_DEFAULT_PREFIX
export COFFEEBREWER_DEFAULT_REPOSITORY
export COFFEEBREWER_DEFAULT_CACHE
export COFFEEBREWER_CACHE
export COFFEEBREWER_DEFAULT_LOGS
export COFFEEBREWER_LOGS
export COFFEEBREWER_DEFAULT_TEMP
export COFFEEBREWER_TEMP
export COFFEEBREWER_CELLAR
export COFFEEBREWER_CASKROOM
export COFFEEBREWER_SYSTEM
export COFFEEBREWER_CURL
export COFFEEBREWER_BREWED_CURL_PATH
export COFFEEBREWER_SYSTEM_CURL_TOO_OLD
export COFFEEBREWER_CURL_SUPPORTS_ETAGS
export COFFEEBREWER_GIT
export COFFEEBREWER_MINIMUM_CURL_VERSION
export COFFEEBREWER_MINIMUM_GIT_VERSION
export COFFEEBREWER_LINUX_MINIMUM_GLIBC_VERSION
export COFFEEBREWER_PHYSICAL_PROCESSOR
export COFFEEBREWER_PROCESSOR
export COFFEEBREWER_OS_VERSION
export COFFEEBREWER_MACOS_VERSION
export COFFEEBREWER_MACOS_VERSION_NUMERIC
export COFFEEBREWER_MACOS_NEWEST_UNSUPPORTED
export COFFEEBREWER_MACOS_NEWEST_SUPPORTED
export COFFEEBREWER_MACOS_OLDEST_SUPPORTED
export COFFEEBREWER_MACOS_OLDEST_ALLOWED
export COFFEEBREWER_USER_AGENT
export COFFEEBREWER_USER_AGENT_CURL
export COFFEEBREWER_API_DEFAULT_DOMAIN
export COFFEEBREWER_BOTTLE_DEFAULT_DOMAIN
export COFFEEBREWER_CURL_SPEED_LIMIT
export COFFEEBREWER_CURL_SPEED_TIME

if [[ -n "${COFFEEBREWER_MACOS}" && -x "/usr/bin/xcode-select" ]]
then
  XCODE_SELECT_PATH="$('/usr/bin/xcode-select' --print-path 2>/dev/null)"
  if [[ "${XCODE_SELECT_PATH}" == "/" ]]
  then
    odie <<EOS
Your xcode-select path is currently set to '/'.
This causes the 'xcrun' tool to hang, and can render CoffeeBrewery unusable.
If you are using Xcode, you should:
  sudo xcode-select --switch /Applications/Xcode.app
Otherwise, you should:
  sudo rm -rf /usr/share/xcode-select
EOS
  fi

  # Don't check xcrun if Xcode and the CLT aren't installed, as that opens
  # a popup window asking the user to install the CLT
  if [[ -n "${XCODE_SELECT_PATH}" ]]
  then
    XCRUN_OUTPUT="$(/usr/bin/xcrun --find clang 2>&1)"
    XCRUN_STATUS="$?"

    if [[ "${XCRUN_STATUS}" -ne 0 && "${XCRUN_OUTPUT}" == *license* ]]
    then
      odie <<EOS
You have not agreed to the Xcode license. Please resolve this by running:
  sudo xcodebuild -license accept
EOS
    fi
  fi
fi

for arg in "$@"
do
  [[ "${arg}" == "--" ]] && break

  if [[ "${arg}" == "--help" || "${arg}" == "-h" || "${arg}" == "--usage" || "${arg}" == "-?" ]]
  then
    export COFFEEBREWER_HELP="1"
    break
  fi
done

COFFEEBREWER_ARG_COUNT="$#"
COFFEEBREWER_COMMAND="$1"
shift
# If you are going to change anything in below case statement,
# be sure to also update COFFEEBREWER_INTERNAL_COMMAND_ALIASES hash in commands.rb
# doesn't need a default case as other arguments handled elsewhere.
# shellcheck disable=SC2249
case "${COFFEEBREWER_COMMAND}" in
  ls) COFFEEBREWER_COMMAND="list" ;;
  homepage) COFFEEBREWER_COMMAND="home" ;;
  -S) COFFEEBREWER_COMMAND="search" ;;
  up) COFFEEBREWER_COMMAND="update" ;;
  ln) COFFEEBREWER_COMMAND="link" ;;
  instal) COFFEEBREWER_COMMAND="install" ;; # gem does the same
  uninstal) COFFEEBREWER_COMMAND="uninstall" ;;
  post_install) COFFEEBREWER_COMMAND="postinstall" ;;
  rm) COFFEEBREWER_COMMAND="uninstall" ;;
  remove) COFFEEBREWER_COMMAND="uninstall" ;;
  abv) COFFEEBREWER_COMMAND="info" ;;
  dr) COFFEEBREWER_COMMAND="doctor" ;;
  --repo) COFFEEBREWER_COMMAND="--repository" ;;
  environment) COFFEEBREWER_COMMAND="--env" ;;
  --config) COFFEEBREWER_COMMAND="config" ;;
  -v) COFFEEBREWER_COMMAND="--version" ;;
  lc) COFFEEBREWER_COMMAND="livecheck" ;;
  tc) COFFEEBREWER_COMMAND="typecheck" ;;
  x) COFFEEBREWER_COMMAND="exec" ;;
esac

# Keep in sync with `Commands.internal_cmd_name?` in `commands.rb`.
if [[ "${COFFEEBREWER_COMMAND}" == */* || "${COFFEEBREWER_COMMAND}" == "." || "${COFFEEBREWER_COMMAND}" == ".." ]]
then
  odie "Unknown command: coffee ${COFFEEBREWER_COMMAND}"
fi
# `update.sh` assumes normal repositories, so fail before it mutates a worktree.
if [[ "${COFFEEBREWER_COMMAND}" == "update" && -z "${COFFEEBREWER_HELP}" && -f "${COFFEEBREWER_REPOSITORY}/.git" ]]
then
  for arg in "$@"
  do
    [[ "${arg}" == "--auto-update" ]] && exit 0
  done
  odie "Cannot \`coffee update\` in a CoffeeBrewery/coffee Git worktree."
fi
if [[ ("${COFFEEBREWER_COMMAND}" == "audit" || "${COFFEEBREWER_COMMAND}" == "lgtm" ||
      "${COFFEEBREWER_COMMAND}" == "style" || "${COFFEEBREWER_COMMAND}" == "tests") &&
      "${COFFEEBREWER_CACHE}" != "${COFFEEBREWER_REPOSITORY}/tmp/cache" ]]
then
  if [[ -d "${COFFEEBREWER_CACHE}" && ! -w "${COFFEEBREWER_CACHE}" ]] ||
     [[ ! -d "${COFFEEBREWER_CACHE}" && ! -w "${COFFEEBREWER_CACHE%/*}" ]]
  then
    original_cache="${COFFEEBREWER_CACHE}"
    COFFEEBREWER_CACHE="${COFFEEBREWER_REPOSITORY}/tmp/cache"
    printf 'Warning: COFFEEBREWER_CACHE is not writable at %s; using %s for CoffeeBrewery cache files instead.\n' \
      "${original_cache}" "${COFFEEBREWER_CACHE}" >&2
    mkdir -p "${COFFEEBREWER_CACHE}/api"
    if [[ -d "${original_cache}/api" ]]
    then
      cp -R "${original_cache}/api/." "${COFFEEBREWER_CACHE}/api/" &>/dev/null || true
    fi
    export COFFEEBREWER_CACHE
  fi
fi

# Set COFFEEBREWER_DEV_CMD_RUN for users who have run a development command.
# This makes them behave like COFFEEBREWER_DEVELOPERs for coffee update.
if [[ -z "${COFFEEBREWER_DEVELOPER}" ]]
then
  export COFFEEBREWER_GIT_CONFIG_FILE
  if [[ "${COFFEEBREWER_GIT_CONFIG_DEVCMDRUN}" == "true" ]]
  then
    export COFFEEBREWER_DEV_CMD_RUN="1"
  fi

  # Don't allow non-developers to customise Ruby warnings.
  unset COFFEEBREWER_RUBY_WARNINGS
fi

setup-auto-update

if [[ -z "${COFFEEBREWER_RUBY_WARNINGS}" ]]
then
  export COFFEEBREWER_RUBY_WARNINGS="-W1"
fi

export COFFEEBREWER_BREW_DEFAULT_GIT_REMOTE="https://github.com/CoffeeBrewery/coffee"
if [[ -z "${COFFEEBREWER_BREW_GIT_REMOTE}" ]]
then
  COFFEEBREWER_BREW_GIT_REMOTE="${COFFEEBREWER_BREW_DEFAULT_GIT_REMOTE}"
fi
export COFFEEBREWER_BREW_GIT_REMOTE

export COFFEEBREWER_CORE_DEFAULT_GIT_REMOTE="https://github.com/CoffeeBrewery/homebrew-core"
if [[ -z "${COFFEEBREWER_CORE_GIT_REMOTE}" ]]
then
  COFFEEBREWER_CORE_GIT_REMOTE="${COFFEEBREWER_CORE_DEFAULT_GIT_REMOTE}"
fi
export COFFEEBREWER_CORE_GIT_REMOTE

# Set COFFEEBREWER_DEVELOPER_COMMAND if the command being run is a developer command
unset COFFEEBREWER_DEVELOPER_COMMAND
if [[ -f "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/dev-cmd/${COFFEEBREWER_COMMAND}.sh" ]] ||
   [[ -f "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/dev-cmd/${COFFEEBREWER_COMMAND}.rb" ]]
then
  export COFFEEBREWER_DEVELOPER_COMMAND="1"
fi

if [[ -n "${COFFEEBREWER_DEVELOPER_COMMAND}" && -z "${COFFEEBREWER_DEVELOPER}" && -z "${COFFEEBREWER_DEV_CMD_RUN}" ]]
then
  opoo <<EOS
$(bold "${COFFEEBREWER_COMMAND}") is a developer command, so CoffeeBrewery's
developer mode has been automatically turned on.
To turn developer mode off, run:
  coffee developer off

EOS

  git config --file="${COFFEEBREWER_GIT_CONFIG_FILE}" --replace-all homebrew.devcmdrun true 2>/dev/null
  export COFFEEBREWER_DEV_CMD_RUN="1"
fi

# Enable features for developers and CI before they become the default for everyone.
if [[ -n "${COFFEEBREWER_DEVELOPER}" ]]
then
  :
fi

# Enable features for users who have run a devcmd before they become the default for everyone.
if [[ -n "${COFFEEBREWER_DEVELOPER}" || -n "${COFFEEBREWER_DEV_CMD_RUN}" ]]
then
  :
fi

# Keep in sync with `CoffeeBrewery::DevCmd::Tests#setup_environment!`.
if [[ -n "${COFFEEBREWER_TESTS_NO_SORBET_RUNTIME}" ]]
then
  unset COFFEEBREWER_SORBET_RUNTIME COFFEEBREWER_SORBET_RECURSIVE
# Only enable runtime typechecking for commands where correctness matters more
# than performance.
elif [[ "${COFFEEBREWER_COMMAND}" == "test" || "${COFFEEBREWER_COMMAND}" == "test-bot" ||
        "${COFFEEBREWER_COMMAND}" == "tests" ]]
then
  export COFFEEBREWER_SORBET_RUNTIME="1"
fi

if [[ -z "${COFFEEBREWER_FORCE_RUBY_COMMAND:-}" && -f "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/${COFFEEBREWER_COMMAND}.sh" ]]
then
  COFFEEBREWER_BASH_COMMAND="${COFFEEBREWER_LIBRARY}/CoffeeBrewery/cmd/${COFFEEBREWER_COMMAND}.sh"
elif [[ -z "${COFFEEBREWER_FORCE_RUBY_COMMAND:-}" && -f "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/dev-cmd/${COFFEEBREWER_COMMAND}.sh" ]]
then
  COFFEEBREWER_BASH_COMMAND="${COFFEEBREWER_LIBRARY}/CoffeeBrewery/dev-cmd/${COFFEEBREWER_COMMAND}.sh"
fi

check-run-command-as-root

check-prefix-is-not-tmpdir

if [[ "${COFFEEBREWER_PREFIX}" == "/usr/local" ]] &&
   [[ "${COFFEEBREWER_PREFIX}" != "${COFFEEBREWER_REPOSITORY}" ]] &&
   [[ "${COFFEEBREWER_CELLAR}" == "${COFFEEBREWER_REPOSITORY}/Cellar" ]]
then
  cat >&2 <<EOS
Warning: your COFFEEBREWER_PREFIX is set to /usr/local but COFFEEBREWER_CELLAR is set
to ${COFFEEBREWER_CELLAR}. Your current COFFEEBREWER_CELLAR location will stop
you being able to use all the binary packages (bottles) CoffeeBrewery provides. We
recommend you move your COFFEEBREWER_CELLAR to /usr/local/Cellar which will get you
access to all bottles.
EOS
fi

source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/analytics.sh"
setup-analytics

# Use this configuration file instead of ~/.ssh/config when fetching git over SSH.
if [[ -n "${COFFEEBREWER_SSH_CONFIG_PATH}" ]]
then
  export GIT_SSH_COMMAND="ssh -F${COFFEEBREWER_SSH_CONFIG_PATH}"
fi

if [[ -n "${COFFEEBREWER_DOCKER_REGISTRY_TOKEN}" ]]
then
  export COFFEEBREWER_GITHUB_PACKAGES_AUTH="Bearer ${COFFEEBREWER_DOCKER_REGISTRY_TOKEN}"
elif [[ -n "${COFFEEBREWER_DOCKER_REGISTRY_BASIC_AUTH_TOKEN}" ]]
then
  # If the token is to the special value "none", unset any existing auth to use anonymous access.
  if [[ "${COFFEEBREWER_DOCKER_REGISTRY_BASIC_AUTH_TOKEN}" == "none" ]]
  then
    unset COFFEEBREWER_GITHUB_PACKAGES_AUTH
  else
    export COFFEEBREWER_GITHUB_PACKAGES_AUTH="Basic ${COFFEEBREWER_DOCKER_REGISTRY_BASIC_AUTH_TOKEN}"
  fi
else
  export COFFEEBREWER_GITHUB_PACKAGES_AUTH="Bearer QQ=="
fi

# Remove internal variables
unset COFFEEBREWER_INTERNAL_ALLOW_PACKAGES_FROM_PATHS

if [[ -n "${COFFEEBREWER_BASH_COMMAND}" ]]
then
  # source rather than executing directly to ensure the entire file is read into
  # memory before it is run. This makes running a Bash script behave more like
  # a Ruby script and avoids hard-to-debug issues if the Bash script is updated
  # at the same time as being run.
  #
  # Shellcheck can't follow this dynamic `source`.
  # shellcheck disable=SC1090
  source "${COFFEEBREWER_BASH_COMMAND}"

  {
    auto-update "$@"
    "homebrew-${COFFEEBREWER_COMMAND}" "$@"
    exit $?
  }

else
  source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/ruby.sh"
  setup-ruby-path

  # Unshift command back into argument list (unless argument list was empty).
  [[ "${COFFEEBREWER_ARG_COUNT}" -gt 0 ]] && set -- "${COFFEEBREWER_COMMAND}" "$@"
  # COFFEEBREWER_RUBY_PATH set by utils/ruby.sh
  # shellcheck disable=SC2154
  {
    auto-update "$@"
    exec "${COFFEEBREWER_RUBY_PATH}" "${COFFEEBREWER_RUBY_WARNINGS}" "${COFFEEBREWER_RUBY_DISABLE_OPTIONS}" \
      "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/coffee.rb" "$@"
  }
fi
