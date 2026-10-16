class_name TagSystem
extends RefCounted

## Unahan tagging (docs/RESBAK.md § 2 "Tagging (Unahan: first clean tag wins)").
## v0.2 charged hampas: pressing Tag starts a charge (EP ends); holding fills it over
## tag_charge_time (the hero moves slower); releasing starts the wind-up (tag_windup, 18 ticks)
## with up to +60 % reach. A tap swings at once with the normal reach. On the landing tick
## (step 5) the hit test picks the nearest taggable enemy within the swing's reach (edge to
## edge) and 45 deg of the lunge.
## Results are stored and applied in step 7 together with rescues. Sabay: two enemies whose
## valid tags land on each other the same tick both stumble and nobody is jailed.

var host: MatchHost

func _init(p_host: MatchHost) -> void:
	host = p_host

## The sole tag rule: both Free, different teams, target not under EP, height gap <= 1 m.
func can_tag(tagger: Hero, target: Hero) -> bool:
	if tagger == null or target == null or tagger == target:
		return false
	if tagger.team == target.team:
		return false
	if not tagger.is_free() or not target.is_free():
		return false
	if target.has_ep() or target.is_immune():
		return false
	return absf(tagger.global_position.y - target.global_position.y) <= host.tuning.height_gap

## A tag can't pass through walls: TALBOG! earth walls and the map's solid walls (the centre
## net included) block it. Small props (chairs, crates) don't: you can reach over them.
func reach_clear(tagger: Hero, target_pos: Vector3) -> bool:
	return host.los_clear(tagger.global_position, target_pos, RB.L_WORLD | RB.L_SKILL_WALL)

## Hit-test geometry only (reach edge to edge + arc), no state rules.
func in_tag_shape(tagger: Hero, lunge: Vector3, target_pos: Vector3, target_radius: float) -> bool:
	var t := host.tuning
	var to := RB.flat(target_pos - tagger.global_position)
	var edge := to.length() - t.body_radius - target_radius
	if edge > (tagger.strike_reach if tagger.strike_reach > 0.0 else tagger.tag_reach()):
		return false
	if to.length() < 0.001:
		return true
	return rad_to_deg(lunge.angle_to(to.normalized())) <= t.tag_arc_deg

## Step 2: the Tag button. Press = start charging (ends EP and see-through); held = keep
## charging; released (or never held) = swing. Rules that stop a charge (stun, stumble, being
## tagged, round end) clear charge_ticks on the hero.
func handle_tag_button(h: Hero, f: InputFrame) -> void:
	if h.is_charging():
		if not h.round_live() or h.is_disabled() or h.capturing:
			h.charge_ticks = -1
		elif f.is_held(RB.BTN_TAG):
			h.charge_ticks = mini(h.charge_ticks + 1, RB.ticks(host.tuning.tag_charge_time))
		else:
			start_windup(h, false)
		return
	if f.was_pressed(RB.BTN_TAG) and h.can_press_tag():
		h.notify_tag_pressed()
		h.charge_ticks = 0
		host.emit_event("tag_charge", {"hero": h})
		if not f.is_held(RB.BTN_TAG):
			start_windup(h, false)

## Swing: aims the lunge, locks in the charged reach, lands tag_windup later.
func start_windup(h: Hero, notify := true) -> void:
	if notify:
		h.notify_tag_pressed()
	var charge := h.charge_fraction()
	h.strike_reach = h.charged_reach()
	h.charge_ticks = -1
	var lunge := h.aim if h.aim != Vector3.ZERO else h.facing
	if h.frame.from_gamepad:
		lunge = _assisted(h, lunge)
	h.lunge_dir = lunge.normalized()
	h.windup_end_tick = host.tick + RB.ticks(host.tuning.tag_windup)
	host.emit_event("tag_windup", {"hero": h, "dir": h.lunge_dir, "charge": charge})

## Tag assist (gamepad, spec § 9): nearest taggable enemy within 2.4 m and 30 deg of the aim
## turns the lunge toward it by up to 15 deg.
func _assisted(h: Hero, lunge: Vector3) -> Vector3:
	var t := host.tuning
	if not bool(host.settings.get("tag_assist", true)):
		return lunge
	var best: Hero = null
	var best_d := INF
	for e in host.enemies_of(h):
		if not can_tag(h, e) or not reach_clear(h, e.global_position):
			continue
		var to := RB.flat(e.global_position - h.global_position)
		var d := to.length()
		if d > t.tag_assist_range or d < 0.001:
			continue
		if rad_to_deg(lunge.angle_to(to.normalized())) > t.tag_assist_angle_deg:
			continue
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return lunge
	var want := RB.flat(best.global_position - h.global_position).normalized()
	var ang := lunge.signed_angle_to(want, Vector3.UP)
	var limit := deg_to_rad(t.tag_assist_turn_deg)
	return lunge.rotated(Vector3.UP, clampf(ang, -limit, limit)).normalized()

## Step 5: resolve every wind-up that ends this tick. Returns result dictionaries:
## {type: "hit"|"fail"|"evaded"|"sabay", tagger, target?, decoys?, evader?, stun?}
func resolve() -> Array:
	var results: Array = []
	for h in host.heroes:
		if h.windup_end_tick != host.tick:
			continue
		h.windup_end_tick = -1
		if h.is_free():
			results.append(_resolve_one(h))
		h.strike_reach = 0.0 # the charged reach lasts one swing only
	# Sabay: valid tags on each other this tick.
	for i in range(results.size()):
		var a: Dictionary = results[i]
		if a.type != "hit":
			continue
		for j in range(i + 1, results.size()):
			var b: Dictionary = results[j]
			if b.type == "hit" and a.target == b.tagger and b.target == a.tagger:
				a.type = "sabay"
				b.type = "sabay"
	return results

func _resolve_one(h: Hero) -> Dictionary:
	var lunge := h.lunge_dir
	# LUSOT! perfect slide (and any other evasion) is checked first, against the enemy's own rule.
	for e in host.enemies_of(h):
		if not e.is_free():
			continue
		for s in e.skills:
			if s.evade_tag(h, lunge):
				return {"type": "evaded", "tagger": h, "evader": e, "stun": s.evade_stun_seconds()}
	var best: Hero = null
	var best_d := INF
	for e in host.enemies_of(h):
		if not in_tag_shape(h, lunge, e.global_position, host.tuning.body_radius):
			continue
		if not can_tag(h, e) or not reach_clear(h, e.global_position):
			continue
		var d := RB.flat_dist(h.global_position, e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best:
		return {"type": "hit", "tagger": h, "target": best}
	var decoys: Array = []
	for o in host.objects:
		if o.is_tag_decoy and o.team != h.team and not o.expired and in_tag_shape(h, lunge, o.global_position, o.decoy_radius) and reach_clear(h, o.global_position):
			decoys.append(o)
	return {"type": "fail", "tagger": h, "decoys": decoys}

## A target skill that cancels the tag outright (BAWAL!): no tag, no stats, no stumble.
func _skill_absorbs(target: Hero, tagger: Hero) -> bool:
	for s in target.skills:
		if s.absorb_tag(tagger):
			return true
	return false

## Step 7: apply. Returns the successful tags (guard breaks included) for the round flow.
func apply(results: Array) -> Array:
	var landed: Array = []
	for r in results:
		var tagger: Hero = r.tagger
		match r.type:
			"hit":
				var target: Hero = r.target
				if _skill_absorbs(target, tagger):
					continue
				var saved := _is_save(target)
				if target.passive and target.passive.absorb_tag(tagger):
					host.emit_event("guard_break", {"tagger": tagger, "target": target})
				else:
					target.on_tagged(tagger)
					host.emit_event("tag", {"tagger": tagger, "target": target})
				host.add_stat(tagger, "tags")
				host.add_impact(tagger, 2 + (2 if saved else 0))
				if saved:
					host.add_stat(tagger, "saves")
				if RB.flat_dist(tagger.global_position, host.base_system.pole_pos(tagger.team)) <= 10.0:
					host.add_stat(tagger, "pader")
				var tb: Dictionary = host.stats[tagger.slot].tagged_by
				tb[target.slot] = int(tb.get(target.slot, 0)) + 1
				landed.append({"tagger": tagger, "target": target})
			"fail":
				tagger.stumble(host.tuning.failed_tag_stumble)
				for d in r.decoys:
					(d as SkillObject).on_decoy_tagged(tagger)
				host.emit_event("tag_failed", {"tagger": tagger, "decoy": not r.decoys.is_empty()})
			"evaded":
				tagger.stun(r.stun, true)
				host.emit_event("perfect_slide", {"tagger": tagger, "evader": r.evader})
			"sabay":
				tagger.stumble(host.tuning.failed_tag_stumble)
				if r.tagger.slot < r.target.slot:
					host.emit_event("sabay", {"a": r.tagger, "b": r.target})
	return landed

## Saved +2: the target was capturing, or was within 5 m of the tip of a chain holding
## its teammates (i.e. about to rescue) (spec § 6 Results, Impact).
func _is_save(target: Hero) -> bool:
	if target.capturing:
		return true
	var tip := host.jail_system.rescue_point(RB.other_team(target.team))
	return tip != Vector3.INF and RB.flat_dist(tip, target.global_position) <= 5.0
