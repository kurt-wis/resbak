"""Build the Meshy Tamaraw into a compact animated projection. Run in background Blender.
Input source_art/props/tamaraw.glb; output assets/props/tamaraw_spirit.glb.
The engine replaces its material with the spectral shader; the source is preserved.
"""
import bpy, bmesh, math, os, sys, json
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "source_art/props/tamaraw.glb"))
mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
mesh.name = 'Tamaraw'
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bm = bmesh.new(); bm.from_mesh(mesh.data)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.00001)
bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=0.000001)
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.to_mesh(mesh.data); bm.free()
lo = Vector(tuple(min(v.co[i] for v in mesh.data.vertices) for i in range(3)))
hi = Vector(tuple(max(v.co[i] for v in mesh.data.vertices) for i in range(3)))
factor = 3.3 / (hi.y-lo.y)
for v in mesh.data.vertices:
    v.co = (v.co - Vector(((hi.x+lo.x)/2,(hi.y+lo.y)/2,lo.z))) * factor
dec = mesh.modifiers.new('ProjectionBudget','DECIMATE'); dec.ratio = min(1, 4800 / len(mesh.data.polygons))
bpy.ops.object.modifier_apply(modifier=dec.name)
mesh.data.materials.clear()
mat=bpy.data.materials.new('M_TamarawSource'); mat.diffuse_color=(1,.65,.1,1)
mesh.data.materials.append(mat)
for p in mesh.data.polygons: p.use_smooth=True
arm_data=bpy.data.armatures.new('TamarawRig')
arm=bpy.data.objects.new('TamarawRig',arm_data); bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm; mesh.select_set(False); arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None):
    b=arm_data.edit_bones.new('mixamorig:'+name); b.head=head; b.tail=tail
    if parent: b.parent=arm_data.edit_bones['mixamorig:'+parent]
    return b
bone('Root',(0,0,0),(0,0,.25))
bone('Hips',(0,.65,.8),(0,.2,.85),'Root')
bone('Spine',(0,.2,.85),(0,-.2,.85),'Hips')
bone('Spine1',(0,-.2,.85),(0,-.45,.9),'Spine')
bone('Spine2',(0,-.45,.9),(0,-.65,.95),'Spine1')
bone('Neck',(0,-.65,.95),(0,-.9,1.0),'Spine2')
bone('Head',(0,-.9,1.0),(0,-1.3,.9),'Neck')
bone('Tail',(0,.9,.9),(0,1.1,.65),'Hips')
bone('Tail1',(0,1.1,.65),(0,1.3,.45),'Tail')
bone('Tail2',(0,1.3,.45),(0,1.5,.35),'Tail1')
for side,x in [('Left',.24),('Right',-.24)]:
    for limb,y,parent in [('Front',-.55,'Spine2'),('Back',.65,'Hips')]:
        prefix=side+limb
        bone(prefix+'Leg',(x,y,.76),(x,y,.4),parent)
        bone(prefix+'Shin',(x,y,.4),(x,y,.12),prefix+'Leg')
        bone(prefix+'Hoof',(x,y,.12),(x,y-.12,.04),prefix+'Shin')
bpy.ops.object.mode_set(mode='OBJECT')
groups={b.name:mesh.vertex_groups.new(name=b.name) for b in arm.data.bones}
for v in mesh.data.vertices:
    x,y,z=v.co
    if y < -.73: weights={'Head':1.0}
    elif y > 1.02: weights={'Tail':1.0}
    elif z < .68:
        side='Left' if x>0 else 'Right'; limb='Front' if y<0 else 'Back'
        if z<.15: weights={side+limb+'Hoof':1.0}
        elif z<.43:
            k=max(0,min(1,(z-.25)/.18)); weights={side+limb+'Shin':1-k,side+limb+'Leg':k}
        else:
            k=max(0,min(1,(z-.5)/.18)); weights={side+limb+'Leg':1-k,'Spine2' if limb=='Front' else 'Hips':k}
    else: weights={'Spine2' if y<0 else 'Hips':1.0}
    for n,w in weights.items():
        if w>0: groups['mixamorig:'+n].add([v.index],w,'REPLACE')
mod=mesh.modifiers.new('Skin','ARMATURE'); mod.object=arm; mesh.parent=arm
arm.animation_data_create()
for f in range(25):
    bpy.context.scene.frame_set(f)
    phase=2*math.pi*f/24
    for pb in arm.pose.bones:
        pb.rotation_mode='XYZ'; pb.rotation_euler=(0,0,0); pb.location=(0,0,0)
        if pb.name.endswith('Leg'):
            sign=1 if ('LeftFront' in pb.name or 'RightBack' in pb.name) else -1
            pb.rotation_euler.x=.34*math.sin(phase)*sign
        elif pb.name.endswith('Shin'): pb.rotation_euler.x=.12+.2*max(0,math.cos(phase))
        elif pb.name.endswith('Head'): pb.rotation_euler.x=.09+.035*math.sin(phase*2)
        elif pb.name.endswith('Hips'): pb.location.z=.025*(1-math.cos(phase*2))
        elif 'Tail' in pb.name: pb.rotation_euler.z=.08*math.sin(phase)
        pb.keyframe_insert('location',frame=f); pb.keyframe_insert('rotation_euler',frame=f); pb.keyframe_insert('scale',frame=f)
act=arm.animation_data.action; act.name='Spirit_Charge'
tr=arm.animation_data.nla_tracks.new(); tr.name='Spirit_Charge'; tr.strips.new('Spirit_Charge',0,act)
arm.animation_data.action=None
os.makedirs(os.path.join(ROOT,'assets/props'),exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets/props/tamaraw_spirit.glb'),export_format='GLB',export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True)
sys.path.insert(0,os.path.join(os.path.expanduser('~'),'.codex/skills/blender-asset-qa/scripts'))
import qa_check
report=qa_check.run(objects=[mesh.name],profile='game')
os.makedirs(os.path.join(ROOT,'renders/qc'),exist_ok=True)
with open(os.path.join(ROOT,'renders/qc/tamaraw_spirit_geometry.json'),'w') as f: json.dump(report,f,indent=2,default=str)
print('TAMARAW',len(mesh.data.polygons),'triangles',list(mesh.dimensions),json.dumps(report,default=str),flush=True)
