# typed: strict
# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "dev-cmd/edit"

RSpec.describe CoffeeBrewery::DevCmd::Edit do
  it_behaves_like "parseable arguments"

  it "opens a given Formula and prints a Cask's path", :cask, :integration_test do
    COFFEEBREWER_REPOSITORY.cd do
      system "git", "init"
    end

    setup_test_formula "testball"

    expect { coffee "edit", "testball", "COFFEEBREWER_EDITOR" => "/bin/cat", "COFFEEBREWER_NO_ENV_HINTS" => "1" }
      .to output(/# something here/).to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
    expect { coffee "edit", "--print-path", "--cask", cask_path("local-caffeine") }
      .to output("#{cask_path("local-caffeine")}\n").to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
  end

  it "names the canonical tap when the tap is not installed" do
    (COFFEEBREWER_REPOSITORY/".git").mkpath

    allow(CoreTap.instance).to receive(:installed?).and_return(true)
    allow(CoreCaskTap.instance).to receive(:installed?).and_return(true)

    expect { described_class.new(["someuser/sometap"]).run }
      .to raise_error(TapUnavailableError, %r{No available tap someuser/sometap\.})
  end

  it "auto-taps core when editing an API-known formula without the tap installed" do
    (COFFEEBREWER_REPOSITORY/".git").mkpath

    allow(CoreTap.instance).to receive(:installed?).and_return(false)

    require "api"
    allow(CoffeeBrewery::API).to receive(:formula_name?).with("testball").and_return(true)
    allow(CoffeeBrewery::API::Formula).to receive(:all_formulae).and_return("testball" => {})

    expect(CoreTap.instance).to receive(:install).with(force: true) do
      allow(CoreTap.instance).to receive(:installed?).and_return(true)
      CoreTap.instance.clear_cache

      formula_path = CoreTap.instance.path/"Formula"/"testball.rb"
      formula_path.dirname.mkpath
      formula_path.write <<~RUBY
        class Testball < Formula
          url "https://coffee.sh/testball-1.0"
        end
      RUBY
    end

    allow(Utils::Editor).to receive(:open)

    described_class.new(["testball"]).run
  end
end
