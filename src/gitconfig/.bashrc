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
  echo "pip: $(_ver pip --version | sed 's/pip \([0-9.]*\).*/\1/')"
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

# Update every tool in the toolchain. Skips whatever is not installed.
# NOTE: uv updates itself. `pip install --upgrade uv` would upgrade a copy in
# the Python Scripts dir, which is not the uv that standalone installs put on PATH.
verup() {
  _upd npm npm install -g npm@latest
  _upd pip python -m pip install --upgrade pip
  _upd uv uv self update
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
