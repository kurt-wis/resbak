extends Skill

## Tutoy S2 LUSOT! (docs/RESBAK.md § 4 Tutoy): slide 4 m over 0.4 s along the movement
## direction (aim if standing still). Vaults props on RB.L_VAULTABLE (that mask bit is dropped
## for the slide); stops at players, walls and map edges. No tagging for 0.3 s after (and none
## during the slide). PERFECT: an enemy's tag that would have hit Tutoy at slide start and lands
## within 6 ticks of the slide start (incl. the landing tick) misses; the TagSystem stuns that
## tagger for lusot_perfect_stun (via evade_tag / evade_stun_seconds). Otherwise the tag is
## checked against the new position like any other.

const GOLD := Color("ffd700")

var start_pos := Vector3.ZERO
var slide_dir := Vector3.RIGHT
var vaulting := false ## the path holds a vaultable prop (Lusot_Vault clip)
var distance_done := 0.0

var _ticks_total := 0
var _ticks_done := 0
var _extra := 0
var _speed := 0.0
var _blocked := false
var _had_ep := false
var _ignored: Array[Hero] = []
var _dust: CPUParticles3D

func _ready() -> void:
	host.event.connect(_on_host_event)

func kind() -> int:
	return RB.SkillKind.MOVEMENT

func _can_cast_extra() -> bool:
	return hero.is_on_floor()

func try_cast(frame: InputFrame) -> bool:
	_had_ep = hero.has_ep() # a tag could not have hit Tutoy under EP; casting clears it
	return super.try_cast(frame)

func blocks_tagging() -> bool:
	return active

func controls_movement() -> bool:
	return active

func _cast(_frame: InputFrame) -> void:
	slide_dir = _pick_dir()
	start_pos = hero.global_position
	_ticks_total = RB.ticks(float(v("lusot_time")))
	_ticks_done = 0
	_extra = 0
	distance_done = 0.0
	_blocked = false
	_speed = float(v("lusot_distance")) / RB.seconds(_ticks_total)
	active = true
	hero.windup_end_tick = -1 # a half-wound tag is dropped
	hero.collision_mask &= ~RB.L_VAULTABLE
	vaulting = _path_has_vaultable()
	_ignored.clear()
	var window := RB.ticks(float(v("lusot_perfect_window")))
	for e in host.enemies_of(hero): # enemies whose tag could be perfect-dodged pass through us
		if e.is_free() and e.windup_end_tick >= host.tick and e.windup_end_tick - host.tick < window and _would_hit(e, e.lunge_dir):
			hero.add_collision_exception_with(e)
			_ignored.append(e)
	hero.visual.play_action("Lusot_Vault" if vaulting else "Lusot_Slide", float(v("lusot_time")))
	Vfx.burst(host.world, start_pos + Vector3(0, 0.12, 0), Color(0.82, 0.76, 0.66, 0.85), 18, 2.8, 0.4, 0.2, -1.0, 55.0, -slide_dir + Vector3.UP * 0.4)
	if _dust == null and hero.visual.extras:
		_dust = Vfx.emitter(hero.visual.extras, Color(0.82, 0.76, 0.66, 0.8), 28, 0.35, 0.2, 1.0, Vector3(0, 0.1, 0))
	if _dust:
		_dust.emitting = true

func move(dt: float) -> void:
	hero.collision_mask &= ~RB.L_VAULTABLE
	var before := hero.global_position
	hero.velocity = Vector3(slide_dir.x * _speed, hero.velocity.y, slide_dir.z * _speed)
	hero.move_body(dt)
	var progress := RB.flat(hero.global_position - before).dot(slide_dir)
	distance_done += progress
	if progress < _speed * dt * 0.5: # a player, wall or map edge in the way
		_blocked = true

func tick(_dt: float) -> void:
	if not active:
		return
	if _blocked:
		end("blocked")
		return
	_ticks_done += 1
	if _ticks_done >= _ticks_total:
		# Never end inside a prop we are vaulting: keep gliding until clear (bounded).
		var max_extra := RB.ticks(float(v("lusot_vault_extra", 0.5)))
		if _extra < max_extra and _overlaps_vaultable():
			_extra += 1
		else:
			end("expired")

func end(reason: String) -> void:
	var was_active := active
	active = false
	if _dust:
		_dust.emitting = false
	for e in _ignored:
		if is_instance_valid(e):
			hero.remove_collision_exception_with(e)
	_ignored.clear()
	if was_active:
		hero.visual.stop_action("Lusot_Slide")
		hero.visual.stop_action("Lusot_Vault")
		hero._update_collision() # restores the vaultable mask bit
		if reason != "tagged" and reason != "reset" and reason != "round_end":
			hero.tag_block_ticks = maxi(hero.tag_block_ticks, RB.ticks(float(v("lusot_no_tag_after"))))

func on_owner_event(event: String, _data: Variant) -> void:
	if active and (event == "pushed" or event == "stunned"):
		end(event)

func evade_tag(tagger: Hero, lunge_dir: Vector3) -> bool:
	if cast_tick < 0 or hero.state != Hero.State.FREE or _had_ep:
		return false
	var since := host.tick - cast_tick # the tag lands this tick
	if since < 0 or since >= RB.ticks(float(v("lusot_perfect_window"))):
		return false
	return _would_hit(tagger, lunge_dir)

func evade_stun_seconds() -> float:
	return float(v("lusot_perfect_stun"))

# ---- helpers ---------------------------------------------------------------------------
## Would `tagger`'s tag (lunging along `lunge`) have hit Tutoy standing at the slide start?
func _would_hit(tagger: Hero, lunge: Vector3) -> bool:
	if tagger.team == hero.team or _had_ep:
		return false
	if absf(tagger.global_position.y - start_pos.y) > host.tuning.height_gap:
		return false
	return host.tag_system.in_tag_shape(tagger, lunge, start_pos, host.tuning.body_radius)

func _pick_dir() -> Vector3:
	if hero.frame.skill_aimed:
		return hero.frame.aim_direction(hero.global_position)
	if hero.wish_dir != Vector3.ZERO:
		return hero.wish_dir
	if hero.ground_speed() > 1.0:
		return RB.flat(hero.velocity).normalized()
	var a := RB.flat(hero.aim)
	return a.normalized() if a.length() > 0.01 else RB.flat(hero.facing).normalized()

func _space() -> PhysicsDirectSpaceState3D:
	return host.world.get_world_3d().direct_space_state

func _shape_query() -> PhysicsShapeQueryParameters3D:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = hero.body_shape.shape
	q.transform = hero.body_shape.global_transform
	q.collision_mask = RB.L_VAULTABLE
	return q

func _path_has_vaultable() -> bool:
	var q := _shape_query()
	q.motion = slide_dir * float(v("lusot_distance"))
	var res := _space().cast_motion(q)
	return res.size() >= 2 and (res[0] < 1.0 or res[1] < 1.0)

func _overlaps_vaultable() -> bool:
	return not _space().intersect_shape(_shape_query(), 1).is_empty()

## Presentation for a perfect slide (the TagSystem emits "perfect_slide" when it applies it).
func _on_host_event(kind_name: String, d: Dictionary) -> void:
	if kind_name != "perfect_slide" or d.evader != hero:
		return
	var pos := hero.global_position
	Vfx.popup_text(host.world, pos, "LUSOT!", GOLD, 120)
	Vfx.popup_text(host.world, d.tagger.global_position, "PERFECT!", GOLD, 120)
	Vfx.ring_pulse(host.world, pos, 3.0, GOLD, 0.5)
	Vfx.burst(host.world, pos + Vector3(0, 0.9, 0), GOLD, 44, 5.5, 0.6, 0.18, -2.0)
	var flash := OmniLight3D.new()
	flash.light_color = GOLD
	flash.light_energy = 6.0
	flash.omni_range = 5.0
	host.world.add_child(flash)
	flash.global_position = pos + Vector3(0, 1.2, 0)
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)
