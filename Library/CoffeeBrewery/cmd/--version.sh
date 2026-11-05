# Documentation defined in Library/CoffeeBrewery/cmd/--version.rb

# COFFEEBREWER_CORE_REPOSITORY, COFFEEBREWER_CASK_REPOSITORY, COFFEEBREWER_VERSION are set by coffee.sh
# shellcheck disable=SC2154
version_string() {
  local repo="$1"
  if ! [[ -d "${repo}" ]]
  then
    echo "N/A"
    return
  fi

  local git_revision_and_date
  git_revision_and_date="$(git -C "${repo}" log -1 --format='%h %cd' --date=short HEAD 2>/dev/null)"
  if [[ -z "${git_revision_and_date}" ]]
  then
    echo "(no Git repository)"
    return
  fi

  echo "(git revision ${git_revision_and_date%% *}; last commit ${git_revision_and_date#* })"
}

homebrew-version() {
  echo "CoffeeBrewery ${COFFEEBREWER_VERSION}"

  if [[ -n "${COFFEEBREWER_NO_INSTALL_FROM_API}" || -d "${COFFEEBREWER_CORE_REPOSITORY}" ]]
  then
    echo "CoffeeBrewery/homebrew-core $(version_string "${COFFEEBREWER_CORE_REPOSITORY}")"
  fi

  if [[ -d "${COFFEEBREWER_CASK_REPOSITORY}" ]]
  then
    echo "CoffeeBrewery/homebrew-cask $(version_string "${COFFEEBREWER_CASK_REPOSITORY}")"
  fi
}
