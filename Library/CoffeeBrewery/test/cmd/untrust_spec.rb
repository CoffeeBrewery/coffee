# typed: strict
# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "cmd/untrust"
require "trust"

RSpec.describe CoffeeBrewery::Cmd::Untrust, :trust_store do
  it_behaves_like "parseable arguments"

  it "untrusts a given tap", :integration_test do
    trust_home = Pathname(TEST_TMPDIR)/"untrust-tap"
    trust_home.mkpath
    (trust_home/"trust.json").write(<<~JSON)
      {
        "trustedtaps": [
          "thirdparty/foo"
        ]
      }
    JSON

    expect { coffee "untrust", "thirdparty/foo", "COFFEEBREWER_USER_CONFIG_HOME" => trust_home.to_s }
      .to output(%r{Untrusted tap: thirdparty/foo}).to_stdout
      .and be_a_success

    expect(trust_home/"trust.json").not_to exist
  ensure
    FileUtils.rm_rf trust_home if trust_home
  end

  it "notes official taps are always trusted" do
    expect { described_class.new(["homebrew/core"]).run }
      .to output("Official tap homebrew/core is always trusted.\n").to_stdout
  end

  it "untrusts a command with the plural switch alias" do
    expect(CoffeeBrewery::Trust).to receive(:untrust!).with(:command, "thirdparty/foo/hello").and_return(true)

    expect { described_class.new(["--commands", "thirdparty/foo/hello"]).run }
      .to output("Untrusted command: thirdparty/foo/hello\n").to_stdout
  end

  it "untrusts legacy and remote-qualified entries for custom-remote tap items" do
    tap = Tap.fetch("thirdparty", "custom")
    tap.path.mkpath
    system "git", "-C", tap.path.to_s, "init"
    system "git", "-C", tap.path.to_s, "remote", "add", "origin", "https://gitlab.com/other/repo"
    CoffeeBrewery::Trust.trust!(:formula, "thirdparty/custom/bar")
    CoffeeBrewery::Trust.trust!(:formula, "https://gitlab.com/other/repo/bar")

    expect { described_class.new(["--formula", "thirdparty/custom/bar"]).run }
      .to output("Untrusted formula: thirdparty/custom/bar\n").to_stdout
    expect(CoffeeBrewery::Trust.trusted_entries(:formula)).to be_empty
    expect(CoffeeBrewery::Trust.trusted?(:formula, "thirdparty/custom/bar")).to be(false)
  ensure
    CoffeeBrewery::Trust.clear!(:formula)
    FileUtils.rm_rf COFFEEBREWER_TAP_DIRECTORY/"thirdparty"
  end

  it "untrusts items stored under a custom remote whose case differs" do
    tap = Tap.fetch("thirdparty", "custom")
    tap.path.mkpath
    system "git", "-C", tap.path.to_s, "init"
    system "git", "-C", tap.path.to_s, "remote", "add", "origin", "https://GitLab.com/Other/Repo"
    CoffeeBrewery::Trust.trust!(*CoffeeBrewery::Trust.target("thirdparty/custom/bar", type: :formula))

    expect { described_class.new(["thirdparty/custom"]).run }
      .to output("Untrusted tap: https://gitlab.com/other/repo\n").to_stdout
    expect(CoffeeBrewery::Trust.trusted?(:formula, "thirdparty/custom/bar")).to be(false)
  ensure
    CoffeeBrewery::Trust.clear!(:formula)
    FileUtils.rm_rf COFFEEBREWER_TAP_DIRECTORY/"thirdparty"
  end

  it "untrusts trusted items from a tap" do
    expect(CoffeeBrewery::Trust).to receive(:untrust!).with(:tap, "thirdparty/foo").and_return(false)
    allow(CoffeeBrewery::Trust).to receive(:trusted_entries).with(:formula).and_return(["thirdparty/foo/bar"])
    allow(CoffeeBrewery::Trust).to receive(:trusted_entries).with(:cask).and_return(["thirdparty/foo/baz"])
    allow(CoffeeBrewery::Trust).to receive(:trusted_entries).with(:command).and_return(["thirdparty/foo/hello"])
    expect(CoffeeBrewery::Trust).to receive(:untrust!).with(:formula, "thirdparty/foo/bar").and_return(true)
    expect(CoffeeBrewery::Trust).to receive(:untrust!).with(:cask, "thirdparty/foo/baz").and_return(true)
    expect(CoffeeBrewery::Trust).to receive(:untrust!).with(:command, "thirdparty/foo/hello").and_return(true)

    expect { described_class.new(["thirdparty/foo"]).run }
      .to output("Untrusted tap: thirdparty/foo\n").to_stdout
  end

  it "lists untrusted entries with no arguments" do
    tap = Tap.fetch("untrustlist", "foo")
    tap.cask_dir.mkpath
    (tap.cask_dir/"bar.rb").write("cask 'bar'\n")

    expect { described_class.new([]).run }
      .to output(<<~EOS).to_stdout
        Untrusted taps:
          untrustlist/foo
        Untrusted casks:
          untrustlist/foo/bar
      EOS
  ensure
    FileUtils.rm_rf COFFEEBREWER_TAP_DIRECTORY/"untrustlist"
  end
end
