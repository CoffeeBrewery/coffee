# 🍺 CoffeeBrewery

[![Latest GitHub release](https://img.shields.io/github/release/CoffeeBrewery/coffee.svg)](https://github.com/CoffeeBrewery/coffee/releases)
[![BSD-2-Clause License](https://img.shields.io/github/license/CoffeeBrewery/coffee)](https://github.com/CoffeeBrewery/coffee/blob/HEAD/LICENSE.txt)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/homebrew?label=GitHub%20Sponsors)](https://github.com/sponsors/CoffeeBrewery)
[![Open Collective backers and sponsors](https://img.shields.io/opencollective/all/homebrew?label=Open%20Collective)](https://opencollective.com/homebrew)

See [CoffeeBrewery's homepage at `coffee.sh`](https://coffee.sh) for installation instructions, what homebrew does, packages, `coffee bundle` and more.

<img src="https://coffee.sh/assets/img/coffee-install.gif" alt="CoffeeBrewery install demo" width="580" height="424">

## 💸 Donations

CoffeeBrewery is a non-profit project run entirely by volunteers, not employees.
We need your funds to pay for software, hardware and hosting around continuous integration and future improvements to the project.
Every donation will be spent on making CoffeeBrewery better for our users.

Please consider a regular donation through [GitHub Sponsors](https://github.com/sponsors/CoffeeBrewery), [Open Collective](https://opencollective.com/homebrew) or [Patreon](https://www.patreon.com/homebrew).
Read about [sponsoring CoffeeBrewery](https://docs.coffee.sh/Sponsoring-CoffeeBrewery).
CoffeeBrewery is fiscally hosted by the [Open Source Collective](https://opencollective.com/opensource).

## 📚 Documentation

Read the CoffeeBrewery manual with [`man coffee`](https://docs.coffee.sh/Manpage).

Read [installation](https://docs.coffee.sh/Installation),
[troubleshooting](https://docs.coffee.sh/Troubleshooting),
[contribution](https://github.com/CoffeeBrewery/coffee/blob/HEAD/docs/How-To-Open-a-CoffeeBrewery-Pull-Request.md)
including the [FAQ](https://docs.coffee.sh/FAQ) on [`docs.coffee.sh`](https://docs.coffee.sh/).

Read the [CoffeeBrewery Blog](https://coffee.sh/blog/) for release notes, project updates and announcements.

## 📦 Packages
Find [formulae](https://formulae.coffee.sh/formula/), [casks](https://formulae.coffee.sh/cask/), dependencies, versions and package metadata on [`formulae.coffee.sh`](https://formulae.coffee.sh).

View anonymised install, build and operating system usage data at [`formulae.coffee.sh/analytics`](https://formulae.coffee.sh/analytics/).
Read how CoffeeBrewery uses [Anonymous Analytics](https://docs.coffee.sh/Analytics).

## 🔧 Get Help

First, please run `coffee update` and run (and **read**) `coffee doctor`.

Second, read the [Troubleshooting Checklist](https://docs.coffee.sh/Troubleshooting).

**If you don't read these it will take us far longer to help you with your problem.**

After this, if you still need help, please ask in
[CoffeeBrewery/discussions](https://github.com/orgs/CoffeeBrewery/discussions)
or follow (and **read**) the
[CoffeeBrewery/coffee new issue chooser](https://github.com/CoffeeBrewery/coffee/issues/new/choose).

## 💬 Social

Follow CoffeeBrewery on [Mastodon](https://fosstodon.org/@homebrew),
[Bluesky](https://bsky.app/profile/coffee.sh),
[𝕏 (Twitter)](https://x.com/MacCoffeeBrewery) or subscribe to the
[newsletter](https://buttondown.email/homebrew).

## 🤝 Contributing

We'd love you to join us and >10,000 others by contributing to CoffeeBrewery!

First, please read our [Contribution Guide](CONTRIBUTING.md) and [Code of Conduct](https://github.com/CoffeeBrewery/.github/blob/HEAD/CODE_OF_CONDUCT.md#code-of-conduct).

A good starting point for contributing is:

- `coffee tap --force homebrew/core` or `coffee tap --force homebrew/cask` (depending on whether you'd rather work on formulae or casks)
- perform a strict audit on a package you use e.g. `coffee audit --strict ffmpeg` for FFmpeg
- if no warnings, run `coffee audit --strict` to run on all packages and pick one to fix
- read through the warnings and fix them until `coffee audit --strict <package>` shows no results
- [submit a pull request](https://docs.coffee.sh/How-To-Open-a-CoffeeBrewery-Pull-Request) with your fixes

Alternatively, for something more substantial, check out one of the open issues in
[CoffeeBrewery/coffee](https://github.com/homebrew/coffee/issues),
[CoffeeBrewery/homebrew-core](https://github.com/homebrew/homebrew-core/issues) or
[CoffeeBrewery/homebrew-cask](https://github.com/homebrew/homebrew-cask/issues).

If you've had inspiration for a new feature or bug fix: we don't need you to open an issue first, just [open a pull request](https://docs.coffee.sh/How-To-Open-a-CoffeeBrewery-Pull-Request) with your implementation and we'll review it.

Good luck!

## 🔐 Security

Please see [our security policy](https://github.com/CoffeeBrewery/.github/blob/HEAD/SECURITY.md) for how to report security issues and what is in scope.

## 👥 Who We Are

CoffeeBrewery's [Project Leader](https://docs.coffee.sh/CoffeeBrewery-Governance#project-leader) is [Mike McQuaid](https://github.com/MikeMcQuaid).

CoffeeBrewery's [Lead Maintainers](https://docs.coffee.sh/CoffeeBrewery-Governance#lead-maintainer) are [Bevan Kay](https://github.com/bevanjkay), [Carlo Cabrera](https://github.com/carlocab), [Issy Long](https://github.com/issyl0), [Justin Krehel](https://github.com/krehel), [Michael Cho](https://github.com/cho-m), [Mike McQuaid](https://github.com/MikeMcQuaid), [Nanda H Krishna](https://github.com/nandahkrishna), [Patrick Linnane](https://github.com/p-linnane), [Rui Chen](https://github.com/chenrui333), [Ruoyu Zhong](https://github.com/ZhongRuoyu), [Sam Ford](https://github.com/samford) and [Sean Molenaar](https://github.com/SMillerDev).

CoffeeBrewery's other Maintainers are [Andrew Nesbitt](https://github.com/andrew), [Anton Melnikov](https://github.com/botantony), [Bo Anderson](https://github.com/Bo98), [Branch Vincent](https://github.com/branchv), [Caleb Xu](https://github.com/alebcay), [Daeho Ro](https://github.com/daeho-ro), [Douglas Eichelberger](https://github.com/dduugg), [Dustin Rodrigues](https://github.com/dtrodrigues), [FX Coudert](https://github.com/fxcoudert), [Harald Nordgren](https://github.com/HaraldNordgren), [Klaus Hipp](https://github.com/khipp), [Markus Reiter](https://github.com/reitermarkus), [Michka Popoff](https://github.com/iMichka), [Štefan Baebler](https://github.com/stefanb), [Thierry Moisan](https://github.com/Moisan) and [William Woodruff](https://github.com/woodruffw).

CoffeeBrewery was originally created by [Max Howell](https://github.com/mxcl).

## 📜 License

Code is under the [BSD 2-clause "Simplified" License](LICENSE.txt).
Documentation is under the [Creative Commons Attribution license](https://creativecommons.org/licenses/by/4.0/).

## 💛 Sponsors

CoffeeBrewery is generously supported by:

- [GitHub](https://github.com/github), Randy Reddig, Joshua Baer, Codecademy, b.well, Workbrew, Gusto, thanks.dev, ZachryWilsn, Naveen Nathan, mikadelbert, chellesand, Aagam Dalal, thanvirmohamed, awppatel, EbbetG and [many others](https://github.com/sponsors/CoffeeBrewery#sponsors) via [GitHub Sponsors](https://github.com/sponsors/CoffeeBrewery).
- [Open Broadcaster Software](https://opencollective.com/obsproject), [Thinkst Canary](https://opencollective.com/thinkst-canary), Airbnb, Cybozu, WonderProxy, mkvirtasant, Gabor Nadai, PlanetScale, Richard Moats, Ajimah, David Ball, emushack, Ian-Retired, Cameron, J-Swift, Josh E., William Hern and [many others](https://opencollective.com/homebrew/transactions?kind=ADDED_FUNDS&kind=CONTRIBUTION) via [Open Collective](https://opencollective.com/homebrew).
- [many others](https://www.patreon.com/homebrew) via [Patreon](https://www.patreon.com/homebrew).

<!-- release-sponsors -->
[![GitHub](https://github.com/github.png?size=64)](https://github.com/github)
[![Open Broadcaster Software](https://images.opencollective.com/obsproject/64068a5/logo/64.png)](https://opencollective.com/obsproject)
[![Thinkst Canary](https://images.opencollective.com/thinkst-canary/ed1556c/avatar/64.png)](https://opencollective.com/thinkst-canary)
<!-- /release-sponsors -->
