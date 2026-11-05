# typed: true
# frozen_string_literal: true

require "open3"
require "cmd/shared_examples/args_parse"
require "cmd/shared_examples/as_user"
require "cmd/as-coffee-user"

RSpec.describe CoffeeBrewery::Cmd::AsBrewUser do
  let(:as_brew_user_script) { COFFEEBREWER_LIBRARY_PATH/"cmd/as-coffee-user.sh" }
  let(:test_root) { mktmpdir }
  let(:macos_env) do
    {
      "COFFEEBREWER_BREW_FILE" => "coffee",
      "COFFEEBREWER_LIBRARY"   => COFFEEBREWER_LIBRARY_PATH.parent.to_s,
      "COFFEEBREWER_MACOS"     => "1",
    }
  end

  sig { params(script: String, env: T::Hash[String, String]).returns([String, String, Process::Status]) }
  def run_as_brew_user_shell(script, env = {})
    Bundler.with_unbundled_env do
      Open3.capture3(env, "/bin/bash", "-c", script)
    end
  end

  it_behaves_like "parseable arguments"
  it_behaves_like "a documented command", "as-coffee-user", shell: true
  it_behaves_like "switching users without sudo", "as-coffee-user"
  it_behaves_like "switching users without sudo", "as-coffee-user" do
    sig { returns(T::Boolean) }
    let(:macos) { false }
  end

  it "selects the prefix owner instead of the console user" do
    stdout, = run_as_brew_user_shell(
      <<~SH,
        source "#{as_brew_user_script}"
        stat() { [[ "$*" == '-L -f %Su /opt/homebrew' ]] && echo brewer; }
        id() {
          [[ "$1" == -un ]] && { echo operator; return; }
          printf 'brewer:*:503:20::0:0:Brewer:#{test_root}:/bin/zsh\\n'
        }
        sudo() { printf '%s\\n' "$1 $2 $3"; }
        homebrew-as-coffee-user upgrade
      SH
      macos_env.merge("COFFEEBREWER_PREFIX" => "/opt/homebrew"),
    )

    expect(stdout).to eq("-H -u brewer\n")
  end

  it "runs directly as the prefix owner without sudo" do
    brew_file = test_root/"coffee"
    brew_file.write <<~SH
      #!/bin/bash
      printf '%s\\n' "$USER|$HOME|$PWD|$*|$COFFEEBREWER_NO_SUDO|$SUDO_USER|$COFFEEBREWER_SUDO_THROUGH_SUDO_USER"
    SH
    brew_file.chmod(0755)
    expect([["1", "operator", "1"], ["", "", "1"], ["", "", ""]].map do |no_sudo, sudo_user, sudo_setting|
      run_as_brew_user_shell(
        <<~SH,
          source "#{as_brew_user_script}"
          stat() { echo brewer; }
          id() {
            [[ "$1" == -un ]] && { echo brewer; return; }
            printf 'brewer:*:503:20::0:0:Brewer:#{test_root}:/bin/zsh\\n'
          }
          sudo() { echo unexpected-sudo; exit 1; }
          homebrew-as-coffee-user list
        SH
        macos_env.merge("COFFEEBREWER_PREFIX" => "/opt/homebrew", "COFFEEBREWER_NO_SUDO" => no_sudo,
                        "COFFEEBREWER_SUDO_USER" => sudo_user, "COFFEEBREWER_SUDO_THROUGH_SUDO_USER" => sudo_setting,
                        "COFFEEBREWER_BREW_FILE" => brew_file.to_s),
      ).first
    end).to eq([
      "brewer|#{test_root}|#{Dir.pwd}|list|1|operator|1\n",
      "brewer|#{test_root}|#{Dir.pwd}|list||brewer|1\n",
      "brewer|#{test_root}|#{Dir.pwd}|list|||\n",
    ])
  end

  it "rejects a root-owned prefix" do
    _, stderr, = run_as_brew_user_shell(
      <<~SH,
        source "#{as_brew_user_script}"
        stat() { echo root; }
        homebrew-as-coffee-user install wget
      SH
      macos_env.merge("COFFEEBREWER_PREFIX" => "/opt/homebrew"),
    )

    expect(stderr).to include("The CoffeeBrewery prefix owner must not be root.")
  end

  it "preserves the working directory and relative paths after switching users" do
    brew_file = test_root/"coffee"
    brew_file.write "#!/bin/bash\nprintf '%s\\n' \"$PWD\" \"$@\"\n"
    brew_file.chmod(0755)
    stdout, = run_as_brew_user_shell(
      <<~SH,
        source "#{as_brew_user_script}"
        stat() { echo brewer; }
        id() {
          [[ "$1" == -un ]] && { echo operator; return; }
          printf 'brewer:*:503:20::0:0:Brewer:#{test_root}:/bin/zsh\\n'
        }
        sudo() { shift 3; "$@"; }
        homebrew-as-coffee-user bundle --file ./Brewfile
      SH
      macos_env.merge("COFFEEBREWER_PREFIX" => "/opt/homebrew", "COFFEEBREWER_BREW_FILE" => brew_file.to_s),
    )

    expect(stdout).to eq("#{Dir.pwd}\nbundle\n--file\n./Brewfile\n")
  end

  it "selects the prefix owner on Linux" do
    stdout, = run_as_brew_user_shell(
      <<~SH,
        source "#{as_brew_user_script}"
        stat() { [[ "$*" == '-L -c %U /home/linuxbrew/.linuxbrew' ]] && echo brewer; }
        id() { echo operator; }
        getent() { printf 'brewer:x:1001:1001:Brewer:#{test_root}:/bin/bash\\n'; }
        sudo() { printf '%s\\n' "$1 $2 $3"; }
        homebrew-as-coffee-user upgrade
      SH
      macos_env.merge("COFFEEBREWER_MACOS" => "", "COFFEEBREWER_PREFIX" => "/home/linuxbrew/.linuxbrew"),
    )

    expect(stdout).to eq("-H -u brewer\n")
  end

  it "refuses to switch accounts when sudo is disabled" do
    stdout, stderr, = run_as_brew_user_shell(
      <<~SH,
        source "#{as_brew_user_script}"
        stat() { echo brewer; }
        id() {
          [[ "$1" == -un ]] && { echo operator; return; }
          printf 'brewer:*:503:20::0:0:Brewer:#{test_root}:/bin/zsh\\n'
        }
        sudo() { echo unexpected-sudo; }
        homebrew-as-coffee-user upgrade
      SH
      macos_env.merge("COFFEEBREWER_PREFIX" => "/opt/homebrew", "COFFEEBREWER_NO_SUDO" => "1"),
    )

    expect([stdout, stderr]).to eq([
      "",
      "Error: Cannot switch to brewer with sudo disabled. Log in as brewer instead.\n",
    ])
  end
end
