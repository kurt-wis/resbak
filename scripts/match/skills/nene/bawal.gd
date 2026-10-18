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
var sign_board: MeshInstance3D

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
	Vfx.sound_shell(host.world, hero.global_position + Vector3.UP, hero.facing, Color("ff467d"), 1.3)
	Vfx.burst(host.world, tagger.global_position + Vector3.UP, Color("dc99ff"), 22, 2.2, 0.45, 0.1, 0.0)
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

func _show_sign(_on: bool) -> void:
	# HeroVisual reads warded() and applies a red glow to the skinned body.
	pass

func hud_note() -> String:
	return "%.1f s" % RB.seconds(_left) if _left > 0 else ""
