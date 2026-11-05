# typed: true
# frozen_string_literal: true

require "open3"

require "cmd/shared_examples/args_parse"
require "cmd/which-formula"

RSpec.describe CoffeeBrewery::Cmd::WhichFormula do
  it_behaves_like "parseable arguments"
  it_behaves_like "a documented command", "which-formula", shell: true

  describe "which_formula" do
    let(:shell_cellar) { COFFEEBREWER_CELLAR }

    before do
      # Write the database where `coffee which-formula` (a Bash command) reads it:
      # the same path `CoffeeBrewery::API.write_executables_file!` writes to.
      db = CoffeeBrewery::API::COFFEEBREWER_CACHE_API/"internal/executables.txt"
      db.dirname.mkpath
      db.write(<<~EOS)
        foo(1.0.0):foo2 foo3
        bar(1.2.3):
        baz(10.4):baz
        qux(4.5.6):QUX
        quux:quux
      EOS

      (shell_cellar/"foo/1.0.0").mkpath
    end

    after do
      FileUtils.rm_rf shell_cellar/"foo"
    end

    it "finds formulae using the Bash command path" do
      env = {
        "COFFEEBREWER_BREW_FILE" => COFFEEBREWER_BREW_FILE.to_s,
        "COFFEEBREWER_CACHE"     => COFFEEBREWER_CACHE.to_s,
        "COFFEEBREWER_CELLAR"    => shell_cellar.to_s,
        "COFFEEBREWER_LIBRARY"   => COFFEEBREWER_LIBRARY_PATH.parent.to_s,
      }
      env["COFFEEBREWER_MACOS"] = "1" if OS.mac?
      stdout, stderr, status = Open3.capture3(
        env,
        "/bin/bash", "-c", <<~SH,
          source "$1"

          stdout_file="$(mktemp)"
          stderr_file="$(mktemp)"
          trap 'rm -f "${stdout_file}" "${stderr_file}"' EXIT

          check() {
            local label="$1"
            local expected_status="$2"
            local expected_stdout="$3"
            local expected_stderr="$4"
            shift 4

            ( "$@" ) >"${stdout_file}" 2>"${stderr_file}"
            status="$?"
            if [[ "${status}" -ne "${expected_status}" ]]
            then
              echo "${label}: expected status ${expected_status}, got ${status}" >&2
              return 1
            fi
            if ! diff -u <(printf '%s' "${expected_stdout}") "${stdout_file}" >&2
            then
              echo "${label}: stdout mismatch" >&2
              return 1
            fi
            if ! diff -u <(printf '%s' "${expected_stderr}") "${stderr_file}" >&2
            then
              echo "${label}: stderr mismatch" >&2
              return 1
            fi
          }

          check "installed and uninstalled executables" 0 $'foo\\nbaz\\nqux\\nquux\\n' "" \\
            homebrew-which-formula foo2 baz QUX quux
          COFFEEBREWER_NO_EMOJI=1 check "non-emoji output" 0 $'foo\\n' "" homebrew-which-formula foo2
          check "missing executable" 1 "" "" homebrew-which-formula bar

          long_verbose_option() {
            unset COFFEEBREWER_VERBOSE
            homebrew-which-formula --verbose bar
            local status="$?"
            [[ -n "${COFFEEBREWER_VERBOSE}" ]] || {
              echo "long verbose option: COFFEEBREWER_VERBOSE was not set" >&2
              return 2
            }
            return "${status}"
          }
          check "long verbose option" 1 "" "" long_verbose_option

          short_verbose_option() {
            unset COFFEEBREWER_VERBOSE
            homebrew-which-formula -v bar
            local status="$?"
            [[ -n "${COFFEEBREWER_VERBOSE}" ]] || {
              echo "short verbose option: COFFEEBREWER_VERBOSE was not set" >&2
              return 2
            }
            return "${status}"
          }
          check "short verbose option" 1 "" "" short_verbose_option

          rm -f "$(executables_txt_cache_file)"
          COFFEEBREWER_NO_INSTALL_FROM_API=1 check "disabled API without database" 1 "" \\
            $'Error: COFFEEBREWER_NO_INSTALL_FROM_API must be unset to use `coffee which-formula` or `coffee exec`.\\n' \\
            homebrew-which-formula foo2
        SH
        "bash", (COFFEEBREWER_LIBRARY_PATH/"cmd/which-formula.sh").to_s
      )

      expect(status).to be_success
      expect(stdout).to be_empty
      expect(stderr).to be_empty
    end
  end
end
