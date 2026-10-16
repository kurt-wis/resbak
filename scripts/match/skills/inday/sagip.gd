extends Skill

## Inday S2 SAGIP! (docs/RESBAK.md § 4 Inday). For sagip_time seconds Inday frees a chain when her
## centre is within sagip_reach metres of its tip (or a lone anchor's hand point), no touch
## and no button. The JailSystem asks ranged_rescue_reach() each tick (step 6) and checks the
## line of sight itself (walls, solid props and TALBOG! walls block; players and clouds don't).
## It does not end when she is stunned or pushed; only the timer, a tag or a reset end it.

const CLIP := "Sagip"
const AURA_COLOR := Color(1.0, 0.86, 0.35, 0.9)

var _left := 0
var _aura: Node3D

func kind() -> int:
	return RB.SkillKind.NEITHER

func _cast(_frame: InputFrame) -> void:
	active = true
	_left = RB.ticks(v("sagip_time", 4.0))
	hero.visual.play_action(CLIP)
	_build_aura()

func tick_action(_frame: InputFrame) -> void:
	if not active:
		return
	if _left <= 0:
		end("expired")
		return
	_left -= 1

func tick(_dt: float) -> void:
	if _aura != null and is_instance_valid(_aura):
		_aura.global_position = hero.global_position + Vector3(0, 0.06, 0)

func ranged_rescue_reach() -> float:
	return float(v("sagip_reach", 3.0)) if active else -1.0

func end(_reason: String) -> void:
	active = false
	_left = 0
	if _aura != null and is_instance_valid(_aura):
		_aura.visible = false
		if _aura.get_parent():
			_aura.get_parent().remove_child(_aura)
		_aura.queue_free()
	_aura = null

func hud_note() -> String:
	return "%.1f s" % RB.seconds(_left) if active else ""

func _build_aura() -> void:
	if _aura != null and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = Vfx.ground_ring(host.world, hero.global_position, float(v("sagip_reach", 3.0)), AURA_COLOR, 0.14, 0.1)
	_aura.name = "SagipAura"
