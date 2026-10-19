extends RefCounted

## Match HUD: builds on a test match, timer/score follow the host, tag feed shows a tag,
## scoreboard toggles, F10 hide, pause overlay.

func run(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "tutoy", "team": RB.DILAW}, {"hero_id": "nene", "team": RB.LILA}])
	var local: Hero = host.heroes[0]
	var view := MatchView.new()
	host.get_parent().add_child(view)
	view.setup(host, local, null)
	var hud := Hud.new()
	host.get_parent().add_child(hud)
	hud.setup(host, local, view)
	await t.frames(2)
	t.check(hud.timer != null and hud.feed != null and hud.scoreboard != null and hud.minimap != null and hud.tracker != null, "HUD parts exist")
	t.go_live(host)
	t.steps(host, 60)
	await t.frames(2)
	t.check(hud.timer_label.text.begins_with("1:5"), "timer counts down from 2:00 (got '%s')" % hud.timer_label.text)
	# a tag shows in the feed
	var foe: Hero = host.heroes[1]
	TestCtx.put(local, 0, 0)
	TestCtx.put(foe, 1.2, 0)
	t.inputs(host).aim_at(local, Vector3(5, 0, 0))
	t.steps(host, 1)
	t.inputs(host).press(local, RB.BTN_TAG)
	t.steps(host, RB.ticks(host.tuning.tag_windup) + 2) # v0.2: the slower hampas windup
	await t.frames(2)
	t.check(foe.state == Hero.State.TAGGED, "the tag landed")
	var feed_text := "\n".join(hud.feed.texts())
	t.check("HINULI" in feed_text, "tag feed shows '[Tagger] HINULI si [Target]' (got '%s')" % feed_text)
	hud.force_scoreboard = true
	await t.frames(2)
	t.check(hud.scoreboard.held and hud.scoreboard.visible, "scoreboard shows while held")
	hud.force_scoreboard = false
	await t.frames(2)
	t.check(not hud.scoreboard.held, "scoreboard hides on release")
	hud.toggle_hidden()
	t.check(hud.is_hidden(), "F10 hides the HUD")
	hud.toggle_hidden()
	hud.set_pause_open(true)
	t.check(hud.is_pause_open(), "pause overlay opens")
	hud.set_pause_open(false)
	t.ok("HUD: timer, tag feed, scoreboard, hide, pause")
	_announcer(t, host, hud)
	await t.free_match(host)
	await _intro(t)
	await _aim_strip(t)
	await _layered_actions(t)
	await _touch_controls(t)
	await _fair_touch_aim(t)
	await _tag_aim_selection(t)
	await _skill_previews(t)
	_camera_zoom(t)

## Round-1 intro (2026-10-17): the overlay names the map, each team and the faceoff, offers the
## skip to a lone human, and MatchView drives the camera's flyover pose and releases it after.
func _intro(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "tutoy", "team": RB.DILAW}, {"hero_id": "nene", "team": RB.LILA, "is_bot": true}], {"skip_intro": false})
	var local: Hero = host.heroes[0]
	var cam := MatchCamera.new()
	host.get_parent().add_child(cam)
	var view := MatchView.new()
	host.get_parent().add_child(view)
	view.setup(host, local, cam)
	var hud := Hud.new()
	host.get_parent().add_child(hud)
	hud.setup(host, local, view)
	t.steps(host, 30) # the flyover blends in over the first 0.4 s
	await t.frames(2)
	var ui := hud.intro_ui
	t.check(ui != null and ui.active and ui.stage == RoundFlow.IntroStage.ARENA and ui.title_text == "BARANGAY COURT", "intro overlay opens on the map title (got '%s')" % ui.title_text)
	t.check(ui.skip_text.contains("Laktawan"), "a lone human sees the skip prompt (got '%s')" % ui.skip_text)
	t.check(cam.intro_w > 0.0, "the camera is blended toward the flyover pose (w %.2f)" % cam.intro_w)
	t.steps(host, RB.ticks(host.tuning.intro_arena + 0.2) - 30)
	await t.frames(2)
	t.check(ui.stage == RoundFlow.IntroStage.TEAM_A and ui.title_text == RB.TEAM_FULL_NAMES[RB.DILAW].to_upper() and ui.sub_text.contains(local.display_name), "then our team's banner (got '%s' / '%s')" % [ui.title_text, ui.sub_text])
	t.steps(host, RB.ticks(host.tuning.intro_team))
	await t.frames(2)
	t.check(ui.stage == RoundFlow.IntroStage.TEAM_B and ui.title_text == RB.TEAM_FULL_NAMES[RB.LILA].to_upper(), "then the enemy team's banner (got '%s')" % ui.title_text)
	t.steps(host, host.round_flow.phase_ticks + 1)
	await t.frames(2)
	t.check(not ui.active and cam.intro_w == 0.0 and host.round_flow.phase == RoundFlow.Phase.COUNTDOWN, "the overlay and the flyover end with the intro")
	t.ok("HUD: round-1 intro overlay and camera flyover")
	await t.free_match(host)

## Preview matches the host's normal reach, arc, eligibility and locked swing direction.
func _aim_strip(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "tutoy", "team": RB.DILAW}, {"hero_id": "nene", "team": RB.LILA}])
	var local: Hero = host.heroes[0]
	var foe: Hero = host.heroes[1]
	var view := MatchView.new()
	host.get_parent().add_child(view)
	view.setup(host, local, null)
	view._update_aim()
	t.check(not view.aim_marker.visible and view.aim_strip_alpha == 0.0, "no strip before live play")
	t.go_live(host)
	TestCtx.put(local, 0, 0)
	TestCtx.put(foe, 1.6, 0)
	t.inputs(host).aim_at(local, Vector3(5, 0, 0))
	t.steps(host, 1)
	view._update_aim()
	t.check(not view.aim_marker.visible and view.preview_target == null, "nearby enemies never expose an idle attack guide or selection highlight")
	var source := PlayerInput.new()
	host.get_parent().add_child(source)
	host.input_sources[local.slot] = source
	source.begin_tag_aim()
	source.touch_target = foe
	view._update_aim()
	var arc := view.aim_marker.get_node_or_null("TagStrip") as MeshInstance3D
	t.check(arc != null and view.aim_marker.get_node_or_null("AimArrow") == null, "a filled straight strip replaces the arc and arrow")
	var reach := local.tag_reach() + host.tuning.body_radius * 2.0
	t.check(t.near(arc.mesh.get_aabb().end.z, reach, 0.02), "strip length equals the host centre-distance reach")
	t.check(t.near(arc.mesh.get_aabb().end.x, host.tuning.tag_strip_half_width, 0.02), "strip width matches the narrow host sweep")
	t.check(is_zero_approx(arc.mesh.get_aabb().position.z) and view.aim_marker.get_child_count() == 2, "filled straight strip has a separate outline")
	t.check(view.preview_target == foe, "enemy inside the tag area is highlighted as the preview target")
	foe.ep_ticks = 10
	view._update_aim()
	t.check(view.preview_target == null, "protection removes the ready-to-tag highlight")
	foe.ep_ticks = 0
	TestCtx.put(foe, -1.6, 0)
	source.touch_target = null
	view._update_aim()
	t.check(view.preview_target == null, "enemies behind the tag direction are not highlighted")
	var fill := arc.material_override as StandardMaterial3D
	var border := view.aim_marker.get_node("TagOutline") as MeshInstance3D
	t.check(fill.albedo_color.r > 0.8 and fill.albedo_color.g < 0.2 and fill.albedo_color.a <= 0.2, "attack strip is red with a faint transparent fill")
	t.check((border.material_override as StandardMaterial3D).albedo_color.a > 0.8, "red outline remains readable around the faint fill")
	host.input_sources[local.slot] = t.inputs(host)
	source.finish_tag_aim(true)
	var idle_alpha := view.aim_strip_alpha
	t.inputs(host).hold(local, RB.BTN_TAG)
	t.steps(host, 1)
	var locked := local.lunge_dir
	t.inputs(host).aim_at(local, Vector3(0, 0, -5))
	t.steps(host, 1)
	view._update_aim()
	t.check(t.near(view.aim_marker.rotation.y, atan2(locked.x, locked.z)), "the strip stays on the committed swing direction")
	t.check(view.aim_strip_alpha > idle_alpha, "the strip brightens during the committed swing")
	t.check(t.near(arc.mesh.get_aabb().end.z, reach), "holding never grows the strip")
	local.windup_end_tick = -1
	TestCtx.put(foe, 12, 0)
	view._update_aim()
	t.check(not view.aim_marker.visible, "ordinary travel with no nearby enemy hides the strip")
	local.on_tagged(foe)
	view._update_aim()
	t.check(not view.aim_marker.visible, "the strip hides when caught")
	t.ok("private tag strip: actual reach/body sweep, eligibility, locked direction and swing feedback")
	await t.free_match(host)

## v0.2 MOBA-style announcer: the real tag above was the round's first; then synthetic host
## events drive streaks, multi-tags, the shutdown, rescue, capture and lockdown calls.
func _announcer(t: TestCtx, host: MatchHost, hud: Hud) -> void:
	var ann := hud.announcer
	t.check(ann != null and ann.history.size() >= 1 and ann.history[0] == "first_tag", "the round's first tag calls UNANG HULI! (%s)" % str(ann.history))
	var a: Hero = host.heroes[0]
	var b: Hero = host.heroes[1]
	ann.on_event("countdown", {"round": 2, "seconds": 3.0})
	ann.history.clear()
	ann.queue.clear()
	ann.current = {}
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history == PackedStringArray(["first_tag"]), "streaks reset each round; the new round's first tag calls UNANG HULI! again")
	t.check(not ann.current.is_empty() and ann.current.title == "UNANG HULI!", "the banner shows the call")
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history[-1] == "double", "a second tag inside the window calls DOBLENG HULI!")
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history.has("triple") and ann.history[-1] == "hot", "a third calls TRIPLENG HULI! then MAINIT! (%s)" % str(ann.history))
	t.check(ann.queue.size() <= host.tuning.announce_queue_max, "the queue is capped at %d" % host.tuning.announce_queue_max)
	host.tick += RB.ticks(host.tuning.announce_multi_window) + 1
	var before := ann.history.size()
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history.size() == before, "a 4th tag after the window chains no multi and is no streak step")
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history[-1] == "beast", "5 in a row calls HALIMAW!")
	ann.on_event("tag", {"tagger": a, "target": b})
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history[-1] == "unstoppable", "7 in a row calls DI MAPIGILAN!")
	ann.on_event("tag", {"tagger": b, "target": a})
	t.check(ann.history.has("shutdown"), "catching a player on a streak calls PINAHINTO!")
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history[-1] != "hot" and ann.history[-1] != "beast", "being caught resets the streak")
	ann.on_event("rescue", {"rescuer": b, "freed": [a], "by_skill": false})
	t.check(ann.history[-1] == "rescue", "a rescue calls RESBAK!")
	ann.on_event("capture", {"hero": a, "team": a.team})
	t.check(ann.history[-1] == "capture", "a capture calls NAAGAW ANG BASE!")
	ann.on_event("round_end", {"reason": "lockdown", "winner": a.team})
	t.check(ann.history[-1] == "ace", "a lockdown win calls LAHAT HULI!")
	before = ann.history.size()
	ann.on_event("round_end", {"reason": "capture", "winner": a.team})
	t.check(ann.history.size() == before, "other round ends make no LAHAT HULI!")
	# the banner plays each call for announce_banner_time, one at a time
	var shown: String = ann.current.id
	ann.refresh(host.tuning.announce_banner_time + 0.01)
	t.check(ann.current.is_empty() or ann.current.id != shown or ann.queue.is_empty(), "the banner moves on after %.1f s" % host.tuning.announce_banner_time)
	for i in range(10):
		ann.refresh(host.tuning.announce_banner_time + 0.01)
	t.check(ann.current.is_empty() and ann.queue.is_empty(), "the queue drains")
	t.ok("announcer: UNANG HULI!, DOBLENG/TRIPLENG, MAINIT!/HALIMAW!/DI MAPIGILAN!, PINAHINTO!, RESBAK!, NAAGAW ANG BASE!, LAHAT HULI!")

## Zoom is fixed while the camera still follows, leads, swivels and flips.
func _camera_zoom(t: TestCtx) -> void:
	var world := Node3D.new()
	t.tree.root.add_child(world)
	var target := Node3D.new()
	world.add_child(target)
	var cam := MatchCamera.new()
	cam.target = target
	world.add_child(cam)
	cam.set_process(false)
	cam.snap()
	t.check(t.near(cam.size, 8.0), "camera starts at the closest fixed zoom")
	for button in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = button
		wheel.pressed = true
		cam._unhandled_input(wheel)
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 2.0
	cam._unhandled_input(pinch)
	pinch.factor = 0.5
	cam._unhandled_input(pinch)
	var before := cam.global_position
	var before_yaw := cam.view_yaw()
	target.position = Vector3(1, 2, 1)
	cam._process(0.1)
	t.check(t.near(cam.size, 8.0), "wheel, pinch, running and elevation keep the same zoom")
	t.check(cam.global_position.distance_to(before) > 0.01, "fixed zoom retains dynamic follow")
	t.check(absf(cam.view_yaw() - before_yaw) > 0.0001, "fixed zoom retains lateral swivel")
	cam.flip()
	cam._process(MatchCamera.FLIP_DURATION)
	t.check(not cam.is_flipping() and t.near(cam.size, 8.0), "camera flip completes without changing zoom")
	cam.intro_w = 1.0
	cam.intro_size = 14.0
	cam._process(0.1)
	t.check(t.near(cam.size, 14.0), "scripted intro flyover framing is preserved")
	cam.intro_w = 0.0
	cam._process(0.1)
	t.check(t.near(cam.size, 8.0), "intro returns to the fixed gameplay zoom")
	world.free()

## Two fingers can move and tap independently; release/holding never adds TAG edges.
func _touch_controls(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "tutoy", "team": RB.DILAW}, {"hero_id": "nene", "team": RB.LILA}])
	t.go_live(host)
	var local: Hero = host.heroes[0]
	var provider := PlayerInput.new()
	host.get_parent().add_child(provider)
	var hud := Hud.new()
	host.get_parent().add_child(hud)
	hud.setup(host, local, null)
	hud.input_source = provider
	var touch = hud.touch
	t.check(touch.wanted(), "on-screen mobile controls are available by default on desktop too")
	touch.force_touch_controls = true
	touch.refresh(0.0)
	var send := func(index: int, pressed: bool, point: Vector2) -> void:
		var event := InputEventScreenTouch.new()
		event.index = index
		event.pressed = pressed
		event.position = touch.get_global_transform_with_canvas() * point
		touch._input(event)
	var stick: Vector2 = touch.stick_centre()
	var tag_at: Vector2 = touch.action_centres()[RB.BTN_TAG]
	send.call(0, true, stick + Vector2(90, 0))
	send.call(1, true, tag_at)
	var frame := provider.frame_for(local, host)
	t.check(frame.move.x > 0.5 and provider.tag_aiming and not frame.was_pressed(RB.BTN_TAG), "two fingers can move and preview TAG independently")
	t.check(not frame.is_held(RB.BTN_TAG) and frame.from_gamepad, "touch tag is an edge with directional assistance, never a hold")
	frame = provider.frame_for(local, host)
	t.check(not frame.was_pressed(RB.BTN_TAG) and frame.move.x > 0.5, "holding TAG does not repeat and movement continues")
	send.call(1, false, tag_at)
	frame = provider.frame_for(local, host)
	t.check(frame.was_pressed(RB.BTN_TAG), "lifting the TAG finger commits one swing")
	# Direction persists when the move finger is released.
	local.aim = Vector3.RIGHT
	send.call(0, false, stick)
	frame = provider.frame_for(local, host)
	t.check(frame.move == Vector2.ZERO and frame.aim_dir == Vector2.RIGHT, "release stops touch movement and preserves the last aim")
	send.call(1, true, tag_at)
	provider.enabled = false
	frame = provider.frame_for(local, host)
	provider.enabled = true
	t.check(frame.pressed == 0 and provider.frame_for(local, host).pressed == 0, "pause clears queued touch presses")
	touch.reset_touches()
	var use_at: Vector2 = touch.action_centres()[RB.BTN_INTERACT]
	send.call(2, true, use_at)
	frame = provider.frame_for(local, host)
	t.check(frame.was_pressed(RB.BTN_INTERACT) and frame.is_held(RB.BTN_INTERACT), "touch BASE supports hold-to-capture")
	send.call(2, false, use_at)
	t.check(not provider.frame_for(local, host).is_held(RB.BTN_INTERACT), "releasing BASE stops capture input")
	touch.reset_touches()
	var skill_at: Vector2 = touch.action_centres()[RB.BTN_SKILL1]
	send.call(0, true, stick + Vector2(90, 0))
	send.call(3, true, skill_at)
	frame = provider.frame_for(local, host)
	t.check(not frame.was_pressed(RB.BTN_SKILL1) and provider.touch_skill_button == RB.BTN_SKILL1, "skill button holds an aim preview without casting")
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = touch.get_global_transform_with_canvas() * (skill_at + Vector2(0, 100))
	touch._input(drag)
	send.call(3, false, skill_at + Vector2(0, 100))
	frame = provider.frame_for(local, host)
	t.check(frame.was_pressed(RB.BTN_SKILL1) and frame.aim_dir.y > 0.9 and frame.move.x > 0.5, "releasing a dragged skill button sends its aimed direction once")
	t.check(not provider.frame_for(local, host).was_pressed(RB.BTN_SKILL1), "skill release does not repeat")
	send.call(3, true, skill_at)
	drag.position = touch.get_global_transform_with_canvas() * touch.cancel_centre()
	touch._input(drag)
	send.call(3, false, touch.cancel_centre())
	t.check(not provider.frame_for(local, host).was_pressed(RB.BTN_SKILL1), "releasing on the explicit cancel target cancels the cast")
	send.call(3, true, skill_at)
	drag.position = touch.get_global_transform_with_canvas() * touch.cancel_centre()
	touch._input(drag)
	t.check(provider.touch_skill_cancelled, "cancel target visibly arms cancellation")
	drag.position = touch.get_global_transform_with_canvas() * (skill_at + Vector2(-500, 0))
	touch._input(drag)
	t.check(not provider.touch_skill_cancelled and provider.touch_skill_fraction == 1.0, "moving away restores aim and long drags clamp to maximum range")
	send.call(3, false, skill_at + Vector2(-500, 0))
	t.check(provider.frame_for(local, host).was_pressed(RB.BTN_SKILL1), "rushed far drag releases a skill instead of cancelling")
	send.call(3, true, skill_at)
	send.call(3, false, touch.cancel_centre())
	t.check(not provider.frame_for(local, host).was_pressed(RB.BTN_SKILL1), "release position alone can cancel without a final drag event")
	local.skills[0].cd_ticks = 100
	send.call(3, true, skill_at)
	send.call(3, false, skill_at)
	t.check(not provider.frame_for(local, host).was_pressed(RB.BTN_SKILL1), "cooldown skill buttons cannot queue a cast")
	local.skills[0].cd_ticks = 0
	send.call(0, false, stick)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = touch.get_global_transform_with_canvas() * tag_at
	mouse.pressed = true
	touch._input(mouse)
	t.check(provider.ui_pointer_captured and provider.tag_aiming, "mouse can hold the visible attack pad for desktop testing")
	Input.action_press("move_right")
	frame = provider.frame_for(local, host)
	t.check(frame.move.x > 0.5 and not frame.was_pressed(RB.BTN_TAG), "WASD movement stays available while mouse holds an on-screen aim pad")
	Input.action_release("move_right")

	var motion := InputEventMouseMotion.new()
	motion.position = mouse.position + Vector2(-70, -40)
	motion.relative = Vector2(-70, -40)
	provider._input(motion)
	touch._input(motion)
	t.check(provider.tag_aiming, "dragging an on-screen mouse pad does not switch to world-click aim")
	mouse.pressed = false
	touch._input(mouse)
	frame = provider.frame_for(local, host)
	t.check(frame.was_pressed(RB.BTN_TAG) and not provider.ui_pointer_captured, "mouse release of the attack pad emits one tag and releases pointer capture")
	t.check(not provider.frame_for(local, host).was_pressed(RB.BTN_TAG), "on-screen mouse tag never duplicates through the world binding")
	mouse.position = touch.get_global_transform_with_canvas() * (stick + Vector2(80, 0))
	mouse.pressed = true
	touch._input(mouse)
	t.check(provider.frame_for(local, host).move.x > 0.5, "mouse can drag the movement joystick")
	mouse.pressed = false
	touch._input(mouse)
	frame = provider.frame_for(local, host)
	t.check(frame.move == Vector2.ZERO and not frame.was_pressed(RB.BTN_TAG), "releasing the movement joystick stops without attacking")
	var pause_calls := [0]
	hud.pause_requested.connect(func(): pause_calls[0] += 1)
	touch.menu_button.pressed.emit()
	t.check(pause_calls[0] == 1, "mobile menu button exposes pause without a keyboard")
	touch.reset_touches()
	t.ok("touch controls: multitouch movement, tap TAG, retained aim, pause cleanup, capture")
	await t.free_match(host)

## Touch can back away while aiming; the lock is visible, bounded, and never tracks hidden foes.
func _fair_touch_aim(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "tutoy", "team": RB.DILAW}, {"hero_id": "nathan", "team": RB.LILA}, {"hero_id": "nene", "team": RB.LILA}])
	t.go_live(host)
	var local: Hero = host.heroes[0]
	var foe: Hero = host.heroes[1]
	var other: Hero = host.heroes[2]
	TestCtx.put(local, 0, 0)
	TestCtx.put(foe, 1.6, 0)
	TestCtx.put(other, 1.65, 0.4)
	var camera := MatchCamera.new()
	camera.target = local
	host.get_parent().add_child(camera)
	camera.set_process(false)
	camera.snap()
	var provider := PlayerInput.new()
	provider.camera = camera
	host.get_parent().add_child(provider)
	provider.set_touch_move(Vector2.RIGHT)
	# No camera yaw in this first input check: right means world +X.
	provider.camera = null
	var frame := provider.frame_for(local, host)
	local.set_frame(frame)
	t.check(provider.touch_target == foe, "touch acquires the nearest visible enemy in the aim cone")
	provider.set_touch_move(Vector2.LEFT)
	frame = provider.frame_for(local, host)
	t.check(frame.move.x < 0.0 and frame.tag_aim_dir.x > 0.0 and frame.aim_dir.x < 0.0, "touch can retreat while tag aim stays on target and skill aim follows the stick")
	t.check(frame.pressed == 0 and frame.tag_aim_dir != Vector2.ZERO, "target lock never attacks or applies a second aim correction")
	t.check(frame.duplicate_frame().tag_aim_dir == frame.tag_aim_dir, "InputFrame copies preserve exact selected-target aim")
	provider.camera = camera
	var screen := camera.unproject_position(other.global_position + Vector3.UP * other.data.model_height * 0.5)
	t.check(provider.select_touch_target(local, host, screen) and provider.touch_target == other, "tapping another visible opponent switches the target")
	t.check(provider.frame_for(local, host).pressed == 0, "selecting a target does not fire TAG")
	var view := MatchView.new()
	host.get_parent().add_child(view)
	view.setup(host, local, camera)
	provider.begin_tag_aim()
	host.input_sources[local.slot] = provider
	view._process(0.0)
	t.check(not other.visual.ring.visible and other.visual.nametag.modulate == Color("ffe59a"), "selected target uses its overhead nametag without a ground ring")
	other.enemy_alpha = 0.0
	TestCtx.put(foe, 10, 0)
	provider.frame_for(local, host)
	view._process(0.0)
	t.check(provider.touch_target == null and not other.visual.nametag.visible, "a hidden opponent immediately loses both lock and marker")
	other.enemy_alpha = 1.0
	provider.touch_target = other
	other.ep_ticks = 100
	provider.frame_for(local, host)
	t.check(provider.touch_target == null, "escape protection releases the aim lock")
	other.ep_ticks = 0
	provider.touch_target = other
	TestCtx.put(other, host.tuning.touch_target_release_range + 0.2, 0)
	provider.frame_for(local, host)
	t.check(provider.touch_target == null, "the lock releases beyond the retention range")
	TestCtx.put(other, 1.6, 0)
	provider.touch_target = other
	host.settings["tag_assist"] = false
	provider.frame_for(local, host)
	t.check(provider.touch_target == null, "disabling tag assist disables touch target locking")
	host.settings["tag_assist"] = true
	# A lock through a solid wall must drop, even when the opponent is still visible.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2, 3)
	shape.shape = box
	wall.add_child(shape)
	host.get_parent().add_child(wall)
	wall.global_position = Vector3(0.8, 0.5, 0)
	await t.physics_frames(2)
	provider.touch_target = other
	provider.frame_for(local, host)
	t.check(provider.touch_target == null, "solid walls release the touch lock")
	wall.free()
	await t.physics_frames(2)
	# Enemy range is private; their model animation remains readable and direction stays committed.
	t.inputs(host).aim_at(other, local.global_position)
	t.inputs(host).press(other, RB.BTN_TAG)
	t.steps(host, 1)
	var direction := other.lunge_dir
	t.check(other.visual.tag_pose_active(), "opponents still show a committed tag animation")
	t.inputs(host).aim_at(other, Vector3(10, 0, 10))
	t.steps(host, 1)
	t.check(other.lunge_dir.is_equal_approx(direction), "opponents cannot turn their swing after the press")
	t.check(view.find_children("TagWindup_*", "Node3D", true, false).is_empty(), "no enemy or teammate attack-range markers are exposed")
	var width := float(local.visual.outline_mat.get_shader_parameter("outline_pixels"))
	t.check(t.near(width, host.tuning.character_outline_pixels) and width <= 1.5, "characters use the thin tuned outline")
	t.ok("fair touch aim: retreat, switch, visibility/range/wall bounds, private ranges, thin outline")
	await t.free_match(host)

## Upper-body actions leave locomotion live, including chained motion and backwards travel.
func _layered_actions(t: TestCtx) -> void:
	var lineup: Array = []
	for id in HeroData.ORDER:
		lineup.append({"hero_id": id, "team": RB.DILAW})
	lineup.append({"hero_id": "nathan", "team": RB.LILA})
	var host := t.make_match(lineup)
	t.go_live(host)
	for hero in host.heroes:
		var visual: HeroVisual = hero.visual
		t.check(not visual.is_upper_action("Tag") and visual.is_upper_action("Chained") and not visual.is_upper_action("Lusot_Slide"), "%s uses a full-body planted Tag and retains moving chain layers" % hero.data.id)
		t.check(visual._upper_paths.size() >= 10 and visual.leg_heading != null, "%s has a skeleton-specific upper-body filter and leg steering" % hero.data.id)
		for path in visual._upper_paths:
			t.check(not "Hips" in String(path) and not "Leg" in String(path) and not "Foot" in String(path), "upper-body filter excludes hip/leg tracks")
		hero.aim = Vector3.RIGHT
		hero.facing = Vector3.RIGHT
		visual.model.rotation.y = PI * 0.5
		hero.velocity = Vector3.LEFT * 2.0
		host.tag_system.start_windup(hero)
		visual._update_animation()
		t.check(is_zero_approx(float(visual.tree.get("parameters/Loco/blend_position"))), "%s suppresses running legs during the planted tag" % hero.data.id)
		visual.tree.advance(0.12)
		var leg := visual._skel.find_bone(visual._bone_by_tail("LeftUpLeg"))
		var before_leg := visual._skel.get_bone_pose_rotation(leg)
		visual.tree.advance(0.17)
		t.check(not ((visual.tree.tree_root as AnimationNodeBlendTree).get_node("ActionLayer") as AnimationNodeBlend2).filter_enabled, "%s uses the authored whole-body hit instead of mixing walking legs" % hero.data.id)
		var before := hero.global_position
		host.tick = hero.tag_started_tick + RB.ticks(host.tuning.tag_windup)
		visual._update_tag_step()
		t.check(t.near(visual.tag_clip_position(), visual.clip_length("Tag") * host.tuning.tag_contact_fraction), "tag contact pose aligns with the host landing tick")
		t.check(hero.global_position == before and visual.model.position == visual._model_origin, "tag has no forward model step or host displacement")
		host.paused = true
		visual._process(0.1)
		t.check(not visual.tree.active, "pause freezes the animation mixer as well as the host tick")
		host.paused = false
		visual._process(0.1)
		t.check(visual.tree.active, "resume restores action and locomotion playback")
		hero.tag_started_tick = -1
		hero.windup_end_tick = -1
		hero.set_state(Hero.State.CHAINED)
		visual._update_animation()
		t.check(visual._desired()[0] == "Chained" and float(visual.tree.get("parameters/Loco/blend_position")) > 0.0, "chain holding pose remains active while the legs walk")
		hero.set_state(Hero.State.FREE)
	t.ok("layered actions: all rigs, filtered upper body, moving chain, backpedal and tick-aligned contact")
	await t.free_match(host)

## Hold is optional selection, not charge. Release emits exactly one normal attack edge.
func _tag_aim_selection(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "nene", "team": RB.DILAW}, {"hero_id": "nathan", "team": RB.LILA}, {"hero_id": "tutoy", "team": RB.LILA}])
	t.go_live(host)
	var hero: Hero = host.heroes[0]
	var nearest: Hero = host.heroes[1]
	var other: Hero = host.heroes[2]
	TestCtx.put(hero, 0, 0)
	TestCtx.put(nearest, 1.3, 0)
	TestCtx.put(other, 0, 1.8)
	var source := PlayerInput.new()
	host.get_parent().add_child(source)
	source.begin_tag_aim()
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(30, 0)
	source._input(motion)
	t.check(source.tag_aiming, "mouse motion preserves a held attack preview")
	var ui := Hud.new()
	host.get_parent().add_child(ui)
	ui.setup(host, hero, null)
	ui.input_source = source
	ui.root.hide()
	ui.touch.refresh(0.0)
	t.check(source.tag_aiming, "hidden touch controls do not cancel desktop aiming")
	source.finish_tag_aim(true)
	source.set_touch_move(Vector2.RIGHT)
	var frame := source.frame_for(hero, host)
	t.check(frame.tag_target_slot == nearest.slot, "plain aim acquires only the nearest eligible in-range opponent")
	TestCtx.put(nearest, -1.3, 0)
	source.begin_tag_aim()
	source.finish_tag_aim()
	frame = source.frame_for(hero, host)
	t.check(frame.was_pressed(RB.BTN_TAG) and frame.tag_target_slot == nearest.slot and frame.tag_aim_dir.x < 0.0, "quick tap auto-aims at the closest nearby opponent even behind movement direction")
	TestCtx.put(nearest, 1.3, 0)

	source.begin_tag_aim()
	source.drag_tag_aim(Vector2(0, 100), host.tuning)
	frame = source.frame_for(hero, host)
	t.check(source.touch_target == other and frame.tag_target_slot == other.slot and frame.pressed == 0, "hold and drag chooses a different opponent without attacking")
	t.check(frame.move.x > 0.0 and frame.aim_dir.x > 0.0 and frame.tag_aim_dir.y > 0.0, "aim selection preserves movement and independent skill direction")
	source.finish_tag_aim()
	frame = source.frame_for(hero, host)
	t.check(frame.was_pressed(RB.BTN_TAG) and frame.tag_target_slot == other.slot, "release commits selected identity exactly once")
	t.check(not source.frame_for(hero, host).was_pressed(RB.BTN_TAG), "holding/releasing never queues a repeat")
	TestCtx.put(nearest, 0, 1.8)
	TestCtx.put(other, 0, 1.6)
	source.begin_tag_aim()
	source.drag_tag_aim(Vector2(0, 100), host.tuning)
	t.check(source.frame_for(hero, host).tag_target_slot == other.slot, "equal manual alignment chooses the nearer body regardless of slot order")
	source.finish_tag_aim(true)
	source.begin_tag_aim()
	source.drag_tag_aim(Vector2(0, host.tuning.tag_aim_cancel_pixels + 10), host.tuning)
	source.finish_tag_aim()
	t.check(source.frame_for(hero, host).was_pressed(RB.BTN_TAG), "long aim drags still release an attack")
	source.begin_tag_aim()
	source.finish_tag_aim(true)
	t.check(not source.frame_for(hero, host).was_pressed(RB.BTN_TAG), "cancelled touch never fires")
	source.begin_tag_aim()
	source.enabled = false
	t.check(not source.tag_aiming, "disabling input discards aim even while the host is not ticking")
	source.frame_for(hero, host)
	source.finish_tag_aim()
	source.enabled = true
	t.check(not source.frame_for(hero, host).was_pressed(RB.BTN_TAG), "pause discards aiming rather than firing on resume")
	TestCtx.put(other, 5, 0)
	source.touch_target = other
	frame = source.frame_for(hero, host)
	t.check(frame.tag_target_slot != other.slot, "selection never retains a target beyond actual tag reach")
	for h in host.heroes:
		h.visual.set_view_alpha(0.25)
		h.visual.set_view_alpha(1.0)
		t.check(not h.visual.ring.visible and h.visual.nametag.visible, "hero identity uses overhead text, never a ground ring")
	await t.free_match(host)

## Every kit has its own intent shape; preview and release share the same selected point.
func _skill_previews(t: TestCtx) -> void:
	var lineup: Array = []
	for id in HeroData.ORDER:
		lineup.append({"hero_id": id, "team": RB.DILAW})
	lineup.append({"hero_id": "nathan", "team": RB.LILA})
	var host := t.make_match(lineup)
	t.go_live(host)
	var icons := {}
	var sources := {}
	var view := MatchView.new()
	host.get_parent().add_child(view)
	view.setup(host, host.heroes[0], null)
	for h in host.heroes:
		TestCtx.put(h, -9 + h.slot, -9)
	for h in host.heroes.slice(0, 5):
		TestCtx.put(h, -5, 0)
		h.aim = Vector3.RIGHT
		var source := PlayerInput.new()
		host.get_parent().add_child(source)
		source.touch_active = true
		sources[h.data.id] = source
		host.input_sources[h.slot] = source
		view.local = h
		view.skill_aim.local = h
		for slot in range(2):
			var skill: Skill = h.skills[slot]
			var button := RB.BTN_SKILL1 if slot == 0 else RB.BTN_SKILL2
			var config := SkillAim.profile(skill)
			icons[config.icon] = true
			t.check(not str(config.hint).is_empty() and not str(config.icon).is_empty(), "%s S%d has its own skill icon and aiming hint" % [h.data.id, slot + 1])
			source.begin_touch_skill(button)
			source.drag_touch_skill(Vector2.RIGHT * host.tuning.skill_aim_pad_radius * 0.5, host.tuning)
			var frame := source.skill_preview_frame(h)
			var before: Vector3 = h.global_position
			var count := host.objects.size()
			var preview := skill.aim_preview(frame)
			t.check(not skill.active and skill.cd_ticks == 0 and host.objects.size() == count and h.global_position == before, "preview never casts, moves, spends cooldown or spawns gameplay objects")
			view.skill_aim.refresh()
			t.check(view.skill_aim.visible and view.skill_aim.info.mode == config.mode, "%s S%d shows the appropriate private preview" % [h.data.id, slot + 1])
			if config.mode == "point":
				t.check(frame.has_aim and t.near(frame.aim_distance(h.global_position), float(config.range) * 0.5), "point skill drag selects half range rather than always maximum")
				t.check(view.skill_aim.get_node_or_null("LandingArea") != null, "point skill shows its landing area")
				if h.data.id == "jm":
					t.check(view.skill_aim.find_children("WallGhost_*", "MeshInstance3D", true, false).is_empty(), "JM previews only the landing stun area, no wall")
			source.finish_touch_skill()
			var release := source.frame_for(h, host)
			t.check(release.was_pressed(button), "release queues exactly one chosen skill")
			if config.mode == "point":
				t.check(release.has_aim and release.aim_point == frame.aim_point and release.skill_aimed, "release preserves the point visible in the preview")
			view.skill_aim.refresh()
			t.check(not view.skill_aim.visible, "private intent disappears on release")
			source.begin_touch_skill(button)
			source.drag_touch_skill(Vector2.RIGHT * (host.tuning.tag_aim_cancel_pixels + 10), host.tuning)
			source.finish_touch_skill(true)
			t.check(source.frame_for(h, host).pressed == 0, "cancelled skill aim cannot cast")
		TestCtx.put(h, -9 + h.slot, -9)
	t.check(icons.size() == 10, "all ten hero skills have distinct button symbols")
	# Actual JM cast: public landing tell and generated wall must match the private preview.
	var jm: Hero = null
	var nathan: Hero = null
	var tutoy: Hero = null
	for h in host.heroes.slice(0, 5):
		if h.data.id == "jm": jm = h
		if h.data.id == "nathan": nathan = h
		if h.data.id == "tutoy": tutoy = h
	TestCtx.put(jm, -5, 0)
	var input: PlayerInput = sources.jm
	input.begin_touch_skill(RB.BTN_SKILL1)
	input.drag_touch_skill(Vector2.RIGHT * host.tuning.skill_aim_pad_radius * 0.5, host.tuning)
	var preview := jm.skills[0].aim_preview(input.skill_preview_frame(jm))
	input.finish_touch_skill()
	var release := input.frame_for(jm, host)
	jm.set_frame(release)
	t.check(jm.skills[0].try_cast(release), "JM can cast the selected half-range jump")
	t.check(jm.skills[0].last_target == preview.point, "JM's committed landing equals the aiming marker")
	var marker: Node3D = jm.skills[0]._marker
	t.check(marker != null and marker.is_visible_in_tree() and marker.get_meta("landing") == preview.point, "committed landing tell lives in the shared world for all players")
	var ghosts: Array[MeshInstance3D] = []
	for child in marker.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			ghosts.append(child)
	t.check(ghosts.is_empty() and preview.wall.is_empty(), "landing tell and preview have no removed wall geometry")
	t.steps(host, RB.ticks(float(jm.data.values.talbog_air_time)))
	var wall: Node3D = jm.skills[0].last_wall
	t.check(wall == null and jm.global_position.distance_to(preview.point) < 0.1, "selected jump lands on preview with no wall")
	t.check(not is_instance_valid(jm.skills[0]._marker), "public landing tell clears on landing")
	# Nathan uses the same point/flight query for the real packet.
	TestCtx.put(nathan, -5, 0)
	input = sources.nathan
	input.begin_touch_skill(RB.BTN_SKILL2)
	input.drag_touch_skill(Vector2.RIGHT * host.tuning.skill_aim_pad_radius * 0.5, host.tuning)
	preview = nathan.skills[1].aim_preview(input.skill_preview_frame(nathan))
	input.finish_touch_skill()
	release = input.frame_for(nathan, host)
	nathan.set_frame(release)
	t.check(nathan.skills[1].try_cast(release), "Nathan casts at his chosen cloud point")
	t.steps(host, RB.ticks(nathan.data.v("ubo_prepare_time")) + 1)
	var packet: UboPacket = host.objects[-1] as UboPacket
	t.check(packet != null and RB.flat_dist(packet.to_pos, preview.point) < 0.01 and packet.flight_ticks == preview.flight, "cloud packet landing and flight match the selected preview")
	# Explicit slide aim overrides the movement stick only for this aimed cast.
	TestCtx.put(tutoy, -6, 0)
	input = sources.tutoy
	input.set_touch_move(Vector2.LEFT)
	input.begin_touch_skill(RB.BTN_SKILL2)
	input.drag_touch_skill(Vector2(0, host.tuning.skill_aim_pad_radius), host.tuning)
	input.finish_touch_skill()
	release = input.frame_for(tutoy, host)
	tutoy.set_frame(release)
	t.check(release.duplicate_frame().skill_aimed, "InputFrame copies retain explicit skill aim")
	t.check(tutoy.skills[1].try_cast(release) and tutoy.skills[1].slide_dir.z > 0.9, "an aimed slide follows its skill pad while the movement stick points elsewhere")
	t.ok("all skill previews: unique kit controls, distance selection, private intent, public JM tell and exact landing/wall parity")
	await t.free_match(host)
