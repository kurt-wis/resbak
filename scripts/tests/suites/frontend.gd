extends RefCounted

## Front-end loop: every screen instantiates, snake draft order and rules, name rules,
## results maths (MVP, badges) and settings persisting through Save.

const SCREENS := ["boot", "title", "first_setup", "home", "play_menu", "roulette", "draft", "results", "settings"]

func run(t: TestCtx) -> void:
	await _screens(t)
	_draft(t)
	_names(t)
	_results(t)
	await _settings(t)

func _screens(t: TestCtx) -> void:
	var session := t.tree.root.get_node_or_null("Session")
	if session:
		session.last_results = _fake_results()
	for s in SCREENS:
		var path := "res://scenes/frontend/%s.tscn" % s
		var packed := load(path) as PackedScene
		if not t.check(packed != null, "%s.tscn loads" % s):
			continue
		var inst := packed.instantiate() as FrontScreen
		if not t.check(inst != null, "%s is a FrontScreen" % s):
			continue
		inst.navigate = false
		t.tree.root.add_child(inst)
		await t.frames(3)
		t.check(inst.content != null and inst.content.get_child_count() > 0, "%s builds its content" % s)
		inst.queue_free()
		await t.frames(1)
	t.ok("all %d front-end screens build" % SCREENS.size())

func _draft(t: TestCtx) -> void:
	var d := DraftLogic.new(42)
	var order: Array = []
	while not d.is_done():
		order.append([d.team_now(), d.slot_now()])
		d.auto_pick() # picks for the current turn
	t.check(str(order) == str(DraftLogic.ORDER), "snake order A1 B1 B2 A2 A3 B3 B4 A4 A5 B5 (got %s)" % str(order))
	for team in range(2):
		var ids: Array = d.picks[team]
		var uniq := {}
		for i in ids:
			uniq[i] = true
		t.check(ids.size() == 5 and uniq.size() == 5, "team %d has five different heroes" % team)
	var lu := d.lineup("Tester")
	t.check(lu.size() == 10 and not lu[0].is_bot and lu[0].team == 0 and lu[0].team_slot == 0, "the player is Dilaw slot 1, everyone else a bot")
	var d2 := DraftLogic.new(1)
	var first := d2.auto_pick()
	d2.pick(first)
	t.check(not d2.can_pick("") , "an empty pick is refused")
	t.ok("snake draft order, no duplicates within a team, lineup shape")

func _names(t: TestCtx) -> void:
	t.check(not NameRules.validate("ab").ok, "names under 3 characters are refused")
	t.check(NameRules.validate("Batang Ñiño").ok, "letters incl. Ñ ñ and spaces are allowed")
	t.check(not NameRules.validate("x".repeat(17)).ok, "names over 16 characters are refused")
	t.check(NameRules.DICE_NAMES.size() >= 20, "at least 20 dice names")

func _fake_results() -> Dictionary:
	var heroes: Array = []
	var stats := {}
	for slot in range(10):
		var team := 0 if slot < 5 else 1
		heroes.append({"slot": slot, "team": team, "hero_id": HeroData.ORDER[slot % 5], "name": "P%d" % slot, "is_bot": slot != 0})
		stats[slot] = {"impact": slot % 5, "tags": 1, "rescues": 0, "captures": 0, "assists": 0, "saves": 0, "pader": 0, "captures_started": 0, "kidlat": 0.0, "tagged_by": {}}
	stats[2].impact = 12
	stats[2].rescues = 3
	stats[7].impact = 9
	return {"winner": 0, "score": [3, 1], "stats": stats, "heroes": heroes, "local_slot": 0}

func _results(t: TestCtx) -> void:
	var r := ResultsCalc.compute(_fake_results())
	t.check(r.local_won and r.winner == 0, "Dilaw won and the local player is on Dilaw")
	t.check(int(r.mvp[0]) == 2 and int(r.mvp[1]) == 7, "MVP per team is the top Impact (got %s)" % str(r.mvp))
	t.check(r.badges.size() >= 1 and String(r.badges[0].id) == "best_resbak" and int(r.badges[0].slot) == 2, "Best Resbak goes to the most prisoners freed")
	t.ok("results: MVPs and badges")

func _settings(t: TestCtx) -> void:
	var save := t.tree.root.get_node_or_null("Save")
	if not t.check(save != null, "Save autoload present"):
		return
	var before = save.get_setting("audio", "music")
	save.set_setting("audio", "music", 33)
	save.load_settings()
	t.check(int(save.get_setting("audio", "music")) == 33, "a setting survives a reload of settings.cfg")
	save.set_setting("audio", "music", before)
	t.ok("settings persist through Save")
