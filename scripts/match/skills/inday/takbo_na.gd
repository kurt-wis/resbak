extends Passive

## Inday passive TAKBO NA! (docs/RESBAK.md § 4 Inday). After any rescue by Inday (touch or
## HILA!), she and every teammate she freed get +takbo_bonus speed for takbo_time seconds, once
## per rescue (source "takbo"; Hero uses the biggest bonus, so it never stacks with IHIP!).
## The prisoners she frees also get takbo_extra_protection more seconds of Escape Protection
## (4 s -> 5 s); the JailSystem reads that through extra_rescue_protection().

const SOURCE := "takbo"

var _left := 0 ## her own boost, ticks left (for the HUD icon)

func on_rescue_performed(freed: Array, _by_skill: bool) -> void:
	var bonus := float(v("takbo_bonus", 0.2))
	var secs := float(v("takbo_time", 2.0))
	hero.add_speed_bonus(bonus, secs, SOURCE)
	for f in freed:
		var h := f as Hero
		if h != null and h != hero:
			h.add_speed_bonus(bonus, secs, SOURCE)
	_left = RB.ticks(secs)
	if host and host.world:
		Vfx.ring_pulse(host.world, hero.global_position, 1.6, Color(1.0, 0.86, 0.35, 0.9), 0.4)
		for f in freed:
			Vfx.burst(host.world, (f as Hero).global_position + Vector3(0, 0.9, 0), Color(1.0, 0.9, 0.5, 0.9), 14, 2.5, 0.5, 0.14)

func extra_rescue_protection() -> float:
	return float(v("takbo_extra_protection", 1.0))

func tick(_dt: float) -> void:
	if _left > 0:
		_left -= 1

func on_jailed() -> void:
	_left = 0

func on_round_reset() -> void:
	_left = 0

func hud_state() -> Dictionary:
	var total := maxf(float(RB.ticks(float(v("takbo_time", 2.0)))), 1.0)
	return {"fill": clampf(_left / total, 0.0, 1.0), "on": _left > 0, "note": ("%.1f s" % RB.seconds(_left)) if _left > 0 else ""}
