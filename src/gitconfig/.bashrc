# Create a ~/.bashrc file
# This file contains commands that are specific to the Bash shell
# Best place for aliases and bash-related functions

# --- Machine-specific config ------------------------------------------------
# This file is meant to be IDENTICAL on every machine you use, so it contains
# no usernames and no absolute paths under /c/Users. Anything that differs per
# machine (SSH key name, where you keep repos) goes in ~/.bashrc.local.
# Copy .bashrc.local.example to ~/.bashrc.local and edit it. See README.md.
# Sourced first, so the ssh-agent block below can see SSH_KEY.
[ -f ~/.bashrc.local ] && . ~/.bashrc.local

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"  # key loaded into ssh-agent
REPOS="${REPOS:-$HOME/repos}"                # target of the `work` alias
TOOLS="${TOOLS:-$HOME/Documents/Tools}"      # unpacked tools (gradle, node, ...)

# ssh-agent: reuse one persistent agent across shells (no leak, one passphrase prompt)
env=~/.ssh/agent.env
agent_load_env() {
  test -f "$env" && . "$env" >/dev/null
}

agent_start() {
  (umask 077; ssh-agent >"$env")
  . "$env" >/dev/null
}

agent_load_env
agent_state=$(ssh-add -l >/dev/null 2>&1; echo $?) # 0=key loaded 1=no key 2=no agent
if [ ! "$SSH_AUTH_SOCK" ] || [ "$agent_state" = 2 ]; then
  agent_start
  [ -f "$SSH_KEY" ] && ssh-add "$SSH_KEY"
elif [ "$agent_state" = 1 ]; then
  [ -f "$SSH_KEY" ] && ssh-add "$SSH_KEY"
fi
unset env

# Git aliases
alias gs='git status -sb'
alias gcc='git checkout'
alias gcm='git checkout master'
alias gaa='git add --all'
gc() {
  git commit -m "$*"
}

alias push='git push'
alias gpo='git push origin'
alias pull='git pull'
alias clone='git clone'
ssa() {
  git stash save "$*" -u && git stash apply
}

alias sl='git stash list'
alias sp='git stash pop'
alias ga='git add'
alias gb='git branch'
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gm='git merge'
alias gf='git fetch'

# Bash aliases
# NOTE: cdd, not `.` -- `.` is the `source` builtin, and aliasing it breaks
# `. ~/.bashrc` and `. venv/Scripts/activate`.
alias cdd='cd .'
alias ..='cd ..'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias bls='echo "" > ~/.bash_history && history -c && clear'
alias cls='clear'
alias ls='ls -F --color=auto --show-control-chars'
alias ll='ls -l'
alias ll.='ls -la'
alias lls='ls -la --sort=size'
alias llt='ls -la --sort=time'
alias rm='rm -iv'
alias init='work && clean -f && verup && ver'
alias work='cd "$REPOS"'

# Print a tool's version, or "not installed" if it is absent.
_ver() {
  local cmd=$1; shift
  command -v "$cmd" >/dev/null 2>&1 || { echo "not installed"; return; }
  "$cmd" "$@" 2>&1 | head -n 1
}

# Gradle lives in a directory; it is not a command on PATH.
_ver_gradle() {
  local jar
  jar=$(ls "$TOOLS"/gradle-*/lib/gradle-launcher-*.jar 2>/dev/null | head -n 1)
  [ -n "$jar" ] || { echo "not installed"; return; }
  basename "$jar" .jar | sed 's/gradle-launcher-//'
}

# Report the version of every tool in the toolchain.
ver() {
  echo "Git: $(_ver git -v)"
  echo "Node: $(_ver node -v)"
  echo "npm: $(_ver npm -v)"
  echo "Java: $(_ver java -version)"
  echo "Gradle: $(_ver_gradle)"
  echo "Python: $(_ver python --version)"
  echo "pip: $(_ver python -m pip --version | sed 's/pip \([0-9.]*\).*/\1/')"
  echo "UV: $(_ver uvx --version)"
  echo "ClaudeCode: $(_ver claude -v)"
  echo "OpenCode: $(_ver opencode -v)"
}

_hr() {
  echo "--------------------"
  echo "$1"
  echo "--------------------"
}

# _upd <label> <command...> - run the update, or skip if the tool is absent.
# Tests the first word of <command...>, so `_upd pip python -m pip ...` checks python.
_upd() {
  local label=$1; shift
  _hr "Updating $label..."
  if command -v "$1" >/dev/null 2>&1; then
    "$@"
  else
    echo "$1 not installed - skipped"
  fi
}

# uv's updater depends on install source: WinGet-managed copies refuse
# `uv self update`, pip-managed copies must be upgraded with pip, and
# standalone installs have no WinGet package to upgrade.
_upd_uv() {
  _hr "Updating uv..."
  if ! command -v uv >/dev/null 2>&1; then
    echo "uv not installed - skipped"
  elif command -v winget >/dev/null 2>&1 &&
       winget list --id astral-sh.uv -e --accept-source-agreements >/dev/null 2>&1; then
    winget upgrade --id astral-sh.uv -e --accept-source-agreements
  elif python -m pip show uv >/dev/null 2>&1; then
    python -m pip install --upgrade uv
  else
    uv self update
  fi
}

# Update every tool in the toolchain. Skips whatever is not installed.
verup() {
  _upd npm npm install -g npm@latest
  _upd pip python -m pip install --upgrade pip
  _upd_uv
  _upd claude npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code@latest
  _upd opencode npm install -g --allow-scripts=opencode-ai opencode-ai@latest
  _hr "End of updates!"
}

# Bash shell settings
# Typing a directory name just by itself will automatically change into that directory.
shopt -s autocd

# Automatically fix directory name typos when changing directory.
shopt -s cdspell

# Automatically expand directory globs and fix directory name typos whilst completing.
# Note, this works in conjuction with the cdspell option listed above.
shopt -s direxpand dirspell

# Enable the ** globstar recursive pattern in file and directory expansions.
# For example, ls **/*.txt will list all text files in the current directory hierarchy.
shopt -s globstar

# Ignore lines which begin with a <space> and match previous entries.
# Erase duplicate entries in history file.
HISTCONTROL=ignoreboth:erasedups

# Ignore saving short- and other listed commands to the history file.
HISTIGNORE=?:??:history

# The maximum number of lines in the history file.
HISTFILESIZE=99999

# The number of entries to save in the history file.
HISTSIZE=99999

# Set Bash to save each command to history, right after it has been executed.
PROMPT_COMMAND='history -a'

# Save multi-line commands in one history entry.
shopt -s cmdhist

# Append commands to the history file, instead of overwriting it.
# History substitution are not immediately passed to the shell parser.
shopt -s histappend histverify

# --- PATH -------------------------------------------------------------------
# Every entry is guarded with [ -d ], so a missing directory is skipped instead
# of padding PATH with dead entries. Official Windows installers own node and
# python; nvm and pyenv are not used.

# opencode / claude (npm global) -> %APPDATA%\npm
[ -d "$HOME/AppData/Roaming/npm" ] && PATH="$PATH:$HOME/AppData/Roaming/npm"

# Node installer -> C:\Program Files\nodejs (node, npm, npx)
[ -d "/c/Program Files/nodejs" ] && PATH="/c/Program Files/nodejs:$PATH"

# Python installer (PyManager 3.14+) -> %LOCALAPPDATA%\Python\bin (python, pip shims)
[ -d "$HOME/AppData/Local/Python/bin" ] && PATH="$HOME/AppData/Local/Python/bin:$PATH"

export PATH

# --- Cache / temp cleanup ---------------------------------------------------
# clean      dry run: list what would be removed, delete nothing (default)
# clean -f   actually delete, then report the space reclaimed
#
# User-scoped on purpose: nothing here needs admin, so C:\Windows\Temp is left
# alone (this account is denied it anyway).
#
# Sizes come from a free-space delta, not `du` -- walking npm-cache's 61k files
# through the MSYS layer takes minutes, while `df` is instant.
#
# Deliberately NOT touched:
#   ~/.cache/whisper          model weights, ~1.5G to re-download
#   ~/.cache/puppeteer        pinned browser builds tools expect to be present
#   WinGet\Packages           real installs live here (uv included), not a cache
#   JetBrains */caches,index  wiping these forces a full project re-index
#   node_modules              build input, not cache -- drop it per project

CLEAN_TEMP_DAYS="${CLEAN_TEMP_DAYS:-3}"   # temp files newer than this are kept

# Free MB on C:, used to measure what a run actually reclaimed.
_clean_free() { df -m /c | awk 'NR==2 {print $4}'; }

# `rm` is aliased to `rm -iv` above, and bash expands aliases inside function
# bodies at parse time, so a bare `rm -rf` here would prompt for every file.
# `command rm` bypasses the alias.
_clean_rm() { command rm -rf -- "$@" 2>/dev/null; }

# _clean_dir <label> <path> - drop a cache directory if it is there.
_clean_dir() {
  [ -d "$2" ] || return 0
  printf '  %-26s %s\n' "$1" "${2#$HOME/}"
  [ -n "$CLEAN_DRY" ] || _clean_rm "$2"
}

# _clean_tool <label> <path> <cmd...> - let the tool evict its own cache so its
# index stays consistent, instead of rm-ing out from under it.
_clean_tool() {
  local label=$1 path=$2; shift 2
  command -v "$1" >/dev/null 2>&1 || return 0
  [ -d "$path" ] || return 0
  printf '  %-26s %s\n' "$label" "$*"
  [ -n "$CLEAN_DRY" ] || "$@" >/dev/null 2>&1
}

clean() {
  local CLEAN_DRY=1 before after
  local la="$HOME/AppData/Local" ra="$HOME/AppData/Roaming"
  [ "$1" = "-f" ] && CLEAN_DRY=""
  before=$(_clean_free)

  _hr "${CLEAN_DRY:+DRY RUN - }Package manager caches"
  _clean_tool "npm"                 "$la/npm-cache"          npm cache clean --force
  _clean_tool "uv"                  "$la/uv/cache"           uv cache clean
  _clean_tool "pip"                 "$la/pip/Cache"          python -m pip cache purge

  _hr "Browser / MCP caches"
  _clean_dir  "chrome cache"        "$la/Google/Chrome/User Data/Default/Cache"
  _clean_dir  "chrome code cache"   "$la/Google/Chrome/User Data/Default/Code Cache"
  _clean_dir  "chrome gpu cache"    "$la/Google/Chrome/User Data/Default/GPUCache"
  _clean_dir  "edge cache"          "$la/Microsoft/Edge/User Data/Default/Cache"
  _clean_dir  "edge code cache"     "$la/Microsoft/Edge/User Data/Default/Code Cache"
  _clean_dir  "playwright-mcp"      "$la/ms-playwright-mcp"
  _clean_dir  "chrome-devtools-mcp" "$HOME/.cache/chrome-devtools-mcp"

  _hr "Editor caches"
  _clean_dir  "vscode cache"        "$ra/Code/Cache"
  _clean_dir  "vscode cacheddata"   "$ra/Code/CachedData"
  _clean_dir  "vscode vsix"         "$ra/Code/CachedExtensionVSIXs"
  _clean_dir  "vscode logs"         "$ra/Code/logs"

  _hr "Temp + dumps"
  _clean_dir  "crash dumps"         "$la/CrashDumps"
  if [ -d "$la/Temp" ]; then
    printf '  %-26s %s\n' "temp" "files older than ${CLEAN_TEMP_DAYS}d"
    # Files first, then the directories they emptied; anything a running
    # process still holds open simply fails and is left in place.
    [ -n "$CLEAN_DRY" ] || {
      find "$la/Temp" -mindepth 1 -mtime "+$CLEAN_TEMP_DAYS" -type f -delete 2>/dev/null
      find "$la/Temp" -mindepth 1 -mtime "+$CLEAN_TEMP_DAYS" -type d -empty -delete 2>/dev/null
    }
  fi

  if [ -n "$CLEAN_DRY" ]; then
    _hr "Nothing deleted. Run 'clean -f' to do it."
  else
    after=$(_clean_free)
    _hr "Reclaimed $(( after - before )) MB -- $(( after / 1024 )) GB free on C:"
  fi
}
