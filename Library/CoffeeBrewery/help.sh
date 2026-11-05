#:  * `help`
#:
#:  Outputs the usage instructions for `coffee`.
#:

# NOTE: Keep the length of vanilla `--help` less than 25 lines!
#       This is because the default Terminal height is 25 lines. Scrolling sucks
#       and concision is important. If more help is needed we should start
#       specialising help like the gem command does.
# NOTE: Keep lines less than 80 characters! Wrapping is just not cricket.
COFFEEBREWER_HELP_MESSAGE='Example usage:
  coffee search TEXT|/REGEX/
  coffee info [FORMULA|CASK...]
  coffee install FORMULA|CASK...
  coffee update
  coffee upgrade [FORMULA|CASK...]
  coffee uninstall FORMULA|CASK...
  coffee list [FORMULA|CASK...]

Troubleshooting:
  coffee config
  coffee doctor
  coffee install --verbose --debug FORMULA|CASK

Contributing:
  coffee create URL [--no-fetch]
  coffee edit [FORMULA|CASK...]

Further help:
  coffee commands
  coffee help [COMMAND]
  man coffee
  https://docs.coffee.sh'

homebrew-help() {
  if [[ -z "$*" ]]
  then
    echo "${COFFEEBREWER_HELP_MESSAGE}" >&2
    exit 1
  fi

  echo "${COFFEEBREWER_HELP_MESSAGE}"
  return 0
}
