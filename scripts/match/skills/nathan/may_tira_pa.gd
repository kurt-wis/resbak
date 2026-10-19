extends Passive

## Nathan passive MAY TIRA PA! (docs/RESBAK.md § 4 Nathan).
## After any skill, the next movement turn of more than 90 deg within 0.5 s drops a powder
## patch (r 1 m, visible to all) where he stands. One patch: a new one replaces the old; it
## lasts until an enemy centre enters it (TiraPatch) or the round ends.
## A turn = the move direction now vs the direction he was heading ~0.2 s ago (or his last
## heading if he had stopped), so keyboard reversals and fast stick flicks count but slow
## curves do not.

var patch: TiraPatch
var _window_end := -1 ## last host tick a turn still drops a patch
var _hist: Array = [] ## recent non-zero move directions: {tick, dir}

func on_skill_cast(skill: Skill) -> void:
	_window_end = host.tick + RB.ticks(float(v("tira_turn_window")))
	# A plant longer than the reaction window must not consume the entire passive.
	if skill.cast_plant_seconds() > float(v("tira_turn_window")):
		_window_end += RB.ticks(skill.cast_plant_seconds())

func tick(_dt: float) -> void:
	if not hero.is_free() or not hero.can_move():
		return
	var dir := hero.wish_dir
	if dir == Vector3.ZERO:
		return
	var sample := RB.ticks(float(v("tira_turn_sample", 0.2)))
	while _hist.size() > 1 and host.tick - int(_hist[0].tick) > sample:
		_hist.pop_front()
	if _window_end >= host.tick and not _hist.is_empty():
		var ref: Vector3 = _hist[0].dir
		if rad_to_deg(ref.angle_to(dir)) > float(v("tira_turn_deg")) + 0.01:
			_drop()
	_hist.append({"tick": host.tick, "dir": dir})

func _drop() -> void:
	_window_end = -1
	if has_patch():
		patch.expire()
	patch = TiraPatch.new()
	patch.begin(host, hero, float(v("tira_patch_radius")), float(v("tira_reveal_time")))
	host.spawn_object(patch, hero.global_position)
	patch.build_visuals()
	host.emit_event("patch_drop", {"hero": hero, "pos": hero.global_position, "patch": patch})

func has_patch() -> bool:
	return patch != null and is_instance_valid(patch) and not patch.expired

func armed() -> bool:
	return _window_end >= host.tick

func on_round_reset() -> void:
	patch = null
	_window_end = -1
	_hist.clear()

func hud_state() -> Dictionary:
	if has_patch():
		return {"fill": 1.0, "on": true, "placed": true, "armed": false, "note": "PATCH"}
	if armed():
		var left := float(_window_end - host.tick + 1) / maxf(1.0, RB.ticks(float(v("tira_turn_window"))))
		return {"fill": clampf(left, 0.0, 1.0), "on": true, "placed": false, "armed": true, "note": "TURN!"}
	return {"fill": 0.0, "on": false, "placed": false, "armed": false, "note": ""}
