@tool
extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("[INTEGRATION TEST] Starting Batang Hamog animation and gameplay verification...")
	# 1. GLB clips
	var glb: PackedScene = load("res://assets/characters/batang_hamog.glb")
	assert(glb != null, "Batang Hamog GLB must be loadable")
	var char_node = glb.instantiate()
	var ap: AnimationPlayer = char_node.find_child("*AnimationPlayer*", true, false)
	assert(ap != null, "AnimationPlayer must exist")
	for anim_name in ["Idle", "Walking", "Running"]:
		assert(ap.has_animation(anim_name), "Animation %s must exist" % anim_name)
		var a := ap.get_animation(anim_name)
		print("  ✓ Verified clip: %s (len: %.2fs, tracks: %d)" % [anim_name, a.length, a.get_track_count()])
		assert(a.get_track_count() >= 60, "Clip %s must animate full skeleton" % anim_name)
	for anim_name in ["Harurot", "Lusot_Slide", "Lusot_Vault"]:
		assert(ap.has_animation(anim_name), "New clip %s must exist" % anim_name)
		var a2 := ap.get_animation(anim_name)
		print("  ✓ Verified new clip: %s (len: %.2fs, tracks: %d)" % [anim_name, a2.length, a2.get_track_count()])
		assert(a2.get_track_count() >= 60, "Clip %s must animate full skeleton" % anim_name)
	assert(snapped(ap.get_animation("Harurot").length, 0.05) == 1.0, "Harurot must be 24f @24fps = 1.0s")
	assert(ap.get_animation("Lusot_Slide").length > 0.9 and ap.get_animation("Lusot_Slide").length < 1.0, "Lusot_Slide must be ~0.96s (0.7+0.25)")
	assert(ap.get_animation("Lusot_Vault").length > 0.5 and ap.get_animation("Lusot_Vault").length < 0.7, "Lusot_Vault must be ~0.58s")
	for removed_name in ["Slide", "Dash"]:
		assert(not ap.has_animation(removed_name), "Removed clip %s must not reappear" % removed_name)
	# exact-name guard: Lusot_Slide must not satisfy Slide check
	assert(ap.has_animation("Lusot_Slide") and not ap.has_animation("Slide"), "Slide absent must be exact-name, Lusot_Slide allowed")
	char_node.free()

	# 1c. JM Botsog procedural character (pure-bpy, Mixamo + towel, XYZ Euler)
	print("[INTEGRATION TEST] Verifying JM Botsog...")
	var jm_glb: PackedScene = load("res://assets/characters/jm_botsog.glb")
	assert(jm_glb != null, "JM GLB must be loadable")
	var jm_node = jm_glb.instantiate()
	var jm_ap: AnimationPlayer = jm_node.find_child("*AnimationPlayer*", true, false)
	assert(jm_ap != null, "JM AnimationPlayer must exist")
	for jm_anim in ["Idle", "Walking", "Running"]:
		assert(jm_ap.has_animation(jm_anim), "JM animation %s must exist" % jm_anim)
		var ja := jm_ap.get_animation(jm_anim)
		print("  ✓ JM clip: %s (len: %.2fs, tracks: %d)" % [jm_anim, ja.length, ja.get_track_count()])
		assert(ja.get_track_count() >= 60, "JM clip %s must animate full skeleton" % jm_anim)
	for bad in ["Slide", "Dash"]:
		assert(not jm_ap.has_animation(bad), "JM removed clip %s must not reappear" % bad)
	# Mixamo bones + towel bones via track paths
	var jm_has_hips := false
	var jm_has_towel1 := false
	var jm_has_towel2 := false
	var jm_has_head := false
	var jm_idle := jm_ap.get_animation("Idle")
	for ti in range(jm_idle.get_track_count()):
		var tp := str(jm_idle.track_get_path(ti))
		if "Hips" in tp: jm_has_hips = true
		if "Towel1" in tp: jm_has_towel1 = true
		if "Towel2" in tp: jm_has_towel2 = true
		if "Head" in tp: jm_has_head = true
	assert(jm_has_hips, "JM must have Mixamo Hips")
	assert(jm_has_head, "JM must have Mixamo Head")
	assert(jm_has_towel1 and jm_has_towel2, "JM must have Towel1_R + Towel2_R")
	print("  ✓ JM Mixamo + towel bones present")
	var jm_sk: Skeleton3D = jm_node.find_child("*Skeleton3D*", true, false)
	if jm_sk == null:
		# fallback search Skeleton3D
		var stack := [jm_node]
		while stack.size() > 0 and jm_sk == null:
			var c = stack.pop_back()
			if c is Skeleton3D: jm_sk = c
			for ch in c.get_children(): stack.push_back(ch)
	assert(jm_sk != null, "JM Skeleton3D must exist")
	assert(jm_sk.get_bone_count() >= 50, "JM skeleton must have full Mixamo + fingers + towel")
	print("  ✓ JM skeleton bones: %d" % jm_sk.get_bone_count())
	jm_node.free()

	# 1b. InputMap bindings from ProjectSettings
	for action in ["move_forward", "move_back", "move_left", "move_right", "skill_harurot", "skill_lusot", "action_tag"]:
		assert(InputMap.has_action(action), "InputMap action %s must be wired" % action)
	print("  ✓ InputMap actions wired (7/7)")

	# 2/3/4. Controller + Dire + VFX (needs physics frames for RayCasts/anim)
	var HamogScript: GDScript = load("res://scripts/runtime/batang_hamog.gd")
	var player: CharacterBody3D = HamogScript.new()
	player.position = Vector3(0, 0.2, 0)
	root.add_child(player)
	await physics_frame
	await physics_frame
	assert(player.get("dire_diretso") != null, "DireDiretso component must exist")
	assert(player.get_node_or_null("VaultDetector/LowObstacleCast") != null, "LowObstacleCast must exist")
	assert(player.get_node_or_null("VaultDetector/HeadClearanceCast") != null, "HeadClearanceCast must exist")
	var low: RayCast3D = player.get_node("VaultDetector/LowObstacleCast")
	var head: RayCast3D = player.get_node("VaultDetector/HeadClearanceCast")
	assert(low.target_position.length() > 1.1 and low.target_position.length() < 1.3, "Low cast must reach 1.2m")
	assert(head.target_position.length() > 1.1 and head.target_position.length() < 1.3, "Head cast must reach 1.2m")
	# VFX (Phase 3)
	for vfx in ["HarurotWindTrail", "HarurotPushOff", "LusotSlideDust", "LusotMist", "DireWisps"]:
		assert(player.get_node_or_null(vfx) != null, "VFX %s must exist" % vfx)
	var trail: GPUParticles3D = player.get_node("HarurotWindTrail")
	assert(trail.local_coords == false, "Wind trail must stay in world space")
	assert(trail.lifetime >= 0.6 and trail.lifetime <= 0.8, "Wind trail lifetime 0.6-0.8s")
	print("  ✓ VaultDetector + VFX present")

	# 2. Harurot recovery through Walk never Run
	assert(player.get("harurot_clip") != "", "Harurot clip must be detected")
	assert(player.get("walk_clip") != "", "Walk clip must be detected")
	assert(player.get_recovery_clip() == player.get("walk_clip"), "Recovery must use Walk")
	assert(player.get_recovery_clip() != player.get("run_clip"), "Recovery must never use Run")
	# runtime: force recovery and verify Walk plays
	player.state = 2 # HARUROT_RECOVERY
	player.recovery_timer = 0.3
	player.velocity = Vector3(0, 0, 5)
	await physics_frame
	await physics_frame
	var cur_anim: String = player.animator.current_animation if player.animator else ""
	assert(cur_anim == player.get("walk_clip"), "During recovery anim must be Walk, got %s" % cur_anim)
	player.state = 0
	print("  ✓ Harurot recovery via Walk (never Run)")

	# 3. Lusot slide lowers hurtbox 0.7s + 0.25s tag lockout
	var ok: bool = player.try_lusot()
	assert(ok, "Lusot slide must trigger in open space")
	assert(player.state == 3, "State must be LUSOT_SLIDE")
	var bcap: CapsuleShape3D = player.body_collision.shape
	var hcap: CapsuleShape3D = player.hurtbox_collision.shape
	assert(snapped(bcap.height, 0.01) == snapped(1.6 * 0.5, 0.01), "Body collision must halve during slide")
	assert(snapped(hcap.height, 0.01) == snapped(1.6 * 0.5, 0.01), "Hurtbox must halve during slide")
	assert(player.lusot_timer > 0.6 and player.lusot_timer <= 0.7, "Slide timer must be 0.7s")
	# fast-forward slide
	player.lusot_timer = 0.01
	await physics_frame
	await physics_frame
	await physics_frame
	assert(player.state == 4, "Must enter LUSOT_RECOVERY, got %d" % player.state)
	assert(player.is_tag_locked(), "Tag must lock during 0.25s recovery")
	assert(not player.attempt_tag(), "attempt_tag must fail while locked")
	# heights restored after slide
	assert(snapped((player.body_collision.shape as CapsuleShape3D).height, 0.01) == 1.6, "Body height must restore after slide")
	player.lusot_timer = 0.01
	player.tag_lockout_timer = 0.01
	await physics_frame
	await physics_frame
	assert(not player.is_tag_locked(), "Tag lock must expire after 0.25s")
	assert(player.attempt_tag(), "Tag must work after recovery")
	print("  ✓ Lusot slide hurtbox + tag lockout")

	# 4. Dire-Diretso stacks + resets + flag override
	var dire = player.dire_diretso
	dire.reset_momentum()
	dire.base_run_speed = 5.0
	for i in range(int(6.2 / 0.05)):
		dire.update_momentum(0.05, Vector3(0, 0, 5.2))
	assert(dire.momentum_stacks == 4, "Must cap at 4 stacks, got %d" % dire.momentum_stacks)
	assert(snapped(dire.speed_bonus(), 0.001) == 1.2, "4 stacks must give +20%")
	dire.update_momentum(0.05, Vector3.ZERO)
	assert(dire.momentum_stacks == 0, "Stop must reset")
	for i in range(40):
		dire.update_momentum(0.05, Vector3(0, 0, 5.2))
	assert(dire.momentum_stacks >= 1, "Must rebuild after reset")
	dire.update_momentum(0.05, Vector3(0, 0, -5.2))
	assert(dire.momentum_stacks == 0, "180 reversal (dot<-0.5) must reset")
	for i in range(40):
		dire.update_momentum(0.05, Vector3(0, 0, 5.2))
	dire.on_tag_attempt()
	assert(dire.momentum_stacks == 0, "Tag attempt must reset")
	for i in range(40):
		dire.update_momentum(0.05, Vector3(0, 0, 5.2))
	dire.on_hit_by_skill()
	assert(dire.momentum_stacks == 0, "Enemy skill hit must reset")
	player.is_carrying_flag = true
	for i in range(60):
		dire.update_momentum(0.05, Vector3(0, 0, 5.2))
	assert(dire.momentum_stacks == 0, "Flag carry must hold at 0")
	player.is_carrying_flag = false
	for i in range(40):
		dire.update_momentum(0.05, Vector3(0, 0, 5.2))
	assert(dire.momentum_stacks > 0, "Must rebuild after flag dropped")
	print("  ✓ Dire-Diretso stacks/resets/flag override")
	player.free()

	# 3b. Lusot vault launches where the player faces (body is never rotated, only the visual)
	for yaw_deg in [0.0, 90.0, 180.0, -90.0]:
		var yaw := deg_to_rad(yaw_deg)
		var facing := Vector3(sin(yaw), 0, cos(yaw))
		var box := StaticBody3D.new()
		var box_cs := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(0.4, 1.0, 0.4) # low cast (0.65m) hits, head cast (1.45m) clears
		box_cs.shape = box_shape
		box.add_child(box_cs)
		box.position = Vector3(0, 0.5, 0) + facing * 0.9
		root.add_child(box)
		var vp: CharacterBody3D = HamogScript.new()
		vp.position = Vector3(0, 0.2, 0)
		root.add_child(vp)
		await physics_frame
		vp.visual.rotation.y = yaw
		vp.vault_detector.rotation.y = yaw
		await physics_frame
		await physics_frame
		assert(vp.get_facing_dir().distance_to(facing) < 0.01, "Facing at yaw %d must be %s" % [yaw_deg, facing])
		var vlow: RayCast3D = vp.low_cast
		var cast_dir: Vector3 = (vlow.global_transform.basis * vlow.target_position).normalized()
		assert(cast_dir.distance_to(facing) < 0.01, "Vault low cast at yaw %d must point along facing, got %s" % [yaw_deg, cast_dir])
		assert(vlow.is_colliding() and not vp.head_cast.is_colliding(), "Low box ahead at yaw %d must be vaultable" % yaw_deg)
		assert(vp.try_lusot(), "Lusot must trigger at yaw %d" % yaw_deg)
		assert(vp.state == 5, "Low box ahead must vault (LUSOT_VAULT), got %d" % vp.state)
		assert(vp.vault_dir.distance_to(facing) < 0.01, "Vault at yaw %d must go %s, got %s" % [yaw_deg, facing, vp.vault_dir])
		vp.free()
		box.free()
	print("  ✓ Lusot vault direction follows facing (4 yaws)")

	# 5. Meshy heroes (tools/build_heroes.py): clips, speed-blended controller, character select
	print("[INTEGRATION TEST] Verifying heroes...")
	var floor_body := StaticBody3D.new()
	var floor_cs := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(200, 1, 200)
	floor_cs.shape = floor_shape
	floor_body.add_child(floor_cs)
	floor_body.position = Vector3(0, -0.5, 0)
	root.add_child(floor_body)
	var hero_ids: Array[String] = []
	for hero in HeroRoster.HEROES:
		hero_ids.append(hero["id"])
	assert(hero_ids == ["tutoy", "nene", "nathan", "jm", "inday"], "Roster must be the five heroes (no Batang Hamog), got %s" % [hero_ids])
	var want_speed := {"tutoy": 5.4, "nene": 5.0, "nathan": 5.0, "jm": 4.6, "inday": 5.0}
	for hid in hero_ids:
		var hero_glb: PackedScene = load(HeroRoster.get_hero(hid)["glb"])
		assert(hero_glb != null, "%s GLB must load" % hid)
		var hnode = hero_glb.instantiate()
		var hap: AnimationPlayer = hnode.find_child("*AnimationPlayer*", true, false)
		assert(hap != null, "%s AnimationPlayer must exist" % hid)
		for clip_name in ["Idle", "Walking", "Running", "BreakDance"]:
			assert(hap.has_animation(clip_name), "%s clip %s must exist" % [hid, clip_name])
			assert(hap.get_animation(clip_name).get_track_count() >= 60, "%s clip %s must animate full skeleton" % [hid, clip_name])
		for bad in ["Slide", "Dash"]:
			assert(not hap.has_animation(bad), "%s must not have %s" % [hid, bad])
		# Meshy's stray Icosphere must be stripped: only the skinned body mesh remains.
		var meshes: Array = hnode.find_children("*", "MeshInstance3D", true, false)
		assert(meshes.size() == 1, "%s must have exactly one mesh, got %d" % [hid, meshes.size()])
		hnode.free()

		var hp := HeroController.new()
		hp.hero_id = hid
		hp.position = Vector3(0, 0.05, 0)
		root.add_child(hp)
		await physics_frame
		assert(hp.anim_tree != null and hp.anim_tree.active, "%s AnimationTree must be active" % hid)
		var space := (hp.anim_tree.tree_root as AnimationNodeBlendTree).get_node("Locomotion") as AnimationNodeBlendSpace1D
		assert(space.get_blend_point_count() == 3, "%s blend space must hold idle/walk/run" % hid)
		assert(is_equal_approx(hp.run_speed, want_speed[hid]), "%s run speed must be %.1f" % [hid, want_speed[hid]])
		assert(is_equal_approx(hp.walk_speed, hp.run_speed * 0.5), "%s walk must be half run" % hid)
		assert(hp.run_clip_speed > 0.0 and hp.walk_clip_speed > 0.0, "%s needs measured clip speeds in the roster" % hid)
		assert(is_equal_approx(hp.playback_scale(hp.run_speed), hp.run_speed / hp.run_clip_speed), "%s run playback must match foot speed" % hid)
		assert(is_equal_approx(hp.playback_scale(0.0), 1.0), "%s idle plays at 1x" % hid)
		assert(hp.speed_for_tilt(0.1) == 0.0 and hp.speed_for_tilt(0.3) == hp.walk_speed and hp.speed_for_tilt(0.5) == hp.run_speed and hp.speed_for_tilt(1.0) == hp.run_speed, "%s stick thresholds 15%%/50%%" % hid)
		assert(is_equal_approx(space.get_blend_point_position(1), hp.walk_speed), "%s walk point at walk_speed" % hid)
		assert(is_equal_approx(space.get_blend_point_position(2), hp.run_speed), "%s run point at run_speed" % hid)
		hp.external_move = Vector2(0, 1)
		for i in range(40):
			await physics_frame
		assert(absf(hp.get_ground_speed() - hp.run_speed) < 0.05, "%s must reach run speed, got %.2f" % [hid, hp.get_ground_speed()])
		assert(absf(float(hp.anim_tree.get(hp.BLEND_PARAM)) - hp.run_speed) < 0.05, "%s blend must sit on Running" % hid)
		assert(hp.get_facing_dir().distance_to(Vector3(0, 0, 1)) < 0.05, "%s must face its move direction" % hid)
		hp.external_move = Vector2(0, 0.3) # light stick tilt walks
		for i in range(40):
			await physics_frame
		assert(absf(hp.get_ground_speed() - hp.walk_speed) < 0.05, "%s walk must settle at walk_speed" % hid)
		assert(absf(float(hp.anim_tree.get(hp.BLEND_PARAM)) - hp.walk_speed) < 0.05, "%s blend must sit on Walking" % hid)
		hp.external_move = Vector2(0, 0.1) # inside the 15 % deadzone
		for i in range(30):
			await physics_frame
		assert(hp.get_ground_speed() < 0.01 and float(hp.anim_tree.get(hp.BLEND_PARAM)) < 0.01, "%s must settle into Idle" % hid)
		print("  ✓ %s: clips + idle/walk/run speed blend" % hid)
		hp.free()
	floor_body.free()

	# character select -> playtest spawns the picked hero
	var select_scene: PackedScene = load("res://scenes/character_select.tscn")
	var select_inst = select_scene.instantiate()
	root.add_child(select_inst)
	await process_frame
	assert(select_inst.cards.size() == HeroRoster.HEROES.size(), "Every hero needs a card")
	select_inst.select(2)
	assert(HeroRoster.selected_id == "nathan", "Selecting card 2 must pick Nathan")
	assert(select_inst.preview_player.current_animation == "BreakDance", "Select screen hero must break dance")
	select_inst.free()
	HeroRoster.selected_id = "inday"
	var court_inst = (load("res://scenes/court_playtest.tscn") as PackedScene).instantiate()
	root.add_child(court_inst)
	await physics_frame
	assert(court_inst.player is HeroController and court_inst.player.hero_id == "inday", "Playtest must spawn the selected hero")
	court_inst.free()
	HeroRoster.selected_id = ""
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/character_select.tscn", "Main scene must be the character select")
	print("  ✓ Character select -> playtest spawns the picked hero")

	# scenes still load
	for scene_path in ["res://scenes/court_playtest.tscn", "res://scenes/movement_test.tscn", "res://scenes/character_select.tscn"]:
		var scn: PackedScene = load(scene_path)
		assert(scn != null, "Scene %s must load" % scene_path)
		var inst = scn.instantiate()
		assert(inst != null, "Scene instance must succeed")
		print("  ✓ Verified scene loads: %s" % scene_path)
		inst.free()

	print("[INTEGRATION TEST] All checks passed successfully (100%)!")
	quit(0)
