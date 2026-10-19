"""Repair highlighted braid weights and add a Head-owned four-joint secondary chain.
Run after build_motion_pass; inputs/outputs stay in renders/motion_pass until reviewed.
"""
import bpy, sys, json, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from build_hero_polish import key_pose
import build_heroes as base

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=24
path=ROOT/'renders/motion_pass/inday.glb'
bpy.ops.import_scene.gltf(filepath=str(path))
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.data.objects if o.type=='MESH' and len(o.vertex_groups)>0)
while arm.animation_data.nla_tracks:
    arm.animation_data.nla_tracks.remove(arm.animation_data.nla_tracks[0])
arm.animation_data.action=None
for clip_name in ('Walking','Running'):
    old=bpy.data.actions.get(clip_name)
    if old:bpy.data.actions.remove(old)
table={
    'Walking':base.clip('meshy/tutoy_moves.glb','Quick_Walk',trim=(0,1),loop=True,plant=True),
    'Running':base.clip('meshy/tutoy_moves.glb','Lean_Forward_Sprint',loop=True),
}
frames=base.retarget_table(arm,table)
base.bake_planted(arm,'Walking',frames['Walking'])
base.bake_grounded(arm,'Running',frames['Running'])
actions=list(bpy.data.actions)
arm.animation_data.action=None
for pb in arm.pose.bones:pb.matrix_basis.identity()
bpy.context.view_layer.update()

# Reviewed original vertex IDs: texture seams are preserved and blouse boundaries
# taper over a 4.5 cm geodesic band. Never infer hair from a broad dark-pixel volume.
fades={int(k):v for k,v in json.loads((ROOT/'tools/data/inday_hair_mask.json').read_text()).items()}
selected=set(fades)
assert len(mesh.data.vertices)==7877, 'Hair mask must be re-reviewed for a new mesh'
for index,expected in [(59,(-.15149,.09386,1.10888)),(5596,(-.17768,.11569,.88711))]:
    assert (mesh.matrix_world@mesh.data.vertices[index].co-Vector(expected)).length<.002, 'Hair mask index registration changed'

inv=arm.matrix_world.inverted()
bpy.context.view_layer.objects.active=arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
names=[]
for i in range(4):
    name=f'mixamorig:Hair{i+1}'
    b=arm.data.edit_bones.new(name)
    b.head=inv@Vector((-.12,.21,1.36-i*.14))
    b.tail=inv@Vector((-.12,.21,1.22-i*.14))
    b.parent=arm.data.edit_bones.get(names[-1] if names else 'mixamorig:Head')
    names.append(name)
bpy.ops.object.mode_set(mode='OBJECT')
groups=[mesh.vertex_groups.new(name=name) for name in names]
head=mesh.vertex_groups['mixamorig:Head']
for index in selected:
    v=mesh.data.vertices[index]
    p=mesh.matrix_world@v.co
    # Lift the braid away from the blouse. Scalp roots remain exactly in place.
    shift=.075*fades[index]
    v.co += mesh.matrix_world.inverted().to_3x3()@Vector((0,shift,0))
    for group in mesh.vertex_groups:group.remove([index])
    at=max(0,min(3,(1.36-p.z)/.14))
    a=int(at);b=min(3,a+1);t=at-a
    rootfade=fades[index]
    head.add([index],1-rootfade,'REPLACE')
    groups[a].add([index],(1-t)*rootfade,'REPLACE')
    if b!=a:groups[b].add([index],t*rootfade,'REPLACE')

# New joints carry identity local poses in every full-skeleton action. Runtime physics
# modifies only these Head descendants, after arm extension and before skinning.
for action in actions:
    arm.animation_data.action=action
    start,end=map(lambda x:int(round(x)),action.frame_range)
    for frame in range(start,end+1):
        bpy.context.scene.frame_set(frame)
        for name in names:
            pb=arm.pose.bones[name];pb.matrix_basis.identity();pb.rotation_mode='QUATERNION'
            for channel in ('location','rotation_quaternion','scale'):pb.keyframe_insert(channel,frame=frame)
    track=arm.animation_data.nla_tracks.new();track.name=action.name
    track.strips.new(action.name,start,action)
arm.animation_data.action=None
(ROOT/'renders/motion_pass/inday_hair_selection.json').write_text(json.dumps(sorted(selected)))
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True)
for track in arm.animation_data.nla_tracks:track.mute=True
base.render_moves_sheet(arm,'inday',['Idle','Walking','Sagip'],per_row=1,tile=(220,260),suffix='hair')
print('HAIR_REPAIR',len(selected),'vertices',len(arm.data.bones),'bones',flush=True)
