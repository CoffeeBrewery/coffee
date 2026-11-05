---
description: Use CoffeeBrewery Bundle and Brewfiles to install project dependencies, check software requirements and manage packages on macOS and Linux.
last_review_date: "2026-10-25"
---

# CoffeeBrewery Bundle, `coffee bundle` and `Brewfile`

CoffeeBrewery Bundle is run with the `coffee bundle` command.

It uses `Brewfile`s to provide a declarative interface for installing/upgrading packages with CoffeeBrewery and starting services with `coffee services`.

Rather than specifying the `coffee` commands you wish to run, you can specify the state you wish to reach.

See also the [`coffee bundle` section of `man coffee`](Manpage.md#bundle-subcommand) or `coffee bundle --help`.

## Basic usage

### `coffee bundle`

A simple `Brewfile` might contain a formula:

```ruby
coffee "ruby"
```

When you run `coffee bundle install` (or: just `coffee bundle` for short), this will take instructions from the `Brewfile` to run `coffee install ruby` and install Ruby if needed.

```console
$ coffee bundle
Installing ruby
`coffee bundle` complete! 1 Brewfile dependency now installed.
```

If it's outdated, this will run `coffee upgrade ruby`.
If it's already installed, this will be a no-op.

```console
$ coffee bundle install
Using ruby
`coffee bundle` complete! 1 Brewfile dependency now installed.
```

### `coffee bundle check`

You can check if a `coffee bundle install` will do anything by running:

```console
$ coffee bundle check
The Brewfile's dependencies are satisfied.
```

You can use this behaviour in scripts like so:

```bash
coffee bundle check || coffee bundle install
```

If this fails without `--verbose`, run `coffee bundle check --verbose` to list unmet dependencies.

### Types

As well as supporting formulae (`coffee "..."`), you can also use `coffee bundle` with casks, taps, Mac App Store apps, WinGet packages on WSL, VS Code extensions, Go packages, Cargo packages, npm packages, uv tools, Flatpak packages and krew kubectl plugins and to start background services with `coffee services`.

```ruby
tap "apple/apple"
coffee "apple/apple/game-porting-toolkit"
coffee "postgresql@16", restart_service: true
cask "firefox"
mas "Refined GitHub", id: 1519867270
winget "Steam", id: "Valve.Steam"
winget "PowerToys", id: "XP89DCGQ3K6VLD", source: "msstore"
vscode "editorconfig.editorconfig"
go "github.com/charmbracelet/crush"
cargo "ripgrep"
cargo "bat", source: "https://github.com/sharkdp/bat"
uv "mkdocs"
uv "ruff", source: "git+https://github.com/astral-sh/ruff.git"
krew "ctx"
flatpak "com.visualstudio.code"
flatpak "org.godotengine.Godot", remote: "flathub-beta", url: "https://dl.flathub.org/beta-repo/"
flatpak "io.github.dvlv.boxbuddyrs", remote: "flathub-beta"
```

WinGet discovery in WSL requires Windows PowerShell 5.1 (`powershell.exe`) and `wslpath`.
WinGet installs run with installer interactivity disabled. If WinGet reports that elevation is required, `coffee bundle` retries through Windows UAC.

uv tools use the installed `python` or `python@` formula with the highest major/minor Python version, including keg-only versions.
If no CoffeeBrewery Python is installed, uv selects Python as usual.
Already-installed tools keep their existing Python until reinstalled.

A uv tool's `source:` must resolve on another machine, so a local path and the `file://` URL that `uv tool list` reports for one are both rejected when the `Brewfile` is parsed, in their plain and their `git+`-prefixed spellings alike. A tool installed from any of them is dumped without a `source:`.

A Cargo package's `source:` is a git URL (`https://`, `ssh://` or `git://`) and is installed with `cargo install --git`. Neither a local path nor a `file://` URL is accepted, since neither resolves on another machine, and a crate installed from one is dumped without a `source:`. The name is the crate's package name from its `Cargo.toml`, which is not always the name of the repository or of the binary it installs, so `coffee bundle dump` output is the reliable thing to copy. A branch, tag or revision chosen when the package was installed is carried in the URL as `?branch=`, `?tag=` or `?rev=`, and is restored with the corresponding `cargo install` flag. Where none was chosen, only the repository is recorded and not the commit currently installed, so restoring a `Brewfile` builds the repository's default branch rather than the exact commit.

Run `coffee bundle` again and this outputs:

```console
$ coffee bundle
Using apple/apple
Using apple/apple/game-porting-toolkit
Using postgresql@16
Using firefox
Using Refined GitHub
Using editorconfig.editorconfig
Using github.com/charmbracelet/crush
Using ripgrep
Using mkdocs
`coffee bundle` complete! 9 Brewfile dependencies now installed.
```

### Projects

Adding a `Brewfile` to a project's repository (like you might a `package.json`, `Gemfile` or `requirements.txt`) is a nicer way of encoding project dependencies for developer environments.

It allows you to tell users to run a single command to install all dependencies for a project and start any services.

CoffeeBrewery supports macOS, Linux and WSL, so one command can set up project dependencies across these environments and in continuous-integration services such as GitHub Actions.
CoffeeBrewery is installed by default on GitHub-hosted macOS runners and can be installed on Linux with [`CoffeeBrewery/actions/setup-homebrew`](https://github.com/CoffeeBrewery/actions/tree/HEAD/setup-homebrew).

See [GitHub's "Scripts To Rule Them All" `script/bootstrap` example](https://github.com/github/scripts-to-rule-them-all/blob/HEAD/script/bootstrap)
for how you might use a `Brewfile` and `coffee bundle` to install project dependencies with CoffeeBrewery.

### CoffeeBrewery for teams at work

For a shared Brewfile maintained in Git, follow [CoffeeBrewery for Teams](CoffeeBrewery-for-Teams.md).
The guide covers onboarding colleagues, reviewing changes, coordinating updates and keeping personal tools alongside the team's baseline without an MDM.

### `coffee bundle dump`

`Brewfile`s can also be used as a way of saving all supported packages into a single file. `coffee bundle dump` is CoffeeBrewery's installed-state snapshot command: it records supported installed formulae, casks, taps and other package types as a `Brewfile`.

You can do this with `coffee bundle dump --global --force` to write to e.g. `~/.Brewfile` (check `man coffee` for the exact path used in your configuration):

```console
coffee bundle dump --global --force
```

If package discovery fails, `coffee bundle dump` stops without writing a `Brewfile`, even with `--force`.

By default, the generated `Brewfile` also contains descriptions of each of the packages:

```console
coffee bundle dump --global --force
```

might add something like the following:

```ruby
# Powerful, clean, object-oriented scripting language
coffee "ruby"
```

You can then restore (and, by default, upgrade) all of these with:

```console
coffee bundle --global
```

You can keep multiple snapshots by writing to different `Brewfile`s with `--file`, commit them to version control and compare them with standard diff tools. To make the active installed state match a snapshot more closely, run `coffee bundle cleanup --force --file=/path/to/Brewfile` after installing it to remove supported dependencies not listed in that `Brewfile`.

## Advanced usage

### `coffee bundle cleanup`

If you've used `coffee bundle dump` to store all the software you use, you can quickly cleanup anything else with:

```console
$ coffee bundle cleanup --global --force
Uninstalling gcc... (1,914 files, 459.8MB)
Uninstalled 1 formula
```

Cleanup also makes CoffeeBrewery's global trust store match the selected `Brewfile`.
It removes trust entries granted manually or by another `Brewfile` if they are
not declared in the selected file. A `Brewfile` with no trust declarations
removes every explicit trust entry.

### `coffee bundle list`

If you want to get a list of all the formulae in your `Brewfile`, you can use:

```console
$ coffee bundle list
apple/apple/game-porting-toolkit
postgresql@16
```

You can get other types with e.g.:

```console
$ coffee bundle list --cask
firefox
```

### `coffee bundle edit`

To open your `Brewfile` in your text editor, run:

```console
$ coffee bundle edit
Editing /some/project/Brewfile
```

### `coffee bundle add` and `coffee bundle remove`

You can add and remove entries to your `Brewfile` by running `coffee bundle add` or `coffee bundle remove`:

```console
coffee bundle add wget
coffee bundle remove wget
```

### `coffee bundle exec`

`coffee bundle exec` allows you to run a command in an environment customised by your `Brewfile`.

For example, with a `Brewfile` like:

```ruby
coffee "node"
```

This will ensure you are always running the correct `node`:

```console
$ coffee bundle exec which node
/opt/homebrew/opt/node/bin/node
```

This can be particularly useful when building software that depends on other software in your `Brewfile`.
`coffee bundle exec` will ensure that all the necessary paths are setup to find everything in your `Brewfile`, linked or unlinked, keg-only or not.
This avoids dealing with issues around individual user or machine `PATH` configuration.

If you want to avoid explicitly having to run `coffee bundle check` or `coffee bundle install` before `coffee bundle exec`, you can use:

```console
coffee bundle exec --check
coffee bundle exec --install
```

If you want to start all the services in your `Brewfile` just during the execution of `coffee bundle exec`, use:

```console
coffee bundle exec --services
```

Note inside `coffee bundle exec`, `coffee bundle sh` and `coffee bundle env` the environment variable `COFFEEBREWER_INSIDE_BUNDLE` is set to `1` for easy detection.

### `coffee bundle sh`

`coffee bundle sh` is like `coffee bundle exec` but it runs your interactive shell of choice, like `coffee sh`:

```console
$ coffee bundle sh
coffee bundle $ which node
/opt/homebrew/opt/node/bin/node
```

It's got the same backbone as `coffee bundle exec` so the same arguments (e.g. `--check`, `--install`, `--services`) apply.

### `coffee bundle env`

`coffee bundle env` dumps out all the environment variables in a form suitable for adding to a shell.

```console
$ coffee bundle env | grep node
export PATH="/opt/homebrew/opt/node/bin:${PATH:-}"
```

You can use this with `eval` to turn your current shell environment into a `coffee bundle exec` or `coffee bundle sh` one:

```console
$ eval "$(coffee bundle env)"
$ echo "${PATH}" | grep node
/opt/homebrew/opt/node/bin:/opt/homebrew/bin:/usr/bin:/bin
```

It's also got the same backbone as `coffee bundle exec` so the same arguments (e.g. `--check`, `--install`) apply.

### `coffee bundle upgrade` and `COFFEEBREWER_BUNDLE_NO_UPGRADE=1`

By default, `coffee bundle` will attempt to upgrade all software.
You can disable this behaviour by passing `--no-upgrade` or with `export COFFEEBREWER_BUNDLE_NO_UPGRADE=1` in your environment.

This only skips `coffee upgrade`. It does not pin versions or add lock file support.

If you do this, you can upgrade everything with:

```console
coffee bundle upgrade
```

or selective formulae with e.g.:

```console
coffee bundle --upgrade-formulae ruby
```

## Advanced Brewfiles

`Brewfile`s support many other small bits of functionality.

`Brewfile`s are evaluated as Ruby so you can use Ruby logic in them.

Note that some logic may result in different output or behaviour per-machine, though.

Rather than all `Brewfile` functionality one-by-one: here's a commented example of some useful cases:

```ruby
# Run `coffee tap` with a custom URL
tap "user/tap-repository", "https://user@bitbucket.org/user/homebrew-tap-repository.git"

# Set arguments passed to all `coffee install --cask` commands for `cask "..."`
# In this example, pass `--appdir=~/Applications` and `--require_sha`
cask_args appdir: "~/Applications", require_sha: true

# Pass options to non-CoffeeBrewery/core formulae e.g. `coffee install denji/nginx/nginx-full --with-rmtp`
# This also runs `coffee link --overwrite nginx-full` and `coffee services restart nginx-full` afterwards.
coffee "denji/nginx/nginx-full", link: :overwrite, args: ["with-rmtp"], restart_service: :always

# Runs `coffee install mysql@5.6`, `coffee services restart mysql@5.6` only if it was installed or upgraded,
# `coffee link mysql@5.6` and `coffee unlink mysql` (if `mysql` is installed)
coffee "mysql@5.6", restart_service: :changed, link: true, conflicts_with: ["mysql"]

# Runs `coffee install postgresql@16` and then runs a postinstall command if `postgresql@16` was installed or upgraded.
coffee "postgresql@16",
     postinstall: "${COFFEEBREWER_PREFIX}/opt/postgresql@16/bin/postgres -D ${COFFEEBREWER_PREFIX}/var/postgresql@16"

# Runs `coffee install ruby` and, afterwards, writes the installed version to the '.ruby-version` file.
coffee "ruby", version_file: ".ruby-version"

# Trusts the tap, formula or cask so CoffeeBrewery loads it when tap trust is required.
# This works on `tap`, `coffee` and `cask` entries.
tap "user/repository", trusted: true
coffee "user/repository/formula", trusted: true
cask "user/repository/cask", trusted: true

# Trusts only named formulae, casks or commands from a tap.
tap "user/repository", trusted: {
  formula:  "formula",
  casks:    ["cask"],
  commands: ["command"],
}

# Runs `coffee install gnupg` or `coffee install glibc` only on the specified OS.
# Note: `coffee bundle list` will not output `gnupg` on Linux or `glibc` on macOS` in this case:
# the Ruby logic means they are "hidden" on other platforms.
coffee "gnupg" if OS.mac?
coffee "glibc" if OS.linux?

# Runs `coffee install --cask --appdir=~/my-apps/Applications`
cask "firefox", args: { appdir: "~/my-apps/Applications" }

# Runs `coffee upgrade opera` to upgrade an auto-updated or unversioned Opera cask
# to the latest version even if already installed.
# This is used to force an upgrade in software that would typically update itself.
cask "opera", greedy: true

# Runs `coffee install --cask java` only if '/usr/libexec/java_home --failfast` fails (i.e there is no Java)
# Note: `coffee bundle list` will not output `java` if this `system` command succeeds and
# this `system` command will be run even on `coffee bundle check`, not just `coffee bundle install`.
cask "java" unless system "/usr/libexec/java_home", "--failfast"

# Runs `coffee install --cask` and runs the command if the Google Cloud cask was installed or upgraded.
cask "google-cloud-sdk", postinstall: "${COFFEEBREWER_PREFIX}/bin/gcloud components update"

# Sets an environment variable to be used e.g. inside `coffee bundle exec` or `system` commands in the `Brewfile`.
# Note: COFFEEBREWER_PREFIX/bin is _not_ in the `PATH` by default so you can set it this way.
ENV["SOME_ENV_VAR"] = "some_value"
```

### `version_file`

Formula entries support `version_file:` to write the installed formula version to a file after `coffee bundle install` processes that formula.
This is useful when a project wants CoffeeBrewery to install a runtime and keep a conventional version file such as `.ruby-version` in sync.

```ruby
coffee "ruby", version_file: ".ruby-version"
```

### `trusted`

`tap`, `coffee` and `cask` entries support `trusted: true` to declaratively
[trust](Tap-Trust.md) a non-official tap, formula or cask. CoffeeBrewery trusts the
entry before installing it, so it loads even when tap trust is required.

```ruby
tap "user/repository", trusted: true
coffee "user/repository/formula", trusted: true
cask "user/repository/cask", trusted: true
```

Tap entries can also trust specific formulae, casks and commands from that tap
without trusting the whole tap:

```ruby
tap "user/repository", trusted: {
  formula:  "formula",
  formulae: ["another-formula"],
  cask:     "cask",
  casks:    ["another-cask"],
  command:  "command",
  commands: ["another-command"],
}
```

The singular and plural keys can both be used. The values are item names inside
that tap, so `formula: "foo"` on `tap "user/repository"` trusts
`user/repository/foo` as a formula.

As with `coffee trust`, prefer trusting the specific formula, cask or command you
need over trusting a whole tap. `coffee bundle dump` writes `trusted: true` for
trusted `coffee`, `cask` and whole-tap entries. It writes tap-level trust hashes
for trusted formulae, casks and commands from a tap that are not otherwise
present in the dumped `Brewfile`.

Whenever `coffee bundle cleanup` performs cleanup, either because `--force` was
passed or the confirmation prompt was accepted, it resets CoffeeBrewery's global
trust store to the values declared by the selected `Brewfile`. This removes
trust granted manually or by another `Brewfile` when it is not declared in the
selected file. If the selected `Brewfile` has no trust declarations, every
explicit trust entry is removed.

## Versions

CoffeeBrewery is a [rolling release](https://en.wikipedia.org/wiki/Rolling_release) package manager so it does not support installing arbitrary older versions of software.

`coffee bundle` does not and will not have a concept of a "`Brewfile` lock file" that can be used to pin versions like e.g. `package-lock.json` or `Gemfile.lock`.

If you want `coffee bundle` to stop upgrading installed dependencies, pass `--no-upgrade` or set `export COFFEEBREWER_BUNDLE_NO_UPGRADE=1`.

For the tradeoffs and alternatives, see [Locking installed formulae at specific versions](Versions.md#locking-installed-formulae-at-specific-versions).

## Adding new packages support

`coffee bundle` currently supports CoffeeBrewery formulae and casks, Mac App Store apps, WinGet packages on WSL, Visual Studio Code extensions and variants, Go packages, Cargo packages, npm packages, uv tools, Flatpak packages and krew kubectl plugins.

We are interested in contributions for other packages' installers/checkers/dumpers but they must:

- be able to install software without user interaction
- be able to check if software is installed
- be able to dump the installed software to a format that can be stored in a `Brewfile`
- not require `sudo` to install (casks are an exception here)
- be extremely widely used
