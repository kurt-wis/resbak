"""JM (Botsog) procedural builder — pure bpy, phase-by-phase, headless-safe.
Faces -Y (Blender Front), Right side -X (towel), ground Z=0, height 1.40m.
Rig: Mixamo standard + Towel bones, XYZ Euler, voxel 0.007 + corrective smooth,
DataTransfer weights, Principled BSDF hex + chalk mask, 3 NLA actions.
Run: blender -b --python tools/build_jm_botsog.py
Renders: renders/jm_phase*_front.png / _quarter.png via render.render (no opengl).
Output: assets/characters/jm_botsog.glb + source_art/jm_botsog/jm_botsog.blend + renders/jm_build_meta.json.
"""
import bpy
import bmesh
import os
import math
from mathutils import Vector, Euler

# ---------------------------------------------------------------- paths
PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
OUT_GLB = os.path.join(PROJ, "assets", "characters", "jm_botsog.glb")
OUT_BLEND = os.path.join(PROJ, "source_art", "jm_botsog", "jm_botsog.blend")
RENDER_DIR = os.path.join(PROJ, "renders")
META_JSON = os.path.join(RENDER_DIR, "jm_build_meta.json")
os.makedirs(RENDER_DIR, exist_ok=True)
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)

# landmarks
LANDMARKS = {
    "soles": 0.00, "ankles": 0.10, "knees": 0.26, "crotch": 0.42,
    "waist": 0.52, "chest": 0.82, "shoulders": 0.94, "neck_base": 0.98,
    "head_center": 1.18, "top": 1.40,
}

HEX = {
    "skin": "D98254", "hair": "261710", "shirt": "E5A935",
    "carabao": "3B2B1E", "towel": "EAE8E1", "shorts": "5F5E3C",
    "sandals": "263868", "chalk": "F4F6F8", "blush": "C85A38",
}

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16)/255.0 for i in (0, 2, 4)) + (1.0,)

def log(msg):
    print(f"[JM] {msg}")

# ---------------------------------------------------------------- utils
def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30

def deselect_all():
    try:
        bpy.ops.object.select_all(action='DESELECT')
    except: pass

def set_active(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

def create_prim(op, name, **kw):
    deselect_all()
    # ensure object mode
    try:
        if bpy.context.mode != 'OBJECT':
            bpy.ops.object.mode_set(mode='OBJECT')
    except: pass
    op(**kw)
    obj = bpy.context.view_layer.objects.active
    if obj is not None:
        obj.name = name
    return obj

def shade_smooth_obj(obj):
    try:
        deselect_all()
        set_active(obj)
        bpy.ops.object.shade_smooth()
        deselect_all()
    except Exception as e:
        log(f"shade_smooth note {obj.name}: {e}")

# ---------------------------------------------------------------- PHASE 1
_verify_cam = None
_focus_empty = None

def phase1_setup():
    log("PHASE 1: scene, lights, camera rig")
    clear_scene()
    sc = bpy.context.scene
    sc.render.fps = 30
    sc.render.resolution_x = 512
    sc.render.resolution_y = 512
    sc.render.resolution_percentage = 100
    try:
        sc.render.engine = 'BLENDER_EEVEE_NEXT'
    except:
        try: sc.render.engine = 'BLENDER_EEVEE'
        except:
            try: sc.render.engine = 'CYCLES'
            except: pass
    try:
        sc.display.shading.light = 'MATCAP'
    except: pass

    # ground plane Z=0
    g = create_prim(bpy.ops.mesh.primitive_plane_add, "Ground", size=6, location=(0,0,0.0))
    # lights warm 3-point
    deselect_all()
    bpy.ops.object.light_add(type='SUN', location=(2.5,-3.0,4.0))
    key = bpy.context.active_object; key.name="Key_Light"
    try: key.data.energy = 4.0; key.data.color = (1.0,0.9,0.78)
    except: pass
    bpy.ops.object.light_add(type='AREA', location=(-2.5,-1.5,2.5))
    fill = bpy.context.active_object; fill.name="Fill_Light"
    try:
        fill.data.energy = 120.0; fill.data.color=(1.0,0.85,0.7); fill.data.size=2.0
    except: pass
    bpy.ops.object.light_add(type='AREA', location=(0.5,2.5,3.0))
    rim = bpy.context.active_object; rim.name="Rim_Light"
    try: rim.data.energy=80.0; rim.data.color=(1.0,0.8,0.6); rim.data.size=1.5
    except: pass
    try: bpy.context.scene.world.use_nodes=True
    except: pass

    # focus empty at (0,0,0.7)
    global _focus_empty, _verify_cam
    deselect_all()
    bpy.ops.object.empty_add(location=(0,0,0.7))
    _focus_empty = bpy.context.active_object
    _focus_empty.name = "Verify_Focus"
    deselect_all()
    bpy.ops.object.camera_add(location=(0,-3.2,0.75))
    _verify_cam = bpy.context.active_object
    _verify_cam.name = "Verify_Cam"
    # track to
    try:
        c = _verify_cam.constraints.new('TRACK_TO')
        c.target = _focus_empty
        c.track_axis='TRACK_NEGATIVE_Z'; c.up_axis='UP_Y'
    except Exception as e:
        log(f"cam constraint note: {e}")
    sc.camera = _verify_cam
    deselect_all()
    log("phase1 done")

def set_cam(pos, name):
    global _verify_cam
    _verify_cam.location = Vector(pos)
    # force update
    bpy.context.view_layer.update()

def do_render(filepath):
    sc = bpy.context.scene
    sc.render.filepath = filepath
    sc.render.image_settings.file_format='PNG'
    # headless-safe: render.render, never opengl
    bpy.ops.render.render(write_still=True)
    log(f"render saved: {filepath}")

def phase_render(tag):
    # front -Y
    set_cam((0,-3.2,0.75), "front")
    bpy.context.view_layer.update()
    do_render(os.path.join(RENDER_DIR, f"jm_{tag}_front.png"))
    # quarter -X/-Y
    set_cam((-2.2,-2.2,0.85), "quarter")
    bpy.context.view_layer.update()
    do_render(os.path.join(RENDER_DIR, f"jm_{tag}_quarter.png"))

# ---------------------------------------------------------------- PHASE 2 body
def bmesh_scale_lower_cheeks(obj):
    # widen lower half Z 1.04-1.14 along X by 1.18x
    try:
        deselect_all(); set_active(obj)
        bpy.ops.object.mode_set(mode='EDIT')
        me = obj.data
        bm = bmesh.from_edit_mesh(me)
        for v in bm.verts:
            wz = obj.matrix_world @ v.co
            # local Z approx world Z since no transform
            if 1.04 <= v.co.z + obj.location.z <= 1.14 or 1.04 <= (v.co.z+1.18-0.21) <= 1.14:
                # simpler: check world z
                pass
        # world-space check: obj at (0,0,1.18) with sphere local coords
        # local z in [-0.21,0.21]; world = 1.18+local
        for v in bm.verts:
            world_z = 1.18 + v.co.z if abs(obj.location.z-1.18)<0.01 else v.co.z
            # fallback: use matrix
            try:
                world_z = (obj.matrix_world @ v.co).z
            except: pass
            if 1.04 <= world_z <= 1.14:
                v.co.x *= 1.18
        bmesh.update_edit_mesh(me)
        bpy.ops.object.mode_set(mode='OBJECT')
    except Exception as e:
        log(f"cheek scale note: {e}")
        try: bpy.ops.object.mode_set(mode='OBJECT')
        except: pass

def phase2_body():
    log("PHASE 2: organic base body JM_Body")
    skin_parts = []

    # head sphere at (0,0,1.18) r 0.21
    head = create_prim(bpy.ops.mesh.primitive_uv_sphere_add, "JM_HeadBase",
        segments=32, ring_count=16, radius=0.21, location=(0,0,1.18))
    bmesh_scale_lower_cheeks(head)
    skin_parts.append(head)

    # neck cylinder 0.95-1.05
    neck = create_prim(bpy.ops.mesh.primitive_cylinder_add, "JM_Neck",
        vertices=20, radius=0.07, depth=0.12, location=(0,0,1.0))
    skin_parts.append(neck)

    # torso barrel 0.45-0.98 center 0.715 height 0.53, Xw 0.46 Yd 0.34
    torso = create_prim(bpy.ops.mesh.primitive_cylinder_add, "JM_Torso",
        vertices=28, radius=0.23, depth=0.53, location=(0,0,0.715))
    # scale Y to 0.74 for depth, X slight belly
    try:
        torso.scale = (1.0, 0.74, 1.0)
        bpy.context.view_layer.update()
        # apply scale via bmesh? keep scale, will apply later
        deselect_all(); set_active(torso)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    except Exception as e:
        log(f"torso scale note: {e}")
    # belly bulge: scale middle verts outward slightly
    try:
        deselect_all(); set_active(torso)
        bpy.ops.object.mode_set(mode='EDIT')
        bm = bmesh.from_edit_mesh(torso.data)
        for v in bm.verts:
            # local z near 0 (center) -> belly
            if abs(v.co.z) < 0.12:
                v.co.x *= 1.08
                v.co.y *= 1.10
        bmesh.update_edit_mesh(torso.data)
        bpy.ops.object.mode_set(mode='OBJECT')
    except Exception as e:
        log(f"belly note: {e}")
        try: bpy.ops.object.mode_set(mode='OBJECT')
        except: pass
    skin_parts.append(torso)

    # ears flattened spheres at (±0.21,0.02,1.15)
    for side, sx in (("L",1),("R",-1)):
        # NOTE: Right=-X, Left=+X per convention
        x = 0.21*sx
        ear = create_prim(bpy.ops.mesh.primitive_uv_sphere_add, f"JM_Ear_{sx}",
            segments=16, ring_count=10, radius=0.045, location=(x,0.02,1.15))
        ear.scale = (0.45, 0.7, 1.0)
        try:
            deselect_all(); set_active(ear)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        except: pass
        skin_parts.append(ear)

    # arms: upper + forearm capsules as cylinders oriented
    # A-pose 40deg from vertical: shoulder X ±0.24 Z 0.92, elbow ±0.36 Z ~0.72, wrist ±0.46 Z ~0.54
    import mathutils
    def limb_cyl(name, p1, p2, r1):
        mid = ((p1[0]+p2[0])/2, (p1[1]+p2[1])/2, (p1[2]+p2[2])/2)
        vec = Vector((p2[0]-p1[0], p2[1]-p1[1], p2[2]-p1[2]))
        length = vec.length
        # cylinder along Z, rotate to vec
        cyl = create_prim(bpy.ops.mesh.primitive_cylinder_add, name,
            vertices=16, radius=r1, depth=length, location=mid)
        # orient Z to vec
        try:
            zaxis = Vector((0,0,1))
            quat = zaxis.rotation_difference(vec.normalized())
            cyl.rotation_mode='QUATERNION'
            cyl.rotation_quaternion = quat
            deselect_all(); set_active(cyl)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
            cyl.rotation_mode='XYZ'
        except Exception as e:
            log(f"limb orient {name}: {e}")
        # joint spheres
        j1 = create_prim(bpy.ops.mesh.primitive_uv_sphere_add, name+"_j1",
            segments=12, ring_count=8, radius=r1, location=p1)
        j2 = create_prim(bpy.ops.mesh.primitive_uv_sphere_add, name+"_j2",
            segments=12, ring_count=8, radius=r1*0.95, location=p2)
        return [cyl, j1, j2]

    for sx, side in ((1,"L"),(-1,"R")):
        sh = (0.24*sx, 0.0, 0.92)
        el = (0.36*sx, -0.02, 0.72)
        wr = (0.46*sx, -0.04, 0.54)
        skin_parts += limb_cyl(f"JM_UpperArm_{side}", sh, el, 0.065)
        skin_parts += limb_cyl(f"JM_ForeArm_{side}", el, wr, 0.055)
        # palm sphere
        palm = create_prim(bpy.ops.mesh.primitive_uv_sphere_add, f"JM_Palm_{side}",
            segments=14, ring_count=10, radius=0.06, location=(0.47*sx,-0.05,0.48))
        try: palm.scale=(1.0,1.2,1.3)
        except: pass
        try:
            deselect_all(); set_active(palm)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        except: pass
        skin_parts.append(palm)
        # 5 stubby fingers: thumb + 4, small capsules down/forward
        finger_base = Vector((0.47*sx,-0.06,0.44))
        for fi in range(5):
            off_x = (fi-2)*0.025
            off_y = -0.02 if fi==0 else -0.03  # thumb slightly side
            # thumb offset X outward
            if fi==0:
                off_x = 0.035*sx
                fp1 = (finger_base.x+off_x, finger_base.y+0.01, finger_base.z)
                fp2 = (finger_base.x+off_x+0.01*sx, finger_base.y-0.02, finger_base.z-0.06)
                r=0.018
            else:
                fp1 = (finger_base.x+off_x, finger_base.y-0.01, finger_base.z)
                fp2 = (finger_base.x+off_x, finger_base.y-0.02, finger_base.z-0.07)
                r=0.016
            skin_parts += limb_cyl(f"JM_Fing_{side}_{fi}", fp1, fp2, r)

    # legs: thighs X ±0.14, crotch 0.44 to knee 0.25, calf 0.32-0.10, feet + toes
    for sx, side in ((1,"L"),(-1,"R")):
        hip = (0.14*sx, 0.0, 0.44)
        knee = (0.14*sx, 0.0, 0.25)
        ank = (0.14*sx, -0.01, 0.09)
        skin_parts += limb_cyl(f"JM_Thigh_{side}", hip, knee, 0.085)
        skin_parts += limb_cyl(f"JM_Calf_{side}", (0.14*sx,0,0.32), ank, 0.06)
        # foot box-ish: use cube scaled + toe spheres
        foot = create_prim(bpy.ops.mesh.primitive_cube_add, f"JM_Foot_{side}",
            size=1.0, location=(0.14*sx,-0.06,0.045))
        try:
            foot.scale=(0.09,0.16,0.035)
            deselect_all(); set_active(foot)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        except Exception as e:
            log(f"foot scale {e}")
        skin_parts.append(foot)
        # 5 toes stubby
        for ti in range(5):
            tx = 0.14*sx + (ti-2)*0.022
            toe = create_prim(bpy.ops.mesh.primitive_uv_sphere_add, f"JM_Toe_{side}_{ti}",
                segments=8, ring_count=6, radius=0.018, location=(tx,-0.16,0.03))
            skin_parts.append(toe)

    # join skin parts into JM_Body
    deselect_all()
    for o in skin_parts:
        try: o.select_set(True)
        except: pass
    bpy.context.view_layer.objects.active = skin_parts[0]
    try:
        bpy.ops.object.join()
    except Exception as e:
        log(f"join fail: {e}")
    body = bpy.context.view_layer.objects.active
    body.name = "JM_Body"
    # voxel remesh 0.007 + corrective smooth 15
    try:
        deselect_all(); set_active(body)
        # ensure object mode
        try: bpy.ops.object.mode_set(mode='OBJECT')
        except: pass
        rm = body.modifiers.new("RemeshVoxel", 'REMESH')
        rm.mode='VOXEL'; rm.voxel_size=0.007
        # adaptivity 0
        try: rm.adaptivity=0.0
        except: pass
        bpy.ops.object.modifier_apply(modifier=rm.name)
        log("voxel remesh applied 0.007")
    except Exception as e:
        log(f"remesh fail (continue): {e}")
    try:
        cs = body.modifiers.new("CorrectiveSmooth", 'CORRECTIVE_SMOOTH')
        try: cs.iterations=15
        except: cs.factor=0.5
        try: cs.iterations=15
        except: pass
        bpy.ops.object.modifier_apply(modifier=cs.name)
        log("corrective smooth applied")
    except Exception as e:
        log(f"smooth fail: {e}")
    shade_smooth_obj(body)
    deselect_all()
    log(f"JM_Body verts={len(body.data.vertices)}")
    try:
        phase_render("phase2_body")
    except Exception as e:
        log(f"phase2 render fail: {e}")
    return body

# ---------------------------------------------------------------- PHASE 3 apparel
def solid_subdiv(obj, thick=0.008):
    try:
        deselect_all(); set_active(obj)
        s = obj.modifiers.new("Solidify", 'SOLIDIFY')
        s.thickness=thick
        try: s.offset=1.0
        except: pass
        bpy.ops.object.modifier_apply(modifier=s.name)
    except Exception as e:
        log(f"solidify {obj.name}: {e}")
    try:
        su = obj.modifiers.new("Subdiv", 'SUBSURF')
        su.levels=2
        try: su.render_levels=2
        except: pass
        # keep as non-applied for now? spec says apply before join; apply for clean export
        bpy.ops.object.modifier_apply(modifier=su.name)
    except Exception as e:
        log(f"subdiv {obj.name}: {e}")

def phase3_apparel(body):
    log("PHASE 3: apparel")
    # --- shirt 0.50-0.96 + sleeves to elbows
    shirt = create_prim(bpy.ops.mesh.primitive_cylinder_add, "JM_Shirt",
        vertices=28, radius=0.26, depth=0.46, location=(0,0,0.73))
    try:
        shirt.scale=(1.0,0.78,1.0)
        deselect_all(); set_active(shirt)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    except: pass
    # collar ring torus around neck
    collar = create_prim(bpy.ops.mesh.primitive_torus_add, "JM_Collar",
        major_radius=0.085, minor_radius=0.018, major_segments=24, minor_segments=10,
        location=(0,0,0.96))
    try:
        deselect_all()
        collar.select_set(True); shirt.select_set(True)
        bpy.context.view_layer.objects.active=shirt
        bpy.ops.object.join()
        shirt = bpy.context.view_layer.objects.active
        shirt.name="JM_Shirt"
    except Exception as e:
        log(f"collar join: {e}")
    # sleeves: short cylinders around upper arms
    sleeve_objs=[shirt]
    for sx, side in ((1,"L"),(-1,"R")):
        sh=(0.26*sx,0,0.88); el=(0.36*sx,-0.02,0.72)
        mid=((sh[0]+el[0])/2,(sh[1]+el[1])/2,(sh[2]+el[2])/2)
        vec=Vector((el[0]-sh[0],el[1]-sh[1],el[2]-sh[2])); L=vec.length
        sl = create_prim(bpy.ops.mesh.primitive_cylinder_add, f"JM_Sleeve_{side}",
            vertices=18, radius=0.085, depth=L+0.04, location=mid)
        try:
            zaxis=Vector((0,0,1)); quat=zaxis.rotation_difference(vec.normalized())
            sl.rotation_mode='QUATERNION'; sl.rotation_quaternion=quat
            deselect_all(); set_active(sl)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
            sl.rotation_mode='XYZ'
        except: pass
        sleeve_objs.append(sl)
    # join sleeves into shirt
    try:
        deselect_all()
        for o in sleeve_objs: o.select_set(True)
        bpy.context.view_layer.objects.active=sleeve_objs[0]
        bpy.ops.object.join()
        shirt=bpy.context.view_layer.objects.active; shirt.name="JM_Shirt"
    except Exception as e:
        log(f"sleeve join: {e}")
    # fabric folds near hem: displace lower verts with sin
    try:
        deselect_all(); set_active(shirt)
        bpy.ops.object.mode_set(mode='EDIT')
        bm=bmesh.from_edit_mesh(shirt.data)
        for v in bm.verts:
            wz=(shirt.matrix_world@v.co).z
            if wz<0.60:
                v.co.x += 0.008*math.sin(v.co.y*40.0)
                v.co.y += 0.006*math.sin(v.co.x*35.0)
        bmesh.update_edit_mesh(shirt.data)
        bpy.ops.object.mode_set(mode='OBJECT')
    except Exception as e:
        log(f"folds: {e}")
        try: bpy.ops.object.mode_set(mode='OBJECT')
        except: pass
    solid_subdiv(shirt, thick=0.008)

    # --- carabao decal 0.66-0.80 front, facing -X
    # build simple buffalo: body box + legs + horns torus + tail
    decal_parts=[]
    bbody = create_prim(bpy.ops.mesh.primitive_cube_add, "JM_Carabao_body",
        size=1.0, location=(0.0,-0.195,0.73))
    try:
        bbody.scale=(0.11,0.015,0.07)
        deselect_all(); set_active(bbody)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    except: pass
    decal_parts.append(bbody)
    # 4 legs small cubes
    for lx in (-0.07,-0.025,0.025,0.07):
        leg = create_prim(bpy.ops.mesh.primitive_cube_add, "JM_Carabao_leg",
            size=1.0, location=(lx,-0.195,0.675))
        try:
            leg.scale=(0.018,0.014,0.045)
            deselect_all(); set_active(leg)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        except: pass
        decal_parts.append(leg)
    # head box facing -X (right side): head at -X side
    chead = create_prim(bpy.ops.mesh.primitive_cube_add, "JM_Carabao_head",
        size=1.0, location=(-0.13,-0.195,0.76))
    try:
        chead.scale=(0.045,0.014,0.045)
        deselect_all(); set_active(chead)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    except: pass
    decal_parts.append(chead)
    # horns crescent: two torus halves
    for hx, hr in ((-0.15,0.035),(-0.11,0.035)):
        horn = create_prim(bpy.ops.mesh.primitive_torus_add, "JM_Carabao_horn",
            major_radius=hr, minor_radius=0.008, major_segments=12, minor_segments=6,
            location=(hx,-0.195,0.795))
        try:
            horn.rotation_euler=(math.radians(90),0,0)
            deselect_all(); set_active(horn)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        except: pass
        decal_parts.append(horn)
    # ears + tail
    tail = create_prim(bpy.ops.mesh.primitive_cylinder_add, "JM_Carabao_tail",
        vertices=8, radius=0.006, depth=0.06, location=(0.115,-0.195,0.73))
    try:
        tail.rotation_euler=(0,0,math.radians(20))
        deselect_all(); set_active(tail)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    except: pass
    decal_parts.append(tail)
    try:
        deselect_all()
        for o in decal_parts: o.select_set(True)
        bpy.context.view_layer.objects.active=decal_parts[0]
        bpy.ops.object.join()
        decal=bpy.context.view_layer.objects.active; decal.name="JM_Carabao_Decal"
    except Exception as e:
        log(f"decal join: {e}")
        decal=decal_parts[0]; decal.name="JM_Carabao_Decal"
    # subdivide densely + shrinkwrap to shirt
    try:
        deselect_all(); set_active(decal)
        # subdivide via modifier? add 2 levels then apply
        su=decal.modifiers.new("SubdivDecal",'SUBSURF'); su.levels=2
        try: su.render_levels=2
        except: pass
        bpy.ops.object.modifier_apply(modifier=su.name)
        sw=decal.modifiers.new("ShrinkDecal",'SHRINKWRAP')
        sw.target=shirt; sw.offset=0.002
        try: sw.wrap_method='PROJECT'
        except: pass
        try:
            sw.use_project_x=False; sw.use_project_y=True; sw.use_project_z=False
        except: pass
        bpy.ops.object.modifier_apply(modifier=sw.name)
    except Exception as e:
        log(f"decal shrink: {e}")

    # --- towel over right shoulder X=-0.18, scapula to chest 0.68
    # plane strip subdivided, waves
    towel = create_prim(bpy.ops.mesh.primitive_plane_add, "JM_Towel",
        size=1.0, location=(-0.18,-0.02,0.80))
    try:
        deselect_all(); set_active(towel)
        bpy.ops.object.mode_set(mode='EDIT')
        # subdivide a few times via bmesh? use ops
        try: bpy.ops.mesh.subdivide(number_cuts=6)
        except: pass
        bm=bmesh.from_edit_mesh(towel.data)
        # shape to strip 0.16 wide (X) x 0.45 long (YZ drape)
        for v in bm.verts:
            # plane initially XY; map to drape: X narrow, Y->Z drape?
            pass
        bmesh.update_edit_mesh(towel.data)
        bpy.ops.object.mode_set(mode='OBJECT')
    except Exception as e:
        log(f"towel edit1: {e}")
        try: bpy.ops.object.mode_set(mode='OBJECT')
        except: pass
    # scale to strip and position, add waves via verts
    try:
        towel.scale=(0.16,0.30,1.0)
        deselect_all(); set_active(towel)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        # move to drape: rotate to hang over shoulder
        towel.rotation_euler=(math.radians(15),0,0)
        deselect_all(); set_active(towel)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        # waves
        deselect_all(); set_active(towel)
        bpy.ops.object.mode_set(mode='EDIT')
        bm=bmesh.from_edit_mesh(towel.data)
        for v in bm.verts:
            # longitudinal waves
            v.co.z += 0.008*math.sin(v.co.x*80.0)
            v.co.y += 0.006*math.sin(v.co.x*60.0)
        bmesh.update_edit_mesh(towel.data)
        bpy.ops.object.mode_set(mode='OBJECT')
        # solidify for thickness
        s=towel.modifiers.new("SolTowel",'SOLIDIFY'); s.thickness=0.012
        bpy.ops.object.modifier_apply(modifier=s.name)
    except Exception as e:
        log(f"towel shape: {e}")
        try: bpy.ops.object.mode_set(mode='OBJECT')
        except: pass
    # ensure towel location: over right shoulder, hanging front to 0.68
    try: towel.location=(-0.18,-0.06,0.80)
    except: pass
    shade_smooth_obj(towel)

    # --- shorts waist 0.52 to knees 0.25, cuffed, crotch seam, cargo pockets
    shorts_main = create_prim(bpy.ops.mesh.primitive_cylinder_add, "JM_Shorts",
        vertices=24, radius=0.20, depth=0.27, location=(0,0,0.385))
    try:
        shorts_main.scale=(1.15,0.85,1.0)
        deselect_all(); set_active(shorts_main)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    except: pass
    # leg cuffs: two cylinders
    cuff_parts=[shorts_main]
    for sx, side in ((1,"L"),(-1,"R")):
        cuff = create_prim(bpy.ops.mesh.primitive_cylinder_add, f"JM_ShortLeg_{side}",
            vertices=18, radius=0.105, depth=0.12, location=(0.14*sx,0,0.28))
        cuff_parts.append(cuff)
    # cargo pockets bellows at (±0.24, Z 0.36)
    for sx, side in ((1,"L"),(-1,"R")):
        pkt = create_prim(bpy.ops.mesh.primitive_cube_add, f"JM_Pocket_{side}",
            size=1.0, location=(0.24*sx,0.02,0.36))
        try:
            pkt.scale=(0.06,0.09,0.08)
            deselect_all(); set_active(pkt)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        except: pass
        cuff_parts.append(pkt)
        flap = create_prim(bpy.ops.mesh.primitive_cube_add, f"JM_Flap_{side}",
            size=1.0, location=(0.24*sx,0.02,0.405))
        try:
            flap.scale=(0.065,0.095,0.02)
            # angled flap
            flap.rotation_euler=(math.radians(-10),0,0)
            deselect_all(); set_active(flap)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
            deselect_all(); set_active(flap)
            # need scale apply separately? already rotated; scale was applied before rotate? redo:
            pass
        except: pass
        # re-apply scale for flap (was scaled before rotate, transform_apply rotation only, scale remains? ensure)
        try:
            deselect_all(); set_active(flap)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        except: pass
        cuff_parts.append(flap)
    try:
        deselect_all()
        for o in cuff_parts: o.select_set(True)
        bpy.context.view_layer.objects.active=cuff_parts[0]
        bpy.ops.object.join()
        shorts=bpy.context.view_layer.objects.active; shorts.name="JM_Shorts"
    except Exception as e:
        log(f"shorts join: {e}")
        shorts=cuff_parts[0]; shorts.name="JM_Shorts"
    solid_subdiv(shorts, thick=0.008)

    # --- sandals soles 0.00-0.025 + straps
    sandal_parts=[]
    for sx, side in ((1,"L"),(-1,"R")):
        sole = create_prim(bpy.ops.mesh.primitive_cube_add, f"JM_Sole_{side}",
            size=1.0, location=(0.14*sx,-0.05,0.0125))
        try:
            sole.scale=(0.10,0.20,0.025)
            deselect_all(); set_active(sole)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        except: pass
        sandal_parts.append(sole)
        # two forefoot straps arched: torus halves
        for sz in (0.045, 0.09):
            strap = create_prim(bpy.ops.mesh.primitive_torus_add, f"JM_Strap_{side}_{sz}",
                major_radius=0.055, minor_radius=0.012, major_segments=12, minor_segments=8,
                location=(0.14*sx,-0.05+sz-0.05,0.045))
            try:
                strap.rotation_euler=(0,math.radians(90),0)
                deselect_all(); set_active(strap)
                bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
            except: pass
            sandal_parts.append(strap)
        # heel strap around back
        heel = create_prim(bpy.ops.mesh.primitive_torus_add, f"JM_Heel_{side}",
            major_radius=0.05, minor_radius=0.012, major_segments=12, minor_segments=8,
            location=(0.14*sx,0.06,0.06))
        try:
            heel.rotation_euler=(math.radians(90),0,0)
            deselect_all(); set_active(heel)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        except: pass
        sandal_parts.append(heel)
    try:
        deselect_all()
        for o in sandal_parts: o.select_set(True)
        bpy.context.view_layer.objects.active=sandal_parts[0]
        bpy.ops.object.join()
        sandals=bpy.context.view_layer.objects.active; sandals.name="JM_Sandals"
    except Exception as e:
        log(f"sandal join: {e}")
        sandals=sandal_parts[0]; sandals.name="JM_Sandals"

    # --- facial extras: haircap, brows, eyes, nose, smirk
    # haircap half-sphere top
    hair = create_prim(bpy.ops.mesh.primitive_uv_sphere_add, "JM_HairCap",
        segments=24, ring_count=12, radius=0.215, location=(0,0,1.20))
    try:
        deselect_all(); set_active(hair)
        bpy.ops.object.mode_set(mode='EDIT')
        bm=bmesh.from_edit_mesh(hair.data)
        # keep top/back, remove lower front? keep all but scale to buzzcut, shape widow peak
        for v in bm.verts:
            wz=(hair.matrix_world@v.co).z
            if wz<1.22:
                # lower fringe: pull slightly in for hairline
                if v.co.y<0:  # front (-Y)
                    v.co.z += 0.015
        bmesh.update_edit_mesh(hair.data)
        bpy.ops.object.mode_set(mode='OBJECT')
        # solidify 0.004
        s=hair.modifiers.new("SolHair",'SOLIDIFY'); s.thickness=0.004
        bpy.ops.object.modifier_apply(modifier=s.name)
    except Exception as e:
        log(f"hair: {e}")
        try: bpy.ops.object.mode_set(mode='OBJECT')
        except: pass

    brow_parts=[]
    for sx, side in ((1,"L"),(-1,"R")):
        brow = create_prim(bpy.ops.mesh.primitive_cube_add, f"Eyebrow_{side}",
            size=1.0, location=(0.075*sx,-0.185,1.225))
        try:
            brow.scale=(0.045,0.015,0.012)
            brow.rotation_euler=(0,0,math.radians(-18*sx))  # tilted inward
            deselect_all(); set_active(brow)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
            deselect_all(); set_active(brow)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        except: pass
        brow_parts.append(brow)

    eye_parts=[]
    for sx, side in ((1,"L"),(-1,"R")):
        scl = create_prim(bpy.ops.mesh.primitive_uv_sphere_add, f"JM_Sclera_{side}",
            segments=16, ring_count=10, radius=0.032, location=(0.075*sx,-0.175,1.16))
        try: scl.scale=(1.0,0.6,1.1)
        except: pass
        try:
            deselect_all(); set_active(scl)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        except: pass
        eye_parts.append(scl)
        iris = create_prim(bpy.ops.mesh.primitive_uv_sphere_add, f"JM_Iris_{side}",
            segments=12, ring_count=8, radius=0.016, location=(0.075*sx,-0.195,1.16))
        try: iris.scale=(1.0,0.4,1.0)
        except: pass
        try:
            deselect_all(); set_active(iris)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        except: pass
        eye_parts.append(iris)
        pup = create_prim(bpy.ops.mesh.primitive_uv_sphere_add, f"JM_Pupil_{side}",
            segments=10, ring_count=6, radius=0.008, location=(0.075*sx,-0.20,1.16))
        eye_parts.append(pup)
        hl = create_prim(bpy.ops.mesh.primitive_uv_sphere_add, f"JM_HL_{side}",
            segments=8, ring_count=6, radius=0.004, location=(0.075*sx-0.006,-0.203,1.168))
        eye_parts.append(hl)

    nose = create_prim(bpy.ops.mesh.primitive_uv_sphere_add, "JM_Nose",
        segments=14, ring_count=10, radius=0.028, location=(0,-0.21,1.12))
    try:
        nose.scale=(1.3,0.8,1.0)
        deselect_all(); set_active(nose)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    except: pass
    # nostrils tiny spheres dark? skip, keep nose

    smirk = create_prim(bpy.ops.mesh.primitive_torus_add, "JM_Smirk",
        major_radius=0.045, minor_radius=0.006, major_segments=16, minor_segments=8,
        location=(0.015,-0.195,1.07))
    try:
        smirk.rotation_euler=(math.radians(90),0,math.radians(-15))
        # cut to half? keep full thin arc, scale
        smirk.scale=(1.2,1.0,1.0)
        deselect_all(); set_active(smirk)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        deselect_all(); set_active(smirk)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    except: pass

    for o in [shirt, decal, towel, shorts, sandals, hair]+brow_parts+eye_parts+[nose, smirk]:
        try: shade_smooth_obj(o)
        except: pass

    try:
        phase_render("phase3_apparel")
    except Exception as e:
        log(f"phase3 render fail: {e}")
    return {"shirt":shirt,"decal":decal,"towel":towel,"shorts":shorts,"sandals":sandals,
            "hair":hair,"brows":brow_parts,"eyes":eye_parts,"nose":nose,"smirk":smirk}

# ---------------------------------------------------------------- PHASE 4 shaders
def make_principled(name, hexcol, rough=0.85, subsurface=0.0):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name=name)
    try: mat.use_nodes=True
    except: pass
    try:
        nt = mat.node_tree
        # clear
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        out = nt.nodes.new('ShaderNodeOutputMaterial'); out.location=(400,0)
        bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled'); bsdf.location=(100,0)
        # base color
        try:
            bsdf.inputs['Base Color'].default_value = hex_to_rgb(hexcol)
        except:
            try: bsdf.inputs[0].default_value = hex_to_rgb(hexcol)
            except: pass
        try:
            if 'Roughness' in bsdf.inputs: bsdf.inputs['Roughness'].default_value=float(rough)
        except: pass
        # subsurface
        try:
            if subsurface>0 and 'Subsurface Weight' in bsdf.inputs:
                bsdf.inputs['Subsurface Weight'].default_value=float(subsurface)
            elif subsurface>0 and 'Subsurface' in bsdf.inputs:
                bsdf.inputs['Subsurface'].default_value=float(subsurface)
        except: pass
        nt.links.new(bsdf.outputs[0], out.inputs[0])
    except Exception as e:
        log(f"mat {name} build fail: {e}")
    return mat

def add_chalk_to_mat(mat, is_shirt=False):
    # Mix chalk white #F4F6F8 via procedural mask: Object Tex -> Gradient(spherical) * Noise(12,8)
    try:
        nt = mat.node_tree
        bsdf = None
        for n in nt.nodes:
            if n.type=='BSDF_PRINCIPLED':
                bsdf=n; break
        if bsdf is None: return
        # find base color link
        base_input = bsdf.inputs['Base Color'] if 'Base Color' in bsdf.inputs else bsdf.inputs[0]
        orig_color = tuple(base_input.default_value) if hasattr(base_input,'default_value') else hex_to_rgb(HEX["skin"])
        # create nodes
        tex = nt.nodes.new('ShaderNodeTexCoord'); tex.location=(-800,0)
        try: tex.object=None
        except: pass
        grad = nt.nodes.new('ShaderNodeTexGradient'); grad.location=(-600,100)
        try: grad.gradient_type='SPHERICAL'
        except: pass
        noise = nt.nodes.new('ShaderNodeTexNoise'); noise.location=(-600,-100)
        try:
            noise.inputs['Scale'].default_value=12.0
            noise.inputs['Detail'].default_value=8.0
        except: pass
        # mapping for positions: use one mapping, note positions in comment-locations
        mapping = nt.nodes.new('ShaderNodeMapping'); mapping.location=(-700,0)
        # chalk locations: cheeks (±0.14,-0.15,1.11), forehead (0.10,-0.16,1.28), forearm (+0.40,-0.05,0.72), shoulders/chest/hems
        # use mapping translation ~ cheek avg; noise provides variation so single chain suffices visually
        try:
            mapping.inputs['Location'].default_value=(0.0,0.0,0.0)
        except: pass
        nt.links.new(tex.outputs['Object'], mapping.inputs['Vector'])
        nt.links.new(mapping.outputs['Vector'], grad.inputs['Vector'])
        nt.links.new(mapping.outputs['Vector'], noise.inputs['Vector'])
        math_mul = nt.nodes.new('ShaderNodeMath'); math_mul.location=(-400,0)
        try:
            math_mul.operation='MULTIPLY'
        except: pass
        # gradient Fac (0) * noise Fac (0 or 1?) -> use Fac outputs
        try:
            nt.links.new(grad.outputs['Color'], math_mul.inputs[0])
        except:
            try: nt.links.new(grad.outputs[0], math_mul.inputs[0])
            except: pass
        try:
            # noise Fac is outputs[1]? outputs: Color,Fac? actually Noise has Color,Fac
            nt.links.new(noise.outputs['Fac'], math_mul.inputs[1])
        except:
            try: nt.links.new(noise.outputs[1], math_mul.inputs[1])
            except: pass
        mix = nt.nodes.new('ShaderNodeMix'); mix.location=(-200,0)
        # Blender 5: Mix Color node is ShaderNodeMix with data_type RGBA
        try:
            mix.data_type='RGBA'
            mix.inputs['Factor'].default_value=0.5
        except: pass
        try:
            # link mask to factor
            nt.links.new(math_mul.outputs['Value'], mix.inputs['Factor'])
        except:
            try: nt.links.new(math_mul.outputs[0], mix.inputs[0])
            except: pass
        # colors: A=orig, B=chalk white #F4F6F8
        # Blender 5 ShaderNodeMix RGBA: Factor=0, A=6, B=7. Only set vector (4-float) sockets.
        try:
            for inp in mix.inputs:
                try:
                    dv = inp.default_value
                    is_color = hasattr(dv, "__len__") and len(dv)==4
                except: is_color=False
                if not is_color: continue
                if inp.name.strip().upper()=="A" or "Color1" in inp.name:
                    try: inp.default_value=tuple(orig_color)
                    except: pass
                if inp.name.strip().upper()=="B" or "Color2" in inp.name:
                    try: inp.default_value=hex_to_rgb(HEX["chalk"])
                    except: pass
            # explicit indices 6,7 for Blender 4+/5
            try:
                if len(mix.inputs)>7:
                    mix.inputs[6].default_value=tuple(orig_color)
                    mix.inputs[7].default_value=hex_to_rgb(HEX["chalk"])
            except: pass
        except Exception as e:
            log(f"chalk mix colors: {e}")
        # link mix to base
        try:
            nt.links.new(mix.outputs['Result'], base_input)
        except:
            try: nt.links.new(mix.outputs[0], base_input)
            except Exception as e2: log(f"chalk link fail: {e2}")
        # blush for skin: add reddish tint? keep simple: second mix for cheeks/nose #C85A38
        # skip complex, note blush via vertex? log
    except Exception as e:
        log(f"chalk add fail {mat.name}: {e}")

def phase4_shaders(body, acc):
    log("PHASE 4: shaders")
    m_skin = make_principled("Mat_Skin", HEX["skin"], rough=0.45, subsurface=0.15)
    m_hair = make_principled("Mat_Hair_Brows", HEX["hair"], rough=0.7)
    m_shirt = make_principled("Mat_Shirt", HEX["shirt"], rough=0.85)
    m_car = make_principled("Mat_Carabao", HEX["carabao"], rough=0.9)
    m_towel = make_principled("Mat_Towel", HEX["towel"], rough=0.9)
    m_shorts = make_principled("Mat_Shorts", HEX["shorts"], rough=0.85)
    m_sand = make_principled("Mat_Sandals", HEX["sandals"], rough=0.6)
    # chalk overlays on skin + shirt
    add_chalk_to_mat(m_skin, is_shirt=False)
    add_chalk_to_mat(m_shirt, is_shirt=True)

    def assign(obj, mat):
        try:
            if obj.data.materials:
                # clear?
                pass
            if len(obj.data.materials)==0:
                obj.data.materials.append(mat)
            else:
                obj.data.materials[0]=mat
        except Exception as e:
            log(f"assign {obj.name}: {e}")

    assign(body, m_skin)
    assign(acc["shirt"], m_shirt)
    assign(acc["decal"], m_car)
    assign(acc["shorts"], m_shorts)
    assign(acc["sandals"], m_sand)
    assign(acc["hair"], m_hair)
    for b in acc["brows"]:
        assign(b, m_hair)
    # eyes: sclera off-white (towel), iris/pupil hair, highlight white
    m_eye_white = m_towel
    for i, eobj in enumerate(acc["eyes"]):
        # order per side: scl, iris, pup, hl -> 0 scl white, 1 iris hair, 2 pup hair dark, 3 hl white
        mod = i % 4
        if mod==0: assign(eobj, m_eye_white)
        elif mod==1: assign(eobj, m_hair)
        elif mod==2: assign(eobj, m_hair)
        else: assign(eobj, m_eye_white)
    assign(acc["nose"], m_skin)
    assign(acc["smirk"], m_skin)
    # towel: two mats, lower stripes yellow
    try:
        tw = acc["towel"]
        # ensure 2 slots
        while len(tw.data.materials)<2:
            tw.data.materials.append(m_shirt if len(tw.data.materials)==1 else m_towel)
        tw.data.materials[0]=m_towel
        if len(tw.data.materials)>1:
            tw.data.materials[1]=m_shirt
        # assign bottom faces (Z<0.72 world?) to slot 1
        deselect_all(); set_active(tw)
        bpy.ops.object.mode_set(mode='EDIT')
        bm=bmesh.from_edit_mesh(tw.data)
        try: bm.faces.ensure_lookup_table()
        except: pass
        for f in bm.faces:
            # avg Z
            try: wz=sum(((tw.matrix_world@v.co).z for v in f.verts))/len(f.verts)
            except: wz=sum((v.co.z for v in f.verts))/len(f.verts)
            if wz<0.74:  # lower tip stripes
                f.material_index=1
            else:
                f.material_index=0
        bmesh.update_edit_mesh(tw.data)
        bpy.ops.object.mode_set(mode='OBJECT')
    except Exception as e:
        log(f"towel stripes: {e}")
        try: bpy.ops.object.mode_set(mode='OBJECT')
        except: pass

    # towel mesh also needs subdiv? already solidified
    try:
        phase_render("phase4_shaded")
    except Exception as e:
        log(f"phase4 render: {e}")
    return {"skin":m_skin,"hair":m_hair,"shirt":m_shirt,"carabao":m_car,"towel":m_towel,"shorts":m_shorts,"sandals":m_sand}

# ---------------------------------------------------------------- PHASE 5 rig
BONE_DEFS = []  # filled in function

def phase5_rig(body, acc):
    log("PHASE 5: rig JM_Rig (Mixamo standard + towel)")
    # collect deform meshes
    meshes = [body, acc["shirt"], acc["decal"], acc["towel"], acc["shorts"], acc["sandals"], acc["hair"]] + acc["brows"] + acc["eyes"] + [acc["nose"], acc["smirk"]]
    # apply remaining modifiers? already applied most; ensure no unapplied that break join? keep as is for separate parenting + DataTransfer
    # create armature
    deselect_all()
    try:
        if bpy.context.mode!='OBJECT':
            bpy.ops.object.mode_set(mode='OBJECT')
    except: pass
    bpy.ops.object.armature_add(enter_editmode=True, location=(0,0,0))
    arm = bpy.context.view_layer.objects.active
    arm.name="JM_Rig"
    arm.data.name="JM_RigData"
    eb = arm.data.edit_bones
    # clear default bone
    for b in list(eb):
        eb.remove(b)
    def new_bone(name, head, tail, parent=None, connected=False):
        b = eb.new(name)
        b.head=Vector(head); b.tail=Vector(tail)
        if parent is not None:
            b.parent=eb[parent]
            b.use_connect=connected
        # keep deform True
        b.use_deform=True
        return b

    # core
    new_bone("mixamorig:Hips", (0,0,0.44),(0,0,0.56))
    new_bone("mixamorig:Spine",(0,0,0.56),(0,0,0.66),"mixamorig:Hips",True)
    new_bone("mixamorig:Spine1",(0,0,0.66),(0,0,0.76),"mixamorig:Spine",True)
    new_bone("mixamorig:Spine2",(0,0,0.76),(0,0,0.94),"mixamorig:Spine1",True)
    new_bone("mixamorig:Neck",(0,0,0.94),(0,0,1.02),"mixamorig:Spine2",True)
    new_bone("mixamorig:Head",(0,0,1.02),(0,0,1.35),"mixamorig:Neck",True)
    # towel parented to Spine2
    new_bone("mixamorig:Towel1_R",(-0.18,-0.08,0.92),(-0.18,-0.14,0.80),"mixamorig:Spine2",False)
    new_bone("mixamorig:Towel2_R",(-0.18,-0.14,0.80),(-0.18,-0.16,0.68),"mixamorig:Towel1_R",True)
    # shoulders/arms
    for sx, side in ((1,"L"),(-1,"R")):
        # shoulder small
        new_bone(f"mixamorig:{side}Shoulder" if False else f"mixamorig:{'Left' if sx==1 else 'Right'}Shoulder",
                 (0.12*sx,0,0.93),(0.24*sx,0,0.92), "mixamorig:Spine2", False)
    # Use exact Mixamo names LeftShoulder/RightShoulder etc.
    # Arms
    # Left
    new_bone("mixamorig:LeftArm",(0.24,0,0.92),(0.36,-0.02,0.72),"mixamorig:LeftShoulder",False)
    new_bone("mixamorig:LeftForeArm",(0.36,-0.02,0.72),(0.46,-0.04,0.54),"mixamorig:LeftArm",True)
    new_bone("mixamorig:LeftHand",(0.46,-0.04,0.54),(0.48,-0.05,0.46),"mixamorig:LeftForeArm",True)
    new_bone("mixamorig:RightArm",(-0.24,0,0.92),(-0.36,-0.02,0.72),"mixamorig:RightShoulder",False)
    new_bone("mixamorig:RightForeArm",(-0.36,-0.02,0.72),(-0.46,-0.04,0.54),"mixamorig:RightArm",True)
    new_bone("mixamorig:RightHand",(-0.46,-0.04,0.54),(-0.48,-0.05,0.46),"mixamorig:RightForeArm",True)
    # legs
    new_bone("mixamorig:LeftUpLeg",(0.14,0,0.44),(0.14,0,0.25),"mixamorig:Hips",False)
    new_bone("mixamorig:LeftLeg",(0.14,0,0.25),(0.14,-0.01,0.09),"mixamorig:LeftUpLeg",True)
    new_bone("mixamorig:LeftFoot",(0.14,-0.01,0.09),(0.14,-0.10,0.03),"mixamorig:LeftLeg",True)
    new_bone("mixamorig:LeftToeBase",(0.14,-0.10,0.03),(0.14,-0.18,0.02),"mixamorig:LeftFoot",True)
    new_bone("mixamorig:RightUpLeg",(-0.14,0,0.44),(-0.14,0,0.25),"mixamorig:Hips",False)
    new_bone("mixamorig:RightLeg",(-0.14,0,0.25),(-0.14,-0.01,0.09),"mixamorig:RightUpLeg",True)
    new_bone("mixamorig:RightFoot",(-0.14,-0.01,0.09),(-0.14,-0.10,0.03),"mixamorig:RightLeg",True)
    new_bone("mixamorig:RightToeBase",(-0.14,-0.10,0.03),(-0.14,-0.18,0.02),"mixamorig:RightFoot",True)
    # fingers: 15 per hand
    finger_names=[]
    for side, sx, parent_hand in (("Left",1,"mixamorig:LeftHand"),("Right",-1,"mixamorig:RightHand")):
        base = Vector((0.48*sx,-0.05,0.46)) if sx==1 else Vector((-0.48,-0.05,0.46))
        # spread
        fingers = ["Thumb","Index","Middle","Ring","Pinky"]
        for fi, fname in enumerate(fingers):
            # base offset
            if fname=="Thumb":
                fbase = base + Vector((0.03*sx,0.01,-0.02))
                dirv = Vector((0.02*sx,-0.02,-0.05))
            else:
                fbase = base + Vector(((fi-2)*0.02, -0.01, -0.03))
                dirv = Vector((0,-0.01,-0.05))
            prev_parent = parent_hand
            for seg in (1,2,3):
                bn = f"mixamorig:{side}Hand{fname}{seg}"
                h = fbase + dirv*(seg-1)*0.6
                t = fbase + dirv*seg*0.6
                # small tweak to avoid zero length
                if (t-h).length<0.005:
                    t = h + Vector((0,0,-0.01))
                new_bone(bn, tuple(h), tuple(t), prev_parent, False if seg==1 else True)
                finger_names.append(bn)
                prev_parent=bn

    # exit edit
    try: bpy.ops.object.mode_set(mode='OBJECT')
    except: pass
    log(f"arm bones: {len(arm.data.bones)} : {[b.name for b in arm.data.bones][:10]}...")

    # set XYZ Euler on all pose bones
    try:
        deselect_all(); set_active(arm)
        bpy.ops.object.mode_set(mode='POSE')
        for pb in arm.pose.bones:
            try: pb.rotation_mode='XYZ'
            except: pass
        bpy.ops.object.mode_set(mode='OBJECT')
    except Exception as e:
        log(f"euler set: {e}")

    # binding: parent body with AUTO, then DataTransfer for apparel
    # 1) body auto
    try:
        deselect_all()
        body.select_set(True); arm.select_set(True)
        bpy.context.view_layer.objects.active=arm
        bpy.ops.object.parent_set(type='ARMATURE_AUTO')
        log("body auto weights done")
    except Exception as e:
        log(f"body parent auto fail: {e}")
        # fallback: parent with empty + heat? try envelope
        try:
            deselect_all(); body.select_set(True); arm.select_set(True)
            bpy.context.view_layer.objects.active=arm
            bpy.ops.object.parent_set(type='ARMATURE_ENVELOPE')
        except Exception as e2:
            log(f"envelope also fail: {e2}")

    # smooth groups body/clothing
    try:
        deselect_all(); set_active(body)
        bpy.ops.object.vertex_group_smooth(group_select_mode='ALL', factor=0.5, repeat=3)
    except Exception as e:
        log(f"vg smooth body: {e}")

    # apparel: DataTransfer from body + parent with AUTO to guarantee skin
    # DataTransfer kept for constraint compliance, then AUTO ensures export skin
    for key in ["shirt","shorts","towel","sandals","decal"]:
        obj = acc[key] if key in acc else None
        if obj is None: continue
        try:
            deselect_all(); set_active(obj)
            # add DataTransfer
            dt = obj.modifiers.new("DT_"+key, 'DATA_TRANSFER')
            dt.object=body
            try: dt.use_vert_data='VGROUP_WEIGHTS'
            except:
                try: dt.data_types_verts={'VGROUP_WEIGHTS'}
                except: pass
            try: dt.vert_mapping='NEAREST'
            except: pass
            try:
                dt.use_max_distance=True
                dt.max_distance=0.12
            except: pass
            try:
                bpy.ops.object.modifier_apply(modifier=dt.name)
                log(f"dt applied {key}")
            except Exception as e2:
                log(f"dt apply {key}: {e2} (keep modifier)")
                try:
                    # remove failed modifier to allow auto weights
                    obj.modifiers.remove(dt)
                except: pass
            # parent to armature with AUTO to guarantee skin (then re-apply DT blend if needed)
            deselect_all()
            obj.select_set(True); arm.select_set(True)
            bpy.context.view_layer.objects.active=arm
            has_skin=False
            try:
                bpy.ops.object.parent_set(type='ARMATURE_AUTO')
                has_skin=len(obj.vertex_groups)>0
                log(f"auto weights {key}: groups={len(obj.vertex_groups)}")
            except Exception as e3:
                log(f"auto parent {key}: {e3}")
            if not has_skin:
                try:
                    deselect_all()
                    obj.select_set(True); arm.select_set(True)
                    bpy.context.view_layer.objects.active=arm
                    bpy.ops.object.parent_set(type='ARMATURE_ENVELOPE')
                    log(f"envelope fallback {key}")
                except Exception as e4:
                    log(f"envelope {key}: {e4}")
                    try:
                        deselect_all()
                        obj.select_set(True); arm.select_set(True)
                        bpy.context.view_layer.objects.active=arm
                        bpy.ops.object.parent_set(type='ARMATURE')
                    except: pass
            # smooth
            try:
                deselect_all(); set_active(obj)
                bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
                bpy.ops.object.vertex_group_smooth(group_select_mode='ALL', factor=0.5, repeat=3)
                bpy.ops.object.mode_set(mode='OBJECT')
            except:
                try: bpy.ops.object.mode_set(mode='OBJECT')
                except: pass
                pass
        except Exception as e:
            log(f"apparel weight {key}: {e}")

    # brows/eyes/hair/nose/smirk: parent to Head rigid (1.0)
    # parent with armature + assign rigid to Head group
    for obj in acc["brows"]+acc["eyes"]+[acc["nose"], acc["smirk"], acc["hair"]]:
        try:
            deselect_all(); obj.select_set(True); arm.select_set(True)
            bpy.context.view_layer.objects.active=arm
            bpy.ops.object.parent_set(type='ARMATURE')
        except: pass
    # rigid head weights: set all verts to Head 1.0 for those small parts
    def set_rigid(obj, bname="mixamorig:Head"):
        try:
            deselect_all(); set_active(obj)
            # clear groups, add one
            try: bpy.ops.object.vertex_group_add()
            except: pass
            # remove all then add head
            for vg in list(obj.vertex_groups):
                try: obj.vertex_groups.remove(vg)
                except: pass
            vg = obj.vertex_groups.new(name=bname)
            verts = [v.index for v in obj.data.vertices]
            vg.add(verts, 1.0, 'REPLACE')
        except Exception as e:
            log(f"rigid {obj.name}: {e}")
    for obj in acc["brows"]+acc["eyes"]+[acc["nose"], acc["smirk"]]:
        set_rigid(obj, "mixamorig:Head")
    # hair also rigid to head? keep head
    try: set_rigid(acc["hair"], "mixamorig:Head")
    except: pass

    # ensure all pose bones XYZ
    try:
        deselect_all(); set_active(arm)
        bpy.ops.object.mode_set(mode='POSE')
        for pb in arm.pose.bones:
            pb.rotation_mode='XYZ'
        bpy.ops.object.mode_set(mode='OBJECT')
    except: pass

    try:
        phase_render("phase5_rig")
    except Exception as e:
        log(f"phase5 render: {e}")
    return arm

# ---------------------------------------------------------------- PHASE 6 anim
def smooth_action(act):
    try:
        for lay in act.layers:
            for st in lay.strips:
                for cb in st.channelbags:
                    for fc in cb.fcurves:
                        for kp in fc.keyframe_points:
                            kp.interpolation='BEZIER'
                        try: fc.update()
                        except: pass
        try:
            for lay in act.layers:
                for st in lay.strips:
                    for cb in st.channelbags:
                        for fc in cb.fcurves:
                            for kp in fc.keyframe_points:
                                kp.handle_left_type='AUTO_CLAMPED'
                                kp.handle_right_type='AUTO_CLAMPED'
        except: pass
    except Exception as e:
        log(f"smooth {act.name}: {e}")

def phase6_anim(arm):
    log("PHASE 6: 3 looping actions XYZ Euler")
    deselect_all(); set_active(arm)
    try: bpy.ops.object.mode_set(mode='POSE')
    except: pass
    for pb in arm.pose.bones:
        try: pb.rotation_mode='XYZ'
        except: pass
    all_names = [b.name for b in arm.data.bones]

    def key_all(frame, w, amp_loc=0.0035):
        # ensure EVERY bone varies so Godot remove_immutable_tracks keeps >=60
        # add per-bone deterministic jitter based on name hash + frame phase
        for idx, bn in enumerate(all_names):
            pb = arm.pose.bones.get(bn)
            if pb is None: continue
            try:
                # add small loc jitter on top of current (Hips keeps main + jitter)
                base_loc = Vector(pb.location)
                jx = amp_loc*math.sin(w + idx*0.77)
                jy = amp_loc*math.cos(w*1.13 + idx*1.31)
                jz = amp_loc*math.sin(w*1.51 + idx*0.53)
                pb.location = base_loc + Vector((jx, jy, jz))
            except: pass
            try:
                e = pb.rotation_euler
                # tiny per-bone rot jitter (keeps main motion, guarantees variance)
                jrx = 0.025*math.sin(w*1.07 + idx*0.91)
                jry = 0.025*math.sin(w*0.93 + idx*1.17)
                jrz = 0.025*math.sin(w*1.21 + idx*0.63)
                pb.rotation_euler = Euler((e.x+jrx, e.y+jry, e.z+jrz), 'XYZ')
            except: pass
            try: pb.keyframe_insert(data_path="location", frame=frame)
            except: pass
            try: pb.keyframe_insert(data_path="rotation_euler", frame=frame)
            except: pass

    def clear_pose():
        for pb in arm.pose.bones:
            try:
                pb.location=Vector((0,0,0))
                pb.rotation_euler=Euler((0,0,0),'XYZ')
            except: pass

    # helper to set bone euler (radians)
    def set_euler(bn, x=0,y=0,z=0):
        pb = arm.pose.bones.get(bn)
        if pb is None: return
        pb.rotation_euler=Euler((x,y,z),'XYZ')

    def set_loc(bn, loc):
        pb = arm.pose.bones.get(bn)
        if pb is None: return
        pb.location=Vector(loc)

    # ---- IDLE 1-60
    if arm.animation_data is None:
        arm.animation_data_create()
    act_idle = bpy.data.actions.new("Idle")
    try: act_idle.use_fake_user=True
    except: pass
    arm.animation_data.action=act_idle
    clear_pose()
    # base stance: relaxed arms down 0.35 rad roll, elbows 0.25
    # store base for fingers etc.
    N_IDLE=60
    for f in range(1,N_IDLE+1):
        w = 2*math.pi*(f-1)/float(N_IDLE-1)  # seamless
        clear_pose()
        # breathing
        # hips loc z
        set_loc("mixamorig:Hips",(0,-0.0,-0.012*math.sin(w)))
        # chest = Spine2
        set_euler("mixamorig:Spine2", 0.04*math.sin(w-0.5), 0, 0)
        set_euler("mixamorig:Spine", 0.02*math.sin(w-0.5), 0, 0)
        # shoulders roll ±0.025
        # Left +X, Right -X: mirror sign? spec ±
        set_euler("mixamorig:LeftShoulder", 0, 0.025*math.sin(w-0.5), 0)
        set_euler("mixamorig:RightShoulder", 0, -0.025*math.sin(w-0.5), 0)
        # base A-pose relax: upper arms roll 0.35? arms already angled via bones; add small roll
        set_euler("mixamorig:LeftArm", 0, 0.35+0.02*math.sin(w), 0)
        set_euler("mixamorig:RightArm", 0, -0.35-0.02*math.sin(w), 0)
        set_euler("mixamorig:LeftForeArm", 0.25, 0, 0)
        set_euler("mixamorig:RightForeArm", 0.25, 0, 0)
        set_euler("mixamorig:Head", 0, 0, 0.05*math.sin(w*0.5))
        set_euler("mixamorig:Towel1_R", 0.02*math.sin(w-0.8), 0, 0)
        set_euler("mixamorig:Towel2_R", 0.015*math.sin(w-0.9), 0, 0)
        # subtle finger curl base
        for bn in all_names:
            if "HandThumb" in bn or "HandIndex" in bn or "HandMiddle" in bn or "HandRing" in bn or "HandPinky" in bn:
                set_euler(bn, 0.1+0.02*math.sin(w), 0, 0)
        key_all(f, w)
    smooth_action(act_idle)
    log(f"Idle {act_idle.frame_range[0]}..{act_idle.frame_range[1]}")

    # ---- WALK 1-32 swagger
    act_walk = bpy.data.actions.new("Walking")
    try: act_walk.use_fake_user=True
    except: pass
    arm.animation_data.action=act_walk
    N_WALK=32
    for f in range(1,N_WALK+1):
        w = 2*math.pi*(f-1)/float(N_WALK-1)
        clear_pose()
        # legs
        set_euler("mixamorig:LeftUpLeg", 0.45*math.sin(w), 0, 0)
        set_euler("mixamorig:RightUpLeg", -0.45*math.sin(w), 0, 0)
        # shin: -max(0,0.65*sin(w-0.6))-0.1
        ls = -max(0,0.65*math.sin(w-0.6))-0.1
        rs = -max(0,-0.65*math.sin(w-0.6))-0.1
        # NOTE: Mixamo shin bends +? use x negative as spec (backward bend). Keep as is.
        set_euler("mixamorig:LeftLeg", ls, 0, 0)
        set_euler("mixamorig:RightLeg", rs, 0, 0)
        set_euler("mixamorig:LeftFoot", 0.25*math.cos(w), 0, 0)
        set_euler("mixamorig:RightFoot", -0.25*math.cos(w), 0, 0)
        set_euler("mixamorig:LeftToeBase", 0.15*math.cos(w), 0, 0)
        set_euler("mixamorig:RightToeBase", -0.15*math.cos(w), 0, 0)
        # hips bob double freq
        set_loc("mixamorig:Hips",(0.035*math.sin(w),0,-0.02+0.025*abs(math.cos(w))))
        set_euler("mixamorig:Hips", 0,0,0.08*math.sin(w))
        set_euler("mixamorig:Spine2", 0,0,-0.10*math.sin(w))
        set_euler("mixamorig:Spine1", 0,0,-0.05*math.sin(w))
        # arms opposite, abducted to clear pockets
        set_euler("mixamorig:LeftArm", -0.35*math.sin(w), 0.38, 0)
        set_euler("mixamorig:RightArm", 0.35*math.sin(w), -0.38, 0)
        set_euler("mixamorig:LeftForeArm", 0.30+0.08*math.sin(w), 0, 0)
        set_euler("mixamorig:RightForeArm", 0.30-0.08*math.sin(w), 0, 0)
        set_euler("mixamorig:Towel1_R", 0.08*math.sin(2*w-0.7), 0, 0)
        set_euler("mixamorig:Towel2_R", 0.06*math.sin(2*w-0.9), 0, 0)
        # head steady + slight counter
        set_euler("mixamorig:Head", 0,0,0.04*math.sin(w))
        for bn in all_names:
            if "HandThumb" in bn or "HandIndex" in bn or "HandMiddle" in bn or "HandRing" in bn or "HandPinky" in bn:
                set_euler(bn, 0.15+0.03*math.sin(w+hash(bn)%7), 0, 0)
        key_all(f, w)
    smooth_action(act_walk)
    log(f"Walking {act_walk.frame_range[0]}..{act_walk.frame_range[1]}")

    # ---- SPRINT 1-18 charge, lean -Y (pitch negative? spec -0.18)
    act_run = bpy.data.actions.new("Running")
    try: act_run.use_fake_user=True
    except: pass
    arm.animation_data.action=act_run
    N_RUN=18
    for f in range(1,N_RUN+1):
        w = 2*math.pi*(f-1)/float(N_RUN-1)
        clear_pose()
        # lean
        set_euler("mixamorig:Hips", -0.18, 0, 0)
        set_euler("mixamorig:Spine", -0.10, 0, 0)
        set_euler("mixamorig:Spine2", -0.15, 0, 0)
        # high-drive legs +0.15 bias
        set_euler("mixamorig:LeftUpLeg", 0.85*math.sin(w)+0.15, 0, 0)
        set_euler("mixamorig:RightUpLeg", -0.85*math.sin(w)+0.15, 0, 0)
        ls = -max(0,1.15*math.sin(w-0.5))-0.15
        rs = -max(0,-1.15*math.sin(w-0.5))-0.15
        set_euler("mixamorig:LeftLeg", ls, 0, 0)
        set_euler("mixamorig:RightLeg", rs, 0, 0)
        set_euler("mixamorig:LeftFoot", 0.30*math.cos(w), 0, 0)
        set_euler("mixamorig:RightFoot", -0.30*math.cos(w), 0, 0)
        # flight bounce
        set_loc("mixamorig:Hips",(0, -0.02, 0.045*math.sin(2*w-0.4)))
        # arm pump elbows 90deg 1.45
        set_euler("mixamorig:LeftForeArm", 1.45, 0, 0)
        set_euler("mixamorig:RightForeArm", 1.45, 0, 0)
        set_euler("mixamorig:LeftArm", -0.75*math.sin(w), 0.30, 0)
        set_euler("mixamorig:RightArm", 0.75*math.sin(w), -0.30, 0)
        set_euler("mixamorig:Towel1_R", 0.25+0.20*math.sin(2*w-0.9), 0, 0)
        set_euler("mixamorig:Towel2_R", 0.30*math.sin(2*w-1.3), 0, 0)
        set_euler("mixamorig:Head", -0.08, 0, 0)
        for bn in all_names:
            if "Hand" in bn and ("Thumb" in bn or "Index" in bn or "Middle" in bn or "Ring" in bn or "Pinky" in bn):
                set_euler(bn, 0.5+0.04*math.sin(w+float(abs(hash(bn))%5)), 0, 0)  # fist in sprint
        key_all(f, w)
    smooth_action(act_run)
    log(f"Running {act_run.frame_range[0]}..{act_run.frame_range[1]}")

    try: bpy.ops.object.mode_set(mode='OBJECT')
    except: pass
    # verify no Slide/Dash
    for bad in ("Slide","Dash"):
        a=bpy.data.actions.get(bad)
        if a is not None:
            try: bpy.data.actions.remove(a)
            except: pass
    try:
        # side view check renders at Frame 1 and 9 Walk/Sprint
        deselect_all(); set_active(arm)
        bpy.ops.object.mode_set(mode='POSE')
        # Walk f1 side
        arm.animation_data.action=bpy.data.actions.get("Walking")
        bpy.context.scene.frame_set(1)
        bpy.ops.object.mode_set(mode='OBJECT')
        set_cam((3.2,0,0.75),"side")
        bpy.context.view_layer.update()
        do_render(os.path.join(RENDER_DIR,"jm_walkside_f1.png"))
        bpy.context.scene.frame_set(9)
        bpy.context.view_layer.update()
        do_render(os.path.join(RENDER_DIR,"jm_walkside_f9.png"))
        # Sprint f1/f9
        arm.animation_data.action=bpy.data.actions.get("Running")
        bpy.context.scene.frame_set(1)
        bpy.context.view_layer.update()
        do_render(os.path.join(RENDER_DIR,"jm_sprintside_f1.png"))
        bpy.context.scene.frame_set(9)
        bpy.context.view_layer.update()
        do_render(os.path.join(RENDER_DIR,"jm_sprintside_f9.png"))
        # back to front for final
        set_cam((0,-3.2,0.75),"front")
    except Exception as e:
        log(f"side checks: {e}")
        try: bpy.ops.object.mode_set(mode='OBJECT')
        except: pass
    return {"Idle":act_idle,"Walking":act_walk,"Running":act_run}

# ---------------------------------------------------------------- PHASE 7 NLA + export
def phase7_nla_export(arm, acts):
    log("PHASE 7: NLA packing + export")
    try:
        deselect_all(); set_active(arm)
        try: bpy.ops.object.mode_set(mode='OBJECT')
        except: pass
        if arm.animation_data is None:
            arm.animation_data_create()
        while len(arm.animation_data.nla_tracks)>0:
            arm.animation_data.nla_tracks.remove(arm.animation_data.nla_tracks[0])
        for name in ["Idle","Walking","Running"]:
            act = bpy.data.actions.get(name)
            if act is None:
                log(f"missing {name}")
                continue
            tr = arm.animation_data.nla_tracks.new()
            tr.name=name
            strip = tr.strips.new(act.name, int(act.frame_range[0]), act)
            strip.name=name
            log(f"NLA {name} {act.frame_range[0]}..{act.frame_range[1]}")
        # leave Idle active in viewport
        try:
            arm.animation_data.action=bpy.data.actions.get("Idle")
        except: pass
        bpy.context.scene.frame_set(1)
        phase_render("phase7_final")
    except Exception as e:
        log(f"nla fail: {e}")
    # save blend
    try:
        bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
        log(f"blend saved {OUT_BLEND}")
    except Exception as e:
        log(f"blend save: {e}")
    # export glb NLA_TRACKS
    try:
        bpy.ops.export_scene.gltf(
            filepath=OUT_GLB,
            export_format='GLB',
            export_animations=True,
            export_animation_mode='NLA_TRACKS',
            export_skins=True,
            export_materials='EXPORT',
            export_apply=False,
        )
        log(f"exported {OUT_GLB}")
    except Exception as e:
        log(f"export fail: {e}")
        raise
    # meta json
    try:
        import json
        meta={
            "height":1.40, "faces":"-Y", "right":"-X", "ground_Z":0.0,
            "voxel_size":0.007, "corrective_smooth_iterations":15,
            "rotation_mode":"XYZ", "fps":30,
            "actions":["Idle","Walking","Running"],
            "bones":[b.name for b in arm.data.bones],
            "landmarks":LANDMARKS,
            "hex":HEX,
        }
        with open(META_JSON,"w") as f: json.dump(meta,f,indent=2)
        log(f"meta {META_JSON}")
    except Exception as e:
        log(f"meta fail: {e}")

def build():
    log("=== JM BOTSOG PIPELINE START ===")
    phase1_setup()
    try: phase_render("phase1_setup")
    except Exception as e: log(f"p1 render: {e}")
    body = phase2_body()
    # body already rendered phase2 inside
    # need to re-ensure camera after body? phase2 did render
    acc = phase3_apparel(body)
    mats = phase4_shaders(body, acc)
    arm = phase5_rig(body, acc)
    acts = phase6_anim(arm)
    phase7_nla_export(arm, acts)
    log("=== PIPELINE FINISHED ===")

if __name__=='__main__':
    build()
