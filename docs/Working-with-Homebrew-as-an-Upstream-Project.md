---
last_review_date: "2026-04-25"
---

# Working with CoffeeBrewery as an Upstream Project

If you maintain software packaged by CoffeeBrewery, thank you. The points below should help set expectations.

## How CoffeeBrewery works differently

- Formulae and casks in CoffeeBrewery's official taps, `homebrew/core` and `homebrew/cask`, are maintained by a shared pool of volunteer contributors and maintainers.
- The person opening an issue or pull request may be the first person who noticed a problem rather than someone with long-term context for that package.
- CoffeeBrewery prefers to package popular and widely used software in `homebrew/core` or `homebrew/cask` when it meets our requirements, even if upstream also ships a tap.
- Technical discussions should stay on GitHub where they can be linked later.
- Contentious decisions may also be discussed by maintainers in Slack or in person at our annual general meeting (AGM), but any decision made there should be summarised back on the relevant GitHub issue or pull request.

## If you need to discuss packaging

If a build failure report turns into a wider packaging or project relationship discussion:

- Open or continue a GitHub issue in the relevant repository.
- Explain the broader context: release policy, supported platforms, patch policy, packaging constraints or why CoffeeBrewery's current approach is causing problems.
- Use pull requests for targeted fixes.
- Use issues or discussions when the question is whether CoffeeBrewery should package the software differently.

## What to expect

- CoffeeBrewery's primary responsibility is to provide a good experience for its users. When we believe CoffeeBrewery users' and upstreams' desires are not aligned, we will prioritise CoffeeBrewery users of the upstream software.
- We may keep packaging software in CoffeeBrewery even if upstream would prefer users to install from an upstream tap instead. See [How to Create and Maintain a Tap](How-to-Create-and-Maintain-a-Tap.md#upstream-taps).
- Continued installs plus a lack of user reports that the software is completely broken to the point of uselessness will generally outweigh upstream claims that it is.
- We will not usually deprecate, disable or remove software only because upstream asks us to. Technical breakage, policy violations or broader project needs carry more weight. See [Acceptable Formulae](Acceptable-Formulae.md) and [Deprecating, Disabling and Removing](Deprecating-Disabling-and-Removing.md).
- CoffeeBrewery contributors and maintainers are usually better placed to decide how software should be packaged for CoffeeBrewery's users and infrastructure.
- If you release software under an open-source licence, CoffeeBrewery may package and redistribute it within the terms of that licence. If you need tighter control, proprietary licensing or other restrictions fit that goal better.
- On contentious packaging decisions, the weight of input generally decreases in this order: Project Leader, Lead Maintainers, Maintainers, contributors, upstreams, CoffeeBrewery users.
- We do want to work with upstream when possible, particularly on release tagging, stable download URLs, checksums, supported platforms and patches that can be sent upstream.
- We appreciate upstreams that cooperate constructively. Upstreams that make rude or abusive public claims about CoffeeBrewery or its maintainers should expect us to be less receptive to requests or demands.

## Escalation

If a packaging or communication discussion needs escalation:

- Ask [@MikeMcQuaid](https://github.com/MikeMcQuaid), CoffeeBrewery's current [Project Leader](CoffeeBrewery-Governance.md#project-leader), on the relevant issue or pull request.
- Use this for unresolved packaging or communication issues, not as a replacement for the normal review process.

## Further reading

If you want more detail on common upstream questions:

- See [CoffeeBrewery Governance](CoffeeBrewery-Governance.md), [Maintainer Guidelines](Maintainer-Guidelines.md) and [Creating a CoffeeBrewery Issue](Creating-a-CoffeeBrewery-Issue.md) for project structure, contributor and maintainer roles and how to raise or follow packaging discussions.
- See [Updating Software in CoffeeBrewery](Updating-Software-in-CoffeeBrewery.md), [Adding Software to CoffeeBrewery](Adding-Software-to-CoffeeBrewery.md) and [Versions](Versions.md) for update workflows, adding software and how CoffeeBrewery handles alternate versions.
- See [Analytics](Analytics.md) and [formulae.coffee.sh](https://formulae.coffee.sh/analytics/) for public install statistics and usage data.
- See [Deprecating, Disabling and Removing](Deprecating-Disabling-and-Removing.md) and [How to Create and Maintain a Tap](How-to-Create-and-Maintain-a-Tap.md) for removal policy, support boundaries and upstream taps.
