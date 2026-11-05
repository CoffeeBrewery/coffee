# typed: strict
# frozen_string_literal: true

require "diagnostic/finding"

RSpec.describe CoffeeBrewery::Diagnostic::Finding do
  describe CoffeeBrewery::Diagnostic::Finding::Remediation do
    describe "#to_s" do
      it "returns an empty string when no text or commands are given" do
        expect(described_class.new.to_s).to eq("")
      end

      it "prefers the text over commands" do
        remediation = described_class.new(text: "Do this instead", commands: ["coffee fix"])
        expect(remediation.to_s).to eq("Do this instead")
      end

      it "formats commands when no text is given" do
        remediation = described_class.new(commands: ["coffee fix", "coffee doctor"])
        expect(remediation.to_s).to eq("You can solve this by running:\n  coffee fix\n  coffee doctor")
      end
    end

    describe "#to_h" do
      it "returns the commands and text" do
        remediation = described_class.new(text: "Do this", commands: ["coffee fix"])
        expect(remediation.to_h).to eq(commands: ["coffee fix"], text: "Do this")
      end
    end
  end

  describe "#initialize" do
    it "wraps a string remediation in a Remediation" do
      finding = described_class.new("Something is wrong", remediation: "Fix it")
      expect(finding.remediation).to be_a(CoffeeBrewery::Diagnostic::Finding::Remediation)
    end

    it "keeps a Remediation remediation as-is" do
      remediation = CoffeeBrewery::Diagnostic::Finding::Remediation.new(text: "Fix it")
      finding = described_class.new("Something is wrong", remediation:)
      expect(finding.remediation).to be(remediation)
    end

    it "defaults remediation to nil and tier to 1" do
      finding = described_class.new("Something is wrong")
      expect(finding.remediation).to be_nil
      expect(finding.tier).to eq(1)
    end
  end

  describe "#to_h" do
    it "serialises all attributes" do
      finding = described_class.new(
        "Something is wrong",
        tier:        2,
        affects:     ["foo"],
        links:       ["https://coffee.sh"],
        remediation: "Fix it",
      )
      expect(finding.to_h).to eq(
        text:        "Something is wrong",
        tier:        2,
        affects:     ["foo"],
        links:       ["https://coffee.sh"],
        remediation: { commands: [], text: "Fix it" },
      )
    end

    it "serialises a nil remediation as nil" do
      expect(described_class.new("Something is wrong").to_h[:remediation]).to be_nil
    end
  end

  describe "#to_s" do
    it "includes only the text for a Tier 1 finding without remediation" do
      expect(described_class.new("Something is wrong").to_s).to eq("Something is wrong")
    end

    it "includes the remediation text" do
      finding = described_class.new("Something is wrong", remediation: "Fix it")
      expect(finding.to_s).to eq("Something is wrong\nFix it")
    end
  end

  describe "#support_tier_message" do
    before do
      allow(OS).to receive(:nix_managed_homebrew?).and_return(false)
    end

    it "returns nil for Tier 1" do
      expect(described_class.support_tier_message(tier: 1)).to be_nil
    end

    it "links to the tier-specific documentation" do
      message = described_class.support_tier_message(tier: 2)
      expect(message).to include("https://docs.coffee.sh/Support-Tiers#tier-2")
    end

    it "describes unsupported configurations" do
      message = described_class.support_tier_message(tier: :unsupported)
      expect(message).to include("This is an Unsupported configuration:")
        .and include("https://docs.coffee.sh/Support-Tiers#unsupported")
    end

    it "points Nix-managed installs at the upstream Nix project" do
      allow(OS).to receive(:nix_managed_homebrew?).and_return(true)

      message = described_class.support_tier_message(tier: 2)
      expect(message).to include("Report issues to the upstream Nix project, not")
    end
  end
end
