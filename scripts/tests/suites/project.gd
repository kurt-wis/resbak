extends RefCounted

## Project settings, autoloads and the input map (spec section 12 "Engine", section 9 Controls).

func run(t: TestCtx) -> void:
	t.check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1920, "viewport width must be 1920")
	t.check(int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 1080, "viewport height must be 1080")
	t.check(str(ProjectSettings.get_setting("display/window/stretch/mode")) == "canvas_items", "stretch mode must be canvas_items")
	t.check(str(ProjectSettings.get_setting("display/window/stretch/aspect")) == "expand", "stretch aspect must be expand")
	t.check(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")) == 60, "physics must run 60 ticks/s")
	t.check(RB.TICK_RATE == 60, "RB.TICK_RATE must be 60")
	t.check(str(ProjectSettings.get_setting("physics/3d/physics_engine")) == "Jolt Physics", "Jolt Physics must be the 3D engine")
	for autoload in ["Save", "Session", "Audio"]:
		t.check(t.tree.root.get_node_or_null(autoload) != null, "autoload %s must exist" % autoload)
		t.check(ProjectSettings.has_setting("autoload/" + autoload), "autoload %s must be registered in project.godot" % autoload)
	Controls.ensure()
	for action in ["move_forward", "move_back", "move_left", "move_right", "tag", "skill_1", "skill_2", "interact", "ping", "scoreboard", "menu"]:
		t.check(InputMap.has_action(action), "input action %s must exist after Controls.ensure()" % action)
		t.check(not InputMap.action_get_events(action).is_empty(), "input action %s must have a binding" % action)
	# ensure() is idempotent
	var before := InputMap.action_get_events("tag").size()
	Controls.ensure()
	t.check(InputMap.action_get_events("tag").size() == before, "Controls.ensure() must not duplicate bindings")
	# Layer names (the spec's collision layers)
	t.check(RB.L_WORLD == 1 and RB.L_HERO == 2 and RB.L_GHOST == 4 and RB.L_SKILL_WALL == 8 and RB.L_VAULTABLE == 16 and RB.L_POLE == 32, "physics layer bits")
	# Tuning matches the spec's numbers
	var tu := Tuning.get_default()
	t.check(t.near(tu.body_radius, 0.4), "body radius 0.4")
	t.check(t.near(tu.tag_windup, 0.35) and RB.ticks(tu.tag_windup) == 21, "approved tag wind-up 0.35 s = 21 ticks (spec 0.15 s)")
	t.check(tu.move_speed_scale > 0.5 and tu.move_speed_scale < 1.0, "v0.2: everyone moves slower (move_speed_scale %.2f)" % tu.move_speed_scale)
	t.check(tu.chain_post_speed > 0.0 and tu.jail_band > 0.0, "jail line tuning (post speed, band)")
	t.check(tu.touch_target_release_range >= tu.tag_assist_range and tu.character_outline_pixels > 0.0 and tu.character_outline_pixels <= 1.5, "touch lock retention and thin character outline tuning")
	t.check(t.near(tu.tagged_freeze, 0.8), "tagged freeze 0.8 s")
	t.check(t.near(tu.failed_tag_stumble, 0.5), "failed tag stumble 0.5 s")
	t.check(t.near(tu.base_ring_radius, 2.0), "base ring 2 (no own-ring barrier since 2026-10-17)")
	t.check(t.near(tu.capture_hold, 2.0) and RB.ticks(tu.capture_hold) == 120, "capture hold 2.0 s = 120 ticks (v0.1.1 pacing; spec 1.5 s)")
	t.check(t.near(tu.escape_protection, 4.0) and t.near(tu.capture_lockout, 4.0), "EP and lockout 4 s")
	t.check(t.near(tu.round_time, 120.0) and t.near(tu.sudden_death_time, 30.0) and tu.points_to_win == 4, "round 120 s / sudden death 30 s / first to 4 (v0.1.1 pacing; spec 3)")
	t.check(t.near(tu.rescue_touch, 0.8) and t.near(tu.chain_link, 1.5) and tu.chain_max == 4, "rescue touch 0.8 / link 1.5 / max chain 4")
	t.check(t.near(tu.danger_border_range, 10.0) and t.near(tu.footstep_range, 15.0), "danger 10 / footsteps 15")
	t.ok("project settings, autoloads, input map, tuning")
