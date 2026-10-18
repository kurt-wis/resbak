import bpy
from mathutils import Vector, Euler, Quaternion
import math
import os

# Repo root, resolved from this file (blender -b --python sets __file__).
PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def build():
    print("=== STARTING BATANG HAMOG ANIMATION PIPELINE ===")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    
    # 1. Import original master model
    src_glb = os.path.join(PROJ, "source_art", "batang_hamog", "BatangHamog.glb")
    bpy.ops.import_scene.gltf(filepath=src_glb)
    
    arm = None
    mesh = None
    for obj in bpy.data.objects:
        if obj.type == 'ARMATURE':
            arm = obj
        elif obj.type == 'MESH':
            mesh = obj
            
    if not arm or not mesh:
        raise RuntimeError("Armature or Mesh not found in imported file!")
        
    print(f"Loaded armature: {arm.name}, mesh: {mesh.name}")
    
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='POSE')
    
    # Helper for keyframing
    def set_bone(bname, frame, loc=None, rot_deg=None):
        b = arm.pose.bones.get(bname)
        if not b:
            return
        if loc is not None:
            b.location = Vector(loc)
            b.keyframe_insert(data_path="location", frame=frame)
        if rot_deg is not None:
            eu = Euler((math.radians(rot_deg[0]), math.radians(rot_deg[1]), math.radians(rot_deg[2])), 'XYZ')
            b.rotation_quaternion = eu.to_quaternion()
            b.keyframe_insert(data_path="rotation_quaternion", frame=frame)

    # Helper to force smooth BEZIER interpolation on a layered Action (Blender 5.2)
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
                            except:
                                pass
            # refresh handles for cohesive ease in/out
            try:
                for lay in act.layers:
                    for st in lay.strips:
                        for cb in st.channelbags:
                            for fc in cb.fcurves:
                                for kp in fc.keyframe_points:
                                    kp.handle_left_type = 'AUTO_CLAMPED'
                                    kp.handle_right_type = 'AUTO_CLAMPED'
            except:
                pass
        except Exception as e:
            print(f"smooth_action note for {act.name}: {e}")

    # ----------------------------------------------------
    # 2. CREATE IDLE ANIMATION (72 frames = 2.4s loop at 30fps)
    # Natural street kid swagger idle: alert, breathing, subtle weight shift
    # ----------------------------------------------------
    act_idle = bpy.data.actions.new("Idle")
    arm.animation_data.action = act_idle
    bpy.ops.pose.select_all(action='SELECT')
    bpy.ops.pose.transforms_clear()
    
    idle_keyframes = [
        # Frame 0: Base street stance
        (0, {
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
        }),
        # Frame 20: Inhaling, chest expansion, subtle alert head turn
        (20, {
            "mixamorig:Hips": ((0.012, -0.017, 0.003), (0.0, 0.0, -3.0)),
            "mixamorig:Spine": (None, (6.8, 1.8, 2.0)),
            "mixamorig:Spine1": (None, (4.8, 1.2, 1.0)),
            "mixamorig:Spine2": (None, (3.8, 0.0, 0.0)),
            "mixamorig:Neck": (None, (-3.0, 2.5, 3.0)),
            "mixamorig:Head": (None, (-2.5, 5.0, 5.0)),
            "mixamorig:LeftShoulder": (None, (1.2, 0.0, 0.0)),
            "mixamorig:RightShoulder": (None, (1.0, 0.0, 0.0)),
            "mixamorig:LeftArm": (None, (-3.2, 9.5, -6.5)),
            "mixamorig:LeftForeArm": (None, (17.5, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (-4.8, -7.0, 5.0)),
            "mixamorig:RightForeArm": (None, (19.5, 0.0, 0.0)),
        }),
        # Frame 36: Apex of breath, subtle weight shift
        (36, {
            "mixamorig:Hips": ((0.014, -0.016, 0.005), (0.0, 0.0, -2.5)),
            "mixamorig:Spine": (None, (7.5, 1.5, 2.0)),
            "mixamorig:Spine1": (None, (5.2, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (4.2, 0.0, 0.0)),
            "mixamorig:Neck": (None, (-3.0, 1.0, 1.0)),
            "mixamorig:Head": (None, (-3.0, 3.0, 2.0)),
            "mixamorig:LeftShoulder": (None, (1.5, 0.0, 0.0)),
            "mixamorig:RightShoulder": (None, (1.2, 0.0, 0.0)),
            "mixamorig:LeftArm": (None, (-3.0, 10.0, -6.0)),
            "mixamorig:LeftForeArm": (None, (18.0, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (-4.5, -6.5, 4.5)),
            "mixamorig:RightForeArm": (None, (20.0, 0.0, 0.0)),
        }),
        # Frame 54: Exhaling, head tracking back to center
        (54, {
            "mixamorig:Hips": ((0.011, -0.019, 0.002), (0.0, 0.0, -3.2)),
            "mixamorig:Spine": (None, (6.0, 1.5, 2.2)),
            "mixamorig:Spine1": (None, (4.0, 1.0, 1.0)),
            "mixamorig:Spine2": (None, (3.0, 0.0, 0.0)),
            "mixamorig:Neck": (None, (-3.2, 0.5, -1.0)),
            "mixamorig:Head": (None, (-3.2, 2.2, 2.8)),
            "mixamorig:LeftShoulder": (None, (0.5, 0.0, 0.0)),
            "mixamorig:RightShoulder": (None, (0.4, 0.0, 0.0)),
            "mixamorig:LeftArm": (None, (-3.8, 9.2, -6.8)),
            "mixamorig:LeftForeArm": (None, (16.8, 0.0, 0.0)),
            "mixamorig:RightArm": (None, (-5.2, -7.2, 5.2)),
            "mixamorig:RightForeArm": (None, (18.8, 0.0, 0.0)),
        }),
        # Frame 72: Identical to Frame 0 for seamless loop
        (72, {
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
        }),
    ]
    
    for f, bones_data in idle_keyframes:
        for bname, (loc, rot_deg) in bones_data.items():
            set_bone(bname, f, loc=loc, rot_deg=rot_deg)
            
    print("Created Action: Idle (72 frames)")

    # ----------------------------------------------------
    # 3. REMOVE DASH / ROLL / SLIDE ANIMATIONS (goal: no dashing, rolling, sliding)
    # Only locomotion (Idle/Walking/Running/RunFast) is kept. Harurot, Slide,
    # Dash and Roll clips are purged so they can never export.
    # ----------------------------------------------------
    for stale_name in ("Slide", "Dash", "Harurot", "Roll"):
        stale = bpy.data.actions.get(stale_name)
        if stale is not None:
            bpy.data.actions.remove(stale)
            print(f"Removed stale {stale_name} action")
    act_idle_check = bpy.data.actions.get("Idle")
    if act_idle_check is not None:
        arm.animation_data.action = act_idle_check
    smooth_action(act_idle)
    print("Kept Idle; dash/roll/slide removed")

    # ----------------------------------------------------
    # 4. RECONSTRUCT NLA TRACKS FOR ALL ACTIONS
    # Ensure only locomotion (Idle, Walking, Running, RunFast) is exported.
    # Slide, Dash, Harurot and Roll clips are intentionally gone (no dash/roll/slide).
    # ----------------------------------------------------
    # Clear current tracks
    if arm.animation_data:
        while len(arm.animation_data.nla_tracks) > 0:
            arm.animation_data.nla_tracks.remove(arm.animation_data.nla_tracks[0])
    else:
        arm.animation_data_create()
        
    primary_actions = [
        "Idle",
        "Walking",
        "Running",
        "RunFast",
    ]
    
    for act_name in primary_actions:
        act = bpy.data.actions.get(act_name)
        if not act:
            print(f"WARNING: Action {act_name} not found!")
            continue
        track = arm.animation_data.nla_tracks.new()
        track.name = act_name
        strip = track.strips.new(act.name, int(act.frame_range[0]), act)
        strip.name = act_name
        print(f"Pushed NLA Track: {track.name} (range {act.frame_range[0]}..{act.frame_range[1]})")

    # Clear active action so NLA tracks take precedence
    arm.animation_data.action = None
    
    # Return to object mode
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # ----------------------------------------------------
    # 5. EXPORT TO assets/characters/batang_hamog.glb
    # ----------------------------------------------------
    out_path = os.path.join(PROJ, "assets", "characters", "batang_hamog.glb")
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format='GLB',
        export_animations=True,
        export_animation_mode='NLA_TRACKS',
        export_skins=True,
        export_materials='EXPORT',
        export_apply=False
    )
    print(f"Exported successfully to: {out_path}")
    print("=== PIPELINE FINISHED SUCCESSFULLY ===")

if __name__ == '__main__':
    build()
