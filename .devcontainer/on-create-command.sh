#!/bin/bash
set -e

# fix permissions so CoffeeBrewery and Bundler don't complain
sudo chmod -R g-w,o-w /home/linuxbrew
sudo chmod +t -R /home/linuxbrew/

# everything below is too slow to do unless prebuilding so skip it
CODESPACES_ACTION_NAME="$(jq --raw-output '.ACTION_NAME' /workspaces/.codespaces/shared/environment-variables.json)"
if [[ "${CODESPACES_ACTION_NAME}" != "createPrebuildTemplate" ]]
then
  echo "Skipping slow items, not prebuilding."
  exit 0
fi

# disable interactive ask mode so non-interactive prebuilds don't hang
export COFFEEBREWER_NO_ASK=1

# install CoffeeBrewery's development gems
coffee install-bundler-gems --groups=all

# install CoffeeBrewery formulae we might need
coffee install shellcheck shfmt gh gnu-tar

# cleanup any mess
coffee cleanup

# actually tap homebrew/core, no longer done by default
coffee tap --force homebrew/core

# install some useful development things
sudo apt-get update
sudo apt-get install -y \
  -o Dpkg::Options::=--force-confdef \
  -o Dpkg::Options::=--force-confnew \
  bash-completion \
  openssh-server \
  zsh

# Start the SSH server so that `gh cs ssh` works.
sudo service ssh start
