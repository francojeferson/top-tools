# Tech Context

## Technologies Used
- **Markdown** - Primary documentation format
- **JSON/JSONC** - VSCode/VSCodium settings
- **HTML** - Bookmark files (Netscape bookmark format)
- **Python 3** - XKCD scraper script and Cline session analysis
- **JavaScript (Node.js)** - Cline session analysis tool
- **Shell Script (Bash)** - Git prompt and shell configuration
- **INI-style** - .gitconfig configuration format
- **YAML** - GitHub Actions workflow

## Development Setup
- **OS**: Windows 11
- **Editor**: VSCodium (open-source VSCode alternative, no Microsoft telemetry)
- **Shell**: Git Bash (via Git for Windows)
- **Version Control**: Git, with GitHub remote
- **Node.js**: Managed via nvm-windows
- **Python**: Managed via pyenv-win
- **Go**: Installed but not used by this project

## Technical Constraints
- No runtime dependencies for the documentation itself (pure markdown/config files)
- XKCD scraper requires: Python 3, `requests`, `beautifulsoup4`, `schedule` packages
- Cline session analyzer (JS) runs on Node.js with no npm dependencies (uses built-in `fs`, `path`, `os`, `child_process`)
- Cline session analyzer (Python) requires Python 3
- Bookmark files must maintain Netscape bookmark format for browser import compatibility

## Dependencies
- **xkcd_scraper/requirements.txt**: `requests`, `beautifulsoup4`, `schedule`
- **GitHub Actions**: Runs on `ubuntu-latest`, uses Python 3.x, `actions/checkout@v4`

## Tool Usage Patterns
- **Git config**: Branches default to `main`, rebase on pull, autoSetupRemote on push, histogram diff algorithm
- **VSCode settings**: Performance-optimized (minimap off, experiments off, semantic highlighting off), native features replacing extensions where possible
- **EditorConfig + Prettier**: Both configured together to avoid conflicts; `.prettierrc` with `editorconfig: true`
- **Cline Rules**: AGENTS.md for behavioral guidelines, WFGY.md for cognitive attention management
