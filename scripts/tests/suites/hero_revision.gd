extends RefCounted

## Approved October revision: host locks, movable preparation, objective facing and UI.
func run(t: TestCtx) -> void:
	await _motion_contract(t)
	await _skill_assistance(t)
	await _casting(t)
	await _prepare_and_capture(t)
	await _status_interaction(t)
	await _jm_carry_and_cadence(t)

func _motion_contract(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "nathan", "team": RB.DILAW}, {"hero_id": "nene", "team": RB.LILA}, {"hero_id": "inday", "team": RB.DILAW}])
	t.go_live(host)
	var nathan: Hero = host.heroes[0]
	var nene: Hero = host.heroes[1]
	var inday: Hero = host.heroes[2]
	for i in range(host.heroes.size()):
		TestCtx.put(host.heroes[i], -8 + i * 5, -7)
	t.check(t.near(host.tuning.tag_windup, 0.35), "approved reference tag windup is 21 host ticks")
	for hero in host.heroes:
		for fraction in [0.25, 0.5, 0.75, 1.0]:
			var rate := hero.visual._loco_scale(hero.base_speed() * host.tuning.move_speed_scale * fraction)
			t.check(rate <= 1.2, "%s walk/run transition never accelerates the gait beyond 1.2x" % hero.data.id)
		var space := (hero.visual.tree.tree_root as AnimationNodeBlendTree).get_node("Loco") as AnimationNodeBlendSpace1D
		t.check(space.sync_mode == AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_MUTABLE, "walk/run foot cycles stay phase synchronized")
	var frame := InputFrame.new()
	frame.has_aim = true
	frame.aim_point = nathan.global_position + Vector3.FORWARD * 6
	var throw_skill: Skill = nathan.skills[1]
	t.check(throw_skill.try_cast(frame), "Nathan starts bag preparation")
	t.check(throw_skill.active and host.objects.is_empty(), "preparation cannot launch an early packet")
	t.steps(host, RB.ticks(throw_skill.v("ubo_prepare_time")) - 1)
	t.check(host.objects.is_empty(), "packet remains held until the release tick")
	t.steps(host, 1)
	t.check(not throw_skill.active and host.objects.size() == 1 and host.objects[0] is UboPacket, "packet releases on the authoritative preparation boundary")
	host.clear_objects()
	throw_skill.cd_ticks = 0
	t.steps(host, nathan.cast_lock_ticks)
	throw_skill.try_cast(frame)
	t.steps(host, 5)
	nathan.on_tagged(nene)
	t.steps(host, 20)
	t.check(not throw_skill.active and host.objects.is_empty(), "tagging during preparation cancels the pending throw")
	t.inputs(host).move(nene, Vector2.RIGHT)
	nene.skills[1].try_cast(frame)
	var at := nene.global_position
	t.steps(host, 8)
	t.check(nene.cast_lock_ticks == 0 and RB.flat_dist(at, nene.global_position) > 0.1 and nene.is_warded(), "BAWAL preserves voluntary movement while protected")
	frame.aim_point = inday.global_position + Vector3.RIGHT * 12
	inday.skills[0].try_cast(frame)
	var lane = inday.skills[0].last_lane
	var start := inday.global_position
	t.inputs(host).move(inday, Vector2.DOWN)
	t.check(t.near(lane.formed_fraction(), 0.0) and not lane.contains(start + Vector3.RIGHT), "unformed lane has no invisible gameplay area")
	t.steps(host, 30)
	t.check(t.near(lane.formed_fraction(), 0.5) and lane.contains(start + Vector3.RIGHT * 5) and not lane.contains(start + Vector3.RIGHT * 7), "half-formed wind affects only its first six metres")
	t.check(RB.flat_dist(start, inday.global_position) < 0.01 and not inday.can_move(), "Inday stays planted during formation")
	t.steps(host, 30)
	t.check(t.near(lane.formed_fraction(), 1.0) and inday.cast_lock_ticks == 0, "formation and movement lock end together at one second")
	t.check(lane.ticks_left == RB.ticks(4.0), "formation consumes the first second of the five-second lifetime")
	await t.free_match(host)
	t.ok("host-timed throws, moving ward, forming wind and bounded gait cadence")

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
	visual._on_skel_updated() # refresh world-space anchors after manual-step teleport
	towel._update_cloth(0.0, true)
	var palm := visual.bone_world_transform("RightHand") * Vector3(h.data.v("towel_grip_offset"))
	t.check(towel.points[0].distance_to(palm) < 0.001, "rolled towel is fixed inside the rendered palm")
	for i in range(90):
		towel._update_cloth(1.0 / 60.0)
	var clear := true
	for point in towel.points.slice(1):
		clear = clear and point.distance_to(towel.body_project(point)) < 0.005
	t.check(clear, "rolled towel strand remains outside torso collision capsule")
	t.check(towel.points[0].distance_to(towel.points[-1]) < 0.85, "held towel remains bounded to the grip (%.3f m, hand %s, tip %s)" % [towel.points[0].distance_to(towel.points[-1]), towel.points[0], towel.points[-1]])
	var tips: Array[Vector3] = []
	for hz in [30, 60, 120]:
		towel._update_cloth(0.0, true)
		towel._solver_remainder = 0.0
		for i in range(hz):towel._process(1.0 / hz)
		tips.append(towel.points[-1])
		t.check(towel.points[-1].y < towel.points[0].y - 0.15, "relaxed towel hangs below the palm at %d render fps" % hz)
	t.check(tips[0].distance_to(tips[1]) < 0.005 and tips[1].distance_to(tips[2]) < 0.005, "fixed towel substeps produce the same settled shape at 30/60/120 fps")
	t.check(visual.has_clip("Tamaraw_Miss"), "JM exports a dedicated full-body miss recovery")
	# Actual HUD press route, like HARUROT!: hold to see the cancel target, release to charge.
	var input := PlayerInput.new()
	host.add_child(input)
	var hud := Hud.new()
	host.add_child(hud)
	hud.input_source = input
	hud.setup(host, h, null)
	hud.touch.force_touch_controls = true
	hud.touch.visible = true
	var to_screen := hud.touch.get_global_transform_with_canvas()
	var press := InputEventScreenTouch.new()
	press.index = 82
	press.pressed = true
	press.position = to_screen * hud.touch.action_centres()[RB.BTN_SKILL2]
	hud.touch._input(press)
	var frame := input.frame_for(h, host)
	t.check(input.touch_skill_button == RB.BTN_SKILL2 and (frame.pressed & RB.BTN_SKILL2) == 0, "holding Tamaraw opens the cancel gesture without casting yet")
	press.pressed = false
	hud.touch._input(press)
	frame = input.frame_for(h, host)
	t.check(frame.was_pressed(RB.BTN_SKILL2) and input.touch_skill_button == 0, "releasing Tamaraw casts it, like HARUROT")
	h.aim = Vector3.RIGHT
	t.check(h.skills[1].try_cast(frame), "the released gesture starts Tamaraw")
	h.skills[1].end("recast")
	t.check(h.cast_lock_ticks == RB.ticks(float(h.data.values.tamaraw_recovery)) and visual.tamaraw_miss_active() and h.is_taggable() and not h.is_stunned(), "empty charge uses existing half-second recovery, with no additional stun or protection")
	t.steps(host, h.cast_lock_ticks)
	t.check(not visual.tamaraw_miss_active() and h.can_move(), "dizzy pose ends on the authoritative recovery boundary")
	# dragging to the cancel target drops the cast instead of charging
	h.skills[1].cd_ticks = 0
	press.pressed = true
	press.position = to_screen * hud.touch.action_centres()[RB.BTN_SKILL2]
	hud.touch._input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 82
	drag.position = to_screen * hud.touch.cancel_centre()
	drag.relative = drag.position - press.position
	hud.touch._input(drag)
	press.pressed = false
	press.position = drag.position
	hud.touch._input(press)
	t.check(input.frame_for(h, host).pressed == 0 and input.touch_skill_button == 0, "dragging to CANCEL drops the Tamaraw cast with no charge and no cooldown")
	h.skills[1].cd_ticks = 0
	h.skills[1].try_cast(frame)
	enemy.teleport(h.global_position + Vector3.RIGHT * 0.2)
	h.skills[1]._shove_touched()
	h.skills[1].end("recast")
	t.check(not visual.tamaraw_miss_active(), "a charge that contacts an enemy never plays missed-charge dizziness")
	await t.free_match(host)
	t.ok("JM shoulder cloth, stepped poses and hold-to-cancel charge")

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
			if skill.cast_plant_seconds() <= 0.0:
				t.check(h.cast_lock_ticks == 0, "moving casts retain locomotion without a generic plant")
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


func _skill_assistance(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "nathan", "team": RB.DILAW}, {"hero_id": "nene", "team": RB.LILA}, {"hero_id": "tutoy", "team": RB.LILA}, {"hero_id": "inday", "team": RB.DILAW}])
	t.go_live(host)
	var n: Hero = host.heroes[0]
	var first: Hero = host.heroes[1]
	var second: Hero = host.heroes[2]
	var inday: Hero = host.heroes[3]
	TestCtx.put(n, 0, -5)
	TestCtx.put(first, 4, -4.6)
	TestCtx.put(second, 3, -3.7)
	TestCtx.put(inday, -10, -9)
	# Skills never nudge the aim, even with an enemy sitting right next to it.
	var input := PlayerInput.new()
	host.get_parent().add_child(input)
	input.touch_active = true
	input.begin_touch_skill(RB.BTN_SKILL1)
	input.touch_skill_direction = Vector2.RIGHT
	var preview := input.skill_preview_frame(n)
	input.finish_touch_skill()
	var release := input.frame_for(n, host)
	var to_first := RB.flat(first.global_position - n.global_position).normalized()
	t.check(rad_to_deg(release.aim_dir.angle_to(Vector2.RIGHT)) < 0.001, "a skill cast keeps the exact aim the player gave")
	t.check(rad_to_deg(release.aim_dir.angle_to(Vector2(to_first.x, to_first.z))) > 1.0, "no skill pulls the aim toward a nearby enemy")
	t.check(t.near(preview.aim_dir.angle_to(release.aim_dir), 0.0, 0.0001), "the skill-pad preview and the release cast the same direction")
	var view := MatchView.new()
	host.get_parent().add_child(view)
	view.setup(host, n, null)
	var preview_view := SkillAimView.new()
	host.get_parent().add_child(preview_view)
	preview_view.setup(host, n)
	preview_view.show_info(n.skills[0], n.skills[0].aim_preview(release), n.global_position)
	t.check(preview_view.find_children("SelectedSkillTarget", "Node3D", true, false).is_empty(), "the preview never marks an enemy")
	t.check(preview_view.find_children("*", "Label3D", true, false).is_empty(), "the preview shows no skill or range text")
	t.check(preview_view.get_child_count() > 3, "the preview still draws the inked shape")
	var committed: InputFrame = release
	t.check(n.skills[0].try_cast(committed), "BUGA commits the given direction")
	var origin := n.global_position
	var direction: Vector3 = n.skills[0].committed_aim.direction
	t.inputs(host).move(n, Vector2.DOWN)
	t.inputs(host).aim_at(n, n.global_position + Vector3.BACK * 8)
	t.steps(host, RB.ticks(0.5))
	view._refresh_skill_tells()
	# Flat distance: the body still settles the last few centimetres onto the floor while planted.
	t.check(RB.flat_dist(n.global_position, origin) < 0.01 and n.facing.dot(direction) > 0.99 and n.skills[0].active, "Nathan stays planted and facing his committed cone through the visible spit")
	t.check(not view._skill_tells.is_empty(), "a committed cone remains public after the inhale")
	var public_view: SkillAimView = view._skill_tells.values()[0]
	t.check(public_view.find_children("*", "Label3D", true, false).is_empty(), "public tells carry no text either")
	t.steps(host, RB.ticks(0.25) + 1)
	view._refresh_skill_tells()
	t.check(n.cast_lock_ticks == 0 and not n.skills[0].active and view._skill_tells.is_empty(), "movement, facing lock and public tell end together at 0.75 seconds")
	await t.free_match(host)
	# TAMARAW!!! is steered by the movement stick and facing, never by an aim point.
	var jm_host := t.make_match([{"hero_id": "jm", "team": RB.DILAW}, {"hero_id": "tutoy", "team": RB.LILA}])
	t.go_live(jm_host)
	var jm: Hero = jm_host.heroes[0]
	var prey: Hero = jm_host.heroes[1]
	var jm_in := t.inputs(jm_host)
	TestCtx.put(jm, 0, -5)
	TestCtx.put(prey, 9, 4)
	jm.set_frame(jm_in.frame_for(jm, jm_host))
	t.check(jm.skills[1].aim_from_movement(), "TAMARAW is a movement-steered charge, not an aimed skill")
	jm_in.move(jm, Vector2.RIGHT)
	jm_in.aim_at(jm, Vector3(0, 0, 20)) # aim is deliberately sideways and must be ignored
	jm.set_frame(jm_in.frame_for(jm, jm_host))
	t.check(jm.skills[1].try_cast(jm.frame) and jm.skills[1].charge_heading().dot(Vector3.RIGHT) > 0.99, "TAMARAW charges where the stick points, ignoring the aim point")
	jm.skills[1].end("reset")
	jm.cast_lock_ticks = 0
	jm_in.move(jm, Vector2.ZERO)
	jm.facing = Vector3(0, 0, -1)
	jm.set_frame(jm_in.frame_for(jm, jm_host))
	t.check(jm.skills[1].charge_heading().dot(Vector3.FORWARD) > 0.99, "with a centred stick TAMARAW uses where JM faces")
	await t.free_match(jm_host)
	t.ok("no skill aim assist, no markers or text, committed powder facing and TAMARAW steering")
