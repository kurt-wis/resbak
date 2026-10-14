extends SceneTree
func _initialize() -> void:
	var court = load("res://scenes/barangay_court.tscn").instantiate()
	court.scene_file_path = ""
	for body in court.get_node("StreetDetails").get_children():
		if String(body.name).begins_with("StreetTricycle") and String(body.name).ends_with("Body"):
			body.free()
	var packed := PackedScene.new()
	packed.pack(court)
	ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")
	quit()
