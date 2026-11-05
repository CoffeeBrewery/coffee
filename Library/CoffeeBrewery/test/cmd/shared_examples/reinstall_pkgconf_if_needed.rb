# typed: true
# frozen_string_literal: true

require "reinstall"
require "install"
require "formula_installer"

RSpec.shared_examples "reinstall_pkgconf_if_needed" do
  context "when running on macOS", :needs_macos do
    describe ".reinstall_pkgconf_if_needed!" do
      let(:formula) { instance_double(Formula) }
      let(:formula_installer) do
        instance_double(FormulaInstaller, formula:, prelude_fetch: true, prelude: true, fetch: true)
      end
      let(:context) { instance_double(CoffeeBrewery::Reinstall::InstallationContext, formula_installer:) }

      before do
        allow(OS).to receive(:mac?).and_return(true)
        allow(Formula).to receive(:[]).with("pkgconf").and_return(formula)
        allow(CoffeeBrewery::Install).to receive(:fetch_formulae).with([formula_installer]).and_return([formula_installer])
        allow(CoffeeBrewery::Reinstall).to receive(:build_install_context).and_return(context)
        allow(formula).to receive(:full_name).and_return("pkgconf")
      end

      context "when there is no macOS SDK mismatch" do
        it "does nothing" do
          allow(CoffeeBrewery::Pkgconf).to receive(:macos_sdk_mismatch).and_return(nil)
          expect(CoffeeBrewery::Reinstall).not_to receive(:reinstall_formula)

          CoffeeBrewery::Reinstall.reinstall_pkgconf_if_needed!
        end
      end

      context "when dry_run is true" do
        it "prints a warning and does not reinstall" do
          allow(CoffeeBrewery::Pkgconf).to receive_messages(
            macos_sdk_mismatch:       %w[13 14],
            mismatch_warning_message: "warning",
          )
          expect(CoffeeBrewery::Reinstall).not_to receive(:reinstall_formula)
          expect(CoffeeBrewery::Reinstall).to receive(:opoo).with(/would be reinstalled/)

          CoffeeBrewery::Reinstall.reinstall_pkgconf_if_needed!(dry_run: true)
        end
      end

      context "when there is a mismatch and reinstall succeeds" do
        it "reinstalls pkgconf and prints success" do
          allow(CoffeeBrewery::Pkgconf).to receive(:macos_sdk_mismatch).and_return(%w[13 14])
          expect(CoffeeBrewery::Reinstall).to receive(:reinstall_formula).with(context)
          expect(CoffeeBrewery::Reinstall).to receive(:ohai).with(/Reinstalled pkgconf/)
          allow(CoffeeBrewery::Reinstall).to receive(:restore_backup)

          CoffeeBrewery::Reinstall.reinstall_pkgconf_if_needed!
        end
      end

      context "when reinstall_formula raises an error" do
        it "rescues and prints the mismatch warning" do
          allow(CoffeeBrewery::Pkgconf).to receive_messages(
            macos_sdk_mismatch:       %w[13 14],
            mismatch_warning_message: "warning",
          )
          allow(CoffeeBrewery::Reinstall).to receive(:reinstall_formula).and_raise(RuntimeError)
          allow(CoffeeBrewery::Reinstall).to receive(:restore_backup)
          allow(CoffeeBrewery::Reinstall).to receive(:backup)

          expect(CoffeeBrewery::Reinstall).to receive(:ofail).with("warning")

          CoffeeBrewery::Reinstall.reinstall_pkgconf_if_needed!
        end
      end
    end
  end

  context "when on a non-macOS platform" do
    before do
      allow(OS).to receive(:mac?).and_return(false)
    end

    it "does nothing and does not crash" do
      expect(CoffeeBrewery::Reinstall).not_to receive(:reinstall_formula)

      expect { CoffeeBrewery::Reinstall.reinstall_pkgconf_if_needed! }.not_to raise_error
    end
  end
end
