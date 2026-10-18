extends Node3D

## Persistent feedback reads real host timers. Hidden heroes never expose their labels.
var hero: Hero
var viewer: Hero
var label: Label3D
var stars: Array[Label3D] = []
var age := 0.0

func setup(value: Hero) -> void:
	hero = value
	name = "StatusFeedback"
	position.y = hero.data.model_height + 0.58
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.0035
	label.outline_size = 8
	add_child(label)
	for i in range(3):
		var star := Label3D.new()
		star.text = "✦"
		star.font_size = 54
		star.pixel_size = 0.004
		star.modulate = Color("ffe182")
		star.outline_size = 5
		star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(star)
		stars.append(star)

func _process(delta: float) -> void:
	if hero == null:
		return
	if hero.host.paused:
		return
	age += delta
	var captions: PackedStringArray = []
	if hero.is_free():
		if hero.stun_ticks > 0:
			captions.append("✦")
		if hero.visual.tamaraw_miss_active():
			captions.append("↻")
		if hero.blind_ticks > 0:
			captions.append("◉")
		if hero.hallucinate_ticks > 0:
			captions.append("↻")
		if hero.strongest_slow() > 0.0:
			captions.append("↓")
		for object in hero.host.objects:
			if object is UboCloud and object.contains(hero.global_position):
				captions.append("≋")
				break
	label.text = " ".join(captions)
	label.modulate = Color("ffe6a3") if hero.stun_ticks > 0 else Color("e5efff")
	for i in range(stars.size()):
		stars[i].visible = hero.visual.tamaraw_miss_active()
		var angle := age * 3.0 + TAU * float(i) / stars.size()
		stars[i].position = Vector3(cos(angle) * 0.34, -0.3 + sin(angle * 2.0) * 0.04, sin(angle) * 0.22)
