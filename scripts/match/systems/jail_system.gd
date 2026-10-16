class_name JailSystem
extends RefCounted

## Jail, human chain and rescue (docs/RESBAK.md § 2 "Jail and chain", "Rescue and EP").
## Tagged heroes freeze 0.8 s, then go to a random free spot in the tagger's jail (own side;
## Jail_Dilaw holds Lila). The jail barrier blocks every free player; only chained prisoners
## cross it. Interact near the marker makes the anchor; near the anchor or tip joins (moved to
## the old tip, becomes the tip). Only the tip is steered, within 1.5 m of the hand point per
## link after the anchor; the other links sit evenly on the hand point -> tip line. A free
## teammate touching the tip (centres <= 0.8 m; lone anchor: <= 0.4 m from the hand point)
## frees the whole chain with Escape Protection (4 s, 5 s via Inday) and capture lockout 4 s.

var host: MatchHost
var chains := [[], []] ## per jail owner team: Array[Hero], anchor first, tip last

func _init(p_host: MatchHost) -> void:
	host = p_host

func chain(owner_team: int) -> Array:
	return chains[owner_team]

func prisoners(owner_team: int) -> Array[Hero]:
	var out: Array[Hero] = []
	for h in host.heroes:
		if h.team != owner_team and (h.state == Hero.State.JAILED or h.state == Hero.State.CHAINED):
			out.append(h)
	return out

func chain_index(h: Hero) -> int:
	return chains[RB.other_team(h.team)].find(h)

func is_tip(h: Hero) -> bool:
	var c: Array = chains[RB.other_team(h.team)]
	return not c.is_empty() and c[-1] == h

func can_steer(h: Hero) -> bool:
	var c: Array = chains[RB.other_team(h.team)]
	return c.size() >= 2 and c[-1] == h

func hand_point(owner_team: int) -> Vector3:
	return host.layout.hand_point(owner_team, host.tuning.hand_point_offset)

## Where a rescuer must touch for this jail's chain (tip, or the hand point for a lone
## anchor), or Vector3.INF if nobody is chained.
func rescue_point(owner_team: int) -> Vector3:
	var c: Array = chains[owner_team]
	if c.is_empty():
		return Vector3.INF
	if c.size() == 1:
		return hand_point(owner_team)
	return (c[-1] as Hero).global_position

func rescue_radius(owner_team: int) -> float:
	return host.tuning.lone_anchor_touch if chains[owner_team].size() == 1 else host.tuning.rescue_touch

# ---- step 2: Interact by prisoners ------------------------------------------------------
func handle_interact(h: Hero, f: InputFrame) -> void:
	if not f.was_pressed(RB.BTN_INTERACT) or not host.round_live():
		return
	var owner := RB.other_team(h.team)
	var c: Array = chains[owner]
	var t := host.tuning
	if h.state == Hero.State.CHAINED:
		_let_go(owner, c.find(h))
		return
	if h.state != Hero.State.JAILED:
		return
	if c.is_empty():
		if RB.flat_dist(h.global_position, host.layout.marker(owner)) <= t.anchor_range:
			c.append(h)
			h.set_state(Hero.State.CHAINED)
			host.emit_event("chain_anchor", {"hero": h})
		return
	if c.size() >= t.chain_max:
		return
	var anchor: Hero = c[0]
	var tip: Hero = c[-1]
	if RB.flat_dist(h.global_position, anchor.global_position) <= t.join_range or RB.flat_dist(h.global_position, tip.global_position) <= t.join_range:
		var old_tip_pos := tip.global_position
		c.append(h)
		h.set_state(Hero.State.CHAINED)
		h.teleport(old_tip_pos)
		_layout_links(owner)
		host.emit_event("chain_join", {"hero": h, "size": c.size()})

## Let go: that prisoner and all beyond it return to random jail spots (anchor = everyone).
func _let_go(owner: int, idx: int) -> void:
	var c: Array = chains[owner]
	if idx < 0:
		return
	var dropped := c.slice(idx)
	chains[owner] = c.slice(0, idx)
	for p in dropped:
		(p as Hero).set_state(Hero.State.JAILED)
		(p as Hero).teleport(_free_spot(owner, p))
	host.emit_event("chain_leave", {"heroes": dropped})

func _free_spot(owner: int, exclude: Hero) -> Vector3:
	var taken: Array = []
	for p in prisoners(owner):
		if p != exclude:
			taken.append(p.global_position)
	return host.layout.random_jail_spot(owner, host.rng, taken, host.tuning.body_radius)

# ---- step 3: freeze -> jail, chain layout ------------------------------------------------
func after_move() -> void:
	for h in host.heroes:
		if h.state == Hero.State.TAGGED:
			h.tagged_ticks -= 1
			if h.tagged_ticks <= 0:
				var owner := h.tagged_by.team if h.tagged_by else RB.other_team(h.team)
				h.on_jailed(_free_spot(owner, h))
				host.emit_event("jailed", {"hero": h, "jail": owner})
	for owner in range(2):
		_layout_links(owner)

## Keep the tip within reach of the hand point and space the middle links on the line.
func _layout_links(owner: int) -> void:
	var c: Array = chains[owner]
	if c.is_empty():
		return
	var hp := hand_point(owner)
	var anchor: Hero = c[0]
	anchor.velocity = Vector3.ZERO
	if c.size() == 1:
		return
	var tip: Hero = c[-1]
	var reach := host.tuning.chain_link * (c.size() - 1)
	var off := RB.flat(tip.global_position - hp)
	if off.length() > reach:
		off = off.normalized() * reach
		tip.global_position = Vector3(hp.x + off.x, tip.global_position.y, hp.z + off.z)
	var n := c.size() - 1
	for k in range(1, n):
		var link: Hero = c[k]
		var p := hp + off * (float(k) / n)
		link.global_position = Vector3(p.x, link.global_position.y, p.z)
		link.velocity = Vector3.ZERO

# ---- step 4: jail barrier ---------------------------------------------------------------
func enforce_barriers() -> void:
	var r := host.tuning.body_radius
	for h in host.heroes:
		match h.state:
			Hero.State.FREE:
				for owner in range(2):
					if host.layout.in_jail(owner, h.global_position, r):
						h.global_position = host.layout.nearest_outside(owner, h.global_position, r)
			Hero.State.JAILED:
				var owner := RB.other_team(h.team)
				var rect := host.layout.jail_rect(owner).grow(-r)
				var p := h.global_position
				h.global_position = Vector3(clampf(p.x, rect.position.x, rect.end.x), p.y, clampf(p.z, rect.position.y, rect.end.y))

# ---- step 6: find rescues ---------------------------------------------------------------
## Returns [{jail: owner_team, rescuer: Hero, by_skill: bool}], one per jail at most.
func find_rescues() -> Array:
	var out: Array = []
	for owner in range(2):
		var c: Array = chains[owner]
		if c.is_empty():
			continue
		var point := rescue_point(owner)
		var radius := rescue_radius(owner)
		var team := RB.other_team(owner) # prisoners' team = rescuers' team
		var best: Hero = null
		var by_skill := false
		for h in host.team_heroes(team):
			if not h.is_free() or absf(h.global_position.y - point.y) > host.tuning.height_gap:
				continue
			if RB.flat_dist(h.global_position, point) <= radius + 0.001:
				if best == null or h.slot < best.slot:
					best = h
		if best == null:
			for h in host.team_heroes(team):
				if not h.is_free():
					continue
				for s in h.skills:
					var reach: float = s.ranged_rescue_reach() if s.active else -1.0
					if reach > 0.0 and RB.flat_dist(h.global_position, point) <= reach and host.los_clear(h.global_position, point):
						if best == null or h.slot < best.slot:
							best = h
							by_skill = true
		if best:
			out.append({"jail": owner, "rescuer": best, "by_skill": by_skill})
	return out

# ---- step 7: apply rescues --------------------------------------------------------------
func apply_rescues(rescues: Array) -> void:
	var t := host.tuning
	for r in rescues:
		var owner: int = r.jail
		var rescuer: Hero = r.rescuer
		var freed: Array = chains[owner].duplicate()
		chains[owner] = []
		var ep := t.escape_protection + (rescuer.passive.extra_rescue_protection() if rescuer.passive else 0.0)
		for p in freed:
			var h := p as Hero
			h.global_position = host.layout.nearest_outside(owner, h.global_position, t.body_radius)
			h.on_freed(rescuer, ep, t.capture_lockout)
		var last_free := true
		for a in host.allies_of(rescuer):
			if a.is_free() and not freed.has(a):
				last_free = false
		host.add_stat(rescuer, "rescues", freed.size())
		host.add_impact(rescuer, 3 * freed.size() + (5 if last_free else 0))
		if last_free:
			host.add_stat(rescuer, "clutch")
		rescuer.notify_rescued_others(freed, r.by_skill)
		host.emit_event("rescue", {"rescuer": rescuer, "freed": freed, "by_skill": r.by_skill})

## Lockdown: every hero of `team` is Tagged, Jailed or Chained at once.
func team_locked_down(team: int) -> bool:
	var any := false
	for h in host.team_heroes(team):
		any = true
		if h.is_free():
			return false
	return any

func jailed_count(team: int) -> int:
	var n := 0
	for h in host.team_heroes(team):
		if h.is_jailed_like():
			n += 1
	return n

func reset_round() -> void:
	chains = [[], []]
