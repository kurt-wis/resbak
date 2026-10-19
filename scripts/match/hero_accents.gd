extends Node3D

## Character-specific moving accents, bounded meshes, no gameplay or visibility authority.
var hero: Hero
var trails: Array[MeshInstance3D] = []
var age := 0.0
var towel: Node3D
var ward_sparks: Array[MeshInstance3D] = []
var shout_age := 10.0
var face: FaceRig
var held_packet: Node3D

func setup(value: Hero) -> void:
	hero = value
	name = "SkillAccents"
	if hero.data.id == "jm":
		towel = preload("res://scripts/match/jm_towel_motion.gd").new()
		add_child(towel)
		towel.setup(hero)
	if hero.data.id == "nathan":
		held_packet = UboPacket._build_pouch()
		add_child(held_packet)
		held_packet.visible = false
	if hero.data.id == "nene":
		face = FaceRig.new()
		face.attach("nene", hero.visual.model, load("res://data/home_diorama.tres"))
		hero.host.event.connect(_on_event)
		for i in range(4):
			var spark := MeshInstance3D.new()
			var shape := SphereMesh.new()
			shape.radius = 0.025
			shape.height = 0.08
			shape.radial_segments = 6
			shape.rings = 3
			spark.mesh = shape
			spark.material_override = Vfx.flat_material(Color("ffc3e4"))
			add_child(spark)
			ward_sparks.append(spark)
	for i in range(3):
		var placeholder := Vfx.ribbon(PackedVector3Array([Vector3.ZERO, Vector3.FORWARD]), 0.03, Color(0.7, 0.93, 1, 0.65))
		placeholder.visible = false
		add_child(placeholder)
		trails.append(placeholder)

func _process(delta: float) -> void:
	if hero == null or hero.host.paused:
		return
	age += delta
	if held_packet:
		var skill := hero.skills[1]
		held_packet.visible = skill.active and hero.is_free() and hero.host.tick - skill.cast_tick >= RB.ticks(float(skill.v("ubo_prepare_time")) * 0.35)
		var hand := hero.visual._skel.find_bone(hero.visual._bone_by_tail("RightHand"))
		var palm_basis := hero.visual._skel.global_basis * hero.visual._skel.get_bone_global_pose(hand).basis
		held_packet.global_position = hero.visual.hand_position(0) + palm_basis.y.normalized() * 0.075
	_update_nene(delta)
	var wind := hero.data.id == "tutoy" and hero.active_skill() != null
	var blowing := hero.data.id == "inday" and hero.skills[0].active
	for i in range(trails.size()):
		trails[i].visible = (wind or blowing) and hero.is_free()
		if not trails[i].visible:
			continue
		var dir := hero.aim if blowing else RB.flat(hero.velocity).normalized()
		if dir.length_squared() < 0.01:
			dir = hero.facing
		var side := dir.cross(Vector3.UP)
		var points := PackedVector3Array()
		var length := float(hero.skills[0].v("ihip_length")) if blowing else 1.8
		if blowing:
			length = hero.skills[0].lane_length()
		for j in range(17):
			var t := float(j) / 16.0
			var offset := sin(t * TAU + age * 5.0 + i * 2.0) * 0.11
			points.append(dir * (length * t if blowing else -length * t) + side * (offset + (i - 1) * 0.3) + Vector3.UP * (0.2 + i * 0.18 + sin(t * PI) * 0.13))
		var fresh := Vfx.ribbon(points, 0.035, Color(0.75, 0.94, 1.0, 0.65))
		trails[i].mesh = fresh.mesh
		fresh.free()

func _on_event(kind: String, data: Dictionary) -> void:
	if kind == "sigaw" and data.get("hero") == hero:
		shout_age = 0.0

func _update_nene(delta: float) -> void:
	if hero.data.id != "nene":
		return
	shout_age += delta
	face.set_frames(face.data.mouth_wide if shout_age < 0.5 else face.data.mouth_closed, face.data.lid_open)
	for i in range(ward_sparks.size()):
		var spark := ward_sparks[i]
		spark.visible = hero.is_warded()
		var angle := age * 2.5 + i * TAU / ward_sparks.size()
		spark.position = Vector3(cos(angle) * 0.42, 0.9 + sin(angle * 2.0) * 0.18, sin(angle) * 0.42)
		spark.rotation.z = angle
