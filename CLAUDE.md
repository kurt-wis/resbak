@AGENTS.md

## Claude Code notes
- Design spec: `docs/RESBAK.md` (the single source of truth; condensed, so read only the sections your task needs). Read the relevant section before building any game system, and check its "What ships when" table for scope. Don't edit `docs/RESBAK.md` or implement from `docs/archive/`.
- Windows host. Use the PowerShell tool for `godot`/`blender` invocations (`& $env:GODOT ...`); set `$env:GODOT`/`$env:BLENDER` in the same command, since shell state doesn't persist between calls.
- Run the gate in the background or with a long timeout. Failed checks are counted, not asserted; if a run stalls past about five minutes, stop it and read the `SCRIPT ERROR` lines. One suite: `-- --only=<suite>` (see `scripts/tests/README.md`).
- In your summary, state the gate's exit code and final line. Don't claim it passed without running it.
- 3D work: after any model or animation change, run tools/qc_asset.py and look at its sheet before calling it done (docs/pipelines/blender.md).
- Match code runs on the host tick (`MatchHost`, 60 ticks/s). Gameplay never reads `Input` directly: players and bots both produce `InputFrame`s. Keep it that way so LAN play can slot in.
