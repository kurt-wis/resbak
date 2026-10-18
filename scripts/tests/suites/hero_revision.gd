extends RefCounted

## Approved October revision: host locks, movable preparation, objective facing and UI.
func run(t: TestCtx) -> void:
	await _casting(t)
	await _prepare_and_capture(t)
	await _status_interaction(t)
	await _jm_carry_and_cadence(t)

func _jm_carry_and_cadence(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "jm", "team": RB.DILAW}, {"hero_id": "nathan", "team": RB.LILA}])
	t.go_live(host)
	var h: Hero = host.heroes[0]
	var enemy: Hero = host.heroes[1]
	TestCtx.put(h, 0, -4)
	TestCtx.put(enemy, 10, 8)
	var visual := h.visual
	for hz in [30, 60, 120]:
		visual._pose_remainder = 0.0
		visual.pose_sample_count = 0
		var elapsed := 0.0
		for i in range(hz):
			elapsed += visual.advance_pose_clock(1.0 / hz)
		t.check(visual.pose_sample_count == 24 and absf(elapsed - 1.0) < 0.00001, "24 pose samples preserve elapsed time at %d render fps" % hz)
	t.check(visual.tree.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "render loop cannot interpolate additional character poses")
	var towel = visual.extras.get_node("SkillAccents/ShoulderTowel")
	towel._update_cloth(0.0, true)
	t.check(towel.points[0].distance_to(visual.hand_position(0)) < 0.04, "cloth grip follows the actual rendered hand")
	var shoulder := visual._bone_pos(visual._bone_by_tail("RightArm"))
	var nearest := INF
	for point in towel.points:
		nearest = minf(nearest, point.distance_to(shoulder))
	t.check(nearest < 0.12 and towel.points[-1].y < shoulder.y - 0.3, "towel crosses the shoulder and hangs down the back")
	t.check(visual.has_clip("Tamaraw_Miss"), "JM exports a dedicated full-body miss recovery")
	# Actual HUD press route: cast on mouse/touch down; releasing must not cast again.
	var input := PlayerInput.new()
	host.add_child(input)
	var hud := Hud.new()
	host.add_child(hud)
	hud.input_source = input
	hud.setup(host, h, null)
	hud.touch.force_touch_controls = true
	hud.touch.visible = true
	var press := InputEventScreenTouch.new()
	press.index = 82
	press.pressed = true
	press.position = hud.touch.get_global_transform_with_canvas() * hud.touch.action_centres()[RB.BTN_SKILL2]
	hud.touch._input(press)
	var frame := input.frame_for(h, host)
	t.check(frame.pressed & RB.BTN_SKILL2 and input.touch_skill_button == 0, "Tamaraw click queues its edge immediately without a hold gesture")
	input.begin_touch_skill(RB.BTN_SKILL1)
	press.pressed = false
	hud.touch._input(press)
	t.check((input.frame_for(h, host).pressed & RB.BTN_SKILL2) == 0, "release does not issue a second Tamaraw cast")
	t.check(input.touch_skill_button == RB.BTN_SKILL1, "Tamaraw release cannot finish another simultaneous skill aim")
	input.finish_touch_skill(true)
	h.aim = Vector3.RIGHT
	t.check(h.skills[1].try_cast(frame), "click starts Tamaraw")
	h.skills[1].end("recast")
	t.check(h.cast_lock_ticks == RB.ticks(float(h.data.values.tamaraw_recovery)) and visual.tamaraw_miss_active() and h.is_taggable() and not h.is_stunned(), "empty charge uses existing half-second recovery, with no additional stun or protection")
	t.steps(host, h.cast_lock_ticks)
	t.check(not visual.tamaraw_miss_active() and h.can_move(), "dizzy pose ends on the authoritative recovery boundary")
	h.skills[1].cd_ticks = 0
	h.skills[1].try_cast(frame)
	enemy.teleport(h.global_position + Vector3.RIGHT * 0.2)
	h.skills[1]._shove_touched()
	h.skills[1].end("recast")
	t.check(not visual.tamaraw_miss_active(), "a charge that contacts an enemy never plays missed-charge dizziness")
	await t.free_match(host)
	t.ok("JM shoulder cloth, stepped poses and click-only missed-charge recovery")

func _casting(t: TestCtx) -> void:
	for id in HeroData.ORDER:
		var host := t.make_match([{"hero_id": id, "team": RB.DILAW}, {"hero_id": "nathan", "team": RB.LILA}])
		t.go_live(host)
		var h: Hero = host.heroes[0]
		TestCtx.put(host.heroes[1], 12, -9)
		for skill in h.skills:
			TestCtx.put(h, -5, -4)
			t.inputs(host).move(h, Vector2.RIGHT)
			t.inputs(host).aim_at(h, Vector3(5, 0, -4))
			h.set_frame(t.inputs(host).frame_for(h, host))
			t.check(skill.try_cast(h.frame), "%s S%d casts" % [id, skill.slot + 1])
			if skill.is_traversal():
				t.check(h.cast_lock_ticks == 0, "traversal uses its own transport without a generic plant")
			else:
				t.check(h.cast_lock_ticks > 0 and not h.can_press_tag() and not h.can_use_skills() and h.is_taggable(), "stationary cast plants actions and retains tag eligibility")
				var at := h.global_position
				t.steps(host, 5)
				t.check(RB.flat_dist(at, h.global_position) < 0.01, "cast plant prevents voluntary displacement")
				t.steps(host, h.cast_lock_ticks)
				t.check(h.can_move(), "movement returns at cast recovery end")
			skill.end("reset")
			t.steps(host, h.cast_lock_ticks)
			h.velocity = Vector3.ZERO
		await t.free_match(host)
	t.ok("all skills enforce stationary-cast and traversal contracts")

func _prepare_and_capture(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "inday", "team": RB.DILAW}, {"hero_id": "nene", "team": RB.LILA}])
	t.go_live(host)
	var h: Hero = host.heroes[0]
	TestCtx.put(h, 0, -4)
	var frame := InputFrame.new()
	frame.tag_preparing = true
	frame.move = Vector2.RIGHT
	frame.tag_aim_dir = Vector2.UP
	h.set_frame(frame)
	var at := h.global_position
	h.tick_move(1.0 / RB.TICK_RATE)
	t.check(h.can_move() and RB.flat_dist(at, h.global_position) > 0.0, "held Hampas permits movement")
	t.check(h.facing.z < -0.99 and h.visual._desired()[0] == "TagCharge", "prepared arm faces aim while legs can travel elsewhere")
	t.check(frame.duplicate_frame().tag_preparing and h.visual.is_upper_action("TagCharge"), "preparation survives input snapshots and uses an upper-body layer")
	host.tag_system.start_windup(h)
	t.check(not h.can_move() and not h.can_use_skills(), "released Hampas commits a planted strike")
	h.tag_started_tick = -1
	h.windup_end_tick = -1
	var pole := host.base_system.pole_pos(RB.LILA)
	h.teleport(pole + Vector3(-1, 0.05, 0))
	frame = InputFrame.new()
	frame.held = RB.BTN_INTERACT
	frame.aim_dir = Vector2.LEFT
	h.set_frame(frame)
	host.base_system.handle_interact(h, frame)
	h._update_facing()
	h.visual._process(0.1)
	t.check(h.capturing and h.facing.x > 0.99 and absf(h.visual.model.rotation.y - PI * 0.5) < 0.01, "capture faces the objective despite opposite aim")
	var strip := Vfx.tag_strip(2, 0.2, Color.WHITE)
	t.check(strip.mesh.get_faces().size() > 6, "ground attack guide has rounded-corner geometry")
	strip.free()
	await t.free_match(host)
	t.ok("movable preparation, planted commitment, objective-facing capture and rounded guides")

func _status_interaction(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "nene", "team": RB.DILAW}, {"hero_id": "nathan", "team": RB.LILA}])
	t.go_live(host)
	var h: Hero = host.heroes[0]
	var input := PlayerInput.new()
	host.add_child(input)
	var hud := Hud.new()
	host.add_child(hud)
	hud.input_source = input
	hud.setup(host, h, null)
	h.stun(1.0, false)
	hud.skills.refresh(0.1)
	# The same regions are used for hit tests and drawing, independent of renderer backend.
	hud.skills._hit_regions = [{"rect": Rect2(900, 800, 52, 52), "detail": "Stunned: movement and actions are disabled."}]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(920, 820)
	hud.skills._input(click)
	t.check(hud.skills._detail.begins_with("Stunned") and input.ui_pointer_captured, "status icon click opens details and captures attack pointer")
	click.pressed = false
	hud.skills._input(click)
	t.check(not input.ui_pointer_captured, "status release restores pointer input")
	hud.minimap.apply_layout()
	t.check(hud.feed.line_rect(0).position.y > hud.minimap.rect.end.y and hud.feed.line_rect(0).end.x <= hud.feed.sz().x - 24.0, "feed stack stays below minimap and inside screen")
	t.check(hud.touch.TAG_RADIUS == 115.0 and hud.touch.ACTION_RADIUS == 72.5, "action buttons use the enlarged layout")
	await t.free_match(host)
	t.ok("status detail interaction and enlarged action controls")
