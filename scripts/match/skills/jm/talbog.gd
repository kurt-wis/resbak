extends Skill

## JM S1 TALBOG! (docs/RESBAK.md § 4 JM). Jump to the aim point (at most 6 m), airborne 0.6 s
## with a landing marker everyone can see; while airborne JM can't steer, tag or be pushed but
## can be tagged (the arc peaks at talbog_jump_height <= the 1 m height gap, so tags still
## reach). The landing is cut short just before a blocking wall, solid prop, pole, the jail
## barrier. On landing: enemies with their centre within 2.5 m are
## pushed 3 m away from the landing point, and a crescent earth wall (talbog_wall.gd) rises 1.5 m
## in front of the landing point along the aim for 4 s. Tagged mid-air: the jump ends where JM is,
## he falls, and no impact or wall happens.

const Wall := preload("res://scripts/match/skills/jm/talbog_wall.gd")

var _start := Vector3.ZERO
var _target := Vector3.ZERO
var _dir := Vector3(0, 0, 1)
var _air_ticks := 36
var _marker: Node3D
var last_wall: Node3D ## the most recent wall (tests, HUD)
var last_target := Vector3.ZERO ## where the last jump was clamped to land

func kind() -> int:
	return RB.SkillKind.OFFENSIVE

func blocks_tagging() -> bool:
	return true

func blocks_other_skills() -> bool:
	return true # one movement skill at a time (spec is silent: TAMARAW!!! does the same)

func can_be_pushed() -> bool:
	return false

func controls_movement() -> bool:
	return true

func hud_note() -> String:
	return "" if not active else "%.1f s" % RB.seconds(maxi(0, _air_ticks - (host.tick - cast_tick)))

# ---- cast -------------------------------------------------------------------------------
func _cast(frame: InputFrame) -> void:
	_start = hero.global_position
	_dir = hero.aim if hero.aim.length() > 0.01 else hero.facing
	_dir = RB.flat(_dir).normalized()
	var want := frame.aim_distance(_start)
	var reach := float(v("talbog_range"))
	if want >= 0.0:
		reach = minf(want, reach)
	reach = clampf(reach, 0.0, float(v("talbog_range")))
	reach = _clamp_reach(_dir, reach)
	_target = _start + _dir * reach
	last_target = _target
	_air_ticks = maxi(1, RB.ticks(v("talbog_air_time")))
	active = true
	# Airborne: nobody collides with JM or blocks him (he is placed along the arc directly).
	hero.collision_layer = RB.L_GHOST
	hero.collision_mask = 0
	hero.facing = _dir
	_show_marker()
	hero.visual.play_action("Talbog_Jump", RB.seconds(_air_ticks))
	host.emit_event("talbog_jump", {"hero": hero, "from": _start, "to": _target})

## How far along `dir` JM may land: stops just before a blocking wall/solid (ray), a pole, the jail
## barrier.
func _clamp_reach(dir: Vector3, reach: float) -> float:
	var t := host.tuning
	var limit := reach
	var end := _start + dir * reach
	var hit := host.ray_hit(_start, end)
	if not hit.is_empty():
		var hp: Vector3 = hit.position
		limit = minf(limit, maxf(0.0, RB.flat_dist(_start, hp) - t.body_radius - 0.05))
	var step := 0.1
	var safe := 0.0
	var d := step
	while true:
		var dd := minf(d, limit)
		if _blocked_spot(_start + dir * dd):
			return safe
		safe = dd
		if dd >= limit:
			break
		d += step
	return safe

func _blocked_spot(p: Vector3) -> bool:
	var t := host.tuning
	for owner in range(2):
		if host.layout.in_jail(owner, p, t.body_radius):
			return true
	var own := host.base_system.pole_pos(hero.team)
	if RB.flat_dist(p, own) < t.pole_radius + t.body_radius:
		return true
	var enemy := host.base_system.pole_pos(RB.other_team(hero.team))
	return RB.flat_dist(p, enemy) < t.pole_radius + t.body_radius

# ---- flight -----------------------------------------------------------------------------
func move(dt: float) -> void:
	var elapsed := host.tick - cast_tick
	var u := clampf(float(elapsed) / _air_ticks, 0.0, 1.0)
	var prev := hero.global_position
	var flat_pos := _start.lerp(_target, u)
	var peak := float(v("talbog_jump_height", 0.95))
	hero.global_position = Vector3(flat_pos.x, _start.y + 4.0 * peak * u * (1.0 - u), flat_pos.z)
	hero.velocity = Vector3((hero.global_position.x - prev.x) / dt, 0.0, (hero.global_position.z - prev.z) / dt)
	hero.facing = _dir
	if elapsed >= _air_ticks:
		_land()

func _land() -> void:
	var land := Vector3(_target.x, _start.y, _target.z)
	hero.global_position = land
	hero.velocity = Vector3.ZERO
	_restore_body()
	_clear_marker()
	active = false
	var radius := float(v("talbog_push_radius"))
	var dist := float(v("talbog_push_distance"))
	var wall = Wall.new()
	wall.setup(host, hero, float(v("talbog_wall_time")))
	wall.ticks_left += 1 # the landing tick already ticks the new wall once: solid for exactly 4 s = 240 ticks
	wall.build(land, _dir, float(v("talbog_wall_width")), float(v("talbog_wall_offset")), float(v("talbog_wall_height")))
	host.spawn_object(wall)
	wall.force_update_transform()
	for c in wall.body.get_children():
		(c as Node3D).force_update_transform()
	wall.play_rise()
	wall.resolve_overlaps(host.heroes, host.tuning.body_radius)
	var pushed: Array[Hero] = []
	for e in host.enemies_of(hero):
		if not e.is_free() or absf(e.global_position.y - land.y) > host.tuning.height_gap:
			continue
		if RB.flat_dist(e.global_position, land) > radius:
			continue
		var away := RB.flat(e.global_position - land)
		if away.length() < 0.05:
			away = _dir
		e.apply_push(away, dist, true)
		pushed.append(e)
	last_wall = wall
	hero.visual.play_action("Talbog_Slam")
	_impact_fx(land, radius)
	host.emit_event("talbog_land", {"hero": hero, "pos": land, "pushed": pushed, "wall": wall})

func _impact_fx(land: Vector3, radius: float) -> void:
	var dust := Color(0.78, 0.64, 0.45, 0.85)
	Vfx.ring_pulse(host.world, land, radius, dust, 0.45)
	Vfx.ring_pulse(host.world, land, radius * 0.6, Color(1, 0.9, 0.7, 0.7), 0.3)
	Vfx.burst(host.world, land + Vector3(0, 0.15, 0), dust, 34, 4.5, 0.7, 0.35, -3.0, 80.0)

# ---- end / reset ------------------------------------------------------------------------
func end(_reason: String) -> void:
	if not active:
		_clear_marker()
		return
	active = false
	_restore_body()
	_clear_marker()
	if hero.visual:
		hero.visual.stop_action("Talbog_Jump")
	hero.velocity = Vector3.ZERO

func _restore_body() -> void:
	hero._update_collision()

# ---- landing marker (visible to everyone) -----------------------------------------------
func _show_marker() -> void:
	_clear_marker()
	var col: Color = RB.TEAM_COLORS[hero.team]
	_marker = Vfx.ground_ring(host.world, _target, float(v("talbog_push_radius")), Color(col.r, col.g, col.b, 0.85), 0.14, 0.14)
	_marker.name = "TalbogMarker"

func _clear_marker() -> void:
	if _marker != null and is_instance_valid(_marker):
		if _marker.get_parent():
			_marker.get_parent().remove_child(_marker) # frees the name at once
		_marker.queue_free()
	_marker = null

func _exit_tree() -> void:
	_clear_marker()
