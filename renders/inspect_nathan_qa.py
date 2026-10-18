import bpy,sys,json
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='E:/RESBAK/resbak/assets/characters/nathan.glb')
sys.path.insert(0,'C:/Users/Kurtl/.codex/skills/blender-asset-qa/scripts')
import qa_check
names=[o.name for o in bpy.context.scene.objects if o.type=='MESH' and len(o.vertex_groups)>0]
def trace(frame,event,arg):
 if frame.f_code.co_filename==qa_check.__file__ and frame.f_code.co_name=='run' and event=='return':
  d=frame.f_locals
  print('PAIRS',d.get('zf_pairs'))
  for a,b in d.get('zf_pairs',[]):
   for i in (a,b):print('TRI',i,[list(d['verts'][v]) for v in d['tris'][i]])
 return trace
sys.settrace(trace)
r=qa_check.run(objects=names)
sys.settrace(None)
print(json.dumps(r))
