# Git Bash Configuration

Drop-in configuration for Git Bash on Windows: shell aliases, a branch-aware prompt, tab-completion
tuning, and one persistent `ssh-agent` so you type your key passphrase once per boot instead of once
per terminal.

For the day-to-day Git workflow these files enable, see [`../gitconfig.md`](../gitconfig.md). This
README covers **installing and configuring** them.

---

## Contents

| File                     | Copy to                        | What it does                                                        |
| ------------------------ | ------------------------------ | ------------------------------------------------------------------- |
| `.bashrc`                | `~/.bashrc`                    | Aliases, `ssh-agent` reuse, `ver`/`verup`, history and `PATH` setup |
| `.bashrc.local.example`  | `~/.bashrc.local`              | **Your** machine's values — key name, repo dir. Never committed     |
| `.bash_profile`          | `~/.bash_profile`              | Login shim: sources `~/.profile` then `~/.bashrc`                   |
| `.gitconfig`             | `~/.gitconfig`                 | Git behaviour: rebase-on-pull, prune-on-fetch, better diffs         |
| `.gitconfig.local.example` | `~/.gitconfig.local`         | **Your** name and email. Never committed                            |
| `.inputrc`               | `~/.inputrc`                   | Readline: cycling tab completion, prefix history search, no bells   |
| `git-prompt.sh`          | `~/.config/git/git-prompt.sh`  | Coloured prompt showing branch and dirty/stash/upstream state       |

`~` is your Windows user folder — `C:\Users\<you>`, which Git Bash shows as `/c/Users/<you>`.

---

## How the split works

`.bashrc` is written to be **byte-identical on every machine you use**. It contains no username and
no absolute path under `/c/Users`. Everything that genuinely varies per machine lives in
`~/.bashrc.local`.

Git config follows the identical pattern, so both halves of your setup work the same way:

```
~/.bashrc          <- same file everywhere; safe to commit to your dotfiles repo
~/.bashrc.local    <- one machine only; names your private key; NEVER commit

~/.gitconfig       <- same file everywhere; safe to commit
~/.gitconfig.local <- one machine only; holds your name and email; NEVER commit
```

`.bashrc` sources `.bashrc.local` **first**, then fills in defaults for anything it did not set:

```bash
[ -f ~/.bashrc.local ] && . ~/.bashrc.local

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
REPOS="${REPOS:-$HOME/repos}"
TOOLS="${TOOLS:-$HOME/Documents/Tools}"
```

`${VAR:-default}` means *use `VAR` if it is already set, otherwise use the default*. So a value you
set in `.bashrc.local` wins, and one you omit falls back. If the defaults already match your layout,
`.bashrc.local` can be a single line — or absent entirely.

The three variables:

| Variable  | Default                  | Used by                                    |
| --------- | ------------------------ | ------------------------------------------ |
| `SSH_KEY` | `$HOME/.ssh/id_ed25519`  | `ssh-agent` block — the key it loads       |
| `REPOS`   | `$HOME/repos`            | the `work` alias                           |
| `TOOLS`   | `$HOME/Documents/Tools`  | Gradle/Node lookup in `ver` and `PATH`     |

**Why sourced first, not last.** The usual dotfiles convention sources the local file at the *end*,
so it can override aliases. Here the `ssh-agent` block runs near the top and needs `SSH_KEY`, so the
local file has to come first. The consequence: `.bashrc.local` is for **config values**, not alias
overrides — an alias defined there would be redefined by `.bashrc` further down.

---

## Install

From this folder, in Git Bash:

```bash
cp .bashrc .bash_profile .gitconfig .inputrc ~/
mkdir -p ~/.config/git && cp git-prompt.sh ~/.config/git/
cp .bashrc.local.example ~/.bashrc.local
cp .gitconfig.local.example ~/.gitconfig.local
```

Git for Windows sources `~/.config/git/git-prompt.sh` automatically — that exact path matters, the
prompt silently stays plain if the file lands anywhere else.

> **Already have these files?** Back them up first: `cp ~/.bashrc ~/.bashrc.backup`. The copy above
> overwrites without asking.

Then do the two configuration steps below and restart Git Bash.

---

## Configure

### 1. `~/.bashrc.local` — your machine

Only change what does not match your setup. To find your key name:

```bash
ls ~/.ssh/*.pub
```

Drop the `.pub` suffix — for `~/.ssh/id_ed25519.pub`, the key is `~/.ssh/id_ed25519`, which is
already the default, so you can delete the line. For a key named `work_key`:

```bash
SSH_KEY=$HOME/.ssh/work_key
```

Use `$HOME`, not `/c/Users/yourname` — it keeps the file reusable if your username differs elsewhere.

No SSH key yet? Either skip it (the config handles a missing key without erroring) or create one:

```bash
ssh-keygen -t ed25519 -C "you@example.com"
```

### 2. `~/.gitconfig.local` — your identity

`.gitconfig` ships with **no** `[user]` section. Instead it ends with:

```ini
[include]
    path = ~/.gitconfig.local
```

Put your identity there:

```ini
[user]
	name = Your Name
	email = you@example.com
```

Or set it with commands — note the `-f`, which targets the local file:

```bash
git config -f ~/.gitconfig.local user.name "Your Name"
git config -f ~/.gitconfig.local user.email "you@example.com"
```

> **Do not use `git config --global` for your identity here.** When git rejects a commit it suggests
> exactly that command, but `--global` appends a `[user]` section to the *end* of `~/.gitconfig` —
> after the `[include]` — so it silently overrides `~/.gitconfig.local` and reintroduces the machine
> value into the file you wanted to keep portable. Always use `-f ~/.gitconfig.local`.

Two details worth understanding:

- **The include is deliberately the last line.** Git resolves duplicate keys last-wins, so an
  `[include]` placed earlier would be overridden by the file that includes it.
- **Skipping this file is safe, not silent.** Git refuses your first commit with *"Please tell me who
  you are"* rather than attributing the work to a placeholder name. That is why no `[user]` fallback
  ships in `.gitconfig`.

If you want a global ignore file, `.gitconfig` already points at `~/.gitignore` (git expands `~`, so
the path is machine-independent). It is not shipped here — create it if you want one:

```bash
printf 'Thumbs.db\ndesktop.ini\n.DS_Store\n' > ~/.gitignore
```

One line in `.gitconfig` is worth knowing about:

```ini
sshCommand = "C:\\Program Files\\Git\\usr\\bin\\ssh.exe"
```

This forces git to use Git Bash's `ssh` instead of the `ssh.exe` bundled with Windows, which does not
share the `ssh-agent` that `.bashrc` starts. Leave it unless you installed Git somewhere else — in
which case override it in `~/.gitconfig.local`, as shown in the example file.

---

## Verify

Restart Git Bash. You should be prompted for your key passphrase **once**, and the prompt should show
time, user, directory, and current branch.

```bash
ver                      # every tool's version, or "not installed"
work && pwd              # should land in your $REPOS
echo "$SSH_KEY"          # should name a key that exists
ssh-add -l               # should list that key's fingerprint
git config --get user.name    # must come from ~/.gitconfig.local
```

Use `git config --get`, not `git config --global --get`. Naming an explicit scope turns include
processing **off**, so the `--global` form reports nothing and looks like the include failed.

Open a second terminal: it must **not** ask for the passphrase again. If it does, see below.

---

## What you get

### `ver` and `verup`

`ver` prints the version of every tool in the toolchain, and `not installed` for anything absent
rather than leaking `bash: java: command not found`:

```
$ ver
Git: git version 2.55.0.windows.1
Node: v24.18.0
Java: not installed
Gradle: not installed
Python: Python 3.14.6
```

`verup` updates all of them, skipping whatever is missing. Note that uv is updated with
`uv self update`, **not** `pip install --upgrade uv` — standalone uv installs live in
`~/.local/bin`, so the pip route silently upgrades a different copy that is not the one on `PATH`.

### Aliases

| Git         | Does                     | Shell       | Does                          |
| ----------- | ------------------------ | ----------- | ----------------------------- |
| `gs`        | compact status           | `work`      | `cd` to `$REPOS`              |
| `ga` `gaa`  | stage file / stage all   | `..` `...`  | up one / two directories      |
| `gc "msg"`  | commit with message      | `ll` `ll.`  | long listing / include hidden |
| `gl`        | graph log                | `lls` `llt` | sort by size / by time        |
| `gcc` `gb`  | checkout / branches      | `cls`       | clear screen                  |
| `gpo`       | push to origin           | `bls`       | wipe shell history            |
| `ssa "msg"` | stash and keep working   | `rm`        | `rm -iv` (prompts before del) |

`cdd` is `cd .`, deliberately not `.` — `.` is the `source` builtin, and aliasing it breaks
`. ~/.bashrc` and `. venv/Scripts/activate`.

### Shell behaviour

`autocd` (type a directory name to enter it), `cdspell` (fixes typos in `cd`), `globstar` (`**/*.txt`
recurses), 99999 lines of de-duplicated history written after every command, and Up/Down searching
history by what you have already typed.

---

## Troubleshooting

| Symptom                                         | Cause and fix                                                                                                             |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Passphrase asked in every new terminal          | `SSH_KEY` does not name an existing file, so nothing was loaded. Check `echo "$SSH_KEY"` and `ls ~/.ssh/`.                 |
| Prompt shows no branch                          | `git-prompt.sh` is not at `~/.config/git/git-prompt.sh`. Check with `ls ~/.config/git/`.                                   |
| `work` goes to the wrong place                  | Set `REPOS` in `~/.bashrc.local`. Confirm with `echo "$REPOS"`.                                                           |
| `Gradle: not installed` but Gradle **is** there | It is not under `$TOOLS`. `ver` expects `$TOOLS/gradle-*/lib/gradle-launcher-*.jar`. Set `TOOLS` to the parent directory.   |
| Aliases missing inside a `.sh` script           | Expected — bash does not expand aliases in non-interactive shells. Call the real command, or `shopt -s expand_aliases`.    |
| Changes to `.bashrc` not applied                | Run `. ~/.bashrc`, or just open a new terminal.                                                                            |
| `.bashrc` broke and shells now error            | Start with `bash --norc`, then check for typos with `bash -n ~/.bashrc`.                                                   |
| `Please tell me who you are` on first commit    | `~/.gitconfig.local` is missing or has no `[user]`. See step 2 — this message is by design, not a broken install.           |
| `git config --global --get user.name` is empty  | Expected. An explicit scope disables includes; use `git config --get user.name`.                                           |
| Edits to `~/.gitconfig.local` have no effect    | A `[user]` section was appended to `~/.gitconfig` after the `[include]`, and last-wins. Delete it from `~/.gitconfig`.      |

---

## Reusing this across machines

Keep `~/.bashrc`, `~/.bash_profile`, `~/.gitconfig`, `~/.inputrc`, and
`~/.config/git/git-prompt.sh` in a dotfiles repo — they are machine-independent. Add both local files
to that repo's `.gitignore`:

```gitignore
.bashrc.local
.gitconfig.local
```

They name your private key and your email address, and belong to one machine only. On a new box:
clone, copy the files into place, then write a fresh `.bashrc.local` and `.gitconfig.local` from the
`.example` templates.
