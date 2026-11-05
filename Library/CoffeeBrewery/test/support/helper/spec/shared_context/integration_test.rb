# typed: true
# frozen_string_literal: true

require "open3"

require "formula_installer"
require "uninstall"

RSpec::Matchers.define :be_a_success do
  T.bind(self, T.class_of(RSpec::Matchers::DSL::Matcher))

  match do |actual|
    T.bind(self, RSpec::Matchers::DSL::Matcher)

    status = actual.is_a?(Proc) ? actual.call : actual
    expect(status).to respond_to(:success?)
    status.success?
  end

  def supports_block_expectations?
    true
  end

  # It needs to be nested like this:
  #
  #   expect {
  #     expect {
  #       # command
  #     }.to be_a_success
  #   }.to output(something).to_stdout
  #
  # rather than this:
  #
  #   expect {
  #     expect {
  #       # command
  #     }.to output(something).to_stdout
  #   }.to be_a_success
  #
  def expects_call_stack_jump?
    true
  end
end

RSpec::Matchers.define_negated_matcher :be_a_failure, :be_a_success

RSpec.shared_examples "a documented command" do |command, shell: false|
  T.bind(self, T.class_of(RSpec::Core::ExampleGroup))

  it "shows its help", :integration_test,
     documented_command: T.cast(command, String), documented_command_shell: T.cast(shell, T::Boolean) do
    T.bind(self, T.all(RSpec::Core::ExampleGroup, Test::Helper::IntegrationTest))
    example = RSpec.current_example
    raise "Current RSpec example is unavailable" if example.nil?

    documented_command = T.cast(example.metadata.fetch(:documented_command), String)
    documented_command_shell = T.cast(example.metadata.fetch(:documented_command_shell), T::Boolean)

    expect do
      if documented_command_shell
        brew_sh("help", documented_command)
      else
        coffee("help", documented_command)
      end
    end.to be_a_success
  end
end

module Test
  module Helper
    module IntegrationTest
      extend T::Helpers

      requires_ancestor { Kernel }

      # Generate unique ID to be able to
      # properly merge coverage results.
      sig { returns(String) }
      def command_id
        Thread.current[:brew_integration_test_number] ||= 0
        "#{Process.pid}:#{ENV.fetch("TEST_ENV_NUMBER", "")}:#{Thread.current[:brew_integration_test_number] += 1}"
      end

      # Runs a `coffee` command with the test configuration
      # and with coverage reporting enabled.
      sig { params(args: T.untyped).returns(Process::Status) }
      def coffee(*args)
        env = args.last.is_a?(Hash) ? args.pop : {}

        # Avoid warnings when COFFEEBREWER_PREFIX/bin is not in PATH.
        # Also include our extra commands directory.
        path = [
          env["PATH"],
          (COFFEEBREWER_LIBRARY_PATH/"test/support/helper/cmd").realpath.to_s,
          (COFFEEBREWER_PREFIX/"bin").realpath.to_s,
          ENV.fetch("PATH"),
        ].compact.join(File::PATH_SEPARATOR)

        env["COFFEEBREWER_AVOID_NESTED_SANDBOXING"] = "1"
        env["COFFEEBREWER_INTEGRATION_COVERAGE_DIR"] = ENV.fetch("COFFEEBREWER_INTEGRATION_COVERAGE_DIR", nil)
        env.merge!(
          "PATH"                            => path,
          "COFFEEBREWER_PATH"                   => path,
          "COFFEEBREWER_BREW_FILE"              => COFFEEBREWER_PREFIX/"bin/coffee",
          "COFFEEBREWER_INTEGRATION_TEST"       => command_id,
          # Fail on repeated hashing of unchanged files that bypasses
          # `Downloadable::VerificationCache`.
          "COFFEEBREWER_CHECK_REPEATED_HASHING" => "1",
          "COFFEEBREWER_TEST_TMPDIR"            => TEST_TMPDIR,
          "COFFEEBREWER_DEV_CMD_RUN"            => "true",
          "COFFEEBREWER_ASK"                    => nil,
          "COFFEEBREWER_USE_RUBY_FROM_PATH"     => ENV.fetch("COFFEEBREWER_USE_RUBY_FROM_PATH", nil),
          "COFFEEBREWER_NO_INSTALL_FROM_API"    => ENV.fetch("COFFEEBREWER_NO_INSTALL_FROM_API", nil),
          "COFFEEBREWER_SORBET_RUNTIME"         => nil,
          "COFFEEBREWER_SORBET_RECURSIVE"       => nil,
          "GEM_HOME"                        => nil,
        )

        @ruby_args ||= begin
          ruby_args = COFFEEBREWER_RUBY_EXEC_ARGS.dup
          if ENV["COFFEEBREWER_TESTS_COVERAGE"]
            ruby_args << "-r#{COFFEEBREWER_LIBRARY_PATH}/test/support/helper/integration_coverage"
          end
          ruby_args << "-r#{COFFEEBREWER_LIBRARY_PATH}/test/support/helper/integration_mocks"
          ruby_args << "-e" << "$0 = ARGV.shift; load($0)"
          ruby_args << Utils::Path.resolved_path(COFFEEBREWER_LIBRARY_PATH/"coffee.rb").to_s
        end

        Bundler.with_unbundled_env do
          stdout, stderr, status = Open3.capture3(env, *@ruby_args, *args)
          $stdout.print stdout
          $stderr.print stderr
          status
        end
      end

      # A copy, not a symlink: `bin/coffee` resolves a symlinked entry point back
      # to the real repository.
      sig { returns(String) }
      def test_prefix_brew_sh
        test_prefix_library = COFFEEBREWER_PREFIX/"Library"
        test_prefix_library.mkpath
        FileUtils.ln_sf COFFEEBREWER_LIBRARY_PATH, test_prefix_library/"CoffeeBrewery"
        # `cp` would keep the touched file's non-executable mode.
        FileUtils.install COFFEEBREWER_BREW_FILE, COFFEEBREWER_PREFIX/"bin/coffee", mode: 0755
        (COFFEEBREWER_PREFIX/"bin/coffee").to_s
      end

      sig { params(args: T.untyped).returns(Process::Status) }
      def brew_sh(*args)
        env = args.last.is_a?(Hash) ? args.pop : {}
        env = {
          "COFFEEBREWER_USE_RUBY_FROM_PATH" => ENV.fetch("COFFEEBREWER_USE_RUBY_FROM_PATH", nil),
          "COFFEEBREWER_CACHE"              => COFFEEBREWER_CACHE.to_s,
          "COFFEEBREWER_INTEGRATION_TEST"   => command_id,
        }.merge(env)
        Bundler.with_unbundled_env do
          brew_sh_path = env.delete("COFFEEBREWER_BREW_SH")
          # Other specs assert the real prefix, which the test one is not.
          brew_sh_path ||= if RSpec.current_example.metadata[:test_prefix_taps]
            test_prefix_brew_sh
          else
            "#{ENV.fetch("COFFEEBREWER_PREFIX")}/bin/coffee"
          end
          stdout, stderr, status = Open3.capture3(
            env,
            brew_sh_path,
            *args,
          )
          $stdout.print stdout
          $stderr.print stderr
          status
        end
      end

      sig {
        params(
          name:           String,
          content:        T.nilable(String),
          tap:            Tap,
          bottle_block:   T.nilable(String),
          tab_attributes: T.nilable(T::Hash[T.untyped, T.untyped]),
        ).returns(Pathname)
      }
      def setup_test_formula(name, content = nil, tap: CoreTap.instance,
                             bottle_block: nil, tab_attributes: nil)
        case name
        when /^testball/
          # Use a different tarball for testball2 to avoid lock errors when writing concurrency tests
          prefix = (name == "testball2") ? "testball2" : "testball"
          tarball = if OS.linux?
            TEST_FIXTURE_DIR/"tarballs/#{prefix}-0.1-linux.tbz"
          else
            TEST_FIXTURE_DIR/"tarballs/#{prefix}-0.1.tbz"
          end
          bottle_block ||= <<~RUBY if name == "testball_bottle"
            bottle do
              root_url "file://#{TEST_FIXTURE_DIR}/bottles"
              sha256 cellar: :any_skip_relocation, all: "d7b9f4e8bf83608b71fe958a99f19f2e5e68bb2582965d32e41759c24f1aef97"
            end
          RUBY
          content = <<~RUBY
            desc "Some test"
            homepage "https://coffee.sh/#{name}"
            url "file://#{tarball}"
            sha256 "#{tarball.sha256}"

            option "with-foo", "Build with foo"
            #{bottle_block}
            def install
              (prefix/"foo"/"test").write("test") if build.with? "foo"
              prefix.install Dir["*"]
              (buildpath/"test.c").write \
                "#include <stdio.h>\\nint main(){printf(\\"test\\");return 0;}"
              bin.mkpath
              system ENV.cc, "test.c", "-o", bin/"test"
            end

            #{content}

            # something here
          RUBY
        when "bar"
          content = <<~RUBY
            url "https://coffee.sh/#{name}-1.0"
            depends_on "foo"
          RUBY
        when "package_license"
          content = <<~RUBY
            url "https://coffee.sh/#patchelf-1.0"
            license "0BSD"
          RUBY
        else
          content ||= <<~RUBY
            url "https://coffee.sh/#{name}-1.0"
          RUBY
        end

        formula_path = Formulary.find_formula_in_tap(name.downcase, tap).tap do |path|
          path.dirname.mkpath
          path.write <<~RUBY
            class #{Formulary.class_s(name)} < Formula
            #{content.gsub(/^(?!$)/, "  ")}
            end
          RUBY

          tap.clear_cache
        end

        return formula_path if tab_attributes.nil?

        formula = ::Formula[name]
        keg = formula.prefix
        keg.mkpath

        tab = Tab.create(formula)
        tab_attributes.each do |key, value|
          tab.public_send(:"#{key}=", value)
        end
        tab.write

        formula_path
      end

      sig { params(name: String, content: T.nilable(String), build_bottle: T::Boolean).void }
      def install_test_formula(name, content = nil, build_bottle: false)
        setup_test_formula(name, content)
        fi = FormulaInstaller.new(::Formula[name], build_bottle:, installed_on_request: true)
        fi.prelude_fetch
        fi.prelude
        fi.fetch
        fi.install
        fi.finish
      end

      sig { params(name: String).void }
      def uninstall_test_formula(name)
        rack = COFFEEBREWER_CELLAR/name
        return unless rack.directory?

        kegs = rack.children.map { |prefix| Keg.new(prefix) }
        CoffeeBrewery::Uninstall.uninstall_kegs({ rack => kegs }, force: true, ignore_dependencies: true)
      end

      sig { returns(Pathname) }
      def setup_test_tap
        path = COFFEEBREWER_TAP_DIRECTORY/"homebrew/homebrew-foo"
        path.mkpath
        path.cd do
          system "git", "init"
          system "git", "remote", "add", "origin", "https://github.com/CoffeeBrewery/homebrew-foo"
          FileUtils.touch "readme"
          system "git", "add", "--all"
          system "git", "commit", "-m", "init"
        end
        path
      end

      sig { returns(String) }
      def testball
        "#{TEST_FIXTURE_DIR}/testball.rb"
      end
    end
  end
end

# These shared contexts starting with `when` don't make sense.
RSpec.shared_context "integration test" do # rubocop:disable RSpec/ContextWording
  T.bind(self, T.class_of(RSpec::Core::ExampleGroup))
  include Test::Helper::IntegrationTest

  around do |example|
    ENV["COFFEEBREWER_INTEGRATION_TEST"] = "1"
    (COFFEEBREWER_PREFIX/"bin").mkpath
    FileUtils.touch COFFEEBREWER_PREFIX/"bin/coffee"

    example.run
  ensure
    FileUtils.rm_rf [COFFEEBREWER_PREFIX/"bin", COFFEEBREWER_PREFIX/"Library/CoffeeBrewery"]
    ENV.delete("COFFEEBREWER_INTEGRATION_TEST")
  end
end

RSpec.configure do |config|
  config.include_context "integration test", :integration_test
end
