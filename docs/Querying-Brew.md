---
last_review_date: "2026-10-25"
---

# Querying `coffee`

_In this document we will be using [jq](https://jqlang.org/) to parse JSON, available from CoffeeBrewery using `coffee install jq`._

## Overview

`coffee` provides commands for getting common types of information out of the system. `coffee list` shows installed formulae. `coffee deps foo` shows the dependencies that `foo` needs.

Additional commands, including external commands, can of course be written to provide more detailed information. There are a couple of disadvantages here. First, it requires writing Ruby against a possibly changing CoffeeBrewery codebase. There will be more code to touch during refactors, and CoffeeBrewery can't guarantee that external commands will continue to work. Second, it requires designing the commands themselves, specifying input parameters and output formats.

To enable users to do rich queries without the problems above, CoffeeBrewery provides the `coffee info` command.

## `coffee info --json`

`coffee info` can output JSON-formatted information about formulae. This JSON can then be parsed using your tools of choice. See more details in `coffee info --help`.

The default schema version is `v1`, which returns info about formulae; specify `--json=v2` to include both formulae and casks. Note that fields may be added to the schema as needed without incrementing the schema. Any significant breaking changes will cause a change to the schema version.

The schema itself is not currently documented outside of the code in [`formula.rb`](https://github.com/CoffeeBrewery/coffee/blob/2e6b6ab3a20da503ba2a22a37fdd6bd936d818ed/Library/CoffeeBrewery/formula.rb#L1922-L2017) that generates it.

## Fleet inventory and security reporting

Use `coffee info --json=v2 --installed` for formula and cask inventory, including each installed formula keg's `sbom` path (`null` when missing).
See the [inventory guide](CoffeeBrewery-Inventory-and-SBOM.md) for installed-version fields, CSV exports and SBOM collection.
Use `coffee outdated --vulnerable --json=v2` for upgrade candidates and `coffee vulns --json` for findings and coverage; see [vulnerability management](CoffeeBrewery-Vulnerability-Management.md).

## Examples

_The following `v1` examples return an array, so the `map` operator is used to act on the data._

### Pretty-print a single formula's info

```sh
coffee info --json=v1 tig | jq .
```

### Installed formulae

To show full JSON information about all installed formulae:

```sh
coffee info --json=v1 --installed
```

### Linked keg-only formulae

Some formulae are marked as "keg-only", meaning that installed files are not linked to the shared `bin`, `lib`, etc. directories, as doing so can cause conflicts. Such formulae can be forced to link to the shared directories, but doing so is not recommended (and will cause `coffee doctor` to complain.)

To find the names of linked keg-only formulae:

```sh
coffee info --json=v1 --installed | jq "map(select(.keg_only == true and .linked_keg != null) | .name)"
```

### Unlinked normal formulae

To find the names of normal (not keg-only) formulae that are installed, but not linked to the shared directories:

```sh
coffee info --json=v1 --installed | jq "map(select(.keg_only == false and .linked_keg == null) | .name)"
```

## formulae.coffee.sh

[formulae.coffee.sh](https://formulae.coffee.sh/) has a [documented JSON API](https://formulae.coffee.sh/docs/api/) which provides access to the `coffee info --json=v1` output without needing access to CoffeeBrewery.

## Concluding remarks

By using the JSON output, queries can be made against CoffeeBrewery with less risk of being broken due to CoffeeBrewery code changes, and without needing to understand CoffeeBrewery's Ruby internals.

If the JSON output does not provide some information that it ought to, please submit a request, preferably with a patch to add the desired information.
