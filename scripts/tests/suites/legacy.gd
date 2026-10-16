extends RefCounted

## Port of the old single-file gate (git show HEAD~:scripts/tests/integration_test.gd): the Batang
## Hamog prototype, JM Botsog's procedural rig, the Hamog controller, Dire-Diretso, LUSOT!
## vault direction, the character select and scene loads. The per-hero HeroController clip and
## speed-blend checks are left out on purpose: the hero clips are being rebuilt (see
## hero_assets.gd for the new clip checks).

func run(t: TestCtx) -> void:
	var root := t.tree.root
	# 1. Batang Hamog GLB clips
	var glb := load("res://assets/characters/batang_hamog.glb") as PackedScene
	if t.check(glb != null, "Batang Hamog GLB must be loadable"):
		var char_node := glb.instantiate()
		var ap := char_node.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
		if t.check(ap != null, "Hamog AnimationPlayer must exist"):
			for anim_name in ["Idle", "Walking", "Running", "Harurot", "Lusot_Slide", "Lusot_Vault"]:
				if t.check(ap.has_animation(anim_name), "Hamog animation %s must exist" % anim_name):
					t.check(ap.get_animation(anim_name).get_track_count() >= 60, "Hamog clip %s must animate full skeleton" % anim_name)
			if ap.has_animation("Harurot"):
				t.check(snappedf(ap.get_animation("Harurot").length, 0.05) == 1.0, "Harurot must be 24f @24fps = 1.0s")
			if ap.has_animation("Lusot_Slide"):
				var ls := ap.get_animation("Lusot_Slide").length
				t.check(ls > 0.9 and ls < 1.0, "Lusot_Slide must be ~0.96s (0.7+0.25)")
			if ap.has_animation("Lusot_Vault"):
				var lv := ap.get_animation("Lusot_Vault").length
				t.check(lv > 0.5 and lv < 0.7, "Lusot_Vault must be ~0.58s")
			for removed_name in ["Slide", "Dash"]:
				t.check(not ap.has_animation(removed_name), "Removed clip %s must not reappear" % removed_name)
			t.check(ap.has_animation("Lusot_Slide") and not ap.has_animation("Slide"), "Slide absent must be exact-name, Lusot_Slide allowed")
		char_node.free()
	t.ok("Batang Hamog clips")

	# 1c. JM Botsog procedural character (pure-bpy, Mixamo + towel, XYZ Euler)
	var jm_glb := load("res://assets/characters/jm_botsog.glb") as PackedScene
	if t.check(jm_glb != null, "JM Botsog GLB must be loadable"):
		var jm_node := jm_glb.instantiate()
		var jm_ap := jm_node.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
		if t.check(jm_ap != null, "JM AnimationPlayer must exist"):
			for jm_anim in ["Idle", "Walking", "Running"]:
				if t.check(jm_ap.has_animation(jm_anim), "JM animation %s must exist" % jm_anim):
					t.check(jm_ap.get_animation(jm_anim).get_track_count() >= 60, "JM clip %s must animate full skeleton" % jm_anim)
			for bad in ["Slide", "Dash"]:
				t.check(not jm_ap.has_animation(bad), "JM removed clip %s must not reappear" % bad)
			var has := {"Hips": false, "Towel1": false, "Towel2": false, "Head": false}
			if jm_ap.has_animation("Idle"):
				var jm_idle := jm_ap.get_animation("Idle")
				for ti in range(jm_idle.get_track_count()):
					var tp := str(jm_idle.track_get_path(ti))
					for key in has:
						if key in tp:
							has[key] = true
			t.check(has.Hips, "JM must have Mixamo Hips")
			t.check(has.Head, "JM must have Mixamo Head")
			t.check(has.Towel1 and has.Towel2, "JM must have Towel1_R + Towel2_R")
		var jm_sk := jm_node.find_child("*Skeleton3D*", true, false) as Skeleton3D
		if jm_sk == null:
			var stack: Array = [jm_node]
			while stack.size() > 0 and jm_sk == null:
				var c: Node = stack.pop_back()
				if c is Skeleton3D:
					jm_sk = c
				for ch in c.get_children():
					stack.push_back(ch)
		if t.check(jm_sk != null, "JM Skeleton3D must exist"):
			t.check(jm_sk.get_bone_count() >= 50, "JM skeleton must have full Mixamo + fingers + towel (got %d)" % jm_sk.get_bone_count())
		jm_node.free()
	t.ok("JM Botsog rig")

	# 1b. InputMap bindings from ProjectSettings
	for action in ["move_forward", "move_back", "move_left", "move_right", "skill_harurot", "skill_lusot", "action_tag"]:
		t.check(InputMap.has_action(action), "InputMap action %s must be wired" % action)
	t.ok("legacy InputMap actions")

	# 2/3/4. Hamog controller + Dire + VFX (needs physics frames for RayCasts/anim)
	var HamogScript := load("res://scripts/runtime/batang_hamog.gd") as GDScript
	if not t.check(HamogScript != null, "batang_hamog.gd must load"):
		return
	var player: CharacterBody3D = HamogScript.new()
	player.position = Vector3(0, 0.2, 0)
	root.add_child(player)
	await t.physics_frames(2)
	t.check(player.get("dire_diretso") != null, "DireDiretso component must exist")
	var low := player.get_node_or_null("VaultDetector/LowObstacleCast") as RayCast3D
	var head := player.get_node_or_null("VaultDetector/HeadClearanceCast") as RayCast3D
	t.check(low != null, "LowObstacleCast must exist")
	t.check(head != null, "HeadClearanceCast must exist")
	if low:
		t.check(low.target_position.length() > 1.1 and low.target_position.length() < 1.3, "Low cast must reach 1.2m")
	if head:
		t.check(head.target_position.length() > 1.1 and head.target_position.length() < 1.3, "Head cast must reach 1.2m")
	for vfx in ["HarurotWindTrail", "HarurotPushOff", "LusotSlideDust", "LusotMist", "DireWisps"]:
		t.check(player.get_node_or_null(vfx) != null, "VFX %s must exist" % vfx)
	var trail := player.get_node_or_null("HarurotWindTrail") as GPUParticles3D
	if trail:
		t.check(trail.local_coords == false, "Wind trail must stay in world space")
		t.check(trail.lifetime >= 0.6 and trail.lifetime <= 0.8, "Wind trail lifetime 0.6-0.8s")
	t.ok("VaultDetector + VFX present")

	# Harurot recovery through Walk never Run
	t.check(player.get("harurot_clip") != "", "Harurot clip must be detected")
	t.check(player.get("walk_clip") != "", "Walk clip must be detected")
	t.check(player.get_recovery_clip() == player.get("walk_clip"), "Recovery must use Walk")
	t.check(player.get_recovery_clip() != player.get("run_clip"), "Recovery must never use Run")
	player.state = 2 # HARUROT_RECOVERY
	player.recovery_timer = 0.3
	player.velocity = Vector3(0, 0, 5)
	await t.physics_frames(2)
	var cur_anim: String = player.animator.current_animation if player.animator else ""
	t.check(cur_anim == player.get("walk_clip"), "During recovery anim must be Walk, got %s" % cur_anim)
	player.state = 0
	t.ok("Harurot recovery via Walk (never Run)")

	# Lusot slide lowers hurtbox 0.7s + 0.25s tag lockout
	var did_slide: bool = player.try_lusot()
	t.check(did_slide, "Lusot slide must trigger in open space")
	t.check(player.state == 3, "State must be LUSOT_SLIDE")
	var bcap: CapsuleShape3D = player.body_collision.shape
	var hcap: CapsuleShape3D = player.hurtbox_collision.shape
	t.check(snappedf(bcap.height, 0.01) == snappedf(1.6 * 0.5, 0.01), "Body collision must halve during slide")
	t.check(snappedf(hcap.height, 0.01) == snappedf(1.6 * 0.5, 0.01), "Hurtbox must halve during slide")
	t.check(player.lusot_timer > 0.6 and player.lusot_timer <= 0.7, "Slide timer must be 0.7s")
	player.lusot_timer = 0.01
	await t.physics_frames(3)
	t.check(player.state == 4, "Must enter LUSOT_RECOVERY, got %d" % player.state)
	t.check(player.is_tag_locked(), "Tag must lock during 0.25s recovery")
	t.check(not player.attempt_tag(), "attempt_tag must fail while locked")
	t.check(snappedf((player.body_collision.shape as CapsuleShape3D).height, 0.01) == 1.6, "Body height must restore after slide")
	player.lusot_timer = 0.01
	player.tag_lockout_timer = 0.01
	await t.physics_frames(2)
	t.check(not player.is_tag_locked(), "Tag lock must expire after 0.25s")
	t.check(player.attempt_tag(), "Tag must work after recovery")
	t.ok("Lusot slide hurtbox + tag lockout")

	# Dire-Diretso stacks + resets + flag override
	var dire = player.dire_diretso
	dire.reset_momentum()
	dire.base_run_speed = 5.0
	for i in range(int(6.2 / 0.05)):
		dire.update_momentum(0.05, Vector3(0, 0, 5.2))
	t.check(dire.momentum_stacks == 4, "Must cap at 4 stacks, got %d" % dire.momentum_stacks)
	t.check(snappedf(dire.speed_bonus(), 0.001) == 1.2, "4 stacks must give +20%")
	dire.update_momentum(0.05, Vector3.ZERO)
	t.check(dire.momentum_stacks == 0, "Stop must reset")
	for i in range(40):
		dire.update_momentum(0.05, Vector3(0, 0, 5.2))
	t.check(dire.momentum_stacks >= 1, "Must rebuild after reset")
	dire.update_momentum(0.05, Vector3(0, 0, -5.2))
	t.check(dire.momentum_stacks == 0, "180 reversal (dot<-0.5) must reset")
	for i in range(40):
		dire.update_momentum(0.05, Vector3(0, 0, 5.2))
	dire.on_tag_attempt()
	t.check(dire.momentum_stacks == 0, "Tag attempt must reset")
	for i in range(40):
		dire.update_momentum(0.05, Vector3(0, 0, 5.2))
	dire.on_hit_by_skill()
	t.check(dire.momentum_stacks == 0, "Enemy skill hit must reset")
	player.is_carrying_flag = true
	for i in range(60):
		dire.update_momentum(0.05, Vector3(0, 0, 5.2))
	t.check(dire.momentum_stacks == 0, "Flag carry must hold at 0")
	player.is_carrying_flag = false
	for i in range(40):
		dire.update_momentum(0.05, Vector3(0, 0, 5.2))
	t.check(dire.momentum_stacks > 0, "Must rebuild after flag dropped")
	t.ok("Dire-Diretso stacks/resets/flag override")
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
		await t.physics_frames(1)
		vp.visual.rotation.y = yaw
		vp.vault_detector.rotation.y = yaw
		await t.physics_frames(2)
		t.check(vp.get_facing_dir().distance_to(facing) < 0.01, "Facing at yaw %d must be %s" % [yaw_deg, facing])
		var vlow: RayCast3D = vp.low_cast
		var cast_dir: Vector3 = (vlow.global_transform.basis * vlow.target_position).normalized()
		t.check(cast_dir.distance_to(facing) < 0.01, "Vault low cast at yaw %d must point along facing, got %s" % [yaw_deg, cast_dir])
		t.check(vlow.is_colliding() and not vp.head_cast.is_colliding(), "Low box ahead at yaw %d must be vaultable" % yaw_deg)
		t.check(vp.try_lusot(), "Lusot must trigger at yaw %d" % yaw_deg)
		t.check(vp.state == 5, "Low box ahead must vault (LUSOT_VAULT), got %d" % vp.state)
		t.check(vp.vault_dir.distance_to(facing) < 0.01, "Vault at yaw %d must go %s, got %s" % [yaw_deg, facing, vp.vault_dir])
		vp.free()
		box.free()
	t.ok("Lusot vault direction follows facing (4 yaws)")

	# 5. Roster, character select, playtest
	var hero_ids: Array[String] = []
	for hero in HeroRoster.HEROES:
		hero_ids.append(hero["id"])
	t.check(hero_ids == ["tutoy", "nene", "nathan", "jm", "inday"], "Roster must be the five heroes (no Batang Hamog), got %s" % [hero_ids])
	var select_scene := load("res://scenes/character_select.tscn") as PackedScene
	var select_inst = select_scene.instantiate()
	root.add_child(select_inst)
	await t.frames(1)
	t.check(select_inst.cards.size() == HeroRoster.HEROES.size(), "Every hero needs a card")
	select_inst.select(2)
	t.check(HeroRoster.selected_id == "nathan", "Selecting card 2 must pick Nathan")
	t.check(select_inst.preview_player.current_animation == "BreakDance", "Select screen hero must break dance")
	select_inst.free()
	HeroRoster.selected_id = "inday"
	var court_inst = (load("res://scenes/court_playtest.tscn") as PackedScene).instantiate()
	root.add_child(court_inst)
	await t.physics_frames(1)
	t.check(court_inst.player is HeroController and court_inst.player.hero_id == "inday", "Playtest must spawn the selected hero")
	court_inst.free()
	HeroRoster.selected_id = ""
	t.check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/frontend/boot.tscn", "Main scene is the boot splash (front-end loop)")
	t.ok("character select -> playtest spawns the picked hero")

	# scenes still load
	for scene_path in ["res://scenes/court_playtest.tscn", "res://scenes/movement_test.tscn", "res://scenes/character_select.tscn", "res://scenes/match.tscn", "res://scenes/barangay_court.tscn"]:
		var scn := load(scene_path) as PackedScene
		if t.check(scn != null, "Scene %s must load" % scene_path):
			var inst := scn.instantiate()
			t.check(inst != null, "Scene %s must instantiate" % scene_path)
			if inst:
				inst.free()
	t.ok("scenes load")
