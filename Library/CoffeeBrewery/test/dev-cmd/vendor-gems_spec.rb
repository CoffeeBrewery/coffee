# typed: strict
# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "dev-cmd/vendor-gems"

RSpec.describe CoffeeBrewery::DevCmd::VendorGems do
  it_behaves_like "parseable arguments"
  it_behaves_like "a documented command", "vendor-gems"

  sig { returns(CoffeeBrewery::DevCmd::VendorGems) }
  def vendor_gems_command
    ENV["BUNDLE_GEMFILE"] = (COFFEEBREWER_LIBRARY_PATH/"Gemfile").to_s
    stub_const("COFFEEBREWER_LIBRARY_PATH", mktmpdir)
    setup_rb = COFFEEBREWER_LIBRARY_PATH/"vendor/bundle/bundler/setup.rb"
    setup_rb.dirname.mkpath
    setup_rb.write <<~RUBY
      $LOAD_PATH.unshift File.expand_path("\#{__dir__}/../\#{RUBY_ENGINE}/\#{Gem.ruby_api_version}/extensions/#{Gem::Platform.local}/\#{Gem.extension_api_version}/json-3.0.2")
    RUBY

    described_class.new(["--no-commit"]).tap do |command|
      allow(command).to receive(:run_bundle)
      allow(command).to receive(:ohai)
      allow(Utils::GemSetup).to receive(:setup_gem_environment!)
      allow(Utils::GemSetup).to receive(:valid_gem_groups).and_return([])
    end
  end

  it "rejects a stale Bootsnap core gem list" do
    command = vendor_gems_command
    allow(CoffeeBrewery::Bootsnap).to receive(:core_gem_names).and_return([])

    expect { command.run }.to raise_error(RuntimeError, /Bootsnap core gem list is out of date/)
  end

  it "accepts reordered Bootsnap core gems" do
    command = vendor_gems_command
    core_gem_names = CoffeeBrewery::Bootsnap.core_gem_names.reverse
    allow(CoffeeBrewery::Bootsnap).to receive(:core_gem_names).and_return(core_gem_names)

    expect { command.run }.not_to raise_error
  end

  it "uses the runtime platform for native extension load paths" do
    vendor_gems_command.run
    platform = OS.linux? ? "arm64-darwin-20" : "x86_64-linux"

    stdout, stderr, status = Open3.capture3(
      *COFFEEBREWER_RUBY_EXEC_ARGS, "-rrubygems", "-e", <<~RUBY,
        RbConfig::CONFIG["arch"] = ARGV.fetch(1)
        Gem::Platform.local(refresh: true)
        load ARGV.fetch(0)
        puts $LOAD_PATH.first
      RUBY
      COFFEEBREWER_LIBRARY_PATH/"vendor/bundle/bundler/setup.rb", platform
    )
    raise stderr unless status.success?

    expect(stdout.chomp).to eq(
      "#{COFFEEBREWER_LIBRARY_PATH}/vendor/bundle/#{RUBY_ENGINE}/#{Gem.ruby_api_version}/" \
      "extensions/#{platform}/#{Gem.extension_api_version}/json-3.0.2",
    )
  end
end
