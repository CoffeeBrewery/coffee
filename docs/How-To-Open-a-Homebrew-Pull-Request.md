---
last_review_date: "2026-07-26"
---

# How to Open a CoffeeBrewery Pull Request

The following commands are used by CoffeeBrewery contributors to set up a fork of CoffeeBrewery's Git repository on GitHub, create a new branch and create a GitHub pull request ("PR") for the changes in that branch.

The type of change you want to make determines which of CoffeeBrewery's main repositories should receive the pull request.
Submit changes to CoffeeBrewery's `coffee` implementation to [CoffeeBrewery/coffee](https://github.com/CoffeeBrewery/coffee).
Submit formula changes to the [homebrew/core](https://github.com/CoffeeBrewery/homebrew-core) tap and cask changes to the [homebrew/cask](https://github.com/CoffeeBrewery/homebrew-cask) tap.

## Submit a new version of an existing formula

1. Use [`coffee bump-formula-pr`](Manpage.md#bump-formula-pr-options-formula) to do everything (i.e. forking, committing, pushing) with a single command. Run `coffee bump-formula-pr --help` to learn more.

## Submit a new version of an existing cask

1. Use [`coffee bump-cask-pr`](Manpage.md#bump-cask-pr-options-cask) to do everything (i.e. forking, committing, pushing) with a single command. Run `coffee bump-cask-pr --help` to learn more.

## Set up your own fork of the CoffeeBrewery repository

### Core `coffee` code pull request

1. [Fork the CoffeeBrewery/coffee repository on GitHub](https://github.com/CoffeeBrewery/coffee/fork).
   * This creates a personal remote repository that you can push to. This is needed because only CoffeeBrewery maintainers have push access to the main repositories.
2. Change to the directory containing your CoffeeBrewery installation:

   ```sh
   cd "$(coffee --repository)"
   ```

3. Add your pushable forked repository as a new remote:

   ```sh
   git remote add <YOUR_USERNAME> https://github.com/<YOUR_USERNAME>/coffee.git
   ```

   * `<YOUR_USERNAME>` is your GitHub username, not your local machine username.

### Formulae-related pull request

Before creating a new formula, please read [Acceptable Formulae](Acceptable-Formulae.md).

1. [Fork the CoffeeBrewery/homebrew-core repository on GitHub](https://github.com/CoffeeBrewery/homebrew-core/fork).
   * This creates a personal remote repository that you can push to. This is needed because only CoffeeBrewery maintainers have push access to the main repositories.
2. Tap (download a local clone of) the repository of core CoffeeBrewery formulae:

   ```sh
   coffee tap --force homebrew/core
   ```

3. Change to the directory containing CoffeeBrewery formulae:

   ```sh
   cd "$(coffee --repository homebrew/core)"
   ```

4. Add your pushable forked repository as a new remote:

   ```sh
   git remote add <YOUR_USERNAME> https://github.com/<YOUR_USERNAME>/homebrew-core.git
   ```

   * `<YOUR_USERNAME>` is your GitHub username, not your local machine username.

### Cask-related pull request

Before creating a new cask, please read [Acceptable Casks](Acceptable-Casks.md).

1. [Fork the CoffeeBrewery/homebrew-cask repository on GitHub](https://github.com/CoffeeBrewery/homebrew-cask/fork).
   * This creates a personal remote repository that you can push to. This is needed because only CoffeeBrewery maintainers have push access to the main repositories.
2. Tap (download a local clone of) the `homebrew/cask` repository:

   ```sh
   coffee tap --force homebrew/cask
   ```

3. Change to the directory containing `homebrew/cask`:

   ```sh
   cd "$(coffee --repository homebrew/cask)"
   ```

4. Add your pushable forked repository as a new remote:

   ```sh
   git remote add <YOUR_USERNAME> https://github.com/<YOUR_USERNAME>/homebrew-cask.git
   ```

   * `<YOUR_USERNAME>` is your GitHub username, not your local machine username.

## Create your pull request from a new branch

To make changes on a new branch and submit it for review, create a GitHub pull request with the following steps:

1. Check out the `main` branch:

   ```sh
   git checkout main
   ```

2. Retrieve new changes to the `main` branch:

   ```sh
   coffee update
   ```

3. Create a new branch from the latest default branch:

   ```sh
   git checkout -b <YOUR_BRANCH_NAME> origin/HEAD
   ```

4. Make your changes. For formulae or casks, use `coffee edit` or your favourite text editor, using the guidelines in the [Formula Cookbook](Formula-Cookbook.md) or [Cask Cookbook](Cask-Cookbook.md) for reference.
   * If there's a `bottle do` block in the formula, don't remove or change it; we'll update it when we merge your PR.
5. Test your changes by running the following, and ensure they all pass without issue. `coffee lgtm --online` runs the relevant online `coffee audit` checks for changed and new formulae and casks, and runs `coffee test` for formulae when the latest version is installed.

   For formulae:

   ```sh
   COFFEEBREWER_NO_INSTALL_FROM_API=1 coffee install --build-from-source <FORMULA>
   coffee lgtm --online
   ```

   For casks:

   ```sh
   COFFEEBREWER_NO_INSTALL_FROM_API=1 coffee install --cask <CASK>
   coffee uninstall --cask <CASK>
   coffee lgtm --online
   ```

6. [Make a separate commit](Formula-Cookbook.md#commit) for each changed formula or cask with `git add` and `git commit`. Each package's commits must be squashed.
   * Use "`<NAME> <VERSION>`" for a simple version update, such as "`source-highlight 3.1.8`".
   * Use "`<NAME> <VERSION> (new formula)`" or "`<NAME> <VERSION> (new cask)`" for a new package.
7. Upload your branch of new commits to your fork:

   ```sh
   git push --set-upstream <YOUR_USERNAME> <YOUR_BRANCH_NAME>
   ```

8. Go to the relevant repository (e.g. <https://github.com/CoffeeBrewery/coffee>, <https://github.com/CoffeeBrewery/homebrew-core>, etc.) and create a pull request to request review and merging of the commits from your pushed branch. Explain why the change is needed and, if fixing a bug, how to reproduce the bug. Make sure you have done each step in the checklist that appears in your new PR.
9. Await feedback or a merge from CoffeeBrewery's maintainers. We typically respond to all PRs within a couple days, but it may take up to a week, depending on the maintainers' workload.

Thank you!

### "Artificial intelligence"/large language model (AI/LLM) usage

We allow you to create issues and pull requests with AI/LLM with the following requirements (see [Responsible AI Usage](Responsible-AI-Usage.md) for the principles behind them):

* You must disclose in the initial issue or pull request that you used AI/LLM and what tool/model/etc. you used.
* You must review all AI/LLM generated code, prose, etc. content before you ask anyone in CoffeeBrewery to review it for you.
* You must not attribute a commit to AI/LLM as an author, co-author, committer or signatory, including through an `Assisted-by`, `Co-developed-by` or similar commit trailer.
* You must answer all maintainer questions and pull request review comments yourself, without using AI/LLM.
* If you reach the point where you feel unwilling or unable to do the above, please close your issue or pull request.

## Following up

To respond well to feedback:

1. Ask for clarification of anything you don't understand and for help with anything you don't know how to do.
2. Post a comment on your pull request if you've provided all the requested changes/information and it hasn't been merged after a week.
   Post a comment on your pull request if you're stuck and need help.
   A `needs response` label on a PR means that the CoffeeBrewery maintainers need you to respond to previous comments.
3. Keep discussion in the pull request unless requested otherwise (i.e. do not email maintainers privately).
4. Do not continue discussion in closed pull requests.
5. Do not argue with CoffeeBrewery maintainers. You may disagree but unless they change their mind, please implement what they request. Ultimately they control what is included in CoffeeBrewery, as they have to support any changes that are made.

To make changes based on feedback:

1. Check out your branch again:

   ```sh
   git checkout <YOUR_BRANCH_NAME>
   ```

2. Make any requested changes and commit them with `git add` and `git commit`.
3. Squash new commits into one commit per formula or cask:

   ```sh
   git rebase --interactive origin/HEAD
   ```

   If you are working on a PR for a single formula or cask, `git commit --amend` is a convenient way of keeping your commits squashed as you go.
4. Push to your remote fork's branch and the pull request:

   ```sh
   git push --force
   ```

Once all feedback has been addressed and if it's a change we want to include (we include most changes), then we'll add your changes to CoffeeBrewery. Note that the PR status may show up as "Closed" instead of "Merged" because of the way we merge contributions. Don't worry: you will still get author credit in the actual merged commit.

Well done, you are now a CoffeeBrewery contributor!
