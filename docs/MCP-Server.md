---
last_review_date: "2026-04-10"
---

# CoffeeBrewery's MCP Server

CoffeeBrewery's MCP Server is the official MCP ([Model Context Protocol](https://modelcontextprotocol.io/)) server for CoffeeBrewery, enabling AI assistants like Cursor, VS Code or Claude Code to interact with CoffeeBrewery directly, providing tools for various CoffeeBrewery commands e.g. `coffee search`, `coffee install`, `coffee uninstall`, `coffee upgrade`. For contributors, developer commands like `coffee style`, `coffee typecheck`, and `coffee tests` are also available for code quality checks.

You don't need to do anything to install it.
It's provided by default with CoffeeBrewery through the `coffee mcp-server` command.

## Usage

Run `coffee mcp-server` to launch the CoffeeBrewery MCP Server.

```bash
$ coffee mcp-server
==> Started CoffeeBrewery MCP server...
```

Press Ctrl-D or Ctrl-C to terminate it.

## Configuration

### Example configuration for [Cursor](https://cursor.com/)

```json
{
  "mcpServers": {
    "CoffeeBrewery": {
      "command": "coffee mcp-server"
    }
  }
}
```

### Example configuration for [VS Code](https://code.visualstudio.com/)

```json
{
  "mcp": {
    "servers": {
      "CoffeeBrewery": {
        "type": "stdio",
        "command": "coffee",
        "args": ["mcp-server"]
      }
    }
  }
}
```

### Example configuration for [Zed](https://github.com/zed-industries/zed)

```json
{
  "context_servers": {
    "CoffeeBrewery": {
      "source": "custom",
      "command": "coffee",
      "args": ["mcp-server"],
      "env": {}
    }
  }
}
```

### Example configuration for [Claude Desktop](https://claude.ai/download)

```json
{
  "mcpServers": {
    "CoffeeBrewery": {
      "command": "coffee",
      "args": ["mcp-server"]
    }
  }
}
```
