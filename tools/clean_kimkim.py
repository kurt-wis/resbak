"""Remove source zero-area pouch triangles and weld texture seam duplicates."""
import bpy,bmesh
from pathlib import Path
R=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(R/'assets/props/kimkim.glb'))
for ob in [o for o in bpy.context.scene.objects if o.type=='MESH']:
    bm=bmesh.new();bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(ob.data);bm.free()
    print('CLEAN KIMKIM',len(ob.data.vertices),len(ob.data.polygons),flush=True)
bpy.ops.export_scene.gltf(filepath=str(R/'renders/revision_assets/kimkim.glb'),export_format='GLB',export_animations=False)
