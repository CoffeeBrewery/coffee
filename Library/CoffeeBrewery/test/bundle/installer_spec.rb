# typed: true
# frozen_string_literal: true

require "bundle"
require "attestation"
require "bundle/dsl"
require "bundle/installer"
require "trust"
require "formulary"

RSpec.describe CoffeeBrewery::Bundle::Installer do
  let(:formula_entry) { CoffeeBrewery::Bundle::Dsl::Entry.new(:coffee, "mysql") }
  let(:second_formula_entry) { CoffeeBrewery::Bundle::Dsl::Entry.new(:coffee, "redis") }
  let(:cask_options) { { args: {}, full_name: "homebrew/cask/google-chrome" } }
  let(:cask_entry) { CoffeeBrewery::Bundle::Dsl::Entry.new(:cask, "google-chrome", cask_options) }
  let(:flatpak_entry) do
    CoffeeBrewery::Bundle::Dsl::Entry.new(:flatpak, "org.gnome.Calculator", { remote: "flathub" })
  end

  before do
    described_class.reset!
    allow(CoffeeBrewery::Bundle::Skipper).to receive(:skip?).and_return(false)
    allow(CoffeeBrewery::Bundle::Brew).to receive_messages(formula_upgradable?: false, install!: true)
    allow(CoffeeBrewery::Bundle::Brew).to receive_messages(formula_installed_and_up_to_date?: false,
                                                      preinstall!:                       true)
    allow(CoffeeBrewery::Bundle::Cask).to receive_messages(cask_upgradable?: false, install!: true)
    allow(CoffeeBrewery::Bundle::Cask).to receive_messages(cask_installed_and_up_to_date?: false,
                                                      installable_or_upgradable?:     true,
                                                      preinstall!:                    true)
    allow(CoffeeBrewery::Bundle::Tap).to receive_messages(preinstall!: true, install!: true, installed_taps: [])
    allow(Formula).to receive(:[]) { |name|
      instance_double(Formula, full_name: name, tap: CoreTap.instance, conflicts: [])
    }
    allow(::Cask::CaskLoader).to receive(:load)
      .and_return(instance_double(::Cask::Cask, full_name: "google-chrome",
                                                tap:       CoreCaskTap.instance))
    # Formula and cask entries share one batched `coffee install`, so specs asserting a
    # specific `Bundle.coffee` call need the others to fall through to a stub.
    allow(CoffeeBrewery::Bundle).to receive(:coffee).and_return(true)
    # Entries can name a tap the Brewfile does not, which is otherwise cloned for real.
    allow_any_instance_of(::Tap).to receive(:ensure_installed!)
  end

  it "resets cached package state before installing" do
    expect(CoffeeBrewery::Bundle::Cask).to receive(:casks).twice.and_return(
      [double(to_s: "stale")],
      [double(to_s: "google-chrome")],
    )

    expect(CoffeeBrewery::Bundle::Cask.cask_names).to eq(["stale"])

    described_class.reset!
    described_class.install!([cask_entry], verbose: false, force: false, quiet: true)
  end

  it "fetches and installs formulae and casks in one `coffee install`" do
    expect(CoffeeBrewery::Bundle).to receive(:coffee)
      .with("install", "--adopt", "homebrew/core/mysql", "homebrew/cask/google-chrome", verbose: false)
      .once.and_return(true)

    described_class.install!([formula_entry, cask_entry], quiet: true)
  end

  it "does not run a separate fetch" do
    expect(CoffeeBrewery::Bundle).not_to receive(:coffee).with("fetch", any_args)

    described_class.install!([formula_entry], quiet: true)
  end

  it "fails a missing Flatpak entry without skipping following entries or claiming success" do
    tap_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:tap, "example/tap")
    allow(CoffeeBrewery::Bundle::Flatpak).to receive(:package_manager_executable).and_return(nil)
    expect(CoffeeBrewery::Bundle::Tap).to receive(:preinstall!)
      .with("example/tap", no_upgrade: false, verbose: false)
      .and_return(true)
    expect(CoffeeBrewery::Bundle::Tap).to receive(:install!)
      .with("example/tap", preinstall: true, no_upgrade: false, verbose: false, force: false)
      .and_return(true)

    result = T.let(nil, T.nilable(T::Boolean))
    expect do
      result = described_class.install!([flatpak_entry, tap_entry], quiet: false)
    end.to output(
      /flatpak is not installed.*Installing org\.gnome\.Calculator has failed!.*`coffee bundle` failed!/m,
    ).to_stderr.and not_to_output(/Using org\.gnome\.Calculator/).to_stdout
    expect(result).to be(false)
  end

  it "trusts `trusted: true` formulae before loading them" do
    trusted_formula_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:coffee, "thirdparty/tap/bar", { trusted: true })

    allow(CoffeeBrewery::Bundle::Tap).to receive(:installed_taps).and_return(["thirdparty/tap"])

    expect(CoffeeBrewery::Trust).to receive(:trust!).with(:formula, "thirdparty/tap/bar").ordered.and_return(true)
    expect(Formula).to receive(:[]).with("thirdparty/tap/bar").ordered
                                   .and_return(instance_double(Formula, full_name: "thirdparty/tap/bar",
                                                                        tap:       Tap.fetch("thirdparty/tap"),
                                                                        conflicts: []))

    described_class.install!([trusted_formula_entry], quiet: true)
  end

  it "trusts `trusted: true` casks before loading them" do
    options = { args: {}, full_name: "thirdparty/tap/baz", trusted: true }
    trusted_cask_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:cask, "baz", options)

    allow(CoffeeBrewery::Bundle::Tap).to receive(:installed_taps).and_return(["thirdparty/tap"])

    expect(CoffeeBrewery::Trust).to receive(:trust!).with(:cask, "thirdparty/tap/baz").ordered.and_return(true)
    expect(::Cask::CaskLoader).to receive(:load).with("thirdparty/tap/baz").ordered
                                                .and_return(instance_double(::Cask::Cask,
                                                                            full_name: "thirdparty/tap/baz",
                                                                            tap:       Tap.fetch("thirdparty/tap")))

    described_class.install!([trusted_cask_entry], quiet: true)
  end

  it "trusts `trusted: true` taps by name" do
    tap_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:tap, "thirdparty/tap", { trusted: true })

    expect(CoffeeBrewery::Trust).to receive(:trust!).with(:tap, "thirdparty/tap").and_return(true)

    described_class.install!([tap_entry], quiet: true)
  end

  it "trusts `trusted: true` taps with a clone target by their remote reference" do
    tap_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(
      :tap, "thirdparty/custom", { clone_target: "https://github.com/thirdparty/homebrew-custom", trusted: true }
    )

    expect(CoffeeBrewery::Trust).to receive(:trust!).with(:tap, "thirdparty/custom").and_return(true)

    described_class.install!([tap_entry], quiet: true)
  end

  it "trusts tap `trusted` hash entries" do
    tap_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(
      :tap, "thirdparty/tap",
      {
        trusted: {
          formula:  "foo",
          formulae: ["bar"],
          cask:     "baz",
          casks:    ["qux"],
          command:  "hello",
          commands: ["world"],
        },
      }
    )

    expect(CoffeeBrewery::Trust).to receive(:trust!).with(:formula, "thirdparty/tap/foo").and_return(true)
    expect(CoffeeBrewery::Trust).to receive(:trust!).with(:formula, "thirdparty/tap/bar").and_return(true)
    expect(CoffeeBrewery::Trust).to receive(:trust!).with(:cask, "thirdparty/tap/baz").and_return(true)
    expect(CoffeeBrewery::Trust).to receive(:trust!).with(:cask, "thirdparty/tap/qux").and_return(true)
    expect(CoffeeBrewery::Trust).to receive(:trust!).with(:command, "thirdparty/tap/hello").and_return(true)
    expect(CoffeeBrewery::Trust).to receive(:trust!).with(:command, "thirdparty/tap/world").and_return(true)

    described_class.install!([tap_entry], quiet: true)
  end

  it "rejects unsupported tap `trusted` hash keys" do
    tap_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:tap, "thirdparty/tap", { trusted: { tap: "foo" } })

    expect { described_class.install!([tap_entry], quiet: true) }
      .to raise_error(UsageError, /Unsupported trusted keys: tap/)
  end

  it "does not trust unqualified `trusted: true` names" do
    trusted_formula_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:coffee, "mysql", { trusted: true })

    expect(CoffeeBrewery::Bundle::Trust.entries([trusted_formula_entry])).to be_empty
  end

  describe "batched CoffeeBrewery installation" do
    before do
      allow(CoffeeBrewery::Bundle).to receive(:coffee).and_return(true)
    end

    it "installs formulae needing installation in a single `coffee install`" do
      expect(CoffeeBrewery::Bundle).to receive(:coffee)
        .with("install", "homebrew/core/mysql", "homebrew/core/redis", verbose: false)
        .and_return(true)

      described_class.install!([formula_entry, second_formula_entry], quiet: true)
    end

    it "installs and upgrades formulae in a single `coffee install`" do
      allow(CoffeeBrewery::Bundle::Brew).to receive(:formula_installed?).with("mysql").and_return(false)
      allow(CoffeeBrewery::Bundle::Brew).to receive(:formula_installed?).with("redis").and_return(true)

      expect(CoffeeBrewery::Bundle).to receive(:coffee)
        .with("install", "homebrew/core/mysql", "homebrew/core/redis", verbose: false)
        .and_return(true)

      described_class.install!([formula_entry, second_formula_entry], quiet: true)
    end

    it "counts every entry of a successful batch as installed" do
      expect(described_class.install!([formula_entry, second_formula_entry], quiet: true)).to be(true)
    end

    it "attributes a failed batch to the entries that are not installed afterwards" do
      allow(CoffeeBrewery::Bundle).to receive(:coffee).with("install", any_args).and_return(false)
      allow(CoffeeBrewery::Bundle::Brew).to receive(:formula_installed_and_up_to_date?)
        .with("mysql", no_upgrade: false).and_return(true)
      allow(CoffeeBrewery::Bundle::Brew).to receive(:formula_installed_and_up_to_date?)
        .with("redis", no_upgrade: false).and_return(false)

      expect do
        expect(described_class.install!([formula_entry, second_formula_entry], quiet: true)).to be(false)
      end.to output(/Installing redis has failed!/).to_stderr
    end

    it "refreshes the cached view of what is installed before finishing each entry" do
      expect(CoffeeBrewery::Bundle::Brew).to receive(:reset!).and_call_original.ordered
      expect(CoffeeBrewery::Bundle::Brew).to receive(:install!)
        .with("mysql", preinstall: false, no_upgrade: false, verbose: false, force: false)
        .ordered
        .and_return(true)

      described_class.install!([formula_entry], quiet: true)
    end

    it "keeps an entry carrying options out of the batch" do
      service_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:coffee, "redis", { restart_service: :changed })

      expect(CoffeeBrewery::Bundle).to receive(:coffee)
        .with("install", "homebrew/core/mysql", verbose: false)
        .and_return(true)
      expect(CoffeeBrewery::Bundle::Brew).to receive(:install!)
        .with("redis", restart_service: :changed, preinstall: true, no_upgrade: false, verbose: false, force: false)
        .and_return(true)

      described_class.install!([formula_entry, service_entry], quiet: true)
    end

    it "keeps an unloadable formula out of the batch" do
      allow(Formula).to receive(:[]).with("mysql").and_raise(FormulaUnavailableError, "mysql")

      expect(CoffeeBrewery::Bundle).not_to receive(:coffee).with("install", any_args)
      expect(CoffeeBrewery::Bundle::Brew).to receive(:install!)
        .with("mysql", preinstall: true, no_upgrade: false, verbose: false, force: false)
        .and_return(true)

      described_class.install!([formula_entry], quiet: true)
    end

    context "with formula conflicts" do
      let(:conflicting_formula) do
        formula("mysql", tap: CoreTap.instance) do
          T.bind(self, T.class_of(Formula))
          url "mysql-1.0"
          conflicts_with "mysql@8.4"
        end
      end
      let(:unrelated_formula) do
        formula("redis", tap: CoreTap.instance) do
          T.bind(self, T.class_of(Formula))
          url "redis-1.0"
        end
      end

      before do
        CoffeeBrewery::Bundle::Brew.reset!
        allow(Formula).to receive(:installed).and_return([])
        allow(Formula).to receive(:[]).with("mysql").and_return(conflicting_formula)
        allow(Formula).to receive(:[]).with("redis").and_return(unrelated_formula)
        allow(CoffeeBrewery::Bundle::Brew).to receive(:install!).and_call_original
      end

      it "batches a formula whose conflicts are neither installed nor requested" do
        expect(CoffeeBrewery::Bundle).to receive(:coffee)
          .with("install", "homebrew/core/mysql", "homebrew/core/redis", verbose: false)
          .and_return(true)

        described_class.install!([formula_entry, second_formula_entry], quiet: true)
      end

      it "keeps batching when an unrelated formula has install arguments" do
        entry_with_args = CoffeeBrewery::Bundle::Dsl::Entry.new(:coffee, "redis", { args: ["build-from-source"] })

        expect(CoffeeBrewery::Bundle).to receive(:coffee)
          .with("install", "homebrew/core/mysql", verbose: false)
          .and_return(true)

        described_class.install!([formula_entry, entry_with_args], quiet: true)
      end

      it "unlinks installed conflicts before installing a formula" do
        (COFFEEBREWER_CELLAR/"mysql@8.4/8.4").mkpath

        expect(CoffeeBrewery::Bundle).to receive(:coffee).with("unlink", "mysql@8.4", verbose: false)
                                                  .ordered.and_return(true)
        expect(CoffeeBrewery::Bundle).to receive(:coffee).with("install", "--formula", "mysql", verbose: false)
                                                  .ordered.and_return(true)

        described_class.install!([formula_entry], quiet: true)
      end

      it "unlinks a conflicting formula requested through an alias before installing a formula" do
        requested_formula = formula("mysql@8.4", tap: CoreTap.instance) do
          T.bind(self, T.class_of(Formula))
          url "mysql-8.4"
        end
        allow(Formula).to receive(:[]).with("mysql-lts").and_return(requested_formula)

        expect(CoffeeBrewery::Bundle).to receive(:coffee).with("install", "homebrew/core/mysql@8.4", verbose: false)
                                                  .ordered do
          requested_formula.prefix.mkpath
          true
        end
        expect(CoffeeBrewery::Bundle).to receive(:coffee).with("unlink", "mysql@8.4", verbose: false)
                                                  .ordered.and_return(true)
        expect(CoffeeBrewery::Bundle).to receive(:coffee).with("install", "--formula", "mysql", verbose: false)
                                                  .ordered.and_return(true)

        described_class.install!([CoffeeBrewery::Bundle::Dsl::Entry.new(:coffee, "mysql-lts"), formula_entry], quiet: true)
      end

      it "expands dependencies once when checking multiple formulae for conflicts" do
        second_formula = formula("redis", tap: CoreTap.instance) do
          T.bind(self, T.class_of(Formula))
          url "redis-1.0"
          conflicts_with "valkey"
        end
        allow(Formula).to receive(:[]).with("redis").and_return(second_formula)

        expect(described_class).to receive(:formula_names_with_dependencies).once.and_call_original

        described_class.install!([formula_entry, second_formula_entry], quiet: true)
      end
    end

    context "with conflicts introduced by dependencies" do
      let(:conflicting_formula) do
        formula("ctags", tap: CoreTap.instance) do
          T.bind(self, T.class_of(Formula))
          url "ctags-1.0"
          conflicts_with "universal-ctags"
        end
      end
      let(:dependency_formula) do
        formula("universal-ctags") do
          T.bind(self, T.class_of(Formula))
          url "universal-ctags-1.0"
        end
      end

      before do
        CoffeeBrewery::Bundle::Brew.reset!
        allow(Formula).to receive(:installed).and_return([])
        allow(Formula).to receive(:[]).with("ctags").and_return(conflicting_formula)
        allow(CoffeeBrewery::Bundle::Brew).to receive(:install!).and_call_original
      end

      it "unlinks conflicts from transitive optional formula dependencies" do
        requested_formula = formula("ctags-lsp", tap: CoreTap.instance) do
          T.bind(self, T.class_of(Formula))
          url "ctags-lsp-1.0"
          depends_on "backend"
        end
        stub_formula_loader(formula("backend") do
          T.bind(self, T.class_of(Formula))
          url "backend-1.0"
          depends_on "universal-ctags" => :optional
        end)
        stub_formula_loader(dependency_formula)
        allow(Formula).to receive(:[]).with("ctags-lsp").and_return(requested_formula)

        expect(CoffeeBrewery::Bundle).to receive(:coffee).with("install", "homebrew/core/ctags-lsp", verbose: false)
                                                  .ordered do
          dependency_formula.prefix.mkpath
          true
        end
        expect(CoffeeBrewery::Bundle).to receive(:coffee).with("unlink", "universal-ctags", verbose: false)
                                                  .ordered.and_return(true)
        expect(CoffeeBrewery::Bundle).to receive(:coffee).with("install", "--formula", "ctags", verbose: false)
                                                  .ordered.and_return(true)

        described_class.install!([
          CoffeeBrewery::Bundle::Dsl::Entry.new(:coffee, "ctags-lsp"),
          CoffeeBrewery::Bundle::Dsl::Entry.new(:coffee, "ctags"),
        ], quiet: true)
      end

      it "unlinks conflicts installed by a cask before installing a formula" do
        requested_cask = ::Cask::Cask.new("editor", tap: CoreCaskTap.instance) do
          version "1.0"
          url "https://example.com/editor.zip"
          depends_on formula: "universal-ctags"
        end
        allow(Formula).to receive(:[]).with("universal-ctags").and_return(dependency_formula)
        allow(::Cask::CaskLoader).to receive(:load).with("editor").and_return(requested_cask)

        expect(CoffeeBrewery::Bundle).to receive(:coffee).with("install", "--adopt", "homebrew/cask/editor", verbose: false)
                                                  .ordered do
          dependency_formula.prefix.mkpath
          true
        end
        expect(CoffeeBrewery::Bundle).to receive(:coffee).with("unlink", "universal-ctags", verbose: false)
                                                  .ordered.and_return(true)
        expect(CoffeeBrewery::Bundle).to receive(:coffee).with("install", "--formula", "ctags", verbose: false)
                                                  .ordered.and_return(true)

        described_class.install!([
          CoffeeBrewery::Bundle::Dsl::Entry.new(:cask, "editor"),
          CoffeeBrewery::Bundle::Dsl::Entry.new(:coffee, "ctags"),
        ], quiet: true)
      end
    end

    it "keeps an already up-to-date entry out of the batch but still finishes it" do
      allow(CoffeeBrewery::Bundle::Brew).to receive(:preinstall!).with("mysql", any_args).and_return(false)

      expect(CoffeeBrewery::Bundle).not_to receive(:coffee).with("install", any_args)
      expect(CoffeeBrewery::Bundle::Brew).to receive(:install!)
        .with("mysql", preinstall: false, no_upgrade: false, verbose: false, force: false)
        .and_return(true)

      expect { described_class.install!([formula_entry], quiet: false) }.to output(/Using mysql/).to_stdout
    end

    it "batches casks with CoffeeBrewery's native download queue" do
      expect(CoffeeBrewery::Bundle).to receive(:coffee)
        .with("install", "--adopt", "homebrew/cask/google-chrome", verbose: false)
        .and_return(true)
      expect(CoffeeBrewery::Bundle::Cask).to receive(:install!)
        .with("google-chrome", **cask_options, preinstall: false, no_upgrade: false, verbose: false, force: false)
        .and_return(true)

      described_class.install!([cask_entry], quiet: true)
    end

    it "installs a cask sharing a token with a formula as a cask" do
      options = { args: {}, full_name: "ambiguous" }
      entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:cask, "ambiguous", options)
      allow(::Cask::CaskLoader).to receive(:load)
        .with("ambiguous")
        .and_return(instance_double(::Cask::Cask, full_name: "ambiguous", tap: CoreCaskTap.instance))

      expect(CoffeeBrewery::Bundle).to receive(:coffee)
        .with("install", "--adopt", "homebrew/cask/ambiguous", verbose: false)
        .and_return(true)

      described_class.install!([entry], quiet: true)
    end

    it "uses the resolved formula name when batching an alias" do
      allow(Formula).to receive(:[]).with("mysql").and_return(instance_double(Formula, full_name: "mysql@9.7",
                                                                                       tap:       CoreTap.instance,
                                                                                       conflicts: []))

      expect(CoffeeBrewery::Bundle).to receive(:coffee)
        .with("install", "homebrew/core/mysql@9.7", verbose: false)
        .and_return(true)

      described_class.install!([formula_entry], quiet: true)
    end

    it "preserves third-party tap names in a mixed batch" do
      allow(Formula).to receive(:[]).with("mysql")
                                    .and_return(instance_double(Formula, full_name: "thirdparty/tap/mysql",
                                                                         tap:       Tap.fetch("thirdparty/tap"),
                                                                         conflicts: []))
      allow(::Cask::CaskLoader).to receive(:load)
        .and_return(instance_double(::Cask::Cask, full_name: "thirdparty/tap/google-chrome",
                                                  tap:       Tap.fetch("thirdparty/tap")))

      expect(CoffeeBrewery::Bundle).to receive(:coffee)
        .with("install", "--adopt", "thirdparty/tap/mysql", "thirdparty/tap/google-chrome", verbose: false)
        .once.and_return(true)

      described_class.install!([formula_entry, cask_entry], quiet: true)
    end

    [:coffee, :cask].each do |type|
      it "preserves a tapless #{type} name" do
        T.bind(self, RSpec::Core::ExampleGroup)

        entry = CoffeeBrewery::Bundle::Dsl::Entry.new(type, "local")
        if type == :coffee
          allow(Formula).to receive(:[]).with("local")
                                        .and_return(instance_double(Formula, full_name: "local", tap: nil,
                                                                             conflicts: []))
        else
          allow(::Cask::CaskLoader).to receive(:load).with("local")
                                                     .and_return(instance_double(::Cask::Cask, full_name: "local",
                                                                                               tap:       nil))
        end

        expect(CoffeeBrewery::Bundle.installable(type)).to receive(:install!)
          .with("local", preinstall: true, no_upgrade: false, verbose: false, force: false).and_return(true)

        described_class.install!([entry], quiet: true)
      end
    end

    ["thirdparty/tap/collision", "collision"].product([false, true], [false, true]).each do |name, force, success|
      it "installs the colliding #{name} cask with an explicit type (force: #{force}, success: #{success})" do
        T.bind(self, RSpec::Core::ExampleGroup)

        tap = Tap.fetch("thirdparty/tap") if name.include?("/")
        if tap
          allow(tap).to receive(:formula_dir).and_return(mktmpdir)
          (tap.formula_dir/"collision.rb").write("class WrongClass < Formula; end")
        end
        allow(CoffeeBrewery::Bundle::Tap).to receive(:installed_taps).and_return(["thirdparty/tap"])
        allow(::Cask::CaskLoader).to receive(:load).with(name)
                                                   .and_return(instance_double(Cask::Cask, full_name: name, tap:))
        expect(Formulary).not_to receive(:factory)
        allow(CoffeeBrewery::Bundle::Cask).to receive(:install!).and_call_original
        allow(CoffeeBrewery::Bundle::Cask).to receive(:cask_installed?).and_return(false)

        expect(CoffeeBrewery::Bundle).to receive(:coffee)
          .with("install", *(["--force", "--overwrite"] if force), "homebrew/core/mysql", verbose: false)
          .ordered.and_return(true)
        expect(CoffeeBrewery::Bundle).to receive(:coffee)
          .with("install", "--cask", name, force ? "--force" : "--adopt", verbose: false)
          .ordered.and_return(success)

        expect do
          expect(described_class.install!([
            CoffeeBrewery::Bundle::Dsl::Entry.new(:coffee, "mysql"),
            CoffeeBrewery::Bundle::Dsl::Entry.new(:cask, name),
          ], force:, quiet: true)).to be(success)
        end.to output(success ? "" : /Installing #{name} has failed!/).to_stderr
      end
    end

    it "keeps a cask matching a formula alias out of the batch without loading the formula" do
      tap = Tap.fetch("thirdparty/tap")
      allow(tap).to receive_messages(formula_dir: mktmpdir, alias_dir: mktmpdir)
      (tap.formula_dir/"foo.rb").write("class WrongClass < Formula; end")
      (tap.alias_dir/"google-chrome").make_symlink(tap.formula_dir/"foo.rb")
      allow(::Cask::CaskLoader).to receive(:load)
        .and_return(instance_double(Cask::Cask, full_name: "thirdparty/tap/google-chrome", tap:))

      expect(Formulary).not_to receive(:factory)
      expect(CoffeeBrewery::Bundle::Cask).to receive(:install!)
        .with("google-chrome", **cask_options, preinstall: true, no_upgrade: false, verbose: false, force: false)
        .and_return(true)

      described_class.install!([cask_entry], quiet: true)
    end

    it "installs a formula sharing a cask token with an explicit type" do
      tap = Tap.fetch("thirdparty/tap")
      allow(tap).to receive(:cask_dir).and_return(mktmpdir)
      (tap.cask_dir/"collision.rb").write('raise "Do not load this cask"')
      allow(CoffeeBrewery::Bundle::Tap).to receive(:installed_taps).and_return([tap.name])
      allow(Formula).to receive(:[]).with("thirdparty/tap/collision")
                                    .and_return(instance_double(Formula, full_name: "thirdparty/tap/collision", tap:,
                                                                         conflicts: []))
      allow(CoffeeBrewery::Bundle::Brew).to receive(:install!).and_call_original
      allow(CoffeeBrewery::Bundle::Brew).to receive_messages(formula_installed?: false, formulae_by_full_name: nil,
                                                        installed_formulae: [])

      expect(::Cask::CaskLoader).not_to receive(:load)
      expect(CoffeeBrewery::Bundle).to receive(:coffee)
        .with("install", "--formula", "thirdparty/tap/collision", verbose: false).and_return(true)

      expect do
        described_class.install!([CoffeeBrewery::Bundle::Dsl::Entry.new(:coffee, "thirdparty/tap/collision")], quiet: true)
      end.not_to output.to_stderr
    end

    it "forces formulae and casks in one batch" do
      expect(CoffeeBrewery::Bundle).to receive(:coffee)
        .with("install", "--force", "--overwrite", "homebrew/core/mysql",
              "homebrew/cask/google-chrome", verbose: false)
        .once.and_return(true)

      described_class.install!([formula_entry, cask_entry], force: true, quiet: true)
    end

    it "finishes installed casks when a mixed batch fails" do
      allow(CoffeeBrewery::Bundle).to receive(:coffee).with("install", any_args).and_return(false)
      allow(CoffeeBrewery::Bundle::Cask).to receive(:cask_installed_and_up_to_date?).and_return(true)

      expect(CoffeeBrewery::Bundle::Cask).to receive(:install!)
        .with("google-chrome", **cask_options, preinstall: false, no_upgrade: false, verbose: false, force: false)
        .and_return(true)

      described_class.install!([formula_entry, cask_entry], quiet: true)
    end

    it "attributes a failed batch to casks that are not installed afterwards" do
      allow(CoffeeBrewery::Bundle).to receive(:coffee).with("install", any_args).and_return(false)

      expect do
        expect(described_class.install!([cask_entry], quiet: true)).to be(false)
      end.to output(/Installing google-chrome has failed!/).to_stderr
    end

    it "keeps a cask with arguments out of the batch" do
      options = cask_options.merge(args: { appdir: "/Applications" })
      entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:cask, "google-chrome", options)

      expect(CoffeeBrewery::Bundle).not_to receive(:coffee).with("install", any_args)
      expect(CoffeeBrewery::Bundle::Cask).to receive(:install!)
        .with("google-chrome", **options, preinstall: true, no_upgrade: false, verbose: false, force: false)
        .and_return(true)

      described_class.install!([entry], quiet: true)
    end

    it "keeps an unloadable cask out of the batch" do
      allow(::Cask::CaskLoader).to receive(:load).with("homebrew/cask/google-chrome")
                                                 .and_raise(::Cask::CaskUnavailableError, "google-chrome")

      expect(CoffeeBrewery::Bundle).not_to receive(:coffee).with("install", any_args)
      expect(CoffeeBrewery::Bundle::Cask).to receive(:install!)
        .with("google-chrome", **cask_options, preinstall: true, no_upgrade: false, verbose: false, force: false)
        .and_return(true)

      described_class.install!([cask_entry], quiet: true)
    end

    it "preserves upgrades when `COFFEEBREWER_NO_INSTALL_UPGRADE` is set" do
      ENV["COFFEEBREWER_NO_INSTALL_UPGRADE"] = "1"

      expect(CoffeeBrewery::Bundle).to receive(:coffee) do |*args, **options|
        expect(args).to eq(["install", "homebrew/core/mysql"])
        expect(options).to eq(verbose: false)
        expect(ENV.fetch("COFFEEBREWER_NO_INSTALL_UPGRADE", nil)).to be_nil
        true
      end

      described_class.install!([formula_entry], quiet: true)
    end

    it "installs Brewfile taps before batching the formulae" do
      tap_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:tap, "homebrew/foo")
      order = []
      allow(CoffeeBrewery::Bundle::Tap).to receive(:install!) do |name, **_options|
        order << name
        true
      end
      allow(CoffeeBrewery::Bundle).to receive(:coffee) do |*args, **_options|
        order << args.first
        true
      end

      described_class.install!([formula_entry, tap_entry], quiet: true)

      expect(order).to eq(["homebrew/foo", "install"])
    end

    it "resolves `gh` before installing anything when verifying attestations" do
      order = []
      allow(CoffeeBrewery::EnvConfig).to receive(:verify_attestations?).and_return(true)
      allow(CoffeeBrewery::Attestation).to receive(:gh_executable) do
        order << "gh"
        Pathname("/fake/gh")
      end
      allow(CoffeeBrewery::Bundle).to receive(:coffee) do |*args, **_options|
        order << args.first
        true
      end

      described_class.install!([formula_entry], quiet: true)

      expect(order).to include("gh")
      expect(order.index("gh")).to be < order.index("install")
    end
  end

  describe "extension installation errors" do
    let(:failed_entry) { CoffeeBrewery::Bundle::Dsl::Entry.new(:npm, "example-tool") }
    let(:installed_entry) { CoffeeBrewery::Bundle::Dsl::Entry.new(:npm, "installed-tool") }
    let(:actionable_entry) { CoffeeBrewery::Bundle::Dsl::Entry.new(:npm, "other-tool") }
    let(:independent_batch_entry) { CoffeeBrewery::Bundle::Dsl::Entry.new(:cargo, "later-tool") }
    let(:later_entry) { CoffeeBrewery::Bundle::Dsl::Entry.new(:krew, "last-tool") }
    let(:entries) { [failed_entry, independent_batch_entry, later_entry] }
    let(:inventory_error) do
      ErrorDuringExecution.new(["example-tool", "list"], status: 2,
                                                         output: [[:stderr, "inventory unavailable"]])
    end

    before do
      allow(CoffeeBrewery::Bundle::Npm).to receive_messages(installed_packages: [], preinstall!: true, install!: true,
                                                       install_batch!: true, reset!: nil)
      allow(CoffeeBrewery::Bundle::Cargo).to receive_messages(preinstall!: true, install_batch!: true, reset!: nil)
      allow(CoffeeBrewery::Bundle::Krew).to receive_messages(preinstall!: true, install!: true)
    end

    def expect_failure_and_continuation
      expect(CoffeeBrewery::Bundle::Cargo).to receive(:install_batch!).with([independent_batch_entry], verbose: false)
      expect(CoffeeBrewery::Bundle::Krew).to receive(:install!)
        .with("last-tool", preinstall: true, no_upgrade: false, verbose: false, force: false)

      expect do
        expect(described_class.install!(entries, quiet: true)).to be(false)
      end.to output(
        /Failed to install example-tool:.*inventory unavailable.*1 Brewfile dependency failed/m,
      ).to_stderr
    end

    context "when choosing the installation verb fails" do
      it "reports the failure and continues independent entries" do
        allow(CoffeeBrewery::Bundle::Npm).to receive(:installed_packages).and_raise(inventory_error)
        expect(CoffeeBrewery::Bundle::Npm).not_to receive(:install_batch!)

        expect_failure_and_continuation
      end
    end

    context "when native batch preparation fails" do
      before do
        allow(CoffeeBrewery::Bundle::Npm).to receive(:preinstall!)
          .with("example-tool", any_args).and_raise(inventory_error)
        allow(CoffeeBrewery::Bundle::Npm).to receive(:preinstall!).with("installed-tool", any_args).and_return(false)
      end

      context "with no actionable entries" do
        let(:entries) { [installed_entry, failed_entry, independent_batch_entry, later_entry] }

        it "counts the failed entry without installing the batch" do
          expect(CoffeeBrewery::Bundle::Npm).not_to receive(:install_batch!)

          expect_failure_and_continuation
        end
      end

      test_each([true, false]) do |batch_succeeded|
        describe "when the remaining batch succeeds: #{batch_succeeded}" do
          let(:entries) { [installed_entry, failed_entry, actionable_entry, independent_batch_entry, later_entry] }

          it "preserves the preparation failure and installs only actionable entries" do
            expect(CoffeeBrewery::Bundle::Npm).to receive(:install_batch!)
              .with([actionable_entry], verbose: false).and_return(batch_succeeded)

            expect_failure_and_continuation
          end
        end
      end
    end

    test_each([:preinstall!, :install!]) do |method|
      describe "when #{method} fails during a native batch retry" do
        let(:entries) { [failed_entry, actionable_entry, independent_batch_entry, later_entry] }

        it "counts the failed retry and continues other retries and entries" do
          allow(CoffeeBrewery::Bundle::Npm).to receive(:install_batch!) do
            allow(CoffeeBrewery::Bundle::Npm).to receive(method).with("example-tool", any_args).and_raise(inventory_error)
            false
          end
          expect(CoffeeBrewery::Bundle::Npm).to receive(:install!)
            .with("other-tool", preinstall: true, no_upgrade: false, verbose: false, force: false)

          expect_failure_and_continuation
        end
      end

      describe "when #{method} fails for a single entry" do
        let(:failed_entry) { CoffeeBrewery::Bundle::Dsl::Entry.new(:krew, "example-tool") }

        it "reports the failure and continues independent entries" do
          allow(CoffeeBrewery::Bundle::Krew).to receive(method).with("example-tool", any_args).and_raise(inventory_error)

          expect_failure_and_continuation
        end
      end
    end

    test_each([RuntimeError, Errno::EIO]) do |error|
      describe "when inventory raises #{error}" do
        let(:failed_entry) { CoffeeBrewery::Bundle::Dsl::Entry.new(:krew, "example-tool") }

        it "reports the failure and continues independent entries" do
          allow(CoffeeBrewery::Bundle::Krew).to receive(:preinstall!)
            .with("example-tool", any_args).and_raise(error, "inventory unavailable")

          expect_failure_and_continuation
        end
      end
    end

    test_each([Interrupt, SystemExit].product([:install_verb, :preinstall!, :install!])) do |error, method|
      it "propagates #{error} from #{method}" do
        allow(CoffeeBrewery::Bundle::Krew).to receive(method).and_raise(error)

        expect { described_class.install!([later_entry], quiet: true) }.to raise_error(error)
      end
    end
  end

  describe "native extension batches" do
    it "delegates entries to an extension that registers batch support" do
      first_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:npm, "typescript")
      second_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:npm, "prettier")
      allow(CoffeeBrewery::Bundle::Npm).to receive_messages(preinstall!: true, reset!: nil)

      expect(CoffeeBrewery::Bundle::Npm).to receive(:install_batch!)
        .with([first_entry, second_entry], verbose: false)
        .and_return(true)
      expect(CoffeeBrewery::Bundle::Npm).not_to receive(:install!)

      expect(described_class.install!([first_entry, second_entry], quiet: true)).to be(true)
    end

    it "retries only entries left uninstalled by a failed native batch" do
      first_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:npm, "typescript")
      second_entry = CoffeeBrewery::Bundle::Dsl::Entry.new(:npm, "prettier")
      allow(CoffeeBrewery::Bundle::Npm).to receive(:preinstall!).with("typescript", any_args).and_return(true, false)
      allow(CoffeeBrewery::Bundle::Npm).to receive(:preinstall!).with("prettier", any_args).and_return(true, true)
      allow(CoffeeBrewery::Bundle::Npm).to receive(:install_batch!).and_return(false)
      expect(CoffeeBrewery::Bundle::Npm).not_to receive(:install!).with("typescript", any_args)
      expect(CoffeeBrewery::Bundle::Npm).to receive(:install!)
        .with("prettier", preinstall: true, no_upgrade: false, verbose: false, force: false)
        .and_return(false)

      expect do
        expect(described_class.install!([first_entry, second_entry], quiet: true)).to be(false)
      end.to output(/Installing prettier has failed!/).to_stderr
    end
  end
end
