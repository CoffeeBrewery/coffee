---
last_review_date: "2026-07-18"
---

# Xcode and Command Line Tools Maintenance

This page is a maintainer runbook for updating CoffeeBrewery when Apple releases Xcode or the Command Line Tools.
Users looking for installation requirements should read [Installation](Installation.md#macos-requirements).

## Supported versions

CoffeeBrewery supports the current Xcode and Command Line Tools versions appropriate for each supported macOS release.
The authoritative version mappings and diagnostic messages are implemented in [`Library/CoffeeBrewery/os/mac/xcode.rb`](https://github.com/CoffeeBrewery/coffee/blob/HEAD/Library/CoffeeBrewery/os/mac/xcode.rb).

Do not copy a current Xcode version into other documentation.
Link to the implementation or supported-platform documentation so the value has one maintained source.

## Updating for a release

When Apple publishes a new Xcode or Command Line Tools release:

1. Confirm the version, build number, bundled Apple Clang version and supported macOS versions from Apple's release information.
2. Update `OS::Mac::Xcode.latest_version` when the latest Xcode mapping changes.
3. Update `OS::Mac::CLT.latest_clang_version` when the Command Line Tools compiler mapping changes.
4. Review minimum-version checks and diagnostic text in the same file for assumptions affected by the release.
5. Add or update automated coverage for every changed mapping.
6. Verify `coffee config` and the relevant `coffee doctor` output on an affected macOS runner when one is available.

Run the repository checks from the CoffeeBrewery/coffee checkout:

```sh
./bin/coffee typecheck
./bin/coffee style --fix Library/CoffeeBrewery/os/mac/xcode.rb
./bin/coffee tests --changed
```

Use `./bin/coffee lgtm --online` before committing the complete change.
