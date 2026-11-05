# typed: true
# frozen_string_literal: true

require "bundle"
require "bundle/subcommand/install"
require "bundle/skipper"

RSpec.describe CoffeeBrewery::Cmd::Bundle::InstallSubcommand do
  subject(:install_subcommand) do
    described_class.new(
      args_for_subcommand(:install, quiet?: false, global?: global, cleanup?: false, force_cleanup?: false),
      context: bundle_subcommand_context(:install, global:),
    )
  end

  let(:global) { false }

  before do
    allow_any_instance_of(IO).to receive(:puts)
  end

  context "when a Brewfile is not found" do
    it "raises an error" do
      allow_any_instance_of(Pathname).to receive(:read).and_raise(Errno::ENOENT)
      expect { install_subcommand.run }.to raise_error(RuntimeError)
    end
  end

  context "when a Brewfile is found", :no_api do
    before do
      CoffeeBrewery::Bundle::Cask.reset!
      allow(CoffeeBrewery::Bundle).to receive(:coffee).and_return(true)
      allow(CoffeeBrewery::Bundle::Brew).to receive(:formula_installed_and_up_to_date?).and_return(false)
      allow(CoffeeBrewery::Bundle::Cask).to receive(:installable_or_upgradable?).and_return(true)
      allow(CoffeeBrewery::Bundle::Tap).to receive(:installed_taps).and_return([])
    end

    let(:brewfile_contents) do
      <<~EOS
        tap 'phinze/cask'
        coffee 'mysql', conflicts_with: ['mysql56']
        cask 'phinze/cask/google-chrome', greedy: true
        mas '1Password', id: 443987910
        vscode 'GitHub.codespaces'
        flatpak 'org.gnome.Calculator'
      EOS
    end

    it "does not raise an error" do
      allow(CoffeeBrewery::Bundle::Tap).to receive(:preinstall!).and_return(false)
      allow(CoffeeBrewery::Bundle::VscodeExtension).to receive(:preinstall!).and_return(false)
      allow(CoffeeBrewery::Bundle::Flatpak).to receive(:preinstall!).and_return(false)
      allow(CoffeeBrewery::Bundle::Brew).to receive_messages(preinstall!: true, install!: true)
      allow(CoffeeBrewery::Bundle::Cask).to receive_messages(preinstall!: true, install!: true)
      allow(CoffeeBrewery::Bundle::MacAppStore).to receive_messages(preinstall!: true, install!: true)
      allow_any_instance_of(Pathname).to receive(:read).and_return(brewfile_contents)
      expect { install_subcommand.run }.not_to raise_error
    end

    it "#dsl returns a valid DSL" do
      allow(CoffeeBrewery::Bundle::Tap).to receive(:preinstall!).and_return(false)
      allow(CoffeeBrewery::Bundle::VscodeExtension).to receive(:preinstall!).and_return(false)
      allow(CoffeeBrewery::Bundle::Flatpak).to receive(:preinstall!).and_return(false)
      allow(CoffeeBrewery::Bundle::Brew).to receive_messages(preinstall!: true, install!: true)
      allow(CoffeeBrewery::Bundle::Cask).to receive_messages(preinstall!: true, install!: true)
      allow(CoffeeBrewery::Bundle::MacAppStore).to receive_messages(preinstall!: true, install!: true)
      allow_any_instance_of(Pathname).to receive(:read).and_return(brewfile_contents)
      install_subcommand.run
      expect(install_subcommand.dsl.entries.first.name).to eql("phinze/cask")
    end

    it "does not raise an error when skippable" do
      expect(CoffeeBrewery::Bundle::Brew).not_to receive(:install!)

      allow(CoffeeBrewery::Bundle::Skipper).to receive(:skip?).and_return(true)
      allow_any_instance_of(Pathname).to receive(:read)
        .and_return("coffee 'mysql'")
      expect { install_subcommand.run }.not_to raise_error
    end

    it "exits on failures" do
      allow(CoffeeBrewery::Bundle::Brew).to receive_messages(preinstall!: true, install!: false)
      allow(CoffeeBrewery::Bundle::Cask).to receive_messages(preinstall!: true, install!: false)
      allow(CoffeeBrewery::Bundle::MacAppStore).to receive_messages(preinstall!: true, install!: false)
      allow(CoffeeBrewery::Bundle::Tap).to receive_messages(preinstall!: true, install!: false)
      allow(CoffeeBrewery::Bundle::VscodeExtension).to receive_messages(preinstall!: true, install!: false)
      allow(CoffeeBrewery::Bundle::Flatpak).to receive_messages(preinstall!: true, install!: false)
      allow_any_instance_of(Pathname).to receive(:read).and_return(brewfile_contents)

      expect { install_subcommand.run }.to raise_error(SystemExit)
    end

    it "skips installs from failed taps" do
      allow(CoffeeBrewery::Bundle::Cask).to receive(:preinstall!).and_return(false)
      allow(CoffeeBrewery::Bundle::Tap).to receive_messages(preinstall!: true, install!: false)
      allow(CoffeeBrewery::Bundle::Brew).to receive_messages(preinstall!: true, install!: true)
      allow(CoffeeBrewery::Bundle::MacAppStore).to receive_messages(preinstall!: true, install!: true)
      allow(CoffeeBrewery::Bundle::VscodeExtension).to receive_messages(preinstall!: true, install!: true)
      allow(CoffeeBrewery::Bundle::Flatpak).to receive_messages(preinstall!: true, install!: true)
      allow_any_instance_of(Pathname).to receive(:read).and_return(brewfile_contents)

      expect { install_subcommand.run }.to raise_error(SystemExit)
    end

    it "marks Brewfile formulae as installed_on_request after installing" do
      allow(CoffeeBrewery::Bundle::Tap).to receive(:preinstall!).and_return(false)
      allow(CoffeeBrewery::Bundle::VscodeExtension).to receive(:preinstall!).and_return(false)
      allow(CoffeeBrewery::Bundle::Flatpak).to receive(:preinstall!).and_return(false)
      allow(CoffeeBrewery::Bundle::Brew).to receive_messages(preinstall!: true, install!: true)
      allow(CoffeeBrewery::Bundle::Cask).to receive_messages(preinstall!: true, install!: true)
      allow(CoffeeBrewery::Bundle::MacAppStore).to receive_messages(preinstall!: true, install!: true)
      allow_any_instance_of(Pathname).to receive(:read).and_return("coffee 'test_formula'")

      expect(CoffeeBrewery::Bundle).to receive(:mark_as_installed_on_request!)
      install_subcommand.run
    end

    it "asks before cleaning up when COFFEEBREWER_BUNDLE_INSTALL_CLEANUP is set" do
      allow(CoffeeBrewery::EnvConfig).to receive(:bundle_install_cleanup?).and_return(true)
      context = bundle_subcommand_context(:install, ask: true)
      subcommand = described_class.new(
        args_for_subcommand(:install, quiet?: false, global?: false, force_cleanup?: false),
        context:,
      )
      allow(CoffeeBrewery::Bundle::Installer).to receive(:install!).and_return(true)
      allow(CoffeeBrewery::Bundle).to receive(:mark_as_installed_on_request!)
      allow_any_instance_of(Pathname).to receive(:read).and_return("coffee 'test_formula'")

      expect(CoffeeBrewery::Cmd::Bundle::CleanupSubcommand).to receive(:cleanup).with(
        global: false, file: nil, zap: false, force: false, ask: true, dsl: anything,
      )

      subcommand.run
    end

    it "force cleans up when --force-cleanup is passed" do
      args = args_for_subcommand(:install, quiet?: false, global?: false, cleanup?: false, force_cleanup?: true)
      subcommand = described_class.new(args,
                                       context: bundle_subcommand_context(:install,
                                                                          ask: true))
      allow(CoffeeBrewery::Bundle::Installer).to receive(:install!).and_return(true)
      allow(CoffeeBrewery::Bundle).to receive(:mark_as_installed_on_request!)
      allow_any_instance_of(Pathname).to receive(:read).and_return("coffee 'test_formula'")

      expect(CoffeeBrewery::Cmd::Bundle::CleanupSubcommand).to receive(:cleanup).with(
        global: false, file: nil, zap: false, force: true, ask: true, dsl: anything,
      )

      subcommand.run
    end

    it "force cleans up when --force and COFFEEBREWER_BUNDLE_INSTALL_CLEANUP are set" do
      allow(CoffeeBrewery::EnvConfig).to receive(:bundle_install_cleanup?).and_return(true)
      subcommand = described_class.new(
        args_for_subcommand(:install, quiet?: false, global?: false, force_cleanup?: false),
        context: bundle_subcommand_context(:install, force: true),
      )
      allow(CoffeeBrewery::Bundle::Installer).to receive(:install!).and_return(true)
      allow(CoffeeBrewery::Bundle).to receive(:mark_as_installed_on_request!)
      allow_any_instance_of(Pathname).to receive(:read).and_return("coffee 'test_formula'")

      expect(CoffeeBrewery::Cmd::Bundle::CleanupSubcommand).to receive(:cleanup).with(
        global: false, file: nil, zap: false, force: true, ask: false, dsl: anything,
      )

      subcommand.run
    end

    it "rejects COFFEEBREWER_BUNDLE_INSTALL_CLEANUP without force or ask" do
      allow(CoffeeBrewery::EnvConfig).to receive(:bundle_install_cleanup?).and_return(true)
      args = args_for_subcommand(:install, quiet?: false, global?: false, force_cleanup?: false)
      expect { described_class.new(args, context: bundle_subcommand_context(:install)).run }
        .to raise_error(UsageError, /cleanup requires `--force`, `--force-cleanup` or `\$COFFEEBREWER_ASK`/)
    end

    it "rejects --zap without a cleanup flag" do
      args = args_for_subcommand(:install, quiet?: false, global?: false, cleanup?: false, force_cleanup?: false,
                                           zap?: true)
      expect { described_class.new(args, context: bundle_subcommand_context(:install)).run }
        .to raise_error(UsageError, /`--zap` cannot be passed without `--force-cleanup`/)
    end
  end
end
