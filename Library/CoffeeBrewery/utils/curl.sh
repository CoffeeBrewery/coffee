# curl selection and version checks plus CoffeeBrewery's user agents.

# Variables set here are used across CoffeeBrewery's Bash scripts.
# shellcheck disable=SC2034
# These variables are set by bin/coffee, coffee.sh or the user environment.
# shellcheck disable=SC2154

# Ensure the system curl is a version that supports modern HTTPS certificates.
COFFEEBREWER_MINIMUM_CURL_VERSION="7.41.0"

# Timeout values to check for dead connections
# We don't use --max-time to support slow connections
COFFEEBREWER_CURL_SPEED_LIMIT=100
COFFEEBREWER_CURL_SPEED_TIME=5

# Set CURL_DISABLE_CURLRC_ARGS with all shared curl options.
# Keep environment options in sync with Utils::Curl.curl_args in utils/curl.rb.
setup_curl_args() {
  # Personal curl defaults can change downloads or the output CoffeeBrewery parses.
  # -q must be first to ignore them, even when the shim adds certificate options.
  # Unset or empty COFFEEBREWER_CURLRC ignores defaults; an absolute path loads only
  # that file. Other non-empty values enable defaults for backwards compatibility.
  CURL_DISABLE_CURLRC_ARGS=()
  if [[ -z "${COFFEEBREWER_CURLRC}" ]]
  then
    CURL_DISABLE_CURLRC_ARGS=(-q)
  elif [[ "${COFFEEBREWER_CURLRC}" == /* ]]
  then
    CURL_DISABLE_CURLRC_ARGS=(-q --config "${COFFEEBREWER_CURLRC}")
  fi

  local retries="${COFFEEBREWER_CURL_RETRIES:-3}"
  if [[ "${retries}" =~ ^[0-9]+$ ]] && ((10#${retries} > 0))
  then
    CURL_DISABLE_CURLRC_ARGS+=(--retry "${retries}")
  fi

  # Match CoffeeBrewery::EnvConfig::FALSY_VALUES in env_config.rb.
  local falsy_values='^([fF][aA][lL][sS][eE]|[nN][oO]|[oO][fF][fF]|[nN][iI][lL]|0)?$'
  if [[ ! "${COFFEEBREWER_CURL_VERBOSE}" =~ ${falsy_values} ]]
  then
    CURL_DISABLE_CURLRC_ARGS+=(--verbose)
  fi

  # Keep redirect policy in sync with Utils::Curl.no_insecure_redirect_curl_args in utils/curl.rb.
  if [[ ! "${COFFEEBREWER_NO_INSECURE_REDIRECT}" =~ ${falsy_values} ]]
  then
    CURL_DISABLE_CURLRC_ARGS+=(--proto-redir "=https")
  fi
}

setup_curl() {
  COFFEEBREWER_BREWED_CURL_PATH="${COFFEEBREWER_PREFIX}/opt/curl/bin/curl"
  select_tool curl "${COFFEEBREWER_MINIMUM_CURL_VERSION}" "${COFFEEBREWER_BREWED_CURL_PATH}" \
    /usr/bin/curl "${COFFEEBREWER_CURL_PATH}" "${COFFEEBREWER_FORCE_BREWED_CURL}"
  COFFEEBREWER_CURL="${COFFEEBREWER_SELECTED_TOOL:-/usr/bin/false}"
  if [[ "${COFFEEBREWER_SYSTEM_TOOL_USABLE}" == 1 ]]
  then
    unset COFFEEBREWER_SYSTEM_CURL_TOO_OLD
  else
    COFFEEBREWER_SYSTEM_CURL_TOO_OLD=1
  fi
  # Reused by Utils::Curl.curl_version in utils/curl.rb without another probe.
  if [[ -n "${COFFEEBREWER_SELECTED_TOOL_VERSION}" ]]
  then
    export COFFEEBREWER_CURL_VERSION="${COFFEEBREWER_SELECTED_TOOL_VERSION}"
    export COFFEEBREWER_CURL_VERSION_PATH="${COFFEEBREWER_CURL}"
  else
    unset COFFEEBREWER_CURL_VERSION COFFEEBREWER_CURL_VERSION_PATH
  fi
}

setup_ca_certificates() {
  if [[ -n "${COFFEEBREWER_FORCE_BREWED_CA_CERTIFICATES}" && -f "${COFFEEBREWER_PREFIX}/etc/ca-certificates/cert.pem" ]]
  then
    export SSL_CERT_FILE="${COFFEEBREWER_PREFIX}/etc/ca-certificates/cert.pem"
    export GIT_SSL_CAINFO="${COFFEEBREWER_PREFIX}/etc/ca-certificates/cert.pem"
    export GIT_SSL_CAPATH="${COFFEEBREWER_PREFIX}/etc/ca-certificates"
  fi
}

check-curl-version() {
  [[ -z "${COFFEEBREWER_CURL_VERSION}" ]] || return 0
  COFFEEBREWER_FORCE_BREWED_CURL=1
  install_tool curl "${COFFEEBREWER_MINIMUM_CURL_VERSION}"
}

setup-user-agents() {
  COFFEEBREWER_USER_AGENT="${COFFEEBREWER_PRODUCT}/${COFFEEBREWER_USER_AGENT_VERSION} (${COFFEEBREWER_SYSTEM}; ${COFFEEBREWER_PROCESSOR} ${COFFEEBREWER_OS_USER_AGENT_VERSION})"
  # Reuse the selected version without another curl process.
  local curl_version_output curl_name_and_version
  if [[ -n "${COFFEEBREWER_CURL_VERSION}" ]]
  then
    curl_name_and_version="curl ${COFFEEBREWER_CURL_VERSION}"
  else
    curl_version_output="$("${COFFEEBREWER_CURL}" --version 2>/dev/null)"
    curl_name_and_version="${curl_version_output%% (*}"
  fi
  COFFEEBREWER_USER_AGENT_CURL="${COFFEEBREWER_USER_AGENT} ${curl_name_and_version// //}"

  unset COFFEEBREWER_CURL_SUPPORTS_ETAGS
  if [[ "$(numeric "${curl_name_and_version##* }")" -ge "$(numeric "7.68.0")" ]]
  then
    COFFEEBREWER_CURL_SUPPORTS_ETAGS=1
  fi
}
