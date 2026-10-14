extends SceneTree
func _initialize() -> void:
 var image := Image.load_from_file("res://assets/environment/painted_concrete_tile.png")
 image.generate_mipmaps()
 var texture := ImageTexture.create_from_image(image)
 texture.resource_name = "PaintedConcreteTile"
 ResourceSaver.save(texture,"res://assets/environment/painted_concrete_tile.res")
 quit()
