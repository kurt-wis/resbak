extends Skill

## JM S2 TAMARAW!!! (docs/RESBAK.md § 4 JM). A charge along the movement stick (or where he
## faces when the stick is centred) at a fixed 9 m/s (no speed bonus, slows still apply) for up
## to 1.5 s; the heading turns toward the stick at most 90 deg/s. There is no aim: the mouse or
## the aim stick never steers it.
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

func is_traversal() -> bool:
	return true

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

## The charge follows the movement stick (and facing when the stick is centred), never the aim.
func aim_from_movement() -> bool:
	return true

## Direction the charge uses right now: the stick, else where JM is facing.
func charge_heading() -> Vector3:
	var wish := RB.flat(hero.wish_dir)
	if wish.length() > 0.01:
		return wish.normalized()
	var face := RB.flat(hero.facing)
	return face.normalized() if face.length() > 0.01 else Vector3.FORWARD

func _cast(_frame: InputFrame) -> void:
	_dir = charge_heading()
	_left = maxi(1, RB.ticks(v("tamaraw_time")))
	_hit.clear()
	active = true
	_ghost_body()
	hero.facing = _dir
	_build_aura()
	hero.visual.play_action("Tamaraw")
	host.emit_event("tamaraw_start", {"hero": hero, "dir": _dir})

func can_recast() -> bool:
	return active

func on_recast(_frame: InputFrame) -> void:
	if active:
		end("recast")

func on_owner_event(event: String, _data: Variant) -> void:
	if active and event == "stunned":
		end("stunned")

func move(dt: float) -> void:
	_ghost_body() # EP / state changes elsewhere may have reset the layers
	# Steer toward the movement stick, at most turn_rate deg/s.
	var want := charge_heading()
	var ang := _dir.signed_angle_to(want, Vector3.UP)
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
		e.add_slow(float(v("tamaraw_contact_slow")), float(v("tamaraw_contact_slow_time")), "tamaraw_daze", true)
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
		if _reason in ["recast", "expired"]:
			hero.plant_cast(float(v("tamaraw_recovery")))
		hero._update_collision()
		if hero.visual:
			hero.visual.stop_action("Tamaraw")
			if _reason in ["recast", "expired"] and _hit.is_empty():
				hero.visual.play_tamaraw_miss()
				host.emit_event("tamaraw_miss", {"hero": hero})
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
	_aura = Node3D.new()
	_aura.name = "TamarawAura"
	hero.visual.extras.add_child(_aura)
	var spirit := preload("res://assets/props/tamaraw_spirit.glb").instantiate() as Node3D
	spirit.scale = Vector3(1.45, 1.15, 1.0)
	spirit.position = Vector3(0, 0.08, 0.1)
	_aura.add_child(spirit)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/tamaraw_spirit.gdshader")
	material.set_shader_parameter("opacity", 0.0)
	_aura.set_meta("spirit_material", material)
	for mesh in spirit.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var players := spirit.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var player := players[0] as AnimationPlayer
		for clip in player.get_animation_list():
			if "Spirit_Charge" in clip:
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				player.play(clip)
				break
	_aura.create_tween().tween_method(func(k: float): material.set_shader_parameter("opacity", k), 0.0, 1.0, 0.12)
	_aura.rotation.y = atan2(_dir.x, _dir.z)
	_dust = Vfx.emitter(_aura, Color(1.0, 0.72, 0.2, 0.6), 24, 0.4, 0.1, 0.8, Vector3(0, 0.6, -0.9), true)
	_dust.emitting = true

func _free_aura() -> void:
	if _aura != null and is_instance_valid(_aura):
		var ghost := _aura
		if is_inside_tree() and not is_queued_for_deletion() and hero.is_free() and host.round_live():
			ghost.top_level = true # keep visibility inherited from the owner, but stop following
			if _dust:
				_dust.emitting = false
			var material: ShaderMaterial = ghost.get_meta("spirit_material")
			var tween := ghost.create_tween()
			tween.tween_method(func(k: float): material.set_shader_parameter("opacity", k), 1.0, 0.0, float(v("tamaraw_spirit_fade")))
			tween.tween_callback(ghost.queue_free)
		else:
			ghost.queue_free()
	_aura = null
	_dust = null

func _exit_tree() -> void:
	if is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null
	_dust = null
