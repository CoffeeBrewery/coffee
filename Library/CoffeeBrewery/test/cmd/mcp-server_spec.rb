# typed: strict
# frozen_string_literal: true

RSpec.describe "coffee mcp-server", type: :system do
  it "starts the MCP server", :integration_test do
    expect { brew_sh "mcp-server", "--ping" }
      .to output("==> Started CoffeeBrewery MCP server...\n").to_stderr
      .and output("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}\n").to_stdout
      .and be_a_success
  end
end
