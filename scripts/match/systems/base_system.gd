class_name BaseSystem
extends RefCounted

## Bases and capture (docs/RESBAK.md § 2 "Bases and capture").
## v0.2: bases are fixed. Each team has one base per map (MapLayout site 1 / BaseSite_<team>);
## the base roulette and settings.base_mode are gone (docs/status.md). Active base = solid
## pole r 0.2 + ring r 2 in team colour. The own-ring barrier keeps the base's own team at
## >= 2.4 m from its pole (enemies pass). Capture: hold Interact with the body-to-enemy-pole gap
## <= 1 m for 1.5 s (90 ticks); capturing heroes can't move, tag or cast but can be pushed;
## progress resets on tag, release, or being pushed out of range. Toggle input: tap start/stop.

var host: MatchHost
var site_number := 1
var poles := [Vector3.ZERO, Vector3.ZERO] ## per team, flat
var pole_bodies: Array[StaticBody3D] = []
var completed := [] ## teams that completed a capture this tick (filled in tick_captures)

func _init(p_host: MatchHost) -> void:
	host = p_host

## Match start: the map's fixed base for each team, then poles and rings.
func setup_match() -> void:
	site_number = 1
	host.settings["base_site"] = site_number
	for t in range(2):
		poles[t] = host.layout.site(t, site_number)
		_build_pole(t)

func pole_pos(team: int) -> Vector3:
	return poles[team]

func _build_pole(team: int) -> void:
	var p: Vector3 = poles[team]
	var t := host.tuning
	var body := StaticBody3D.new()
	body.name = "ActivePole_%s" % RB.TEAM_NAMES[team]
	body.collision_layer = RB.L_POLE
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = t.pole_radius
	cyl.height = 2.4
	cs.shape = cyl
	cs.position.y = 1.2
	body.add_child(cs)
	host.world.add_child(body)
	body.global_position = p
	body.force_update_transform() # the solid pole must be at the site before the first physics step
	pole_bodies.append(body)
	# Older maps drew their own poles: move that art to the active site. The basketball stand
	# and the painted ring are presentation (ArenaArt, added by MatchView).
	var art: Array = host.layout.pole_nodes[team]
	var anchor: Vector3 = host.layout.site(team, 1)
	for node in art:
		var n := node as Node3D
		n.global_position = Vector3(p.x + (n.global_position.x - anchor.x), n.global_position.y, p.z + (n.global_position.z - anchor.z))

func in_own_ring(h: Hero) -> bool:
	return RB.flat_dist(h.global_position, poles[h.team]) <= host.tuning.base_ring_radius

## Gap from a hero's body edge to the enemy pole's surface.
func capture_gap(h: Hero) -> float:
	var t := host.tuning
	return RB.flat_dist(h.global_position, poles[RB.other_team(h.team)]) - t.body_radius - t.pole_radius

func in_capture_range(h: Hero) -> bool:
	return capture_gap(h) <= host.tuning.capture_range + 0.001

# ---- step 2: Interact -------------------------------------------------------------------
func handle_interact(h: Hero, f: InputFrame) -> void:
	var toggle := bool(host.settings.get("capture_toggle", false))
	if h.capturing:
		var stop := f.was_pressed(RB.BTN_INTERACT) if toggle else not f.is_held(RB.BTN_INTERACT)
		if stop:
			cancel_capture(h, "released")
		return
	var start := f.was_pressed(RB.BTN_INTERACT) if toggle else f.is_held(RB.BTN_INTERACT)
	if start and h.can_start_capture() and in_capture_range(h):
		h.capturing = true
		h.capture_ticks = 0
		h.velocity = Vector3.ZERO
		h.notify_capture_start()
		host.add_stat(h, "captures_started")
		host.emit_event("capture_start", {"hero": h})

func cancel_capture(h: Hero, reason: String) -> void:
	if not h.capturing:
		return
	h.capturing = false
	h.capture_ticks = 0
	host.emit_event("capture_cancel", {"hero": h, "reason": reason})

# ---- step 4: barriers -------------------------------------------------------------------
func enforce_barriers() -> void:
	var r := host.tuning.base_barrier_radius
	for h in host.heroes:
		if not h.is_free():
			continue
		var p: Vector3 = poles[h.team]
		var d := RB.flat(h.global_position - p)
		var len := d.length()
		if len >= r:
			continue
		var dir := d / len if len > 0.001 else (Vector3.RIGHT if h.team == RB.LILA else Vector3.LEFT)
		h.global_position = Vector3(p.x + dir.x * r, h.global_position.y, p.z + dir.z * r)
		host.emit_event("barrier_bump", {"hero": h})

# ---- step 8: captures -------------------------------------------------------------------
## Returns the teams that completed a capture this tick.
func tick_captures() -> Array:
	completed = []
	var hold := RB.ticks(host.tuning.capture_hold)
	for h in host.heroes:
		if not h.capturing:
			continue
		if not h.is_free():
			cancel_capture(h, "tagged")
			continue
		if not in_capture_range(h):
			cancel_capture(h, "pushed")
			continue
		h.capture_ticks += 1
		if h.capture_ticks >= hold:
			if not completed.has(h.team):
				completed.append(h.team)
			host.add_stat(h, "captures")
			host.add_impact(h, 10)
			if _is_last_free(h):
				host.add_impact(h, 5)
				host.add_stat(h, "clutch")
			host.emit_event("capture", {"hero": h, "team": h.team})
	return completed

func _is_last_free(h: Hero) -> bool:
	for a in host.allies_of(h):
		if a.is_free():
			return false
	return true

## Capture progress 0..1 per team (the best attacker), for the HUD.
func capture_progress(team: int) -> float:
	var best := 0.0
	for h in host.team_heroes(team):
		if h.capturing:
			best = maxf(best, float(h.capture_ticks) / RB.ticks(host.tuning.capture_hold))
	return best

func reset_round() -> void:
	for h in host.heroes:
		h.capturing = false
		h.capture_ticks = 0
