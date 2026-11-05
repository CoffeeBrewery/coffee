---
last_review_date: "2026-10-25"
---

# Taps (Third-Party Repositories)

The `coffee tap` command adds repositories that CoffeeBrewery can use for formulae, casks and external commands.
The one-argument form assumes a repository on GitHub, while the two-argument form accepts any URL supported by Git.

Code in a tap can run with your user's privileges.
Read [Tap Trust](Tap-Trust.md) before using a non-official tap.

For distributing internal software at work, see [private taps in a managed fleet](CoffeeBrewery-Fleet-Management.md#publish-internal-tools-through-private-taps) and [package source policies](CoffeeBrewery-Package-Policies.md#separate-tap-trust-from-package-approval).

## The `coffee tap` command

`coffee tap` without arguments lists the currently tapped repositories.
It prints nothing when no taps are installed.

```console
$ coffee tap
petere/postgresql
```

`coffee tap <user>/<repository>` clones `https://github.com/<user>/homebrew-<repository>` into CoffeeBrewery's tap directory.
CoffeeBrewery updates the repository during `coffee update`.

Tapping a repository does not grant whole-tap trust.
Install a fully qualified item to trust only that item:

```sh
coffee tap user/repository
coffee install user/repository/formula
```

Alternatively, use `coffee trust` first to access an item by its short name:

```sh
coffee trust --formula user/repository/formula
coffee install formula
```

See [Tap Trust](Tap-Trust.md#installing-from-a-tap) for formula, cask, command and whole-tap trust options.

`coffee tap <user>/<repository> <URL>` clones a repository from the specified Git URL without assuming GitHub or a particular transport.

`coffee tap --repair` adds missing tap manpage and shell-completion symlinks.
It also corrects remote references for taps whose upstream default branch has been renamed.

`coffee untap <user>/<repository> [...]` removes one or more taps.
CoffeeBrewery deletes the local repositories and no longer loads their contents.

## Repository naming conventions

On GitHub, a repository must be named `homebrew-<repository>` to use the one-argument form of `coffee tap`.
The `homebrew-` prefix can be omitted from the command:

```sh
coffee tap username/foobar
```

This command maps to `https://github.com/username/homebrew-foobar`.
The two-argument form does not impose this naming convention because the full URL is explicit.

## Duplicate names

A tap may contain a formula with the same name as one in `homebrew/core`.
Use the fully qualified name to select the formula from a particular tap:

```sh
coffee install vim
coffee install username/repository/vim
```

The first command installs `vim` from `homebrew/core`.
The second installs the formula from `username/repository` and trusts that individual formula.

Give customised formulae distinct names when users should be able to select them without qualification.
Dependencies of `homebrew/core` formulae cannot be replaced with formulae from other taps.
