# typed: strict
# frozen_string_literal: true

require "diagnostic"
require "install"

RSpec.describe CoffeeBrewery::Diagnostic do
  before do
    allow(described_class).to receive(:support_tiers).and_return([])
  end

  it "reports only the least supported tier after all checks" do
    checks = instance_double(CoffeeBrewery::Diagnostic::Checks,
                             supported_configuration_checks: ["check_access_directories"],
                             check_access_directories:       [
                               CoffeeBrewery::Diagnostic::Finding.new("First warning", tier: 2),
                               CoffeeBrewery::Diagnostic::Finding.new("Second warning", tier: 3),
                             ])
    allow(CoffeeBrewery::Diagnostic::Checks).to receive(:new).and_return(checks)

    expect do
      described_class.checks(:supported_configuration_checks, fatal: false)
      described_class.report_support_tier
      described_class.report_support_tier
    end.to output(<<~EOS).to_stderr
      Warning: First warning
      Warning: Second warning

      #{CoffeeBrewery::Diagnostic::Finding.support_tier_message(tier: 3)&.chomp}
    EOS
  end

  it "includes a custom compiler in the final tier without repeating the tier warning" do
    expect do
      CoffeeBrewery::Install.check_cc_argv("clang")
      described_class.support_tiers << 2
      described_class.report_support_tier
    end.to output(<<~EOS).to_stderr
      Warning: You passed `--cc=clang`.

      #{CoffeeBrewery::Diagnostic::Finding.support_tier_message(tier: 3)&.chomp}
    EOS
  end

  it "reports the final tier on exit without depending on coffee.rb" do
    _, stderr, status = Open3.capture3(
      *COFFEEBREWER_RUBY_EXEC_ARGS,
      "-I", $LOAD_PATH.join(File::PATH_SEPARATOR),
      "-rglobal", "-rdiagnostic",
      "-e", 'CoffeeBrewery::Diagnostic.support_tiers.concat([2, 3, 2]); abort "command failed"'
    )

    expect([stderr.scan(/^This is a Tier \d configuration:/), status.exitstatus])
      .to eq([["This is a Tier 3 configuration:"], 1])
  end
end
