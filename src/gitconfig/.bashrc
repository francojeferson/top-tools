# Create a ~/.bashrc file
# This file contains commands that are specific to the Bash shell
# Best place for aliases and bash-related functions

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
  ssh-add ~/.ssh/YOURNAME_key
elif [ "$agent_state" = 1 ]; then
  ssh-add ~/.ssh/YOURNAME_key
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
alias work='cd /c/Users/YOURNAME/repos'
ver() {
  echo "Git: $(git -v)"
  echo "Node: $(node -v)"
  echo "npm: $(npm -v)"
  echo "Java: $(java -version 2>&1 | head -n 1)"
  echo "Gradle: $(basename "$(ls /c/Users/YOURNAME/Documents/Tools/gradle-*/lib/gradle-launcher-*.jar 2>/dev/null)" .jar | sed 's/gradle-launcher-//')"
  echo "Python: $(python --version 2>&1)"
  echo "pip: $(pip --version 2>&1 | sed 's/pip \([0-9.]*\).*/\1/')"
  echo "UV: $(uvx --version 2>&1)"
  echo "ClaudeCode: $(claude -v 2>/dev/null)"
  echo "OpenCode: $(opencode -v 2>/dev/null)"
}

verup() {
  echo "--------------------"
  echo "Updating npm..."
  echo "--------------------"
  npm install -g npm@latest
  echo "--------------------"
  echo "Updating pip..."
  echo "--------------------"
  python -m pip install --upgrade pip
  echo "--------------------"
  echo "Updating uv..."
  echo "--------------------"
  pip install --upgrade uv
  echo "--------------------"
  echo "Updating claude..."
  echo "--------------------"
  npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code@latest
  echo "--------------------"
  echo "Updating opencode..."
  echo "--------------------"
  npm install -g --allow-scripts=opencode-ai opencode-ai@latest
  echo "--------------------"
  echo "End of updates!"
  echo "--------------------"
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

# Node (outside orca where %NODE_HOME% doesn't expand)
export PATH="/c/Users/YOURNAME/Documents/Tools/node-v22:$PATH"

# Python user scripts (uv, uvx)
export PATH="$PATH:$HOME/AppData/Roaming/Python/Python313/Scripts"

# opencode (npm global) on PATH
export PATH="$PATH:$HOME/AppData/Roaming/npm"

# --- Toolchain: official Windows installers own node/python. ---
# nvm + pyenv removed; node/python/claude come from the installer paths below
# (claude installed globally on the installer node -> %APPDATA%\npm).

# Node installer -> C:\Program Files\nodejs (node, npm, npx)
[ -d "/c/Program Files/nodejs" ] && PATH="/c/Program Files/nodejs:$PATH"

# Python installer (PyManager 3.14+) -> %LOCALAPPDATA%\Python\bin (python, pip shims)
[ -d "$HOME/AppData/Local/Python/bin" ] && PATH="$HOME/AppData/Local/Python/bin:$PATH"

export PATH
