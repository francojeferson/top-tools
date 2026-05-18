# Product Context

## Why This Project Exists
This project exists to centralize and version-control the user's development environment configuration. Instead of manually remembering settings, extensions, and tool preferences across machines, everything is documented in one place.

## Problems It Solves
- **Environment drift**: Configurations can be consistently applied across Windows machines
- **Knowledge loss**: Tool recommendations and settings are documented instead of stored in memory
- **Migration friction**: When switching editors (VSCode to VSCodium) or setting up new machines, configurations are ready to apply
- **Extension sprawl**: Active vs replaced vs deprecated extensions are clearly tracked with migration guides
- **Context persistence**: The Memory Bank system ensures AI assistant context is preserved between sessions

## How It Should Work
- **VSCode/VSCodium**: User copies `settings.json` to editor config, installs active extensions, skips deprecated ones
- **Browser**: User installs extensions listed in `browser.md`, imports bookmarks from `fav.html`
- **Git**: User copies `.gitconfig`, `.bashrc`, `.bash_profile`, `.inputrc`, `git-prompt.sh` to home directory
- **Cline Rules**: AGENTS.md and WFGY.md are loaded automatically as `.clinerules` for this workspace
- **XKCD Scraper**: Runs daily via GitHub Actions, fetches latest comic and explanation, commits to repo

## User Experience Goals
- Clear and quick reference - user should find what they need in seconds
- Categories and tables for easy scanning
- Performance impact documented for each tool/extension
- Migration paths documented when replacing extensions
- Minimal friction to apply configurations to a new environment
