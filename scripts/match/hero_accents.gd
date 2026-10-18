extends Node3D

## Character-specific moving accents, bounded meshes, no gameplay or visibility authority.
var hero: Hero
var trails: Array[MeshInstance3D] = []
var age := 0.0
var towel: Node3D

func setup(value: Hero) -> void:
	hero = value
	name = "SkillAccents"
	if hero.data.id == "jm":
		towel = preload("res://scripts/match/jm_towel_motion.gd").new()
		add_child(towel)
		towel.setup(hero)
	for i in range(3):
		var placeholder := Vfx.ribbon(PackedVector3Array([Vector3.ZERO, Vector3.FORWARD]), 0.03, Color(0.7, 0.93, 1, 0.65))
		placeholder.visible = false
		add_child(placeholder)
		trails.append(placeholder)

func _process(delta: float) -> void:
	if hero == null or hero.host.paused:
		return
	age += delta
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
