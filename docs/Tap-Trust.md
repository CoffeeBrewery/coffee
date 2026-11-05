---
last_review_date: "2026-10-25"
---

# Tap Trust

CoffeeBrewery taps can contain formulae, casks and external commands.
Loading them can run Ruby code from the tap, so CoffeeBrewery distinguishes between official taps and non-official taps that you have explicitly trusted.

Official CoffeeBrewery taps and CoffeeBrewery's built-in commands are always trusted.
Non-official taps require explicit trust by default [since CoffeeBrewery 6.0.0](https://coffee.sh/2026/06/11/homebrew-6.0.0/).

`coffee doctor` warns about non-official taps for which neither the tap nor any individual item is trusted.
Commands that need to load an untrusted tap or item will fail until the relevant trust is granted.

For centrally managed devices, combine trust decisions with [package policies and approvals](CoffeeBrewery-Package-Policies.md#separate-tap-trust-from-package-approval).
Use [inventory and scan coverage](CoffeeBrewery-Vulnerability-Management.md#capture-findings-without-losing-errors) to identify installations omitted because their taps are untrusted.

## Why tap trust exists

Formulae, casks and external commands are executable package definitions, not plain metadata.
CoffeeBrewery sometimes needs to evaluate Ruby code from a tap to resolve dependencies, discover packages or run commands.
Trusting a tap means accepting that its code may run with your user's privileges whenever CoffeeBrewery loads it.

Tap trust reduces the amount of non-official code CoffeeBrewery evaluates by default.
This limits the impact of compromised tap repositories, unexpected repository ownership changes, package name collisions and commands loaded merely because their tap is present.
It also makes automation explicit by allowing scripts to trust only the tap, formula, cask or command they intend to use.

Tap trust is one part of CoffeeBrewery's wider approach to [software supply chain security](CoffeeBrewery-Security-and-Supply-Chain.md).

Prefer trusting the specific formula, cask or command you need.
Trust a whole tap only when you accept all current and future formulae, casks and external commands from that tap.

## Installing from a tap

Installing a fully qualified formula or cask name trusts only that item:

```sh
coffee install user/repository/formula
coffee install --cask user/repository/cask
```

Formula trust must be granted using the canonical name. If an alias or former
name resolves to an untrusted formula, CoffeeBrewery refuses to load it and shows the
canonical name to trust explicitly. Aliases and former names can be used once
that formula is trusted. If their target changes, the new formula requires its
own trust; existing trust does not follow the alias or rename.

To install by short name from a tapped repository, trust the specific item first:

```sh
coffee tap user/repository
coffee trust --formula user/repository/formula
coffee install formula
```

Use `coffee trust --cask user/repository/cask` for casks and `coffee trust --command user/repository/command` for external commands.

You can also trust the whole tap:

```sh
coffee tap user/repository
coffee trust user/repository
coffee install formula
```

Whole-tap trust allows CoffeeBrewery to load every current and future formula, cask and external command from that tap.
This may be appropriate for a tap you administer or use frequently.
For one-off installs, automation or software from a vendor you do not fully control, prefer trusting only the required item.

## Trusting in a `Brewfile`

For `Brewfile` trust syntax and `coffee bundle` dump and cleanup behaviour, see the [`trusted` section of the CoffeeBrewery Bundle documentation](Brew-Bundle-and-Brewfile.md#trusted).

## Managing trust

List trusted entries:

```sh
coffee trust
```

List untrusted taps, formulae, casks and commands:

```sh
coffee untrust
```

Stop trusting a tap or item:

```sh
coffee untrust user/repository
coffee untrust --formula user/repository/formula
```

An untrusted tap is not loaded when tap trust is required unless you explicitly install a fully qualified formula or cask from that tap.
If you trust only a specific formula, cask or command, CoffeeBrewery may load that item without trusting the rest of its tap.

## Environment variables

Tap trust is required by default.
Commands that evaluate all formulae or casks load only official or explicitly trusted entries.

`COFFEEBREWER_REQUIRE_TAP_TRUST=1` is deprecated because it only requests the default behaviour and should be unset.
`COFFEEBREWER_NO_REQUIRE_TAP_TRUST=1` is also deprecated and will be removed in a later release.
Instead of disabling tap trust, use `coffee trust` to trust only the tap, formula, cask or command you need.
