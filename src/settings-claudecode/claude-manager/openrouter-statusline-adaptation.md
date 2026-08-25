# Statusline: OpenRouter Cost Tracking

Status: **shipped**. This documents the statusline as it currently works.

Cost, context usage, and rate-limit percentages are rendered by
`statusline-tap.js`. There is no external plugin dependency — an earlier
version delegated the left-hand segment to a third-party plugin script, which
has since been removed.

## Pipeline

```
Claude Code → stdin (JSON) → statusline-tap.js
                               ├─ parse + normalize
                               ├─ persist snapshot → statusline.json
                               ├─ run optional inner command (statusline-inner.json)
                               └─ combine: "<inner>  ·  <tap output>"
```

## Files

### 1. `C:/Users/YOURNAME/.claude/settings.json`

Wires the tap in as the statusline command:

```json
{
  "statusLine": {
    "type": "command",
    "command": "node \"C:\\Users\\YOURNAME\\.claude\\.claude-manager\\statusline-tap.js\""
  }
}
```

### 2. `C:/Users/YOURNAME/.claude/.claude-manager/statusline-tap.js`

Does the work. `parse()` pulls `model.display_name`,
`context_window.used_percentage`, `context_window.context_window_size`,
`cost.total_cost_usd`, and `rate_limits.{five_hour,seven_day}.used_percentage`
off the stdin payload. `format()` joins the non-null pieces with `  ·  `:

```
Opus 5  ·  ctx 12%  ·  5h 4%  ·  7d 9%  ·  $3.52
```

Hardening worth preserving on any edit:

- Symlink-safe atomic writes — refuses reparse points, verifies the parent
  directory resolves under `$HOME`, writes temp + rename at mode `0600`
- Control-character stripping on every display string (blocks ANSI/OSC
  injection into the terminal), capped at 64 chars
- Inner-command output capped at 512 bytes, 5s timeout, `windowsHide`
- Strict type coercion on all parsed fields; malformed stdin yields empty
  output rather than throwing

### 3. `C:/Users/YOURNAME/.claude/.claude-manager/statusline.json`

Normalized snapshot the tap writes on every render, for other tooling to read:

```json
{
  "capturedAt": 1787663247694,
  "version": "2.1.231",
  "model": { "id": "claude-opus-5", "displayName": "Opus 5" },
  "context": { "usedPercent": 12.4, "size": 1000000 },
  "cost": {
    "totalUsd": 3.5196655,
    "durationMs": 639959,
    "linesAdded": 0,
    "linesRemoved": 0
  },
  "rateLimits": {
    "fiveHour": { "usedPercent": 4, "resetsAt": 0 },
    "sevenDay": { "usedPercent": 9, "resetsAt": 0 }
  }
}
```

### 4. `C:/Users/YOURNAME/.claude/.claude-manager/statusline-inner.json`

Optional prefix segment. Empty means the tap renders alone:

```json
{
  "command": ""
}
```

To add a prefix badge, point `command` at a script that prints one short line
to stdout. It receives the same stdin JSON as the tap and its output is
prepended, separated by `  ·  `. Keep it under 512 bytes and fast — it runs on
every keystroke.

## Verifying a change

Pipe a sample payload in via a file (a PowerShell `|` into node mangles stdin):

```powershell
'{"model":{"display_name":"Opus 5"},"context_window":{"used_percentage":12.4,"context_window_size":1000000},"cost":{"total_cost_usd":3.52},"rate_limits":{"five_hour":{"used_percentage":4},"seven_day":{"used_percentage":9}}}' |
  Out-File -FilePath sl.json -Encoding ascii -NoNewline
cmd /c "node statusline-tap.js < sl.json"
```

Expected: `Opus 5  ·  ctx 12%  ·  5h 4%  ·  7d 9%  ·  $3.52`
