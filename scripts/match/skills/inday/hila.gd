extends Skill

## Inday S2 HILA! (v0.2, replaces SAGIP!; docs/status.md). Inday stretches her hand along her
## aim (HilaHand): it flies out up to hila_range metres (walls stop it) and stays open for
## hila_hold seconds. The first Free teammate who touches it is yanked to her. A chain tip
## it touches is rescued as if Inday touched it (a rescue by skill, so TAKBO NA! applies),
## and the freed tip is pulled in next. Type: Neither.

const CLIP := "Sagip"

var _hand: HilaHand

func kind() -> int:
	return RB.SkillKind.NEITHER

func _cast(frame: InputFrame) -> void:
	var dir := frame.aim_direction(hero.global_position)
	if dir == Vector3.ZERO:
		dir = hero.aim
	dir = RB.flat(dir).normalized()
	if dir == Vector3.ZERO:
		dir = Vector3.RIGHT if hero.team == RB.DILAW else Vector3.LEFT
	_hand = HilaHand.new()
	_hand.begin(host, hero, dir, {
		"speed": float(v("hila_speed")),
		"range": float(v("hila_range")),
		"hold": float(v("hila_hold")),
		"grab": float(v("hila_grab")),
		"gap": float(v("hila_gap")),
	})
	host.spawn_object(_hand, hero.global_position + dir * host.tuning.body_radius)
	if hero.visual:
		var clip_time := minf(hero.visual.clip_length(CLIP), 0.6)
		if clip_time > 0.0:
			hero.visual.play_action(CLIP, clip_time)
	host.emit_event("hila", {"hero": hero, "dir": dir, "object": _hand})

## The open hand counts as Inday's touch for a chain tip (JailSystem step 6).
func rescue_touch_point() -> Vector3:
	if _hand == null or not is_instance_valid(_hand) or _hand.expired:
		return Vector3.INF
	return _hand.global_position

func rescue_touch_radius() -> float:
	return float(v("hila_grab"))

func end(_reason: String) -> void:
	active = false
	if _hand != null and is_instance_valid(_hand) and not _hand.expired:
		_hand.expire()
	_hand = null
