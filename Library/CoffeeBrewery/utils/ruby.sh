# When bumping, run `coffee vendor-gems --update=--ruby`.
# When bumping to a new major/minor version, also update the bounds in the Gemfile.
# Also make sure that vendored gems have been committed for the new Ruby version by updating .gitignore.
# COFFEEBREWER_LIBRARY set by bin/coffee
# shellcheck disable=SC2154
export COFFEEBREWER_REQUIRED_RUBY_VERSION="4.0"
read -r COFFEEBREWER_PORTABLE_RUBY_VERSION <"${COFFEEBREWER_LIBRARY}/CoffeeBrewery/vendor/portable-ruby-version"
export COFFEEBREWER_BUNDLER_VERSION="4.0.20"

# Disable Ruby options we don't need.
export COFFEEBREWER_RUBY_DISABLE_OPTIONS="--disable=gems,rubyopt"

# COFFEEBREWER_LIBRARY set by bin/coffee
# shellcheck disable=SC2154
test_ruby() {
  if [[ ! -x "$1" ]]
  then
    return 1
  fi

  "$1" --enable-frozen-string-literal --disable=gems,did_you_mean,rubyopt \
    "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/ruby_check_version_script.rb" \
    "${COFFEEBREWER_REQUIRED_RUBY_VERSION}" 2>/dev/null
}

system_ruby_supported() {
  ([[ -z "${COFFEEBREWER_MACOS}" ]] || can_use_ruby_from_path)
}

can_use_ruby_from_path() {
  if [[ -n "${COFFEEBREWER_DEVELOPER}" || -n "${COFFEEBREWER_TESTS}" ]] && [[ -n "${COFFEEBREWER_USE_RUBY_FROM_PATH}" ]]
  then
    return 0
  fi

  return 1
}

find_first_valid_ruby() {
  local ruby_exec
  while IFS= read -r ruby_exec
  do
    if test_ruby "${ruby_exec}"
    then
      echo "${ruby_exec}"
      break
    fi
  done
}

# COFFEEBREWER_PATH is set by global.rb
# shellcheck disable=SC2154
find_ruby() {
  local valid_ruby

  # Prioritise rubies from the filtered path (/usr/bin etc) unless explicitly overridden.
  if ! can_use_ruby_from_path
  then
    # function which() is set by coffee.sh
    # it is aliased to `type -P`
    # shellcheck disable=SC2230
    valid_ruby=$(find_first_valid_ruby < <(which -a ruby))
  fi

  if [[ -z "${valid_ruby}" ]]
  then
    # Same as above
    # shellcheck disable=SC2230
    valid_ruby=$(find_first_valid_ruby < <(PATH="${COFFEEBREWER_PATH}" which -a ruby))
  fi

  echo "${valid_ruby}"
}

# COFFEEBREWER_FORCE_VENDOR_RUBY is from the user environment
# shellcheck disable=SC2154
need_vendored_ruby() {
  if [[ -n "${COFFEEBREWER_FORCE_VENDOR_RUBY}" ]]
  then
    return 0
  elif system_ruby_supported && test_ruby "${COFFEEBREWER_RUBY_PATH}"
  then
    return 1
  else
    return 0
  fi
}

# COFFEEBREWER_LINUX is set by coffee.sh
# shellcheck disable=SC2154
setup-ruby-path() {
  local vendor_dir
  local vendor_ruby_root
  local vendor_ruby_path
  local vendor_ruby_terminfo
  local bootsnap_gem_paths
  local nullglob_enabled
  local ruby_exec
  local upgrade_fail
  local install_fail

  if [[ -n "${COFFEEBREWER_MACOS}" ]]
  then
    upgrade_fail="Failed to upgrade CoffeeBrewery Portable Ruby!"
    install_fail="Failed to install CoffeeBrewery Portable Ruby (and your system version is too old)!"
  else
    local advice="
If there's no CoffeeBrewery Portable Ruby available for your processor:
- install Ruby ${COFFEEBREWER_REQUIRED_RUBY_VERSION} with your system package manager (or rbenv/ruby-build)
- make it first in your PATH
- try again
"
    upgrade_fail="Failed to upgrade CoffeeBrewery Portable Ruby!${advice}"
    install_fail="Failed to install CoffeeBrewery Portable Ruby and cannot find another Ruby ${COFFEEBREWER_REQUIRED_RUBY_VERSION}!${advice}"
  fi

  vendor_dir="${COFFEEBREWER_LIBRARY}/CoffeeBrewery/vendor"
  vendor_ruby_root="${vendor_dir}/portable-ruby/current"
  vendor_ruby_path="${vendor_ruby_root}/bin/ruby"
  vendor_ruby_terminfo="${vendor_ruby_root}/share/terminfo"

  unset COFFEEBREWER_RUBY_PATH

  if [[ "${COFFEEBREWER_COMMAND}" == "vendor-install" ]]
  then
    return 0
  fi

  # Needed for `coffee` and `odie`.
  source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils.sh"

  if [[ -x "${vendor_ruby_path}" ]]
  then
    COFFEEBREWER_RUBY_PATH="${vendor_ruby_path}"
    TERMINFO_DIRS="${vendor_ruby_terminfo}"
    # `-ef` (rather than `readlink`) to check the `current` symlink without a fork.
    if ! [[ "${vendor_ruby_root}" -ef "${vendor_dir}/portable-ruby/${COFFEEBREWER_PORTABLE_RUBY_VERSION}" ]]
    then
      coffee vendor-install ruby || odie "${upgrade_fail}"
    fi
    nullglob_enabled=""
    shopt -q nullglob && nullglob_enabled="1"
    shopt -s nullglob
    bootsnap_gem_paths=("${vendor_ruby_root}"/lib/ruby/gems/*/gems/bootsnap-*/lib/bootsnap)
    [[ -z "${nullglob_enabled}" ]] && shopt -u nullglob
    COFFEEBREWER_BOOTSNAP_GEM_PATH="${bootsnap_gem_paths[*]-}"
  else
    if system_ruby_supported
    then
      COFFEEBREWER_RUBY_PATH="$(find_ruby)"
    fi

    if need_vendored_ruby
    then
      coffee vendor-install ruby || odie "${install_fail}"
      COFFEEBREWER_RUBY_PATH="${vendor_ruby_path}"
      TERMINFO_DIRS="${vendor_ruby_terminfo}"

      if [[ -n "${COFFEEBREWER_DEVELOPER}" && -x "${vendor_ruby_path}" ]]
      then
        if [[ ! -f "${vendor_ruby_root}/bin/bundle" ]]
        then
          odie "CoffeeBrewery Portable Ruby is installed but bundle is not!"
        elif [[ ! -d "${vendor_ruby_root}/lib/ruby/gems/${COFFEEBREWER_REQUIRED_RUBY_VERSION}.0/gems/bundler-${COFFEEBREWER_BUNDLER_VERSION}" ]]
        then
          odie "CoffeeBrewery Portable Ruby is installed but bundler ${COFFEEBREWER_BUNDLER_VERSION} is not!"
        elif ! grep -q "  ${COFFEEBREWER_BUNDLER_VERSION}" "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/Gemfile.lock"
        then
          odie "CoffeeBrewery Portable Ruby is installed but bundler ${COFFEEBREWER_BUNDLER_VERSION} is not in the Gemfile.lock!"
        fi
      fi
    fi
  fi

  homebrew_ruby_bin="${COFFEEBREWER_RUBY_PATH%/*}"
  if [[ ! -f "${homebrew_ruby_bin}/bundle" ]]
  then
    "${homebrew_ruby_bin}/gem" install bundler -v "${COFFEEBREWER_BUNDLER_VERSION}"
  fi

  export COFFEEBREWER_RUBY_PATH COFFEEBREWER_BOOTSNAP_GEM_PATH
  [[ -n "${COFFEEBREWER_LINUX}" && -n "${TERMINFO_DIRS}" ]] && export TERMINFO_DIRS
}

setup-gem-home-bundle-gemfile() {
  GEM_VERSION="$("${COFFEEBREWER_RUBY_PATH}" "${COFFEEBREWER_RUBY_DISABLE_OPTIONS}" "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/ruby_sh/ruby_gem_version.rb")"
  GEM_HOME="${COFFEEBREWER_LIBRARY}/CoffeeBrewery/vendor/bundle/ruby/${GEM_VERSION}"
  BUNDLE_GEMFILE="${COFFEEBREWER_LIBRARY}/CoffeeBrewery/Gemfile"

  export GEM_HOME
  export BUNDLE_GEMFILE
}

ensure-bundle-dependencies() {
  local install_args=()

  if ! bundle check &>/dev/null
  then
    if [[ -n "${BUNDLE_WITH}" ]]
    then
      # Convert colon-separated BUNDLE_WITH to comma-separated for --add-groups
      local groups_for_flag="${BUNDLE_WITH//:/,}"
      install_args+=("--add-groups=${groups_for_flag}")
    fi
    "${COFFEEBREWER_BREW_FILE}" install-bundler-gems "${install_args[@]}"
  fi
}
