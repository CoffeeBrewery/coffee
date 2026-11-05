# typed: true
# frozen_string_literal: true

require "diagnostic"

RSpec.describe CoffeeBrewery::EnvConfig do
  subject(:env_config) { described_class }

  describe "ENVS" do
    it "sorts alphabetically" do
      expect(CoffeeBrewery::EnvConfig::ENVS.keys).to eql(CoffeeBrewery::EnvConfig::ENVS.keys.sort)
    end
  end

  describe ".env_method_name" do
    it "generates method names" do
      expect(env_config.env_method_name("COFFEEBREWER_FOO", {})).to eql("foo")
    end

    it "generates boolean method names" do
      expect(env_config.env_method_name("COFFEEBREWER_BAR", boolean: true)).to eql("bar?")
    end
  end

  describe ".env_value" do
    it "deprecates variables using ENVS metadata" do
      ENV["COFFEEBREWER_TEST_DEPRECATED"] = "1"

      expect { env_config.env_value(:COFFEEBREWER_TEST_DEPRECATED, odeprecated: true) }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_TEST_DEPRECATED.*deprecated/)
    ensure
      ENV["COFFEEBREWER_TEST_DEPRECATED"] = nil
    end

    it "disables variables using ENVS metadata" do
      ENV["COFFEEBREWER_TEST_DISABLED"] = "1"

      expect { env_config.env_value(:COFFEEBREWER_TEST_DISABLED, odisabled: true) }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_TEST_DISABLED.*disabled/)
    ensure
      ENV["COFFEEBREWER_TEST_DISABLED"] = nil
    end

    it "applies variable deprecations to matching commands" do
      with_env(COFFEEBREWER_TEST_DEPRECATED: "1", COFFEEBREWER_COMMAND: "install") do
        expect { env_config.env_value(:COFFEEBREWER_TEST_DEPRECATED, odeprecated: true, commands: ["install"]) }
          .to raise_error(MethodDeprecatedError, /COFFEEBREWER_TEST_DEPRECATED.*deprecated/)
      end
    end

    it "skips variable deprecations for other commands" do
      with_env(COFFEEBREWER_TEST_DEPRECATED: "1", COFFEEBREWER_COMMAND: "info") do
        expect(env_config.env_value(:COFFEEBREWER_TEST_DEPRECATED, odeprecated: true, commands: ["install"]))
          .to eq("1")
      end
    end

    it "applies variable deprecations to matching subcommands" do
      with_env(COFFEEBREWER_TEST_DEPRECATED: "1", COFFEEBREWER_SUBCOMMAND: "install") do
        expect { env_config.env_value(:COFFEEBREWER_TEST_DEPRECATED, odeprecated: true, subcommands: ["install"]) }
          .to raise_error(MethodDeprecatedError, /COFFEEBREWER_TEST_DEPRECATED.*deprecated/)
      end
    end

    it "skips variable deprecations for other subcommands" do
      with_env(COFFEEBREWER_TEST_DEPRECATED: "1", COFFEEBREWER_SUBCOMMAND: "dump") do
        expect(env_config.env_value(:COFFEEBREWER_TEST_DEPRECATED, odeprecated: true, subcommands: ["install"]))
          .to eq("1")
      end
    end
  end

  describe ".check_deprecated_bash_variables" do
    before do
      ENV.delete("COFFEEBREWER_FORCE_BREW_WRAPPER")
      ENV.delete("COFFEEBREWER_FORCE_BREW_WRAPPER_HELP_MESSAGE")
      ENV.delete("COFFEEBREWER_NO_FORCE_BREW_WRAPPER")
    end

    test_each(%w[
      COFFEEBREWER_FORCE_BREW_WRAPPER
      COFFEEBREWER_FORCE_BREW_WRAPPER_HELP_MESSAGE
      COFFEEBREWER_NO_FORCE_BREW_WRAPPER
    ]) do |variable|
      it "deprecates the obsolete Bash setting #{variable}" do
        ENV[variable] = "1"

        expect { env_config.check_deprecated_bash_variables }
          .to raise_error(MethodDeprecatedError, /#{variable}.*deprecated/)
      end
    end

    it "leaves Ruby settings to their accessors" do
      ENV["COFFEEBREWER_BAT_THEME"] = "GitHub"
      ENV["COFFEEBREWER_PRY"] = "1"
      ENV["COFFEEBREWER_REQUIRE_TAP_TRUST"] = "1"

      expect { env_config.check_deprecated_bash_variables }.not_to raise_error
    end

    it "ignores blank values" do
      ENV["COFFEEBREWER_FORCE_BREW_WRAPPER"] = ""

      expect { env_config.check_deprecated_bash_variables }.not_to raise_error
    end

    it "warns once per variable even when checked or read again" do
      ENV["COFFEEBREWER_FORCE_BREW_WRAPPER"] = "/wrapper/coffee"
      ENV["COFFEEBREWER_NO_FORCE_BREW_WRAPPER"] = "0"
      ENV.delete("COFFEEBREWER_TESTS")
      ENV.delete("COFFEEBREWER_DEVELOPER")
      ENV.delete("GITHUB_ACTIONS")
      CoffeeBrewery.raise_deprecation_exceptions = false
      allow(CoffeeBrewery).to receive(:auditing?).and_return(false)
      stub_const("CoffeeBrewery::EnvConfig::WARNED_DEPRECATED_ENVS", Set.new)

      expect do
        env_config.check_deprecated_bash_variables
        env_config.check_deprecated_bash_variables
        env_config.force_brew_wrapper
        env_config.no_force_brew_wrapper?
      end.to output(
        "Warning: Calling COFFEEBREWER_FORCE_BREW_WRAPPER is deprecated! Use your wrapper directly instead.\n" \
        "Warning: Calling COFFEEBREWER_NO_FORCE_BREW_WRAPPER is deprecated! " \
        "Use an environment without $COFFEEBREWER_NO_FORCE_BREW_WRAPPER instead.\n",
      ).to_stderr
    end
  end

  describe ".allowed_taps" do
    it "deprecates the tap allowlist" do
      ENV["COFFEEBREWER_ALLOWED_TAPS"] = "user/repo"

      expect { env_config.allowed_taps }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_ALLOWED_TAPS.*deprecated/)
    end
  end

  describe ".forbidden_cask_artifacts" do
    it "deprecates the artifact denylist" do
      ENV["COFFEEBREWER_FORBIDDEN_CASK_ARTIFACTS"] = "pkg installer"

      expect { env_config.forbidden_cask_artifacts }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_FORBIDDEN_CASK_ARTIFACTS.*deprecated/)
    end
  end

  describe ".forbid_casks?" do
    it "deprecates refusing all casks" do
      ENV["COFFEEBREWER_FORBID_CASKS"] = "1"

      expect { env_config.forbid_casks? }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_FORBID_CASKS.*deprecated/)
    end
  end

  describe ".force_brew_wrapper" do
    it "deprecates requiring a wrapper" do
      ENV["COFFEEBREWER_FORCE_BREW_WRAPPER"] = "/wrapper/coffee"

      expect { env_config.force_brew_wrapper }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_FORCE_BREW_WRAPPER.*deprecated/)
    end
  end

  describe ".force_brew_wrapper_help_message" do
    it "deprecates custom wrapper help" do
      ENV["COFFEEBREWER_FORCE_BREW_WRAPPER_HELP_MESSAGE"] = "Contact support."

      expect { env_config.force_brew_wrapper_help_message }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_FORCE_BREW_WRAPPER_HELP_MESSAGE.*deprecated/)
    end
  end

  describe ".no_force_brew_wrapper?" do
    it "deprecates the wrapper opt-out" do
      ENV["COFFEEBREWER_NO_FORCE_BREW_WRAPPER"] = "1"

      expect { env_config.no_force_brew_wrapper? }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_NO_FORCE_BREW_WRAPPER.*deprecated/)
    end
  end

  describe ".arch" do
    it "deprecates overriding the compiler architecture" do
      ENV["COFFEEBREWER_ARCH"] = "haswell"

      expect { env_config.arch }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_ARCH.*deprecated.*native/)
    end

    it "preserves the default native architecture" do
      ENV.delete("COFFEEBREWER_ARCH")

      expect(env_config.arch).to eq("native")
    end

    it "preserves an explicit architecture during deprecation" do
      ENV["COFFEEBREWER_ARCH"] = "haswell"
      allow(env_config).to receive(:odeprecated)

      expect(env_config.arch).to eq("haswell")
    end
  end

  describe ".non_default_variable?" do
    it "detects whether a variable has a non-default value" do
      ENV["COFFEEBREWER_CURL_RETRIES"] = "4"
      ENV["COFFEEBREWER_BAT"] = "false"

      expect([
        env_config.non_default_variable?(:COFFEEBREWER_CURL_RETRIES),
        env_config.non_default_variable?(:COFFEEBREWER_BAT),
      ]).to eq([true, false])
    end

    it "compares values with callable defaults" do
      ENV["COFFEEBREWER_MAKE_JOBS"] = "8"
      allow(Hardware::CPU).to receive(:cores).and_return(8)

      expect(env_config.non_default_variable?(:COFFEEBREWER_MAKE_JOBS)).to be(false)
    end

    it "treats blank boolean values as default like their accessors" do
      ENV["COFFEEBREWER_SBOM"] = ""

      expect(env_config.non_default_variable?(:COFFEEBREWER_SBOM)).to be(false)
    end

    it "treats values matching computed defaults as default" do
      ENV["COFFEEBREWER_PIP_INDEX_URL"] = "https://pypi.org/simple"
      ENV["COFFEEBREWER_SSH_CONFIG_PATH"] = "#{Dir.home}/.ssh/config"
      ENV["COFFEEBREWER_AUTO_UPDATE_SECS"] = "300"
      ENV["COFFEEBREWER_NO_INSTALL_FROM_API"] = "1"
      ENV.delete("COFFEEBREWER_AUTO_UPDATE_TAP")
      ENV.delete("COFFEEBREWER_DEV_CMD_RUN")

      expect([
        env_config.non_default_variable?(:COFFEEBREWER_PIP_INDEX_URL),
        env_config.non_default_variable?(:COFFEEBREWER_SSH_CONFIG_PATH),
        env_config.non_default_variable?(:COFFEEBREWER_AUTO_UPDATE_SECS),
      ]).to eq([false, false, false])
    end

    it "compares boolean defaults computed at runtime" do
      ENV["COFFEEBREWER_FORBID_PACKAGES_FROM_PATHS"] = "1"
      ENV.delete("COFFEEBREWER_TESTS")
      ENV.delete("COFFEEBREWER_DEVELOPER")

      expect(env_config.non_default_variable?(:COFFEEBREWER_FORBID_PACKAGES_FROM_PATHS)).to be(false)
    end
  end

  describe ".user_set_variable?" do
    it "only counts COFFEEBREWER_* variables recorded by bin/coffee as user-set" do
      ENV["COFFEEBREWER_USER_SET_VARS"] = "COFFEEBREWER_CURL_RETRIES COFFEEBREWER_BAT"
      ENV["COFFEEBREWER_CURL_RETRIES"] = "4"
      ENV["COFFEEBREWER_EDITOR"] = "vim"
      ENV["SUDO_ASKPASS"] = "/usr/bin/ssh-askpass"
      ENV.delete("COFFEEBREWER_BAT")

      expect([
        env_config.user_set_variable?(:COFFEEBREWER_CURL_RETRIES),
        env_config.user_set_variable?(:COFFEEBREWER_EDITOR),
        env_config.user_set_variable?(:SUDO_ASKPASS),
        env_config.user_set_variable?(:COFFEEBREWER_BAT),
      ]).to eq([true, false, true, false])
    end
  end

  describe ".default_description" do
    it "prefers human default text over literal defaults" do
      expect([
        env_config.default_description(:COFFEEBREWER_MAKE_JOBS),
        env_config.default_description(:COFFEEBREWER_API_AUTO_UPDATE_SECS),
        env_config.default_description(:COFFEEBREWER_BAT),
        env_config.default_description(:COFFEEBREWER_REMOVED_VARIABLE),
      ]).to eq(["The number of available CPU cores.", "`450`.", nil, nil])
    end
  end

  describe "ANALYTICS_VARIABLES" do
    it "excludes variables that prevent analytics" do
      expect(CoffeeBrewery::EnvConfig::ANALYTICS_VARIABLES).to eq(
        CoffeeBrewery::EnvConfig::ENVS.keys - [:COFFEEBREWER_NO_ANALYTICS],
      )
    end
  end

  describe ".non_default_variables" do
    it "returns names of user-set variables with non-default values" do
      CoffeeBrewery::EnvConfig::ENVS.each_key { |env| ENV.delete(env.to_s) }
      ENV["COFFEEBREWER_USER_SET_VARS"] = "COFFEEBREWER_CURL_RETRIES COFFEEBREWER_GITHUB_API_TOKEN " \
                                      "COFFEEBREWER_NO_AUTO_UPDATE COFFEEBREWER_BAT COFFEEBREWER_REQUIRE_TAP_TRUST"
      ENV["COFFEEBREWER_CURL_RETRIES"] = "4"
      ENV["COFFEEBREWER_GITHUB_API_TOKEN"] = "secret"
      ENV["COFFEEBREWER_NO_AUTO_UPDATE"] = "1"
      ENV["COFFEEBREWER_BAT"] = "false"
      ENV["COFFEEBREWER_REQUIRE_TAP_TRUST"] = "1"
      ENV["COFFEEBREWER_EDITOR"] = "vim"

      expect(env_config.non_default_variables).to eq(
        %w[COFFEEBREWER_CURL_RETRIES COFFEEBREWER_GITHUB_API_TOKEN COFFEEBREWER_NO_AUTO_UPDATE],
      )
    end
  end

  describe ".artifact_domain" do
    it "returns value if set" do
      ENV["COFFEEBREWER_ARTIFACT_DOMAIN"] = "https://coffee.sh"
      expect(env_config.artifact_domain).to eql("https://coffee.sh")
    end

    it "returns nil if empty" do
      ENV["COFFEEBREWER_ARTIFACT_DOMAIN"] = ""
      expect(env_config.artifact_domain).to be_nil
    end
  end

  describe ".bottle_domain_custom?" do
    it "returns true for a custom bottle domain" do
      ENV["COFFEEBREWER_BOTTLE_DOMAIN"] = "https://mirror.example.com"

      expect(env_config.bottle_domain_custom?).to be(true)
    end

    it "returns false for the default bottle domain" do
      ENV["COFFEEBREWER_BOTTLE_DOMAIN"] = COFFEEBREWER_BOTTLE_DEFAULT_DOMAIN

      expect(env_config.bottle_domain_custom?).to be(false)
    end
  end

  describe ".cleanup_periodic_full_days" do
    it "returns value if set" do
      ENV["COFFEEBREWER_CLEANUP_PERIODIC_FULL_DAYS"] = "360"
      expect(env_config.cleanup_periodic_full_days).to eql("360")
    end

    it "returns default if unset" do
      ENV["COFFEEBREWER_CLEANUP_PERIODIC_FULL_DAYS"] = nil
      expect(env_config.cleanup_periodic_full_days).to eql("30")
    end
  end

  describe ".bat?" do
    it "returns true if set" do
      ENV["COFFEEBREWER_BAT"] = "1"
      expect(env_config.bat?).to be(true)
    end

    it "returns false if unset" do
      ENV["COFFEEBREWER_BAT"] = nil
      expect(env_config.bat?).to be(false)
    end

    it "returns false if set to a falsey value" do
      ENV["COFFEEBREWER_BAT"] = "0"
      expect(env_config.bat?).to be(false)
    end
  end

  describe ".ask?" do
    before do
      ENV["COFFEEBREWER_ASK"] = nil
      ENV["COFFEEBREWER_NO_ASK"] = nil
    end

    it "returns true by default" do
      expect(env_config.ask?).to be(true)
    end

    it "returns false if COFFEEBREWER_NO_ASK is set" do
      ENV["COFFEEBREWER_NO_ASK"] = "1"
      expect(env_config.ask?).to be(false)
    end

    it "disables COFFEEBREWER_ASK" do
      ENV["COFFEEBREWER_ASK"] = "1"
      expect { env_config.ask? }.to raise_error(MethodDeprecatedError, /COFFEEBREWER_ASK.*disabled/)
    end
  end

  describe ".color?" do
    before do
      ENV["COFFEEBREWER_COLOR"] = nil
      ENV["COFFEEBREWER_NO_COLOR"] = nil
    end

    it "returns false if COFFEEBREWER_NO_COLOR is set" do
      ENV["COFFEEBREWER_COLOR"] = "1"
      ENV["COFFEEBREWER_NO_COLOR"] = "1"
      expect(env_config.color?).to be(false)
    end
  end

  describe ".make_jobs" do
    it "returns value if positive" do
      ENV["COFFEEBREWER_MAKE_JOBS"] = "4"
      expect(env_config.make_jobs).to eql("4")
    end

    it "returns default if negative" do
      ENV["COFFEEBREWER_MAKE_JOBS"] = "-1"
      expect(Hardware::CPU).to receive(:cores).and_return(16)
      expect(env_config.make_jobs).to eql("16")
    end
  end

  describe ".bundle_describe?" do
    it "returns true if unset" do
      with_env(COFFEEBREWER_BUNDLE_DESCRIBE: nil, COFFEEBREWER_BUNDLE_NO_DESCRIBE: nil) do
        expect(env_config.bundle_describe?).to be(true)
      end
    end

    it "returns false if COFFEEBREWER_BUNDLE_NO_DESCRIBE is set" do
      with_env(COFFEEBREWER_BUNDLE_DESCRIBE: "1", COFFEEBREWER_BUNDLE_NO_DESCRIBE: "1") do
        expect(env_config.bundle_describe?).to be(false)
      end
    end

    it "disables COFFEEBREWER_BUNDLE_DESCRIBE" do
      with_env(COFFEEBREWER_BUNDLE_DESCRIBE: "1") do
        expect { env_config.bundle_describe? }
          .to raise_error(MethodDeprecatedError, /COFFEEBREWER_BUNDLE_DESCRIBE.*disabled/)
      end
    end
  end

  describe ".bundle_no_secrets?" do
    it "returns true if unset" do
      with_env(COFFEEBREWER_BUNDLE_NO_SECRETS: nil, COFFEEBREWER_BUNDLE_SECRETS: nil) do
        expect(env_config.bundle_no_secrets?).to be(true)
      end
    end

    it "returns false if COFFEEBREWER_BUNDLE_SECRETS is set" do
      with_env(COFFEEBREWER_BUNDLE_NO_SECRETS: "1", COFFEEBREWER_BUNDLE_SECRETS: "1") do
        expect(env_config.bundle_no_secrets?).to be(false)
      end
    end

    it "disables COFFEEBREWER_BUNDLE_NO_SECRETS" do
      with_env(COFFEEBREWER_BUNDLE_NO_SECRETS: "1", COFFEEBREWER_BUNDLE_SECRETS: nil) do
        expect { env_config.bundle_no_secrets? }
          .to raise_error(MethodDeprecatedError, /COFFEEBREWER_BUNDLE_NO_SECRETS.*disabled/)
      end
    end
  end

  describe ".use_internal_api?" do
    it "disables COFFEEBREWER_USE_INTERNAL_API" do
      with_env(COFFEEBREWER_USE_INTERNAL_API: "1") do
        expect { env_config.use_internal_api? }
          .to raise_error(MethodDeprecatedError, /COFFEEBREWER_USE_INTERNAL_API.*disabled/)
      end
    end
  end

  describe ".forbid_packages_from_paths?" do
    around do |example|
      with_env(COFFEEBREWER_TESTS: ENV.fetch("COFFEEBREWER_TESTS", nil)) { example.run }
    end

    before do
      ENV["COFFEEBREWER_FORBID_PACKAGES_FROM_PATHS"] = nil
      ENV["COFFEEBREWER_DEVELOPER"] = nil
      ENV["COFFEEBREWER_TESTS"] = nil
    end

    it "returns true if COFFEEBREWER_FORBID_PACKAGES_FROM_PATHS is set" do
      ENV["COFFEEBREWER_FORBID_PACKAGES_FROM_PATHS"] = "1"
      expect(env_config.forbid_packages_from_paths?).to be(true)
    end

    it "returns true if COFFEEBREWER_DEVELOPER is not set" do
      ENV["COFFEEBREWER_DEVELOPER"] = nil
      expect(env_config.forbid_packages_from_paths?).to be(true)
    end

    it "returns false if COFFEEBREWER_DEVELOPER is set and COFFEEBREWER_FORBID_PACKAGES_FROM_PATHS is not set" do
      ENV["COFFEEBREWER_DEVELOPER"] = "1"
      ENV["COFFEEBREWER_FORBID_PACKAGES_FROM_PATHS"] = nil
      expect(env_config.forbid_packages_from_paths?).to be(false)
    end

    it "returns true if both COFFEEBREWER_DEVELOPER and COFFEEBREWER_FORBID_PACKAGES_FROM_PATHS are set" do
      ENV["COFFEEBREWER_DEVELOPER"] = "1"
      ENV["COFFEEBREWER_FORBID_PACKAGES_FROM_PATHS"] = "1"
      expect(env_config.forbid_packages_from_paths?).to be(true)
    end
  end

  describe ".upgrade_auto_updates_casks?" do
    around do |example|
      with_env(
        COFFEEBREWER_DEVELOPER:                     nil,
        COFFEEBREWER_UPGRADE_AUTO_UPDATES_CASKS:    nil,
        COFFEEBREWER_NO_UPGRADE_AUTO_UPDATES_CASKS: nil,
      ) { example.run }
    end

    it "returns true by default" do
      ENV["COFFEEBREWER_DEVELOPER"] = "1"
      expect(env_config.upgrade_auto_updates_casks?).to be(true)
    end

    it "returns true if set to a falsey value" do
      ENV["COFFEEBREWER_UPGRADE_AUTO_UPDATES_CASKS"] = "0"
      expect(env_config.upgrade_auto_updates_casks?).to be(true)
    end

    it "returns false if COFFEEBREWER_NO_UPGRADE_AUTO_UPDATES_CASKS is set" do
      ENV["COFFEEBREWER_UPGRADE_AUTO_UPDATES_CASKS"] = "1"
      ENV["COFFEEBREWER_NO_UPGRADE_AUTO_UPDATES_CASKS"] = "1"
      expect(env_config.upgrade_auto_updates_casks?).to be(false)
    end
  end

  describe ".sandbox_linux?" do
    around do |example|
      with_env(
        COFFEEBREWER_DEVELOPER:        nil,
        COFFEEBREWER_NO_SANDBOX_LINUX: nil,
        COFFEEBREWER_SANDBOX_LINUX:    nil,
      ) { example.run }
    end

    it "returns true by default" do
      expect(env_config.sandbox_linux?).to be(true)
    end

    it "returns true for developers" do
      ENV["COFFEEBREWER_DEVELOPER"] = "1"
      expect(env_config.sandbox_linux?).to be(true)
    end

    it "disables COFFEEBREWER_SANDBOX_LINUX" do
      ENV["COFFEEBREWER_SANDBOX_LINUX"] = "1"
      expect { env_config.sandbox_linux? }.to raise_error(MethodDeprecatedError, /COFFEEBREWER_SANDBOX_LINUX.*disabled/)
    end

    it "deprecates COFFEEBREWER_NO_SANDBOX_LINUX" do
      ENV["COFFEEBREWER_NO_SANDBOX_LINUX"] = "1"
      expect { env_config.sandbox_linux? }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_NO_SANDBOX_LINUX.*deprecated.*Landlock-enabled Linux kernel/)
    end
  end

  describe ".sbom?" do
    around do |example|
      with_env(COFFEEBREWER_SBOM: nil) { example.run }
    end

    it "returns true by default" do
      expect(env_config.sbom?).to be(true)
    end

    it "returns true if set to a falsey value" do
      ENV["COFFEEBREWER_SBOM"] = "0"
      expect(env_config.sbom?).to be(true)
    end

    it "is hidden" do
      expect(env_config.hidden?(CoffeeBrewery::EnvConfig::ENVS.fetch(:COFFEEBREWER_SBOM))).to be(true)
    end
  end

  describe ".no_sandbox_cask?" do
    it "disables COFFEEBREWER_NO_SANDBOX_CASK" do
      ENV["COFFEEBREWER_NO_SANDBOX_CASK"] = "1"
      expect { env_config.no_sandbox_cask? }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_NO_SANDBOX_CASK.*disabled/)
    ensure
      ENV["COFFEEBREWER_NO_SANDBOX_CASK"] = nil
    end
  end

  describe ".require_tap_trust?" do
    around do |example|
      with_env(
        COFFEEBREWER_REQUIRE_TAP_TRUST:    nil,
        COFFEEBREWER_NO_REQUIRE_TAP_TRUST: nil,
      ) { example.run }
    end

    it "returns true by default" do
      expect(env_config.require_tap_trust?).to be(true)
    end

    it "deprecates COFFEEBREWER_REQUIRE_TAP_TRUST" do
      ENV["COFFEEBREWER_REQUIRE_TAP_TRUST"] = "1"
      expect { env_config.require_tap_trust? }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_REQUIRE_TAP_TRUST.*deprecated.*default behaviour/)
    end

    it "deprecates COFFEEBREWER_NO_REQUIRE_TAP_TRUST" do
      ENV["COFFEEBREWER_NO_REQUIRE_TAP_TRUST"] = "1"
      expect { env_config.require_tap_trust? }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_NO_REQUIRE_TAP_TRUST.*deprecated.*`coffee trust`/)
    end
  end

  describe ".bundle_install_cleanup?" do
    it "deprecates COFFEEBREWER_BUNDLE_INSTALL_CLEANUP" do
      ENV["COFFEEBREWER_BUNDLE_INSTALL_CLEANUP"] = "1"
      expect { env_config.bundle_install_cleanup? }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_BUNDLE_INSTALL_CLEANUP.*deprecated.*`coffee bundle cleanup`/)
    ensure
      ENV["COFFEEBREWER_BUNDLE_INSTALL_CLEANUP"] = nil
    end
  end

  describe ".bundle_force_install_cleanup?" do
    it "deprecates COFFEEBREWER_BUNDLE_FORCE_INSTALL_CLEANUP" do
      ENV["COFFEEBREWER_BUNDLE_FORCE_INSTALL_CLEANUP"] = "1"
      expect { env_config.bundle_force_install_cleanup? }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_BUNDLE_FORCE_INSTALL_CLEANUP.*deprecated.*cleanup --force/)
    ensure
      ENV["COFFEEBREWER_BUNDLE_FORCE_INSTALL_CLEANUP"] = nil
    end
  end

  describe ".verify_attestations?" do
    around do |example|
      with_env(
        COFFEEBREWER_VERIFY_ATTESTATIONS:    nil,
        COFFEEBREWER_NO_VERIFY_ATTESTATIONS: nil,
      ) { example.run }
    end

    it "returns false if COFFEEBREWER_NO_VERIFY_ATTESTATIONS is set" do
      ENV["COFFEEBREWER_VERIFY_ATTESTATIONS"] = "1"
      ENV["COFFEEBREWER_NO_VERIFY_ATTESTATIONS"] = "1"
      expect(env_config.verify_attestations?).to be(false)
    end
  end

  describe ".eval_all?" do
    it "disables COFFEEBREWER_EVAL_ALL" do
      ENV["COFFEEBREWER_EVAL_ALL"] = "1"
      expect { env_config.eval_all? }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_EVAL_ALL.*disabled.*default trusted-tap behaviour/)
    ensure
      ENV["COFFEEBREWER_EVAL_ALL"] = nil
    end
  end

  describe ".no_eval_env_scrubbing?" do
    it "disables COFFEEBREWER_NO_EVAL_ENV_SCRUBBING" do
      ENV["COFFEEBREWER_NO_EVAL_ENV_SCRUBBING"] = "1"
      expect { env_config.no_eval_env_scrubbing? }
        .to raise_error(MethodDeprecatedError, /COFFEEBREWER_NO_EVAL_ENV_SCRUBBING.*disabled/)
    ensure
      ENV["COFFEEBREWER_NO_EVAL_ENV_SCRUBBING"] = nil
    end
  end
end
