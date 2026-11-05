# Formatting helpers for CoffeeBrewery's Bash scripts.

# COFFEEBREWER_LIBRARY is set by bin/coffee
# shellcheck disable=SC2154
source "${COFFEEBREWER_LIBRARY}/CoffeeBrewery/utils/tty.sh"

formatter_label() {
  local colour="$1"
  local string="$2"
  local stream="${3:-1}"

  if tty_colour_enabled "${stream}"
  then
    printf '\033[%sm%s\033[0m' "${colour}" "${string}"
  else
    printf '%s' "${string}"
  fi
}

# Keep in sync with Formatter.bold in Library/CoffeeBrewery/utils/formatter.rb.
bold() {
  # Check whether stderr is a tty.
  if tty_colour_enabled 2
  then
    echo -e "\\033[1m""$*""\\033[0m"
  else
    echo "$*"
  fi
}

# Keep in sync with Formatter.headline in Library/CoffeeBrewery/utils/formatter.rb.
headline() {
  if tty_colour_enabled 1
  then
    printf '\033[34m==>\033[0m \033[1m%s\033[0m' "$*" # blue arrow and bold text
  else
    printf '==> %s' "$*"
  fi
}
