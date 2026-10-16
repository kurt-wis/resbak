extends SceneTree
func _initialize():
 var image=Image.load_from_file("C:/Users/Kurtl/.codex/attachments/750a2474-afb8-418c-930b-779b1880a020/image-1.png")
 for span in [[90,230],[1130,1300]]:
  var rows=[]
  for y in range(640,765):
   var pixels=[]
   for x in range(span[0],span[1]):
    var c=image.get_pixel(x,y)
    if c.r>.74 and c.g>.70 and c.b>.58 and c.r-c.b<.25:pixels.append(x)
   if pixels.size()>22:rows.append([y,pixels[0],pixels[-1]])
  var groups=[]
  for row in rows:
   if groups.is_empty() or row[0]>groups[-1][-1][0]+1:groups.append([])
   groups[-1].append(row)
  for group in groups:
   var middle=group[group.size()/2]
   print("CROSSWALK ",span," y ",group[0][0],"..",group[-1][0]," midpoint ",middle)
 quit()
