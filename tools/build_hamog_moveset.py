"""Batang Hamog moveset authoring — Phase 1.
Loads the current game-ready GLB (preserves mesh/textures/Idle/Walking/Running/RunFast),
purges legacy Slide/Dash/Roll, authors Harurot (24f), Lusot_Slide (24f 0..23),
Lusot_Vault (15f 0..14) @24fps, pushes clean NLA tracks and re-exports.
Run: blender -b --python tools/build_hamog_moveset.py
"""
import bpy
from mathutils import Vector, Euler
import math
import os

# Repo root, resolved from this file (blender -b --python sets __file__).
PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE_GLB = os.path.join(PROJ, "assets", "characters", "batang_hamog.glb")
OUT_GLB = BASE_GLB  # rebuilds the game GLB in place

# Exact Idle frame-0 stance from tools/build_batang_hamog.py (must match for seamless pop).
IDLE_F0 = {
    "mixamorig:Hips": ((0.010, -0.020, 0.000), (0.0, 0.0, -3.5)),
    "mixamorig:Spine": (None, (5.5, 1.5, 2.5)),
    "mixamorig:Spine1": (None, (3.5, 1.0, 1.0)),
    "mixamorig:Spine2": (None, (2.5, 0.0, 0.0)),
    "mixamorig:Neck": (None, (-3.5, 0.0, -2.0)),
    "mixamorig:Head": (None, (-3.5, 2.0, 2.5)),
    "mixamorig:LeftShoulder": (None, (0.0, 0.0, 0.0)),
    "mixamorig:RightShoulder": (None, (0.0, 0.0, 0.0)),
    "mixamorig:LeftArm": (None, (-4.0, 9.0, -7.0)),
    "mixamorig:LeftForeArm": (None, (16.0, 0.0, 0.0)),
    "mixamorig:LeftHand": (None, (0.0, 0.0, 8.0)),
    "mixamorig:RightArm": (None, (-5.5, -7.5, 5.5)),
    "mixamorig:RightForeArm": (None, (18.0, 0.0, 0.0)),
    "mixamorig:RightHand": (None, (0.0, 0.0, -8.0)),
    "mixamorig:LeftUpLeg": (None, (9.0, 5.0, -3.5)),
    "mixamorig:LeftLeg": (None, (-11.0, 0.0, 0.0)),
    "mixamorig:LeftFoot": (None, (2.5, -3.5, 3.5)),
    "mixamorig:RightUpLeg": (None, (-3.5, -3.5, 3.5)),
    "mixamorig:RightLeg": (None, (-5.5, 0.0, 0.0)),
    "mixamorig:RightFoot": (None, (7.0, 1.5, -2.5)),
}

def build():
    print("=== HAMOG MOVESET PIPELINE START ===")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24
    bpy.ops.import_scene.gltf(filepath=BASE_GLB)

    arm = None
    for obj in bpy.data.objects:
        if obj.type == 'ARMATURE':
            arm = obj
            break
    if arm is None:
        raise RuntimeError("Armature not found in base GLB")

    print(f"Armature: {arm.name}, bones: {len(arm.data.bones)}")
    print(f"Pre-existing actions: {[a.name for a in bpy.data.actions]}")

    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='POSE')
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'

    all_bone_names = [b.name for b in arm.data.bones]

    def euler_to_quat(deg):
        eu = Euler((math.radians(deg[0]), math.radians(deg[1]), math.radians(deg[2])), 'XYZ')
        return eu.to_quaternion()

    def apply_pose(pose_dict, frame):
        for bname in all_bone_names:
            pb = arm.pose.bones.get(bname)
            if pb is None:
                continue
            loc, rot = pose_dict.get(bname, (None, None)) if bname in pose_dict else (None, None)
            # Default: zero location, identity rotation
            if loc is None:
                # Hips keeps explicit loc when given; other bones stay at 0
                if bname == "mixamorig:Hips" and bname in pose_dict and pose_dict[bname][0] is not None:
                    loc = pose_dict[bname][0]
                else:
                    # keep current loc for non-hips? force 0 for hygiene
                    pb.location = Vector((0.0, 0.0, 0.0))
            else:
                pb.location = Vector(loc)
            if rot is None:
                if bname in pose_dict and pose_dict[bname][1] is not None:
                    rot = pose_dict[bname][1]
                else:
                    pb.rotation_quaternion = Euler((0, 0, 0), 'XYZ').to_quaternion()
                    pb.keyframe_insert(data_path="location", frame=frame)
                    pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)
                    continue
            if loc is not None or bname == "mixamorig:Hips":
                pass
            pb.rotation_quaternion = euler_to_quat(rot)
            pb.keyframe_insert(data_path="location", frame=frame)
            pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)

    def smooth_action(act):
        try:
            for lay in act.layers:
                for st in lay.strips:
                    for cb in st.channelbags:
                        for fc in cb.fcurves:
                            for kp in fc.keyframe_points:
                                kp.interpolation = 'BEZIER'
                            try:
                                fc.update()
                            except Exception:
                                pass
            try:
                for lay in act.layers:
                    for st in lay.strips:
                        for cb in st.channelbags:
                            for fc in cb.fcurves:
                                for kp in fc.keyframe_points:
                                    kp.handle_left_type = 'AUTO_CLAMPED'
                                    kp.handle_right_type = 'AUTO_CLAMPED'
            except Exception:
                pass
        except Exception as e:
            print(f"smooth note {act.name}: {e}")

    # ---- 1. PURGE legacy + stale new clips ----
    for stale in ("Slide", "Dash", "Roll", "Harurot", "Lusot_Slide", "Lusot_Vault"):
        a = bpy.data.actions.get(stale)
        if a is not None:
            bpy.data.actions.remove(a)
            print(f"Purged action: {stale}")
    # Purge any other unexpected actions (keep only locomotion set)
    allowed_keep = {"Idle", "Walking", "Running", "RunFast"}
    for a in list(bpy.data.actions):
        if a.name not in allowed_keep:
            print(f"Purging unexpected action: {a.name}")
            bpy.data.actions.remove(a)
    print(f"Actions after purge: {[a.name for a in bpy.data.actions]}")

    # ---- 2. HARUROT (frames 0..24 @24fps) ----
    harurot_keys = [
        (0, {
            "mixamorig:Hips": ((0.010, -0.090, 0.000), (0.0, 0.0, -3.5)),
            "mixamorig:Spine": (None, (14.0, 2.0, 2.0)),
            "mixamorig:Spine1": (None, (8.0, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (6.0, 0.0, 0.0)),
            "mixamorig:Neck": (None, (-5.0, 0.0, -2.0)),
            "mixamorig:Head": (None, (-5.0, 2.0, 2.0)),
            "mixamorig:LeftArm": (None, (25.0, 12.0, -8.0)),
            "mixamorig:LeftForeArm": (None, (30.0, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (30.0, -10.0, 6.0)),
            "mixamorig:RightForeArm": (None, (32.0, 0.0, 0.0)),
            "mixamorig:LeftUpLeg": (None, (25.0, 5.0, -3.0)),
            "mixamorig:LeftLeg": (None, (-25.0, 0.0, 0.0)),
            "mixamorig:LeftFoot": (None, (5.0, 0.0, 0.0)),
            "mixamorig:RightUpLeg": (None, (15.0, -3.0, 3.0)),
            "mixamorig:RightLeg": (None, (-25.0, 0.0, 0.0)),
            "mixamorig:RightFoot": (None, (5.0, 0.0, 0.0)),
        }),
        (4, {
            "mixamorig:Hips": ((0.010, -0.110, 0.000), (0.0, 0.0, -3.5)),
            "mixamorig:Spine": (None, (16.0, 2.0, 2.0)),
            "mixamorig:Spine1": (None, (10.0, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (7.0, 0.0, 0.0)),
            "mixamorig:Neck": (None, (-6.0, 0.0, -2.0)),
            "mixamorig:Head": (None, (-6.0, 2.0, 2.0)),
            "mixamorig:LeftArm": (None, (35.0, 12.0, -8.0)),
            "mixamorig:LeftForeArm": (None, (35.0, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (38.0, -10.0, 6.0)),
            "mixamorig:RightForeArm": (None, (36.0, 0.0, 0.0)),
            "mixamorig:LeftUpLeg": (None, (30.0, 5.0, -3.0)),
            "mixamorig:LeftLeg": (None, (-35.0, 0.0, 0.0)),
            "mixamorig:LeftFoot": (None, (8.0, 0.0, 0.0)),
            "mixamorig:RightUpLeg": (None, (20.0, -3.0, 3.0)),
            "mixamorig:RightLeg": (None, (-35.0, 0.0, 0.0)),
            "mixamorig:RightFoot": (None, (8.0, 0.0, 0.0)),
        }),
        (8, {
            "mixamorig:Hips": ((0.020, 0.000, 0.080), (0.0, 0.0, -4.0)),
            "mixamorig:Spine": (None, (28.0, 2.0, 3.0)),
            "mixamorig:Spine1": (None, (14.0, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (10.0, 0.0, 0.0)),
            "mixamorig:Neck": (None, (-10.0, 0.0, -2.0)),
            "mixamorig:Head": (None, (-8.0, 2.0, 2.0)),
            "mixamorig:LeftArm": (None, (-75.0, 10.0, -7.0)),
            "mixamorig:LeftForeArm": (None, (10.0, 0.0, 0.0)),
            "mixamorig:LeftHand": (None, (0.0, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (40.0, -8.0, 6.0)),
            "mixamorig:RightForeArm": (None, (15.0, 0.0, 0.0)),
            "mixamorig:LeftUpLeg": (None, (-70.0, 5.0, -3.0)),
            "mixamorig:LeftLeg": (None, (-20.0, 0.0, 0.0)),
            "mixamorig:LeftFoot": (None, (15.0, 0.0, 0.0)),
            "mixamorig:RightUpLeg": (None, (25.0, -3.0, 3.0)),
            "mixamorig:RightLeg": (None, (-5.0, 0.0, 0.0)),
            "mixamorig:RightFoot": (None, (30.0, 0.0, 0.0)),
        }),
        (13, {
            "mixamorig:Hips": ((0.020, 0.100, 0.050), (0.0, 0.0, -4.0)),
            "mixamorig:Spine": (None, (22.0, 2.0, 2.0)),
            "mixamorig:Spine1": (None, (12.0, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (8.0, 0.0, 0.0)),
            "mixamorig:Neck": (None, (-8.0, 0.0, -2.0)),
            "mixamorig:Head": (None, (-6.0, 2.0, 2.0)),
            "mixamorig:LeftArm": (None, (-65.0, 12.0, -10.0)),
            "mixamorig:LeftForeArm": (None, (12.0, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (45.0, -8.0, 8.0)),
            "mixamorig:RightForeArm": (None, (18.0, 0.0, 0.0)),
            "mixamorig:LeftUpLeg": (None, (-60.0, 5.0, -5.0)),
            "mixamorig:LeftLeg": (None, (-25.0, 0.0, 0.0)),
            "mixamorig:LeftFoot": (None, (12.0, 0.0, 0.0)),
            "mixamorig:RightUpLeg": (None, (30.0, -4.0, 4.0)),
            "mixamorig:RightLeg": (None, (-8.0, 0.0, 0.0)),
            "mixamorig:RightFoot": (None, (25.0, 0.0, 0.0)),
        }),
        (17, {
            "mixamorig:Hips": ((0.015, -0.100, 0.030), (0.0, 0.0, -3.5)),
            "mixamorig:Spine": (None, (18.0, 2.0, 2.0)),
            "mixamorig:Spine1": (None, (10.0, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (7.0, 0.0, 0.0)),
            "mixamorig:Neck": (None, (-6.0, 0.0, -2.0)),
            "mixamorig:Head": (None, (-5.0, 2.0, 2.0)),
            "mixamorig:LeftArm": (None, (-30.0, 10.0, -7.0)),
            "mixamorig:LeftForeArm": (None, (20.0, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (20.0, -8.0, 6.0)),
            "mixamorig:RightForeArm": (None, (22.0, 0.0, 0.0)),
            "mixamorig:LeftUpLeg": (None, (-45.0, 5.0, -3.0)),
            "mixamorig:LeftLeg": (None, (-40.0, 0.0, 0.0)),
            "mixamorig:LeftFoot": (None, (5.0, 0.0, 0.0)),
            "mixamorig:RightUpLeg": (None, (20.0, -3.0, 3.0)),
            "mixamorig:RightLeg": (None, (-30.0, 0.0, 0.0)),
            "mixamorig:RightFoot": (None, (10.0, 0.0, 0.0)),
        }),
        (20, {
            "mixamorig:Hips": ((0.012, -0.080, 0.010), (0.0, 0.0, -3.5)),
            "mixamorig:Spine": (None, (12.0, 1.5, 2.0)),
            "mixamorig:Spine1": (None, (7.0, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (5.0, 0.0, 0.0)),
            "mixamorig:Neck": (None, (-4.0, 0.0, -2.0)),
            "mixamorig:Head": (None, (-4.0, 2.0, 2.0)),
            "mixamorig:LeftArm": (None, (-15.0, 10.0, -7.0)),
            "mixamorig:LeftForeArm": (None, (22.0, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (-10.0, -8.0, 6.0)),
            "mixamorig:RightForeArm": (None, (24.0, 0.0, 0.0)),
            "mixamorig:LeftUpLeg": (None, (15.0, 5.0, -3.0)),
            "mixamorig:LeftLeg": (None, (-20.0, 0.0, 0.0)),
            "mixamorig:LeftFoot": (None, (5.0, 0.0, 0.0)),
            "mixamorig:RightUpLeg": (None, (-10.0, -3.0, 3.0)),
            "mixamorig:RightLeg": (None, (-20.0, 0.0, 0.0)),
            "mixamorig:RightFoot": (None, (8.0, 0.0, 0.0)),
        }),
        (24, dict(IDLE_F0)),
    ]

    act_h = bpy.data.actions.new("Harurot")
    arm.animation_data.action = act_h
    bpy.ops.pose.select_all(action='SELECT')
    bpy.ops.pose.transforms_clear()
    for f, pd in harurot_keys:
        apply_pose(pd, f)
    smooth_action(act_h)
    print(f"Created Harurot range {act_h.frame_range[0]}..{act_h.frame_range[1]}")

    # ---- 3. LUSOT_SLIDE (0..23) ----
    slide_low = {
        "mixamorig:Hips": ((0.010, -0.320, 0.020), (0.0, 0.0, -3.5)),
        "mixamorig:Spine": (None, (28.0, 2.0, 3.0)),
        "mixamorig:Spine1": (None, (14.0, 1.0, 1.0)),
        "mixamorig:Spine2": (None, (10.0, 0.0, 0.0)),
        "mixamorig:Neck": (None, (-12.0, 0.0, -2.0)),
        "mixamorig:Head": (None, (-10.0, 2.0, 2.0)),
        "mixamorig:LeftArm": (None, (35.0, -12.0, 12.0)),
        "mixamorig:LeftForeArm": (None, (18.0, 0.0, 0.0)),
        "mixamorig:RightArm": (None, (-50.0, -8.0, 5.0)),
        "mixamorig:RightForeArm": (None, (10.0, 0.0, 0.0)),
        "mixamorig:RightHand": (None, (0.0, 0.0, 0.0)),
        "mixamorig:LeftUpLeg": (None, (-55.0, 8.0, -12.0)),
        "mixamorig:LeftLeg": (None, (-12.0, 0.0, 0.0)),
        "mixamorig:LeftFoot": (None, (25.0, 0.0, 0.0)),
        "mixamorig:RightUpLeg": (None, (65.0, -4.0, 4.0)),
        "mixamorig:RightLeg": (None, (-95.0, 0.0, 0.0)),
        "mixamorig:RightFoot": (None, (20.0, 0.0, 0.0)),
    }
    import copy
    def shifted(hips_z, hips_y=None):
        d = copy.deepcopy(slide_low)
        hx, hy, hz = d["mixamorig:Hips"][0]
        d["mixamorig:Hips"] = ((hx, hips_y if hips_y is not None else hy, hips_z), d["mixamorig:Hips"][1])
        return d

    slide_keys = [
        (0, dict(IDLE_F0)),
        (3, {
            "mixamorig:Hips": ((0.010, -0.150, 0.000), (0.0, 0.0, -3.5)),
            "mixamorig:Spine": (None, (20.0, 2.0, 2.0)),
            "mixamorig:Spine1": (None, (10.0, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (7.0, 0.0, 0.0)),
            "mixamorig:LeftArm": (None, (10.0, 10.0, -7.0)),
            "mixamorig:LeftForeArm": (None, (25.0, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (-20.0, -8.0, 6.0)),
            "mixamorig:RightForeArm": (None, (20.0, 0.0, 0.0)),
            "mixamorig:LeftUpLeg": (None, (30.0, 5.0, -3.0)),
            "mixamorig:LeftLeg": (None, (-35.0, 0.0, 0.0)),
            "mixamorig:RightUpLeg": (None, (25.0, -3.0, 3.0)),
            "mixamorig:RightLeg": (None, (-40.0, 0.0, 0.0)),
        }),
        (4, shifted(0.02)),
        (11, shifted(0.08)),
        (17, shifted(0.12)),
        (18, {
            "mixamorig:Hips": ((0.012, -0.250, 0.130), (0.0, 0.0, -3.5)),
            "mixamorig:Spine": (None, (22.0, 2.0, 2.0)),
            "mixamorig:Spine1": (None, (11.0, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (8.0, 0.0, 0.0)),
            "mixamorig:LeftArm": (None, (20.0, 10.0, -7.0)),
            "mixamorig:LeftForeArm": (None, (22.0, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (-35.0, -8.0, 5.0)),
            "mixamorig:RightForeArm": (None, (15.0, 0.0, 0.0)),
            "mixamorig:LeftUpLeg": (None, (-20.0, 6.0, -6.0)),
            "mixamorig:LeftLeg": (None, (-25.0, 0.0, 0.0)),
            "mixamorig:RightUpLeg": (None, (40.0, -3.0, 3.0)),
            "mixamorig:RightLeg": (None, (-60.0, 0.0, 0.0)),
        }),
        (23, dict(IDLE_F0)),
    ]
    act_s = bpy.data.actions.new("Lusot_Slide")
    arm.animation_data.action = act_s
    bpy.ops.pose.select_all(action='SELECT')
    bpy.ops.pose.transforms_clear()
    for f, pd in slide_keys:
        apply_pose(pd, f)
    smooth_action(act_s)
    print(f"Created Lusot_Slide range {act_s.frame_range[0]}..{act_s.frame_range[1]}")

    # ---- 4. LUSOT_VAULT (0..14) ----
    vault_keys = [
        (0, dict(IDLE_F0)),
        (3, {
            "mixamorig:Hips": ((0.015, 0.020, 0.030), (0.0, 0.0, -4.0)),
            "mixamorig:Spine": (None, (18.0, 2.0, 2.0)),
            "mixamorig:Spine1": (None, (10.0, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (7.0, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (-70.0, 10.0, -5.0)),
            "mixamorig:RightForeArm": (None, (8.0, 0.0, 0.0)),
            "mixamorig:LeftArm": (None, (20.0, -8.0, 5.0)),
            "mixamorig:LeftForeArm": (None, (20.0, 0.0, 0.0)),
            "mixamorig:LeftUpLeg": (None, (-50.0, 5.0, -3.0)),
            "mixamorig:LeftLeg": (None, (-25.0, 0.0, 0.0)),
            "mixamorig:RightUpLeg": (None, (10.0, -3.0, 3.0)),
            "mixamorig:RightLeg": (None, (-20.0, 0.0, 0.0)),
            "mixamorig:RightFoot": (None, (20.0, 0.0, 0.0)),
        }),
        (6, {
            "mixamorig:Hips": ((0.020, 0.120, 0.050), (0.0, 0.0, -4.0)),
            "mixamorig:Spine": (None, (20.0, 2.0, 2.0)),
            "mixamorig:Spine1": (None, (11.0, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (8.0, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (-60.0, 10.0, -5.0)),
            "mixamorig:RightForeArm": (None, (10.0, 0.0, 0.0)),
            "mixamorig:LeftArm": (None, (-20.0, 10.0, -7.0)),
            "mixamorig:LeftForeArm": (None, (15.0, 0.0, 0.0)),
            "mixamorig:LeftUpLeg": (None, (-70.0, 6.0, -6.0)),
            "mixamorig:LeftLeg": (None, (-90.0, 0.0, 0.0)),
            "mixamorig:RightUpLeg": (None, (-60.0, -5.0, 5.0)),
            "mixamorig:RightLeg": (None, (-85.0, 0.0, 0.0)),
        }),
        (9, {
            "mixamorig:Hips": ((0.020, 0.080, 0.080), (0.0, 0.0, -4.0)),
            "mixamorig:Spine": (None, (20.0, 2.0, 8.0)),
            "mixamorig:Spine1": (None, (11.0, 1.0, 2.0)),
            "mixamorig:Spine2": (None, (8.0, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (-40.0, 12.0, -8.0)),
            "mixamorig:LeftArm": (None, (25.0, -10.0, 8.0)),
            "mixamorig:LeftUpLeg": (None, (-50.0, 8.0, -14.0)),
            "mixamorig:LeftLeg": (None, (-60.0, 0.0, 0.0)),
            "mixamorig:RightUpLeg": (None, (-30.0, -6.0, 12.0)),
            "mixamorig:RightLeg": (None, (-55.0, 0.0, 0.0)),
        }),
        (11, {
            "mixamorig:Hips": ((0.015, -0.020, 0.100), (0.0, 0.0, -3.5)),
            "mixamorig:Spine": (None, (15.0, 2.0, 2.0)),
            "mixamorig:Spine1": (None, (8.0, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (6.0, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (-40.0, 10.0, -7.0)),
            "mixamorig:LeftArm": (None, (30.0, -8.0, 6.0)),
            "mixamorig:LeftUpLeg": (None, (-45.0, 5.0, -3.0)),
            "mixamorig:LeftLeg": (None, (-20.0, 0.0, 0.0)),
            "mixamorig:RightUpLeg": (None, (30.0, -3.0, 3.0)),
            "mixamorig:RightLeg": (None, (-15.0, 0.0, 0.0)),
        }),
        (14, {
            "mixamorig:Hips": ((0.015, -0.010, 0.120), (0.0, 0.0, -4.0)),
            "mixamorig:Spine": (None, (16.0, 2.0, 2.0)),
            "mixamorig:Spine1": (None, (9.0, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (6.0, 0.0, 0.0)),
            "mixamorig:Neck": (None, (-6.0, 0.0, -2.0)),
            "mixamorig:Head": (None, (-5.0, 2.0, 2.0)),
            "mixamorig:RightArm": (None, (-45.0, 10.0, -7.0)),
            "mixamorig:RightForeArm": (None, (12.0, 0.0, 0.0)),
            "mixamorig:LeftArm": (None, (32.0, -8.0, 6.0)),
            "mixamorig:LeftForeArm": (None, (16.0, 0.0, 0.0)),
            "mixamorig:LeftUpLeg": (None, (-50.0, 5.0, -3.0)),
            "mixamorig:LeftLeg": (None, (-18.0, 0.0, 0.0)),
            "mixamorig:LeftFoot": (None, (10.0, 0.0, 0.0)),
            "mixamorig:RightUpLeg": (None, (28.0, -3.0, 3.0)),
            "mixamorig:RightLeg": (None, (-12.0, 0.0, 0.0)),
            "mixamorig:RightFoot": (None, (18.0, 0.0, 0.0)),
        }),
    ]
    act_v = bpy.data.actions.new("Lusot_Vault")
    arm.animation_data.action = act_v
    bpy.ops.pose.select_all(action='SELECT')
    bpy.ops.pose.transforms_clear()
    for f, pd in vault_keys:
        apply_pose(pd, f)
    smooth_action(act_v)
    print(f"Created Lusot_Vault range {act_v.frame_range[0]}..{act_v.frame_range[1]}")

    # ---- 5. NLA hygiene ----
    if arm.animation_data is None:
        arm.animation_data_create()
    while len(arm.animation_data.nla_tracks) > 0:
        arm.animation_data.nla_tracks.remove(arm.animation_data.nla_tracks[0])
    for name in ["Idle", "Walking", "Running", "RunFast", "Harurot", "Lusot_Slide", "Lusot_Vault"]:
        act = bpy.data.actions.get(name)
        if act is None:
            print(f"WARNING missing action {name}")
            continue
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(act.name, int(act.frame_range[0]), act)
        strip.name = name
        print(f"NLA {track.name} {act.frame_range[0]}..{act.frame_range[1]}")
    arm.animation_data.action = None
    bpy.ops.object.mode_set(mode='OBJECT')

    print(f"Final actions: {[a.name for a in bpy.data.actions]}")
    assert bpy.data.actions.get("Slide") is None, "Slide must be absent"
    assert bpy.data.actions.get("Dash") is None, "Dash must be absent"
    for req in ["Idle", "Walking", "Running", "Harurot", "Lusot_Slide", "Lusot_Vault"]:
        assert bpy.data.actions.get(req) is not None, f"{req} missing"

    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB,
        export_format='GLB',
        export_animations=True,
        export_animation_mode='NLA_TRACKS',
        export_skins=True,
        export_materials='EXPORT',
        export_apply=False,
    )
    print(f"Exported to {OUT_GLB}")
    print("=== HAMOG MOVESET PIPELINE FINISHED ===")

if __name__ == '__main__':
    build()
