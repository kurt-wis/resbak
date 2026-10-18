extends SceneTree
func _initialize():
 for name in ["bawal_umihi_dito","malabanan_123_45_67","meme_67_basketball"]:
  var image=Image.load_from_file("res://assets/decals/"+name+".png")
  print(name," alpha mode ",image.detect_alpha()," corners ",image.get_pixel(0,0).a," ",image.get_pixel(image.get_width()/2,0).a," ",image.get_pixel(0,image.get_height()/2).a)
 quit()
