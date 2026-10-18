extends RefCounted

## Home diorama (spec § 6 "Home"): the 48 s loop is seamless by construction (every gesture and walk ends
## before the wrap, the background tricycle and the walkers are off-screen at both ends), the cast and
## bystanders build, every clip the schedule names exists on its hero, the seated cast is fitted to its
## stool, the hero picker saves the default character, and the version / Master-volume defaults match.

const HOME_SCENE := "res://scenes/frontend/home.tscn"

## A scheduled gesture lasts as long as its clip (the clips are built to ease in from and out to the
## base idle, so the clip's own end is where the hero is back at rest). A `dur` well short of the clip
## cuts it mid-motion and drags the hands across the body in the fade-out; a `dur` well past it just
## wastes schedule. Seconds.
const GESTURE_DUR_TOL := 0.15
## Hand-motion ceilings over a full loop (HomeMotion samples the hands and first finger bones at
## 60 Hz). Measured after the 2026-10-19 pass (renders/qc/home_motion.json) plus headroom; the
## pre-fix build peaked at 12 m/s and 12.2 m/s per frame (a lost end cue, then a snap to the next gesture).
const MAX_HAND_SPEED := 8.0 ## m/s (measured 7.0: Nathan's cheer swings fast on purpose)
const MAX_HAND_DV := 3.0 ## m/s (measured 2.5) change in one 1/60 s step

func run(t: TestCtx) -> void:
	_data(t)
	_clips(t)
	_defaults(t)
	await _diorama(t)
	await _home_and_picker(t)

## Every clip the diorama asks for must exist on the hero it asks it of: each cast member's base loop
## and every scheduled gesture. A renamed or missing Menu_* clip would otherwise only show up as a
## T-posing hero in the backdrop (the reference-crop pass added six new ones).
func _clips(t: TestCtx) -> void:
	var d := HomeDioramaData.new()
	var wanted := {}
	for hid in d.cast:
		wanted[hid] = [String(d.cast[hid].get("base", ""))]
	for g in d.gestures:
		var hid := String(g.hero)
		if not wanted.has(hid):
			wanted[hid] = []
		if not (String(g.clip) in wanted[hid]):
			wanted[hid].append(String(g.clip))
	var wanted_dur := {}
	for g in d.gestures:
		wanted_dur[String(g.hero) + "/" + String(g.clip)] = float(g.dur)
	for hid in wanted:
		var hd := HeroData.load_hero(hid)
		if not t.check(hd != null, "%s hero data loads for the diorama cast" % hid):
			continue
		var packed := load(hd.glb) as PackedScene
		if not t.check(packed != null, "%s GLB loads for the diorama cast" % hid):
			continue
		var node := packed.instantiate()
		var ap := node.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
		for clip in wanted[hid]:
			if clip == "":
				continue
			if not t.check(ap != null and ap.has_animation(clip),
					"%s has the clip %s the Home diorama plays" % [hid, clip]):
				continue
			t.check(ap.get_animation(clip).get_track_count() >= 60,
				"%s clip %s animates the full skeleton (>= 60 tracks)" % [hid, clip])
			var key: String = hid + "/" + clip
			if wanted_dur.has(key):
				var clip_len := ap.get_animation(clip).length
				t.check(absf(float(wanted_dur[key]) - clip_len) <= GESTURE_DUR_TOL,
					"%s gesture %s lasts its clip (dur %.2f s, clip %.2f s)" % [hid, clip, wanted_dur[key], clip_len])
		node.free()

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
	var pass_dur: float = (d.pass_to - d.pass_from).length() / d.pass_speed
	t.check(d.pass_t0 + pass_dur <= d.loop_length, "the background tricycle finishes its pass before the wrap")
	t.check(d.seat_pad > 0.0, "the seat pad is a data value (%.3f m)" % d.seat_pad)
	var seats_ok := true
	for hero in d.cast:
		if String(d.cast[hero].get("stool", "")) != "":
			seats_ok = seats_ok and ResourceLoader.exists("res://assets/props/home/%s.tscn" % d.cast[hero].stool)
	t.check(seats_ok, "every seated hero names a stool prop that exists")
	t.ok("Home loop schedule: 48 s, gestures/walks/tricycle all end before the wrap")

func _defaults(t: TestCtx) -> void:
	t.check(FE.VERSION == "0.1.2 (Demo build)", "FE.VERSION is 0.1.2 (Demo build) (got %s)" % FE.VERSION)
	t.check(int(Save.SETTINGS_DEFAULTS.audio.master) == 50, "Master volume defaults to 50 (spec § 10)")
	# The reference-built props: store, crate stack, stool, banana clump, house, pole, both tricycles
	# and the counter the store stands on, plus the painted street the ground is textured with.
	var props := ["store", "crate_stack", "plastic_stool", "banana_plant", "house_left", "power_pole",
			"tricycle_blue", "tricycle_right", "store_base", "mango_tree", "coconut_palm"]
	for p in props:
		t.check(ResourceLoader.exists("res://assets/props/home/%s.glb" % p), "assets/props/home/%s.glb exists" % p)
	for f in ["res://assets/fonts/LuckiestGuy-Regular.ttf", "res://assets/ui/home/cardboard.png", "res://assets/ui/home/tape.png",
			"res://assets/audio/home/home_music.wav", "res://assets/props/home/street_decal.png"]:
		t.check(FileAccess.file_exists(f) or ResourceLoader.exists(f), "%s exists" % f)
	t.check(FileAccess.file_exists(HomeDioramaData.new().ref_overlay),
		"the reference overlay image is on disk (loaded as a raw file, source_art/ is Godot-ignored)")
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
	t.check(d.pass_vehicle != null, "the background tricycle is built")
	for g in ["res://shaders/diorama_sky.gdshader", "res://shaders/diorama_dof.gdshader", "res://assets/props/home/store.glb"]:
		t.check(ResourceLoader.exists(g), "%s exists" % g)
	t.check(d.ref_overlay == null, "the reference overlay stays off without --home-ref")
	t.check(is_equal_approx(d.timeline.get_animation("loop").length, 48.0), "the Timeline animation is 48 s")
	for edge in [0.0, 47.9]:
		d.seek_to(edge)
		t.check(not d.pass_vehicle.visible, "the tricycle is off the road at %.1f s" % edge)
		for who in d.walkers:
			if d.data.bystanders[who].has("from"):
				t.check(not (d.walkers[who] as Node3D).visible, "%s is out of sight at %.1f s" % [who, edge])
	t.check(d._sky_mat != null and d._sky_mat.shader != null, "the diorama has its own sky shader")
	var blur := d.camera.get_node_or_null("DepthBlur") as MeshInstance3D
	t.check(blur != null and blur.material_override is ShaderMaterial, "the depth-blur quad rides the camera")
	t.check(d.data.backdrop.size() >= 8, "the skyline backdrop has its facades (%d)" % d.data.backdrop.size())
	d.seek_to(d.data.pass_t0 + 2.0)
	t.check(d.pass_vehicle.visible and d.pass_progress() > 0.0 and d.pass_progress() < 1.0, "the tricycle is on the road mid-pass")
	# The seat fit is computed from the sit clip, so the suite measures the pose the AnimationTree
	# actually drives: at rest each sitter's pelvis within 3 cm of the seat top plus the pad, and over
	# the whole loop no sole below the floor and no pelvis below its own stool.
	d.seek_to(0.0)
	var seated: Array = []
	for hero in d.data.cast:
		if String(d.data.cast[hero].get("stool", "")) == "":
			continue
		var m: Dictionary = d.sitter_pose(hero)
		t.check(not m.is_empty(), "%s has a measured seat fit" % hero)
		if m.is_empty():
			continue
		seated.append(hero)
		var want: float = float(m.seat_top) + float(m.pad)
		t.check(absf(float(m.pelvis) - want) <= 0.03,
			"%s sits within 3 cm of its seat (pelvis %.3f m, seat top + pad %.3f m)" % [hero, m.pelvis, want])
	var lo := {}
	for hero in seated:
		lo[hero] = {"pelvis": INF, "sole": INF}
	var fired := [0]
	d.turn_started.connect(func(_h, _l): fired[0] += 1)
	d.seek_to(0.0)
	for _i in range(int(48.0 / 0.05)):
		d.step(0.05)
		for hero in seated:
			var p: Dictionary = d.sitter_pose(hero)
			if p.is_empty():
				continue
			lo[hero]["pelvis"] = minf(lo[hero]["pelvis"], float(p.pelvis))
			lo[hero]["sole"] = minf(lo[hero]["sole"], float(p.sole))
	for hero in seated:
		var seat_top: float = float(d.sitter_pose(hero).seat_top)
		t.check(float(lo[hero]["sole"]) >= -0.005,
			"%s never puts a sole under the floor across the sit clip (lowest %.4f m)" % [hero, lo[hero]["sole"]])
		t.check(float(lo[hero]["pelvis"]) >= seat_top - 0.03,
			"%s never sinks through its stool (lowest pelvis %.3f m, seat top %.3f m)" % [hero, lo[hero]["pelvis"], seat_top])
	t.check(fired[0] >= 3, "heroes take their turns to talk over a full loop (%d turns)" % fired[0])
	# Every gesture's end cue must land: one method track once held a single key per instant, so two
	# gestures ending together dropped one end cue and that hero kept gesturing to the end of the clip.
	d.seek_to(0.0)
	var gestures: Array = d.data.gestures
	var checked := 0
	var stuck := []
	var tt := 0.0
	while tt < d.data.loop_length - 0.2:
		d.step(1.0 / 30.0)
		tt += 1.0 / 30.0
		for g in gestures:
			var probe: float = float(g.t) + float(g.dur) + d.data.gesture_fade_out + 0.2
			if tt >= probe and tt < probe + 1.0 / 30.0:
				checked += 1
				var again := false
				for h in gestures:
					if h.hero == g.hero and h != g and float(h.t) <= probe and probe < float(h.t) + float(h.dur) + d.data.gesture_fade_out:
						again = true
				if not again and bool((d.actors[g.hero] as DioramaActor).tree.get("parameters/Upper/active")):
					stuck.append("%s %s" % [g.hero, g.clip])
	t.check(checked == gestures.size() and stuck.is_empty(),
		"every gesture ends on cue and releases the upper body (%d/%d probed, stuck: %s)" % [checked, gestures.size(), stuck])
	t.check(d.time < 1.0 or d.time > 47.0, "a full loop returns to the start")
	# Hand pops: the hands never lurch. A gesture cut mid-motion, a lost end cue or a base-idle seam
	# shows as a velocity-change spike; QC's tools/qc_home_motion.gd prints the worst offenders.
	var motion: Dictionary = HomeMotion.measure(d, 2.0)
	for hero in motion.heroes:
		var h: Dictionary = motion.heroes[hero]
		t.check(float(h.peak_speed) <= MAX_HAND_SPEED and float(h.peak_dv) <= MAX_HAND_DV,
			"%s hands stay smooth (peak %.2f m/s, change %.2f m/s per frame @%.2f s in %s; limits %.1f / %.1f)" % [
				hero, h.peak_speed, h.peak_dv, h.peak_dv_t, h.peak_dv_active, MAX_HAND_SPEED, MAX_HAND_DV])
	d.queue_free()
	await t.frames(1)
	t.ok("Home diorama builds, seats its cast on the computed stools, and loops")

## Home without the 3D backdrop (headless), then the picker flow end to end.
func _home_and_picker(t: TestCtx) -> void:
	var save := t.tree.root.get_node_or_null("Save")
	var before: String = save.profile.get("home_hero", "jm") if save else "jm"
	var home = (load(HOME_SCENE) as PackedScene).instantiate()
	home.navigate = false
	t.tree.root.add_child(home)
	await t.frames(3)
	for n in ["PlayerCard", "PlayerFace", "PlayerName", "Stats", "PlayerStats", "Laro", "Settings", "Tansan", "News", "Profile"]:
		t.check(home.find_child(n, true, false) != null, "Home has %s" % n)
	t.check(home.find_child("Barkada", true, false) != null and home.find_child("Locker", true, false) != null
			and home.find_child("Gawain", true, false) != null, "the three locked tiles sit in a row under TUTORIAL")
	var settings_btn := home.find_child("Settings", true, false) as Control
	t.check(settings_btn != null and settings_btn.global_position.x > 1400.0, "SETTINGS sits at the top right")
	var right_ok := true
	for n in ["Tansan", "News", "Profile"]:
		var tile := home.find_child(n, true, false) as Control
		right_ok = right_ok and tile != null and tile.global_position.x > 1400.0 and tile.global_position.y < 420.0
	t.check(right_ok, "TANSAN / BALITA / PROFILE stack under SETTINGS on the right")
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
