# scripts/tests/

| File | Status | What it checks |
| ---- | ------ | -------------- |
| `integration_test.gd` | **The gate. Must pass.** | Batang Hamog clips (Idle/Walking/Running/Harurot/Lusot_Slide/Lusot_Vault, ≥60 tracks, Slide/Dash absent), JM Botsog GLB (clips, Mixamo + towel bones, ≥50 bones), 7 InputMap actions, `BatangHamogController` (VaultDetector casts, VFX nodes, Harurot→Walk recovery, Lusot hurtbox + tag lockout), `DireDiretsoComponent` stacking/resets, both playtest scenes load. |
| `legacy/verify_*.gd` | **Stale — fail on current map.** Not part of the gate. | Snapshots of the map at earlier pipeline stages (some contradict each other, e.g. `verify_refinement` asserts no `CourtRoof`, `verify_court` requires one). Kept for history; do not "fix" the map to satisfy them. |

Run the gate (from repo root):

```powershell
& $env:GODOT --headless --path . -s scripts/tests/integration_test.gd
```

Exit code 0 + final line `All checks passed successfully (100%)!` = pass.
A failed `assert` aborts the deferred `run()` before `quit()`, so a broken gate
can **hang** instead of exiting non-zero — if it doesn't finish in ~1 min, treat it as a failure and read the `SCRIPT ERROR` lines.

When adding a feature, add asserts to `integration_test.gd` (keep the
`print("  ✓ ...")` line-per-section style).
