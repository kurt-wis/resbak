import bpy, json, os
from pathlib import Path
R=Path(__file__).resolve().parents[1]
for name,path in [('jm','source_art/heroes/jm_revised.glb'),('inday','assets/characters/inday.glb')]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(R/path))
    arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    print('RIG',name,json.dumps([{'name':b.name,'head':list(arm.matrix_world@b.head_local),'tail':list(arm.matrix_world@b.tail_local),'parent':b.parent.name if b.parent else None} for b in arm.data.bones]),flush=True)
    if name=='inday':
        for o in bpy.data.objects:
            if o.type=='MESH' and len(o.vertex_groups):
                print('INDAY',o.name,'bounds',[[min((o.matrix_world@v.co)[i] for v in o.data.vertices),max((o.matrix_world@v.co)[i] for v in o.data.vertices)] for i in range(3)],flush=True)
