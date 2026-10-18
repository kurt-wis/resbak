class_name JailSystem
extends RefCounted

## Jail, human chain and rescue (docs/RESBAK.md § 2 "Jail and chain", "Rescue and EP"; the
## automatic chain is a v0.1.1 change logged in docs/status.md and docs/decisions.md).
## Tagged heroes freeze 0.8 s, then join the tagger's jail chain automatically: the first
## prisoner holds the jail post, the second holds the first, and so on. Only the LAST prisoner
## caught (the tip) steers, slowly; every other link only moves when the rope pulls it, one
## after the other, so the chain drags behind the tip. Links never sit more than chain_link
## from their neighbour (the post counts as link 0), so the tip reaches at most
## chain_link x prisoners from the post.
## v0.2 jail line (docs/status.md): the post is not fixed. It slides along the map's jail line
## (MapLayout.lines), dragged by the post holder (the first prisoner, who steers too) at
## chain_post_speed, so a chain can walk up and down the map's end and pick where it reaches
## out. Links stay inside the play bounds.
## A free teammate touching the tip (centres <= rescue_touch) frees the whole chain with
## Escape Protection (4 s, 5 s via Inday) and capture lockout 4 s. Free players are kept
## jail_post_barrier away from the post so nobody can stand on it.

var host: MatchHost
var chains := [[], []] ## per jail owner team: Array[Hero], post holder first, tip last
var anchor_s := [0.0, 0.0] ## per jail owner team: where the post is, metres along the jail line

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

func is_post_holder(h: Hero) -> bool:
	var c: Array = chains[RB.other_team(h.team)]
	return not c.is_empty() and c[0] == h

## The tip reaches out; the post holder walks the post along the line.
func can_steer(h: Hero) -> bool:
	return h.state == Hero.State.CHAINED and (is_tip(h) or is_post_holder(h))

func post(owner_team: int) -> Vector3:
	return host.layout.line_point(owner_team, anchor_s[owner_team])

## Into the field from the post (the line's normal where the post stands).
func out_dir(owner_team: int) -> Vector3:
	return host.layout.line_normal(owner_team, anchor_s[owner_team])

## Where the first prisoner stands: just out from the post, toward the prisoners' home.
func post_spot(owner_team: int) -> Vector3:
	return post(owner_team) + out_dir(owner_team) * host.tuning.post_hold_offset

## The previous link of chain position `idx` (the post for the first prisoner).
func link_before(owner_team: int, idx: int) -> Vector3:
	var c: Array = chains[owner_team]
	if idx <= 0:
		return post(owner_team)
	return (c[idx - 1] as Hero).global_position

## Where a rescuer must touch for this jail's chain (the tip), or Vector3.INF if empty.
func rescue_point(owner_team: int) -> Vector3:
	var c: Array = chains[owner_team]
	if c.is_empty():
		return Vector3.INF
	return (c[-1] as Hero).global_position

func rescue_radius(_owner_team: int) -> float:
	return host.tuning.rescue_touch

## The farthest the tip of a chain of `n` can be from the post.
func reach(n: int) -> float:
	return host.tuning.chain_link * mini(n, host.tuning.chain_max)

# ---- step 2: prisoners have no buttons --------------------------------------------------
## The chain forms by itself; Interact does nothing in jail (kept for the call in MatchHost).
func handle_interact(_h: Hero, _f: InputFrame) -> void:
	pass

# ---- step 3: freeze -> chain, rope ------------------------------------------------------
func after_move() -> void:
	for h in host.heroes:
		if h.state == Hero.State.TAGGED:
			h.tagged_ticks -= 1
			if h.tagged_ticks <= 0:
				var owner := h.tagged_by.team if h.tagged_by else RB.other_team(h.team)
				_join(owner, h)
	for owner in range(2):
		_pull(owner)

## A prisoner arrives: it holds the post if the chain is empty, else the current tip's free
## hand, standing one link further out. It becomes the new tip.
func _join(owner: int, h: Hero) -> void:
	var c: Array = chains[owner]
	var at := post_spot(owner)
	if not c.is_empty():
		var tip: Hero = c[-1]
		var from := link_before(owner, c.size() - 1)
		var dir := RB.flat(tip.global_position - from)
		if dir.length() < 0.05:
			dir = out_dir(owner)
		at = tip.global_position + dir.normalized() * host.tuning.chain_link * 0.8
	at = _in_field(at)
	h.on_jailed(at)
	c.append(h)
	h.set_state(Hero.State.CHAINED)
	host.emit_event("jailed", {"hero": h, "jail": owner})
	host.emit_event("chain_join", {"hero": h, "size": c.size()})

## The rope. The tip has already moved (Hero.tick_move, slow, walls block). Walk from the tip
## back toward the post: a link that is pulled past the slack length steps toward its outer
## neighbour at chain_follow_speed (never faster: that is the drag). Then walk from the post
## out: nobody may be more than chain_link from the link before it (this is what holds the
## tip back while the links behind are still catching up). Everything stays in the yard.
func _pull(owner: int) -> void:
	var c: Array = chains[owner]
	if c.is_empty():
		return
	var t := host.tuning
	var dt := 1.0 / RB.TICK_RATE
	var step := t.chain_follow_speed * dt
	var link := t.chain_link
	var before := {} # hero -> position at the start of this pass (for presentation velocity)
	for p in c:
		before[p] = (p as Hero).global_position
	# 0. The post holder drags the post along the line toward where it stands.
	var holder: Hero = c[0]
	var want_s := host.layout.line_project(owner, holder.global_position)
	var ds := want_s - float(anchor_s[owner])
	var post_step := t.chain_post_speed * dt
	anchor_s[owner] = float(anchor_s[owner]) + clampf(ds, -post_step, post_step)
	# 1. Pulled links follow the tip, outermost first, one after the other.
	for k in range(c.size() - 2, -1, -1):
		var me: Hero = c[k]
		if k == 0 and me.wish_dir != Vector3.ZERO:
			continue # a steering post holder walks the post; the rope doesn't pull it back
		var outer: Vector3 = (c[k + 1] as Hero).global_position
		var inner := link_before(owner, k)
		var to_outer := RB.flat(outer - me.global_position)
		if to_outer.length() <= link * t.chain_slack:
			continue
		# Best spot: on the line toward the outer link, one link from it, but still within one
		# link of the inner neighbour (the post for the first prisoner).
		var want := outer - to_outer.normalized() * link * t.chain_slack
		want = _clamp_to(want, inner, _limit(c, k))
		var move := RB.flat(want - me.global_position)
		if move.length() > step:
			move = move.normalized() * step
		me.global_position += move
	# 2. Hard limits from the post outward.
	for k in range(c.size()):
		var me: Hero = c[k]
		var inner := link_before(owner, k)
		var p := _clamp_to(me.global_position, inner, _limit(c, k))
		p = _in_field(p)
		me.global_position = Vector3(p.x, me.global_position.y, p.z)
	# Presentation: links that were dragged walk; the tip keeps its own velocity.
	for k in range(c.size()):
		var me: Hero = c[k]
		var moved := RB.flat(me.global_position - before[me])
		if k < c.size() - 1:
			me.velocity = Vector3(moved.x / dt, me.velocity.y, moved.z / dt) if moved.length() > 0.0005 else Vector3(0, me.velocity.y, 0)
		# Everyone looks out along the chain, toward the tip and the rescuers beyond it.
		var out := RB.flat(me.global_position - link_before(owner, k))
		if k == c.size() - 1:
			var v := RB.flat(me.velocity)
			out = v if v.length() > 0.3 else out
		if out.length() > 0.05:
			me.facing = out.normalized()

## How far link k may be from the link before it. The post holder keeps a hand on the post
## (short), unless it is alone: then it is the tip and leans out a full link.
func _limit(c: Array, k: int) -> float:
	var t := host.tuning
	if k == 0 and c.size() > 1:
		return t.post_hold_offset + 0.35
	return t.chain_link

func _clamp_to(p: Vector3, centre: Vector3, radius: float) -> Vector3:
	var d := RB.flat(p - centre)
	if d.length() <= radius:
		return p
	var q := centre + d.normalized() * radius
	return Vector3(q.x, p.y, q.z)

func _in_field(p: Vector3) -> Vector3:
	var r := host.layout.bounds.grow(-host.tuning.body_radius)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return p
	return Vector3(clampf(p.x, r.position.x, r.end.x), p.y, clampf(p.z, r.position.y, r.end.y))

# ---- step 4: jail barrier ---------------------------------------------------------------
## Free players can't stand on the post (prisoners are ghosts and pass).
func enforce_barriers() -> void:
	var r := host.tuning.jail_post_barrier + host.tuning.body_radius
	for h in host.heroes:
		if h.state != Hero.State.FREE:
			continue
		for owner in range(2):
			var p := post(owner)
			var d := RB.flat(h.global_position - p)
			if d.length() < r:
				var dir := d.normalized() if d.length() > 0.001 else out_dir(owner)
				h.global_position = Vector3(p.x + dir.x * r, h.global_position.y, p.z + dir.z * r)

## Nearest spot outside the post barrier (rescued prisoners standing on the post move here).
func outside_post(owner: int, at: Vector3) -> Vector3:
	var r := host.tuning.jail_post_barrier + host.tuning.body_radius + 0.05
	var p := post(owner)
	var d := RB.flat(at - p)
	if d.length() >= r:
		return at
	var dir := d.normalized() if d.length() > 0.001 else out_dir(owner)
	return Vector3(p.x + dir.x * r, at.y, p.z + dir.z * r)

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
					var at: Vector3 = s.rescue_touch_point()
					if at == Vector3.INF or absf(at.y - point.y) > host.tuning.height_gap + 1.0:
						continue
					if RB.flat_dist(at, point) <= radius + s.rescue_touch_radius() + 0.001:
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
			h.global_position = outside_post(owner, h.global_position)
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
	for owner in range(2):
		anchor_s[owner] = host.layout.line_length(owner) * 0.5
