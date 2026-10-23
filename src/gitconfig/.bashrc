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
# `clean` only, not `clean -f`: a forced clean deletes live Claude/OpenCode/
# Codex session state, and `init` is often run from inside one of them. You get
# the list, then run `clean -f` yourself once those tools are closed.
alias init='work && clean && verup && ver'
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
  echo "GitHubCLI: $(_ver gh --version)"
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

# Git, VSCodium and Node come from their own installers and Python from
# PyManager, so `verup` never touches them and they go stale unnoticed.
# Both checks hit the network (~3s), so this runs from `ver` on demand, never
# at shell startup. One winget call covers all three winget-owned tools.
_ver_updates() {
  local out pair label id cur latest
  command -v winget >/dev/null 2>&1 &&
    out=$(winget upgrade --accept-source-agreements 2>/dev/null)
  for pair in 'Git:Git.Git' \
              'VSCodium:VSCodium.VSCodium' \
              'Node:OpenJS.NodeJS.LTS' \
              'PyManager:Python.PythonInstallManager'; do
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
    echo "! Python $cur -> $latest (py install ${cur%.*} --upgrade)"
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
  _upd_pip
  _upd_uv
  _upd rustup rustup update
  _upd gh winget upgrade --id GitHub.cli -e --accept-source-agreements
  _upd rtk winget upgrade --id rtk-ai.rtk -e --accept-source-agreements
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

# Python installer (PyManager 3.14+) -> %LOCALAPPDATA%\Python\bin (python, pip shims)
[ -d "$HOME/AppData/Local/Python/bin" ] && PATH="$HOME/AppData/Local/Python/bin:$PATH"

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
#             also deletes local Claude/OpenCode/Codex session history; close
#             those tools first so their stores and runtime files are idle
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
#   WinGet\Packages           real installs live here (uv included), not a cache
#   JetBrains */caches,index  wiping these forces a full project re-index
#   node_modules              build input, not cache -- drop it per project
#   ~/.claude/projects/*/memory  per-project persistent memory
#   ~/.claude/projects/*/CLAUDE.md, settings*, scheduled_tasks.json
#   ~/.claude/plugins         installed Claude Code plugins
#   ~/.claude/skills          custom skills
#   ~/.claude/hooks           user hook scripts
#   ~/.claude/ide             IDE integration config
#   ~/.claude/security        security settings
#   ~/.claude/CLAUDE.md       user instructions
#   ~/.config/opencode        settings, plugins, and plugin dependencies
#   ~/.local/share/opencode/auth.json,opencode.db*  credentials and data store
#   ~/.codex/auth.json,config.toml,AGENTS.md,hooks.json  auth and configuration
#   ~/.codex/skills,plugins    installed Codex extensions
#   ~/.codex/*memories*.sqlite,goals_*.sqlite        persistent memory and goals
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
# (UUID-named) while keeping memory/, CLAUDE.md, settings, and scheduled tasks.
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

# Remove OpenCode sessions through its CLI so the SQLite store, child sessions,
# messages, and parts are deleted together instead of leaving dangling rows.
_clean_opencode_sessions() {
  local ids id n=0 failed=0
  command -v opencode >/dev/null 2>&1 || return 0
  ids=$(opencode --pure session list --format json 2>/dev/null |
    sed -n 's/^[[:space:]]*"id":[[:space:]]*"\([^"]*\)".*/\1/p') || return 0
  for id in $ids; do
    if [ -n "$CLEAN_DRY" ]; then
      n=$((n + 1))
    elif opencode --pure session delete "$id" >/dev/null 2>&1; then
      n=$((n + 1))
    else
      failed=$((failed + 1))
    fi
  done
  if [ "$n" -gt 0 ] || [ "$failed" -gt 0 ]; then
    if [ -n "$CLEAN_DRY" ]; then
      printf '  %-26s %s\n' "opencode sessions" "$n sessions"
    else
      printf '  %-26s %s\n' "opencode sessions" "$n deleted, $failed kept"
    fi
  fi
  return 0
}

# Codex keeps rollout files and SQLite thread metadata in sync. Extract each
# rollout UUID, then let `codex delete` remove it consistently. A live session
# may refuse deletion; count it as kept and continue cleaning other entries.
_clean_codex_sessions() {
  local cdir="$1/sessions" f id n=0 failed=0
  command -v codex >/dev/null 2>&1 || return 0
  [ -d "$cdir" ] || return 0
  while IFS= read -r -d '' f; do
    id=$(printf '%s\n' "${f##*/}" | sed -n \
      's/.*-\([0-9a-fA-F]\{8\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{12\}\)\.jsonl$/\1/p')
    [ -n "$id" ] || continue
    if [ -n "$CLEAN_DRY" ]; then
      n=$((n + 1))
    elif codex delete --force "$id" >/dev/null 2>&1; then
      n=$((n + 1))
    else
      failed=$((failed + 1))
    fi
  done < <(find "$cdir" -type f -name 'rollout-*.jsonl' -print0 2>/dev/null)
  if [ "$n" -gt 0 ] || [ "$failed" -gt 0 ]; then
    if [ -n "$CLEAN_DRY" ]; then
      printf '  %-26s %s\n' "codex sessions" "$n sessions"
    else
      printf '  %-26s %s\n' "codex sessions" "$n deleted, $failed kept"
    fi
  fi
  return 0
}

# clean_selfcheck - the two helpers above decide what to delete by parsing
# text, so prove they prune only what is really dead. Run it by hand after
# touching them; nothing calls it automatically. Works on a fake tree, never
# on your real caches.
clean_selfcheck() {
  local t win rc=0 CLEAN_DRY="" d uuid=8bae70a1-b346-4bbb-bdc0-db1228974670
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

  command rm -rf -- "$t"
  [ "$rc" = 0 ] && echo "clean_selfcheck: all checks passed"
  return "$rc"
}

clean() {
  local CLEAN_DRY=1 before after freed
  local la="$HOME/AppData/Local" ra="$HOME/AppData/Roaming"
  [ "$1" = "-f" ] && CLEAN_DRY=""
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

  _hr "OpenCode caches"
  local oc_cache="${XDG_CACHE_HOME:-$HOME/.cache}/opencode"
  local oc_data="${XDG_DATA_HOME:-$HOME/.local/share}/opencode"
  local oc_state="${XDG_STATE_HOME:-$HOME/.local/state}/opencode"
  _clean_opencode_sessions
  _clean_dir  "opencode cache"         "$oc_cache"
  _clean_dir  "opencode logs"          "$oc_data/log"
  _clean_dir  "opencode snapshots"     "$oc_data/snapshot"
  _clean_dir  "opencode locks"         "$oc_state/locks"
  _clean_dir  "opencode temp"          "$la/Temp/opencode"

  _hr "Codex caches"
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  _clean_codex_sessions "$codex_home"
  _clean_dir  "codex cache"            "$codex_home/cache"
  _clean_file "codex models cache"     "$codex_home/models_cache.json"
  _clean_dir  "codex staging"          "$codex_home/.tmp"
  _clean_dir  "codex temp"             "$codex_home/tmp"
  _clean_dir  "codex logs"             "$codex_home/log"
  _clean_dir  "codex shell snapshots"  "$codex_home/shell_snapshots"
  _clean_dir  "codex tui refs"         "$codex_home/tui-thread-reference-capabilities"

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
    # Free space is the whole of C:, so anything else writing during the run
    # can outweigh what we deleted. Report 0 rather than a negative "reclaimed".
    freed=$(( after - before ))
    [ "$freed" -lt 0 ] && freed=0
    _hr "Reclaimed $freed MB -- $(( after / 1024 )) GB free on C:"
  fi
}
