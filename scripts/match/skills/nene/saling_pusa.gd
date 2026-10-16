extends Passive

## Nene passive SALING-PUSA (docs/RESBAK.md § 4 Nene): after 4 continuous seconds with no free
## enemy within 8 m, her footsteps go silent (no sound, no on-screen cue). It ends when a free
## enemy comes within 4 m or she uses a skill, and can start again after another 4 s with no
## free enemy within 8 m. Only counts while the round is live and she is Free. Stays on in
## Tradisyonal (passives stay when Skills are Off).

var _quiet := 0 ## continuous ticks with no free enemy within the clear radius
var _silent := false

func tick(_dt: float) -> void:
	if not hero.is_free() or not host.round_live():
		_reset()
		return
	var nearest := INF
	for e in host.enemies_of(hero):
		if e.is_free():
			nearest = minf(nearest, RB.flat_dist(e.global_position, hero.global_position))
	if _silent:
		if nearest <= float(v("saling_pusa_break_radius")):
			_reset()
		return
	if nearest <= float(v("saling_pusa_clear_radius")):
		_quiet = 0
		return
	_quiet += 1
	if _quiet >= RB.ticks(v("saling_pusa_quiet_time")):
		_silent = true

func _reset() -> void:
	_quiet = 0
	_silent = false

func on_skill_cast(_skill: Skill) -> void:
	_reset()

func on_round_reset() -> void:
	_reset()

func on_jailed() -> void:
	_reset()

func footsteps_silent() -> bool:
	return _silent and hero.is_free()

func hud_state() -> Dictionary:
	var need := maxi(1, RB.ticks(v("saling_pusa_quiet_time")))
	return {"fill": 1.0 if _silent else clampf(float(_quiet) / need, 0.0, 1.0), "on": _silent,
		"note": "Silent" if _silent else ""}
