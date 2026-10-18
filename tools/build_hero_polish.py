"""Preserve the shipped libraries; repair gait sources and author HILA/towel actions.
Run: blender -b --python tools/build_hero_polish.py
Use -- <hero ids> to rebuild selected heroes. Replacement clips come from source mocap
or unchanged Idle, so no gesture is repeatedly layered onto itself.
"""
import bpy, bmesh, os, sys, math, json
from mathutils import Quaternion, Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_heroes as base
import retarget_clip
ROOT=base.PROJ

def key_pose(arm, frame):
    for pb in arm.pose.bones:
        pb.rotation_mode='QUATERNION'
        for path in ('location','rotation_quaternion','scale'): pb.keyframe_insert(path, frame=frame)

def author_reach(arm):
    idle=bpy.data.actions['Idle']; frames=[]
    arm.animation_data.action=idle
    for f in range(25):
        bpy.context.scene.frame_set(f)
        frames.append({p.name:p.matrix_basis.copy() for p in arm.pose.bones})
    old=bpy.data.actions.get('Sagip')
    if old: bpy.data.actions.remove(old)
    arm.animation_data.action=None
    for f in range(25):
        bpy.context.scene.frame_set(f)
        for pb in arm.pose.bones: pb.matrix_basis=frames[f][pb.name]
        bpy.context.view_layer.update()
        # Short anticipatory gather, open reach at 55%, followed by elbow-led recovery.
        u=f/24
        reach=min(1,u/.55) if u<=.55 else max(0,(1-u)/.45)
        reach=reach*reach*(3-2*reach)
        for name in (() if f in (0,24) else ('RightArm','RightForeArm','RightHand')):
            pb=arm.pose.bones['mixamorig:'+name]
            current=pb.matrix.copy()
            direction=current.to_quaternion() @ Vector((0,1,0))
            desired=Vector((.08,-1,.04)).normalized()
            turn=Quaternion().slerp(direction.rotation_difference(desired),reach)
            current=Matrix.Translation(current.translation) @ (turn @ current.to_quaternion()).to_matrix().to_4x4()
            pb.matrix=current
        key_pose(arm,f)
    arm.animation_data.action.name='Sagip'

def author_towel_tag(arm):
    action=bpy.data.actions['Tag']; arm.animation_data.action=action
    f0,f1=action.frame_range
    poses=[]
    for f in range(int(f1)+1):
        bpy.context.scene.frame_set(f)
        poses.append({p.name:p.matrix_basis.copy() for p in arm.pose.bones})
    bpy.data.actions.remove(action);arm.animation_data.action=None
    for f,pose in enumerate(poses):
        bpy.context.scene.frame_set(f)
        for pb in arm.pose.bones: pb.matrix_basis=pose[pb.name]
        u=f/max(1,len(poses)-1)
        # Coil across the chest, whip outward at contact, relaxed wrist follow-through.
        coil=math.sin(math.pi*min(1,u/.55)) if u<.55 else -.3*math.sin(math.pi*(u-.55)/.45)
        for name,axis,angle in [('Spine2',(0,0,1),.18),('RightArm',(0,0,1),-.35),('RightForeArm',(1,0,0),.2)]:
            pb=arm.pose.bones['mixamorig:'+name]
            pb.rotation_quaternion=pb.rotation_quaternion @ Quaternion(axis,angle*coil)
        key_pose(arm,f)
    arm.animation_data.action.name='Tag'

def polish(hero):
    shipped=os.path.join(ROOT,'assets/characters',hero+'.glb')
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=24
    bpy.ops.import_scene.gltf(filepath=shipped)
    arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    if hero == 'nathan':
        for mesh in [o for o in bpy.context.scene.objects if o.type=='MESH']:
            bm=bmesh.new();bm.from_mesh(mesh.data)
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.000001)
            bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=0.000001)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            bm.to_mesh(mesh.data);bm.free()
            # Two source shoulder triangles share a seam and partially overlap coplanarly.
            # Lift the upper seam by 5 mm, preserving UV loops and skin weights.
            seam = [Vector((-.2401685,-.1291046,1.4462534)), Vector((-.2247933,-.0836082,1.4625338))]
            bpy.context.view_layer.update()
            evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            posed=evaluated.to_mesh()
            indices={v.index for v in posed.vertices if min((mesh.matrix_world@v.co-target).length for target in seam)<.002}
            for index in indices:mesh.data.vertices[index].co.x-=.006
            print('Shoulder seam adjusted:',len(indices),'vertices',flush=True)
            evaluated.to_mesh_clear()
    names=[a.name for a in bpy.data.actions]
    while arm.animation_data.nla_tracks:arm.animation_data.nla_tracks.remove(arm.animation_data.nla_tracks[0])
    arm.animation_data.action=None
    if hero in ('jm','nathan'):
        old=bpy.data.actions['Walking'];bpy.data.actions.remove(old)
        frames=base.retarget_table(arm,{'Walking':base.clip('meshy/tutoy_moves.glb','Quick_Walk',trim=(0,1),loop=True,plant=True)})['Walking']
        base.bake_planted(arm,'Walking',frames)
    if hero=='inday':author_reach(arm)
    if hero=='jm':
        bpy.data.actions.remove(bpy.data.actions['Tag'])
        frames=base.retarget_table(arm,{'Tag':base.SHARED['Tag']})['Tag']
        base.bake_grounded(arm,'Tag',frames)
        author_towel_tag(arm)
    # All existing character-specific idles/runs/skills and menu clips survive.
    for name in names:
        act=bpy.data.actions[name]
        tr=arm.animation_data.nla_tracks.new();tr.name=name
        tr.strips.new(name,int(act.frame_range[0]),act)
    arm.animation_data.action=None
    bpy.ops.export_scene.gltf(filepath=shipped,export_format='GLB',export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True)
    # Review only changed locomotion/cast clips rather than the unrelated menu library.
    for tr in arm.animation_data.nla_tracks:tr.mute=True
    base.render_moves_sheet(arm,hero,['Idle','Walking','Running']+(['Sagip'] if hero=='inday' else ['Tag']),per_row=1,tile=(150,190),suffix='polish')
    print('POLISHED',hero,len(names),'clips',flush=True)

def towel():
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30
    # An open fabric surface is intentional, with tapered folds and colored end bands.
    verts=[];faces=[]
    for row in range(17):
        u=row/16
        for side in (-1,1): verts.append((side*.085*(1-.25*u),u*.72,.012*math.sin(u*math.pi*5)))
    for i in range(16):faces.append((i*2,i*2+1,i*2+3,i*2+2))
    me=bpy.data.meshes.new('TowelCloth');me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new('TowelCloth',me);bpy.context.collection.objects.link(ob)
    for col in [(0.92,.88,.72,1),(.1,.35,.45,1)]:
        mat=bpy.data.materials.new('Cotton' if len(me.materials)==0 else 'WovenBand');mat.diffuse_color=col;me.materials.append(mat)
    for i,p in enumerate(me.polygons):p.material_index=1 if i in (1,2,13,14) else 0;p.use_smooth=True
    uv=me.uv_layers.new()
    for p in me.polygons:
        for li in p.loop_indices:
            co=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(co.x/.17+.5,co.y/.72)
    data=bpy.data.armatures.new('TowelRig');arm=bpy.data.objects.new('TowelRig',data);bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active=arm;arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    for i in range(6):
        b=data.edit_bones.new('Cloth%d'%i);b.head=(0,i*.12,0);b.tail=(0,(i+1)*.12,0)
        if i:b.parent=data.edit_bones['Cloth%d'%(i-1)];b.use_connect=True
    bpy.ops.object.mode_set(mode='OBJECT')
    groups=[ob.vertex_groups.new(name=b.name) for b in data.bones]
    for v in me.vertices:
        pos=max(0,min(5,v.co.y/.12-.5));a=int(pos);b=min(5,a+1);t=pos-a
        groups[a].add([v.index],1-t,'REPLACE')
        if b!=a:groups[b].add([v.index],t,'REPLACE')
    mod=ob.modifiers.new('ClothSkin','ARMATURE');mod.object=arm;ob.parent=arm
    arm.animation_data_create()
    for f in range(25):
        bpy.context.scene.frame_set(f)
        for i,pb in enumerate(arm.pose.bones):
            u=f/24
            pulse=math.sin(math.pi*min(1,max(0,(u-i*.035)/.65)))
            pb.rotation_mode='XYZ';pb.rotation_euler=(.16*pulse,0,.24*pulse*(-1 if u>.55 else 1))
            pb.keyframe_insert('rotation_euler',frame=f)
    act=arm.animation_data.action;act.name='Towel_Whip'
    tr=arm.animation_data.nla_tracks.new();tr.name='Towel_Whip';tr.strips.new('Towel_Whip',0,act);arm.animation_data.action=None
    solid=ob.modifiers.new('CottonThickness','SOLIDIFY');solid.thickness=.003
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets/props/jm_towel.glb'),export_format='GLB',export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True)

if __name__=='__main__':
    ids=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(base.HEROES)
    for hero in ids:polish(hero)
    if 'jm' in ids:towel()
