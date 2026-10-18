extends SceneTree
func median_at(im: Image,p: Vector2i)->Array:
 var r=[];var g=[];var b=[]
 for x in range(p.x-4,p.x+5):
  for y in range(p.y-4,p.y+5):
   var c=im.get_pixel(x,y);r.append(c.r*255);g.append(c.g*255);b.append(c.b*255)
 r.sort();g.sort();b.sort();return [r[40],g[40],b[40]]
func _initialize():
 var source=Image.load_from_file("C:/Users/Kurtl/.codex/attachments/750a2474-afb8-418c-930b-779b1880a020/image-1.png")
 var render=Image.load_from_file("C:/Users/Kurtl/Documents/Codex/2026-10-13/files-mentioned-by-the-user-agawan/outputs/structure-overview.png")
 for point in [Vector2i(540,315),Vector2i(840,315),Vector2i(1015,435)]:
  print("COURT PALETTE ",point," source=",median_at(source,point)," render=",median_at(render,Vector2i(point.x*1280./1376,point.y*720./768)))
 quit()
