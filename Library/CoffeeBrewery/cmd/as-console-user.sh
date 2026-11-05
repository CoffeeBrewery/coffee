# Documentation defined in Library/CoffeeBrewery/cmd/as-console-user.rb

# COFFEEBREWER_LIBRARY is set by coffee.sh.
# shellcheck disable=SC1091,SC2154
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/as_user.sh"

homebrew-as-console-user() {
  homebrew-as-user as-console-user "$@"
}
