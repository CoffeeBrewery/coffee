# typed: strict
# frozen_string_literal: true

require "cmd/unalias"
require "cmd/shared_examples/args_parse"

RSpec.describe CoffeeBrewery::Cmd::Unalias do
  it_behaves_like "parseable arguments"

  it "unsets an alias", :integration_test do
    (COFFEEBREWER_PREFIX/"bin").mkpath
    CoffeeBrewery::Aliases.init

    expect { CoffeeBrewery::Aliases.add("foo", "bar") }
      .to not_to_output.to_stdout
      .and not_to_output.to_stderr
    expect { CoffeeBrewery::Aliases.show }
      .to output(/coffee alias foo='bar'/).to_stdout
      .and not_to_output.to_stderr

    expect { coffee "unalias", "foo" }
      .to not_to_output.to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
    expect { CoffeeBrewery::Aliases.show }
      .to not_to_output.to_stdout
      .and not_to_output.to_stderr
  end
end
