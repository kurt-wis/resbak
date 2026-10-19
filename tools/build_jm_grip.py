"""Give JM's unweighted finger joint a real hinge and reviewed distal finger weights.
Run after build_motion_pass -- jm; edits only the staged GLB until QA/promotion.
"""
import bpy, json, sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_heroes as base
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=24
path=ROOT/'renders/motion_pass/jm.glb'
bpy.ops.import_scene.gltf(filepath=str(path))
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.data.objects if o.type=='MESH' and len(o.vertex_groups))
actions=list(bpy.data.actions)
while arm.animation_data.nla_tracks:arm.animation_data.nla_tracks.remove(arm.animation_data.nla_tracks[0])
arm.animation_data.action=None
name='mixamorig:RightHandMiddle1'
handname='mixamorig:RightHand'
bpy.context.view_layer.objects.active=arm;arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bone=arm.data.edit_bones[name]
bone.parent=arm.data.edit_bones[handname]
bone.matrix=bone.parent.matrix @ Matrix.Translation(Vector((0,.12,-.035)))
bone.length=.08
bpy.ops.object.mode_set(mode='OBJECT')
weights={int(k):v for k,v in json.loads((ROOT/'tools/data/jm_finger_grip_weights.json').read_text()).items()}
hand=mesh.vertex_groups[handname];finger=mesh.vertex_groups[name]
for index,fade in weights.items():
    vertex=mesh.data.vertices[index]
    total=sum(g.weight for g in vertex.groups if g.group in (hand.index,finger.index))
    hand.add([index],total*(1-fade),'REPLACE')
    finger.add([index],total*fade,'REPLACE')
for action in actions:
    arm.animation_data.action=action
    start,end=map(lambda x:int(round(x)),action.frame_range)
    for frame in range(start,end+1):
        bpy.context.scene.frame_set(frame)
        pb=arm.pose.bones[name];pb.rotation_mode='QUATERNION'
        pb.location=Vector();pb.rotation_quaternion=Quaternion((0,0,-1),1.65);pb.scale=Vector((1,1,1))
        for channel in ('location','rotation_quaternion','scale'):pb.keyframe_insert(channel,frame=frame)
    track=arm.animation_data.nla_tracks.new();track.name=action.name
    track.strips.new(action.name,start,action)
arm.animation_data.action=None
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True)
for track in arm.animation_data.nla_tracks:track.mute=True
base.render_moves_sheet(arm,'jm',['Idle','Running','Tag'],per_row=1,tile=(220,260),suffix='grip')
print('JM_GRIP',len(weights),'reviewed distal vertices',flush=True)
