# Operating system detection, default paths and OS-specific behaviour.
# This is sourced first by coffee.sh so only fast, fork-free code may run at
# source time: commands like `coffee shellenv` need everything defined here.

# COFFEEBREWER_* variables set here are used across CoffeeBrewery's Bash scripts.
# shellcheck disable=SC2034
# HOME is set by bin/coffee and the remaining variables by the user environment.
# shellcheck disable=SC2154

case "${MACHTYPE}" in
  arm64-* | aarch64-*)
    COFFEEBREWER_PROCESSOR="arm64"
    ;;
  x86_64-*)
    COFFEEBREWER_PROCESSOR="x86_64"
    ;;
  *)
    COFFEEBREWER_PROCESSOR="$(uname -m)"
    ;;
esac

case "${OSTYPE}" in
  darwin*)
    COFFEEBREWER_SYSTEM="Darwin"
    COFFEEBREWER_MACOS="1"
    ;;
  linux*)
    COFFEEBREWER_SYSTEM="Linux"
    COFFEEBREWER_LINUX="1"
    ;;
  *)
    COFFEEBREWER_SYSTEM="$(uname -s)"
    ;;
esac
COFFEEBREWER_PHYSICAL_PROCESSOR="${COFFEEBREWER_PROCESSOR}"

COFFEEBREWER_MACOS_ARM_DEFAULT_PREFIX="/opt/homebrew"
COFFEEBREWER_LINUX_DEFAULT_PREFIX="/home/linuxbrew/.linuxbrew"
COFFEEBREWER_GENERIC_DEFAULT_PREFIX="/usr/local"
if [[ -n "${COFFEEBREWER_MACOS}" && "${COFFEEBREWER_PROCESSOR}" == "arm64" ]]
then
  COFFEEBREWER_DEFAULT_PREFIX="${COFFEEBREWER_MACOS_ARM_DEFAULT_PREFIX}"
  COFFEEBREWER_DEFAULT_REPOSITORY="${COFFEEBREWER_MACOS_ARM_DEFAULT_PREFIX}"
elif [[ -n "${COFFEEBREWER_LINUX}" ]]
then
  COFFEEBREWER_DEFAULT_PREFIX="${COFFEEBREWER_LINUX_DEFAULT_PREFIX}"
  COFFEEBREWER_DEFAULT_REPOSITORY="${COFFEEBREWER_LINUX_DEFAULT_PREFIX}/CoffeeBrewery"
else
  COFFEEBREWER_DEFAULT_PREFIX="${COFFEEBREWER_GENERIC_DEFAULT_PREFIX}"
  COFFEEBREWER_DEFAULT_REPOSITORY="${COFFEEBREWER_GENERIC_DEFAULT_PREFIX}/CoffeeBrewery"
fi

if [[ -n "${COFFEEBREWER_MACOS}" ]]
then
  COFFEEBREWER_DEFAULT_CACHE="${HOME}/Library/Caches/CoffeeBrewery"
  COFFEEBREWER_DEFAULT_LOGS="${HOME}/Library/Logs/CoffeeBrewery"
  COFFEEBREWER_DEFAULT_TEMP="/private/tmp"
else
  CACHE_HOME="${COFFEEBREWER_XDG_CACHE_HOME:-${HOME}/.cache}"
  COFFEEBREWER_DEFAULT_CACHE="${CACHE_HOME}/CoffeeBrewery"
  COFFEEBREWER_DEFAULT_LOGS="${CACHE_HOME}/CoffeeBrewery/Logs"
  if [[ -r "/var/tmp" && -w "/var/tmp" ]]
  then
    COFFEEBREWER_DEFAULT_TEMP="/var/tmp"
  else
    COFFEEBREWER_DEFAULT_TEMP="/tmp"
  fi
fi

# coffee shellenv needs COFFEEBREWER_MACOS_VERSION_NUMERIC
if [[ -n "${COFFEEBREWER_MACOS}" ]]
then
  # Read ProductVersion directly to avoid forking `sw_vers`, which reads the
  # same file but costs several milliseconds on every invocation.
  COFFEEBREWER_MACOS_VERSION=""
  SYSTEM_VERSION_PLIST="/System/Library/CoreServices/SystemVersion.plist"
  SYSTEM_VERSION_PRODUCT_VERSION_KEY=""
  while IFS= read -r SYSTEM_VERSION_PLIST_LINE
  do
    if [[ -n "${SYSTEM_VERSION_PRODUCT_VERSION_KEY}" ]]
    then
      COFFEEBREWER_MACOS_VERSION="${SYSTEM_VERSION_PLIST_LINE#*<string>}"
      COFFEEBREWER_MACOS_VERSION="${COFFEEBREWER_MACOS_VERSION%%</string>*}"
      break
    fi
    [[ "${SYSTEM_VERSION_PLIST_LINE}" == *"<key>ProductVersion</key>"* ]] && SYSTEM_VERSION_PRODUCT_VERSION_KEY="1"
  done 2>/dev/null <"${SYSTEM_VERSION_PLIST}"
  MACOS_VERSION_REGEX="^[0-9.]+$"
  if ! [[ "${COFFEEBREWER_MACOS_VERSION}" =~ ${MACOS_VERSION_REGEX} ]]
  then
    COFFEEBREWER_MACOS_VERSION="$(/usr/bin/sw_vers -productVersion)"
  fi
  unset SYSTEM_VERSION_PLIST SYSTEM_VERSION_PLIST_LINE SYSTEM_VERSION_PRODUCT_VERSION_KEY MACOS_VERSION_REGEX

  IFS=. read -r -a MACOS_VERSION_ARRAY < <(printf '%s' "${COFFEEBREWER_MACOS_VERSION}")
  printf -v COFFEEBREWER_MACOS_VERSION_NUMERIC "%02d%02d%02d" "${MACOS_VERSION_ARRAY[@]}"

  unset MACOS_VERSION_ARRAY
fi

# Force UTF-8 to avoid encoding issues for users with broken locale settings.
# Validate the active locale's charmap rather than trusting its name before
# selecting a usable fallback.
setup-locale() {
  local locales c_utf_regex en_us_regex utf_regex
  if [[ -z "${COFFEEBREWER_MACOS}" ]]
  then
    [[ -z "${COFFEEBREWER_LANG:-}" ]] || export LANG="${COFFEEBREWER_LANG}"
    [[ -z "${COFFEEBREWER_LC_CTYPE:-}" ]] || export LC_CTYPE="${COFFEEBREWER_LC_CTYPE}"
    [[ -z "${COFFEEBREWER_LC_ALL:-}" ]] || export LC_ALL="${COFFEEBREWER_LC_ALL}"
  fi
  unset COFFEEBREWER_LANG COFFEEBREWER_LC_CTYPE COFFEEBREWER_LC_ALL

  if [[ -n "${COFFEEBREWER_MACOS}" ]]
  then
    if [[ -z "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" ]] || [[ "$(locale charmap)" != "UTF-8" ]]
    then
      export LC_ALL="en_US.UTF-8"
    fi
  else
    if ! command -v locale >/dev/null
    then
      export LC_ALL=C
    elif [[ "$(locale charmap)" != "UTF-8" ]]
    then
      locales="$(locale -a)"
      c_utf_regex='\bC\.(utf8|UTF-8)\b'
      en_us_regex='\ben_US\.(utf8|UTF-8)\b'
      utf_regex='\b[a-z][a-z]_[A-Z][A-Z]\.(utf8|UTF-8)\b'
      if [[ ${locales} =~ ${c_utf_regex} || ${locales} =~ ${en_us_regex} || ${locales} =~ ${utf_regex} ]]
      then
        export LC_ALL="${BASH_REMATCH[0]}"
      else
        export LC_ALL=C
      fi
    fi
  fi
}

# Derive the OS-specific product naming and user agent details and check the
# OS version and hardware are supported.
setup-os-details() {
  local MACOS_VERSION_ARRAY
  if [[ -n "${COFFEEBREWER_MACOS}" ]]
  then
    COFFEEBREWER_PRODUCT="CoffeeBrewery"
    COFFEEBREWER_SYSTEM="Macintosh"
    [[ "${COFFEEBREWER_PROCESSOR}" == "x86_64" ]] && COFFEEBREWER_PROCESSOR="Intel"
    # Don't change this from Mac OS X to match what macOS itself does in Safari
    COFFEEBREWER_OS_USER_AGENT_VERSION="Mac OS X ${COFFEEBREWER_MACOS_VERSION}"

    # `sysctl` is only needed to detect Rosetta so don't fork it on ARM.
    if [[ "${COFFEEBREWER_PHYSICAL_PROCESSOR}" == "x86_64" ]] &&
       [[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" == "1" ]]
    then
      # used in vendor-install.sh and update.sh
      COFFEEBREWER_PHYSICAL_PROCESSOR="arm64"
    fi

    IFS=. read -r -a MACOS_VERSION_ARRAY < <(printf '%s' "${COFFEEBREWER_MACOS_OLDEST_ALLOWED}")
    printf -v COFFEEBREWER_MACOS_OLDEST_ALLOWED_NUMERIC "%02d%02d%02d" "${MACOS_VERSION_ARRAY[@]}"

    COFFEEBREWER_OS_VERSION="macOS ${COFFEEBREWER_MACOS_VERSION%.*}"

    # Refuse to run on pre-Big Sur
    if [[ "${COFFEEBREWER_MACOS_VERSION_NUMERIC}" -lt "${COFFEEBREWER_MACOS_OLDEST_ALLOWED_NUMERIC}" ]]
    then
      printf "ERROR: Your version of macOS (%s) is too old to run CoffeeBrewery!\\n" "${COFFEEBREWER_MACOS_VERSION}" >&2
      printf "         For this macOS version see: https://www.macports.org\\n" >&2
      printf "\\n" >&2
    fi

  else
    if [[ -r "/proc/cpuinfo" ]] &&
       [[ "${COFFEEBREWER_PROCESSOR}" == "x86_64" ]]
    then
      if ! grep -qE '^(flags|Features).*\bssse3\b' /proc/cpuinfo
      then
        odie "CoffeeBrewery's x86_64 support on Linux requires a CPU with SSSE3 support!"
      fi
    fi

    COFFEEBREWER_PRODUCT="${COFFEEBREWER_SYSTEM}coffee"
    # Don't try to follow /etc/os-release
    # shellcheck disable=SC1091
    [[ -n "${COFFEEBREWER_LINUX}" ]] && COFFEEBREWER_OS_VERSION="$(source /etc/os-release && echo "${PRETTY_NAME}")"
    : "${COFFEEBREWER_OS_VERSION:=$(uname -r)}"
    COFFEEBREWER_OS_USER_AGENT_VERSION="${COFFEEBREWER_OS_VERSION}"

    COFFEEBREWER_LINUX_MINIMUM_GLIBC_VERSION="2.13"
  fi
}
