# typed: false
# frozen_string_literal: true

require "diagnostic"

RSpec.describe CoffeeBrewery::Diagnostic::Checks do
  subject(:checks) { described_class.new }

  specify "#append_indented_list" do
    expect(checks.append_indented_list([], "foo:\n")).to eq("foo:\n")
    expect(checks.append_indented_list(%w[/a /b], "foo:\n")).to eq("foo:\n  /a\n  /b\n")
  end

  specify "#check_for_installed_developer_tools uses installation instructions" do
    allow(DevelopmentTools).to receive_messages(installed?: false, installation_instructions: "Install build tools.")

    expect(checks.check_for_installed_developer_tools&.to_s).to eq <<~EOS.rstrip
      No developer tools installed.

      Install build tools.
    EOS
  end

  describe "#examine_git_origin" do
    let(:git) { COFFEEBREWER_SHIMS_PATH/"shared/git" }
    let(:repository) { GitRepository.new(mktmpdir) }
    let(:desired_origin) { "https://github.com/CoffeeBrewery/coffee" }

    before { system git, "-C", repository.pathname, "init", "--quiet" }

    it "accepts a GitHub SSH origin" do
      system git, "-C", repository.pathname, "remote", "add", "origin", "git@github.com:CoffeeBrewery/coffee.git"

      expect(checks.examine_git_origin(repository, desired_origin)).to be_nil
    end

    it "suggests renaming the remotes when another remote is the desired origin" do
      system git, "-C", repository.pathname, "remote", "add", "origin", "git@github.com:someone/coffee.git"
      system git, "-C", repository.pathname, "remote", "add", "upstream", "git@github.com:CoffeeBrewery/coffee.git"

      expect(checks.examine_git_origin(repository, desired_origin)&.to_s)
        .to include("remote rename origin fork", "remote rename upstream origin")
    end

    it "doesn't suggest renaming `origin` when only its rewritten URL is the desired origin" do
      system git, "-C", repository.pathname, "config", "url.https://github.com/CoffeeBrewery/.insteadOf", "gh:"
      system git, "-C", repository.pathname, "remote", "add", "origin", "gh:coffee"

      expect(checks.examine_git_origin(repository, desired_origin)&.to_s).not_to include("remote rename")
    end

    it "rejects an origin that only matches the desired origin as a pattern" do
      system git, "-C", repository.pathname, "remote", "add", "origin", "https://githubXcom/CoffeeBrewery/coffee"

      expect(checks.examine_git_origin(repository, desired_origin)).not_to be_nil
    end
  end

  specify "#check_access_directories" do
    skip "User is root so everything is writable." if Process.euid.zero?
    begin
      dirs = [
        COFFEEBREWER_CACHE,
        COFFEEBREWER_CELLAR,
        COFFEEBREWER_REPOSITORY,
        COFFEEBREWER_LOGS,
        COFFEEBREWER_LOCKS,
      ]
      modes = {}
      dirs.each do |dir|
        modes[dir] = dir.stat.mode & 0777
        dir.chmod 0555
        expect(checks.check_access_directories&.to_s).to match(dir.to_s)
      end
    ensure
      modes.each do |dir, mode|
        dir.chmod mode
      end
    end
  end

  specify "#check_user_path_1" do
    bin = COFFEEBREWER_PREFIX/"bin"
    sep = File::PATH_SEPARATOR
    # ensure /usr/bin is before COFFEEBREWER_PREFIX/bin in the PATH
    ENV["PATH"] = "/usr/bin#{sep}#{bin}#{sep}" +
                  ENV["PATH"].gsub(%r{(?:^|#{sep})(?:/usr/bin|#{bin})}, "")

    # ensure there's at least one file with the same name in both /usr/bin/ and
    # COFFEEBREWER_PREFIX/bin/
    (bin/File.basename(Dir["/usr/bin/*"].first)).mkpath

    expect(checks.check_user_path_1&.to_s)
      .to match("/usr/bin occurs before #{COFFEEBREWER_PREFIX}/bin")
  end

  specify "#check_user_path_2" do
    ENV["PATH"] = ENV["PATH"].gsub \
      %r{(?:^|#{File::PATH_SEPARATOR})#{COFFEEBREWER_PREFIX}/bin}o, ""

    expect(checks.check_user_path_1&.to_s).to be_nil
    expect(checks.check_user_path_2&.to_s)
      .to match("CoffeeBrewery's \"bin\" was not found in your PATH.")
  end

  specify "#check_user_path_3" do
    sbin = COFFEEBREWER_PREFIX/"sbin"
    (sbin/"something").mkpath

    homebrew_path =
      "#{COFFEEBREWER_PREFIX}/bin#{File::PATH_SEPARATOR}" +
      ENV["COFFEEBREWER_PATH"].gsub(/(?:^|#{Regexp.escape(File::PATH_SEPARATOR)})#{Regexp.escape(sbin)}/, "")
    stub_const("ORIGINAL_PATHS", PATH.new(homebrew_path).filter_map { |path| Pathname.new(path).expand_path })

    expect(checks.check_user_path_1&.to_s).to be_nil
    expect(checks.check_user_path_2&.to_s).to be_nil
    expect(checks.check_user_path_3&.to_s)
      .to match("CoffeeBrewery's \"sbin\" was not found in your PATH")
  ensure
    FileUtils.rm_rf(sbin)
  end

  specify "#check_for_symlinked_cellar" do
    FileUtils.rm_r(COFFEEBREWER_CELLAR)

    mktmpdir do |path|
      FileUtils.ln_s path, COFFEEBREWER_CELLAR

      expect(checks.check_for_symlinked_cellar&.to_s).to match(path)
    end
  ensure
    COFFEEBREWER_CELLAR.unlink
    COFFEEBREWER_CELLAR.mkpath
  end

  specify "#check_homebrew_repository_git_hooks" do
    mktmpdir do |path|
      stub_const("COFFEEBREWER_REPOSITORY", path)

      hook = path/".git/hooks/post-checkout"
      hook.dirname.mkpath
      hook.write("#!/bin/sh\n")
      gitconfig = path/".gitconfig"
      gitconfig.write("[safe]\n")

      expect(checks.check_homebrew_repository_git_hooks&.to_s).to eq <<~EOS.rstrip
        Git hooks or a repository-local `.gitconfig` were found in your CoffeeBrewery repository.
        CoffeeBrewery does not use these, and they can break CoffeeBrewery operations.

        Paths found:
          #{hook}
          #{gitconfig}

        Remove them with:
          rm -rf "#{path}/.git/hooks" "#{path}/.gitconfig"
      EOS
    end
  end

  specify "#check_homebrew_repository_git_hooks ignores sample hooks" do
    mktmpdir do |path|
      stub_const("COFFEEBREWER_REPOSITORY", path)

      hook = path/".git/hooks/post-checkout.sample"
      hook.dirname.mkpath
      hook.write("#!/bin/sh\n")

      expect(checks.check_homebrew_repository_git_hooks&.to_s).to be_nil
    end
  end

  specify "#check_untrusted_taps" do
    foo_tap = instance_double(Tap, name: "thirdparty/foo")
    bar_tap = instance_double(Tap, name: "thirdparty/bar")
    foo_rack = COFFEEBREWER_CELLAR/"foo-formula"
    bar_rack = COFFEEBREWER_CELLAR/"bar-formula"
    foo_keg = instance_double(Keg, tab: instance_double(Tab, tap: foo_tap))
    bar_keg = instance_double(Keg, tab: instance_double(Tab, tap: bar_tap))
    foo_cask = instance_double(Cask::Cask, token: "foo-cask", tab: instance_double(Cask::Tab, tap: foo_tap))
    bar_cask = instance_double(Cask::Cask, token: "bar-cask", tab: instance_double(Cask::Tab, tap: bar_tap))
    allow(CoffeeBrewery::Trust).to receive(:wholly_untrusted_taps).and_return([foo_tap, bar_tap])
    allow(Formula).to receive(:racks).and_return([foo_rack, bar_rack])
    allow(Keg).to receive(:from_rack).with(foo_rack).and_return(foo_keg)
    allow(Keg).to receive(:from_rack).with(bar_rack).and_return(bar_keg)
    allow(Cask::Caskroom).to receive(:casks).and_return([foo_cask, bar_cask])

    check_untrusted_taps = checks.check_untrusted_taps&.to_s
    expect(check_untrusted_taps).to eq <<~EOS.rstrip
      The following taps are not trusted:
        thirdparty/foo
        thirdparty/bar

      CoffeeBrewery is currently ignoring formulae, casks and commands
      from these taps because tap trust is required.
      Prefer trusting only the specific formulae, casks or commands you need.
      Trust installed formulae from these taps with:
        coffee trust --formula thirdparty/bar/bar-formula
        coffee trust --formula thirdparty/foo/foo-formula
      Trust installed casks from these taps with:
        coffee trust --cask thirdparty/bar/bar-cask
        coffee trust --cask thirdparty/foo/foo-cask
      Trust other specific commands with:
        coffee trust --command <user>/<tap>/<command>
      Whole-tap trust is broader and includes all current and future formulae,
      casks and commands from the listed taps. Trust whole taps with:
        coffee trust thirdparty/foo thirdparty/bar
      Untap them with:
        coffee untap thirdparty/foo thirdparty/bar
      For more information, see:
        #{Formatter.url("https://docs.coffee.sh/Tap-Trust")}
    EOS

    expect(check_untrusted_taps)
      .not_to include(
        "coffee trust --formula <user>/<tap>/<formula>",
        "coffee trust --cask <user>/<tap>/<cask>",
      )
  end

  specify "#check_untrusted_taps requires trust by default" do
    tap = instance_double(Tap, name: "thirdparty/foo")
    allow(CoffeeBrewery::Trust).to receive(:wholly_untrusted_taps).and_return([tap])
    allow(Formula).to receive(:racks).and_return([])
    allow(Cask::Caskroom).to receive(:casks).and_return([])

    with_env(COFFEEBREWER_REQUIRE_TAP_TRUST: nil, COFFEEBREWER_NO_REQUIRE_TAP_TRUST: nil) do
      check_untrusted_taps = checks.check_untrusted_taps&.to_s
      expect(check_untrusted_taps).to eq <<~EOS.rstrip
        The following taps are not trusted:
          thirdparty/foo

        CoffeeBrewery is currently ignoring formulae, casks and commands
        from these taps because tap trust is required.
        Untap them with:
          coffee untap thirdparty/foo
        Trust specific formulae, casks and commands with:
          coffee trust --formula <user>/<tap>/<formula>
          coffee trust --cask <user>/<tap>/<cask>
          coffee trust --command <user>/<tap>/<command>
        Whole-tap trust is broader and includes all current and future formulae,
        casks and commands from the listed taps. Trust whole taps with:
          coffee trust thirdparty/foo
        For more information, see:
          #{Formatter.url("https://docs.coffee.sh/Tap-Trust")}
      EOS
    end
  end

  specify "#check_untrusted_taps skips when tap trust is explicitly disabled" do
    allow(CoffeeBrewery::EnvConfig).to receive(:no_require_tap_trust?).and_return(true)
    expect(CoffeeBrewery::Trust).not_to receive(:wholly_untrusted_taps)

    expect(checks.check_untrusted_taps&.to_s).to be_nil
  end

  specify "#check_tmpdir" do
    ENV["TMPDIR"] = "/i/don/t/exis/t"
    expect(checks.check_tmpdir&.to_s).to match("doesn't exist")
  end

  specify "#check_for_nix_homebrew" do
    stub_const("COFFEEBREWER_REPOSITORY", COFFEEBREWER_PREFIX/"Library/.homebrew-is-managed-by-nix")

    expect(checks.check_for_nix_homebrew&.to_s)
      .to include("Your CoffeeBrewery installation is managed by Nix.",
                  "CoffeeBrewery does not support Nix-managed installations.")
  end

  specify "#check_for_external_cmd_name_conflict" do
    mktmpdir do |path1|
      mktmpdir do |path2|
        [path1, path2].each do |path|
          cmd = "#{path}/coffee-foo"
          FileUtils.touch cmd
          FileUtils.chmod 0755, cmd
        end

        allow(Commands).to receive(:tap_cmd_directories).and_return([path1, path2])

        expect(checks.check_for_external_cmd_name_conflict&.to_s)
          .to match("coffee-foo")
      end
    end
  end

  specify "#check_homebrew_prefix" do
    allow(CoffeeBrewery).to receive(:default_prefix?).and_return(false)
    expect(checks.check_homebrew_prefix&.to_s)
      .to match("Your CoffeeBrewery's prefix is not #{CoffeeBrewery::DEFAULT_PREFIX}")
  end

  specify "#check_homebrew_prefix accepts relocatable prefixes without a finding" do
    allow(CoffeeBrewery).to receive(:default_prefix?).and_return(false)
    allow(BottleSpecification).to receive(:compatible_locations?).and_return(true)

    expect(checks.check_homebrew_prefix).to be_nil
  end

  specify "#check_for_unnecessary_core_tap" do
    ENV.delete("COFFEEBREWER_DEVELOPER")

    expect_any_instance_of(CoreTap).to receive(:installed?).and_return(true)

    expect(checks.check_for_unnecessary_core_tap&.to_s).to match("You have an unnecessary local Core tap")
  end

  specify "#check_for_unnecessary_cask_tap" do
    ENV.delete("COFFEEBREWER_DEVELOPER")

    expect_any_instance_of(CoreCaskTap).to receive(:installed?).and_return(true)

    expect(checks.check_for_unnecessary_cask_tap&.to_s).to match("unnecessary local Cask tap")
  end

  specify "#check_cask_corrupt_dirs" do
    allow(Cask::Caskroom).to receive(:corrupt_cask_dirs).and_return(["google-chrome", "docker-desktop"])

    expect(checks.check_cask_corrupt_dirs&.to_s).to eq <<~EOS.rstrip
      Some directories in the Caskroom do not have valid metadata.
      The following casks cannot be upgraded as-is:
        #{Cask::Caskroom.path}/google-chrome
        #{Cask::Caskroom.path}/docker-desktop

      To fix this, run:
        coffee reinstall --cask --force google-chrome
        coffee reinstall --cask --force docker-desktop
    EOS
  end
end
