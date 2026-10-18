class_name ArenaArt
extends Node3D

## Match-only set dressing built from the host state (presentation, never read for rules):
## - each active base is a basketball resting on a short team-coloured stand (the court's take
##   on the pole), with a painted ring that fills with a capture
##   progress arc while an enemy is taking it;
## - each jail is the map's jail line (v0.2): a painted band along it and the post the first
##   prisoner holds, which slides along the line with the chain.
## MatchView adds one and calls refresh() every frame.

const BALL_RADIUS := 0.3
const BALL_HEIGHT := 1.25
const STAND_HEIGHT := 0.95

var host: MatchHost
var _balls: Array[Node3D] = [] ## per team: the ball (null where the map draws a base prop)
var _castles: Array[Node3D] = [] ## per team: the map's base prop (sand castle), else null
var _flags: Array[Node3D] = []
var _crumble: Array[float] = [-1.0, -1.0] ## per team: seconds since its base was captured (-1 = standing)
var _rings: Array[ShaderMaterial] = []
var _posts: Array[Node3D] = [] ## per jail owner: the post, following JailSystem.post()
var _t := 0.0

func setup(p_host: MatchHost) -> void:
	host = p_host
	name = "ArenaArt"
	for team in range(2):
		_build_base(team)
		_build_jail(team)

static func outline_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/character_outline.gdshader")
	m.set_shader_parameter("ink_color", Color(0.055, 0.045, 0.075))
	m.set_shader_parameter("outline_pixels", 2.5)
	return m

static func toon_material(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/character_toon.gdshader")
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	m.set_shader_parameter("base_texture", ImageTexture.create_from_image(img))
	m.set_shader_parameter("base_color", color)
	m.next_pass = outline_material()
	return m

func _mesh(mesh: Mesh, mat: Material, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi

func _floor_quad(parent: Node3D, at: Vector3, extent: Vector2, mat: ShaderMaterial) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = extent
	var mi := _mesh(pm, mat, at + Vector3(0, 0.035, 0), parent)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _build_base(team: int) -> void:
	var t := host.tuning
	var col: Color = RB.TEAM_COLORS[team]
	var root := Node3D.new()
	root.name = "Base_%s" % RB.TEAM_NAMES[team]
	add_child(root)
	root.global_position = host.base_system.pole_pos(team)
	var prop := host.base_system.base_prop_scene()
	if prop:
		_build_prop(root, prop, team)
	else:
		_build_stand(root, team)
	_castles_pad(team)
	# painted ring
	var ext := (t.base_ring_radius + 1.0) * 2.0
	var rm := ShaderMaterial.new()
	rm.shader = load("res://shaders/floor_marking.gdshader")
	rm.set_shader_parameter("mode", 0)
	rm.set_shader_parameter("color", col)
	rm.set_shader_parameter("progress_color", RB.TEAM_COLORS[RB.other_team(team)])
	rm.set_shader_parameter("extent", Vector2(ext, ext))
	rm.set_shader_parameter("radius", t.base_ring_radius)
	rm.render_priority = 2
	_floor_quad(root, Vector3.ZERO, Vector2(ext, ext), rm)
	_rings.append(rm)

func _castles_pad(team: int) -> void:
	while _castles.size() <= team:
		_castles.append(null)
		_flags.append(null)
	while _balls.size() <= team:
		_balls.append(null)

## The map's base prop (Konstruksyon's sand castle): its Flag is tinted in the team colour.
func _build_prop(root: Node3D, prop: PackedScene, team: int) -> void:
	_castles_pad(team)
	var castle := prop.instantiate() as Node3D
	castle.name = "BaseProp"
	root.add_child(castle)
	castle.rotation.y = PI * 0.5 if team == RB.DILAW else -PI * 0.5 # door faces the other base
	_castles[team] = castle
	var flag := castle.find_child("Flag", true, false) as MeshInstance3D
	if flag:
		var m := StandardMaterial3D.new()
		m.albedo_color = RB.TEAM_COLORS[team]
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		flag.material_override = m
		_flags[team] = flag

func _build_stand(root: Node3D, team: int) -> void:
	var col: Color = RB.TEAM_COLORS[team]
	_castles_pad(team)
	# stand: a weighted base plate, a slim post and a cup the ball sits in
	var plate := CylinderMesh.new()
	plate.top_radius = 0.32
	plate.bottom_radius = 0.38
	plate.height = 0.12
	_mesh(plate, toon_material(Color("2b2733")), Vector3(0, 0.06, 0), root)
	var post := CylinderMesh.new()
	post.top_radius = 0.07
	post.bottom_radius = 0.09
	post.height = STAND_HEIGHT
	_mesh(post, toon_material(col), Vector3(0, 0.12 + STAND_HEIGHT * 0.5, 0), root)
	var cup := CylinderMesh.new()
	cup.top_radius = 0.2
	cup.bottom_radius = 0.1
	cup.height = 0.12
	_mesh(cup, toon_material(col.darkened(0.25)), Vector3(0, 0.12 + STAND_HEIGHT, 0), root)
	var ball := Node3D.new()
	ball.name = "Ball"
	ball.position = Vector3(0, BALL_HEIGHT, 0)
	root.add_child(ball)
	var sph := SphereMesh.new()
	sph.radius = BALL_RADIUS
	sph.height = BALL_RADIUS * 2.0
	sph.radial_segments = 32
	sph.rings = 16
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/basketball.gdshader")
	bm.set_shader_parameter("team_tint", col)
	bm.set_shader_parameter("tint_amount", 0.12)
	bm.next_pass = outline_material()
	_mesh(sph, bm, Vector3.ZERO, ball)
	_balls[team] = ball

func _build_jail(owner: int) -> void:
	var col: Color = RB.TEAM_COLORS[owner]
	var root := Node3D.new()
	root.name = "Jail_%s" % RB.TEAM_NAMES[owner]
	add_child(root)
	# v0.2 jail line: a translucent band (the jail) with a chalk stripe down its middle,
	# one strip per segment of the map's line, so angled and snaking lines read too
	var pts: PackedVector3Array = host.layout.lines[owner]
	var band := host.tuning.jail_band
	var band_mat := Vfx.flat_material(Color(col.lightened(0.25), 0.22))
	band_mat.render_priority = 1
	var chalk_mat := Vfx.flat_material(Color(col.lightened(0.55), 0.85))
	chalk_mat.render_priority = 2
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := b - a
		if seg.length() < 0.01:
			continue
		var basis := Basis.looking_at(seg.normalized(), Vector3.UP)
		_strip(root, (a + b) * 0.5 + Vector3(0, 0.02, 0), basis, Vector2(band * 2.0, seg.length() + 0.05), band_mat)
		_strip(root, (a + b) * 0.5 + Vector3(0, 0.03, 0), basis, Vector2(0.12, seg.length() + 0.02), chalk_mat)
	for end_pt in [pts[0], pts[pts.size() - 1]]: # round caps at both ends
		var cap := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = band
		cyl.bottom_radius = band
		cyl.height = 0.01
		cyl.radial_segments = 24
		cap.mesh = cyl
		cap.material_override = band_mat
		root.add_child(cap)
		cap.global_position = end_pt + Vector3(0, 0.02, 0)
	# the post: a metal pipe with a team-coloured band and cap, on a concrete foot. It slides
	# along the line with the chain (refresh)
	var post := Node3D.new()
	post.name = "Post"
	root.add_child(post)
	post.global_position = host.jail_system.post(owner)
	var foot := CylinderMesh.new()
	foot.top_radius = 0.2
	foot.bottom_radius = 0.24
	foot.height = 0.18
	_mesh(foot, toon_material(Color("9a948a")), Vector3(0, 0.09, 0), post)
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.075
	pipe.bottom_radius = 0.075
	pipe.height = 2.2
	_mesh(pipe, toon_material(Color("c9ccd2")), Vector3(0, 1.1, 0), post)
	var pband := CylinderMesh.new()
	pband.top_radius = 0.09
	pband.bottom_radius = 0.09
	pband.height = 0.35
	_mesh(pband, toon_material(col), Vector3(0, 1.15, 0), post)
	var cap_m := SphereMesh.new()
	cap_m.radius = 0.12
	cap_m.height = 0.24
	_mesh(cap_m, toon_material(col), Vector3(0, 2.25, 0), post)
	_posts.append(post)
	# the floor word, beside the middle of the line on the field side
	var mid := host.layout.line_length(owner) * 0.5
	var word := Label3D.new()
	word.text = "KULUNGAN"
	word.font_size = 160
	word.outline_size = 0
	word.modulate = Color(col.lightened(0.4), 0.55)
	word.rotation_degrees = Vector3(-90, 0, 0) # flat on the floor, reading left to right on screen
	word.pixel_size = 0.004
	word.shaded = false
	word.double_sided = false
	root.add_child(word)
	word.global_position = host.layout.line_point(owner, mid) + host.layout.line_normal(owner, mid) * (band + 0.6) + Vector3(0, 0.04, 0)

## A flat floor strip: `size` = (width across, length along the basis' -Z).
func _strip(parent: Node3D, at: Vector3, basis: Basis, size: Vector2, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	m.mesh = plane
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_transform = Transform3D(basis, at)

## Ball bob and spin, ring pulse and capture progress (enemy attackers on this base).
func refresh(delta: float) -> void:
	_t += delta
	for owner in range(_posts.size()):
		_posts[owner].global_position = host.jail_system.post(owner)
	for team in range(_rings.size()):
		var prog := host.base_system.capture_progress(RB.other_team(team))
		var ball := _balls[team]
		if ball:
			ball.position.y = BALL_HEIGHT + sin(_t * 2.2 + team) * 0.04
			ball.rotation.y += delta * 0.6
		elif _castles[team]:
			_refresh_castle(team, prog, delta)
		var m := _rings[team]
		m.set_shader_parameter("progress", prog)
		m.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_t * (10.0 if prog > 0.0 else 2.0)))

func has_prop(team: int) -> bool:
	return team < _castles.size() and _castles[team] != null

## The base was captured: the castle slumps into a heap and the flag drops (presentation).
func crumble(team: int) -> void:
	if team < _castles.size() and _castles[team] and _crumble[team] < 0.0:
		_crumble[team] = 0.0
		var at := host.base_system.pole_pos(team) + Vector3(0, 0.5, 0)
		Vfx.burst(self, at, Color("e3c27d"), 60, 3.5, 0.9, 0.22, -6.0, 180.0)
		Vfx.burst(self, at + Vector3(0, 0.7, 0), Color("c29a57"), 30, 2.5, 0.7, 0.16, -5.0, 180.0)

## Castle shows the capture: it shivers while an enemy holds Interact, flag whips faster, and
## after the capture it sinks to a low mound until the next round resets it.
func _refresh_castle(team: int, prog: float, delta: float) -> void:
	var castle := _castles[team]
	var flag := _flags[team]
	var phase := host.round_flow.phase
	if _crumble[team] >= 0.0 and (phase == RoundFlow.Phase.COUNTDOWN or phase == RoundFlow.Phase.INTRO):
		_crumble[team] = -1.0 # a new round: rebuilt
	if _crumble[team] >= 0.0:
		_crumble[team] += delta
		var k := clampf(_crumble[team] / 0.9, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		castle.scale = Vector3(1.0 + 0.25 * k, 1.0 - 0.8 * k, 1.0 + 0.25 * k)
		castle.rotation.z = 0.0
		if flag:
			flag.visible = false
		return
	castle.scale = Vector3.ONE
	castle.rotation.z = sin(_t * 38.0) * 0.012 * prog if prog > 0.0 else 0.0
	if flag:
		flag.visible = true
		flag.rotation.y = sin(_t * (3.0 + 9.0 * prog) + team) * 0.18
