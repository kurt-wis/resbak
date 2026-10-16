extends Skill

## Nene S1 IYAK! (docs/RESBAK.md § 4 Nene). Leaves a crying decoy (IyakDecoy, 5 s) where she
## stands and makes Nene see-through for 3 s (enemies see 25 % opacity; the outline and the
## minimap marker stay). The see-through ends early on Tag press, her other skill, capture
## start, a rescue, and when she stops being Free (tagged). The placed decoy always lasts its
## full time. Type: Neither (Escape Protection is not ended by it).
## `active` stays false on purpose: an active skill would stop her starting a capture
## (Hero.can_start_capture), but the spec lets her capture and just ends the see-through.

var _left := 0 ## see-through ticks left

func kind() -> int:
	return RB.SkillKind.NEITHER

func _ready() -> void:
	if hero:
		hero.state_changed.connect(_on_hero_state)

func see_through_active() -> bool:
	return _left > 0

func _cast(_frame: InputFrame) -> void:
	var decoy := IyakDecoy.new()
	decoy.setup(host, hero, v("iyak_decoy_time"))
	host.spawn_object(decoy, hero.global_position)
	_left = RB.ticks(v("iyak_see_through_time"))
	hero.enemy_alpha = v("iyak_see_through_alpha")
	host.emit_event("iyak", {"hero": hero, "decoy": decoy})

func tick(_dt: float) -> void:
	if _left <= 0:
		return
	if _left > 1:
		_left -= 1
	else:
		end("expired")

func end(_reason: String) -> void:
	if _left > 0:
		hero.enemy_alpha = 1.0
	_left = 0
	active = false

func _on_hero_state(_hero: Hero, _old: int, new_state: int) -> void:
	if new_state != Hero.State.FREE:
		end("tagged")

func on_owner_event(event: String, _data: Variant) -> void:
	if _left > 0 and event in ["tag_pressed", "skill_cast", "capture_start", "rescue"]:
		end(event)

func hud_note() -> String:
	return "%.1f s" % RB.seconds(_left) if _left > 0 else ""
