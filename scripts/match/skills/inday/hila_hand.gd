class_name HilaHand
extends SkillObject

## Inday's stretched hand (HILA!, Inday S2). It shoots out along her aim at a fixed speed in
## step 3 and stops at a wall or after `range` metres, then stays open for `hold` seconds.
## The first Free teammate whose body touches it (within `grab` of its centre, edge to edge)
## is yanked to her (a push toward Inday), and the hand closes. A chain tip it touches counts
## as Inday's touch: the JailSystem asks HILA! for the hand's position in step 6 (a rescue by
## skill), and the freed tip is then grabbed and pulled in on the next tick.
## The hand closes early when Inday stops being Free.

const COLOR := Color(1.0, 0.82, 0.32)

var dir := Vector3.RIGHT
var cfg := {}
var travelled := 0.0
var holding := false
var _hold_left := 0
var _palm: MeshInstance3D
var _arm: MeshInstance3D
var _close_reason := "cancelled"

func begin(p_host: MatchHost, p_owner: Hero, p_dir: Vector3, p_cfg: Dictionary) -> void:
	setup(p_host, p_owner, -1.0)
	name = "HilaHand"
	dir = p_dir
	cfg = p_cfg
	_palm = MeshInstance3D.new()
	var palm := BoxMesh.new()
	palm.size = Vector3(0.23, 0.08, 0.23)
	_palm.mesh = palm
	_palm.material_override = Vfx.flat_material(COLOR)
	_palm.position = Vector3(0, 1.0, 0)
	_palm.rotation.y = atan2(dir.x, dir.z) + PI
	add_child(_palm)
	# Recognizable open hand: four fingers and a thumb, rather than a floating sphere.
	for i in range(5):
		var finger := MeshInstance3D.new()
		var shape := CapsuleMesh.new()
		shape.radius = 0.025
		shape.height = 0.17 if i < 4 else 0.12
		finger.mesh = shape
		finger.material_override = Vfx.flat_material(COLOR)
		finger.rotation.x = PI * 0.5
		finger.position = Vector3((float(i) - 1.5) * 0.06, 0, -0.17) if i < 4 else Vector3(0.15, 0, 0)
		if i == 4:
			finger.rotation.z = -PI * 0.3
		_palm.add_child(finger)
	_arm = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 1.0)
	_arm.mesh = box
	_arm.material_override = Vfx.flat_material(COLOR.darkened(0.15))
	_arm.top_level = true
	add_child(_arm)

func tick(dt: float) -> void:
	if expired:
		return
	if owner_hero == null or not owner_hero.is_free():
		_close("owner")
		return
	if not holding:
		var from := global_position
		var to := from + dir * float(cfg.speed) * dt
		var wall := host.ray_hit(from, to, RB.L_WORLD | RB.L_SKILL_WALL)
		if not wall.is_empty():
			to = RB.flat(wall.position) - dir * 0.05 + Vector3(0, from.y, 0)
		global_position = to
		travelled += from.distance_to(to)
		if not wall.is_empty() or travelled >= float(cfg.range):
			holding = true
			_hold_left = RB.ticks(float(cfg.hold))
			host.emit_event("hila_open", {"hero": owner_hero, "pos": global_position})
	else:
		_hold_left -= 1
		if _hold_left <= 0:
			_close("expired")
			return
	var ally := _touching_ally()
	if ally:
		_pull(ally)

## The nearest Free teammate (not Inday) touching the hand.
func _touching_ally() -> Hero:
	var best: Hero = null
	var bd := INF
	var reach := float(cfg.grab) + host.tuning.body_radius
	for h in host.team_heroes(team):
		if h == owner_hero or h.state != Hero.State.FREE:
			continue
		if absf(h.global_position.y - global_position.y) > host.tuning.height_gap:
			continue
		var d := RB.flat_dist(h.global_position, global_position)
		if d <= reach and d < bd:
			bd = d
			best = h
	return best

func _pull(h: Hero) -> void:
	var to_inday := RB.flat(owner_hero.global_position - h.global_position)
	var dist := to_inday.length() - 2.0 * host.tuning.body_radius - float(cfg.gap)
	if dist > 0.05:
		h.apply_push(to_inday.normalized(), dist, false)
	host.emit_event("hila_pull", {"hero": owner_hero, "target": h, "distance": maxf(0.0, dist)})
	_close("pulled")

func _close(reason: String) -> void:
	if expired:
		return
	_close_reason = reason
	expire()

func palm_position() -> Vector3:
	return _palm.global_position if is_instance_valid(_palm) else global_position + Vector3.UP

func _on_expire() -> void:
	var at := palm_position()
	host.emit_event("hila_close", {"hero": owner_hero, "reason": _close_reason, "pos": at})
	# Gameplay ends now. The short returning hand is visual only: no rescue or grab queries.
	if not is_instance_valid(owner_hero) or not owner_hero.is_free() or not host.round_live():
		return
	var ghost := Node3D.new()
	ghost.name = "HilaReturn"
	host.world.add_child(ghost)
	_palm.reparent(ghost, true)
	_arm.reparent(ghost, true)
	var palm := _palm
	var arm := _arm
	var owner := owner_hero
	var match_host := host
	_palm = null
	_arm = null
	var tween := ghost.create_tween()
	tween.tween_method(func(progress: float) -> void:
		if not is_instance_valid(owner) or not owner.is_free() or not match_host.round_live():
			ghost.visible = false
			return
		var end := owner.visual.hand_position(0) if owner.visual else owner.global_position + Vector3.UP
		palm.global_position = at.lerp(end, progress)
		palm.scale = Vector3.ONE * lerpf(1.0, 0.5, progress)
		HilaHand.place_arm(arm, end, palm.global_position)
	, 0.0, 1.0, owner.tuning.hila_retract_time)
	tween.tween_callback(ghost.queue_free)

static func place_arm(arm: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	arm.visible = length > 0.02
	if arm.visible:
		arm.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.FORWARD if absf((to - from).normalized().y) > 0.99 else Vector3.UP), (from + to) * 0.5)
		arm.scale = Vector3(1, 1, length)

## Presentation: stretch the arm from Inday's shoulder to the palm.
func _process(_delta: float) -> void:
	if _arm == null or owner_hero == null or not is_instance_valid(owner_hero):
		return
	var from := owner_hero.visual.hand_position(0) if owner_hero.visual else owner_hero.global_position + Vector3.UP
	place_arm(_arm, from, _palm.global_position)
	var open := 1.0 if holding else clampf(travelled / maxf(0.01, float(cfg.range)), 0.0, 1.0)
	for i in range(_palm.get_child_count()):
		var finger := _palm.get_child(i) as Node3D
		finger.rotation.x = lerpf(0.3, PI * 0.5, open)
