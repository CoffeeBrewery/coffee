# typed: strict
# frozen_string_literal: true

require "cmd/alias"
require "cmd/shared_examples/args_parse"

RSpec.describe CoffeeBrewery::Cmd::Alias do
  it_behaves_like "parseable arguments"

  it "sets an alias", :integration_test do
    expect { coffee "alias", "foo-test=bar" }
      .to not_to_output.to_stdout
      .and not_to_output.to_stderr
      .and be_a_success

    alias_file = COFFEEBREWER_ALIASES/"foo_test"
    expect([alias_file.read.include?("coffee bar $*"), (COFFEEBREWER_PREFIX/"bin/coffee-foo-test").realpath])
      .to eq([true, alias_file])
  end
end
