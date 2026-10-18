"""Geometry/weight QA for changed heroes and the two new props, using blender-asset-qa."""
import bpy, os, sys, json
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0,os.path.join(os.path.expanduser('~'),'.codex/skills/blender-asset-qa/scripts'))
import qa_check
reports={}
paths=['assets/characters/'+h+'.glb' for h in ('tutoy','nene','nathan','jm','inday')]
paths+=['assets/props/tamaraw_spirit.glb','assets/props/jm_towel.glb']
paths+=['assets/props/kimkim.glb']
paths+=['assets/characters/face_cards/jm_cards.glb']
for path in paths:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT,path))
    objects=[o.name for o in bpy.context.scene.objects if o.type=='MESH' and (len(o.vertex_groups)>0 or path.endswith(('kimkim.glb','_cards.glb')))]
    reports[path]=qa_check.run(objects=objects,profile='game')
    print('ASSET_QA',path,json.dumps(reports[path],default=str),flush=True)
os.makedirs(os.path.join(ROOT,'renders/qc'),exist_ok=True)
with open(os.path.join(ROOT,'renders/qc/hero_polish_geometry.json'),'w') as f:json.dump(reports,f,indent=2,default=str)
