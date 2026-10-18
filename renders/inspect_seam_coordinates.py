import bpy
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='E:/RESBAK/resbak/assets/characters/nathan.glb')
o=next(o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.vertex_groups)>0)
p=Vector((-.2401685,-.1291046,1.4462534))
print('nearest',sorted([(round((o.matrix_world@v.co-p).length,5),v.index,list(v.co),list(o.matrix_world@v.co)) for v in o.data.vertices])[:4])
print('tri',[(i,list(o.data.polygons[i].vertices)) for i in [1187,10123]])
