extends Skill

## TALBOG: terrain-aware jump, public landing marker, enemy radial push and 2 s stun.
## The approved 2026-10-18 redesign removes the earth wall (see docs/status.md).
## Landing query is shared with the preview; interruption creates no impact.

var _start := Vector3.ZERO
var _target := Vector3.ZERO
var _dir := Vector3(0, 0, 1)
var _air_ticks := 36
var _marker: Node3D
var last_wall: Node3D ## retained query handle; always null after the no-wall redesign
var last_target := Vector3.ZERO ## where the last jump was clamped to land

func kind() -> int:
	return RB.SkillKind.OFFENSIVE

func is_traversal() -> bool:
	return true

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
	var preview := aim_preview(frame)
	_dir = preview.direction
	_target = preview.point
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
func _clamp_reach(dir: Vector3, reach: float, origin := Vector3.INF) -> float:
	if origin == Vector3.INF:
		origin = _start
	var t := host.tuning
	var limit := reach
	var end := origin + dir * reach
	var hit := host.ray_hit(origin, end)
	if not hit.is_empty():
		var hp: Vector3 = hit.position
		limit = minf(limit, maxf(0.0, RB.flat_dist(origin, hp) - t.body_radius - 0.05))
	var step := 0.1
	var safe := 0.0
	var d := step
	while true:
		var dd := minf(d, limit)
		if _blocked_spot(origin + dir * dd):
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

## Read-only query shared by aiming, release and public flight telegraph.
func aim_preview(frame: InputFrame) -> Dictionary:
	var info := super.aim_preview(frame)
	var dir := frame.aim_direction(hero.global_position)
	if dir == Vector3.ZERO:
		dir = hero.aim if hero.aim.length() > 0.01 else hero.facing
	dir = RB.flat(dir).normalized()
	var want := frame.aim_distance(hero.global_position)
	var reach := float(v("talbog_range"))
	if want >= 0.0:
		reach = clampf(want, 0.0, reach)
	reach = _clamp_reach(dir, reach, hero.global_position)
	info.direction = dir
	info.point = landing_ground(hero.global_position + dir * reach)
	info.distance = reach
	info.wall = [] # TALBOG is now an impact stun, with no obstacle or wall ghost.
	return info

func landing_ground(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * float(v("talbog_ground_probe_up")), point + Vector3.DOWN * float(v("talbog_ground_probe_down")), RB.L_WORLD | RB.L_VAULTABLE)
	var hit := host.world.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else hero.global_position

# ---- flight -----------------------------------------------------------------------------
static func sample_arc(from: Vector3, to: Vector3, progress: float, peak: float) -> Vector3:
	var point := from.lerp(to, progress)
	point.y += 4.0 * peak * progress * (1.0 - progress)
	return point

func move(dt: float) -> void:
	var elapsed := host.tick - cast_tick
	var u := clampf(float(elapsed) / _air_ticks, 0.0, 1.0)
	var prev := hero.global_position
	hero.global_position = sample_arc(_start, _target, u, float(v("talbog_jump_height", 0.95)))
	hero.velocity = Vector3((hero.global_position.x - prev.x) / dt, 0.0, (hero.global_position.z - prev.z) / dt)
	hero.facing = _dir
	if elapsed >= _air_ticks:
		_land()

func _land() -> void:
	var land := _target
	hero.global_position = land
	hero.velocity = Vector3.ZERO
	_restore_body()
	_clear_marker()
	active = false
	var radius := float(v("talbog_push_radius"))
	var dist := float(v("talbog_push_distance"))
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
		e.stun(float(v("talbog_stun")), true)
		pushed.append(e)
	last_wall = null
	hero.visual.play_action("Talbog_Slam", float(v("talbog_recovery")))
	hero.plant_cast(float(v("talbog_recovery")))
	_impact_fx(land, radius)
	host.emit_event("talbog_land", {"hero": hero, "pos": land, "pushed": pushed, "wall": null})

func _impact_fx(land: Vector3, radius: float) -> void:
	var dust := Color(0.78, 0.64, 0.45, 0.85)
	Vfx.ring_pulse(host.world, land, radius, dust, 0.45)
	Vfx.ring_pulse(host.world, land, radius * 0.6, Color(1, 0.9, 0.7, 0.7), 0.3)
	Vfx.burst(host.world, land + Vector3(0, 0.15, 0), dust, 34, 4.5, 0.7, 0.35, -3.0, 80.0)
	for i in range(10):
		var angle := TAU * float(i) / 10.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		var side := direction.cross(Vector3.UP)
		var points := PackedVector3Array()
		for j in range(6):
			var amount := float(j) / 5.0
			points.append(direction * amount * radius * 0.85 + side * sin(j * 2.7 + i) * amount * 0.1)
		var crack := Vfx.ribbon(points, 0.035, Color(0.42, 0.24, 0.09, 0.8))
		host.world.add_child(crack)
		crack.global_position = land + Vector3.UP * 0.025
		Vfx.fade_and_free(crack, 0.55)

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
	_marker.set_meta("landing", _target)


func _clear_marker() -> void:
	if _marker != null and is_instance_valid(_marker):
		if _marker.get_parent():
			_marker.get_parent().remove_child(_marker) # frees the name at once
		_marker.queue_free()
	_marker = null

func _exit_tree() -> void:
	# The world's children may be exiting together when leaving/resetting training.
	# Queue deletion without removing a sibling from that busy parent.
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
