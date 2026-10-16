class_name HeroVisual
extends Node3D

## Presentation for one Hero: model, toon + outline materials, animation, see-through,
## icons, team ring. Reads the Hero every frame (_process) and never changes game state.
## Animation: an AnimationTree blends Idle / Walking / Running by ground speed (playback
## scaled to the measured foot speed, as HeroController did) and cross-fades to an action
## layer for state clips (Tagged, Stunned, Jailed...) and skill clips requested through
## play_action(). Clip names are the contract in docs/pipelines/blender.md.

const LOOP_CLIPS := ["Idle", "Walking", "Running", "BreakDance", "Stunned", "Jailed", "Chained",
		"Capture", "Harurot", "Tamaraw", "Ihip", "Iyak"]
const XFADE := 0.12
const TURN_RATE := 16.0 ## rad/s the model turns toward `facing`

var hero: Hero
var model: Node3D
var animator: AnimationPlayer
var tree: AnimationTree
var outline_mat: ShaderMaterial
var meshes: Array[MeshInstance3D] = []
var _opaque: Array = [] ## [mesh, surface, material]
var _faded: Array = []
var _alpha := 1.0
var ring: MeshInstance3D
var icon: Label3D
var charge_bg: MeshInstance3D ## the hampas charge bar over the head (v0.2)
var charge_fill: MeshInstance3D
const CHARGE_W := 0.9
const CHARGE_H := 0.11
var shield: MeshInstance3D
var extras: Node3D ## skills and passives may parent presentation nodes here

var _slot := 0 ## alternates 0/1 so a new action always restarts
var _cur_key := ""
var _req_clip := ""
var _req_until := 0.0 ## engine seconds; <= 0 means until stop_action()
var _req_dur := -1.0
var _req_loop := false
var _req_serial := 0
var _cur_serial := -1
var _tag_anim_until := 0.0
var _victory := false

# Human chain: two-bone IK on both arms so prisoners really hold the post and each other.
const ARM_BONES := [["mixamorig:RightArm", "mixamorig:RightForeArm", "mixamorig:RightHand"],
		["mixamorig:LeftArm", "mixamorig:LeftForeArm", "mixamorig:LeftHand"]]
const HAND_HEIGHT := 0.6 ## hand grip height as a fraction of the model height
var arm_ik: TwoBoneIK3D
var _hand_targets: Array[Marker3D] = [] ## 0 = rear hand (post / inner link), 1 = front hand
var _hand_poles: Array[Marker3D] = []
var _ik_weight := 0.0

func setup(p_hero: Hero) -> void:
	hero = p_hero
	extras = Node3D.new()
	extras.name = "Extras"
	add_child(extras)
	_load_model()
	_build_tree()
	_build_markers()
	_build_arm_ik()

# ---- public API ------------------------------------------------------------------------
func has_clip(clip: String) -> bool:
	return animator != null and animator.has_animation(clip)

func clip_length(clip: String) -> float:
	return animator.get_animation(clip).length if has_clip(clip) else 0.0

## Play a skill clip. duration > 0 time-scales the clip to fit and ends the request after it;
## loop clips with duration <= 0 play until stop_action(). Missing clips are ignored.
func play_action(clip: String, duration: float = -1.0, hold := false) -> void:
	if not has_clip(clip):
		return
	_req_clip = clip
	_req_dur = duration
	_req_loop = clip in LOOP_CLIPS or hold
	var natural := clip_length(clip)
	var span := duration if duration > 0.0 else (natural if not _req_loop else 0.0)
	_req_until = _now() + span if span > 0.0 else 0.0
	_req_serial += 1

func stop_action(clip := "") -> void:
	if clip == "" or clip == _req_clip:
		_req_clip = ""

func show_victory(on: bool) -> void:
	_victory = on

var _spin_until := 0.0
var _spin_rate := 0.0

## Spin the model in place (`turns` full turns over `secs`), e.g. JM's angry MAKAPAL! spin.
func spin(secs: float, turns: float) -> void:
	if secs <= 0.0:
		return
	_spin_until = _now() + secs
	_spin_rate = TAU * turns / secs

## Viewer-dependent look, set by the match presentation every frame.
## alpha 0 = hidden (cloud, Taguan), 0.25 = IYAK! see-through, 1 = normal.
func set_view_alpha(alpha: float) -> void:
	alpha = clampf(alpha, 0.0, 1.0)
	if is_equal_approx(alpha, _alpha):
		return
	_alpha = alpha
	if model:
		model.visible = alpha > 0.01
	var use_fade := alpha < 0.99
	for entry in (_faded if use_fade else _opaque):
		(entry[0] as MeshInstance3D).set_surface_override_material(entry[1], entry[2])
	if use_fade:
		for entry in _faded:
			(entry[2] as ShaderMaterial).set_shader_parameter("alpha", alpha)
	ring.visible = alpha > 0.01

func set_outline(color: Color) -> void:
	if outline_mat:
		outline_mat.set_shader_parameter("ink_color", color)

## "" none, "taggable" orange "!", "untaggable" none; ep adds the shield.
func set_markers(taggable_mark: bool, ep: bool) -> void:
	icon.visible = taggable_mark and _alpha > 0.01
	shield.visible = ep and _alpha > 0.01

func set_ring_color(color: Color) -> void:
	(ring.material_override as StandardMaterial3D).albedo_color = color

# ---- build -----------------------------------------------------------------------------
func _load_model() -> void:
	var packed := load(hero.data.glb) as PackedScene
	if packed == null:
		push_warning("HeroVisual: can't load %s" % hero.data.glb)
		return
	model = packed.instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	var bounds := AABB()
	var found := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		meshes.append(mi)
		var box: AABB = model.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		bounds = box if not found else bounds.merge(box)
		found = true
	if found and bounds.size.y > 0.01:
		var k: float = hero.data.model_height / bounds.size.y
		model.scale = Vector3.ONE * k
		model.position.y = -bounds.position.y * k
	for node in model.find_children("*", "AnimationPlayer", true, false):
		animator = node as AnimationPlayer
		break
	if animator:
		for clip in animator.get_animation_list():
			animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip in LOOP_CLIPS else Animation.LOOP_NONE
	_apply_materials()

func _apply_materials() -> void:
	outline_mat = ShaderMaterial.new()
	outline_mat.shader = load("res://shaders/character_outline.gdshader")
	outline_mat.set_shader_parameter("ink_color", Color(0.055, 0.045, 0.075))
	var toon := load("res://shaders/character_toon.gdshader")
	var fade := load("res://shaders/character_toon_fade.gdshader")
	for mi in meshes:
		for surface in range(mi.mesh.get_surface_count()):
			var src := mi.get_active_material(surface)
			var tex: Texture2D = null
			var col := Color.WHITE
			if src is StandardMaterial3D:
				tex = (src as StandardMaterial3D).albedo_texture
				col = (src as StandardMaterial3D).albedo_color
			var opaque := ShaderMaterial.new()
			opaque.shader = toon
			opaque.set_shader_parameter("base_texture", tex)
			opaque.set_shader_parameter("base_color", col)
			opaque.next_pass = outline_mat
			var faded := ShaderMaterial.new()
			faded.shader = fade
			faded.set_shader_parameter("base_texture", tex)
			faded.set_shader_parameter("base_color", col)
			faded.set_shader_parameter("alpha", 0.25)
			faded.next_pass = outline_mat
			mi.set_surface_override_material(surface, opaque)
			_opaque.append([mi, surface, opaque])
			_faded.append([mi, surface, faded])

func _build_tree() -> void:
	if animator == null or not (has_clip("Idle") and has_clip("Walking") and has_clip("Running")):
		push_warning("HeroVisual %s: missing Idle/Walking/Running" % hero.data.id)
		return
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = maxf(hero.data.run_speed, 0.1)
	space.sync = true
	var walk_speed := hero.data.run_speed * hero.tuning.walk_fraction
	for point in [["Idle", 0.0], ["Walking", walk_speed], ["Running", hero.data.run_speed]]:
		var n := AnimationNodeAnimation.new()
		n.animation = point[0]
		space.add_blend_point(n, point[1], -1, point[0])
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("Loco", space, Vector2(0, 0))
	bt.add_node("LocoSpeed", AnimationNodeTimeScale.new(), Vector2(200, 0))
	bt.connect_node("LocoSpeed", 0, "Loco")
	for s in ["A", "B"]:
		var a := AnimationNodeAnimation.new()
		a.animation = "Idle"
		bt.add_node("Act" + s, a, Vector2(0, 200 if s == "A" else 400))
		bt.add_node("Speed" + s, AnimationNodeTimeScale.new(), Vector2(200, 200 if s == "A" else 400))
		bt.connect_node("Speed" + s, 0, "Act" + s)
	var mode := AnimationNodeTransition.new()
	mode.xfade_time = XFADE
	mode.input_count = 3
	mode.set_input_name(0, "loco")
	mode.set_input_name(1, "a")
	mode.set_input_name(2, "b")
	for i in range(3):
		mode.set_input_reset(i, true)
	bt.add_node("Mode", mode, Vector2(400, 0))
	bt.connect_node("Mode", 0, "LocoSpeed")
	bt.connect_node("Mode", 1, "SpeedA")
	bt.connect_node("Mode", 2, "SpeedB")
	bt.connect_node("output", 0, "Mode")
	tree = AnimationTree.new()
	tree.name = "AnimTree"
	tree.tree_root = bt
	animator.add_sibling(tree)
	tree.anim_player = tree.get_path_to(animator)
	tree.set("parameters/LocoSpeed/scale", 1.0)
	tree.set("parameters/SpeedA/scale", 1.0)
	tree.set("parameters/SpeedB/scale", 1.0)
	tree.active = true

func _build_markers() -> void:
	ring = MeshInstance3D.new()
	ring.name = "TeamRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.52
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus
	ring.scale = Vector3(1, 0.08, 1)
	ring.position.y = 0.04
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = RB.TEAM_COLORS[hero.team]
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	icon = Label3D.new()
	icon.name = "TaggableIcon"
	icon.text = "!"
	icon.font_size = 96
	icon.outline_size = 18
	icon.modulate = Color("ff8a1f")
	icon.outline_modulate = Color("1a1020")
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.no_depth_test = true
	icon.position.y = hero.data.model_height + 0.45
	icon.visible = false
	add_child(icon)
	charge_bg = _bar_quad(CHARGE_W + 0.06, CHARGE_H + 0.06, Color("1a1020"), 0)
	charge_fill = _bar_quad(CHARGE_W, CHARGE_H, Color("ffd27a"), 1)
	charge_bg.name = "ChargeBar"
	charge_bg.add_child(charge_fill)
	charge_bg.position.y = hero.data.model_height + 0.3
	charge_bg.visible = false
	add_child(charge_bg)
	shield = MeshInstance3D.new()
	shield.name = "ProtectionShield"
	var sph := SphereMesh.new()
	sph.radius = 0.75
	sph.height = 1.9
	shield.mesh = sph
	shield.position.y = 0.9
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.55, 0.85, 1.0, 0.18)
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield.material_override = sm
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield.visible = false
	add_child(shield)

func _build_arm_ik() -> void:
	if model == null:
		return
	var skel := model.find_children("*", "Skeleton3D", true, false)
	if skel.is_empty():
		return
	var sk := skel[0] as Skeleton3D
	for arm in ARM_BONES:
		for b in arm:
			if sk.find_bone(b) < 0:
				return
	arm_ik = TwoBoneIK3D.new()
	arm_ik.name = "ChainArms"
	sk.add_child(arm_ik)
	arm_ik.setting_count = 2
	for i in range(2):
		var target := Marker3D.new()
		target.name = "HandTarget%d" % i
		add_child(target)
		_hand_targets.append(target)
		var pole := Marker3D.new()
		pole.name = "ElbowPole%d" % i
		add_child(pole)
		_hand_poles.append(pole)
		arm_ik.set_root_bone_name(i, ARM_BONES[i][0])
		arm_ik.set_middle_bone_name(i, ARM_BONES[i][1])
		arm_ik.set_end_bone_name(i, ARM_BONES[i][2])
		arm_ik.set_target_node(i, arm_ik.get_path_to(target))
		arm_ik.set_pole_node(i, arm_ik.get_path_to(pole))
	arm_ik.influence = 0.0
	arm_ik.active = false

## Where this prisoner's hands go: [rear grip, front grip] in world space, or [] when free.
## The rear hand holds the post (first prisoner) or the inner neighbour's front hand; the front
## hand holds the outer neighbour's rear hand, and the tip reaches toward the nearest free ally.
func chain_grips() -> Array:
	if hero.host == null or hero.state != Hero.State.CHAINED:
		return []
	var js := hero.host.jail_system
	var owner := RB.other_team(hero.team)
	var c: Array = js.chain(owner)
	var k := c.find(hero)
	if k < 0:
		return []
	var y := hero.global_position.y + hero.data.model_height * HAND_HEIGHT
	var me := hero.global_position
	var inner: Vector3 = js.link_before(owner, k)
	var rear := (me + inner) * 0.5 if k > 0 else inner
	rear.y = y + (0.15 if k == 0 else 0.0)
	var front: Vector3
	if k < c.size() - 1:
		front = (me + (c[k + 1] as Hero).global_position) * 0.5
		front.y = y
	else: # the tip stretches out toward the rescue
		var reach_to := me + hero.facing * 1.0
		var best := INF
		for a in hero.host.allies_of(hero):
			if a.is_free():
				var d := RB.flat_dist(a.global_position, me)
				if d < best:
					best = d
					reach_to = a.global_position
		var dir := RB.flat(reach_to - me)
		dir = dir.normalized() if dir.length() > 0.05 else hero.facing
		front = me + dir * 0.75
		front.y = y + 0.25
	return [rear, front]

func _update_arm_ik(delta: float) -> void:
	if arm_ik == null:
		return
	var grips := chain_grips()
	var want := 1.0 if not grips.is_empty() else 0.0
	_ik_weight = move_toward(_ik_weight, want, delta * 4.0)
	arm_ik.active = _ik_weight > 0.001
	arm_ik.influence = _ik_weight
	if grips.is_empty():
		return
	var side := hero.facing.cross(Vector3.UP).normalized()
	for i in range(2):
		_hand_targets[i].global_position = grips[i]
		# elbows bend down and outward, away from the body
		var shoulder := hero.global_position + Vector3(0, hero.data.model_height * 0.78, 0)
		var out := side * (1.0 if i == 0 else -1.0)
		_hand_poles[i].global_position = shoulder + out * 0.6 + Vector3(0, -0.8, 0) - hero.facing * 0.2

## Chained prisoners turn sideways to the chain so one arm reaches back and one forward.
func _chain_turn() -> float:
	if hero.state != Hero.State.CHAINED:
		return 0.0
	return deg_to_rad(-55.0)

# ---- per frame -------------------------------------------------------------------------
func _process(delta: float) -> void:
	if hero == null:
		return
	var want := atan2(hero.facing.x, hero.facing.z) + _chain_turn()
	if model and _now() < _spin_until:
		model.rotation.y = wrapf(model.rotation.y + _spin_rate * delta, -PI, PI)
	elif model:
		model.rotation.y = lerp_angle(model.rotation.y, want, minf(TURN_RATE * delta, 1.0))
	if hero.is_winding_up():
		_tag_anim_until = _now() + 0.35
	_update_charge_bar()
	_update_animation()
	_update_arm_ik(delta)

## Billboarded, unshaded quad; the mesh is offset (not the node) so it survives billboarding.
func _bar_quad(w: float, h: float, color: Color, priority: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.render_priority = priority
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Fills left to right while Tag is held; turns orange-white at full charge.
func _update_charge_bar() -> void:
	if charge_bg == null:
		return
	var on := hero.is_charging() and _alpha > 0.01
	charge_bg.visible = on
	if not on:
		return
	var k := hero.charge_fraction()
	var q := charge_fill.mesh as QuadMesh
	q.size.x = maxf(0.001, CHARGE_W * k)
	q.center_offset.x = -CHARGE_W * 0.5 + q.size.x * 0.5
	(charge_fill.material_override as StandardMaterial3D).albedo_color = Color("ffd27a").lerp(Color("ff5a1f"), k) if k < 1.0 else Color("fff4e0")

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## What to show, most important first: state clips, then skill requests, then locomotion.
func _desired() -> Array:
	var h := hero
	if h.state == Hero.State.TAGGED:
		return ["Tagged", h.tuning.tagged_freeze, -2]
	if h.is_stunned():
		return ["Stunned", -1.0, -3]
	if h.is_stumbling():
		return ["Stumble", h.tuning.failed_tag_stumble, -4]
	if h.capturing:
		return ["Capture", -1.0, -5]
	if _req_clip != "" and (_req_until <= 0.0 or _now() < _req_until):
		return [_req_clip, _req_dur, _req_serial]
	_req_clip = ""
	if _tag_anim_until > _now() and h.is_free():
		return ["Tag", 0.45, -6]
	if _victory:
		return ["Victory", -1.0, -7]
	if h.state == Hero.State.CHAINED and h.ground_speed() < 0.3:
		return ["Chained", -1.0, -8]
	if h.state == Hero.State.JAILED and h.ground_speed() < 0.3:
		return ["Jailed", -1.0, -9]
	return ["", -1.0, -1]

func _update_animation() -> void:
	if tree == null:
		return
	var d := _desired()
	var clip: String = d[0]
	if clip != "" and not has_clip(clip):
		clip = ""
	var key := "%s#%d" % [clip, d[2]]
	if clip == "":
		if _cur_key != "loco":
			tree.set("parameters/Mode/transition_request", "loco")
			_cur_key = "loco"
		var spd := hero.ground_speed()
		tree.set("parameters/Loco/blend_position", clampf(spd, 0.0, hero.data.run_speed))
		tree.set("parameters/LocoSpeed/scale", _loco_scale(spd))
		return
	if key == _cur_key:
		return
	_cur_key = key
	_slot = 1 - _slot
	var s := "A" if _slot == 0 else "B"
	var node := (tree.tree_root as AnimationNodeBlendTree).get_node("Act" + s) as AnimationNodeAnimation
	node.animation = clip
	var dur: float = d[1]
	var natural := clip_length(clip)
	var scale := 1.0
	if dur > 0.0 and natural > 0.0 and animator.get_animation(clip).loop_mode == Animation.LOOP_NONE:
		scale = natural / dur
	tree.set("parameters/Speed%s/scale" % s, scale)
	tree.set("parameters/Mode/transition_request", s.to_lower())

## Clip rate that makes the planted foot match the body (walk/run clip speeds from qc_asset).
func _loco_scale(spd: float) -> float:
	var walk := hero.data.run_speed * hero.tuning.walk_fraction
	var run := hero.data.run_speed
	var walk_k := walk / hero.data.walk_clip_speed if hero.data.walk_clip_speed > 0.0 else 1.0
	var run_k := run / hero.data.run_clip_speed if hero.data.run_clip_speed > 0.0 else 1.0
	if spd <= walk:
		return lerpf(1.0, walk_k, spd / walk)
	if spd <= run:
		return lerpf(walk_k, run_k, (spd - walk) / maxf(run - walk, 0.01))
	return run_k * spd / run
