# Documentation defined in Library/CoffeeBrewery/cmd/update-if-needed.rb

homebrew-update-if-needed() {
  export COFFEEBREWER_AUTO_UPDATE_COMMAND="1"
  auto-update "$@"
}
