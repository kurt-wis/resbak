@AGENTS.md

## Claude Code notes
- Windows host. Use the PowerShell tool for `godot`/`blender` invocations (`& $env:GODOT ...`); set `$env:GODOT`/`$env:BLENDER` in the same command, since shell state doesn't persist between calls.
- Run the gate in the background or with a long timeout. If it hasn't finished after about a minute, it's hung on a failed assert, so stop it and read the `SCRIPT ERROR` lines.
- In your summary, state the gate's exit code and final line. Don't claim it passed without running it.
