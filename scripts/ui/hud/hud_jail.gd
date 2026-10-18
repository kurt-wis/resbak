class_name HudJail
extends HudPart

## Jail screen (docs/RESBAK.md § 7; v0.1.1 automatic chain): while the local hero is jailed,
## above the chain card: how long the chain is and how far the tip is from the nearest free
## teammate (whole metres), so the tip knows which way to stretch. There is no button prompt
## any more: the chain forms by itself and nobody lets go (see JailSystem).

var prompt: Label
var chain_label: Label
var dist_label: Label
var prompt_text := ""
var chain_text := ""
var dist_text := ""

func _init() -> void:
	prompt = HudStyle.label(self, 32, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.GOLD)
	chain_label = HudStyle.label(self, 28, HORIZONTAL_ALIGNMENT_CENTER)
	dist_label = HudStyle.label(self, 34, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.GOLD)

func _layout() -> void:
	var s := sz()
	prompt.position = Vector2(0, s.y - 300.0)
	prompt.size = Vector2(s.x, 44)
	chain_label.position = Vector2(0, s.y - 252.0)
	chain_label.size = Vector2(s.x, 40)
	dist_label.position = Vector2(0, s.y - 214.0)
	dist_label.size = Vector2(s.x, 44)

## Interact never acts in jail now (kept for older callers): always "".
func interact_action() -> String:
	return ""

func refresh(_delta: float) -> void:
	var me := hud.local
	var host := hud.host
	var jailed := me != null and (me.state == Hero.State.JAILED or me.state == Hero.State.CHAINED)
	visible = jailed
	if not jailed:
		prompt_text = ""
		chain_text = ""
		dist_text = ""
		return
	var jail_owner := RB.other_team(me.team)
	var c: Array = host.jail_system.chain(jail_owner)
	prompt_text = ""
	chain_text = "Kadena %d/%d" % [c.size(), host.jail_system.prisoners(jail_owner).size()]
	var from: Vector3 = (c[-1] as Hero).global_position if not c.is_empty() else host.jail_system.post(jail_owner)
	var best := -1.0
	for a in host.allies_of(me):
		if a.is_free():
			var d := RB.flat_dist(a.global_position, from)
			if best < 0.0 or d < best:
				best = d
	dist_text = "Pinakamalapit na kakampi: %d m" % roundi(best) if best >= 0.0 else "Walang malayang kakampi"
	prompt.text = prompt_text
	chain_label.text = ""
	dist_label.text = dist_text
