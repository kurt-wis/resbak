extends SceneTree

## THE GATE. Runs every suite in SUITES (scripts/tests/suites/*.gd); each suite is a
## RefCounted with `func run(t: TestCtx)` that records checks with t.check(cond, msg).
## Pass = exit 0 and the last line "All checks passed successfully (100%)!".
## One suite:  & $env:GODOT --headless --path . -s scripts/tests/integration_test.gd -- --only=core_rules   (comma-separated for several)
## After adding or renaming class_name scripts, refresh the class cache first:
##   & $env:GODOT --headless --path . --import

const SUITES := [
	"res://scripts/tests/suites/project.gd",
	"res://scripts/tests/suites/legacy.gd",
	"res://scripts/tests/suites/hero_assets.gd",
	"res://scripts/tests/suites/core_rules.gd",
	"res://scripts/tests/suites/kit_tutoy.gd",
	"res://scripts/tests/suites/kit_nene.gd",
	"res://scripts/tests/suites/kit_nathan.gd",
	"res://scripts/tests/suites/kit_jm.gd",
	"res://scripts/tests/suites/kit_inday.gd",
	"res://scripts/tests/suites/bots.gd",
	"res://scripts/tests/suites/hud.gd",
	"res://scripts/tests/suites/konstruksyon.gd",
	"res://scripts/tests/suites/frontend.gd",
	"res://scripts/tests/suites/match_flow.gd",
]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	var ctx := TestCtx.new(self)
	var ran := 0
	for path in SUITES:
		var suite_name: String = path.get_file().get_basename()
		if only != "" and not (suite_name in only.split(",")):
			continue
		if not ResourceLoader.exists(path):
			print("[INTEGRATION TEST] suite %s: not present, skipped" % suite_name)
			continue
		ctx.suite = suite_name
		print("[INTEGRATION TEST] suite %s" % suite_name)
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			ctx.check(false, "suite script failed to load or compile")
			continue
		var suite = script.new()
		await suite.run(ctx)
		ran += 1
	print("[INTEGRATION TEST] %d suites, %d checks, %d failed" % [ran, ctx.checks, ctx.failures.size()])
	if ran == 0:
		printerr("[INTEGRATION TEST] no suite ran")
		quit(1)
		return
	if not ctx.failures.is_empty():
		for f in ctx.failures:
			printerr("  FAILED " + f)
		print("[INTEGRATION TEST] FAILED")
		quit(1)
		return
	print("[INTEGRATION TEST] All checks passed successfully (100%)!")
	quit(0)
