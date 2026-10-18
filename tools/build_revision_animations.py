"""Author prepared Hampas, committed strikes, one-handed Ubo and coughs on full rigs.
Also adapts the supplied JM model to Mixamo names and repairs Inday's hair weights.
Run Blender -b --python tools/build_revision_animations.py -- [hero ids].
"""
import bpy, os, sys, math, json
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_heroes as base
from build_hero_polish import key_pose
R=Path(base.PROJ)

def orient(arm, tail, direction, weight=1):
    pb=arm.pose.bones.get('mixamorig:'+tail)
    if pb is None:return
    m=pb.matrix.copy(); q=m.to_quaternion()
    current=q@Vector((0,1,0))
    turn=Quaternion().slerp(current.rotation_difference(Vector(direction).normalized()),weight)
    pb.matrix=Matrix.Translation(m.translation)@(turn@q).to_matrix().to_4x4()
    bpy.context.view_layer.update()

def author(arm,name,mode):
    idle=bpy.data.actions['Idle'];arm.animation_data.action=idle
    bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
    neutral={p.name:p.matrix_basis.copy() for p in arm.pose.bones}
    old=bpy.data.actions.get(name)
    if old:bpy.data.actions.remove(old)
    arm.animation_data.action=None
    count=24 if mode=='prepare' else (17 if mode=='cough' else 13)
    for f in range(count+1):
        bpy.context.scene.frame_set(f)
        for pb in arm.pose.bones:pb.matrix_basis=neutral[pb.name]
        bpy.context.view_layer.update();u=f/count
        if mode in ('prepare','tag','throw'):
            # Prepared elbow out, forearm gathered near the shoulder. Contact leads
            # with the right shoulder and extends the actual hand/towel forward.
            strike=0 if mode=='prepare' else math.exp(-((u-.60)/.19)**2)
            recover=0 if mode=='prepare' else max(0,(u-.78)/.22)
            if mode=='throw':
                strike=math.exp(-((u-.04)/.22)**2)
                a=Vector((-.4,.12,.9)).lerp(Vector((-.12,-1,.12)),strike)
                b=Vector((.3,-.2,.9)).lerp(Vector((0,-1,-.15)),strike)
            else:
                a=Vector((-.8,-.15,.6)).lerp(Vector((-.08,-1,.05)),strike)
                b=Vector((.5,-.1,.8)).lerp(Vector((.08,-1,-.02)),strike)
            for tail,d in [('RightArm',a),('RightForeArm',b),('RightHand',b)]:
                orient(arm,tail,d,1-recover)
            spine=arm.pose.bones.get('mixamorig:Spine2')
            if spine:
                spine.rotation_quaternion=spine.rotation_quaternion@Quaternion((0,1,0),(.12-.26*strike)*(1-recover))
            if mode=='prepare':
                spine.location.z+=.002*math.sin(TAU*u)
        else:
            # Hand covers mouth, elbow held clear of the ribs; two small chest coughs.
            envelope=math.sin(math.pi*u)**.65
            orient(arm,'RightArm',(-.85,-.3,-.35),envelope)
            orient(arm,'RightForeArm',(.6,-.45,.9),envelope)
            orient(arm,'RightHand',(.15,-.4,.8),envelope)
            spine=arm.pose.bones.get('mixamorig:Spine2')
            if spine:spine.rotation_quaternion=spine.rotation_quaternion@Quaternion((1,0,0),.12*envelope*(.5+.5*math.sin(u*math.pi*6)))
        key_pose(arm,f)
    arm.animation_data.action.name=name
    return name

TAU=2*math.pi
def new_jm():
    source=R/'source_art/heroes/jm_shoulder_source.glb'
    if not source.exists():source=R/'source_art/heroes/jm_revised.glb'
    library=R/'source_art/heroes/jm_animation_library.glb'
    if not library.exists():library.write_bytes((R/'assets/characters/jm.glb').read_bytes())
    bpy.ops.import_scene.gltf(filepath=str(source))
    arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    mapping={0:'Root',1:'Hips',4:'Spine',3:'Spine1',2:'Spine2',14:'Neck',13:'Head',18:'RightArm',17:'RightForeArm',16:'RightHand',15:'RightHandMiddle1',22:'LeftArm',21:'LeftForeArm',20:'LeftHand',19:'LeftHandMiddle1',8:'LeftUpLeg',7:'LeftLeg',6:'LeftFoot',5:'LeftToeBase',12:'RightUpLeg',11:'RightLeg',10:'RightFoot',9:'RightToeBase'}
    if arm.data.bones.get('Bone_000'):
        for n,tail in mapping.items():arm.data.bones[f'Bone_{n:03}'].name='mixamorig:'+tail
    else:
        for old,new in [('Bone_023','LeftHandMiddle1'),('Bone_024','RightHandMiddle1'),('headfront','HeadFront')]:
            if arm.data.bones.get(old):arm.data.bones[old].name='mixamorig:'+new
    if arm.animation_data:
        arm.animation_data_clear()
    for action in list(bpy.data.actions):bpy.data.actions.remove(action)
    # Blender propagates vertex-group names when bones are renamed.
    names=json.loads((R/'renders/revision_jm_clips.json').read_text()) if (R/'renders/revision_jm_clips.json').exists() else None
    if names is None:
        before=set(bpy.data.objects);acts=set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=str(library))
        names=[a.name for a in bpy.data.actions if a not in acts]
        for o in list(bpy.data.objects):
            if o not in before:bpy.data.objects.remove(o,do_unlink=True)
        for a in list(bpy.data.actions):
            if a not in acts:bpy.data.actions.remove(a)
        (R/'renders/revision_jm_clips.json').write_text(json.dumps(names))
    # retarget_table resolves file names under mocap; use a repository-relative route.
    table={n:base.clip('../heroes/jm_animation_library.glb',n,loop=n in ('Idle','Walking','Running','TagCharge','Tamaraw')) for n in names}
    if source.name=='jm_shoulder_source.glb':
        table['Running']=base.clip('../heroes/jm_shoulder_source.glb','Running',loop=True)
    frames=base.retarget_table(arm,table)
    arm.animation_data_create()
    for n in names:base.bake_grounded(arm,n,frames[n])
    base.rigid_head(arm)
    # SmartRig puts its Head pivot high in this stylized skull. The whole face,
    # including the lower cheeks/jaw, must follow Head so Home face cards remain
    # registered when the neck and head rotate independently in sitting clips.
    for ob in [o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.vertex_groups)]:
        group=ob.vertex_groups['mixamorig:Head']
        for vertex in ob.data.vertices:
            point=ob.matrix_world@vertex.co
            if source.name=='jm_revised.glb' and point.z>1.30 and abs(point.x)<.30:
                for g in ob.vertex_groups:g.remove([vertex.index])
                group.add([vertex.index],1.0,'REPLACE')
    return arm,names

def carry_pose(arm,name):
    """Keep the gait/hips while the right hand lightly holds the shoulder towel."""
    act=bpy.data.actions[name];arm.animation_data.action=act
    start,end=map(lambda x:int(round(x)),act.frame_range)
    snapshots=[]
    for f in range(start,end+1):
        bpy.context.scene.frame_set(f)
        snapshots.append({p.name:p.matrix_basis.copy() for p in arm.pose.bones})
    arm.animation_data.action=None
    bpy.data.actions.remove(act)
    output=None
    for f,pose in zip(range(start,end+1),snapshots):
        arm.animation_data.action=None
        bpy.context.scene.frame_set(f)
        for p in arm.pose.bones:p.matrix_basis=pose[p.name]
        bpy.context.view_layer.update()
        # Anatomical right is -X, forward is -Y. Elbow stays below shoulder,
        # forearm folds towards the chest, palm softly curled around the front end.
        for tail,d in [('RightArm',(-.38,-.18,-.90)),('RightForeArm',(.25,-.75,.38)),('RightHand',(.10,-.90,.30))]:
            orient(arm,tail,d)
        finger=arm.pose.bones.get('mixamorig:RightHandMiddle1')
        if finger:finger.rotation_quaternion=finger.rotation_quaternion@Quaternion((1,0,0),.65)
        arm.animation_data.action=output
        key_pose(arm,f)
        output=arm.animation_data.action
    arm.animation_data.action.name=name


def dizzy_pose(arm):
    arm.animation_data.action=bpy.data.actions['Idle']
    bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
    neutral={p.name:p.matrix_basis.copy() for p in arm.pose.bones}
    arm.animation_data.action=None
    old=bpy.data.actions.get('Tamaraw_Miss')
    if old:bpy.data.actions.remove(old)
    for f in range(13):
        bpy.context.scene.frame_set(f);u=f/12
        for p in arm.pose.bones:p.matrix_basis=neutral[p.name]
        envelope=math.sin(math.pi*u)
        for tail,axis,angle in [('Spine2',(0,1,0),.15*math.sin(u*math.pi*3)),('Head',(0,1,0),.20*math.sin(u*math.pi*4)),('Neck',(1,0,0),.15)]:
            p=arm.pose.bones.get('mixamorig:'+tail)
            if p:p.rotation_quaternion=p.rotation_quaternion@Quaternion(axis,angle*envelope)
        bpy.context.view_layer.update()
        orient(arm,'LeftArm',(.55,-.1,-.6),envelope)
        orient(arm,'LeftForeArm',(-.3,-.35,.8),envelope)
        key_pose(arm,f)
    arm.animation_data.action.name='Tamaraw_Miss'


def repair_hair(arm):
    # Only dark texture samples in the head/back-hair volume. Blouse/skin vertices
    # are excluded even where they share triangles with the long hair at the shoulder.
    head=arm.data.bones['mixamorig:Head']; neck=arm.data.bones['mixamorig:Neck']
    headz=(arm.matrix_world@head.head_local).z
    neckz=(arm.matrix_world@neck.head_local).z
    changed=0
    for ob in [o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.vertex_groups)]:
        mat=ob.data.materials[0];image=next(n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
        pixels=list(image.pixels);w,h=image.size;uv=ob.data.uv_layers.active.data
        dark=set()
        for loop in ob.data.loops:
            u,v=uv[loop.index].uv;x=min(w-1,max(0,int(u*w)));y=min(h-1,max(0,int(v*h)));i=(y*w+x)*4
            if max(pixels[i:i+3])<.20:dark.add(loop.vertex_index)
        hg=ob.vertex_groups['mixamorig:Head']
        for v in ob.data.vertices:
            p=ob.matrix_world@v.co
            if v.index in dark and p.z>neckz-.46 and abs(p.x)<.32 and p.y>-.08:
                for g in ob.vertex_groups:g.remove([v.index])
                hg.add([v.index],1.0,'REPLACE');changed+=1
    print('HAIR vertices corrected',changed,'head',headz,'neck',neckz,flush=True)
    # Meshy also leaves arm weights on the torso/back below the braid. A stretching
    # arm magnifies even a small spill into long triangles, so confine its weights
    # to the actual rest-pose limb volume rather than relying on texture alone.
    joints=[arm.matrix_world@arm.data.bones['mixamorig:'+n].head_local for n in ('RightArm','RightForeArm','RightHand')]
    def segment_distance(p,a,b):
        d=b-a;t=max(0,min(1,(p-a).dot(d)/d.length_squared))
        return (p-(a+d*t)).length
    spill=0
    for ob in [o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.vertex_groups)]:
        torso=ob.vertex_groups['mixamorig:Spine2']
        arm_groups={g.index:g for g in ob.vertex_groups if any(t in g.name for t in ('RightArm','RightForeArm','RightHand'))}
        for v in ob.data.vertices:
            p=ob.matrix_world@v.co
            if min(segment_distance(p,joints[0],joints[1]),segment_distance(p,joints[1],joints[2])) <= .105:continue
            weights=[(arm_groups[g.group],g.weight) for g in v.groups if g.group in arm_groups]
            if not weights:continue
            for group,_ in weights:group.remove([v.index])
            torso.add([v.index],sum(w for _,w in weights),'ADD');spill+=1
    print('TORSO arm-weight spill corrected',spill,flush=True)

def build(hero):
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=24
    if hero=='jm':arm,names=new_jm()
    else:
        bpy.ops.import_scene.gltf(filepath=str(R/f'assets/characters/{hero}.glb'))
        arm=next(o for o in bpy.data.objects if o.type=='ARMATURE');names=[a.name for a in bpy.data.actions]
    while arm.animation_data.nla_tracks:arm.animation_data.nla_tracks.remove(arm.animation_data.nla_tracks[0])
    arm.animation_data.action=None
    if hero=='inday':repair_hair(arm)
    if hero=='jm':
        for clip in ('Idle','Walking','Running'):
            carry_pose(arm,clip)
    for name,mode in [('Tag','tag'),('TagCharge','prepare'),('Cough','cough')]+([('Ubo','throw')] if hero=='nathan' else []):
        author(arm,name,mode)
        if name not in names:names.append(name)
    if hero=='jm':
        dizzy_pose(arm)
        if 'Tamaraw_Miss' not in names:names.append('Tamaraw_Miss')
    for name in names:
        act=bpy.data.actions[name];track=arm.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,int(act.frame_range[0]),act)
    arm.animation_data.action=None
    staging=R/'renders/revision_assets';staging.mkdir(exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(staging/f'{hero}.glb'),export_format='GLB',export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True)
    for tr in arm.animation_data.nla_tracks:tr.mute=True
    base.render_moves_sheet(arm,hero,(['Idle','Walking','Running','Tamaraw_Miss','Tag'] if hero=='jm' else ['TagCharge','Tag','Cough']+(['Ubo'] if hero=='nathan' else [])),per_row=1,tile=(170,200),suffix='revision')
    print('REVISION',hero,len(names),flush=True)

if __name__=='__main__':
    ids=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(base.HEROES)
    for hero in ids:build(hero)
