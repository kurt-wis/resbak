class_name HeroVisual
extends Node3D

## Presentation for one Hero: model, toon + outline materials, animation, see-through,
## icons, team ring. Reads the Hero every frame (_process) and never changes game state.
## Animation: an AnimationTree blends Idle / Walking / Running by ground speed (playback
## scaled to the measured foot speed, as HeroController did) and cross-fades to an action
## layer for state clips (Tagged, Stunned, Jailed...) and skill clips requested through
## play_action(). Clip names are the contract in docs/pipelines/blender.md.

const LOOP_CLIPS := ["Idle", "Walking", "Running", "BreakDance", "Stunned", "Jailed", "Chained",
		"Capture", "TagCharge", "Harurot", "Tamaraw", "Ihip", "Iyak"]
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
# Godot renames imported Mixamo bones (mixamorig:LeftHand becomes mixamorig_LeftHand), so the arm
# bones are found by their name tail at load time, never by the exact Blender name.
const ARM_BONE_TAILS := [["RightArm", "RightForeArm", "RightHand"],
		["LeftArm", "LeftForeArm", "LeftHand"]]
# Hands are held at hip-to-waist height: low enough to read as holding hands, high enough that
# every rig can reach it while keeping the elbow bent (these arms are only ~0.39-0.51 m long).
const HAND_HEIGHT := 0.48 ## hand grip height as a fraction of the model height
const ELBOW_BEND := 0.93 ## a grip target never sits past this fraction of the arm's reach
const GRIP_BLEND := 0.55 ## how far a shared grip pulls from the pair midpoint toward the neighbour's hand
const TIP_REACH_RANGE := 6.0 ## the tip stretches for a rescuer this close; further away that arm hangs
# Kid-sized arms can't span chain_link, so the chain is DRAWN shorter than it is: each link is
# pulled toward the post until its neighbours' hands can meet (presentation only; host positions,
# tagging and rescue are untouched). The pull lets go as a free ally nears the tip, so the
# rescue touch lands where the tip really stands.
const GRIP_SLACK := 0.92 ## neighbours are drawn no farther apart than this share of their joined spans
const PULL_RELEASE_NEAR := 2.5 ## a free ally this close to the tip: the chain is drawn at its real spacing
const PULL_RATE := 6.0 ## how fast the drawn offset eases in and out (per second)
var _half_span := -1.0
var _chain_offset := Vector3.ZERO
var _was_chained := false
var arm_ik: TwoBoneIK3D
var _skel: Skeleton3D
var _arm_bones: Array = [] ## per arm, the three resolved bone names (root, middle, end)
var _hand_targets: Array[Marker3D] = [] ## 0 = right hand, 1 = left hand
var _hand_poles: Array[Marker3D] = []
var _ik_weight := 0.0
## A SkeletonModifier3D's result is discarded from the stored bone pose once it has been applied
## to the skin (Godot's "Design of the Skeleton Modifier 3D"), so get_bone_global_pose() in
## _process() returns the un-IK'd animation pose. The arm joints are therefore captured on the
## skeleton's `skeleton_updated` signal, which fires with the modified pose still in place.
var _bones_world := {} ## bone name -> last rendered world position
var _tail_names := {} ## Mixamo name tail -> resolved bone name

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
	_skel = skel[0] as Skeleton3D
	_arm_bones.clear()
	for arm in ARM_BONE_TAILS:
		var names: Array[String] = []
		for tail in arm:
			var bone := _bone_by_tail(tail)
			if bone == "":
				push_warning("HeroVisual %s: no mixamorig:%s bone in the rig, the chain arms stay off"
						% [hero.data.id, tail])
				_skel = null
				return
			names.append(bone)
		_arm_bones.append(names)
	arm_ik = TwoBoneIK3D.new()
	arm_ik.name = "ChainArms"
	_skel.add_child(arm_ik)
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
		arm_ik.set_root_bone_name(i, _arm_bones[i][0])
		arm_ik.set_middle_bone_name(i, _arm_bones[i][1])
		arm_ik.set_end_bone_name(i, _arm_bones[i][2])
		arm_ik.set_target_node(i, arm_ik.get_path_to(target))
		arm_ik.set_pole_node(i, arm_ik.get_path_to(pole))
	arm_ik.influence = 0.0
	arm_ik.active = false
	_skel.skeleton_updated.connect(_on_skel_updated)
	_on_skel_updated()

## Capture the arm joint positions as rendered (after the IK modifier has run). Reading
## get_bone_global_pose() at any other time gives the animation pose, not the IK result.
func _on_skel_updated() -> void:
	if _skel == null:
		return
	var xform := _skel.global_transform
	for arm in _arm_bones:
		for bone in arm:
			var idx := _skel.find_bone(bone)
			if idx >= 0:
				_bones_world[bone] = xform * _skel.get_bone_global_pose(idx).origin

## The rig bone ending in the Mixamo name tail ("RightHand" finds mixamorig_RightHand), or "".
func _bone_by_tail(tail: String) -> String:
	if _skel == null:
		return ""
	if _tail_names.has(tail):
		return _tail_names[tail]
	for i in range(_skel.get_bone_count()):
		var bone_name := _skel.get_bone_name(i)
		if bone_name.begins_with("mixamorig") and bone_name.replace(":", "_").ends_with(tail):
			_tail_names[tail] = bone_name
			return bone_name
	return ""

## A bone joint's world position, as rendered this frame (IK included).
func _bone_pos(bone: String) -> Vector3:
	if _bones_world.has(bone):
		return _bones_world[bone]
	var idx := _skel.find_bone(bone) if _skel != null else -1
	if idx < 0:
		return global_position + Vector3(0, hero.data.model_height * HAND_HEIGHT, 0)
	return _skel.global_transform * _skel.get_bone_global_pose(idx).origin

## World position of a rig bone by its Mixamo name tail ("LeftHand", "RightArm"): for QC and tests.
func bone_world(tail: String) -> Vector3:
	var bone := _bone_by_tail(tail)
	return Vector3.ZERO if bone == "" else _bone_pos(bone)

## World position of one hand bone (0 = right, 1 = left) after animation and IK.
func hand_position(arm: int) -> Vector3:
	return bone_world("LeftHand" if arm == 1 else "RightHand")

## World position of the hand bone that holds one grip (0 = rear grip, 1 = front grip).
func grip_hand(grip: int) -> Vector3:
	var map := arm_grip_indices()
	for i in range(2):
		if map[i] == grip:
			return hand_position(i)
	return hand_position(0)

## How far a hand bone sits from the point its IK is aiming at: 0 means it is exactly on the grip.
func hand_target_error(arm: int) -> float:
	if _hand_targets.size() < 2 or _skel == null:
		return 0.0
	return hand_position(arm).distance_to(_hand_targets[arm].global_position)

## Shoulder-to-wrist length of one arm: a rig constant, whatever the pose does. Taken from the
## rest pose on purpose: the IK'd pose is bent, so measuring it live would shrink every frame.
func _arm_reach(arm: int) -> float:
	if _skel == null:
		return 0.4
	return _rest_pos(_arm_bones[arm][0]).distance_to(_rest_pos(_arm_bones[arm][1])) \
			+ _rest_pos(_arm_bones[arm][1]).distance_to(_rest_pos(_arm_bones[arm][2]))

func _rest_pos(bone: String) -> Vector3:
	var idx := _skel.find_bone(bone)
	return Vector3.ZERO if idx < 0 else _skel.global_transform * _skel.get_bone_global_rest(idx).origin

## Pull a grip point inside the arm's reach, so the elbow always keeps a slight bend.
func _reach_to(shoulder: Vector3, point: Vector3, reach: float) -> Vector3:
	var to := point - shoulder
	var d := to.length()
	if d < 0.001 or d <= reach * ELBOW_BEND:
		return point
	return shoulder + to / d * reach * ELBOW_BEND

## The chain this prisoner belongs to as [jail system, jailed-from team, chain, index], or [].
func _chain_ctx() -> Array:
	if hero == null or hero.host == null or hero.state != Hero.State.CHAINED:
		return []
	var js: JailSystem = hero.host.jail_system
	var owner := RB.other_team(hero.team)
	var c: Array = js.chain(owner)
	var k := c.find(hero)
	return [js, owner, c, k] if k >= 0 else []

## The neighbour's hand that holds this prisoner: its front grip (1) for the inner neighbour,
## its rear grip (0) for the outer one. Picked by grip, not by distance: the closer hand can be
## the wrong one while the chain turns.
func _neighbour_hand(link: Hero, grip: int) -> Vector3:
	return (link.visual as HeroVisual).grip_hand(grip)

## The shared grip point of one pair of neighbours: the midpoint between the two prisoners, pulled
## toward the neighbour's real hand, at hand height. Both links aim at it, so the two hands
## converge on one spot; each arm clamps the point to its own reach, which keeps elbows bent.
func _meet_point(other: Vector3, other_hand: Vector3, y: float) -> Vector3:
	var mid := (global_position + other) * 0.5
	mid.y = y
	var point := mid.lerp(Vector3(other_hand.x, y, other_hand.z), GRIP_BLEND)
	point.y = y
	return point

## How far this hero's hand can sit from its body centre, sideways, at grip height with the elbow
## keeping its bend: the shoulder's offset plus the arm's flat reach. A rig constant (rest pose).
func half_span() -> float:
	if _half_span >= 0.0:
		return _half_span
	if _skel == null or _arm_bones.is_empty():
		return 0.5
	var shoulder := _rest_pos(_arm_bones[0][0]) - global_position
	var drop := shoulder.y - hero.data.model_height * HAND_HEIGHT
	var reach := _arm_reach(0) * ELBOW_BEND
	_half_span = Vector2(shoulder.x, shoulder.z).length() + sqrt(maxf(reach * reach - drop * drop, 0.0))
	return _half_span

## Where the chain draws this prisoner: the real chain walked out from the post, each step cut to
## what the two neighbours' arms can span, easing back to the real spacing as a rescuer closes in
## on the tip (see GRIP_SLACK). Not chained: the hero's own position.
func chain_draw_position() -> Vector3:
	var ctx := _chain_ctx()
	if ctx.is_empty():
		return hero.global_position
	var c: Array = ctx[2]
	var k: int = ctx[3]
	var release := _chain_release(c)
	var prev: Vector3 = (ctx[0] as JailSystem).link_before(ctx[1], 0)
	var at := prev
	var prev_span := 0.0 # the post takes no arm
	for i in range(k + 1):
		var link: Hero = c[i]
		var span := (link.visual as HeroVisual).half_span()
		var d := RB.flat(link.global_position - prev)
		var dist := d.length()
		if dist > 0.001:
			at += d / dist * lerpf(minf(dist, (prev_span + span) * GRIP_SLACK), dist, release)
		prev = link.global_position
		prev_span = span
	at.y = hero.global_position.y
	return at

## Eases the drawn chain offset toward chain_draw_position by `weight` (1 = snap). Joining a chain
## is a teleport into jail, so it snaps; everything after eases.
func settle_chain_draw(weight := 1.0) -> void:
	var chained := not _chain_ctx().is_empty()
	if chained and not _was_chained:
		weight = 1.0
	_was_chained = chained
	var pull := RB.flat(chain_draw_position() - hero.global_position)
	_chain_offset = _chain_offset.lerp(pull, weight)
	position = _chain_offset # this node sits unrotated at the hero's origin

## 0 while no free ally is near the chain's tip, rising to 1 as one closes to PULL_RELEASE_NEAR.
func _chain_release(c: Array) -> float:
	var tip: Hero = c[c.size() - 1]
	var best := INF
	for a in hero.host.allies_of(tip):
		if a.is_free():
			best = minf(best, RB.flat_dist(a.global_position, tip.global_position))
	return 1.0 - clampf((best - PULL_RELEASE_NEAR) / (TIP_REACH_RANGE - PULL_RELEASE_NEAR), 0.0, 1.0)

## The free ally this tip stretches toward, or INF when none is in range.
func _tip_target() -> Vector3:
	var ctx := _chain_ctx()
	if ctx.is_empty():
		return Vector3.INF
	var c: Array = ctx[2]
	if c[c.size() - 1] != hero:
		return Vector3.INF
	var best := TIP_REACH_RANGE
	var at := Vector3.INF
	for a in hero.host.allies_of(hero):
		if a.is_free():
			var d := RB.flat_dist(a.global_position, hero.global_position)
			if d < best:
				best = d
				at = a.global_position
	return at

## Which grip is a relaxed hang instead of a real hold: 1 when this hero is the tip and no rescuer
## is close enough to stretch for, else -1 (both hands hold something).
func chain_relaxed_grip() -> int:
	var ctx := _chain_ctx()
	if ctx.is_empty() or ctx[2][ctx[2].size() - 1] != hero:
		return -1 ## only the chain tip ever lets an arm hang
	return 1 if _tip_target() == Vector3.INF else -1

## Where this prisoner's hands go: [rear grip, front grip] in world space, or [] when free.
## The rear hand holds the post (first prisoner) or the inner neighbour's front hand; the front
## hand holds the outer neighbour's rear hand, and the tip reaches toward the nearest free ally.
func chain_grips() -> Array:
	var ctx := _chain_ctx()
	if ctx.is_empty():
		return []
	var js: JailSystem = ctx[0]
	var owner: int = ctx[1]
	var c: Array = ctx[2]
	var k: int = ctx[3]
	var me := global_position # where this prisoner is drawn (chain_draw_position)
	var y := me.y + hero.data.model_height * HAND_HEIGHT
	var rear: Vector3
	if k > 0:
		var inner: Hero = c[k - 1]
		rear = _meet_point(inner.visual.global_position, _neighbour_hand(inner, 1), y)
	else: # the post holder grips the post itself
		var post: Vector3 = js.link_before(owner, 0)
		rear = Vector3(post.x, y, post.z)
	var front: Vector3
	if k < c.size() - 1:
		var outer: Hero = c[k + 1]
		front = _meet_point(outer.visual.global_position, _neighbour_hand(outer, 0), y)
	else:
		var at := _tip_target()
		var dir := RB.flat(at - me) if at != Vector3.INF else RB.flat(hero.facing)
		dir = dir.normalized() if dir.length() > 0.05 else RB.flat(hero.facing).normalized()
		# a rescuer in range gets a stretched arm, otherwise the free arm only hangs beside the body
		var out := 0.9 if at != Vector3.INF else 0.05
		front = Vector3(me.x, y, me.z) + dir * out
	return [rear, front]

func _update_arm_ik(delta: float) -> void:
	if arm_ik == null or _skel == null:
		return
	var grips := chain_grips()
	var want := 1.0 if not grips.is_empty() else 0.0
	_ik_weight = move_toward(_ik_weight, want, delta * 4.0)
	arm_ik.active = _ik_weight > 0.001
	arm_ik.influence = _ik_weight
	if grips.is_empty():
		return
	# The model faces across the chain (chain_facing), so the arm on the rear side of the body
	# takes the rear grip and the other arm the front grip. _arm_bones[0] is the right arm.
	var face := chain_facing()
	var right := face.cross(Vector3.UP).normalized()
	var map := arm_grip_indices()
	var relaxed := chain_relaxed_grip()
	for i in range(2):
		var side := right * (1.0 if i == 0 else -1.0)
		var shoulder := _bone_pos(_arm_bones[i][0])
		if map[i] == relaxed: # nothing to hold on this side: the arm hangs beside the body
			_hand_targets[i].global_position = shoulder + side * 0.12 + Vector3(0, -0.32, 0)
		else:
			_hand_targets[i].global_position = _reach_to(shoulder, grips[map[i]], _arm_reach(i))
		# elbows drop down and drift behind the body, so the arms hang instead of pointing out
		_hand_poles[i].global_position = shoulder + side * 0.15 + Vector3(0, -0.75, 0) - face * 0.35

## Which grip each arm takes: [grip index of the right arm, of the left arm] (0 = rear grip,
## 1 = front grip). The arm on the rear side of the body (as the model faces across the chain)
## holds the rear grip, so the hands meet the neighbours' hands instead of crossing the body.
func arm_grip_indices() -> Array:
	var ctx := _chain_ctx()
	if ctx.is_empty():
		return [0, 1]
	var right := chain_facing().cross(Vector3.UP).normalized()
	# toward the link before (not via chain_grips: neighbours read each other's grip hands)
	var rear_dir := RB.flat((ctx[0] as JailSystem).link_before(ctx[1], ctx[3]) - hero.global_position)
	return [0, 1] if rear_dir.dot(right) >= 0.0 else [1, 0]

## The way a chained prisoner's model faces: across the chain, the side the camera is on, so
## the line reads as people holding hands. Falls back to the sign that keeps a fixed look when
## there is no camera. Visual only: hero.facing is untouched. ZERO when not chained.
func chain_facing() -> Vector3:
	var ctx := _chain_ctx()
	if ctx.is_empty():
		return Vector3.ZERO
	var js: JailSystem = ctx[0]
	var owner: int = ctx[1]
	var k: int = ctx[3]
	var axis := RB.flat(hero.global_position - js.link_before(owner, k))
	if axis.length() < 0.05:
		axis = RB.flat(hero.facing)
	axis = axis.normalized()
	var perp := axis.cross(Vector3.UP).normalized()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		if RB.flat(cam.global_position - hero.global_position).dot(perp) < 0.0:
			perp = -perp
	elif perp.dot(Vector3.BACK) < 0.0:
		perp = -perp
	return perp

# ---- per frame -------------------------------------------------------------------------
func _process(delta: float) -> void:
	if hero == null:
		return
	var cf := chain_facing()
	var look := cf if cf != Vector3.ZERO else hero.facing
	var want := atan2(look.x, look.z)
	if model and _now() < _spin_until:
		model.rotation.y = wrapf(model.rotation.y + _spin_rate * delta, -PI, PI)
	elif model:
		model.rotation.y = lerp_angle(model.rotation.y, want, minf(TURN_RATE * delta, 1.0))
	if hero.is_winding_up():
		_tag_anim_until = _now() + 0.35
	_update_charge_bar()
	_update_animation()
	settle_chain_draw(minf(PULL_RATE * delta, 1.0))
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
	# Held hampas: the wind-up loop (clip is optional, tools/build_heroes.py TagCharge; no clip = normal pose)
	if h.is_charging() and h.is_free() and has_clip("TagCharge"):
		return ["TagCharge", -1.0, -6]
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
