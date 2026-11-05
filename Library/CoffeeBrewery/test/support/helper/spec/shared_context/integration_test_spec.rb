# typed: true
# frozen_string_literal: true

RSpec.describe Test::Helper::IntegrationTest do
  subject(:helper) { Object.new.extend(described_class) }

  let(:status) { instance_double(Process::Status) }

  before do
    allow(helper).to receive(:command_id).and_return("integration-command")
  end

  around do |example|
    (COFFEEBREWER_PREFIX/"bin").mkpath
    example.run
  ensure
    FileUtils.rm_rf [COFFEEBREWER_PREFIX/"bin", COFFEEBREWER_PREFIX/"Library/CoffeeBrewery"]
  end

  it "copies an executable CoffeeBrewery entry point into the test prefix" do
    FileUtils.touch COFFEEBREWER_PREFIX/"bin/coffee"
    brew_sh_path = Pathname(helper.test_prefix_brew_sh)

    expect([brew_sh_path.symlink?, brew_sh_path.executable?, brew_sh_path.read])
      .to eq([false, true, COFFEEBREWER_BREW_FILE.read])
  end

  it "disables Sorbet checking in Ruby integration commands" do
    captured_env = {}
    allow(Open3).to receive(:capture3) do |env, *_args|
      captured_env.replace(env)
      ["", "", status]
    end

    helper.coffee "help"

    expect(captured_env.slice("COFFEEBREWER_SORBET_RUNTIME", "COFFEEBREWER_SORBET_RECURSIVE")).to eq(
      "COFFEEBREWER_SORBET_RUNTIME"   => nil,
      "COFFEEBREWER_SORBET_RECURSIVE" => nil,
    )
  end

  it "uses the lightweight integration coverage recorder" do
    ENV["COFFEEBREWER_TESTS_COVERAGE"] = "1"
    captured_command = []
    allow(Open3).to receive(:capture3) do |_env, *command|
      captured_command.replace(command.map(&:to_s))
      ["", "", status]
    end

    helper.coffee "help"

    expect([
      captured_command.any? { |arg| arg.include?("integration_coverage") },
      captured_command.any? { |arg| arg.include?("simplecov_start") },
    ]).to eq([true, false])
  end
end
