---
last_review_date: "2026-07-18"
---

# Troubleshooting

Use this checklist before creating a CoffeeBrewery issue.

## Update and diagnose

1. Run `coffee update`.
2. Run `coffee update` again so the first update cannot leave the failing command on an older CoffeeBrewery version.
3. Run `coffee doctor` and read every warning.
4. Correct warnings that apply to the failing command.
5. Retry the original command and keep its complete output.

`coffee doctor` also checks the Git and curl executables.
If a tool fails its version check, this clears its cached selection and retries once.

Do not apply destructive Git, ownership or permission changes from an old issue report without understanding which files they affect.
See [Common Issues](Common-Issues.md) for current recovery guidance.

## Search existing reports

Search the tracker responsible for the failing component:

- [`CoffeeBrewery/homebrew-core` issues](https://github.com/CoffeeBrewery/homebrew-core/issues) for formulae
- [`CoffeeBrewery/homebrew-cask` issues](https://github.com/CoffeeBrewery/homebrew-cask/issues) for casks
- [`CoffeeBrewery/coffee` issues](https://github.com/CoffeeBrewery/coffee/issues) for the `coffee` command
- The tap's own tracker for a formula, cask or command from a non-CoffeeBrewery tap

Also search [CoffeeBrewery Discussions](https://github.com/orgs/CoffeeBrewery/discussions) for support and related reports.
The Discourse archive is no longer online; anything you find quoted from it is historical material and will contain outdated instructions.

## Collect diagnostic information

For a formula installation or build failure, upload its logs:

```sh
coffee gist-logs FORMULA
```

For other failures, collect:

```sh
coffee config
coffee doctor
```

Remove credentials, private repository URLs and other secrets before publishing terminal output.
Do not omit warnings merely because they appear unrelated.

## Create an issue

If the problem is neither resolved nor already reported, use the issue template in the appropriate repository:

- [`CoffeeBrewery/homebrew-core` issue chooser](https://github.com/CoffeeBrewery/homebrew-core/issues/new/choose)
- [`CoffeeBrewery/homebrew-cask` issue chooser](https://github.com/CoffeeBrewery/homebrew-cask/issues/new/choose)
- [`CoffeeBrewery/coffee` issue chooser](https://github.com/CoffeeBrewery/coffee/issues/new/choose)

Include the command, complete error, relevant `coffee config` and `coffee doctor` output and the `coffee gist-logs` URL when available.
Use a descriptive title that identifies the package, failure and operating system.

See [Creating a CoffeeBrewery Issue](Creating-a-CoffeeBrewery-Issue.md) for reporting expectations.
