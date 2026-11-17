@RTK.md

## RTK and auto mode

The RTK hook rewrites plain commands to `rtk ...`. In auto mode, a rewrite that no allow rule covers (for example `stat`, or a chain with `echo`) is blocked on the first try ("auto mode classifier gave no verdict"), because the command changed after auto mode reviewed it. The retry costs a turn.

Type the RTK form yourself so the hook has nothing to rewrite, also after a pipe or `&&`:

- `git ...` → `rtk git ...`; `ls` → `rtk ls`; `grep` → `rtk grep`; `find` → `rtk find`; `wc` → `rtk wc`; `stat` → `rtk stat`; `curl` → `rtk curl`; `docker` → `rtk docker`; `./gradlew` → `rtk gradlew`
- `cat f` → `rtk read f`; `head -n N f` → `rtk read f --head-lines N`

Commands RTK does not rewrite (`echo`, `node`, `netstat`, `rm`, `npm test`) run as they are. If a command is blocked this way anyway, re-issue it exactly as the error shows.
