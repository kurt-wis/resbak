extends Skill

## JM S2 TAMARAW!!! (docs/RESBAK.md § 4 JM). A charge along the aim at a fixed 9 m/s (no speed
## bonus, slows still apply) for up to 1.5 s; the heading turns toward the aim at most 90 deg/s.
## Pressing S2 again ends it. JM can't tag while charging. Each enemy touched is pushed 2 m
## sideways off the path, once per charge; allies are unaffected and don't block (JM moves on the
## ghost layer with no hero mask while charging). Hitting a wall or other solid thing (world, TALBOG!
## wall, pole, vaultable prop: a move_and_slide collision that is not the floor) ends the charge:
## enemies within 2.5 m are slowed 40 % for 1 s and JM is stunned 0.8 s (not by an enemy skill).
## Enemies in Escape Protection are shoved too (EP only protects against tags).

var _dir := Vector3(0, 0, 1)
var _left := 0 ## move ticks left
var _hit: Array[Hero] = [] ## enemies already shoved this charge
var _aura: Node3D
var _dust: CPUParticles3D

func kind() -> int:
	return RB.SkillKind.OFFENSIVE

func blocks_tagging() -> bool:
	return true

func blocks_other_skills() -> bool:
	return true

func controls_movement() -> bool:
	return true

func fixed_speed() -> float:
	return float(v("tamaraw_speed"))

func hud_note() -> String:
	return "" if not active else "%.1f s" % RB.seconds(_left)

func _cast(_frame: InputFrame) -> void:
	_dir = RB.flat(hero.aim if hero.aim.length() > 0.01 else hero.facing).normalized()
	_left = maxi(1, RB.ticks(v("tamaraw_time")))
	_hit.clear()
	active = true
	_ghost_body()
	hero.facing = _dir
	_build_aura()
	hero.visual.play_action("Tamaraw")
	host.emit_event("tamaraw_start", {"hero": hero, "dir": _dir})

func on_recast(_frame: InputFrame) -> void:
	if active:
		end("recast")

func on_owner_event(event: String, _data: Variant) -> void:
	if active and event == "stunned":
		end("stunned")

func move(dt: float) -> void:
	_ghost_body() # EP / state changes elsewhere may have reset the layers
	# Steer toward the aim, at most turn_rate deg/s.
	var want := hero.aim
	if want.length() > 0.01:
		var ang := _dir.signed_angle_to(RB.flat(want).normalized(), Vector3.UP)
		var lim := deg_to_rad(float(v("tamaraw_turn_rate_deg"))) * dt
		_dir = _dir.rotated(Vector3.UP, clampf(ang, -lim, lim)).normalized()
	var spd := hero.current_speed()
	hero.velocity = Vector3(_dir.x * spd, hero.velocity.y, _dir.z * spd)
	hero.move_body(dt)
	hero.facing = _dir
	if _aura:
		_aura.rotation.y = atan2(_dir.x, _dir.z)
	_shove_touched()
	if _hit_solid():
		_crash()
		return
	_left -= 1
	if _left <= 0:
		end("expired")

## Enemies in contact are pushed 2 m to the side of the path they are on, once each.
func _shove_touched() -> void:
	var t := host.tuning
	var touch := t.body_radius * 2.0 + 0.15
	var side := float(v("tamaraw_push_side"))
	for e in host.enemies_of(hero):
		if not e.is_free() or _hit.has(e):
			continue
		if absf(e.global_position.y - hero.global_position.y) > t.height_gap:
			continue
		var rel := RB.flat(e.global_position - hero.global_position)
		if rel.length() > touch:
			continue
		var perp := Vector3(_dir.z, 0.0, -_dir.x) # right of the path
		var s := signf(rel.dot(perp))
		if s == 0.0:
			s = 1.0 if (e.slot % 2) == 0 else -1.0
		_hit.append(e)
		e.apply_push(perp * s, side, true)
		Vfx.burst(host.world, e.global_position + Vector3(0, 0.9, 0), Color(1, 0.8, 0.4, 0.9), 10, 3.0, 0.3, 0.12)
		host.emit_event("tamaraw_shove", {"hero": hero, "target": e})

## A non-floor collision from this tick's move_and_slide.
func _hit_solid() -> bool:
	for i in range(hero.get_slide_collision_count()):
		var c := hero.get_slide_collision(i)
		if c.get_collider() is CharacterBody3D:
			continue
		if c.get_normal().y < 0.6:
			return true
	return false

func _crash() -> void:
	var pos := hero.global_position
	end("wall")
	var radius := float(v("tamaraw_wall_radius"))
	for e in host.enemies_of(hero):
		if e.is_free() and RB.flat_dist(e.global_position, pos) <= radius:
			e.add_slow(float(v("tamaraw_wall_slow")), float(v("tamaraw_wall_slow_time")), "tamaraw_wall", true)
	hero.stun(float(v("tamaraw_self_stun")), false)
	Vfx.ring_pulse(host.world, pos, radius, Color(0.9, 0.75, 0.5, 0.8), 0.4)
	Vfx.burst(host.world, pos + Vector3(0, 0.6, 0), Color(0.85, 0.7, 0.5, 0.9), 30, 4.5, 0.6, 0.3, -3.0, 90.0)
	host.emit_event("tamaraw_crash", {"hero": hero, "pos": pos})

func end(_reason: String) -> void:
	if active:
		active = false
		hero._update_collision()
		if hero.visual:
			hero.visual.stop_action("Tamaraw")
	_left = 0
	_free_aura()

# ---- body layers ---------------------------------------------------------------------------
## Pass through players, stay solid to the world.
func _ghost_body() -> void:
	hero.collision_layer = RB.L_GHOST
	hero.collision_mask = RB.MASK_MOVE

# ---- tamaraw aura (a see-through carabao with V horns, trailing dust) ------------------------
func _build_aura() -> void:
	_free_aura()
	var ex := hero.visual.extras
	_aura = Node3D.new()
	_aura.name = "TamarawAura"
	ex.add_child(_aura)
	var gold := Vfx.flat_material(Color(1.0, 0.78, 0.25, 0.32))
	var horn := Vfx.flat_material(Color(1.0, 0.95, 0.75, 0.55))
	var body := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.8
	bs.height = 1.6
	body.mesh = bs
	body.scale = Vector3(0.95, 0.7, 1.55)
	body.position = Vector3(0, 0.85, -0.2)
	body.material_override = gold
	_aura.add_child(body)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.38
	hs.height = 0.76
	head.mesh = hs
	head.scale = Vector3(0.9, 0.95, 1.25)
	head.position = Vector3(0, 0.95, 1.1)
	head.material_override = gold
	_aura.add_child(head)
	for sgn in [-1.0, 1.0]:
		var h := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.07
		cm.height = 0.95
		h.mesh = cm
		h.material_override = horn
		# V-shaped horns: sweep up and back-out from the forehead
		h.position = Vector3(0.22 * sgn, 1.42, 1.0)
		h.rotation = Vector3(deg_to_rad(-25.0), 0.0, deg_to_rad(-35.0 * sgn))
		_aura.add_child(h)
	_aura.rotation.y = atan2(_dir.x, _dir.z)
	_dust = Vfx.emitter(_aura, Color(0.85, 0.7, 0.5, 0.7), 28, 0.6, 0.3, 1.2, Vector3(0, 0.15, -1.0), true)
	_dust.emitting = true

func _free_aura() -> void:
	if _aura != null and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null
	_dust = null

func _exit_tree() -> void:
	_free_aura()
