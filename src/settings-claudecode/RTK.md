# RTK in Claude Code auto mode

Type the explicit RTK form for every supported command, including commands after `|` or `&&`.

No hook rewrites commands. A command that you type without `rtk` runs with its full output.

Do not add an `rtk hook` to `settings.json`. A hook that changes a command after auto mode reviews it makes auto mode refuse that command ("auto mode classifier gave no verdict").

`settings.json` sets `RTK_SUPPRESS_HOOK_WARNING=1`. This stops `rtk` from printing a no-hook warning on every command.
