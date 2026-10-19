"""Build clean terry cloth from supplied material, with independent deform joints.
984 triangles; closed loosely rolled cloth. Runtime supplies grip/contact
anchors and damped follow-through. NLA clips permit standalone asset review.
"""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector, Matrix
R=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=24
source=R/'source_art/props/jm_terry_source.glb'
if not source.exists():source=R/'source_art/props/jm_towel_source.glb'
bpy.ops.import_scene.gltf(filepath=str(source))
raw=[o for o in bpy.context.scene.objects if o.type=='MESH']
material=raw[0].data.materials[0]
material.use_backface_culling=False
for n in material.node_tree.nodes:
    if n.type=='BSDF_PRINCIPLED':
        for socket in ('Roughness','Metallic'):
            for link in list(n.inputs[socket].links):material.node_tree.links.remove(link)
        n.inputs['Roughness'].default_value=.94
        n.inputs['Metallic'].default_value=0.0
for o in raw:bpy.data.objects.remove(o,do_unlink=True)
rows,cols,length,width=40,12,.72,.07
verts=[];faces=[]
for row in range(rows+1):
    t=row/rows
    for col in range(cols):
        angle=col/cols*math.tau
        radius=(.023+.012*math.sin(math.pi*t)**.5)*(1+.06*math.cos(angle*3+t*12))
        verts.append((math.cos(angle)*radius,t*length,math.sin(angle)*radius))
for row in range(rows):
    for col in range(cols):
        i=row*cols+col;j=row*cols+(col+1)%cols
        faces.append((i,i+cols,j+cols,j))
# Soft gathered caps, explicitly triangulated for stable game export.
for row,reverse in [(0,False),(rows,True)]:
    center=len(verts);verts.append((0,row/rows*length,0))
    for col in range(cols):
        a=row*cols+col;b=row*cols+(col+1)%cols
        faces.append((center,b,a) if reverse else (center,a,b))
mesh=bpy.data.meshes.new('RolledTerry');mesh.from_pydata(verts,[],faces);mesh.update()
mesh.materials.append(material)
uv=mesh.uv_layers.new(name='UVMap')
for polygon in mesh.polygons:
    if polygon.index < rows*cols:
        row=polygon.index//cols;col=polygon.index%cols
        coords=[(col/cols,.15+row/rows*.85),(col/cols,.15+(row+1)/rows*.85),((col+1)/cols,.15+(row+1)/rows*.85),((col+1)/cols,.15+row/rows*.85)]
        for li,coordinate in zip(polygon.loop_indices,coords):uv.data[li].uv=coordinate
    else:
        center_u=.25 if polygon.index<rows*cols+cols else .75
        for li in polygon.loop_indices:
            co=mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv=(center_u+co.x*1.8,.075+co.z*1.8)
for p in mesh.polygons:p.use_smooth=True
ob=bpy.data.objects.new('JM_TerryCloth',mesh);bpy.context.collection.objects.link(ob)
data=bpy.data.armatures.new('TowelRig');arm=bpy.data.objects.new('TowelRig',data);bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm;arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
count=17
for i in range(count):
    b=data.edit_bones.new('Cloth%02d'%i);b.head=(0,i*length/(count-1),0);b.tail=b.head+Vector((0,.04,0))
bpy.ops.object.mode_set(mode='OBJECT')
groups=[ob.vertex_groups.new(name=b.name) for b in data.bones]
for v in mesh.vertices:
    at=max(0,min(count-1,v.co.y/length*(count-1)));a=int(at);b=min(count-1,a+1);t=at-a
    if 1-t>0:groups[a].add([v.index],1-t,'REPLACE')
    if b!=a and t>0:groups[b].add([v.index],t,'REPLACE')
mod=ob.modifiers.new('ClothSkin','ARMATURE');mod.object=arm;ob.parent=arm
arm.animation_data_create()
def curve(t,carry):
    if not carry:return Vector((.12*math.sin(t*math.pi),t*length,.05*math.sin(t*math.pi*2)))
    return Vector((.04*math.sin(t*math.pi),t*length,-.04*math.sin(t*math.pi)))
for name,carry in [('Towel_Carry',True),('Towel_Whip',False)]:
    arm.animation_data.action=None
    for f in range(25):
        bpy.context.scene.frame_set(f)
        for i,pb in enumerate(arm.pose.bones):
            t=i/(count-1);p=curve(t,carry);q=curve(min(1,t+.005),carry)-curve(max(0,t-.005),carry)
            if i>8:p.x+=math.sin(f/24*math.tau-t*4)*.012*(t-.5)
            pb.matrix=Matrix.Translation(p)@Vector((0,1,0)).rotation_difference(q.normalized()).to_matrix().to_4x4()
            pb.rotation_mode='QUATERNION'
            for path in ('location','rotation_quaternion','scale'):pb.keyframe_insert(path,frame=f)
    act=arm.animation_data.action;act.name=name
    tr=arm.animation_data.nla_tracks.new();tr.name=name;tr.strips.new(name,0,act);tr.mute=True
arm.animation_data.action=None
for tr in arm.animation_data.nla_tracks:tr.mute=False
bpy.ops.export_scene.gltf(filepath=str(R/'assets/props/jm_towel.glb'),export_format='GLB',export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True)
print('TOWEL',len(mesh.polygons)+rows*cols,'triangles',count,'joints',flush=True)
