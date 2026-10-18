"""Build clean terry cloth from supplied material, with independent deform joints.
960 triangles; open double-sided sheet is intentional. Runtime supplies shoulder/contact
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
rows,cols,length,width=40,12,.85,.22
verts=[];faces=[]
for row in range(rows+1):
    t=row/rows
    for col in range(cols+1):
        u=col/cols
        # Broad soft corrugations, not a rigid flat board. Gather only at grip.
        gather=.38+.62*min(1,t/.16)
        verts.append(((u-.5)*width*gather,t*length,(.018*math.sin(u*math.pi*4)+.007*(abs(u-.5)*2)**3)*math.sin(math.pi*t)**.4))
for row in range(rows):
    for col in range(cols):
        i=row*(cols+1)+col;faces.append((i,i+1,i+cols+2,i+cols+1))
mesh=bpy.data.meshes.new('TerryCloth');mesh.from_pydata(verts,[],faces);mesh.update()
mesh.materials.append(material)
uv=mesh.uv_layers.new(name='UVMap')
for loop in mesh.loops:
    i=loop.vertex_index;uv.data[loop.index].uv=(i%(cols+1)/cols,1-i//(cols+1)/rows)
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
    if not carry:return Vector((.05*math.sin(t*math.pi),t*length,.06*math.sin(t*math.pi*2)))
    # Piecewise shoulder arch from a chest grip over the shoulder to the back.
    controls=[Vector((0,0,0)),Vector((-.02,.16,.22)),Vector((-.02,.36,.15)),Vector((-.02,.39,-.26))]
    u=t*3;k=min(2,int(u));f=u-k
    a=controls[max(0,k-1)];b=controls[k];c=controls[k+1];d=controls[min(3,k+2)]
    return .5*((2*b)+(-a+c)*f+(2*a-5*b+4*c-d)*f*f+(-a+3*b-3*c+d)*f*f*f)
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
print('TOWEL',rows*cols*2,'triangles',count,'joints',flush=True)
