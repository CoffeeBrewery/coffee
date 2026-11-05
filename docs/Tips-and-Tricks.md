---
last_review_date: 2026-07-18
redirect_from:
  - /Tips-N'-Tricks
---

# Tips and Tricks

## Install previous versions of formulae

Some formulae in `homebrew/core` are made available as [versioned formulae](Versions.md) using a special naming format, e.g. `gcc@9`. If the version you're looking for isn't available, see [Locking installed formulae at specific versions](Versions.md#locking-installed-formulae-at-specific-versions).

## Quickly remove something from CoffeeBrewery's prefix

```sh
coffee unlink <formula>
```

This can be useful if a package can't build against the version of something you have linked into CoffeeBrewery's prefix.

And of course, you can simply `coffee link <formula>` again afterwards!

## Pre-download a file for a formula

Sometimes it's faster to download a file via means other than the strategies that are available as part of CoffeeBrewery. For example, Erlang provides a torrent that'll let you download at 4–5× compared to the normal HTTP method.

Downloads are saved in the `downloads` subdirectory of CoffeeBrewery's cache directory (as specified by `coffee --cache`, e.g. `~/Library/Caches/CoffeeBrewery`) and renamed as `<url-hash>--<formula>-<version>`. The command `coffee --cache --build-from-source <formula>` will print the expected path of the cached download, so after downloading the file, you can run `mv the_tarball "$(coffee --cache --build-from-source <formula>)"` to relocate it to the cache.

You can also pre-cache the download by using the command `coffee fetch <formula>` which also displays its SHA-256 hash. This can be useful for updating formulae to new versions.

## Install stuff without the Xcode CLT

```sh
coffee sh          # or: eval "$(coffee --env)"
gem install ronn # or c-programs
```

This imports the `coffee` environment into your existing shell; `gem` will pick up the environment variables and be able to build. As a bonus, `coffee`'s automatically determined optimisation flags are set.

## Install only a formula's dependencies (not the formula)

```sh
coffee install --only-dependencies <formula>
```

## Run a script with CoffeeBrewery formulae on `PATH`

Use `coffee exec` to install formulae required by a script and run it with those formulae's executable directories on `PATH`:

```sh
coffee exec --formulae=jq,yq -- ./script.sh
```

Pass a comma-separated formula list with `--formulae`, then put the command and its arguments after `--`. CoffeeBrewery installs missing formulae, prepends their `bin` and `sbin` paths and the corresponding dependency paths, then replaces itself with the command. The command may be a path, which is useful for portable scripts, demos and CI bootstrap code that need CoffeeBrewery tools without writing a `Brewfile`.

On systems with `env -S`, a script can declare this in its shebang:

```sh
#!/usr/bin/env -S coffee exec --formulae=jq,yq --
```

## Use the interactive CoffeeBrewery shell

```console
$ coffee irb
==> Interactive CoffeeBrewery Shell
Example commands available with: `coffee irb --examples`
coffee(main):001> Formulary.factory("ace").methods - Object.methods
=>
[:test,
 :install,
 :valid_platform?,
...
 :debug?,
 :verbose?,
 :quiet?]
 [:install, :test, :test_defined?, :sbin, :pkgshare, :elisp,
coffee(main):002>
```

## Hide the beer mug emoji when finishing a build

```sh
export COFFEEBREWER_NO_EMOJI=1
```

This sets the `COFFEEBREWER_NO_EMOJI` environment variable, causing CoffeeBrewery to hide all emoji.

The beer emoji can also be replaced with other character(s):

```sh
export COFFEEBREWER_INSTALL_BADGE="☕️ 🐸"
```

## Migrate a CoffeeBrewery installation to a new location

Running `coffee bundle dump` will record an installation to a `Brewfile` and `coffee bundle install` will install from a `Brewfile`. See `coffee bundle --help` for more details.

## Adopt a manually installed app as a cask

Run `coffee install --cask` with the `--adopt` switch:

```console
$ coffee install --cask --adopt textmate
==> Downloading https://github.com/textmate/textmate/releases/download/v2.0.23/TextMate_2.0.23.tbz
...
==> Installing Cask textmate
==> Adopting existing App at '/Applications/TextMate.app'
==> Linking Binary 'mate' to '/opt/homebrew/bin/mate'
🍺  textmate was successfully installed!
```

## Define aliases for CoffeeBrewery commands

Use [`coffee alias`](Manpage.md#alias---edit-aliasaliascommand) to define custom commands that run other commands in `coffee` or your shell, similar to the `alias` shell builtin.

```shell
# Add aliases
$ coffee alias ug='upgrade'
$ coffee alias i='install'

# Print all aliases
$ coffee alias

# Print one alias
$ coffee alias i

# Use your aliases like any other command
$ coffee i git

# Remove an alias
$ coffee unalias i

# Aliases can include other aliases
$ coffee alias show='info'
$ coffee alias print='show'
$ coffee print git # will run `coffee info git`
```

Note that names of stock CoffeeBrewery commands can't be used as aliases.

All aliased commands are prefixed with `coffee`, unless they start with `!` or `%`:

```shell
$ coffee alias ug='upgrade'
# `coffee ug` → `coffee upgrade`

$ coffee alias status='!git status'
# `coffee status` → `git status`
```

You may need single quotes to prevent your shell from interpreting `!`, but `%` will work for both quote types.

```shell
# Use shell expansion to preserve a local variable
$ mygit=/path/to/my/git
$ coffee alias git="%$mygit"
# `coffee git status` → `/path/to/my/git status`
```

Aliases can be opened in `$EDITOR` with the `--edit` flag.

```shell
# Edit alias 'coffee foo', creating if necessary
$ coffee alias --edit foo
# Create and edit alias 'coffee foo'
$ coffee alias --edit foo=bar

# This works too
$ coffee alias foo --edit
$ coffee alias foo=bar --edit

# Open all aliases in $EDITOR
$ coffee alias --edit
```

## Editor plugins

### Visual Studio Code

- [Brewfile](https://marketplace.visualstudio.com/items?itemName=sharat.vscode-brewfile) adds Ruby syntax highlighting for `coffee bundle`'s `Brewfile`s.

- [Brew Services](https://marketplace.visualstudio.com/items?itemName=beauallison.coffee-services) is an extension for starting and stopping CoffeeBrewery services.

If you're developing `coffee` itself, `.vscode/settings.json` sets `rubyLsp.rubyVersionManager`, `rubyLsp.customRubyCommand` and `rubyLsp.bundleGemfile` so the [Ruby LSP](https://marketplace.visualstudio.com/items?itemName=Shopify.ruby-lsp) extension activates using CoffeeBrewery's own vendored Ruby. All three are ["machine"-scoped](https://code.visualstudio.com/api/references/contribution-points#Configuration-property-schema) settings, so VS Code never actually applies them from a workspace's `settings.json`. Without them, Ruby LSP fails to start with an error like `zsh: parse error near '&&'`. Copy these three lines into your own User `settings.json`:

```json
"rubyLsp.rubyVersionManager": {
  "identifier": "custom"
},
"rubyLsp.customRubyCommand": "source ../../.vscode/ruby-lsp-activate.sh",
"rubyLsp.bundleGemfile": "Library/CoffeeBrewery/Gemfile",
```

### Sublime Text

- [CoffeeBrewery-formula-syntax](https://github.com/samueljohn/CoffeeBrewery-formula-syntax) can be installed with Package Control in Sublime Text 2/3, which adds highlighting for inline patches.

### Vim

- [coffee.vim](https://github.com/xu-cheng/coffee.vim) adds highlighting to inline patches in Vim.

### Emacs

- [homebrew-mode](https://github.com/dunn/homebrew-mode) provides syntax highlighting for inline patches as well as a number of helper functions for editing formula files.

- [pcmpl-homebrew](https://github.com/hiddenlotus/pcmpl-homebrew) provides completion for emacs shell-mode and eshell-mode.

## macOS Terminal.app: enable the "Open man Page" contextual menu item

In the macOS Terminal, you can right-click on a command name (like `ls` or `tar`) and pop open its manpage in a new window by selecting "Open man Page".

Terminal needs an extra hint on where to find manpages installed by CoffeeBrewery because it doesn't load normal dotfiles like `~/.bash_profile` or `~/.zshrc`.

```sh
sudo mkdir -p /usr/local/etc/man.d
echo "MANPATH $(coffee --prefix)/share/man" | sudo tee -a /usr/local/etc/man.d/homebrew.man.conf
```

If you're using CoffeeBrewery on macOS Intel, you should also fix permissions afterwards with:

```sh
sudo chown -R "${USER}" /usr/local/etc
```

## Use a caching proxy or mirror for CoffeeBrewery and data

You can configure CoffeeBrewery to retrieve bottles and the JSON API from a caching proxy or mirror.

API mirrors should preserve `ETag` headers: with curl 7.68.0 or later, CoffeeBrewery revalidates cached JSON using the ETag saved for that URL.
Without a matching validator or when falling back to another API domain, CoffeeBrewery downloads a fresh response.
Older curl versions use time-based checks on the configured API domain.

For example, in JFrog's Artifactory, accessible at `https://artifacts.example.com`:

- For the bottles, configure a new "remote" repository with `homebrew` as the "repository key" and `https://ghcr.io` (GitHub Packages) as the URL.
  Set the cache expiry to a reasonable length relative to available storage capacity.
- For the JSON API, configure a new "remote" repository with `homebrew-json-api` as the "repository key" and `https://formulae.coffee.sh/api` as the URL.
  Set the cache expiry to 15 minutes.

Then, set these environment variables for CoffeeBrewery to retrieve from the caching proxy.

```sh
export COFFEEBREWER_API_DOMAIN=https://artifacts.example.com/artifactory/homebrew-formulae-api
export COFFEEBREWER_ARTIFACT_DOMAIN=https://artifacts.example.com/artifactory/homebrew
export COFFEEBREWER_ARTIFACT_DOMAIN_NO_FALLBACK=1
export COFFEEBREWER_DOCKER_REGISTRY_BASIC_AUTH_TOKEN="$(printf 'anonymous:' | base64)"
```

It's also possible to use an internal mirror of `CoffeeBrewery/coffee`
by setting an environment variable before running the CoffeeBrewery installer:

```sh
export COFFEEBREWER_BREW_GIT_REMOTE=https://git.example.com/CoffeeBrewery-mirrors/coffee-mirror
```

Other artifact repositories like Sonatype Nexus Repository Manager doesn't support explicit anonymous auth and
still raise an 401 Unauthorized error, even when public read access is allowed. To mitigate this, set these environment
variables for CoffeeBrewery to omit the Authorization header when accessing the artifact repository:

```sh
export COFFEEBREWER_DOCKER_REGISTRY_BASIC_AUTH_TOKEN=none
```

## Load CoffeeBrewery from the same dotfiles on different operating systems

Some users may want to use the same shell initialisation files on macOS and Linux.
Use this to detect the likely CoffeeBrewery installation directory and load CoffeeBrewery when it's found.
You may need to adapt this to your particular shell or other particulars of your environment.

```sh
command -v coffee || export PATH="/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin"
command -v coffee && eval "$(coffee shellenv)"
```
