---
last_review_date: "2026-06-10"
---

# Agent Instructions for CoffeeBrewery/coffee docs

These instructions apply when working in `docs/`.

## Tooling

- Use the system CoffeeBrewery `coffee bundle exec ...` workflow from this directory
  rather than `./bin/coffee` for the docs site toolchain.
- Set `COFFEEBREWER_NO_AUTO_UPDATE=1` for docs verification commands to match the
  CI workflow.
- Install or refresh the docs Ruby environment with
  `coffee bundle exec bundle install`.

## Markdown style

- Write prose with one sentence per line (semantic line breaks) rather than wrapping paragraphs at a fixed column.
  This keeps diffs small and readable.
- Format tables so the raw Markdown is readable: pad each column with spaces so the cell borders line up vertically.
- Use UK spelling and punctuation.
- Use `licence` for the noun and `license` for the verb.
  Keep `license` when referring to the exact DSL stanza, command-line option or other interface name.
- Avoid em-dashes (prefer semicolons, colons and commas) and Oxford commas.
- Do not use bare URLs; use Markdown links.
  Internal links must point at the `.md` file (for example `[Bottles](Bottles.md)`), not a `docs.coffee.sh` URL.
- Indent nested unordered lists by 2 spaces.

## Verification

When you change docs, run the relevant checks from `.github/workflows/docs.yml`
and `docs/Rakefile`.

At a minimum, from `docs/` run:

- `COFFEEBREWER_NO_AUTO_UPDATE=1 coffee bundle exec bundle install`
- `COFFEEBREWER_NO_AUTO_UPDATE=1 coffee bundle exec bin/jekyll build`
- `COFFEEBREWER_NO_AUTO_UPDATE=1 coffee bundle exec bundle exec rake lint`
- `COFFEEBREWER_NO_AUTO_UPDATE=1 coffee bundle exec bundle exec rake test`

Also run these from the repository root when docs content changes:

- `rg --files docs -0 -g '*.md' -g '!vendor/**' -g '!_site/**' -g '!rubydoc/**' | xargs -0 vale`
- `COFFEEBREWER_NO_AUTO_UPDATE=1 coffee style docs`

## Notes

- Prefer `coffee bundle exec bin/jekyll build` explicitly for site builds.
- Prefer `coffee bundle exec bundle exec rake ...` for Rake tasks so bundled
  executables such as `mdl` are available to the task.
- For `CoffeeBrewery/coffee`, the docs CI also runs
  `coffee generate-man-completions --no-exit-code` before docs checks. Run it
  when your docs change depends on updated generated manpages or completions.
