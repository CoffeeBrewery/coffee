---
last_review_date: "2026-07-18"
---

# `coffee` Shell Completion

CoffeeBrewery provides completion definitions for `coffee` in Bash, fish and zsh.
Some formulae and external commands provide completions for their own commands.

CoffeeBrewery stores completions under `COFFEEBREWER_PREFIX`, which a system shell may not search automatically.
The installer does not modify every shell's completion configuration because startup files and plugin managers vary.

Completions supplied by external CoffeeBrewery commands are not linked automatically.
Enable them with:

```sh
coffee completions link
```

## Bash

Add the following to `~/.bash_profile`, or to `~/.profile` when `~/.bash_profile` does not exist:

```sh
if type coffee &>/dev/null
then
  COFFEEBREWER_PREFIX="$(coffee --prefix)"
  if [[ -r "${COFFEEBREWER_PREFIX}/etc/profile.d/bash_completion.sh" ]]
  then
    source "${COFFEEBREWER_PREFIX}/etc/profile.d/bash_completion.sh"
  else
    for COMPLETION in "${COFFEEBREWER_PREFIX}/etc/bash_completion.d/"*
    do
      [[ -r "${COMPLETION}" ]] && source "${COMPLETION}"
    done
  fi
fi
```

The `bash-completion` formula supports the system Bash shipped by macOS.
Use `bash-completion@2` with CoffeeBrewery's Bash 4 or newer.
The two formulae conflict with each other, so install only one.
The snippet above loads the installed version, so do not also source it elsewhere in the same shell configuration.

## zsh

`coffee shellenv` adds CoffeeBrewery's zsh completion directory to `FPATH`.
Ensure that `eval "$(coffee shellenv)"` runs before zsh initialises completion, then add the following to `~/.zshrc` if your configuration or framework does not already call `compinit`:

```sh
autoload -Uz compinit
compinit
```

Oh My Zsh calls `compinit` when it loads.
Make sure `coffee shellenv` is evaluated first, particularly on Linux.

If zsh reports insecure completion directories, run `compaudit` to list the affected paths.
Inspect their ownership and remove group or world write access only from the directories reported by `compaudit`.
Do not recursively change permissions across the entire CoffeeBrewery prefix.

## fish

CoffeeBrewery's `fish` formula discovers CoffeeBrewery-managed completions automatically.

For a fish installation from another source, add the following to `~/.config/fish/config.fish`:

```fish
if test -d (coffee --prefix)"/share/fish/completions"
    set -p fish_complete_path (coffee --prefix)/share/fish/completions
end

if test -d (coffee --prefix)"/share/fish/vendor_completions.d"
    set -p fish_complete_path (coffee --prefix)/share/fish/vendor_completions.d
end
```

## PowerShell

Some formulae install PowerShell completions for their own commands under CoffeeBrewery's PowerShell completion directory.
CoffeeBrewery does not currently provide a PowerShell completion definition for `coffee` itself.

Add the following to your PowerShell profile, such as `~/.config/powershell/Microsoft.PowerShell_profile.ps1`:

```pwsh
if ((Get-Command coffee -ErrorAction SilentlyContinue) -and (Test-Path ($completions = "$(coffee --prefix)/share/pwsh/completions"))) {
  foreach ($f in Get-ChildItem -Path $completions -File) {
    . $f
  }
}
```
