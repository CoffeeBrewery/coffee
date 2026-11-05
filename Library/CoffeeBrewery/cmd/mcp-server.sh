# Documentation defined in Library/CoffeeBrewery/cmd/mcp-server.rb

# This is a shell command as MCP servers need a faster startup time
# than a normal CoffeeBrewery Ruby command allows.

# COFFEEBREWER_LIBRARY is set by coffee.sh
# COFFEEBREWER_BREW_FILE is set by extend/ENV/super.rb
# shellcheck disable=SC2154
homebrew-mcp-server() {
  source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/ruby.sh"
  setup-ruby-path
  export COFFEEBREWER_VERSION
  "${COFFEEBREWER_RUBY_PATH}" "-r${COFFEEBREWER_LIBRARY}/CoffeeBrewery/mcp_server.rb" -e "CoffeeBrewery::McpServer.new.run" "$@"
}
