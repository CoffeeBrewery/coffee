# typed: strict
# frozen_string_literal: true

require "diagnostic"

RSpec.describe CoffeeBrewery::Diagnostic::Checks do
  describe "#check_brew_path" do
    sig { returns(CoffeeBrewery::Diagnostic::Checks) }
    subject(:checks) { described_class.new }

    sig { returns(Pathname) }
    def coffee
      COFFEEBREWER_PREFIX/"bin/coffee"
    end

    sig { returns(Pathname) }
    def other_brew
      COFFEEBREWER_TEMP/"wrapper/bin/coffee"
    end

    before do
      coffee.dirname.mkpath
      coffee.write("#!/bin/sh\n")
      coffee.chmod 0755
      other_brew.dirname.mkpath
      other_brew.write("#!/bin/sh\nexit 1\n")
      other_brew.chmod 0755
      stub_const("COFFEEBREWER_BREW_FILE", coffee)
      stub_const("ORIGINAL_PATHS", [other_brew.dirname, coffee.dirname])
    end

    it "warns when another coffee shadows this installation" do
      expect(checks.check_brew_path&.to_s)
        .to include("Another `coffee` shadows this CoffeeBrewery installation in your PATH:",
                    other_brew.to_s, "#{COFFEEBREWER_PREFIX}/bin")
    end

    it "checks the original PATH, not CoffeeBrewery's modified PATH" do
      ENV["PATH"] = coffee.dirname.to_s

      expect(checks.check_brew_path).not_to be_nil
    end

    it "uses the same PATH guidance as the missing-bin warning" do
      stub_const("ORIGINAL_PATHS", [other_brew.dirname])

      expect(checks.check_brew_path&.remediation&.to_h)
        .to eq(checks.check_user_path_2&.remediation&.to_h)
    end

    it "does not warn when this installation takes precedence" do
      stub_const("ORIGINAL_PATHS", [coffee.dirname, other_brew.dirname])

      expect(checks.check_brew_path).to be_nil
    end

    it "does not warn about symlinks to the same coffee" do
      other_brew.unlink
      FileUtils.ln_s coffee, other_brew

      expect(checks.check_brew_path).to be_nil
    end

    it "ignores non-executable files" do
      other_brew.chmod 0644

      expect(checks.check_brew_path).to be_nil
    end

    it "ignores directories named coffee" do
      other_brew.unlink
      other_brew.mkpath

      expect(checks.check_brew_path).to be_nil
    end

    it "does not duplicate the missing PATH warning" do
      stub_const("ORIGINAL_PATHS", [])

      expect(checks.check_brew_path).to be_nil
    end
  end
end
