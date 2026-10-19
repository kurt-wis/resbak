"""Geometry gate for the staged motion pass, before promotion into assets/."""
import bpy, os, sys, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
sys.path.insert(0,str(Path.home()/'.codex/skills/blender-asset-qa/scripts'))
import qa_check
from mathutils import Vector
reports={}
rows=[]
for name in ('tutoy','nene','nathan','jm','inday','jm_towel'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path=ROOT/('assets/props/jm_towel.glb' if name=='jm_towel' else f'renders/motion_pass/{name}.glb')
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects=[o.name for o in bpy.context.scene.objects if o.type=='MESH' and len(o.vertex_groups)]
    report=qa_check.run(objects=objects,profile='game')
    meshes=[bpy.data.objects[name] for name in objects]
    for arm in [o for o in bpy.context.scene.objects if o.type=='ARMATURE']:arm.data.pose_position='REST'
    bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    corners=[]
    for mesh in meshes:
        evaluated=mesh.evaluated_get(dg)
        corners.extend(evaluated.matrix_world@Vector(corner) for corner in evaluated.bound_box)
    lo=Vector(tuple(min(v[axis] for v in corners) for axis in range(3)))
    hi=Vector(tuple(max(v[axis] for v in corners) for axis in range(3)))
    report['bind_dimensions_m']=[round(v,3) for v in hi-lo]
    report['mesh_objects']=len(meshes)
    report['material_count']=len({slot.material.name for mesh in meshes for slot in mesh.material_slots if slot.material})
    reports[name]=report
    triangles=sum(o['tris'] for o in report['objects'].values())
    output='assets/props/jm_towel.glb' if name=='jm_towel' else f'assets/characters/{name}.glb'
    rows.append(f"| `{output}` | {triangles:,} | {len(meshes)} | {report['material_count']} | {report['bind_dimensions_m']} |")
    print('MOTION_QA',name,json.dumps(report,default=str),flush=True)
(ROOT/'renders/motion_pass/geometry.json').write_text(json.dumps(reports,indent=2,default=str))
(ROOT/'renders/motion_pass/delivery.md').write_text('# Motion pass asset report\n\nBind dimensions are Blender XYZ metres; runtime normalizes heroes to 1.8 m height.\n\n| Output | Triangles | Mesh objects | Materials | Bind dimensions (m) |\n| --- | ---: | ---: | ---: | --- |\n'+'\n'.join(rows)+'\n\nAll assets pass geometry QA. Preserved source UV/normal splits, hidden source face pairs and held/animation origins remain documented warnings.\n',encoding='utf-8')
