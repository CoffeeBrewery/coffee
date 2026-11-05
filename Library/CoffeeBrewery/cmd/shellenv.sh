# Documentation defined in Library/CoffeeBrewery/cmd/shellenv.rb

# COFFEEBREWER_CELLAR and COFFEEBREWER_PREFIX are set by extend/ENV/super.rb
# COFFEEBREWER_REPOSITORY is set by bin/coffee
# Leading colon in MANPATH prepends default man dirs to search path in Linux and macOS.
# Trailing colon in INFOPATH appends the default info dirs to the search path.
# Please do not submit PRs to remove it!
# shellcheck disable=SC2154
homebrew-shellenv() {
  if [[ "${COFFEEBREWER_PATH}:" == "${COFFEEBREWER_PREFIX}/bin:${COFFEEBREWER_PREFIX}/sbin:"* ]]
  then
    return
  fi

  # Use specified shell name parameter, if available.
  COFFEEBREWER_SHELL_NAME="${1:-}"

  # Use the parent process name, if possible.
  # This is known to fail under some sandboxes.
  if [[ -z "${COFFEEBREWER_SHELL_NAME}" ]]
  then
    COFFEEBREWER_SHELL_NAME="$(/bin/ps -p "${PPID}" -c -o comm= 2>/dev/null)"
  fi

  # Fall back to the (login) shell name from the environment.
  if [[ -z "${COFFEEBREWER_SHELL_NAME}" ]]
  then
    COFFEEBREWER_SHELL_NAME="${SHELL##*/}"
  fi

  case "${COFFEEBREWER_SHELL_NAME}" in
    fish | -fish)
      echo "set --global --export COFFEEBREWER_PREFIX \"${COFFEEBREWER_PREFIX}\";"
      echo "set --global --export COFFEEBREWER_CELLAR \"${COFFEEBREWER_CELLAR}\";"
      echo "set --global --export COFFEEBREWER_REPOSITORY \"${COFFEEBREWER_REPOSITORY}\";"
      echo "fish_add_path --global --move --path \"${COFFEEBREWER_PREFIX}/bin\" \"${COFFEEBREWER_PREFIX}/sbin\";"
      echo "if test -n \"\$MANPATH\"; set --global --export MANPATH (string replace --regex '^:*(.*?):*\$' ':\$1' -- \"\$MANPATH\"); end;"
      echo "if not set --query INFOPATH; set INFOPATH ''; end; set --global --export INFOPATH \"${COFFEEBREWER_PREFIX}/share/info\" \$INFOPATH;"
      ;;
    csh | -csh | tcsh | -tcsh)
      echo "setenv COFFEEBREWER_PREFIX ${COFFEEBREWER_PREFIX};"
      echo "setenv COFFEEBREWER_CELLAR ${COFFEEBREWER_CELLAR};"
      echo "setenv COFFEEBREWER_REPOSITORY ${COFFEEBREWER_REPOSITORY};"
      echo "setenv PATH \"${COFFEEBREWER_PREFIX}/bin:${COFFEEBREWER_PREFIX}/sbin:\$PATH\";"
      echo "test \${?MANPATH} -eq 1 && test -n \"\${MANPATH}\" && setenv MANPATH :\`printf '%s' \"\${MANPATH}\" | /usr/bin/sed -e 's/^:*//' -e 's/:*\$//'\`;"
      echo "test \${?INFOPATH} -eq 1 || setenv INFOPATH '';"
      echo "setenv INFOPATH \"${COFFEEBREWER_PREFIX}/share/info:\${INFOPATH}\";"
      ;;
    pwsh | -pwsh | pwsh-preview | -pwsh-preview)
      echo "[System.Environment]::SetEnvironmentVariable('COFFEEBREWER_PREFIX','${COFFEEBREWER_PREFIX}',[System.EnvironmentVariableTarget]::Process)"
      echo "[System.Environment]::SetEnvironmentVariable('COFFEEBREWER_CELLAR','${COFFEEBREWER_CELLAR}',[System.EnvironmentVariableTarget]::Process)"
      echo "[System.Environment]::SetEnvironmentVariable('COFFEEBREWER_REPOSITORY','${COFFEEBREWER_REPOSITORY}',[System.EnvironmentVariableTarget]::Process)"
      echo "[System.Environment]::SetEnvironmentVariable('PATH',\$('${COFFEEBREWER_PREFIX}/bin:${COFFEEBREWER_PREFIX}/sbin:'+\$ENV:PATH),[System.EnvironmentVariableTarget]::Process)"
      echo "if (\${ENV:MANPATH}) { [System.Environment]::SetEnvironmentVariable('MANPATH',(':'+\${ENV:MANPATH}.Trim(':')),[System.EnvironmentVariableTarget]::Process) }"
      echo "[System.Environment]::SetEnvironmentVariable('INFOPATH',('${COFFEEBREWER_PREFIX}/share/info:'+\${ENV:INFOPATH}),[System.EnvironmentVariableTarget]::Process)"
      ;;
    *)
      echo "export COFFEEBREWER_PREFIX=\"${COFFEEBREWER_PREFIX}\";"
      echo "export COFFEEBREWER_CELLAR=\"${COFFEEBREWER_CELLAR}\";"
      echo "export COFFEEBREWER_REPOSITORY=\"${COFFEEBREWER_REPOSITORY}\";"
      if [[ "${COFFEEBREWER_SHELL_NAME}" == "zsh" ]] || [[ "${COFFEEBREWER_SHELL_NAME}" == "-zsh" ]]
      then
        echo "fpath[1,0]=\"${COFFEEBREWER_PREFIX}/share/zsh/site-functions\";"
        echo "export FPATH;"
      fi
      echo "export PATH=\"${COFFEEBREWER_PREFIX}/bin:${COFFEEBREWER_PREFIX}/sbin\${PATH+:\$PATH}\";"
      echo "[ -z \"\${MANPATH-}\" ] || { export MANPATH=\"\${MANPATH%\"\${MANPATH##*[!:]}\"}\"; export MANPATH=\":\${MANPATH#\"\${MANPATH%%[!:]*}\"}\"; };"
      echo "export INFOPATH=\"${COFFEEBREWER_PREFIX}/share/info:\${INFOPATH:-}\";"
      ;;
  esac
}
