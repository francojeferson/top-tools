# OpenRouter Statusline Adaptation Plan

## Goal
Adapt current caveman statusline to display OpenRouter API cost tracking (usage %, context size, total USD cost) like the reference repo.

## Files to Modify

### 1. `C:/Users/DELLI7/.claude/.claude-manager/statusline.json`
Add OpenRouter model info and context window data:
```json
{
  "model": {
    "id": "openrouter/free[1m]",
    "displayName": "openrouter/free[1m]"
  },
  "context": {
    "usedPercent": 7,
    "size": 1000000
  },
  "cost": {
    "totalUsd": 3.5196655,
    "durationMs": 639959,
    "linesAdded": 0,
    "linesRemoved": 0
  },
  "rateLimits": {
    "fiveHour": null,
    "sevenDay": null
  }
}
```

### 2. `C:/Users/DELLI7/.claude/.claude-manager/statusline-inner.json`
Update command to use new TypeScript cost calculator (or keep PS1 wrapper with new logic):
```json
{
  "command": "powershell -ExecutionPolicy Bypass -File \"C:\\Users\\DELLI7\\.claude\\plugins\\marketplaces\\caveman\\src\\hooks\\caveman-statusline.ps1\""
}
```

### 3. `C:/Users/DELLI7/.claude/plugins/marketplaces/caveman/src/hooks/caveman-statusline.ps1`
Add OpenRouter cost reading from `statusline.json` and render cost suffix alongside caveman mode indicator.

### 4. `C:/Users/DELLI7/.claude/.claude-manager/statusline-tap.js`
Update `h()` parser to extract OpenRouter fields (`cost.total_cost_usd`, `context_window.used_percentage`, `context_window.context_window_size`) and update `w()` formatter to include cost in output.

## Implementation Steps

1. [ ] Update `statusline.json` with OpenRouter structure
2. [ ] Modify `statusline-tap.js` parser (`h()`) to read new fields
3. [ ] Update formatter (`w()`) to append cost: `$3.52`
4. [ ] Test statusline renders correctly in Claude Code

## Success Criteria
- Statusline shows: `[CAVEMAN] ctx 7% · 5h 0% · 7d 0% · $3.52`
- No breaking changes to existing caveman mode display
- Cost updates in real-time as tokens consumed