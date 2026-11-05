# Documentation defined in Library/CoffeeBrewery/cmd/vendor-install.rb

# COFFEEBREWER_ARTIFACT_DOMAIN, COFFEEBREWER_ARTIFACT_DOMAIN_NO_FALLBACK, COFFEEBREWER_BOTTLE_DOMAIN, COFFEEBREWER_CACHE,
# COFFEEBREWER_CURLRC, COFFEEBREWER_DEVELOPER, COFFEEBREWER_DEBUG, COFFEEBREWER_VERBOSE are from the user environment
# COFFEEBREWER_PORTABLE_RUBY_VERSION is set by utils/ruby.sh
# COFFEEBREWER_LIBRARY, COFFEEBREWER_PREFIX are set by bin/coffee
# COFFEEBREWER_CURL, COFFEEBREWER_GITHUB_PACKAGES_AUTH, COFFEEBREWER_LINUX, COFFEEBREWER_LINUX_MINIMUM_GLIBC_VERSION, COFFEEBREWER_MACOS,
# COFFEEBREWER_PHYSICAL_PROCESSOR, COFFEEBREWER_PROCESSOR, COFFEEBREWER_USER_AGENT_CURL are set by coffee.sh
# shellcheck disable=SC2154
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/cmd.sh"
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/curl.sh"
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/lock.sh"
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/ruby.sh"

VENDOR_DIR="${COFFEEBREWER_LIBRARY}/CoffeeBrewery/vendor"

set_ruby_variables() {
  # Handle the case where /usr/local/bin/coffee is run under arm64.
  # It's a x86_64 installation there (we refuse to install arm64 binaries) so
  # use a x86_64 Portable Ruby.
  if [[ -n "${COFFEEBREWER_MACOS}" && "${VENDOR_PHYSICAL_PROCESSOR}" == "arm64" && "${COFFEEBREWER_PREFIX}" == "/usr/local" ]]
  then
    ruby_PROCESSOR="x86_64"
    ruby_OS="darwin"
  else
    ruby_PROCESSOR="${VENDOR_PHYSICAL_PROCESSOR}"
    if [[ -n "${COFFEEBREWER_MACOS}" ]]
    then
      ruby_OS="darwin"
    elif [[ -n "${COFFEEBREWER_LINUX}" ]]
    then
      ruby_OS="linux"
    fi
  fi

  ruby_PLATFORMINFO="${COFFEEBREWER_LIBRARY}/CoffeeBrewery/vendor/portable-ruby-${ruby_PROCESSOR}-${ruby_OS}"
  if [[ -f "${ruby_PLATFORMINFO}" && -r "${ruby_PLATFORMINFO}" ]]
  then
    # ruby_TAG and ruby_SHA will be set via the sourced file if it exists
    # shellcheck disable=SC1090
    source "${ruby_PLATFORMINFO}"
  fi

  # Dynamic variables can't be detected by shellcheck
  # shellcheck disable=SC2034
  if [[ -n "${ruby_TAG}" && -n "${ruby_SHA}" ]]
  then
    ruby_FILENAME="portable-ruby-${COFFEEBREWER_PORTABLE_RUBY_VERSION}.${ruby_TAG}.bottle.tar.gz"
    ruby_URLs=()
    if [[ -n "${COFFEEBREWER_ARTIFACT_DOMAIN}" ]]
    then
      # If the artifact domain already contains the Docker Registry API's
      # /v2/ path (e.g. an OCI registry proxying ghcr.io under a repository
      # prefix: https://mirror.example.com/v2/ghcr-io), skip adding v2
      # rather than producing a duplicate /v2/.
      # Keep this in sync with the COFFEEBREWER_ARTIFACT_DOMAIN handling in
      # Library/CoffeeBrewery/download_strategy/curl_download_strategy.rb.
      local artifact_domain="${COFFEEBREWER_ARTIFACT_DOMAIN%/}"
      if [[ ! "${artifact_domain}" =~ ^https?://[^/]+/v2(/|$) ]]
      then
        artifact_domain="${artifact_domain}/v2"
      fi
      ruby_URLs+=("${artifact_domain}/homebrew/core/portable-ruby/blobs/sha256:${ruby_SHA}")
      if [[ -n "${COFFEEBREWER_ARTIFACT_DOMAIN_NO_FALLBACK}" ]]
      then
        ruby_URL="${ruby_URLs[0]}"
        return
      fi
    fi
    if [[ -n "${COFFEEBREWER_BOTTLE_DOMAIN}" ]]
    then
      ruby_URLs+=("${COFFEEBREWER_BOTTLE_DOMAIN}/${ruby_FILENAME}")
    fi
    ruby_URLs+=(
      "https://ghcr.io/v2/homebrew/core/portable-ruby/blobs/sha256:${ruby_SHA}"
    )
    ruby_URL="${ruby_URLs[0]}"
  fi
}

check_linux_glibc_version() {
  if [[ -z "${COFFEEBREWER_LINUX}" || -z "${COFFEEBREWER_LINUX_MINIMUM_GLIBC_VERSION}" ]]
  then
    return 0
  fi

  local glibc_version
  local glibc_version_major
  local glibc_version_minor

  local minimum_required_major="${COFFEEBREWER_LINUX_MINIMUM_GLIBC_VERSION%.*}"
  local minimum_required_minor="${COFFEEBREWER_LINUX_MINIMUM_GLIBC_VERSION#*.}"

  if [[ "$(/usr/bin/ldd --version)" =~ \ [0-9]\.[0-9]+ ]]
  then
    glibc_version="${BASH_REMATCH[0]// /}"
    glibc_version_major="${glibc_version%.*}"
    glibc_version_minor="${glibc_version#*.}"
    if ((glibc_version_major < minimum_required_major || glibc_version_minor < minimum_required_minor))
    then
      odie "Vendored tools require system Glibc ${COFFEEBREWER_LINUX_MINIMUM_GLIBC_VERSION} or later (yours is ${glibc_version})."
    fi
  else
    odie "Failed to detect system Glibc version."
  fi
}

fetch() {
  local -a curl_args
  local url
  local sha
  local first_try=1
  local vendor_locations
  local temporary_path
  local curl_exit_code=0

  setup_curl_args
  curl_args=("${CURL_DISABLE_CURLRC_ARGS[@]}")

  # Authorization is needed for GitHub Packages but harmless on GitHub Releases
  curl_args+=(
    --fail
    --remote-time
    --location
    --user-agent "${COFFEEBREWER_USER_AGENT_CURL}"
  )

  if [[ -n "${COFFEEBREWER_GITHUB_PACKAGES_AUTH}" ]]
  then
    curl_args[${#curl_args[*]}]="--header"
    curl_args[${#curl_args[*]}]="Authorization: ${COFFEEBREWER_GITHUB_PACKAGES_AUTH}"
  fi

  if [[ -n "${COFFEEBREWER_QUIET}" ]]
  then
    curl_args[${#curl_args[*]}]="--silent"
  elif [[ -z "${COFFEEBREWER_VERBOSE}" ]]
  then
    curl_args[${#curl_args[*]}]="--progress-bar"
  fi

  temporary_path="${CACHED_LOCATION}.incomplete"

  mkdir -p "${COFFEEBREWER_CACHE}"
  [[ -n "${COFFEEBREWER_QUIET}" ]] || ohai "Downloading ${VENDOR_URL}" >&2
  if [[ -f "${CACHED_LOCATION}" ]]
  then
    [[ -n "${COFFEEBREWER_QUIET}" ]] || echo "Already downloaded: ${CACHED_LOCATION}" >&2
  else
    for url in "${VENDOR_URLs[@]}"
    do
      [[ -n "${COFFEEBREWER_QUIET}" || -n "${first_try}" ]] || ohai "Downloading ${url}" >&2
      first_try=''
      if [[ -f "${temporary_path}" ]]
      then
        # COFFEEBREWER_CURL is set by coffee.sh (and isn't misspelt here)
        # shellcheck disable=SC2153
        "${COFFEEBREWER_CURL}" "${curl_args[@]}" -C - "${url}" -o "${temporary_path}"
        curl_exit_code="$?"
        if [[ "${curl_exit_code}" -eq 33 ]]
        then
          [[ -n "${COFFEEBREWER_QUIET}" ]] || echo "Trying a full download" >&2
          rm -f "${temporary_path}"
          "${COFFEEBREWER_CURL}" "${curl_args[@]}" "${url}" -o "${temporary_path}"
          curl_exit_code="$?"
        fi
      else
        "${COFFEEBREWER_CURL}" "${curl_args[@]}" "${url}" -o "${temporary_path}"
        curl_exit_code="$?"
      fi

      [[ -f "${temporary_path}" ]] && break
    done

    if [[ "${curl_exit_code}" -ne 0 ]]
    then
      rm -f "${temporary_path}"
    fi

    if [[ ! -f "${temporary_path}" ]]
    then
      vendor_locations="$(printf "  - %s\n" "${VENDOR_URLs[@]}")"
      odie <<EOS
Failed to download ${VENDOR_NAME} from the following locations:
${vendor_locations}

Do not file an issue on GitHub about this; you will need to figure out for
yourself what issue with your internet connection restricts your access to
GitHub (used for CoffeeBrewery updates and binary packages).
EOS
    fi

    trap '' SIGINT
    mv "${temporary_path}" "${CACHED_LOCATION}"
    trap - SIGINT
  fi

  if [[ -x "/usr/bin/shasum" ]]
  then
    sha="$(/usr/bin/shasum -a 256 "${CACHED_LOCATION}" | cut -d' ' -f1)"
  fi

  if [[ -z "${sha}" && -x "$(type -P sha256sum)" ]]
  then
    sha="$(sha256sum "${CACHED_LOCATION}" | cut -d' ' -f1)"
  fi

  if [[ -z "${sha}" ]]
  then
    if [[ -x "$(type -P ruby)" ]]
    then
      sha="$(
        ruby <<EOSCRIPT
require 'digest/sha2'
digest = Digest::SHA256.new
File.open('${CACHED_LOCATION}', 'rb') { |f| digest.update(f.read) }
puts digest.hexdigest
EOSCRIPT
      )"
    else
      odie "Cannot verify checksum ('shasum', 'sha256sum' and 'ruby' not found)!"
    fi
  fi

  if [[ -z "${sha}" ]]
  then
    odie "Could not get checksum ('shasum', 'sha256sum' and 'ruby' produced no output)!"
  fi

  if [[ "${sha}" != "${VENDOR_SHA}" ]]
  then
    odie <<EOS
Checksum mismatch.
Expected: ${VENDOR_SHA}
  Actual: ${sha}
 Archive: ${CACHED_LOCATION}
To retry an incomplete download, remove the file above.
EOS
  fi
}

install() {
  local tar_args

  if [[ -n "${COFFEEBREWER_VERBOSE}" ]]
  then
    tar_args="xvzf"
  else
    tar_args="xzf"
  fi

  mkdir -p "${VENDOR_DIR}/portable-${VENDOR_NAME}"
  safe_cd "${VENDOR_DIR}/portable-${VENDOR_NAME}"

  trap '' SIGINT

  if [[ -d "${VENDOR_VERSION}" ]]
  then
    mv "${VENDOR_VERSION}" "${VENDOR_VERSION}.reinstall"
  fi

  safe_cd "${VENDOR_DIR}"
  [[ -n "${COFFEEBREWER_QUIET}" ]] || ohai "Brewing ${VENDOR_FILENAME}" >&2
  tar "${tar_args}" "${CACHED_LOCATION}"

  if [[ "${VENDOR_PROCESSOR}" != "${COFFEEBREWER_PROCESSOR}" ]] ||
     [[ "${VENDOR_PHYSICAL_PROCESSOR}" != "${COFFEEBREWER_PHYSICAL_PROCESSOR}" ]]
  then
    return 0
  fi

  safe_cd "${VENDOR_DIR}/portable-${VENDOR_NAME}"

  if "./${VENDOR_VERSION}/bin/${VENDOR_NAME}" --version >/dev/null
  then
    ln -sfn "${VENDOR_VERSION}" current
    if [[ -d "${VENDOR_VERSION}.reinstall" ]]
    then
      rm -rf "${VENDOR_VERSION}.reinstall"
    fi
  else
    rm -rf "${VENDOR_VERSION}"
    if [[ -d "${VENDOR_VERSION}.reinstall" ]]
    then
      mv "${VENDOR_VERSION}.reinstall" "${VENDOR_VERSION}"
    fi
    odie "Failed to install ${VENDOR_NAME} ${VENDOR_VERSION}!"
  fi

  trap - SIGINT
}

homebrew-vendor-install() {
  local option
  local url_var
  local sha_var

  unset VENDOR_PHYSICAL_PROCESSOR
  unset VENDOR_PROCESSOR

  for option in "$@"
  do
    if homebrew-command-help vendor-install "${option}"
    then
      exit $?
    fi
    if homebrew-command-common-option "${option}"
    then
      continue
    fi

    case "${option}" in
      --*) ;;
      -*) homebrew-command-common-short-options "${option}" ;;
      *)
        if [[ -n "${VENDOR_NAME}" ]]
        then
          if [[ -n "${COFFEEBREWER_DEVELOPER}" ]]
          then
            if [[ -n "${PROCESSOR_TARGET}" ]]
            then
              odie "This command does not take more than vendor and processor targets!"
            else
              VENDOR_PHYSICAL_PROCESSOR="${option}"
              VENDOR_PROCESSOR="${option}"
            fi
          else
            odie "This command does not take multiple vendor targets!"
          fi
        else
          VENDOR_NAME="${option}"
        fi
        ;;
    esac
  done

  [[ -z "${VENDOR_NAME}" ]] && odie "This command requires a vendor target!"
  homebrew-command-enable-debug

  if [[ -z "${VENDOR_PHYSICAL_PROCESSOR}" ]]
  then
    VENDOR_PHYSICAL_PROCESSOR="${COFFEEBREWER_PHYSICAL_PROCESSOR}"
  fi

  if [[ -z "${VENDOR_PROCESSOR}" ]]
  then
    VENDOR_PROCESSOR="${COFFEEBREWER_PROCESSOR}"
  fi

  set_ruby_variables
  check_linux_glibc_version

  filename_var="${VENDOR_NAME}_FILENAME"
  sha_var="${VENDOR_NAME}_SHA"
  url_var="${VENDOR_NAME}_URL"
  VENDOR_FILENAME="${!filename_var}"
  VENDOR_SHA="${!sha_var}"
  VENDOR_URL="${!url_var}"
  VENDOR_VERSION="$(cat "${VENDOR_DIR}/portable-${VENDOR_NAME}-version")"

  if [[ -z "${VENDOR_URL}" || -z "${VENDOR_SHA}" ]]
  then
    odie "No CoffeeBrewery ${VENDOR_NAME} ${VENDOR_VERSION} available for ${COFFEEBREWER_PROCESSOR} processors!"
  fi

  # Expand the name to an array of variables
  # The array name must be "${VENDOR_NAME}_URLs"! Otherwise substitution errors will occur!
  # shellcheck disable=SC2086
  read -r -a VENDOR_URLs <<<"$(eval "echo "\$\{${url_var}s[@]\}"")"

  CACHED_LOCATION="${COFFEEBREWER_CACHE}/${VENDOR_FILENAME}"

  lock "vendor-install ${VENDOR_NAME}"
  fetch
  install
}
