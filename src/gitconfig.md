# Git Configuration Guide

---

## Configuration Files Overview

The `src/gitconfig/` directory contains optimized configuration files:

- **`.gitconfig`**: Core Git settings (branch sorting, auto-setup, aliases)
- **`.bashrc`**: Shell environment + Git/workflow aliases
- **`.bash_profile`**: Loads .bashrc settings
- **`.inputrc`**: Terminal input customization
- **`git-prompt.sh`**: Custom Git Bash prompt

---

## Essential Configuration Highlights

### Key .gitconfig Settings

```ini
[init]
    defaultBranch = main  # Modern default branch

[pull]
    rebase = true  # Prefer rebase over merge

[push]
    autoSetupRemote = true  # Auto-create tracking branches

[fetch]
    prune = true  # Auto-remove stale branches

[alias]
    difftofile = !git diff --cached > output.diff  # Save staged changes
```

### Top Git Aliases (.bashrc)

```bash
gs='git status -sb'       # Compact status
gaa='git add --all'       # Stage all changes
gc='git commit -m'        # Commit with message
gl='git log --graph'      # Visual history
gcc='git checkout'        # Switch branches
gpo='git push origin'     # Push to origin
```

### Terminal Enhancements

- **.inputrc**: Improved tab completion/history navigation
- **git-prompt.sh**: Branch-aware prompt with status indicators
- Navigation aliases: `..` (up 1), `...` (up 2), etc.

---

## Recommended Workflow

1. **Daily Start**:

   ```bash
   work  # cd to repos directory
   gcc feature-branch  # Switch to feature branch
   ```

2. **Make Changes**:

   ```bash
   gs  # Check status
   ga file.js  # Stage specific file
   # Or: gaa to stage all
   ```

3. **Commit & Push**:

   ```bash
   gc "Add new feature"  # Commit with message
   gpo  # Push to origin
   ```

4. **Update & Clean**:

   ```bash
   pull  # Fetch latest changes
   git branch -d old-branch  # Delete merged branches
   ```

---

## Best Practices

1. **Commit Hygiene**:

   - Atomic commits (one change per commit)
   - Descriptive commit messages
   - Verify changes with `gs` before committing

2. **Branch Management**:

   - `main` as protected default branch
   - Short-lived feature branches
   - Regular pruning: `git fetch --prune`

3. **Terminal Efficiency**:
   - Use `gl` instead of basic `git log`
   - `ll` for detailed directory listings
   - `bashclear` to reset command history
