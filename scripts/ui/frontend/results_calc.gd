class_name ResultsCalc
extends RefCounted

## Results maths (docs/RESBAK.md § 6 "Results (steps 1 to 3)"): rows per player, MVP per team
## (top Impact; tie: more rescues, more captures, lower slot) and up to three badges in the
## order Best Resbak, Pader, Pasaway, Kidlat, Nemesis (value >= 1; tie: more Impact, else none).
## Input: Session.last_results = {winner, score, stats {slot: {...}}, lineup, heroes, local_slot}.

const TABS := [
	{"key": "impact", "fil": "Impact", "en": "Impact"},
	{"key": "tags", "fil": "Tags", "en": "Tags"},
	{"key": "rescues", "fil": "Rescues", "en": "Rescues"},
	{"key": "captures", "fil": "Captures", "en": "Captures"},
	{"key": "assists", "fil": "Assists", "en": "Assists"},
	{"key": "saves", "fil": "Saves", "en": "Saves"},
]

const BADGES := [
	{"id": "best_resbak", "fil": "Best Resbak", "en": "Most prisoners freed", "stat": "rescues"},
	{"id": "pader", "fil": "Pader", "en": "Wall: most tags near own pole", "stat": "pader"},
	{"id": "pasaway", "fil": "Pasaway", "en": "Troublemaker: most captures started", "stat": "captures_started"},
	{"id": "kidlat", "fil": "Kidlat", "en": "Lightning: longest chase", "stat": "kidlat"},
	{"id": "nemesis", "fil": "Nemesis", "en": "Rival pair", "stat": ""},
]

static func stat_of(stats: Dictionary, slot: int, key: String) -> float:
	var s: Variant = stats.get(slot, stats.get(str(slot), {}))
	return float((s as Dictionary).get(key, 0)) if s is Dictionary else 0.0

## One row per player: {slot, team, team_slot, name, hero_id, is_bot, stats}.
static func rows(res: Dictionary) -> Array:
	var out: Array = []
	var stats: Dictionary = res.get("stats", {})
	var source: Array = res.get("heroes", [])
	if source.is_empty():
		for e in res.get("lineup", []):
			source.append({"slot": int(e.team) * 5 + int(e.get("team_slot", 0)), "team": e.team, "hero_id": e.hero_id,
				"name": e.get("name", ""), "is_bot": e.get("is_bot", true)})
	for h in source:
		var slot := int(h.slot)
		var st: Dictionary = stats.get(slot, stats.get(str(slot), {}))
		out.append({"slot": slot, "team": int(h.team), "team_slot": slot % 5, "name": String(h.name),
			"hero_id": String(h.hero_id), "is_bot": bool(h.get("is_bot", true)), "stats": st})
	out.sort_custom(func(a, b): return int(a.slot) < int(b.slot))
	return out

## The row with the top Impact in a team; ties: more rescues, more captures, lower slot.
static func mvp_of(team_rows: Array) -> Dictionary:
	var best: Dictionary = {}
	for r in team_rows:
		if best.is_empty() or _beats(r, best):
			best = r
	return best

static func _beats(a: Dictionary, b: Dictionary) -> bool:
	for key in ["impact", "rescues", "captures"]:
		var x := float(a.stats.get(key, 0))
		var y := float(b.stats.get(key, 0))
		if x != y:
			return x > y
	return int(a.slot) < int(b.slot)

static func compute(res: Dictionary) -> Dictionary:
	var all := rows(res)
	var score: Array = res.get("score", [0, 0])
	var winner := int(res.get("winner", -1))
	if winner < 0 and score.size() == 2:
		winner = 0 if int(score[0]) > int(score[1]) else (1 if int(score[1]) > int(score[0]) else -1)
	var local_slot := int(res.get("local_slot", 0))
	var local_team := 0 if local_slot < 5 else 1
	var by_team: Array = [[], []]
	for r in all:
		by_team[r.team].append(r)
	var mvp := {}
	for t in range(2):
		if not by_team[t].is_empty():
			mvp[t] = int(mvp_of(by_team[t]).slot)
	return {"winner": winner, "score": [int(score[0]), int(score[1])], "local_slot": local_slot,
		"local_team": local_team, "local_won": winner == local_team, "rows": all, "mvp": mvp,
		"badges": badges(all), "by_team": by_team}

## Up to three badges, in order. Each {id, fil, en, slot, slot2 (-1 unless Nemesis), value}.
static func badges(all: Array) -> Array:
	var out: Array = []
	for b in BADGES:
		if out.size() >= 3:
			break
		if b.id == "nemesis":
			var n := _nemesis(all)
			if not n.is_empty():
				out.append(n)
			continue
		var best_val := 0.0
		for r in all:
			best_val = maxf(best_val, float(r.stats.get(b.stat, 0)))
		if best_val < (0.001 if b.id == "kidlat" else 1.0):
			continue
		var tied: Array = []
		for r in all:
			if float(r.stats.get(b.stat, 0)) == best_val:
				tied.append(r)
		var winner := _impact_winner(tied)
		if not winner.is_empty():
			out.append({"id": b.id, "fil": b.fil, "en": b.en, "slot": int(winner.slot), "slot2": -1, "value": best_val})
	return out

## Highest Impact among tied rows; a further tie gives no badge.
static func _impact_winner(tied: Array) -> Dictionary:
	if tied.size() == 1:
		return tied[0]
	var top := -1.0
	var holder: Dictionary = {}
	var dup := false
	for r in tied:
		var imp := float(r.stats.get("impact", 0))
		if imp > top:
			top = imp
			holder = r
			dup = false
		elif imp == top:
			dup = true
	return {} if dup else holder

## Enemy pair with mutual tags: total >= 3 and each >= 1; the most tags wins (tie: Impact).
static func _nemesis(all: Array) -> Dictionary:
	var best := {}
	var best_total := 0
	var best_impact := -1.0
	var dup := false
	for a in all:
		if a.team != 0:
			continue
		for b in all:
			if b.team != 1:
				continue
			var ab := int((a.stats.get("tagged_by", {}) as Dictionary).get(int(b.slot), 0))
			var ba := int((b.stats.get("tagged_by", {}) as Dictionary).get(int(a.slot), 0))
			if ab < 1 or ba < 1 or ab + ba < 3:
				continue
			var imp := float(a.stats.get("impact", 0)) + float(b.stats.get("impact", 0))
			if ab + ba > best_total or (ab + ba == best_total and imp > best_impact):
				best_total = ab + ba
				best_impact = imp
				best = {"id": "nemesis", "fil": "Nemesis", "en": "Rival pair", "slot": int(a.slot), "slot2": int(b.slot), "value": float(ab + ba)}
				dup = false
			elif ab + ba == best_total and imp == best_impact:
				dup = true
	return {} if dup else best
