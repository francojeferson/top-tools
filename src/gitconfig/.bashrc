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
# Name of its own, and left set: both helpers below stay usable by hand after
# startup. A bare `env` that got unset at the end of this block did not.
AGENT_ENV=~/.ssh/agent.env

agent_load_env() {
  test -f "$AGENT_ENV" && . "$AGENT_ENV" >/dev/null
}

agent_start() {
  (umask 077; ssh-agent >"$AGENT_ENV")
  . "$AGENT_ENV" >/dev/null
}

agent_load_env
agent_state=$(ssh-add -l >/dev/null 2>&1; echo $?) # 0=key loaded 1=no key 2=no agent
if [ ! "$SSH_AUTH_SOCK" ] || [ "$agent_state" = 2 ]; then
  agent_start
fi
# 0 means the key is already loaded; 1 and 2 both need it added.
[ "$agent_state" != 0 ] && [ -f "$SSH_KEY" ] && ssh-add "$SSH_KEY"
unset agent_state

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
alias claude='claude --effort max'
# `clean -f` deletes live Claude/OpenCode/Codex session state, and `init` is
# often run from inside one of them. Close those tools before running it; use
# bare `clean` when you only want the list. `clean -f` refuses while Claude
# Code, Codex, or OpenCode is running.
alias init='work && clean -f && verup && ver'
alias work='cd "$REPOS"'

# Print a tool's version, or "not installed" if it is absent.
_ver() {
  local cmd=$1; shift
  command -v "$cmd" >/dev/null 2>&1 || { echo "not installed"; return; }
  # First non-blank line, not first line: 7-Zip opens its banner with an empty
  # one, which would report the tool as installed but versionless.
  "$cmd" "$@" 2>&1 | grep -m1 .
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
  echo "GitHubCLI: $(_ver gh --version)"
  echo "VSCodium: $(_ver codium --version)"
  echo "7-Zip: $(_ver 7z | sed 's/^7-Zip \([0-9.]*\).*/\1/')"
  echo "Node: $(_ver node -v)"
  echo "npm: $(_ver npm -v)"
  echo "Java: $(_ver java -version)"
  echo "Gradle: $(_ver_gradle)"
  echo "Python: $(_ver python --version)"
  echo "pip: $(_ver python -m pip --version | sed 's/pip \([0-9.]*\).*/\1/')"
  echo "UV: $(_ver uv --version)"
  echo "Rust: $(_ver rustc --version)"
  echo "RTK: $(_ver rtk --version)"
  echo "ClaudeCode: $(_ver claude -v)"
  echo "Codex: $(_ver codex --version)"
  echo "OpenCode: $(_ver opencode -v)"
  _ver_updates
}

# Git cannot be upgraded from inside Git Bash (that would replace the running
# bash.exe), so `verup` only reports it, exactly as here. The rest `verup`
# updates, or for a machine-wide package prints the command to run; they stay
# listed here so `ver` on its own still tells you what is pending.
# Both checks hit the network (~3s), so this runs from `ver` on demand, never
# at shell startup. One winget call covers every winget-owned tool.
_ver_updates() {
  local out pair label id cur latest
  command -v winget >/dev/null 2>&1 &&
    out=$(winget upgrade --accept-source-agreements 2>/dev/null)
  for pair in 'Git:Git.Git' \
              'GitHubCLI:GitHub.cli' \
              'VSCodium:VSCodium.VSCodium' \
              '7-Zip:7zip.7zip' \
              'Node:OpenJS.NodeJS.LTS' \
              'PyManager:Python.PythonInstallManager' \
              'RTK:rtk-ai.rtk'; do
    label=${pair%%:*}; id=${pair#*:}
    case $out in
      *"$id"*) echo "! $label update available (winget upgrade --id $id -e)" ;;
    esac
  done

  # PyManager owns the interpreter, so winget only ever sees the manager, not
  # the Python it installed. Ask PyManager for the newest build of the minor
  # already installed; a major bump is a deliberate migration, not an update.
  cur=$(python --version 2>/dev/null | cut -d' ' -f2)
  [ -n "$cur" ] || return 0
  latest=$(py list --online -f json "${cur%.*}" 2>/dev/null |
             grep -o '"sort-version": "[0-9][0-9.]*"' | head -n 1 | cut -d'"' -f4)
  [ -n "$latest" ] && [ "$latest" != "$cur" ] &&
    echo "! Python $cur -> $latest (py install ${cur%.*} -u)"
  return 0
}

_hr() {
  echo "--------------------"
  echo "$1"
  echo "--------------------"
}

# _upd <tool> <command...> - run the update, or skip if the tool is absent.
# Tests <tool> itself, not the first word of <command...>: the updater is often
# a different program (winget, npm), and testing that would install the tool on
# a box that never had it instead of skipping it.
_upd() {
  local tool=$1; shift
  _hr "Updating $tool..."
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool not installed - skipped"
  elif ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 not installed - cannot update $tool"
  else
    "$@"
  fi
}

# pip ships as a python module, and the `pip` shim is not always on PATH even
# where `python -m pip` works fine. Test the module, so a missing shim does not
# silently stop pip from ever being upgraded.
_upd_pip() {
  _hr "Updating pip..."
  if ! command -v python >/dev/null 2>&1; then
    echo "python not installed - cannot update pip"
  elif ! python -m pip --version >/dev/null 2>&1; then
    echo "pip not installed - skipped"
  else
    python -m pip install --upgrade pip
  fi
}

# uv's updater depends on install source: WinGet-managed copies refuse
# `uv self update`, pip-managed copies must be upgraded with pip, and
# standalone installs update themselves. Decide by the uv that is actually on
# PATH, not by which installer knows of one: a stray pip copy off PATH once
# took every upgrade while the uv in use sat versions behind.
_upd_uv() {
  local uv
  _hr "Updating uv..."
  uv=$(command -v uv 2>/dev/null) || { echo "uv not installed - skipped"; return; }
  case $uv in
    */WinGet/*)  winget upgrade --id astral-sh.uv -e --accept-source-agreements ;;
    */Scripts/*) python -m pip install --upgrade uv ;;
    *)           uv self update ;;
  esac
}

# _winget_up <id> - upgrade a winget package without ever asking the user.
# A machine-scope package (Program Files) needs admin, and unelevated winget
# answers that with a UAC dialog, which stalls `verup` forever on a box where
# the account cannot elevate at all. So prove the package is user-scope, or
# that we are elevated, before calling winget; otherwise just print the command
# to run by hand. --disable-interactivity is the backstop for everything else:
# winget fails instead of prompting. winget exits non-zero for "nothing to do",
# so the result is read from the text, not the status.
_winget_up() {
  local id=$1 proc=$2 out rc
  command -v winget >/dev/null 2>&1 || { echo "winget not installed - skipped"; return; }
  # `winget list` grows an "Available" column only when a newer version exists,
  # so its presence is the whole test. Asked first, because every bail-out
  # below prints a command to run by hand -- and nagging about a tool that is
  # already current is how a warning stops being read.
  case $(winget list --id "$id" -e --accept-source-agreements 2>/dev/null) in
    *Available*) ;;
    *) echo "up to date"; return ;;
  esac
  # A silent upgrade replaces files in use: it would close a running editor, or
  # the shell this runs in, and take any AI session with it. Pass the app's
  # process name and it is reported instead of killed.
  if [ -n "$proc" ] && tasklist //NH //FI "IMAGENAME eq $proc" 2>/dev/null | grep -qi "$proc"; then
    echo "! update available, but $proc is running - close it, or run:"
    echo "    winget upgrade --id $id -e"
    return
  fi
  if ! winget list --id "$id" -e --scope user --accept-source-agreements >/dev/null 2>&1 &&
     ! net session >/dev/null 2>&1; then
    echo "! update available, but it is machine-wide and needs admin - run:"
    echo "    winget upgrade --id $id -e   (then approve the UAC prompt)"
    return
  fi
  out=$(winget upgrade --id "$id" -e --silent --disable-interactivity \
          --accept-source-agreements --accept-package-agreements 2>&1)
  rc=$?
  printf '%s\n' "$out"
  case $out in
    *"No available upgrade"* | *"No installed package"*) return ;;
  esac
  # Only user-scope or already-elevated runs get here, so admin is never the
  # fix: the reason is in winget's output above (a file in use, the network).
  [ "$rc" = 0 ] || echo "! not updated - see winget's output above, then retry: winget upgrade --id $id -e"
}

# PyManager owns the interpreter, so winget never sees it. Upgrade the minor
# already installed; a major bump is a deliberate migration, not an update.
# -y so a confirmation prompt cannot stall the run.
_upd_python() {
  local cur=""
  _hr "Updating Python..."
  command -v python >/dev/null 2>&1 && cur=$(python --version 2>/dev/null | cut -d' ' -f2)
  if ! command -v py >/dev/null 2>&1; then
    echo "py (PyManager) not installed - skipped"
  elif [ -z "$cur" ]; then
    echo "python not installed - skipped"
  else
    py install -u -y "${cur%.*}"
  fi
}

# Pull a JDK package Id out of `winget list`. Matches a dotted token only, so
# it can only ever hit the Id column -- names in the Name column have spaces.
_java_winget_id() {
  grep -oiE '[A-Za-z0-9]+\.[A-Za-z0-9.]*(Temurin|OpenJDK|Zulu|Corretto|GraalVM|Liberica|JDK)[A-Za-z0-9.]*' |
    head -n 1
}

# Java has no single vendor, so resolve whichever JDK winget installed instead
# of pinning an id that would go wrong on the next machine.
# shortcut: only a winget-installed JDK is upgraded; an unpacked JDK under
# $TOOLS is reported and left alone. Add a branch here if you adopt one.
_upd_java() {
  local id
  _hr "Updating Java..."
  if ! command -v java >/dev/null 2>&1; then
    echo "java not installed - skipped"
    return
  fi
  id=$(winget list --accept-source-agreements 2>/dev/null | _java_winget_id)
  if [ -z "$id" ]; then
    echo "no winget JDK package found - update it the way you installed it"
  else
    _winget_up "$id"
  fi
}

# verup_selfcheck - _java_winget_id picks an id out of free text, so prove it
# finds real JDK ids and ignores everything else. Run by hand after editing it.
verup_selfcheck() {
  local got rc=0 line
  for line in 'Microsoft Build of OpenJDK (21)  Microsoft.OpenJDK.21  21.0.5  winget:Microsoft.OpenJDK.21' \
              'Eclipse Temurin JDK 21  EclipseAdoptium.Temurin.21.JDK  21.0.5  winget:EclipseAdoptium.Temurin.21.JDK' \
              'Azul Zulu 21  Azul.Zulu.21.JDK  21.0.5  winget:Azul.Zulu.21.JDK' \
              'Node.js  OpenJS.NodeJS.LTS  24.22.1  winget:' \
              'GitHub CLI  GitHub.cli  2.103.2  winget:'; do
    got=$(printf '%s\n' "${line%:*}" | _java_winget_id)
    [ "$got" = "${line##*:}" ] ||
      { echo "FAIL java id: got '$got', want '${line##*:}'"; rc=1; }
  done
  [ "$rc" = 0 ] && echo "verup_selfcheck: all checks passed"
  return "$rc"
}

# Update every tool in the toolchain. Skips whatever is not installed.
# Node before npm and Python before pip: the runtime update ships its own copy
# of the package manager, so updating the manager first would be thrown away.
# PyManager goes before Python itself: it is what installs the interpreter.
verup() {
  _upd node _winget_up OpenJS.NodeJS.LTS
  _upd npm npm install -g npm@latest
  _upd py _winget_up Python.PythonInstallManager
  _upd_python
  _upd_pip
  _upd_uv
  _upd_java
  _upd rustup rustup update
  # bash.exe is the shell running this line, so the guard can never clear for
  # Git: it degrades to a notice plus the command, which is all Git can get.
  _upd git _winget_up Git.Git bash.exe
  _upd gh _winget_up GitHub.cli gh.exe
  _upd rtk _winget_up rtk-ai.rtk
  _upd codium _winget_up VSCodium.VSCodium VSCodium.exe
  _upd 7z _winget_up 7zip.7zip 7zFM.exe
  _upd claude npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code@latest
  _upd codex npm install -g @openai/codex@latest
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

# claude / codex / opencode (npm global) -> %APPDATA%\npm
[ -d "$HOME/AppData/Roaming/npm" ] && PATH="$PATH:$HOME/AppData/Roaming/npm"

# Node installer -> C:\Program Files\nodejs (node, npm, npx)
[ -d "/c/Program Files/nodejs" ] && PATH="/c/Program Files/nodejs:$PATH"

# Node picked by the Windows user variable NODE_HOME (NODE_16 / NODE_22 under
# ~/Documents/Tools). The Windows Path hardcodes ...\Tools\node-v22 and never
# reads NODE_HOME, so changing the variable alone did nothing. Prepended after
# the installer line above so an explicit choice outranks it.
_nh=$(cygpath -u "${NODE_HOME:-}" 2>/dev/null)
[ -n "$_nh" ] && [ -d "$_nh" ] && PATH="$_nh:$PATH"
unset _nh

# Python installer (PyManager 3.14+) -> %LOCALAPPDATA%\Python\bin (python, pip shims)
[ -d "$HOME/AppData/Local/Python/bin" ] && PATH="$HOME/AppData/Local/Python/bin:$PATH"

# 7-Zip installer -> C:\Program Files\7-Zip (7z). Its installer never puts this
# on PATH, so `ver`/`verup` would call 7-Zip "not installed". Appended, not
# prepended: nothing here should outrank a 7z the toolchain already provides.
[ -d "/c/Program Files/7-Zip" ] && PATH="$PATH:/c/Program Files/7-Zip"

# Drop duplicate and empty entries, keeping the first of each, so `. ~/.bashrc`
# stays idempotent. First-wins preserves the priority the prepends just set,
# and clears any repeats inherited from the Windows PATH too.
# Assigned only if it produced something: a missing awk/paste would otherwise
# blank PATH and leave the shell with no commands at all.
_path_dedup=$(printf '%s' "$PATH" | tr ':' '\n' | awk 'NF && !seen[$0]++' | paste -sd:)
[ -n "$_path_dedup" ] && PATH=$_path_dedup
unset _path_dedup

export PATH

# --- Cache / temp cleanup ---------------------------------------------------
# clean      dry run: list what would be removed, delete nothing (default)
# clean -f   actually delete, then report the space reclaimed
#             also deletes local session history and persistent AI memories;
#             close those tools first so their stores and runtime files are idle
#             (refuses while Claude Code, Codex, or OpenCode is running)
#
# User-scoped on purpose: nothing here needs admin, so C:\Windows\Temp is left
# alone (this account is denied it anyway).
#
# Sizes come from a free-space delta, not `du` -- walking npm-cache's 61k files
# through the MSYS layer takes minutes, while `df` is instant.
#
# Deliberately NOT touched:
#   ~/.cache/whisper          model weights, ~1.5G to re-download
#   $ra/uv/python             uv-managed interpreters: an install, not a cache
#   $ra/Code/User             settings.json, snippets, globalStorage
#   $ra/VSCodium/User         settings, snippets, globalStorage, local file History
#   $ra/VSCodium/WebStorage   extension state, not a cache
#   $la/Pub/Cache/bin         `dart pub global activate` installs
#   WinGet\Packages           real installs live here (rtk, gh), not a cache
#   JetBrains */caches,index  wiping these forces a full project re-index
#   node_modules              build input, not cache -- drop it per project
#   ~/.claude/projects/*/CLAUDE.md, settings*, scheduled_tasks.json
#   ~/.claude/plugins         installed Claude Code plugins (except orphaned caches)
#   ~/.claude/skills          custom skills
#   ~/.claude/hooks           user hook scripts
#   ~/.claude/ide             IDE integration config
#   ~/.claude/security        security settings
#   ~/.claude/CLAUDE.md       user instructions
#   ~/.config/opencode        settings, plugins, and plugin dependencies
#   ${XDG_CACHE_HOME:-~/.cache}/opencode  installed plugins and runtime files
#   ~/.local/share/opencode/auth.json,opencode.db*  credentials and data store
#   ~/.codex/auth.json,config.toml,AGENTS.md,hooks.json  auth and configuration
#   ~/.codex/skills,plugins    installed Codex extensions
#   ~/.codex/goals_*.sqlite   persistent goals
#   ~/.codex/thread-writer-locks,app-server-*         live process coordination
#   $la/Citrix/Receiver,SelfService,AuthManager  corp VPN config, not cache
#   $ra/orca/speech-models    model weights, ~640M to re-download
#   $ra/orca/ai-vault,profiles,*.key,*keypair*  credentials and profile state
#   $ra/orca/agent-session-*,terminal-history   session journal and history
#   $la/Orca/daemon-host      the installed runtime, not a cache

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

# _clean_file <label> <path> - drop a single cache file if it is there.
_clean_file() {
  [ -f "$2" ] || return 0
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

# _clean_gone <label> <path> <cmd> - a cache left behind by a tool that is no
# longer installed. Skipped while the tool is still present, so reinstalling it
# puts the directory back under its own management.
_clean_gone() {
  command -v "$3" >/dev/null 2>&1 && return 0
  _clean_dir "$1" "$2"
}

# file:// URI -> a path [ -d ] can test. Byte-wise, so a percent escape above
# 7F would decode to mojibake; _clean_ws_orphans refuses those rather than
# mistake a live folder for a dead one.
_clean_uri_path() {
  printf '%s' "${1#file:///}" | gawk '{
    while (match($0, /%[0-9a-fA-F][0-9a-fA-F]/))
      $0 = substr($0, 1, RSTART-1) \
           sprintf("%c", strtonum("0x" substr($0, RSTART+1, 2))) \
           substr($0, RSTART+3)
    print
  }'
}

# Editor per-workspace state for folders that are gone. Only prunes an entry it
# can positively prove is dead: no workspace.json, no "folder" key, a non-ASCII
# escape, or a drive that is not mounted (G: while Drive is offline) all mean
# "leave it alone".
_clean_ws_orphans() {
  local ws=$1 label=${2:-workspaces} d j uri path n=0
  [ -d "$ws" ] || return 0
  for d in "$ws"/*/; do
    j="$d/workspace.json"
    [ -f "$j" ] || continue
    uri=$(sed -n 's/.*"folder"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$j")
    case $uri in
      "" | *%[89aAbBcCdDeEfF][0-9a-fA-F]*) continue ;;
    esac
    path=$(_clean_uri_path "$uri")
    [ -n "$path" ] || continue          # decode failed: unknowable, keep
    [ -d "${path%%/*}/" ] || continue   # drive not mounted: unknowable, keep
    [ -d "$path" ] && continue
    n=$((n + 1))
    [ -n "$CLEAN_DRY" ] || _clean_rm "$d"
  done
  [ "$n" -gt 0 ] && printf '  %-26s %s\n' "$label" "$n orphaned"
  return 0
}

# Purge Claude Code per-project session transcripts (.jsonl) and working dirs
# (UUID-named); auto memory is handled separately from project instructions.
_clean_cc_projects() {
  local pdir="${1:-$HOME/.claude/projects}" n=0 f d
  [ -d "$pdir" ] || return 0
  for f in "$pdir"/*/*.jsonl; do
    [ -f "$f" ] || continue
    n=$((n + 1))
    [ -n "$CLEAN_DRY" ] || _clean_rm "$f"
  done
  for d in "$pdir"/*/[0-9a-f][0-9a-f]??????-????-????-????-????????????/; do
    [ -d "$d" ] || continue
    n=$((n + 1))
    [ -n "$CLEAN_DRY" ] || _clean_rm "$d"
  done
  [ "$n" -gt 0 ] && printf '  %-26s %s\n' "cc project sessions" "$n items"
  return 0
}

# shortcut: only default user-level Claude memories are covered; add custom or project-scoped stores if used.
_clean_cc_memories() {
  local cc="${1:-$HOME/.claude}" root dir resolved links
  [ -d "$cc" ] && [ ! -L "$cc" ] || return 0
  root=$(realpath -e -- "$cc" 2>/dev/null) || return 1
  for dir in "$cc"/projects/*/memory "$cc"/agent-memory; do
    [ -d "$dir" ] || continue
    resolved=$(realpath -e -- "$dir" 2>/dev/null) || continue
    if [ -L "$dir" ] || [ "$resolved" != "$root/${dir#"$cc"/}" ]; then
      printf '  %-26s %s\n' "cc memories" "skipped linked path: $dir"
      continue
    fi
    links=$(find "$resolved" -type l -print -quit 2>/dev/null) || continue
    if [ -n "$links" ]; then
      printf '  %-26s %s\n' "cc memories" "skipped linked contents: $dir"
      continue
    fi
    printf '  %-26s %s\n' "cc memories" "${dir#$HOME/}"
    if [ -z "$CLEAN_DRY" ] && ! command rm -rf -- "$resolved"; then
      printf '  %-26s %s\n' "cc memories" "failed to remove: $dir" >&2
    fi
  done
}

# Remove orphaned plugin versions only after checking the installed registry.
_clean_cc_plugin_cache() {
  local plugins="${1:-$HOME/.claude/plugins}" cache installed paths="" d path canonical links n=0
  [ -d "$plugins/cache" ] || return 0
  if [ -L "$plugins" ] || [ -L "$plugins/cache" ]; then
    echo "  cc orphaned plugins        skipped: cache path is a link"
    return 0
  fi
  if ! command -v jq >/dev/null 2>&1 || ! command -v cygpath >/dev/null 2>&1 ||
     ! cache=$(realpath -e -- "$plugins/cache" 2>/dev/null); then
    echo "  cc orphaned plugins        skipped: jq, cygpath or cache unavailable"
    return 0
  fi
  installed=$(jq -er '
    if (.plugins | type) == "object" and all(.plugins[]; type == "array") then
      [.plugins[][] | .installPath |
        if type == "string" and length > 0 and (contains("\n") | not) then .
        else error("invalid installPath") end] | join("\n")
    else error("invalid plugins") end' "$plugins/installed_plugins.json" 2>/dev/null) || {
    echo "  cc orphaned plugins        skipped: cannot read installed plugins"
    return 0
  }
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    canonical=$(cygpath -u "$path" 2>/dev/null) && canonical=$(realpath -e -- "$canonical" 2>/dev/null) &&
      canonical=$(cygpath -m "$canonical" 2>/dev/null) || {
      echo "  cc orphaned plugins        skipped: cannot resolve installed plugin"
      return 0
    }
    paths+="$canonical"$'\n'
  done <<< "$installed"
  for d in "$plugins"/cache/*/*/*; do
    [ -d "$d" ] && [ ! -L "$d" ] && [ -f "$d/.orphaned_at" ] && [ ! -L "$d/.orphaned_at" ] || continue
    canonical=$(realpath -e -- "$d" 2>/dev/null) || continue
    [ "$canonical" = "$cache/${d#"$plugins"/cache/}" ] || continue
    path=$(cygpath -m "$canonical" 2>/dev/null) || continue
    printf '%s' "$paths" | grep -Fxiq -- "$path" && continue
    links=$(find "$canonical" -type l -print -quit 2>/dev/null) || continue
    [ -z "$links" ] || continue
    n=$((n + 1))
    [ -n "$CLEAN_DRY" ] || _clean_rm "$canonical"
  done
  [ "$n" -gt 0 ] && printf '  %-26s %s\n' "cc orphaned plugins" "$n versions"
  return 0
}

# Claude Code writes ~/.claude/sessions/<pid>.json (a Windows pid) for each
# running session. Print "<pid> (<image>)" for every one whose process is still
# alive, so `clean -f` can refuse instead of deleting that session's own
# transcript. A crash leaves a file naming a dead pid, which is not listed; the
# image check keeps a pid that Windows has since reused from counting.
_clean_live_claude() {
  local f pid img
  for f in "${1:-$HOME/.claude/sessions}"/*.json; do
    [ -f "$f" ] || continue
    pid=$(sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$f")
    [ -n "$pid" ] || continue
    img=$(tasklist //FI "PID eq $pid" //NH //FO CSV 2>/dev/null | sed -n 's/^"\(claude\|node\)\.exe".*/\1.exe/p')
    [ -n "$img" ] && printf '%s (%s)\n' "$pid" "$img"
  done
  return 0
}

# shortcut: only native Codex/OpenCode process names are detected; extend if their launchers change.
_clean_live_other_ai() {
  local processes
  processes=$(tasklist //NH //FO CSV 2>/dev/null) || return 1
  printf '%s\n' "$processes" | sed -nE 's/^"((codex|opencode)(-[^"]*)?\.exe)","([0-9]+)".*/\1 (\4)/Ip'
}

# _clean_temp <dir> [label] - files in <dir> older than CLEAN_TEMP_DAYS. `find -mtime +3`
# means 4 or more full days, hence the +1 in the label. This is the biggest
# delete in clean, so a dry run names the files (first 20).
_clean_temp() {
  local list n
  [ -d "$1" ] || return 0
  list=$(find "$1" -mindepth 1 -mtime "+$CLEAN_TEMP_DAYS" -type f -printf '%P\n' 2>/dev/null)
  n=$(printf '%s' "$list" | grep -c .)
  printf '  %-26s %s\n' "${2:-temp}" "$n files at least $((CLEAN_TEMP_DAYS + 1))d old"
  if [ -n "$CLEAN_DRY" ]; then
    printf '%s\n' "$list" | head -n 20 | sed -n 's/^./      &/p'
    [ "$n" -gt 20 ] && printf '      ... and %s more\n' "$((n - 20))"
    return 0
  fi
  # Files first, then the old directories that are empty; anything a running
  # process still holds open simply fails and is left in place.
  find "$1" -mindepth 1 -mtime "+$CLEAN_TEMP_DAYS" -type f -delete 2>/dev/null
  find "$1" -mindepth 1 -mtime "+$CLEAN_TEMP_DAYS" -type d -empty -delete 2>/dev/null
}

# Enumerate root sessions across projects; OpenCode deletes each root's children.
_clean_opencode_sessions() {
  local json ids id n=0 failed=0
  command -v opencode >/dev/null 2>&1 || return 0
  command -v jq >/dev/null 2>&1 || { echo "  opencode sessions          skipped: jq unavailable"; return 0; }
  json=$(opencode --pure db --format json 'SELECT s.id FROM session AS s LEFT JOIN session AS parent ON parent.id = s.parent_id WHERE s.parent_id IS NULL OR parent.id IS NULL' 2>/dev/null) || {
    echo "  opencode sessions          skipped: cannot list sessions"; return 0;
  }
  ids=$(printf '%s\n' "$json" | jq -er '
    if type == "array" and all(.[]; (.id | type) == "string" and (.id | test("^ses_[A-Za-z0-9]+$")))
    then [.[].id] | join("\n") else error("invalid session list") end' 2>/dev/null) || {
    echo "  opencode sessions          skipped: invalid session list"; return 0;
  }
  while IFS= read -r id; do
    id=${id%$'\r'}
    [ -n "$id" ] || continue
    if [ -n "$CLEAN_DRY" ]; then
      n=$((n + 1))
    elif opencode --pure session delete "$id" >/dev/null 2>&1; then
      n=$((n + 1))
    else
      failed=$((failed + 1))
    fi
  done <<< "$ids"
  if [ "$n" -gt 0 ] || [ "$failed" -gt 0 ]; then
    if [ -n "$CLEAN_DRY" ]; then
      printf '  %-26s %s\n' "opencode sessions" "$n sessions"
    else
      printf '  %-26s %s\n' "opencode sessions" "$n deleted, $failed kept"
    fi
  fi
  return 0
}

# shortcut: requires Codex app-server memory/reset and thread/list with UUID IDs; update if the protocol changes.
_clean_codex_app_server() {
  python - "$1" <<'PY'
import json, queue, shutil, subprocess, sys, threading, uuid

server = None
ids = {}
try:
    mode = sys.argv[1]
    if mode not in ("sessions", "memories"):
        raise ValueError("unknown cleanup mode")
    server = subprocess.Popen([shutil.which("codex"), "app-server"], stdin=subprocess.PIPE,
                              stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, encoding="utf-8")
    lines = queue.Queue()
    def read_output():
        try:
            for line in server.stdout:
                lines.put(line)
        finally:
            lines.put(None)
    threading.Thread(target=read_output, daemon=True).start()
    request_id = 0
    def request(method, params):
        global request_id
        request_id += 1
        server.stdin.write(json.dumps({"id": request_id, "method": method, "params": params}) + "\n")
        server.stdin.flush()
        while True:
            line = lines.get(timeout=30)
            if line is None:
                raise RuntimeError("app server closed")
            message = json.loads(line)
            if message.get("id") != request_id or "method" in message:
                continue
            if "error" in message:
                raise RuntimeError("app server request failed")
            return message["result"]
    init = {"clientInfo": {"name": "clean", "version": "1"}}
    if mode == "memories":
        init["capabilities"] = {"experimentalApi": True}
    request("initialize", init)
    server.stdin.write('{"method":"initialized"}\n')
    server.stdin.flush()
    if mode == "memories":
        if not isinstance(request("memory/reset", None), dict):
            raise ValueError("invalid memory reset response")
    else:
        kinds = ["cli", "vscode", "exec", "appServer", "subAgent", "subAgentReview",
                 "subAgentCompact", "subAgentThreadSpawn", "subAgentOther", "unknown"]
        for archived in (False, True):
            cursor, seen = None, set()
            while True:
                params = {"limit": 100, "archived": archived, "sourceKinds": kinds}
                if cursor is not None:
                    params["cursor"] = cursor
                page = request("thread/list", params)
                if not isinstance(page.get("data"), list):
                    raise ValueError("invalid session list")
                for item in page["data"]:
                    session_id = item["id"]
                    if str(uuid.UUID(session_id)) != session_id.lower():
                        raise ValueError("invalid session id")
                    ids[session_id] = isinstance(item.get("source"), dict)
                cursor = page.get("nextCursor")
                if cursor is None:
                    break
                if not isinstance(cursor, str) or not cursor or cursor in seen:
                    raise ValueError("invalid session cursor")
                seen.add(cursor)
except Exception:
    sys.exit(1)
finally:
    if server is not None:
        try:
            server.stdin.close()
            server.wait(timeout=5)
        except (OSError, subprocess.TimeoutExpired):
            server.terminate()
            server.wait(timeout=5)
for session_id in sorted(ids, key=lambda item: not ids[item]):
    sys.stdout.buffer.write((session_id + "\n").encode("ascii"))
PY
}

# Let Codex delete sessions so its transcript and database stores stay in sync.
_clean_codex_sessions() {
  local ids id n=0 failed=0
  command -v codex >/dev/null 2>&1 || return 0
  command -v python >/dev/null 2>&1 || { echo "  codex sessions             skipped: python unavailable"; return 0; }
  ids=$(_clean_codex_app_server sessions) || { echo "  codex sessions             skipped: cannot list sessions"; return 0; }
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if [ -n "$CLEAN_DRY" ]; then
      n=$((n + 1))
    elif codex delete --force "$id" >/dev/null 2>&1; then
      n=$((n + 1))
    else
      failed=$((failed + 1))
    fi
  done <<< "$ids"
  if [ "$n" -gt 0 ] || [ "$failed" -gt 0 ]; then
    if [ -n "$CLEAN_DRY" ]; then
      printf '  %-26s %s\n' "codex sessions" "$n sessions"
    else
      printf '  %-26s %s\n' "codex sessions" "$n deleted, $failed failed or already removed"
    fi
  fi
  return 0
}

# Codex owns its memory database; its reset also clears Computer History where available.
_clean_codex_memories() {
  command -v codex >/dev/null 2>&1 || return 0
  command -v python >/dev/null 2>&1 || { echo "  codex memories             skipped: python unavailable"; return 1; }
  if [ -n "$CLEAN_DRY" ]; then
    printf '  %-26s %s\n' "codex memories" "reset local memory"
  elif _clean_codex_app_server memories; then
    printf '  %-26s %s\n' "codex memories" "reset"
  else
    printf '  %-26s %s\n' "codex memories" "reset failed or unconfirmed" >&2
    return 1
  fi
}

# clean_selfcheck - the helpers above decide what to delete by parsing text
# and file ages, so prove they prune only what is really dead. Run it by hand after
# touching them; nothing calls it automatically. Works on a fake tree, never
# on your real caches.
clean_selfcheck() {
  local t win rc=0 CLEAN_DRY="" CLEAN_TEMP_DAYS=3 live d status uuid=8bae70a1-b346-4bbb-bdc0-db1228974670
  t=$(mktemp -d "$HOME/.clean-selfcheck.XXXXXX") || return 1
  win="${t#/}"; win="${win%%/*}:/${t#/*/}"   # /c/Users/x -> c:/Users/x, as VSCodium writes it

  mkdir -p "$t/live" "$t/ws/keep-live" "$t/ws/prune-dead" "$t/ws/keep-nojson" \
           "$t/ws/keep-badescape" "$t/ws/keep-nodrive"
  printf '{"folder":"file:///%s/live"}\n' "${win//:/%3A}"  > "$t/ws/keep-live/workspace.json"
  printf '{"folder":"file:///%s/gone"}\n' "${win//:/%3A}"  > "$t/ws/prune-dead/workspace.json"
  printf '{"folder":"file:///c%%3A/caf%%E9"}\n'            > "$t/ws/keep-badescape/workspace.json"
  printf '{"folder":"file:///q%%3A/nope"}\n'               > "$t/ws/keep-nodrive/workspace.json"
  _clean_ws_orphans "$t/ws" >/dev/null
  for d in keep-live keep-nojson keep-badescape keep-nodrive; do
    [ -d "$t/ws/$d" ] || { echo "FAIL ws_orphans: deleted $d"; rc=1; }
  done
  [ -d "$t/ws/prune-dead" ] && { echo "FAIL ws_orphans: kept a dead workspace"; rc=1; }

  mkdir -p "$t/projects/p/$uuid" "$t/projects/p/memory"
  : > "$t/projects/p/session.jsonl"; : > "$t/projects/p/memory/keep.md"
  : > "$t/projects/p/CLAUDE.md"
  _clean_cc_projects "$t/projects" >/dev/null
  [ -f "$t/projects/p/session.jsonl" ] && { echo "FAIL cc_projects: kept a transcript"; rc=1; }
  [ -d "$t/projects/p/$uuid" ]         && { echo "FAIL cc_projects: kept a session dir"; rc=1; }
  [ -f "$t/projects/p/memory/keep.md" ] || { echo "FAIL cc_projects: deleted memory"; rc=1; }
  [ -f "$t/projects/p/CLAUDE.md" ]      || { echo "FAIL cc_projects: deleted CLAUDE.md"; rc=1; }

  mkdir -p "$t/cc/projects/p/memory" "$t/cc/agent-memory/agent"
  : > "$t/cc/projects/p/memory/MEMORY.md"; : > "$t/cc/agent-memory/agent/MEMORY.md"
  : > "$t/cc/projects/p/CLAUDE.md"
  CLEAN_DRY=1
  _clean_cc_memories "$t/cc" >/dev/null
  [ -f "$t/cc/projects/p/memory/MEMORY.md" ] && [ -f "$t/cc/agent-memory/agent/MEMORY.md" ] ||
    { echo "FAIL cc_memories: dry run deleted memory"; rc=1; }
  CLEAN_DRY=""
  _clean_cc_memories "$t/cc" >/dev/null
  [ ! -e "$t/cc/projects/p/memory" ] && [ ! -e "$t/cc/agent-memory" ] && [ -f "$t/cc/projects/p/CLAUDE.md" ] ||
    { echo "FAIL cc_memories: wrong files removed"; rc=1; }

  mkdir -p "$t/plugins/cache/market/plugin/"{old,installed,unmarked}
  : > "$t/plugins/cache/market/plugin/old/.orphaned_at"
  : > "$t/plugins/cache/market/plugin/installed/.orphaned_at"
  win=$(cygpath -m "$t/plugins/cache/market/plugin/installed")
  printf '{"plugins":{"active":[{"installPath":"%s"}]}}\n' "$win" > "$t/plugins/installed_plugins.json"
  CLEAN_DRY=1
  _clean_cc_plugin_cache "$t/plugins" | grep -q '1 versions' || { echo "FAIL plugin_cache: dry run count"; rc=1; }
  [ -d "$t/plugins/cache/market/plugin/old" ] || { echo "FAIL plugin_cache: dry run deleted a version"; rc=1; }
  CLEAN_DRY=""
  _clean_cc_plugin_cache "$t/plugins" >/dev/null
  [ -d "$t/plugins/cache/market/plugin/old" ] && { echo "FAIL plugin_cache: kept orphan"; rc=1; }
  [ -d "$t/plugins/cache/market/plugin/installed" ] || { echo "FAIL plugin_cache: deleted installed version"; rc=1; }
  [ -d "$t/plugins/cache/market/plugin/unmarked" ] || { echo "FAIL plugin_cache: deleted unmarked version"; rc=1; }
  mkdir -p "$t/plugins/cache/market/plugin/unknown"
  : > "$t/plugins/cache/market/plugin/unknown/.orphaned_at"
  printf 'invalid json\n' > "$t/plugins/installed_plugins.json"
  _clean_cc_plugin_cache "$t/plugins" >/dev/null
  [ -d "$t/plugins/cache/market/plugin/unknown" ] || { echo "FAIL plugin_cache: deleted with bad registry"; rc=1; }
  printf '{"plugins":{"active":[{"installPath":"C:/missing-plugin"}]}}\n' > "$t/plugins/installed_plugins.json"
  _clean_cc_plugin_cache "$t/plugins" >/dev/null
  [ -d "$t/plugins/cache/market/plugin/unknown" ] || { echo "FAIL plugin_cache: deleted with missing install"; rc=1; }

  (
    opencode() {
      if [ "$2" = db ]; then printf '[{"id":"ses_a"},{"id":"ses_b"}]\n'
      elif [ "$2" = session ] && [ "$3" = delete ]; then printf '%s\n' "$4" >> "$t/opencode-calls"
      else return 1; fi
    }
    CLEAN_DRY=1
    live=$(_clean_opencode_sessions)
    [[ $live == *'2 sessions'* ]] && [ ! -e "$t/opencode-calls" ] || exit 1
    CLEAN_DRY=""
    live=$(_clean_opencode_sessions)
    [[ $live == *'2 deleted, 0 kept'* ]] && [ "$(< "$t/opencode-calls")" = $'ses_a\nses_b' ] || exit 1
    opencode() {
      if [ "$2" = db ]; then printf '[{"id":"ses_a"},{"id":"ses_b"}]\n'
      elif [ "$2" = session ] && [ "$3" = delete ]; then [ "$4" != ses_b ]
      else return 1; fi
    }
    live=$(_clean_opencode_sessions)
    [[ $live == *'1 deleted, 1 kept'* ]] || exit 1
    : > "$t/opencode-calls"
    opencode() { [ "$2" = db ] && { echo invalid; return; }; echo unexpected >> "$t/opencode-calls"; }
    _clean_opencode_sessions >/dev/null
    [ ! -s "$t/opencode-calls" ]
  ) || { echo "FAIL opencode_sessions: preview, deletion, or invalid list"; rc=1; }

  (
    _clean_codex_app_server() { [ "$1" = sessions ] || return 1; printf '%s\n' 11111111-1111-4111-8111-111111111111 22222222-2222-4222-8222-222222222222; }
    codex() { [ "$1" = delete ] && [ "$2" = --force ] || return 1; printf '%s\n' "$3" >> "$t/codex-calls"; }
    CLEAN_DRY=1
    live=$(_clean_codex_sessions)
    [[ $live == *'2 sessions'* ]] && [ ! -e "$t/codex-calls" ] || exit 1
    CLEAN_DRY=""
    live=$(_clean_codex_sessions)
    [[ $live == *'2 deleted, 0 failed'* ]] && [ "$(< "$t/codex-calls")" = $'11111111-1111-4111-8111-111111111111\n22222222-2222-4222-8222-222222222222' ] || exit 1
    codex() { [ "$3" != 22222222-2222-4222-8222-222222222222 ]; }
    live=$(_clean_codex_sessions)
    [[ $live == *'1 deleted, 1 failed'* ]] || exit 1
    : > "$t/codex-calls"
    codex() { echo unexpected >> "$t/codex-calls"; }
    _clean_codex_app_server() { return 1; }
    _clean_codex_sessions >/dev/null
    [ ! -s "$t/codex-calls" ]
  ) || { echo "FAIL codex_sessions: preview, deletion, or failed list"; rc=1; }

  (
    codex() { :; }
    _clean_codex_app_server() { printf '%s\n' "$1" >> "$t/memory-calls"; [ "$1" = memories ]; }
    CLEAN_DRY=1
    live=$(_clean_codex_memories)
    [[ $live == *'reset local memory'* ]] && [ ! -e "$t/memory-calls" ] || exit 1
    CLEAN_DRY=""
    live=$(_clean_codex_memories)
    [[ $live == *'reset'* ]] && [ "$(< "$t/memory-calls")" = memories ] || exit 1
    _clean_codex_app_server() { return 1; }
    _clean_codex_memories >/dev/null 2>&1 && exit 1
    exit 0
  ) || { echo "FAIL codex_memories: preview, reset, or failed reset"; rc=1; }

  mkdir -p "$t/tmp/mixed"
  : > "$t/tmp/old.txt"; : > "$t/tmp/fresh.txt"; : > "$t/tmp/edge.txt"
  : > "$t/tmp/mixed/old.txt"; : > "$t/tmp/mixed/fresh.txt"
  touch -d '6 days ago' "$t/tmp/old.txt" "$t/tmp/mixed/old.txt"
  touch -d '1 day ago' "$t/tmp/fresh.txt" "$t/tmp/mixed/fresh.txt"
  touch -d '3 days 12 hours ago' "$t/tmp/edge.txt"   # under 4 full days: find keeps it
  CLEAN_DRY=1
  _clean_temp "$t/tmp" | grep -q 'old.txt' || { echo "FAIL temp: dry run did not name an old file"; rc=1; }
  _clean_temp "$t/tmp" "codex plugin staging" | grep -q 'codex plugin staging' || { echo "FAIL temp: lost custom label"; rc=1; }
  [ -f "$t/tmp/old.txt" ] || { echo "FAIL temp: dry run deleted a file"; rc=1; }
  CLEAN_DRY=""
  _clean_temp "$t/tmp" >/dev/null
  { [ -f "$t/tmp/old.txt" ] || [ -f "$t/tmp/mixed/old.txt" ]; } && { echo "FAIL temp: kept an old file"; rc=1; }
  { [ -f "$t/tmp/fresh.txt" ] && [ -f "$t/tmp/mixed/fresh.txt" ] && [ -f "$t/tmp/edge.txt" ]; } ||
    { echo "FAIL temp: deleted a file that is not old enough"; rc=1; }

  mkdir -p "$t/sessions"
  printf '{"pid":111,"sessionId":"a"}\n' > "$t/sessions/111.json"
  printf '{"pid":222,"sessionId":"b"}\n' > "$t/sessions/222.json"
  tasklist() { [ "$2" = "PID eq 111" ] && printf '"claude.exe","111","Console","1","1 K"\r\n'; }   # only pid 111 is alive
  live=$(_clean_live_claude "$t/sessions")
  unset -f tasklist
  [ "$live" = "111 (claude.exe)" ] || { echo "FAIL live_claude: wanted '111 (claude.exe)', got '$live'"; rc=1; }

  tasklist() { printf '"codex.exe","333","Console","1","1 K"\n"opencode-windows-x64.exe","444","Console","1","1 K"\n"editor.exe","555","Console","1","1 K"\n'; }
  live=$(_clean_live_other_ai)
  [ "$live" = $'codex.exe (333)\nopencode-windows-x64.exe (444)' ] || { echo "FAIL live_other_ai: wrong processes: $live"; rc=1; }
  tasklist() { return 1; }
  _clean_live_other_ai >/dev/null && { echo "FAIL live_other_ai: ignored tasklist failure"; rc=1; }
  unset -f tasklist
  live=$(
    _clean_live_claude() { :; }
    _clean_live_other_ai() { echo 'codex.exe (333)'; }
    _clean_free() { echo 0; }
    _hr() { exit 42; }
    clean -f 2>&1
  ); status=$?
  [ "$status" = 1 ] && [[ $live == *'Codex/OpenCode is still running'* ]] || { echo "FAIL clean: did not stop for Codex"; rc=1; }
  live=$(
    _clean_live_claude() { :; }
    _clean_live_other_ai() { return 1; }
    _clean_free() { echo 0; }
    _hr() { exit 42; }
    clean -f 2>&1
  ); status=$?
  [ "$status" = 1 ] && [[ $live == *'cannot check Codex/OpenCode processes'* ]] || { echo "FAIL clean: did not stop on process check failure"; rc=1; }

  command rm -rf -- "$t"
  [ "$rc" = 0 ] && echo "clean_selfcheck: all checks passed"
  return "$rc"
}

clean() {
  local CLEAN_DRY=1 before after freed live
  local la="$HOME/AppData/Local" ra="$HOME/AppData/Roaming"
  if [ "$1" = "-f" ]; then
    live=$(_clean_live_claude)
    [ -z "$live" ] || { echo "clean -f: Claude Code is still running: ${live//$'\n'/, }. Close it first; bare 'clean' only lists." >&2; return 1; }
    live=$(_clean_live_other_ai) || { echo "clean -f: cannot check Codex/OpenCode processes; aborting." >&2; return 1; }
    [ -z "$live" ] || { echo "clean -f: Codex/OpenCode is still running: ${live//$'\n'/, }. Close it first; bare 'clean' only lists." >&2; return 1; }
    CLEAN_DRY=""
  fi
  before=$(_clean_free)

  _hr "${CLEAN_DRY:+DRY RUN - }Package manager caches"
  _clean_tool "npm"                 "$la/npm-cache"          npm cache clean --force
  _clean_tool "uv"                  "$la/uv/cache"           uv cache clean
  _clean_tool "pip"                 "$la/pip/Cache"          python -m pip cache purge
  _clean_gone "yarn (uninstalled)"  "$la/Yarn"               yarn

  _hr "Build caches"
  _clean_dir  "electron"            "$la/electron/Cache"
  _clean_dir  "electron-builder"    "$la/electron-builder"
  _clean_dir  "node-gyp headers"    "$la/node-gyp/Cache"

  _hr "Language toolchain caches"
  _clean_dir  "pub packages"        "$la/Pub/Cache/hosted"
  _clean_dir  "pub hashes"          "$la/Pub/Cache/hosted-hashes"
  _clean_dir  "pub temp"            "$la/Pub/Cache/_temp"
  _clean_dir  "dart analysis"       "$la/.dartServer"
  _clean_dir  "jxbrowser chromium"  "$la/JxBrowser-x64"
  _clean_dir  "jxbrowser chromium"  "$la/JxBrowser"

  _hr "Browser / MCP caches"
  _clean_dir  "chrome cache"        "$la/Google/Chrome/User Data/Default/Cache"
  _clean_dir  "chrome code cache"   "$la/Google/Chrome/User Data/Default/Code Cache"
  _clean_dir  "chrome gpu cache"    "$la/Google/Chrome/User Data/Default/GPUCache"
  _clean_dir  "chrome shader cache" "$la/Google/Chrome/User Data/GrShaderCache"
  _clean_dir  "edge cache"          "$la/Microsoft/Edge/User Data/Default/Cache"
  _clean_dir  "edge code cache"     "$la/Microsoft/Edge/User Data/Default/Code Cache"
  _clean_dir  "edge gpu cache"      "$la/Microsoft/Edge/User Data/Default/GPUCache"
  # Browser binaries: versioned, re-downloadable, and slow to fetch again.
  # Wiped on purpose -- the next playwright/puppeteer run re-installs them.
  _clean_dir  "playwright browsers" "$la/ms-playwright"
  _clean_dir  "playwright-go"       "$la/ms-playwright-go"
  _clean_dir  "playwright-mcp"      "$la/ms-playwright-mcp"
  _clean_dir  "puppeteer browsers"  "$HOME/.cache/puppeteer"
  _clean_dir  "chrome-devtools-mcp" "$la/chrome-devtools-mcp"
  _clean_dir  "chrome-devtools-mcp" "$HOME/.cache/chrome-devtools-mcp"
  _clean_dir  "codebase-memory-mcp" "$HOME/.cache/codebase-memory-mcp"

  _hr "Communication app caches"
  _clean_dir  "zoom data"           "$ra/Zoom/data"
  _clean_dir  "zoom logs"           "$ra/Zoom/logs"
  _clean_dir  "zoom reports"        "$ra/Zoom/reports"
  _clean_dir  "zoom download"       "$ra/Zoom/ZoomDownload"
  _clean_dir  "webex cache"         "$la/WebEx"
  _clean_dir  "cisco spark"         "$la/CiscoSpark"

  _hr "Desktop app caches"
  _clean_dir  "postman cache"       "$ra/Postman/Cache"
  _clean_dir  "postman code cache"  "$ra/Postman/Code Cache"
  _clean_dir  "postman crashpad"    "$ra/Postman/Crashpad"
  _clean_dir  "box cache"           "$la/Box/Box/cache"
  _clean_dir  "box logs"            "$la/Box/Box/logs"
  _clean_dir  "box office logs"     "$la/Box/BoxForOfficeLogs"
  _clean_dir  "devtoys webview2"    "$la/DevToys.WebView2"
  _clean_dir  "adobe acrocef"       "$la/Adobe/AcroCef"
  _clean_dir  "citrix telemetry"    "$la/Citrix/CitrixTelemetry"
  _clean_dir  "citrix analytics"    "$la/Citrix/Analytics"

  _hr "AI / dev tool caches"
  _clean_dir  "rtk tee"             "$la/rtk/tee"
  # Orca is Electron: same cache layout as the VSCodium entries above.
  _clean_dir  "orca cache"          "$ra/orca/Cache"
  _clean_dir  "orca code cache"     "$ra/orca/Code Cache"
  _clean_dir  "orca gpu cache"      "$ra/orca/GPUCache"
  _clean_dir  "orca dawn cache"     "$ra/orca/DawnGraphiteCache"
  _clean_dir  "orca dawn cache"     "$ra/orca/DawnWebGPUCache"
  _clean_dir  "orca blob storage"   "$ra/orca/blob_storage"
  _clean_dir  "orca crashpad"       "$ra/orca/Crashpad"
  _clean_dir  "orca logs"           "$ra/orca/logs"
  # Downloaded installer (~210M), re-fetched by the updater when needed.
  _clean_file "orca installer"      "$la/orca-updater/installer.exe"

  _hr "System caches"
  _clean_dir  "d3d shader cache"    "$la/D3DSCache"
  _clean_dir  "squirrel temp"       "$la/SquirrelTemp"

  _hr "Editor caches"
  _clean_dir  "vscode cache"        "$ra/Code/Cache"
  _clean_dir  "vscode cacheddata"   "$ra/Code/CachedData"
  _clean_dir  "vscode vsix"         "$ra/Code/CachedExtensionVSIXs"
  _clean_dir  "vscode logs"         "$ra/Code/logs"
  _clean_ws_orphans                 "$ra/Code/User/workspaceStorage" "vscode workspaces"
  _clean_dir  "vscodium cache"      "$ra/VSCodium/Cache"
  _clean_dir  "vscodium cacheddata" "$ra/VSCodium/CachedData"
  _clean_dir  "vscodium profiles"   "$ra/VSCodium/CachedProfilesData"
  _clean_dir  "vscodium vsix"       "$ra/VSCodium/CachedExtensionVSIXs"
  _clean_dir  "vscodium gpu cache"  "$ra/VSCodium/GPUCache"
  _clean_dir  "vscodium dawn cache" "$ra/VSCodium/DawnGraphiteCache"
  _clean_dir  "vscodium dawn cache" "$ra/VSCodium/DawnWebGPUCache"
  _clean_dir  "vscodium code cache" "$ra/VSCodium/Code Cache"
  _clean_dir  "vscodium logs"       "$ra/VSCodium/logs"
  _clean_ws_orphans                 "$ra/VSCodium/User/workspaceStorage" "vscodium workspaces"

  _hr "Claude Code caches"
  local cc="$HOME/.claude"
  _clean_dir  "cc cache"              "$cc/cache"
  _clean_dir  "cc debug"              "$cc/debug"
  _clean_dir  "cc paste-cache"        "$cc/paste-cache"
  _clean_dir  "cc plans"              "$cc/plans"
  _clean_dir  "cc sessions"           "$cc/sessions"
  _clean_dir  "cc telemetry"          "$cc/telemetry"
  _clean_dir  "cc backups"            "$cc/backups"
  _clean_dir  "cc file-history"       "$cc/file-history"
  _clean_dir  "cc shell-snapshots"    "$cc/shell-snapshots"
  _clean_dir  "cc session-env"        "$cc/session-env"
  _clean_dir  "cc tasks"              "$cc/tasks"
  _clean_dir  "cc daemon"             "$cc/daemon"
  _clean_dir  "cc jobs"               "$cc/jobs"
  _clean_dir  "cc cli-nodejs"         "$la/claude-cli-nodejs"
  _clean_cc_projects
  _clean_cc_memories
  _clean_cc_plugin_cache

  _hr "OpenCode caches"
  local oc_data="${XDG_DATA_HOME:-$HOME/.local/share}/opencode"
  local oc_state="${XDG_STATE_HOME:-$HOME/.local/state}/opencode"
  _clean_opencode_sessions
  _clean_dir  "opencode logs"          "$oc_data/log"
  _clean_dir  "opencode snapshots"     "$oc_data/snapshot"
  _clean_dir  "opencode locks"         "$oc_state/locks"
  _clean_dir  "opencode temp"          "$la/Temp/opencode"

  _hr "Codex caches"
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  _clean_codex_sessions
  _clean_codex_memories
  _clean_dir  "codex cache"            "$codex_home/cache"
  _clean_file "codex models cache"     "$codex_home/models_cache.json"
  _clean_dir  "codex staging"          "$codex_home/.tmp"
  _clean_dir  "codex temp"             "$codex_home/tmp"
  _clean_dir  "codex logs"             "$codex_home/log"
  _clean_dir  "codex shell snapshots"  "$codex_home/shell_snapshots"
  _clean_dir  "codex tui refs"         "$codex_home/tui-thread-reference-capabilities"
  _clean_temp "$codex_home/plugins/.marketplace-plugin-source-staging" "codex plugin sources"
  _clean_temp "$codex_home/plugins/.remote-plugin-install-staging" "codex plugin installs"

  _hr "Temp + dumps"
  _clean_dir  "crash dumps"         "$la/CrashDumps"
  _clean_temp "$la/Temp"

  if [ -n "$CLEAN_DRY" ]; then
    _hr "Nothing deleted. Run 'clean -f' to do it."
  else
    after=$(_clean_free)
    # Free space is the whole of C:, so anything else writing during the run
    # can outweigh what we deleted. Report 0 rather than a negative "reclaimed".
    freed=$(( after - before ))
    [ "$freed" -lt 0 ] && freed=0
    _hr "Reclaimed $freed MB -- $(( after / 1024 )) GB free on C:"
  fi
}
