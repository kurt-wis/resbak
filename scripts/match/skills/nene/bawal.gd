extends Skill

## Nene S2 BAWAL! (v0.2, replaces SUMBONG KITA!; docs/status.md). For bawal_time seconds a
## "BAWAL!" sign hangs over her head, seen by everyone: don't hit me. An enemy tag that lands
## on her while it is up does not count; instead the tagger hallucinates for
## bawal_hallucinate_time seconds (Hero.hallucinate: the move stick is turned around, and a
## player's screen warps). One curse per cast: the sign drops after it fires. The sign also
## drops when she presses Tag, starts a capture or stops being Free.
## `active` stays false so she may still start a capture (that ends the sign).
## Type: Neither.

var _left := 0
var sign_label: Label3D

func kind() -> int:
	return RB.SkillKind.NEITHER

func _ready() -> void:
	if hero:
		hero.state_changed.connect(_on_hero_state)

func warded() -> bool:
	return _left > 0

func _cast(_frame: InputFrame) -> void:
	_left = RB.ticks(v("bawal_time"))
	_show_sign(true)
	host.emit_event("bawal", {"hero": hero, "seconds": float(v("bawal_time"))})

func tick(_dt: float) -> void:
	if _left <= 0:
		return
	_left -= 1
	if _left == 0:
		end("expired")

func absorb_tag(tagger: Hero) -> bool:
	if _left <= 0:
		return false
	tagger.hallucinate(v("bawal_hallucinate_time"))
	host.emit_event("bawal_curse", {"hero": hero, "tagger": tagger, "seconds": float(v("bawal_hallucinate_time"))})
	end("absorbed")
	return true

func end(_reason: String) -> void:
	_left = 0
	active = false
	_show_sign(false)

func _on_hero_state(_hero: Hero, _old: int, new_state: int) -> void:
	if new_state != Hero.State.FREE:
		end("tagged")

func on_owner_event(event: String, _data: Variant) -> void:
	if _left > 0 and event in ["tag_pressed", "capture_start"]:
		end(event)

func _show_sign(on: bool) -> void:
	if on and sign_label == null:
		sign_label = Label3D.new()
		sign_label.name = "BawalSign"
		sign_label.text = "BAWAL!"
		sign_label.font_size = 96
		sign_label.pixel_size = 0.005
		sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign_label.modulate = Color("ff3b5c")
		sign_label.outline_modulate = Color("1a0610")
		sign_label.outline_size = 20
		sign_label.no_depth_test = true
		sign_label.position = Vector3(0, hero.data.model_height + 0.75, 0)
		hero.add_child(sign_label)
	if sign_label:
		sign_label.visible = on

func hud_note() -> String:
	return "%.1f s" % RB.seconds(_left) if _left > 0 else ""
