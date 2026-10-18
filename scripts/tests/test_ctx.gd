class_name TestCtx
extends RefCounted

## Shared helpers for the gate's suites (scripts/tests/suites/*.gd).
## check() records a failure instead of asserting, so a broken suite reports and the gate
## exits 1 instead of hanging. Matches built here use a small grey arena with the same node
## names as the real maps, scripted inputs, and manual host stepping (exact ticks).

var tree: SceneTree
var suite := ""
var failures: Array[String] = []
var checks := 0

func _init(p_tree: SceneTree) -> void:
	tree = p_tree

func check(cond: bool, msg: String) -> bool:
	checks += 1
	if not cond:
		failures.append("[%s] %s" % [suite, msg])
		printerr("  ✗ [%s] %s" % [suite, msg])
	return cond

func ok(msg: String) -> void:
	print("  ✓ [%s] %s" % [suite, msg])

func near(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) <= eps

func frames(n := 1) -> void:
	for i in range(n):
		await tree.process_frame

func physics_frames(n := 1) -> void:
	for i in range(n):
		await tree.physics_frame

# ---- arena and matches ------------------------------------------------------------------
## A flat 40 x 30 m arena with walls, three base sites per side (same spots as the Barangay
## Court) and two 6 x 4 m jails, using the spec node names.
static func build_arena() -> Node3D:
	var root := Node3D.new()
	root.name = "TestArena"
	var floor := StaticBody3D.new()
	floor.name = "Floor"
	var fs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(60, 1, 44)
	fs.shape = fb
	fs.position.y = -0.5
	floor.add_child(fs)
	root.add_child(floor)
	for w in [[Vector3(0, 1, -12.5), Vector3(42, 2, 1)], [Vector3(0, 1, 12.5), Vector3(42, 2, 1)], [Vector3(-20.5, 1, 0), Vector3(1, 2, 26)], [Vector3(20.5, 1, 0), Vector3(1, 2, 26)]]:
		var wall := StaticBody3D.new()
		wall.name = "Wall"
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = w[1]
		cs.shape = b
		wall.add_child(cs)
		wall.position = w[0]
		root.add_child(wall)
	var sites := [Vector3(-12, 0, 0), Vector3(-15, 0, -5), Vector3(-8, 0, 6.5)]
	for t in range(2):
		var tn: String = ["Dilaw", "Lila"][t]
		for n in range(3):
			var s := Node3D.new()
			s.name = "BaseSite_%s_%d" % [tn, n + 1]
			var p: Vector3 = sites[n]
			s.position = Vector3(p.x if t == 0 else -p.x, 0, p.z)
			root.add_child(s)
		var jail := Area3D.new()
		jail.name = "Jail_%s" % tn
		var js := CollisionShape3D.new()
		var jb := BoxShape3D.new()
		jb.size = Vector3(6, 1, 4)
		js.shape = jb
		jail.add_child(js)
		jail.position = Vector3(-16.6 if t == 0 else 16.6, 0.5, 7.2 if t == 0 else -7.2)
		root.add_child(jail)
	return root

## Starts a match in a fresh arena. lineup entries: {hero_id, team, team_slot?, is_bot?}.
## Returns the host (manual stepping, every slot driven by `inputs`, a ScriptedInput).
func make_match(lineup: Array, settings: Dictionary = {}) -> MatchHost:
	var holder := Node3D.new()
	holder.name = "TestMatch"
	tree.root.add_child(holder)
	var arena := build_arena()
	holder.add_child(arena)
	var world := Node3D.new()
	world.name = "World"
	holder.add_child(world)
	var host := MatchHost.new()
	host.manual_step = true
	holder.add_child(host)
	var s := {"seed": 1234, "base_mode": 1, "skip_intro": true}
	s.merge(settings, true)
	var full: Array = []
	var per_team := [0, 0]
	for e in lineup:
		var entry: Dictionary = e.duplicate()
		if not entry.has("team_slot"):
			entry["team_slot"] = per_team[entry.team]
		per_team[entry.team] += 1
		entry["name"] = entry.get("name", entry.hero_id)
		entry["is_bot"] = entry.get("is_bot", false)
		full.append(entry)
	host.setup(world, arena, full, s)
	var inputs := ScriptedInput.new()
	for h in host.heroes:
		host.input_sources[h.slot] = inputs
	host.set_meta("inputs", inputs)
	return host

func inputs(host: MatchHost) -> ScriptedInput:
	return host.get_meta("inputs")

## Skip the countdown so the round is live.
func go_live(host: MatchHost) -> void:
	while not host.round_live():
		host.step()

func steps(host: MatchHost, n: int) -> void:
	for i in range(n):
		host.step()

func free_match(host: MatchHost) -> void:
	var holder := host.get_parent()
	holder.queue_free()
	await tree.process_frame

## Place a hero exactly (and stop it).
static func put(h: Hero, x: float, z: float) -> void:
	h.teleport(Vector3(x, 0.05, z))
