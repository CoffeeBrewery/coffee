# typed: true
# frozen_string_literal: true

require "bundle"
require "bundle/dumper"
require "bundle/brew_services"
require "cask"

RSpec.describe CoffeeBrewery::Bundle::Dumper do
  subject(:dumper) { described_class }

  before do
    ENV["COFFEEBREWER_BUNDLE_FILE"] = ""

    allow(CoffeeBrewery::Bundle).to receive(:cask_installed?).and_return(true)
    allow(CoffeeBrewery::Bundle::MacAppStore).to receive(:package_manager_executable).and_return(nil)
    allow(CoffeeBrewery::Bundle::Winget).to receive(:package_manager_executable).and_return(nil)
    allow(CoffeeBrewery::Bundle::VscodeExtension).to receive(:package_manager_executable).and_return(nil)
    CoffeeBrewery::Bundle::Brew.reset!
    CoffeeBrewery::Bundle::Tap.reset!
    CoffeeBrewery::Bundle::Cask.reset!
    CoffeeBrewery::Bundle::MacAppStore.reset!
    CoffeeBrewery::Bundle::Winget.reset!
    CoffeeBrewery::Bundle::VscodeExtension.reset!
    CoffeeBrewery::Bundle::Go.reset!
    CoffeeBrewery::Bundle::Cargo.reset!
    CoffeeBrewery::Bundle::Uv.reset!
    CoffeeBrewery::Bundle::Brew::Services.reset!

    chrome     = instance_double(Cask::Cask,
                                 full_name: "google-chrome",
                                 to_s:      "google-chrome",
                                 config:    nil)
    java       = instance_double(Cask::Cask,
                                 full_name: "java",
                                 to_s:      "java",
                                 config:    nil)
    iterm2beta = instance_double(Cask::Cask,
                                 full_name: "homebrew/cask-versions/iterm2-beta",
                                 to_s:      "iterm2-beta",
                                 config:    nil)

    allow(Cask::Caskroom).to receive(:casks).and_return([chrome, java, iterm2beta])
    allow(CoffeeBrewery::Bundle::Go).to receive(:package_manager_executable).and_return(nil)
    allow(CoffeeBrewery::Bundle::Cargo).to receive(:package_manager_executable).and_return(nil)
    allow(CoffeeBrewery::Bundle::Uv).to receive(:package_manager_executable).and_return(nil)
    allow(Tap).to receive(:select).and_return([])
  end

  # `Tap.taps` and `Cask.casks` memoise the stubbed doubles, which must not outlive the example.
  after do
    CoffeeBrewery::Bundle::Tap.reset!
    CoffeeBrewery::Bundle::Cask.reset!
  end

  it "generates output" do
    expect(dumper.build_brewfile(
             describe: false, no_restart: false, formulae: true, taps: true, casks: true,
             extension_types: { mas: true, vscode: true, cargo: true, flatpak: false, go: true, uv: true }
           )).to eql("cask \"google-chrome\"\ncask \"java\"\ncask \"homebrew/cask-versions/iterm2-beta\"\n")
  end

  it "dumps tap trust entries not represented by dumped formulae" do
    tap = instance_double(Tap, name: "thirdparty/tap", custom_remote?: false, remote: nil)
    allow(tap).to receive(:matches_reference?) { |reference| reference == "thirdparty/tap" }
    allow(Tap).to receive(:select).and_return([tap])
    allow(CoffeeBrewery::Bundle::Brew).to receive(:formulae).and_return([
      {
        args:                  [],
        full_name:             "thirdparty/tap/requested",
        installed_on_request?: true,
        link?:                 nil,
      },
      {
        args:                  [],
        full_name:             "thirdparty/tap/dependency",
        installed_on_request?: false,
        link?:                 nil,
      },
    ])
    allow(CoffeeBrewery::Bundle::Brew::Services).to receive(:started?).and_return(false)
    allow(CoffeeBrewery::Trust).to receive(:trusted_entries).with(:tap).and_return([])
    allow(CoffeeBrewery::Trust).to receive(:trusted_entries).with(:formula)
                                                       .and_return(%w[
                                                         thirdparty/tap/dependency
                                                         thirdparty/tap/requested
                                                       ])
    allow(CoffeeBrewery::Trust).to receive(:trusted_entries).with(:cask).and_return([])
    allow(CoffeeBrewery::Trust).to receive(:trusted_entries).with(:command).and_return([])

    expect(dumper.build_brewfile(
             describe: false, no_restart: false, formulae: true, taps: true, casks: false,
             extension_types: {}
           )).to eql(<<~BREWFILE)
             tap "thirdparty/tap", trusted: { formulae: ["dependency"] }
             coffee "thirdparty/tap/requested", trusted: true
           BREWFILE
  end

  it "determines the brewfile correctly" do
    expect(dumper.brewfile_path).to eql(Pathname.new(Dir.pwd).join("Brewfile"))
  end

  it "preserves the legacy extension dump order" do
    allow(CoffeeBrewery::Bundle::Winget).to receive(:dump)
      .and_return('winget "PowerToys", id: "XP89DCGQ3K6VLD", source: "msstore"')
    allow(CoffeeBrewery::Bundle::Go).to receive(:dump).and_return('go "github.com/charmbracelet/crush"')
    allow(CoffeeBrewery::Bundle::Cargo).to receive(:dump).and_return('cargo "ripgrep"')
    allow(CoffeeBrewery::Bundle::Uv).to receive(:dump).and_return('uv "mkdocs"')
    allow(CoffeeBrewery::Bundle::Flatpak).to receive(:dump).and_return('flatpak "org.gnome.Calculator"')

    expect(dumper.build_brewfile(
             describe: false, no_restart: false, formulae: false, taps: false, casks: false,
             extension_types: { mas: false, winget: true, vscode: false, cargo: true, flatpak: true, go: true,
                                uv: true }
           )).to eql(<<~BREWFILE)
             go "github.com/charmbracelet/crush"
             cargo "ripgrep"
             uv "mkdocs"
             flatpak "org.gnome.Calculator"
             winget "PowerToys", id: "XP89DCGQ3K6VLD", source: "msstore"
           BREWFILE
  end
end
