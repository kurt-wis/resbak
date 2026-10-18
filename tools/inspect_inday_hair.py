import bpy,json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(R/'assets/characters/inday.glb'))
for ob in [o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.vertex_groups)]:
    mat=ob.data.materials[0];im=next(n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image);pixels=list(im.pixels);w,h=im.size
    colors={}
    for lp in ob.data.loops:
        u,v=ob.data.uv_layers.active.data[lp.index].uv;i=(min(h-1,max(0,int(v*h)))*w+min(w-1,max(0,int(u*w))))*4
        colors[lp.vertex_index]=pixels[i:i+3]
    out=[]
    for v in ob.data.vertices:
        p=ob.matrix_world@v.co
        groups={ob.vertex_groups[g.group].name:g.weight for g in v.groups}
        if abs(p.x)<.32 and p.z>.88 and p.y>-.1 and sum(w for n,w in groups.items() if 'RightArm' in n or 'RightForeArm' in n)>.02:
            out.append({'id':v.index,'p':list(p),'rgb':colors[v.index],'groups':groups})
    (R/'renders/inday_hair_candidates.json').write_text(json.dumps(out,indent=1))
    print('Candidates',len(out),flush=True)
