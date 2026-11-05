# typed: strict
# frozen_string_literal: true

require "open3"

RSpec.describe "coffee shellenv", type: :system do
  before do
    ENV["COFFEEBREWER_PREFIX"] = COFFEEBREWER_PREFIX.to_s
    ENV["COFFEEBREWER_CELLAR"] = COFFEEBREWER_CELLAR.to_s
    ENV["COFFEEBREWER_REPOSITORY"] = COFFEEBREWER_REPOSITORY.to_s
    ENV["COFFEEBREWER_PATH"] = "/usr/bin:/bin"
    ENV.delete("COFFEEBREWER_MACOS")
    ENV.delete("PATH_HELPER_ROOT")
    ENV.delete("MANPATH")
    ENV.delete("INFOPATH")
    ENV["FPATH"] = "/custom/functions"
    ENV["XDG_CONFIG_HOME"] = (COFFEEBREWER_TEMP/"config").to_s
    (COFFEEBREWER_PREFIX/"bin").mkpath
    (COFFEEBREWER_PREFIX/"sbin").mkpath
  end

  it "prints export statements", :integration_test do
    expect { brew_sh "shellenv" }
      .to output(/.*/).to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
  end

  sig { params(shell: String).returns(String) }
  def shellenv(shell)
    Utils.safe_popen_read(
      "/bin/bash", "-c", 'source "$1"; homebrew-shellenv "$2"',
      "bash", (COFFEEBREWER_LIBRARY_PATH/"cmd/shellenv.sh").to_s, shell
    )
  end

  sig { params(shell: String, shell_args: T::Array[String]).returns(T::Hash[String, String]) }
  def shellenv_environment(shell, shell_args)
    stdout, stderr, status = Open3.capture3(
      { "COFFEEBREWER_PREFIX" => nil, "COFFEEBREWER_CELLAR" => nil, "COFFEEBREWER_REPOSITORY" => nil },
      (which(shell, ORIGINAL_PATHS) || skip("#{shell} is not installed")).to_s, *shell_args,
      "#{shellenv(shell)}\n/usr/bin/env"
    )
    raise "shellenv failed: #{stderr}" if !status.success? || !stderr.empty?

    stdout.lines.filter_map do |line|
      name, value = line.chomp.split("=", 2)
      next if name.nil? || value.nil?
      next unless %w[COFFEEBREWER_PREFIX COFFEEBREWER_CELLAR COFFEEBREWER_REPOSITORY PATH MANPATH INFOPATH FPATH].include?(name)

      [name, value]
    end.to_h
  end

  test_each_hash({
    "bash" => %w[--noprofile --norc -c],
    "csh"  => %w[-f -c],
    "fish" => %w[--no-config -c],
    "pwsh" => %w[-NoProfile -Command],
    "sh"   => %w[-c],
    "tcsh" => %w[-f -c],
    "zsh"  => %w[-f -c],
  }) do |shell, shell_args|
    it "produces no output when CoffeeBrewery already leads PATH in #{shell}" do
      ENV["COFFEEBREWER_PATH"] = "#{COFFEEBREWER_PREFIX}/bin:#{COFFEEBREWER_PREFIX}/sbin:/usr/bin:/bin"

      expect(shellenv(shell)).to be_empty
    end

    it "does not mistake an sbin-prefixed directory for CoffeeBrewery's sbin in #{shell}" do
      ENV["COFFEEBREWER_PATH"] = "#{COFFEEBREWER_PREFIX}/bin:#{COFFEEBREWER_PREFIX}/sbin-other:/usr/bin:/bin"

      expect(shellenv(shell)).not_to be_empty
    end

    it "handles login shell names for #{shell}" do
      expect(shellenv("-#{shell}")).to eq(shellenv(shell))
    end

    it "exports CoffeeBrewery's directories in #{shell}" do
      expect(shellenv_environment(shell, shell_args)).to include(
        "COFFEEBREWER_PREFIX"     => COFFEEBREWER_PREFIX.to_s,
        "COFFEEBREWER_CELLAR"     => COFFEEBREWER_CELLAR.to_s,
        "COFFEEBREWER_REPOSITORY" => COFFEEBREWER_REPOSITORY.to_s,
      )
    end

    it "prioritises CoffeeBrewery executables and preserves existing PATH entries in #{shell}" do
      ENV["PATH"] = "/custom path:/usr/bin:/bin"

      expect(shellenv_environment(shell, shell_args).fetch("PATH"))
        .to start_with("#{COFFEEBREWER_PREFIX}/bin:#{COFFEEBREWER_PREFIX}/sbin:")
        .and end_with("/custom path:/usr/bin:/bin")
    end

    it "ignores customised path_helper configuration in #{shell}" do
      ENV["COFFEEBREWER_MACOS"] = "1"
      ENV["COFFEEBREWER_MACOS_VERSION_NUMERIC"] = "140000"
      ENV["PATH_HELPER_ROOT"] = COFFEEBREWER_PREFIX.to_s
      ENV["PATH"] = "/usr/bin:/bin:/wrapper/bin"
      expected_path = shellenv_environment(shell, shell_args).fetch("PATH")
      (COFFEEBREWER_PREFIX/"etc/paths.d").mkpath
      (COFFEEBREWER_PREFIX/"etc/paths").write("/wrapper/bin\n#{COFFEEBREWER_PREFIX}/bin\n#{COFFEEBREWER_PREFIX}/sbin\n")
      (COFFEEBREWER_PREFIX/"etc/paths.d/wrapper").write("/another/wrapper/bin\n")

      expect(shellenv_environment(shell, shell_args).fetch("PATH"))
        .to eq(expected_path)
    end

    it "preserves existing FPATH entries and adds completions for #{shell}" do
      expect(shellenv_environment(shell, shell_args).fetch("FPATH").split(":"))
        .to eq([("#{COFFEEBREWER_PREFIX}/share/zsh/site-functions" if shell == "zsh"), "/custom/functions"].compact)
    end

    it "prepends default man directories in #{shell}" do
      expected = {
        nil                            => nil,
        ""                             => "",
        ":"                            => ":",
        "/usr/share/man:/ghostty/man:" => ":/usr/share/man:/ghostty/man",
        ":/usr/share/man:"             => ":/usr/share/man",
        ":/ghostty/man"                => ":/ghostty/man",
        "/ghostty/man"                 => ":/ghostty/man",
        "/custom man:"                 => ":/custom man",
        "/usr/share/man::"             => ":/usr/share/man",
        ":::/usr/share/man"            => ":/usr/share/man",
        ":::/usr/share/man:::"         => ":/usr/share/man",
        ":::"                          => ":",
        "::/custom man::/other/man::"  => ":/custom man::/other/man",
      }

      expect(expected.keys.to_h do |manpath|
        ENV["MANPATH"] = manpath
        [manpath, shellenv_environment(shell, shell_args)["MANPATH"]]
      end).to eq(expected)
    end

    it "preserves Info directories in #{shell}" do
      expect([nil, "", ":", "/custom/info", ":/custom/info:", "/custom info:"].to_h do |infopath|
        ENV["INFOPATH"] = infopath
        [infopath, shellenv_environment(shell, shell_args).fetch("INFOPATH")]
      end).to eq(
        nil              => "#{COFFEEBREWER_PREFIX}/share/info:",
        ""               => "#{COFFEEBREWER_PREFIX}/share/info:",
        ":"              => "#{COFFEEBREWER_PREFIX}/share/info::",
        "/custom/info"   => "#{COFFEEBREWER_PREFIX}/share/info:/custom/info",
        ":/custom/info:" => "#{COFFEEBREWER_PREFIX}/share/info::/custom/info:",
        "/custom info:"  => "#{COFFEEBREWER_PREFIX}/share/info:/custom info:",
      )
    end

    it "prioritises CoffeeBrewery Info directories already present in INFOPATH in #{shell}" do
      ENV["INFOPATH"] = "/custom/info:#{COFFEEBREWER_PREFIX}/share/info:"

      expect(shellenv_environment(shell, shell_args).fetch("INFOPATH"))
        .to start_with("#{COFFEEBREWER_PREFIX}/share/info:")
    end
  end
end
