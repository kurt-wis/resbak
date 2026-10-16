class_name HudJail
extends HudPart

## Jail screen (docs/RESBAK.md § 7): while the local hero is jailed or chained -- the Interact
## prompt only when it would act (hold on / let go, key per device), the chain length
## linked/prisoners (e.g. 2/3), and whole metres from the chain tip (no chain: the jail
## marker) to the nearest free teammate.

var prompt: Label
var chain_label: Label
var dist_label: Label
var prompt_text := ""
var chain_text := ""
var dist_text := ""

func _init() -> void:
	prompt = HudStyle.label(self, 32, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.GOLD)
	chain_label = HudStyle.label(self, 30, HORIZONTAL_ALIGNMENT_CENTER)
	dist_label = HudStyle.label(self, 30, HORIZONTAL_ALIGNMENT_CENTER)

func _layout() -> void:
	var s := sz()
	prompt.position = Vector2(0, s.y - 238.0)
	prompt.size = Vector2(s.x, 48)
	chain_label.position = Vector2(0, s.y - 342.0)
	chain_label.size = Vector2(s.x, 44)
	dist_label.position = Vector2(0, s.y - 296.0)
	dist_label.size = Vector2(s.x, 44)

## What Interact would do for the local hero right now: "hold", "let_go" or "".
func interact_action() -> String:
	var me := hud.local
	var host := hud.host
	if me == null or not host.round_live():
		return ""
	var jail_owner := RB.other_team(me.team)
	var c: Array = host.jail_system.chain(jail_owner)
	if me.state == Hero.State.CHAINED:
		return "let_go"
	if me.state != Hero.State.JAILED:
		return ""
	var t := host.tuning
	if c.is_empty():
		return "hold" if RB.flat_dist(me.global_position, host.layout.marker(jail_owner)) <= t.anchor_range else ""
	if c.size() >= t.chain_max:
		return ""
	var anchor: Hero = c[0]
	var tip: Hero = c[-1]
	if RB.flat_dist(me.global_position, anchor.global_position) <= t.join_range or RB.flat_dist(me.global_position, tip.global_position) <= t.join_range:
		return "hold"
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
	var key := hud.key_label("interact")
	match interact_action():
		"hold":
			prompt_text = "Pindutin ang %s para kumapit" % key
		"let_go":
			prompt_text = "Pindutin ang %s para bumitaw" % key
		_:
			prompt_text = ""
	chain_text = "Kadena %d/%d" % [c.size(), host.jail_system.prisoners(jail_owner).size()]
	var from: Vector3 = (c[-1] as Hero).global_position if not c.is_empty() else host.layout.marker(jail_owner)
	var best := -1.0
	for a in host.allies_of(me):
		if a.is_free():
			var d := RB.flat_dist(a.global_position, from)
			if best < 0.0 or d < best:
				best = d
	dist_text = "Kakampi: %d m" % roundi(best) if best >= 0.0 else "Kakampi: --"
	prompt.text = prompt_text
	chain_label.text = chain_text
	dist_label.text = dist_text
