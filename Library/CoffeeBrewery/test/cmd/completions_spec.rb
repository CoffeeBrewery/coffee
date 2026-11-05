# typed: strict
# frozen_string_literal: true

require "cmd/completions"
require "cmd/shared_examples/args_parse"

RSpec.describe CoffeeBrewery::Cmd::CompletionsCmd do
  it_behaves_like "parseable arguments"

  it "uses state as the default subcommand" do
    expect(described_class.new([]).args.subcommand).to eq("state")
  end

  it "rejects extra arguments for state" do
    expect { described_class.new(%w[state foo]) }
      .to raise_error(CoffeeBrewery::CLI::MaxNamedArgumentsError)
  end

  it "links completions", :integration_test do
    COFFEEBREWER_REPOSITORY.cd do
      system "git", "init"
    end

    expect { coffee "completions", "link" }
      .to output(/Completions are now linked/).to_stdout
      .and not_to_output.to_stderr
      .and be_a_success

    CoffeeBrewery::Settings.clear_cache
    expect(CoffeeBrewery::Completions.link_completions?).to be(true)
  end
end
