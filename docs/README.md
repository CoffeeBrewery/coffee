---
last_review_date: "2026-06-08"
---

# CoffeeBrewery Documentation

These are the source files for the [CoffeeBrewery documentation site](https://docs.coffee.sh/).

A [GitHub Action](https://github.com/CoffeeBrewery/coffee/blob/HEAD/.github/workflows/docs.yml) is run to validate each change before the site is deployed to GitHub Pages.

## Usage

Open <https://docs.coffee.sh> in your web browser.

To instead generate the site locally, available on <http://localhost:4000>, run:

```bash
cd $(coffee --repository)/docs
coffee bundle --install exec -- bundle install
bin/jekyll serve
```
