# Architecture

## System Architecture
This is a documentation-only repository. There is no application runtime or build system. Files are organized by category in the `src/` directory, with supporting tools in `xkcd_scraper/`.

## Source Code Paths

```
top-tools/
├── .clinerules/
│   └── memory-bank-rules.md      # Memory bank behavioral rules
├── .github/workflows/
│   └── xkcd-daily.yml            # Daily XKCD scraper automation
├── .memory-bank/                  # AI assistant context documentation
├── src/
│   ├── browser.md                 # Browser extensions documentation
│   ├── clinerules.md              # Index of clinerules files
│   ├── clinerules/
│   │   ├── AGENTS.md              # Behavioral coding guidelines
│   │   ├── WFGY.md                # Cognitive framework (attention/tension)
│   │   └── local/
│   │       └── memory-bank-rules.md  # Local copy of memory bank rules
│   ├── fav/
│   │   ├── ca-fav.html            # (bookmarks)
│   │   ├── gft-fav.html           # (bookmarks)
│   │   └── pvt-fav.html           # Personal bookmarks (AI tools, jobs, learning)
│   ├── gitconfig.md               # Git configuration guide
│   ├── gitconfig/
│   │   ├── .bashrc                # Shell aliases and environment
│   │   ├── .bash_profile          # Shell profile loading .bashrc
│   │   ├── .gitconfig             # Git core config
│   │   ├── .inputrc               # Terminal input customization
│   │   └── git-prompt.sh          # Git-aware bash prompt
│   ├── settings/
│   │   └── settings.json          # VSCode/VSCodium editor settings
│   ├── vscode.md                  # VSCode extensions documentation
│   └── windows.md                 # Installed Windows programs
├── xkcd_scraper/
│   ├── README.md
│   ├── requirements.txt           # Python dependencies
│   ├── xkcd_scraper.py            # Scraper script (requests + BeautifulSoup)
│   └── comics/
│       ├── latest_xkcd.jpg        # Latest downloaded comic
│       └── latest_xkcd_explanation.txt  # Latest comic explanation
├── analyze_cline_sessions.js      # Tool to analyze Cline session metrics
├── analyze_cline_sessions.py      # Same tool in Python
├── LICENSE                        # MIT license
└── README.md                      # Project overview and quick start
```

## Key Technical Decisions
- **Documentation format**: Markdown for readability, with HTML for bookmark files (Netscape bookmark format)
- **GitHub Actions**: Used for scheduled XKCD scraping (daily trigger)
- **No package.json**: Project has no Node.js dependencies - it's pure documentation
- **Settings in JSON with comments**: Uses JSONC format supported by VSCode/VSCodium settings editor

## Component Relationships
- `src/settings/settings.json` is referenced by `src/vscode.md` (extension configurations)
- `src/vscode.md` documents extensions that use settings from `settings.json`
- `src/browser.md` is referenced by `README.md` as part of quick start
- `src/clinerules.md` indexes `src/clinerules/AGENTS.md` and `src/clinerules/WFGY.md`
- `xkcd_scraper/README.md` and `README.md` both reference the XKCD comic

## Critical Implementation Paths
- To apply VSCode settings: copy `src/settings/settings.json` to VSCode settings
- To apply Git config: copy files from `src/gitconfig/` to home directory
- To install extensions: consult `src/vscode.md` active list
- To run XKCD scraper locally: `cd xkcd_scraper && pip install -r requirements.txt && python xkcd_scraper.py`
- To analyze Cline sessions: needs path to Cline session directory as argument
