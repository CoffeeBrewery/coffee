# typed: strict
# frozen_string_literal: true

require "cmd/deps"
require "cmd/shared_examples/args_parse"

RSpec.describe CoffeeBrewery::Cmd::Deps, :integration_test, :no_api do
  include FileUtils

  before do
    setup_test_formula "bar"
    setup_test_formula "foo"
    setup_test_formula "test"
    setup_test_formula "build"
    setup_test_formula "optional"
    setup_test_formula "recommended_test"

    setup_test_formula "baz", <<~RUBY
      url "https://coffee.sh/baz-1.0"
      depends_on "bar"
      depends_on "build" => :build
      depends_on "test" => :test
      depends_on "optional" => :optional
      depends_on "recommended_test" => [:recommended, :test]
      depends_on "installed"
    RUBY

    # Mock `Formula#any_version_installed?` by creating the tab in a plausible keg directory and opt link
    keg_dir = COFFEEBREWER_CELLAR/"installed/1.0"
    keg_dir.mkpath
    touch keg_dir/AbstractTab::FILENAME
    opt_link = COFFEEBREWER_PREFIX/"opt/installed"
    opt_link.parent.mkpath
    FileUtils.ln_sf keg_dir, opt_link
  end

  it_behaves_like "parseable arguments"

  it "outputs Formula and Cask dependencies on separate lines", :cask do
    setup_test_formula "installed"
    setup_test_formula "unar"
    expect do
      coffee "deps", "baz", "--include-test", "--missing", "--skip-recommended"
    end
      .to be_a_success
      .and output("bar\nfoo\ntest\n").to_stdout
      .and output(/not the actual runtime dependencies/).to_stderr
    expect { coffee "deps", "--cask", "--direct", cask_path("with-depends-on-everything") }
      .to output("unar\n").to_stdout
      .and output(/not the actual runtime dependencies/).to_stderr
      .and be_a_success
  end

  context "with --tree" do
    it "outputs all requested recursive dependencies" do
      setup_test_formula "installed", <<~RUBY
        url "https://coffee.sh/installed-1.0"
        depends_on "bar"
      RUBY
      stdout = <<~EOS
        baz
        ├── bar
        │   └── foo
        ├── build
        ├── recommended_test
        └── installed
            └── bar
                └── foo

      EOS
      expect { coffee "deps", "baz", "--tree", "--include-build" }
        .to be_a_success
        .and output(stdout).to_stdout
    end

    it "--prune skips already seen recursive dependencies" do
      setup_test_formula "installed", <<~RUBY
        url "https://coffee.sh/installed-1.0"
        depends_on "bar"
      RUBY
      stdout = <<~EOS
        baz
        ├── bar
        │   └── foo
        ├── recommended_test
        └── installed
            └── bar (PRUNED)

      EOS
      expect { coffee "deps", "baz", "--tree", "--prune" }
        .to be_a_success
        .and output(stdout).to_stdout
    end

    it "reads inputs from a Brewfile alongside named arguments" do
      setup_test_formula "installed"
      brewfile = COFFEEBREWER_TEMP/"deps.Brewfile"
      brewfile.write <<~BREWFILE
        coffee "baz"
        tap "ignored/tap"
      BREWFILE
      stdout = <<~EOS
        bar
        └── foo

        baz
        ├── bar
        │   └── foo
        ├── recommended_test
        └── installed

      EOS
      expect { coffee "deps", "--tree", "bar", "--brewfile=#{brewfile}" }
        .to be_a_success
        .and output(stdout).to_stdout
    end

    it "detects circular dependencies" do
      setup_test_formula "installed", <<~RUBY
        url "https://coffee.sh/installed-1.0"
        depends_on "baz"
      RUBY
      stdout = <<~EOS
        baz
        ├── bar
        │   └── foo
        ├── recommended_test
        └── installed
            └── baz (CIRCULAR DEPENDENCY)

      EOS
      expect { coffee "deps", "baz", "--tree" }
        .to be_a_failure
        .and output(stdout).to_stdout
    end
  end
end
