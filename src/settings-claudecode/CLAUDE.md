@RTK.md

Auto mode rejects (once) any Bash call the rtk hook rewrites. The hook rewrites every `;`, `&&` and `|` segment that does not already start with `rtk`, so write each segment as `rtk <cmd>` or `rtk proxy <cmd>` (raw output) yourself. `node`, `echo` and similar pass unchanged.
