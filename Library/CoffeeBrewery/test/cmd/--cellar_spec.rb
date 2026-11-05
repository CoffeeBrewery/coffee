# typed: strict
# frozen_string_literal: true

require "cmd/--cellar"
require "cmd/shared_examples/args_parse"

RSpec.describe CoffeeBrewery::Cmd::Cellar do
  it_behaves_like "parseable arguments"

  it "prints CoffeeBrewery's Cellar and a Formula's Cellar", :integration_test do
    testball = setup_test_formula "testball"

    expect { brew_sh "--cellar" }
      .to output("#{ENV.fetch("COFFEEBREWER_CELLAR")}\n").to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
    expect { brew_sh "--cellar", testball }
      .to output(%r{/Cellar/testball\n}).to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
  end

  it "prints the Cellar for a Formula" do
    cmd = described_class.new(["testball"])
    allow(cmd.args.named).to receive(:to_resolved_formulae)
      .and_return([instance_double(Formula, rack: COFFEEBREWER_CELLAR/"testball")])

    expect { cmd.run }
      .to output(%r{#{COFFEEBREWER_CELLAR}/testball}o).to_stdout
      .and not_to_output.to_stderr
  end
end
