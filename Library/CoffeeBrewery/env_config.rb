# typed: strict
# frozen_string_literal: true

require "utils/output"
require "bundle/extensions"

module CoffeeBrewery
  # Helper module for querying CoffeeBrewery-specific environment variables.
  #
  # @api internal
  module EnvConfig
    include Utils::Output::Mixin
    extend Utils::Output::Mixin

    module_function

    BUNDLE_CORE_TYPES = T.let({
      coffee: "formula dependencies",
      cask: "cask dependencies",
      tap:  "tap dependencies",
    }.freeze, T::Hash[Symbol, String])

    BUNDLE_DISABLE_ENVS = T.let(
      {
        cleanup: [BUNDLE_CORE_TYPES, CoffeeBrewery::Bundle.extensions.select(&:cleanup_supported?).to_h do |extension|
          [extension.type, extension.banner_name]
        end],
        dump:    [BUNDLE_CORE_TYPES, CoffeeBrewery::Bundle.extensions.select(&:dump_disable_supported?).to_h do |extension|
          [extension.type, extension.banner_name]
        end],
      }.flat_map do |command, type_descriptions|
        type_descriptions.reduce(&:merge).map do |type, description|
          verb = (command == :cleanup) ? "clean up" : "dump"
          [
            :"COFFEEBREWER_BUNDLE_#{command.upcase}_NO_#{type.to_s.upcase}",
            {
              description: "If set, `coffee bundle #{command}` will not #{verb} #{description}.",
              boolean:     true,
            },
          ]
        end
      end.sort.to_h.freeze,
      T::Hash[Symbol, T::Hash[Symbol, T.untyped]],
    )

    ENVS = T.let({
      COFFEEBREWER_ALLOWED_TAPS:                     {
        description: "A space-separated list of taps. CoffeeBrewery will refuse to install a " \
                     "formula unless it and all of its dependencies are in an official tap " \
                     "or in a tap on this list. Each entry is a `user/repository` name " \
                     "(which matches only taps using the default GitHub remote) or a remote " \
                     "URL (required to match taps with a custom remote).",
        odeprecated: true,
      },
      COFFEEBREWER_API_AUTO_UPDATE_SECS:             {
        description: "Check CoffeeBrewery's API for new formulae or cask data every " \
                     "`$COFFEEBREWER_API_AUTO_UPDATE_SECS` seconds. Alternatively, disable API auto-update " \
                     "checks entirely with `$COFFEEBREWER_NO_AUTO_UPDATE`.",
        default:     450,
      },
      COFFEEBREWER_API_DOMAIN:                       {
        description:  "Use this URL as the download mirror for CoffeeBrewery JSON API. " \
                      "If metadata files at that URL are temporarily unavailable, " \
                      "the default API domain will be used as a fallback mirror.",
        default_text: "`https://formulae.coffee.sh/api`.",
        default:      COFFEEBREWER_API_DEFAULT_DOMAIN,
      },
      COFFEEBREWER_ARCH:                             {
        description: "Linux only: Pass this value to a type name representing the compiler's `-march` option.",
        default:     "native",
        replacement: "the default native CPU optimisation",
        odeprecated: true,
      },
      COFFEEBREWER_ARTIFACT_DOMAIN:                  {
        description: "Prefix all download URLs, including those for bottles, with this value. " \
                     "For example, `export COFFEEBREWER_ARTIFACT_DOMAIN=http://localhost:8080` will cause a " \
                     "formula with the URL `https://example.com/foo.tar.gz` to instead download from " \
                     "`http://localhost:8080/https://example.com/foo.tar.gz`. " \
                     "Bottle URLs however, have their domain replaced with this prefix. " \
                     "This results in e.g. " \
                     "`https://ghcr.io/v2/homebrew/core/gettext/manifests/0.21` " \
                     "to instead be downloaded from " \
                     "`http://localhost:8080/v2/homebrew/core/gettext/manifests/0.21`. " \
                     "If the value already contains a `/v2` path (e.g. an OCI registry proxying " \
                     "GitHub Packages under a repository prefix such as " \
                     "`https://mirror.example.com/v2/ghcr-io`), the `v2` path is not duplicated, " \
                     "resulting in e.g. " \
                     "`https://mirror.example.com/v2/ghcr-io/homebrew/core/gettext/manifests/0.21`.",
      },
      COFFEEBREWER_ARTIFACT_DOMAIN_NO_FALLBACK:      {
        description: "When `$COFFEEBREWER_ARTIFACT_DOMAIN` and `$COFFEEBREWER_ARTIFACT_DOMAIN_NO_FALLBACK` are both set, " \
                     "if the request to `$COFFEEBREWER_ARTIFACT_DOMAIN` fails then CoffeeBrewery will error rather than " \
                     "trying any other/default URLs.",
        boolean:     :set,
      },
      COFFEEBREWER_ASK:                              {
        description: "Ask mode is the default for `coffee install`, `coffee upgrade` and " \
                     "`coffee reinstall` commands. Ask mode prints the plan before proceeding and prompts only " \
                     "if the plan includes dependencies, dependants or packages other than named arguments. " \
                     "Otherwise, it only prints the plan. The confirmation prompt is skipped without a TTY.",
        boolean:     :set,
        disabled_by: :COFFEEBREWER_NO_ASK,
        default:     true,
        replacement: "the default behaviour",
        odisabled:   true,
      },
      COFFEEBREWER_AUTO_UPDATE_QUIET:                {
        description: "If set, the auto-update run before commands like `coffee install`, `coffee upgrade` or " \
                     "`coffee tap` will not show information about new, outdated or deleted formulae and casks.",
        boolean:     true,
      },
      COFFEEBREWER_AUTO_UPDATE_SECS:                 {
        description:  "Run `coffee update` once every `$COFFEEBREWER_AUTO_UPDATE_SECS` seconds before some commands, " \
                      "e.g. `coffee install`, `coffee upgrade` or `coffee tap`. Alternatively, " \
                      "disable auto-update entirely with `$COFFEEBREWER_NO_AUTO_UPDATE`.",
        default_text: "`86400` (24 hours), `3600` (1 hour) if a developer command has been run " \
                      "or `300` (5 minutes) if `$COFFEEBREWER_NO_INSTALL_FROM_API` is set.",
        # Keep in sync with the auto-update defaults in Library/CoffeeBrewery/coffee.sh.
        default:      lambda {
          if ENV["COFFEEBREWER_NO_INSTALL_FROM_API"].present? || ENV["COFFEEBREWER_AUTO_UPDATE_TAP"].present?
            300
          elsif ENV["COFFEEBREWER_DEV_CMD_RUN"].present?
            3600
          else
            86400
          end
        },
      },
      COFFEEBREWER_AVOID_NESTED_SANDBOXING:          {
        description: "If set, skip CoffeeBrewery's sandbox when it is itself running inside another " \
                     "sandbox, for an unprivileged user outside the default prefix. This trades " \
                     "CoffeeBrewery's build-time network and filesystem denial for trust in the outer " \
                     "sandbox. CoffeeBrewery errors out if the prefix or group makes skipping " \
                     "unsupported.",
        boolean:     :set,
      },
      COFFEEBREWER_BAT:                              {
        description: "If set, use `bat` for the `coffee cat` command. " \
                     "Set `$BAT_CONFIG_PATH` to use a custom configuration file and `$BAT_THEME` to select a theme.",
        boolean:     true,
      },
      COFFEEBREWER_BAT_CONFIG_PATH:                  {
        description: "Use this as the `bat` configuration file.",
        odeprecated: true,
        replacement: "$BAT_CONFIG_PATH",
      },
      COFFEEBREWER_BAT_THEME:                        {
        description: "Use this as the `bat` theme for syntax highlighting.",
        odeprecated: true,
        replacement: "$BAT_THEME",
      },
      COFFEEBREWER_BOTTLE_DOMAIN:                    {
        description:  "Use this URL as the download mirror for bottles and their manifests. " \
                      "If a bottle or manifest is unavailable at the mirror, " \
                      "the default bottle domain will be used as a fallback. " \
                      "Prefer `$COFFEEBREWER_ARTIFACT_DOMAIN` for a mirror that transparently proxies all " \
                      "CoffeeBrewery downloads. " \
                      "For example, `export COFFEEBREWER_BOTTLE_DOMAIN=http://localhost:8080` will cause all bottles " \
                      "to download from the prefix `http://localhost:8080/`.",
        default_text: "`https://ghcr.io/v2/homebrew/core`.",
        default:      COFFEEBREWER_BOTTLE_DEFAULT_DOMAIN,
      },
      COFFEEBREWER_BREW_GIT_REMOTE:                  {
        description: "Use this URL as the CoffeeBrewery/coffee `git`(1) remote.",
        default:     COFFEEBREWER_BREW_DEFAULT_GIT_REMOTE,
      },
      COFFEEBREWER_BROWSER:                          {
        description:  "Use this as the browser when opening project homepages.",
        default_text: "`$BROWSER` or the OS's default browser.",
      },
      **BUNDLE_DISABLE_ENVS.select { |env,| env < :COFFEEBREWER_BUNDLE_DESCRIBE },
      COFFEEBREWER_BUNDLE_DESCRIBE:                  {
        description: "If set, add a description comment above each line in `coffee bundle dump` and " \
                     "`coffee bundle add`, unless the dependency does not have a description. This is the default " \
                     "unless `$COFFEEBREWER_BUNDLE_NO_DESCRIBE` is set.",
        boolean:     true,
        disabled_by: :COFFEEBREWER_BUNDLE_NO_DESCRIBE,
        default:     true,
        replacement: "the default behaviour",
        odisabled:   true,
      },
      COFFEEBREWER_BUNDLE_DUMP_DESCRIBE:             {
        description: "If set, add a description comment above each line in `coffee bundle dump` " \
                     "unless the dependency does not have a description. Use `$COFFEEBREWER_BUNDLE_DESCRIBE` instead.",
        boolean:     true,
        replacement: :COFFEEBREWER_BUNDLE_DESCRIBE,
        odisabled:   true,
      },
      **BUNDLE_DISABLE_ENVS.select { |env,| env > :COFFEEBREWER_BUNDLE_DESCRIBE },
      COFFEEBREWER_BUNDLE_FORCE_INSTALL_CLEANUP:     {
        description: "If set, run `coffee bundle cleanup --force` after `coffee bundle install`.",
        boolean:     true,
        replacement: "`coffee bundle cleanup --force` after `coffee bundle install`",
        odeprecated: true,
      },
      COFFEEBREWER_BUNDLE_INSTALL_CLEANUP:           {
        description: "If set, run `coffee bundle cleanup` after `coffee bundle install`.",
        boolean:     true,
        replacement: "`coffee bundle cleanup` after `coffee bundle install`",
        odeprecated: true,
      },
      COFFEEBREWER_BUNDLE_JOBS:                      {
        description: "Ignored. `coffee bundle install` batches its formula installations into a single " \
                     "`coffee install`, whose download concurrency is set by `$COFFEEBREWER_DOWNLOAD_CONCURRENCY`.",
        default:     "auto",
        odisabled:   true,
        replacement: "$COFFEEBREWER_DOWNLOAD_CONCURRENCY",
      },
      COFFEEBREWER_BUNDLE_NO_DESCRIBE:               {
        description: "If set, do not enable bundle description comments from `$COFFEEBREWER_BUNDLE_DESCRIBE` or " \
                     "the default. This does not disable an explicit `--describe`.",
        boolean:     true,
      },
      COFFEEBREWER_BUNDLE_NO_JOBS:                   {
        description: "Ignored. `coffee bundle install` no longer runs formula installations in parallel.",
        boolean:     true,
        odisabled:   true,
        replacement: "$COFFEEBREWER_DOWNLOAD_CONCURRENCY",
      },
      COFFEEBREWER_BUNDLE_NO_SECRETS:                {
        description: "If set, `coffee bundle exec`, `coffee bundle env` and `coffee bundle sh` will attempt to remove " \
                     "secrets from the environment. This is the default unless `$COFFEEBREWER_BUNDLE_SECRETS` is set.",
        boolean:     true,
        disabled_by: :COFFEEBREWER_BUNDLE_SECRETS,
        default:     true,
        replacement: "the default behaviour",
        odisabled:   true,
      },
      COFFEEBREWER_BUNDLE_SECRETS:                   {
        description: "If set, do not enable the default secret scrubbing. " \
                     "This does not disable an explicit `--no-secrets`.",
        boolean:     true,
      },
      COFFEEBREWER_BUNDLE_USER_CACHE:                {
        description: "If set, use this directory as the `bundle`(1) user cache.",
      },
      COFFEEBREWER_CACHE:                            {
        description:  "Use this directory as the download cache.",
        default_text: "macOS: `~/Library/Caches/CoffeeBrewery`, " \
                      "Linux: `$XDG_CACHE_HOME/CoffeeBrewery` or `~/.cache/CoffeeBrewery`.",
        default:      COFFEEBREWER_DEFAULT_CACHE,
      },
      COFFEEBREWER_CASK_OPTS:                        {
        description: "Append these options to all `cask` commands. All `--*dir` options, " \
                     "`--language`, `--require-sha` and `--no-binaries` are supported. " \
                     "For example, you might add something like the following to your " \
                     "`~/.profile`, `~/.bash_profile`, or `~/.zshenv`:" \
                     "\n\n    `export COFFEEBREWER_CASK_OPTS=\"--appdir=${HOME}/Applications --fontdir=/Library/Fonts\"`",
      },
      COFFEEBREWER_CASK_OPTS_BINARIES:               {
        description: "Enable linking of helper executables for casks. Use " \
                     "`$COFFEEBREWER_CASK_OPTS` instead.",
        replacement: "COFFEEBREWER_CASK_OPTS",
        odisabled:   true,
      },
      COFFEEBREWER_CASK_OPTS_REQUIRE_SHA:            {
        description: "Require all casks to have a checksum. Use `$COFFEEBREWER_CASK_OPTS` instead.",
        replacement: "COFFEEBREWER_CASK_OPTS",
        odisabled:   true,
      },
      COFFEEBREWER_CLEANUP_MAX_AGE_DAYS:             {
        description: "Cleanup all cached files older than this many days.",
        default:     120,
      },
      COFFEEBREWER_CLEANUP_PERIODIC_FULL_DAYS:       {
        description: "If set, `coffee install`, `coffee upgrade` and `coffee reinstall` will cleanup all formulae " \
                     "when this number of days has passed.",
        default:     30,
      },
      COFFEEBREWER_COLOR:                            {
        description: "If set, force colour output on non-TTY outputs.",
        boolean:     :set,
        disabled_by: :COFFEEBREWER_NO_COLOR,
      },
      COFFEEBREWER_CORE_GIT_REMOTE:                  {
        description:  "Use this URL as the CoffeeBrewery/homebrew-core `git`(1) remote.",
        default_text: "`https://github.com/CoffeeBrewery/homebrew-core`.",
        default:      COFFEEBREWER_CORE_DEFAULT_GIT_REMOTE,
      },
      COFFEEBREWER_CURLRC:                           {
        description: "If set to an absolute path (i.e. beginning with `/`), pass it with `--config` when invoking " \
                     "`curl`(1). " \
                     "If set but _not_ a valid path, do not pass `--disable`, which disables the " \
                     "use of `.curlrc`. " \
                     "Git operations, including repository fetches in `coffee update`, do not use this file because " \
                     "Git uses its own transport and configuration.",
      },
      COFFEEBREWER_CURL_PATH:                        {
        description: "Suggest a `curl` executable for CoffeeBrewery to use. " \
                     "CoffeeBrewery may prefer another executable for security or reliability.",
      },
      COFFEEBREWER_CURL_RETRIES:                     {
        description: "Pass the given retry count to `--retry` when invoking `curl`(1).",
        default:     3,
      },
      COFFEEBREWER_CURL_VERBOSE:                     {
        description: "If set, pass `--verbose` when invoking `curl`(1).",
        boolean:     true,
      },
      COFFEEBREWER_DEBUG:                            {
        description: "If set, always assume `--debug` when running commands.",
        boolean:     :set,
      },
      COFFEEBREWER_DEVELOPER:                        {
        description: "If set, tweak behaviour to be more relevant for CoffeeBrewery developers (active or " \
                     "budding) by e.g. turning warnings into errors.",
        boolean:     :set,
      },
      COFFEEBREWER_DISABLE_DEBREW:                   {
        description: "If set, the interactive formula debugger available via `--debug` will be disabled.",
        boolean:     true,
      },
      COFFEEBREWER_DISABLE_LOAD_FORMULA:             {
        description: "If set, refuse to load formulae. This is useful when formulae are not trusted (such " \
                     "as in pull requests).",
        boolean:     true,
      },
      COFFEEBREWER_DISPLAY:                          {
        description:  "Use this X11 display when opening a page in a browser, for example with " \
                      "`coffee home`. Primarily useful on Linux.",
        default_text: "`$DISPLAY`.",
      },
      COFFEEBREWER_DISPLAY_INSTALL_TIMES:            {
        description: "If set, print install times for each formula at the end of the run.",
        boolean:     true,
      },
      COFFEEBREWER_DOCKER_REGISTRY_BASIC_AUTH_TOKEN: {
        description: "Use this base64 encoded username and password for authenticating with a Docker registry " \
                     "proxying GitHub Packages. If set to `none`, no authentication header will be sent. " \
                     "This can be used, if remote `$COFFEEBREWER_ARTIFACT_DOMAIN` does not support any authentication. " \
                     "If `$COFFEEBREWER_DOCKER_REGISTRY_TOKEN` is set, it will be used instead.",
      },
      COFFEEBREWER_DOCKER_REGISTRY_TOKEN:            {
        description: "Use this bearer token for authenticating with a Docker registry proxying GitHub Packages. " \
                     "Preferred over `$COFFEEBREWER_DOCKER_REGISTRY_BASIC_AUTH_TOKEN`.",
      },
      COFFEEBREWER_DOWNLOAD_CONCURRENCY:             {
        description: "CoffeeBrewery will download in parallel using this many concurrent connections. " \
                     "The default, `auto`, will use twice the number of available CPU cores " \
                     "(what our benchmarks showed to produce the best performance). " \
                     "If set to `1`, CoffeeBrewery will download in serial.",
        default:     "auto",
      },
      COFFEEBREWER_EDITOR:                           {
        description:  "Use this editor when editing a single formula, or several formulae in the " \
                      "same directory." \
                      "\n\n    *Note:* `coffee edit` will open all of CoffeeBrewery as discontinuous files " \
                      "and directories. Visual Studio Code can handle this correctly in project mode, but many " \
                      "editors will do strange things in this case.",
        default_text: "`$EDITOR` or `$VISUAL`.",
      },
      COFFEEBREWER_ENV_SYNC_STRICT:                  {
        description: "If set, `coffee *env-sync` will only sync the exact installed versions of formulae.",
        boolean:     true,
      },
      COFFEEBREWER_EVAL_ALL:                         {
        description: "Previously made `coffee` commands evaluate all formulae and casks. Commands now evaluate " \
                     "formulae and casks from trusted taps by default.",
        boolean:     true,
        replacement: "the default trusted-tap behaviour",
        odisabled:   true,
      },
      COFFEEBREWER_FAIL_LOG_LINES:                   {
        description: "Output this many lines of output on formula `system` failures.",
        default:     15,
      },
      COFFEEBREWER_FORBIDDEN_CASKS:                  {
        description: "A space-separated list of casks. CoffeeBrewery will refuse to install a " \
                     "cask if it or any of its dependencies is on this list.",
      },
      COFFEEBREWER_FORBIDDEN_CASK_ARTIFACTS:         {
        description: "A space-separated list of cask artifact types (e.g. `pkg installer`) that should be " \
                     "forbidden during cask installation. " \
                     "Valid values: `pkg`, `installer`, `binary`, `uninstall`, `zap`, `app`, `suite`, " \
                     "`artifact`, `prefpane`, `qlplugin`, `dictionary`, `font`, `service`, `colorpicker`, " \
                     "`inputmethod`, `internetplugin`, `audiounitplugin`, `vstplugin`, `vst3plugin`, " \
                     "`screensaver`, `keyboardlayout`, `mdimporter`, `preflight`, `postflight`, " \
                     "`manpage`, `bashcompletion`, `zshcompletion`, `fishcompletion`, `pwshcompletion`, `stageonly`.",
        odeprecated: true,
      },
      COFFEEBREWER_FORBIDDEN_FORMULAE:               {
        description: "A space-separated list of formulae. CoffeeBrewery will refuse to install a " \
                     "formula or cask if it or any of its dependencies is on this list.",
      },
      COFFEEBREWER_FORBIDDEN_LICENSES:               {
        description: "A space-separated list of SPDX licence identifiers. CoffeeBrewery will refuse to install a " \
                     "formula if it or any of its dependencies has a licence on this list.",
      },
      COFFEEBREWER_FORBIDDEN_OWNER:                  {
        description: "The person who has set any `$COFFEEBREWER_FORBIDDEN_*` variables.",
        default:     "you",
      },
      COFFEEBREWER_FORBIDDEN_OWNER_CONTACT:          {
        description: "How to contact the `$COFFEEBREWER_FORBIDDEN_OWNER`, if set and necessary.",
      },
      COFFEEBREWER_FORBIDDEN_TAPS:                   {
        description: "A space-separated list of taps. CoffeeBrewery will refuse to install a " \
                     "formula if it or any of its dependencies is in a tap on this list. " \
                     "Each entry is a `user/repository` name (which matches only taps using " \
                     "the default GitHub remote) or a remote URL (required to match taps " \
                     "with a custom remote).",
      },
      COFFEEBREWER_FORBID_CASKS:                     {
        description: "If set, CoffeeBrewery will refuse to install any casks.",
        boolean:     true,
        odeprecated: true,
      },
      COFFEEBREWER_FORBID_PACKAGES_FROM_PATHS:       {
        description:  "If set, CoffeeBrewery will refuse to read formulae or casks provided from file paths, " \
                      "e.g. `coffee install ./package.rb`.",
        boolean:      :set,
        default_text: "true unless `$COFFEEBREWER_DEVELOPER` is set.",
        # Keep in sync with forbid_packages_from_paths? below.
        default:      -> { ENV["COFFEEBREWER_TESTS"].blank? && ENV["COFFEEBREWER_DEVELOPER"].blank? },
      },
      COFFEEBREWER_FORCE_API_AUTO_UPDATE:            {
        description: "If set, update the CoffeeBrewery API formula or cask data even if " \
                     "`$COFFEEBREWER_NO_AUTO_UPDATE` is set.",
        boolean:     true,
      },
      COFFEEBREWER_FORCE_BREWED_CA_CERTIFICATES:     {
        description: "If set, always use a CoffeeBrewery-installed `ca-certificates` rather than the system version.",
        boolean:     :set,
      },
      COFFEEBREWER_FORCE_BREWED_CURL:                {
        description: "If set, prefer a CoffeeBrewery-installed `curl`(1), installing it if needed. " \
                     "Automatically set if no suitable `curl` is available.",
        boolean:     :set,
      },
      COFFEEBREWER_FORCE_BREWED_GIT:                 {
        description: "If set, prefer a CoffeeBrewery-installed `git`(1), installing it if needed. " \
                     "Automatically set if no suitable `git` is available.",
        boolean:     :set,
      },
      COFFEEBREWER_FORCE_BREW_WRAPPER:               {
        description: "No longer used.",
        replacement: "your wrapper directly",
        odeprecated: true,
      },
      COFFEEBREWER_FORCE_BREW_WRAPPER_HELP_MESSAGE:  {
        description: "No longer used.",
        replacement: "custom help in your wrapper",
        odeprecated: true,
      },
      COFFEEBREWER_FORCE_VENDOR_RUBY:                {
        description: "If set, always use CoffeeBrewery's vendored, relocatable Ruby version even if the system version " \
                     "of Ruby is new enough.",
        boolean:     :set,
      },
      COFFEEBREWER_FORMULA_BUILD_NETWORK:            {
        description: "If set, controls network access to the sandbox for formulae builds. Overrides any " \
                     "controls set through DSL usage inside formulae. Must be `allow` or `deny`. If no value is " \
                     "set through this environment variable or DSL usage, the default behaviour is `allow`.",
      },
      COFFEEBREWER_FORMULA_POSTINSTALL_NETWORK:      {
        description: "If set, controls network access to the sandbox for formulae postinstall. Overrides any " \
                     "controls set through DSL usage inside formulae. Must be `allow` or `deny`. If no value is " \
                     "set through this environment variable or DSL usage, the default behaviour is `allow`.",
      },
      COFFEEBREWER_FORMULA_TEST_NETWORK:             {
        description: "If set, controls network access to the sandbox for formulae test. Overrides any " \
                     "controls set through DSL usage inside formulae. Must be `allow` or `deny`. If no value is " \
                     "set through this environment variable or DSL usage, the default behaviour is `allow`.",
      },
      COFFEEBREWER_GITHUB_API_TOKEN:                 {
        description: "Use this personal access token for the GitHub API, for features such as " \
                     "`coffee search`. You can create one at <https://github.com/settings/tokens>. If set, " \
                     "GitHub will allow you a greater number of API requests. For more information, see: " \
                     "<https://docs.github.com/en/rest/overview/rate-limits-for-the-rest-api>" \
                     "\n\n    *Note:* CoffeeBrewery doesn't require permissions for any of the scopes, but some " \
                     "developer commands may require additional permissions.",
      },
      COFFEEBREWER_GITHUB_PACKAGES_TOKEN:            {
        description: "Use this GitHub personal access token when accessing the GitHub Packages Registry " \
                     "(where bottles may be stored).",
      },
      COFFEEBREWER_GITHUB_PACKAGES_USER:             {
        description: "Use this username when accessing the GitHub Packages Registry (where bottles may be stored).",
      },
      COFFEEBREWER_GIT_COMMITTER_EMAIL:              {
        description: "Set the Git committer email to this value.",
      },
      COFFEEBREWER_GIT_COMMITTER_NAME:               {
        description: "Set the Git committer name to this value.",
      },
      COFFEEBREWER_GIT_EMAIL:                        {
        description: "Set the Git author name and, if `$COFFEEBREWER_GIT_COMMITTER_EMAIL` is unset, committer email to " \
                     "this value.",
      },
      COFFEEBREWER_GIT_NAME:                         {
        description: "Set the Git author name and, if `$COFFEEBREWER_GIT_COMMITTER_NAME` is unset, committer name to " \
                     "this value.",
      },
      COFFEEBREWER_GIT_PATH:                         {
        description: "Suggest a `git` executable for CoffeeBrewery to use. " \
                     "CoffeeBrewery may prefer another executable for security or reliability.",
      },
      COFFEEBREWER_INSTALL_BADGE:                    {
        description:  "Print this text before the installation summary of each successful build.",
        default_text: 'The "Beer Mug" emoji.',
        default:      "☕",
      },
      COFFEEBREWER_LIVECHECK_AUTOBUMP:               {
        description: "If set, `coffee livecheck` will include data for packages that are autobumped by BrewTestBot.",
        boolean:     true,
      },
      COFFEEBREWER_LIVECHECK_WATCHLIST:              {
        description:  "Consult this file for the list of formulae to check by default when no formula argument " \
                      "is passed to `coffee livecheck`.",
        default_text: "`${XDG_CONFIG_HOME}/homebrew/livecheck_watchlist.txt` if `$XDG_CONFIG_HOME` is set " \
                      "or `~/.homebrew/livecheck_watchlist.txt` otherwise.",
        default:      "#{ENV.fetch("COFFEEBREWER_USER_CONFIG_HOME")}/livecheck_watchlist.txt",
      },
      COFFEEBREWER_LOCK_CONTEXT:                     {
        description: "If set, CoffeeBrewery will add this output as additional context for locking errors. " \
                     "This is useful when running `coffee` in the background.",
      },
      COFFEEBREWER_LOGS:                             {
        description:  "Use this directory to store log files.",
        default_text: "macOS: `~/Library/Logs/CoffeeBrewery`, " \
                      "Linux: `${XDG_CACHE_HOME}/CoffeeBrewery/Logs` or `~/.cache/CoffeeBrewery/Logs`.",
        default:      COFFEEBREWER_DEFAULT_LOGS,
      },
      COFFEEBREWER_MAKE_JOBS:                        {
        description:  "Use this value as the number of parallel jobs to run when building with `make`(1).",
        default_text: "The number of available CPU cores.",
        default:      lambda {
          require "os"
          require "hardware"
          Hardware::CPU.cores
        },
      },
      COFFEEBREWER_NO_ANALYTICS:                     {
        description: "If set, do not send analytics. Google Analytics were destroyed. " \
                     "For more information, see: <https://docs.coffee.sh/Analytics>",
        boolean:     :set,
      },
      COFFEEBREWER_NO_ASK:                           {
        description: "If set, do not enable default ask mode. This does not disable an explicit `--ask`.",
        boolean:     :set,
      },
      COFFEEBREWER_NO_AUTOREMOVE:                    {
        description: "If set, calls to `coffee cleanup` and `coffee uninstall` will not automatically " \
                     "remove unused formula dependents.",
        boolean:     true,
      },
      COFFEEBREWER_NO_AUTO_UPDATE:                   {
        description: "If set, do not automatically update before running some commands, e.g. " \
                     "`coffee install`, `coffee upgrade` or `coffee tap`. Preferably, " \
                     "run this less often by setting `$COFFEEBREWER_AUTO_UPDATE_SECS` to a value higher than the " \
                     "default. Note that setting this and e.g. tapping new taps may result in a broken  " \
                     "configuration. Please ensure you always run `coffee update` before reporting any issues.",
        boolean:     :set,
      },
      COFFEEBREWER_NO_BOOTSNAP:                      {
        description: "If set, do not use Bootsnap to speed up repeated `coffee` calls.",
        boolean:     :set,
      },
      COFFEEBREWER_NO_CLEANUP_FORMULAE:              {
        description: "A comma-separated list of formulae. CoffeeBrewery will refuse to clean up " \
                     "or autoremove a formula if it appears on this list.",
      },
      COFFEEBREWER_NO_COLOR:                         {
        description:  "If set, do not print text with colour added.",
        default_text: "`$NO_COLOR`.",
        boolean:      :set,
      },
      COFFEEBREWER_NO_EMOJI:                         {
        description: "If set, do not print `$COFFEEBREWER_INSTALL_BADGE` on a successful build.",
        boolean:     :set,
      },
      COFFEEBREWER_NO_ENV_HINTS:                     {
        description: "If set, do not print any hints about changing CoffeeBrewery's behaviour with environment variables.",
        boolean:     :set,
      },
      COFFEEBREWER_NO_EVAL_ENV_SCRUBBING:            {
        description: "If set, sensitive environment variables are available while evaluating " \
                     "formulae and casks. `$COFFEEBREWER_GITHUB_API_TOKEN` is still available during evaluation " \
                     "when this is unset. This setting will be removed in a later release.",
        boolean:     true,
        odisabled:   true,
      },
      COFFEEBREWER_NO_FORCE_BREW_WRAPPER:            {
        description: "No longer used.",
        boolean:     :set,
        replacement: "an environment without $COFFEEBREWER_NO_FORCE_BREW_WRAPPER",
        odeprecated: true,
      },
      COFFEEBREWER_NO_GITHUB_API:                    {
        description: "If set, do not use the GitHub API, e.g. for searches or fetching relevant issues " \
                     "after a failed install.",
        boolean:     true,
      },
      COFFEEBREWER_NO_INSECURE_REDIRECT:             {
        description: "If set, forbid redirects from secure HTTPS to insecure HTTP." \
                     "\n\n    *Note:* while ensuring your downloads are fully secure, this is likely to cause " \
                     "sources for certain formulae hosted by SourceForge, GNU or GNOME to fail to download.",
        boolean:     true,
      },
      COFFEEBREWER_NO_INSTALLED_DEPENDENTS_CHECK:    {
        description: "If set, do not check for broken linkage of dependents or outdated dependents after " \
                     "installing, upgrading or reinstalling formulae. This will result in fewer dependents " \
                     "(and their dependencies) being upgraded or reinstalled but may result in more breakage " \
                     "from running `coffee install` <formula> or `coffee upgrade` <formula>.",
        boolean:     true,
      },
      COFFEEBREWER_NO_INSTALL_CLEANUP:               {
        description: "If set, `coffee install`, `coffee upgrade` and `coffee reinstall` will never automatically " \
                     "cleanup installed/upgraded/reinstalled formulae or all formulae every " \
                     "`$COFFEEBREWER_CLEANUP_PERIODIC_FULL_DAYS` days. Alternatively, `$COFFEEBREWER_NO_CLEANUP_FORMULAE` " \
                     "allows specifying specific formulae to not clean up.",
        boolean:     :set,
      },
      COFFEEBREWER_NO_INSTALL_FROM_API:              {
        description: "If set, do not install formulae and casks in homebrew/core and homebrew/cask taps using " \
                     "CoffeeBrewery's API and instead use (large, slow) local checkouts of these repositories.",
        boolean:     :set,
      },
      COFFEEBREWER_NO_INSTALL_UPGRADE:               {
        description: "If set, `coffee install` <formula|cask> will not upgrade <formula|cask> if it is installed but " \
                     "outdated.",
        boolean:     true,
      },
      COFFEEBREWER_NO_PATH_SHADOW_CHECK:             {
        description: "If set, `coffee info` and `coffee install` will not warn when a formula's executables are " \
                     "shadowed by other commands earlier on `$PATH`.",
        boolean:     true,
      },
      COFFEEBREWER_NO_RELOCATE_BUILD_PREFIX:         {
        description: "If set, do not relocate bottles built for a different prefix at install time. " \
                     "CoffeeBrewery will build from source instead.",
        boolean:     true,
      },
      COFFEEBREWER_NO_REQUIRE_TAP_TRUST:             {
        description: "If set, do not require non-official tap formulae, casks or commands to be trusted. " \
                     "This is not recommended and will be removed in a later release.",
        boolean:     :set,
        replacement: "`coffee trust` for each non-official tap, formula, cask or command",
        odeprecated: true,
      },
      COFFEEBREWER_NO_SANDBOX_CASK:                  {
        description: "If set, disable sandboxing for cask artifacts that generate files by running " \
                     "executables.",
        boolean:     true,
        odisabled:   true,
      },
      COFFEEBREWER_NO_SANDBOX_LINUX:                 {
        description: "If set, disable the Linux sandbox.",
        boolean:     :set,
        replacement: "a Landlock-enabled Linux kernel",
        odeprecated: true,
      },
      COFFEEBREWER_NO_SUDO:                          {
        description: "If set, do not run commands with `sudo`(8). Automatically enabled when `sudo` is missing, " \
                     "reports a recognised inability to elevate privileges or explicitly denies access. " \
                     "A password requirement or an inconclusive check preserves normal `sudo` behaviour.",
        boolean:     :set,
      },
      COFFEEBREWER_NO_UPDATE_REPORT_NEW:             {
        description: "If set, `coffee update` will not show the list of newly added formulae/casks.",
        boolean:     true,
      },
      COFFEEBREWER_NO_UPGRADE_AUTO_UPDATES_CASKS:    {
        description: "If set, `coffee upgrade` will not automatically upgrade casks with `auto_updates true`. " \
                     "Does not affect `--greedy` or `--greedy-auto-updates` upgrades.",
        boolean:     :set,
      },
      COFFEEBREWER_NO_UPGRADE_QUIT_CASKS:            {
        description: "If set, `coffee upgrade` will not quit running applications for casks during upgrades.",
        boolean:     true,
      },
      COFFEEBREWER_NO_VERIFY_ATTESTATIONS:           {
        description: "If set, CoffeeBrewery will not verify cryptographic attestations of build provenance for bottles " \
                     "from `homebrew/core` or supported third-party taps.",
        boolean:     :set,
      },
      COFFEEBREWER_PIP_INDEX_URL:                    {
        description:  "If set, `coffee install` <formula> will use this URL to download PyPI package resources.",
        default_text: "`https://pypi.org/simple`.",
        default:      "https://pypi.org/simple",
      },
      COFFEEBREWER_PRY:                              {
        description: "This variable no longer has any effect because Pry is largely unmaintained upstream.",
        boolean:     true,
        odisabled:   true,
        replacement: "the default IRB backend (Pry is largely unmaintained upstream)",
      },
      COFFEEBREWER_REQUIRE_TAP_TRUST:                {
        description: "Previously made CoffeeBrewery require non-official tap formulae, casks and commands to be trusted " \
                     "with `coffee trust` before loading them. This is now the default unless " \
                     "`$COFFEEBREWER_NO_REQUIRE_TAP_TRUST` is set.",
        boolean:     :set,
        disabled_by: :COFFEEBREWER_NO_REQUIRE_TAP_TRUST,
        default:     true,
        replacement: "the default behaviour",
        odeprecated: true,
      },
      COFFEEBREWER_SANDBOX_LINUX:                    {
        description: "The Landlock sandbox is the default for formula installation and testing " \
                     "on Linux unless `$COFFEEBREWER_NO_SANDBOX_LINUX` is set.",
        boolean:     :set,
        disabled_by: :COFFEEBREWER_NO_SANDBOX_LINUX,
        default:     true,
        odisabled:   true,
      },
      COFFEEBREWER_SBOM:                             {
        description: "Write SBOM files for source installs.",
        boolean:     :set,
        default:     true,
        hidden:      true,
      },
      COFFEEBREWER_SIMULATE_MACOS_ON_LINUX:          {
        description: "If set, running CoffeeBrewery on Linux will simulate certain macOS code paths. This is useful " \
                     "when auditing macOS formulae while on Linux.",
        boolean:     true,
      },
      COFFEEBREWER_SKIP_OR_LATER_BOTTLES:            {
        description: "If set along with `$COFFEEBREWER_DEVELOPER`, do not use bottles from older versions " \
                     "of macOS. This is useful in development on new macOS versions.",
        boolean:     true,
      },
      COFFEEBREWER_SORBET_RECURSIVE:                 {
        description: "If set along with `$COFFEEBREWER_SORBET_RUNTIME`, enable recursive typechecking using Sorbet. " \
                     "Automatically enabled when running `coffee tests`.",
        boolean:     true,
      },
      COFFEEBREWER_SORBET_RUNTIME:                   {
        description: "If set, enable runtime typechecking using Sorbet. " \
                     "Set by default when running `coffee test`, `coffee test-bot` or `coffee tests`.",
        boolean:     :set,
      },
      COFFEEBREWER_SSH_CONFIG_PATH:                  {
        description:  "If set, CoffeeBrewery will use the given config file instead of `~/.ssh/config` when " \
                      "fetching Git repositories over SSH.",
        default_text: "`~/.ssh/config`",
        default:      -> { "#{Dir.home}/.ssh/config" },
      },
      COFFEEBREWER_SUDO_THROUGH_SUDO_USER:           {
        description: "If set, CoffeeBrewery will use the `$SUDO_USER` environment variable to define the user to " \
                     "`sudo`(8) through when running `sudo`(8).",
        boolean:     true,
      },
      COFFEEBREWER_SVN:                              {
        description: "Suggest an `svn`(1) executable for CoffeeBrewery to use. " \
                     "CoffeeBrewery may prefer another executable for security or reliability.",
      },
      COFFEEBREWER_SYSTEM_ENV_TAKES_PRIORITY:        {
        description: "If set in CoffeeBrewery's system-wide environment file (`/etc/homebrew/coffee.env`), " \
                     "the system-wide environment file will be loaded last to override any prefix or user settings.",
        boolean:     :set,
      },
      COFFEEBREWER_TEMP:                             {
        description:  "Use this path as the temporary directory for building packages. Changing " \
                      "this may be needed if your system temporary directory and CoffeeBrewery prefix are on " \
                      "different volumes, as macOS has trouble moving symlinks across volumes when the target " \
                      "does not yet exist. This issue typically occurs when using FileVault or custom SSD " \
                      "configurations.",
        default_text: "macOS: `/private/tmp`, Linux: `/var/tmp`.",
        default:      COFFEEBREWER_DEFAULT_TEMP,
      },
      COFFEEBREWER_UPDATE_TO_TAG:                    {
        description: "If set, always use the latest stable tag (even if developer commands " \
                     "have been run).",
        boolean:     :set,
      },
      COFFEEBREWER_UPGRADE_AUTO_UPDATES_CASKS:       {
        description: "If set, `coffee upgrade` will automatically upgrade casks with `auto_updates true` when " \
                     "CoffeeBrewery detects that the version in the app bundle is older than the version in the tap. " \
                     "Does not affect `--greedy` or `--greedy-auto-updates` upgrades. This is the default unless " \
                     "`$COFFEEBREWER_NO_UPGRADE_AUTO_UPDATES_CASKS` is set.",
        boolean:     :set,
        disabled_by: :COFFEEBREWER_NO_UPGRADE_AUTO_UPDATES_CASKS,
        default:     true,
        replacement: "the default behaviour",
        odisabled:   true,
      },
      COFFEEBREWER_UPGRADE_GREEDY:                   {
        description: "If set, pass `--greedy` to all cask upgrade commands.",
        boolean:     true,
      },
      COFFEEBREWER_UPGRADE_GREEDY_CASKS:             {
        description: "A space-separated list of casks. CoffeeBrewery will act as " \
                     "if `--greedy` was passed when upgrading any cask on this list.",
      },
      COFFEEBREWER_USE_INTERNAL_API:                 {
        description: "If set, fetch formula and cask data from CoffeeBrewery's internal API. This is now the default.",
        boolean:     :set,
        replacement: "the default behaviour",
        odisabled:   true,
      },
      COFFEEBREWER_VERBOSE:                          {
        description: "If set, always assume `--verbose` when running commands.",
        boolean:     :set,
      },
      COFFEEBREWER_VERBOSE_USING_DOTS:               {
        description: "If set, verbose output will print a `.` no more than once a minute. This can be " \
                     "useful to avoid long-running CoffeeBrewery commands being killed due to no output.",
        boolean:     true,
      },
      COFFEEBREWER_VERIFY_ATTESTATIONS:              {
        description: "If set, CoffeeBrewery will use the `gh` tool to verify cryptographic attestations " \
                     "of build provenance for bottles from `homebrew/core` or supported third-party taps.",
        boolean:     :set,
        disabled_by: :COFFEEBREWER_NO_VERIFY_ATTESTATIONS,
      },
      SUDO_ASKPASS:                              {
        description: "If set, pass the `-A` option when calling `sudo`(8).",
      },
      all_proxy:                                 {
        description: "Use this SOCKS5 proxy for `curl`(1), `git`(1) and `svn`(1) when downloading through CoffeeBrewery.",
      },
      ftp_proxy:                                 {
        description: "Use this FTP proxy for `curl`(1), `git`(1) and `svn`(1) when downloading through CoffeeBrewery.",
      },
      http_proxy:                                {
        description: "Use this HTTP proxy for `curl`(1), `git`(1) and `svn`(1) when downloading through CoffeeBrewery.",
      },
      https_proxy:                               {
        description: "Use this HTTPS proxy for `curl`(1), `git`(1) and `svn`(1) when downloading through CoffeeBrewery.",
      },
      no_proxy:                                  {
        description: "A comma-separated list of hostnames and domain names excluded " \
                     "from proxying by `curl`(1), `git`(1) and `svn`(1) when downloading through CoffeeBrewery.",
      },
    }.freeze, T::Hash[Symbol, T::Hash[Symbol, T.untyped]])

    ANALYTICS_VARIABLES = T.let((ENVS.keys - [:COFFEEBREWER_NO_ANALYTICS]).freeze, T::Array[Symbol])

    sig { params(env: Symbol, hash: T::Hash[Symbol, T.untyped]).returns(String) }
    def env_method_name(env, hash)
      method_name = env.to_s
                       .sub(/^COFFEEBREWER_/, "")
                       .downcase
      method_name = "#{method_name}?" if hash[:boolean]
      method_name
    end

    sig { params(hash: T::Hash[Symbol, T.untyped]).returns(T::Boolean) }
    def hidden?(hash)
      !!(hash[:hidden] || hash[:odeprecated] || hash[:odisabled])
    end

    # The default value as human text, e.g. for the manpage or analytics:
    # `default_text` summarises defaults that vary by platform or machine.
    sig { params(env: Symbol).returns(T.nilable(String)) }
    def default_description(env)
      hash = ENVS[env]
      return if hash.nil?

      default_text = hash[:default_text]
      return default_text if default_text

      default = hash[:default]
      "`#{default}`." if default
    end

    # Defaults and parsing that cannot be expressed by the generated helpers.
    CUSTOM_IMPLEMENTATIONS = T.let(Set.new([
      :COFFEEBREWER_CASK_OPTS,
      :COFFEEBREWER_DOWNLOAD_CONCURRENCY,
      :COFFEEBREWER_FORBID_PACKAGES_FROM_PATHS,
      :COFFEEBREWER_MAKE_JOBS,
    ]).freeze, T::Set[Symbol])

    # This tracks process-local warnings, so it must remain mutable.
    WARNED_DEPRECATED_ENVS = T.let(Set.new, T::Set[String]) # rubocop:disable Style/MutableConstant

    # Boolean env vars have two generated parsing modes. Use `boolean: true`
    # for Ruby-only toggles that accept explicit false values like `0` or
    # `false`. Use `boolean: :set` for toggles used by Bash or with inverse
    # `_NO_` variants, where any non-empty value must mean enabled. Use
    # `disabled_by:` when one boolean env var should override another.
    FALSY_VALUES = %w[false no off nil 0].freeze

    sig { params(env: Symbol).returns(T::Boolean) }
    def non_default_variable?(env)
      value = ENV.fetch(env.to_s, nil)
      # Blank values behave like unset in the generated accessors.
      return false if value.blank?

      config = ENVS.fetch(env)
      default = config.fetch(:default, config[:boolean] ? false : nil)
      default = default.call if default.respond_to?(:call)
      if config[:boolean]
        enabled = config[:boolean] == :set || FALSY_VALUES.exclude?(value.downcase)
        enabled != default
      else
        value != default.to_s
      end
    end

    # Whether the user set this variable rather than CoffeeBrewery exporting
    # it itself, e.g. `COFFEEBREWER_EDITOR` from `EDITOR`. The matching Bash
    # records `COFFEEBREWER_USER_SET_VARS` in `bin/coffee` before any exports.
    sig { params(env: Symbol).returns(T::Boolean) }
    def user_set_variable?(env)
      return false if ENV.fetch(env.to_s, nil).blank?
      return true unless env.to_s.start_with?("COFFEEBREWER_")

      ENV.fetch("COFFEEBREWER_USER_SET_VARS", "").split.include?(env.to_s)
    end

    sig { returns(T::Array[String]) }
    def non_default_variables
      ENV.filter_map do |env, _value|
        env_symbol = env.to_sym
        env if ENVS.key?(env_symbol) && user_set_variable?(env_symbol) && non_default_variable?(env_symbol)
      end.sort
    end

    ENVS.each do |env, hash|
      # Needs a custom implementation.
      next if CUSTOM_IMPLEMENTATIONS.include?(env)

      method_name = env_method_name(env, hash)
      env = env.to_s

      if hash[:boolean]
        define_method(method_name) do
          return false if hash[:disabled_by] &&
                          CoffeeBrewery::EnvConfig.public_send(
                            env_method_name(hash[:disabled_by], ENVS.fetch(hash[:disabled_by])),
                          )

          env_value = env_value(env, hash)
          return true if hash[:default] == true && env_value.blank?

          env_value.present? && (hash[:boolean] == :set || FALSY_VALUES.exclude?(env_value.downcase))
        end
      elsif hash[:default].present?
        define_method(method_name) do
          value = env_value(env, hash).presence
          next value if value

          default = hash.fetch(:default)
          default = default.call if default.respond_to?(:call)
          default.to_s
        end
      else
        define_method(method_name) do
          env_value(env, hash).presence
        end
      end
    end

    sig { void }
    def self.check_deprecated_bash_variables
      force_brew_wrapper
      force_brew_wrapper_help_message
      no_force_brew_wrapper?

      nil
    end

    sig { params(env: T.any(String, Symbol), hash: T::Hash[Symbol, T.untyped]).returns(T.nilable(String)) }
    def env_value(env, hash)
      env = env.to_s
      env_value = ENV.fetch(env, nil)
      return if env_value.nil?

      if env_value.present? && (hash[:default] != true || FALSY_VALUES.exclude?(env_value.downcase))
        odeprecated_env(env, hash)
      end
      if (replacement = hash[:replacement]).is_a?(Symbol)
        ENV[replacement.to_s] ||= env_value
      end
      env_value
    end

    sig { params(env: String, hash: T::Hash[Symbol, T.untyped]).void }
    def odeprecated_env(env, hash)
      return if !hash[:odeprecated] && !hash[:odisabled]
      return unless env_deprecation_applies?(hash)

      replacement = hash[:replacement] if hash.key?(:replacement)
      return if !CoffeeBrewery.raise_deprecation_exceptions? && ENV["COFFEEBREWER_TESTS"].blank? &&
                !WARNED_DEPRECATED_ENVS.add?(env)

      odeprecated env, replacement, disable: hash.fetch(:odisabled, false)
    end

    sig { params(hash: T::Hash[Symbol, T.untyped]).returns(T::Boolean) }
    def env_deprecation_applies?(hash)
      commands = Array(hash[:commands]).map(&:to_s)
      command = ENV.fetch("COFFEEBREWER_COMMAND", nil)
      return false if commands.present? && command.present? && commands.exclude?(command)

      subcommands = Array(hash[:subcommands]).map(&:to_s)
      subcommand = ENV.fetch("COFFEEBREWER_SUBCOMMAND", nil)
      return false if subcommands.present? && subcommand.present? && subcommands.exclude?(subcommand)

      true
    end

    sig { returns(T::Boolean) }
    def bottle_domain_custom?
      CoffeeBrewery::EnvConfig.bottle_domain != COFFEEBREWER_BOTTLE_DEFAULT_DOMAIN
    end

    sig { returns(String) }
    def make_jobs
      jobs = ENV["COFFEEBREWER_MAKE_JOBS"].to_i
      return jobs.to_s if jobs.positive?

      ENVS.fetch(:COFFEEBREWER_MAKE_JOBS)
          .fetch(:default)
          .call
          .to_s
    end

    sig { returns(T::Array[String]) }
    def cask_opts
      Shellwords.shellsplit(ENV.fetch("COFFEEBREWER_CASK_OPTS", ""))
    end

    sig { returns(T::Boolean) }
    def self.cask_opts_binaries?
      cask_opts.reverse_each do |opt|
        return true if opt == "--binaries"
        return false if opt == "--no-binaries"
      end

      method_name = :cask_opts_binaries
      env_value = T.cast(CoffeeBrewery::EnvConfig.public_send(method_name), T.nilable(String))
      return FALSY_VALUES.exclude?(env_value.downcase) if env_value.present?

      true
    end

    sig { returns(T::Boolean) }
    def cask_opts_require_sha?
      return true if cask_opts.include?("--require-sha")

      method_name = :cask_opts_require_sha
      env_value = T.cast(CoffeeBrewery::EnvConfig.public_send(method_name), T.nilable(String))
      env_value.present? && FALSY_VALUES.exclude?(env_value.downcase)
    end

    sig { returns(T::Boolean) }
    def forbid_packages_from_paths?
      # Undocumented opt-out for internal use.
      return false if ENV["COFFEEBREWER_INTERNAL_ALLOW_PACKAGES_FROM_PATHS"].present?

      return true if ENV["COFFEEBREWER_FORBID_PACKAGES_FROM_PATHS"].present?

      # Provide an opt-out for tests and developers.
      # Our testing framework installs formulae from file paths all over the place.
      # Keep in sync with the COFFEEBREWER_FORBID_PACKAGES_FROM_PATHS default above.
      ENV["COFFEEBREWER_TESTS"].blank? && ENV["COFFEEBREWER_DEVELOPER"].blank?
    end

    sig { returns(T::Boolean) }
    def automatically_set_no_install_from_api?
      ENV["COFFEEBREWER_AUTOMATICALLY_SET_NO_INSTALL_FROM_API"].present?
    end

    sig { returns(T::Boolean) }
    def devcmdrun?
      CoffeeBrewery::Settings.read("devcmdrun") == "true"
    end

    sig { returns(Integer) }
    def download_concurrency
      concurrency = ENV.fetch("COFFEEBREWER_DOWNLOAD_CONCURRENCY", "auto")
      concurrency = if concurrency == "auto"
        require "os"
        require "hardware"
        Hardware::CPU.cores * 2
      else
        concurrency.to_i
      end

      [concurrency, 1].max
    end
  end
end
