class_name TagSystem
extends RefCounted

## Unahan tagging (docs/RESBAK.md § 2 "Tagging (Unahan: first clean tag wins)").
## One attack edge commits a normal-reach swing. PlayerInput emits it on aim release.
## Selection and direction lock at commitment. At landing the selected body must still overlap.
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

## Hit-test geometry only: edge-to-edge reach and a narrow straight sweep expanded by body radius.
func in_tag_shape(tagger: Hero, lunge: Vector3, target_pos: Vector3, target_radius: float) -> bool:
	var t := host.tuning
	var to := RB.flat(target_pos - tagger.global_position)
	var edge := to.length() - t.body_radius - target_radius
	if edge > (tagger.strike_reach if tagger.strike_reach > 0.0 else tagger.tag_reach()):
		return false
	if to.length() < 0.001:
		return true
	var forward := to.dot(lunge.normalized())
	var lateral := (to - lunge.normalized() * forward).length()
	return forward >= 0.0 and lateral <= t.tag_strip_half_width + target_radius

## Step 2: only a fresh button press starts a swing, even when held across many ticks.
func handle_tag_button(h: Hero, f: InputFrame) -> void:
	if f.was_pressed(RB.BTN_TAG) and h.can_press_tag():
		start_windup(h)

## Shared by the preview and the committed swing; assist never changes after the press.
func aim_direction(h: Hero) -> Vector3:
	if h.frame.tag_aim_dir != Vector2.ZERO:
		return Vector3(h.frame.tag_aim_dir.x, 0, h.frame.tag_aim_dir.y).normalized()
	var lunge := h.aim if h.aim != Vector3.ZERO else h.facing
	return (_assisted(h, lunge) if h.frame.from_gamepad else lunge).normalized()

func start_windup(h: Hero) -> void:
	h.notify_tag_pressed()
	h.strike_reach = h.tag_reach()
	h.lunge_dir = aim_direction(h)
	h.strike_target_slot = h.frame.tag_target_slot
	if h.strike_target_slot < 0:
		var selected := preview_target(h, h.lunge_dir)
		if selected:
			h.strike_target_slot = selected.slot
	h.tag_started_tick = host.tick
	h.windup_end_tick = host.tick + RB.ticks(host.tuning.tag_windup)
	host.emit_event("tag_windup", {"hero": h, "dir": h.lunge_dir})

## Read-only query: same geometry, eligibility, nearest-target and wall checks as landing.
func preview_target(h: Hero, direction: Vector3) -> Hero:
	if h.is_winding_up() or h.windup_end_tick == host.tick or (h.tag_started_tick >= 0 and host.tick == h.tag_started_tick + RB.ticks(host.tuning.tag_windup)):
		if h.strike_target_slot >= 0:
			var selected := host.hero_by_slot(h.strike_target_slot)
			if selected and can_tag(h, selected) and reach_clear(h, selected.global_position) and in_tag_shape(h, direction, selected.global_position, host.tuning.body_radius):
				return selected
			return null
	var best: Hero = null
	var best_d := INF
	for e in host.enemies_of(h):
		if not in_tag_shape(h, direction, e.global_position, host.tuning.body_radius):
			continue
		if not can_tag(h, e) or not reach_clear(h, e.global_position):
			continue
		var d := RB.flat_dist(h.global_position, e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

## Tag assist (gamepad, spec § 9): nearest taggable enemy within 2.4 m and 30 deg of the aim
## turns the lunge toward it by up to 15 deg.
func _assisted(h: Hero, lunge: Vector3) -> Vector3:
	var t := host.tuning
	if not bool(host.settings.get("tag_assist", true)):
		return lunge
	var best: Hero = null
	var best_d := INF
	for e in host.enemies_of(h):
		if not can_tag(h, e) or not reach_clear(h, e.global_position) or host.visibility(h, e) < 0.5 or e.is_warded():
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
		h.strike_reach = 0.0 # clear the committed reach after landing
	# Sabay: valid tags on each other this tick.
	for i in range(results.size()):
		var a: Dictionary = results[i]
		if a.type != "hit":
			continue
		for j in range(i + 1, results.size()):
			var b: Dictionary = results[j]
			if b.type == "hit" and a.target == b.tagger and b.target == a.tagger:
				var a_low := wind_disadvantaged(a.tagger)
				var b_low := wind_disadvantaged(b.tagger)
				if a_low != b_low:
					if a_low:
						a.type = "outprioritized"
					else:
						b.type = "outprioritized"
				else:
					a.type = "sabay"
					b.type = "sabay"
	return results

## Membership is sampled at landing, with no grace period after leaving a lane.
func wind_disadvantaged(h: Hero) -> bool:
	for object in host.objects:
		if object.has_method("disadvantages") and object.disadvantages(h):
			return true
	return false

func _resolve_one(h: Hero) -> Dictionary:
	var lunge := h.lunge_dir
	# LUSOT! perfect slide (and any other evasion) is checked first, against the enemy's own rule.
	for e in host.enemies_of(h):
		if not e.is_free():
			continue
		if h.strike_target_slot >= 0 and e.slot != h.strike_target_slot:
			continue
		for s in e.skills:
			if s.evade_tag(h, lunge):
				return {"type": "evaded", "tagger": h, "evader": e, "stun": s.evade_stun_seconds()}
	var best := preview_target(h, lunge)
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
					host.emit_event("guard_break", {"tagger": tagger, "target": target, "point": contact_point(tagger, target)})
				else:
					target.on_tagged(tagger)
					host.emit_event("tag", {"tagger": tagger, "target": target, "point": contact_point(tagger, target)})
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
				tagger.sabay_fall()
				if r.tagger.slot < r.target.slot:
					host.emit_event("sabay", {"a": r.tagger, "b": r.target})
	return landed

## Impact is on the target body surface, not the reach indicator. Pure host geometry.
func contact_point(tagger: Hero, target: Hero) -> Vector3:
	var from := RB.flat(tagger.global_position - target.global_position).normalized()
	return target.global_position + from * host.tuning.body_radius + Vector3.UP * target.data.model_height * host.tuning.tag_contact_height

## Saved +2: the target was capturing, or was within 5 m of the tip of a chain holding
## its teammates (i.e. about to rescue) (spec § 6 Results, Impact).
func _is_save(target: Hero) -> bool:
	if target.capturing:
		return true
	var tip := host.jail_system.rescue_point(RB.other_team(target.team))
	return tip != Vector3.INF and RB.flat_dist(tip, target.global_position) <= 5.0
