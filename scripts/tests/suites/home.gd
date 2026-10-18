extends RefCounted

## Home diorama (spec § 6 "Home"): the 48 s loop is seamless by construction (every gesture and walk ends
## before the wrap, the jeepney and walkers are off-screen at both ends), the cast and bystanders build,
## the hero picker saves the default character, the old centre-stage breakdance is gone, and the
## version / Master-volume defaults match the build.

const HOME_SCENE := "res://scenes/frontend/home.tscn"

func run(t: TestCtx) -> void:
	_data(t)
	_defaults(t)
	await _diorama(t)
	await _home_and_picker(t)

## The schedule numbers alone (no scene needed): nothing runs past the wrap, nothing overlaps.
func _data(t: TestCtx) -> void:
	var d := HomeDioramaData.new()
	t.check(is_equal_approx(d.loop_length, 48.0), "the Home loop is 48 s")
	var by_hero := {}
	var bad_end := 0
	for g in d.gestures:
		if g.t + g.dur > d.loop_length - 0.05:
			bad_end += 1
		if not by_hero.has(g.hero):
			by_hero[g.hero] = []
		by_hero[g.hero].append(g)
	t.check(bad_end == 0, "every gesture ends before the loop wraps (%d run over)" % bad_end)
	var overlaps := 0
	for hero in by_hero:
		var list: Array = by_hero[hero]
		list.sort_custom(func(a, b): return a.t < b.t)
		for i in range(1, list.size()):
			if list[i].t < list[i - 1].t + list[i - 1].dur:
				overlaps += 1
	t.check(overlaps == 0, "no hero has two gestures at once (%d overlaps)" % overlaps)
	var speech_ok := true
	for s in d.speech:
		speech_ok = speech_ok and s.t0 >= 0.0 and s.t1 <= d.loop_length and s.t0 < s.t1
	t.check(speech_ok, "speech windows sit inside the loop")
	var walks_ok := true
	for who in d.bystanders:
		var e: Dictionary = d.bystanders[who]
		if e.has("from"):
			var dur: float = (e.to - e.from).length() / float(e.speed)
			walks_ok = walks_ok and e.t0 >= 0.0 and e.t0 + dur <= d.loop_length
	t.check(walks_ok, "every bystander finishes its walk before the wrap")
	var jeep_dur: float = (d.jeep_to - d.jeep_from).length() / d.jeep_speed
	t.check(d.jeep_t0 + jeep_dur <= d.loop_length, "the jeepney leaves before the wrap")
	t.ok("Home loop schedule: 48 s, gestures/walks/jeepney all end before the wrap")

func _defaults(t: TestCtx) -> void:
	t.check(FE.VERSION == "0.1.2 (Demo build)", "FE.VERSION is 0.1.2 (Demo build) (got %s)" % FE.VERSION)
	t.check(int(Save.SETTINGS_DEFAULTS.audio.master) == 50, "Master volume defaults to 50 (spec § 10)")
	for f in ["res://assets/fonts/LuckiestGuy-Regular.ttf", "res://assets/ui/home/cardboard.png", "res://assets/ui/home/tape.png",
			"res://assets/audio/home/home_music.wav", "res://assets/props/home/mango_tree.glb"]:
		t.check(FileAccess.file_exists(f) or ResourceLoader.exists(f), "%s exists" % f)
	t.check(UiFonts.home_display() != null, "the Home font resolves")

## Build the real diorama (silent, manually stepped) and test the loop edges.
func _diorama(t: TestCtx) -> void:
	var d := HomeDiorama.new()
	d.manual = true
	t.tree.root.add_child(d)
	await t.frames(2)
	t.check(d.actors.size() == 5, "the diorama seats five heroes (got %d)" % d.actors.size())
	var walkers_n := 0
	for who in d.walkers:
		walkers_n += 1
	t.check(walkers_n == 4, "four bystanders are built (got %d)" % walkers_n)
	t.check(d.jeep != null, "the jeepney is built")
	for g in ["res://shaders/diorama_sky.gdshader", "res://shaders/diorama_dof.gdshader", "res://assets/props/home/graffiti_wall.glb"]:
		t.check(ResourceLoader.exists(g), "%s exists" % g)
	t.check(is_equal_approx(d.timeline.get_animation("loop").length, 48.0), "the Timeline animation is 48 s")
	for edge in [0.0, 47.9]:
		d.seek_to(edge)
		t.check(not d.jeep.visible, "the jeepney is off the road at %.1f s" % edge)
		for who in d.walkers:
			if d.data.bystanders[who].has("from"):
				t.check(not (d.walkers[who] as Node3D).visible, "%s is out of sight at %.1f s" % [who, edge])
	t.check(d._sky_mat != null and d._sky_mat.shader != null, "the diorama has its own sky shader")
	var blur := d.camera.get_node_or_null("DepthBlur") as MeshInstance3D
	t.check(blur != null and blur.material_override is ShaderMaterial, "the depth-blur quad rides the camera")
	t.check(d.data.backdrop.size() >= 8, "the skyline backdrop has its facades (%d)" % d.data.backdrop.size())
	d.seek_to(d.data.jeep_t0 + 2.0)
	t.check(d.jeep.visible and d.jeep_progress() > 0.0 and d.jeep_progress() < 1.0, "the jeepney is on the road mid-pass")
	var fired := [0]
	d.turn_started.connect(func(_h, _l): fired[0] += 1)
	d.seek_to(0.0)
	for _i in range(int(48.0 / 0.05)):
		d.step(0.05)
	t.check(fired[0] >= 3, "heroes take their turns to talk over a full loop (%d turns)" % fired[0])
	t.check(d.time < 1.0 or d.time > 47.0, "a full loop returns to the start")
	d.queue_free()
	await t.frames(1)
	t.ok("Home diorama builds, loops and hides its passers-by at the seam")

## Home without the 3D backdrop (headless), then the picker flow end to end.
func _home_and_picker(t: TestCtx) -> void:
	var save := t.tree.root.get_node_or_null("Save")
	var before: String = save.profile.get("home_hero", "jm") if save else "jm"
	var home = (load(HOME_SCENE) as PackedScene).instantiate()
	home.navigate = false
	t.tree.root.add_child(home)
	await t.frames(3)
	for n in ["PlayerCard", "PlayerFace", "PlayerName", "Stats", "PlayerStats", "Laro"]:
		t.check(home.find_child(n, true, false) != null, "Home has %s" % n)
	t.check(home.find_child("BenchPrev", true, false) == null and home.find_child("BenchNext", true, false) == null,
		"the old centre-stage hero arrows are gone")
	t.check(home.find_child("HeroPreview", true, false) == null, "no breakdance preview on the Home screen itself")
	var picker: HeroPicker = home.open_picker()
	await t.frames(3)
	t.check(picker != null and picker.is_inside_tree(), "the player card opens the hero picker")
	t.check(home.open_picker() == picker, "opening the picker twice gives the same one")
	t.check(picker.find_child("PickerPreview", true, false) != null, "the picker holds the breakdance preview")
	t.check(picker.badges.size() == HeroData.ORDER.size(), "one portrait per hero")
	var got := []
	picker.chosen.connect(func(id): got.append(id))
	var pick_id := "nene" if home.bench_id != "nene" else "inday"
	picker.pick(pick_id)
	t.check(picker.selected == pick_id, "pressing a portrait selects it")
	t.check(home.bench_id != pick_id, "browsing the picker doesn't change the default until Piliin")
	picker.confirm()
	await t.frames(3)
	t.check(got == [pick_id], "Piliin emits chosen with the selection")
	t.check(home.bench_id == pick_id, "the default character is now %s" % pick_id)
	if save:
		t.check(save.profile.get("home_hero", "") == pick_id, "the default character is saved to the profile")
	t.check(home.picker == null, "the picker closes after Piliin")
	# Cancel keeps the old choice.
	var p2: HeroPicker = home.open_picker()
	await t.frames(2)
	var closed := [false]
	p2.closed.connect(func(): closed[0] = true)
	p2.preview_hero("tutoy" if pick_id != "tutoy" else "jm")
	p2.close()
	await t.frames(2)
	t.check(closed[0] and home.bench_id == pick_id, "Bumalik closes the picker and keeps the old default")
	home.queue_free()
	if save:
		save.profile["home_hero"] = before
	await t.frames(1)
	t.ok("hero picker: open, browse, Piliin saves, Bumalik keeps")
