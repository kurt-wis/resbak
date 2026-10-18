"""
build_heroes.py - Every clip of the five Meshy-rigged heroes, from one clip table per hero.

Input : source_art/heroes/<Name>_Character.glb (Meshy auto-rig, Mixamo bone names, A-pose, faces -Y)
        source_art/mocap/meshy/*.glb (Meshy auto-rig of each hero + Meshy preset animations and
          two text-to-motion clips; 24-bone Meshy rig, see tools/retarget_clip.py)
        source_art/mocap/quaternius/UAL1_Standard.glb (Quaternius Universal Animation Library, CC0)
        mixamo/breakdance-pack/*.fbx (Mixamo breakdance pack on X Bot)
Output: assets/characters/<id>.glb with one NLA clip per entry below (names are the game's
          contract: scripts/runtime looks them up by name),
        renders/heroes_<id>_{idle,walking,running}.png stills, renders/heroes_breakdance.png,
        renders/heroes_<id>_moves.png (six frames of every clip, for review).

- HERO_CLIPS: each hero's own Idle / Walking / Running and skill clips. SHARED: the core-rule
  clips every hero gets (Tag, Tagged, Stumble, Stunned, Jailed, Capture, Victory). Chained is
  authored here from the hero's Idle (arms out to the sides, holding hands in the chain).
- An entry: clip(source file, source clip, trim=(start_s, end_s), warp=[(out_s, src_s), ...],
  loop=..., in_place=..., blend=frames, face=..., turn=deg, plant=...). Loops always lose their
  travel and spin (in_place) so the seam is exact; open whole-clip loops are closed by
  retarget_clip; `blend` eases a cut segment back into its first frame; face / turn rotate a
  clip that stands turned. Every clip is grounded: lowest point on the floor over the whole
  clip (jumps keep their air time), or with plant=True every frame's lowest sole on the floor.
- BreakDance is each hero's own routine of Mixamo moves (BREAKDANCE below), unchanged since
  2026-10-16: drift removed, cross-faded, kept on the select pad, eased into frame 0.
- Never name a clip exactly 'Slide' or 'Dash' (the gate asserts they are absent).
- After changing clips, re-measure foot speeds with tools/qc_asset.py and update
  walk_clip_speed / run_clip_speed in data/heroes/<id>.tres (HeroData), where the game reads them.

Run:  & $env:BLENDER -b --python tools/build_heroes.py            (all heroes)
      & $env:BLENDER -b --python tools/build_heroes.py -- nene    (one hero)
"""
import bpy, os, math, sys
import numpy as np
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import retarget_clip  # noqa: E402  (tools/retarget_clip.py)

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
SRC_DIR = os.path.join(PROJ, "source_art", "heroes")
OUT_DIR = os.path.join(PROJ, "assets", "characters")
RENDER_DIR = os.path.join(PROJ, "renders")
MOCAP_DIR = os.path.join(PROJ, "source_art", "mocap")
MIXAMO_DIR = os.path.join(PROJ, "mixamo", "breakdance-pack")

HEROES = {  # id -> source file
    "tutoy": "Tutoy_Character.glb",
    "nene": "Nene_Character.glb",
    "nathan": "Nathan_Character.glb",
    "jm": "JM_Character.glb",
    "inday": "Inday_Character.glb",
}


def clip(src, name=None, trim=None, warp=None, loop=False, in_place=False, blend=0, face=False,
         turn=0.0, plant=False, on_floor=False):
    """One clip: `src` is relative to source_art/mocap/; `name` None = the file's only clip.
    trim / warp times are seconds in the source clip (Meshy files: frame / 24).
    face : turn the clip so the chest faces -Y on average (clips that stand turned).
    turn : then turn it this many more degrees about Z (+ = toward the hero's left, +X).
    plant: ground every frame on its lowest sole (bake_planted) instead of the whole clip on
           its lowest point; for standing clips whose retargeted feet hover, or whose hands
           reach under the floor (Talbog_Slam).
    on_floor: keep the clip's own height and lift only the frames whose mesh dips under the
           floor (bake_on_floor); for a flip whose hands or head reach below it."""
    return {"src": src, "name": name, "trim": trim, "warp": warp, "loop": loop,
            "in_place": in_place, "blend": blend, "face": face, "turn": turn, "plant": plant,
            "on_floor": on_floor}


T, NE, NA, J, I = (f"meshy/{h}_moves.glb" for h in ("tutoy", "nene", "nathan", "jm", "inday"))
TM, NEM, NAM, JM, IM = (f"meshy/{h}_menu.glb" for h in ("tutoy", "nene", "nathan", "jm", "inday"))  # Home diorama

# Each hero's own locomotion and skills. Times were picked from source contact sheets.
HERO_CLIPS = {
    "tutoy": {
        "Idle": clip(T, "Idle_5", loop=True, face=True),                   # stands ~42 deg turned
        "Walking": clip(T, "Quick_Walk", trim=(0.0, 1.0), loop=True),     # 3 identical 1 s cycles
        "Running": clip(T, "Lean_Forward_Sprint", loop=True),
        "Harurot": clip(T, "run_fast_2", loop=True),                       # S1 HARUROT! sprint
        "Lusot_Slide": clip(T, "slide_light", trim=(5 / 24, 25 / 24), in_place=True),  # drop to get-up
        "Lusot_Vault": clip(T, "Unarmed_Vault", in_place=True),
    },
    "nene": {
        "Idle": clip(NE, "Happy_Sway_Standing", loop=True),
        "Walking": clip(NE, "Skip_Forward", loop=True),
        "Running": clip(NE, "run_fast_7", loop=True),
        # S1 IYAK! crying decoy: the sitting tantrum (kicking, crying), looped.
        "Iyak": clip(NE, "Angry_To_Tantrum_Sit", trim=(66 / 24, 114 / 24), loop=True, blend=12),
        # S2 SUMBONG KITA!: arm sweeps up, then calls out with a hand at the mouth.
        "Sumbong": clip(NE, "Call_Gesture", trim=(45 / 24, 72 / 24)),
    },
    "nathan": {
        "Idle": clip(NA, "Scheming_Hand_Rub", loop=True),
        "Walking": clip(NA, "Sneaky_Walk", loop=True),
        "Running": clip(NA, "run_fast_9", loop=True),
        # S1 BUGA!: lean back to inhale, then blow forward; the source holds the inhale ~0.8 s,
        # squeezed so the blow peaks 0.4 s in (the spec's inhale time), settle at full speed.
        "Buga": clip("meshy/nathan_buga.glb",
                     warp=[(0.0, 1 / 24), (0.22, 9 / 24), (0.27, 27 / 24), (0.40, 39 / 24), (1.20, 60 / 24)],
                     plant=True),
        # S2 UBO! UBO! packet throw: hand up by the shoulder, then the throw forward and down.
        # The source is a grappling over-shoulder throw; the body stands ~70 deg turned to the
        # left while the throwing hand releases straight ahead, so it is left unturned.
        "Ubo": clip(NA, "Over_Shoulder_Throw", trim=(54 / 24, 74 / 24), plant=True),
    },
    "jm": {
        "Idle": clip(J, "Idle_11", loop=True),
        "Walking": clip(J, "Proud_Strut", loop=True, plant=True),           # hovered ~7 cm
        "Running": clip(J, "run_fast_4", loop=True),
        # Crouch to just before landing; the source jumps with feet ~50 deg to the right.
        "Talbog_Jump": clip(J, "Regular_Jump", trim=(4 / 24, 26 / 24), turn=40),
        # Impact + recovery. Planted: his hand reaches 11 cm under his soles in the crouch, so
        # whole-clip grounding floated him 11-20 cm; now the fist dips into the floor instead.
        "Talbog_Slam": clip(J, "Charged_Ground_Slam", trim=(33 / 24, 66 / 24), plant=True),
        "Tamaraw": clip(J, "Male_Head_Down_Charge", loop=True, in_place=True),
        "GuardBreak": clip(J, "Hit_Reaction_to_Waist", trim=(3 / 24, 27 / 24), face=True),  # ~55 deg off
    },
    "inday": {
        "Idle": clip(I, "Hand_on_Hip_Gesture", loop=True),
        "Walking": clip(I, "Confident_Strut", loop=True),
        "Running": clip(I, "run_fast_6", loop=True),
        # S1 IHIP!: the held two-arms-forward push, channelled up to 4 s.
        "Ihip": clip(I, "mage_soell_cast_3", trim=(32.8 / 24, 60.8 / 24), loop=True, blend=6),
        "Sagip": clip(I, "Cheer_with_Both_Hands_Up", trim=(3 / 24, 36 / 24)),   # S2 SAGIP!
    },
}

# Home diorama clips (2026-10-17): the base loops and gestures the AnimationTree layers on a seated
# or standing hero. Every Menu clip is turned to face -Y on average (`face`) so a gesture laid over
# a base never twists the torso, and stays in place. Sitters (Nene, JM, Nathan) are grounded as a
# whole; standers are planted per frame. Times are source frames / 24, picked from probe sheets.
HERO_CLIPS["tutoy"].update({
    # His own Idle_5 is a wide fighter's crouch; the Quaternius talking idle stands relaxed.
    "Menu_StandIdle": clip("quaternius/UAL1_Standard.glb", "Idle_Talking_Loop", loop=True, face=True, plant=True),
    "Menu_TalkPassionate": clip(TM, "Talk_Passionately", face=True, in_place=True, plant=True),
    "Menu_HandOnHip": clip(TM, "Hand_on_Hip_Gesture", face=True, in_place=True, plant=True),
    "Menu_Cheer": clip(TM, "Cheer_with_Both_Hands_Up", trim=(12 / 24, 44 / 24), face=True, in_place=True,
                       plant=True),                                  # the first ~11 frames crouch
    "Menu_HandstandFlip": clip(TM, "Handstand_Flip", in_place=True, on_floor=True),  # travels ~1 m in the source
})
HERO_CLIPS["nene"].update({
    # The source bows her head from ~frame 160; the first 150 frames are the stable stretch.
    "Menu_SitIdle": clip(NEM, "Chair_Sit_Idle_F", trim=(0.0, 150 / 24), loop=True, blend=12, face=True,
                         in_place=True),  # grounded, not planted: her dangling feet swing 8 cm
    "Menu_SitDrink": clip(NEM, "Sit_and_Drink", face=True, in_place=True),
    "Menu_FingerWag": clip(NEM, "Sit_Finger_Wag_No", face=True, in_place=True),
    "Menu_Clap": clip(NEM, "Sitting_Clap", face=True, in_place=True),
})
HERO_CLIPS["jm"].update({
    # The source hunches forward for most of its 10 s and rises upright for ~1.5 s near the end
    # (frames 211-247); that near-still stretch, looped, is the idle.
    "Menu_SitIdle": clip(JM, "Chair_Sit_Idle_M", trim=(211 / 24, 247 / 24), loop=True, blend=8, face=True,
                         in_place=True, plant=True),
    "Menu_SitDrink": clip(JM, "Sit_and_Drink", face=True, in_place=True),
    "Menu_LeanBackLaugh": clip(JM, "Sit_Hands_on_Head_Lean_Back", face=True, in_place=True),
    "Menu_Clap": clip(JM, "Sitting_Clap", face=True, in_place=True),
})
HERO_CLIPS["nathan"].update({
    "Menu_SitIdle": clip(NAM, "Chair_Sit_Idle_M", trim=(211 / 24, 247 / 24), loop=True, blend=8, face=True,
                         in_place=True, plant=True),
    "Menu_Answer": clip(NAM, "Sitting_Answering_Questions", face=True, in_place=True),
    "Menu_ThumbsUp": clip(NAM, "Sit_Thumbs_Up_Right", face=True, in_place=True),
    "Menu_Clap": clip(NAM, "Sitting_Clap", face=True, in_place=True),
})
HERO_CLIPS["inday"].update({
    # Her own Idle touches her face mid-loop, which would cover the face card; the talking idle does not.
    "Menu_StandIdle": clip("quaternius/UAL1_Standard.glb", "Idle_Talking_Loop", loop=True, face=True, plant=True),
    "Menu_TalkHandsOpen": clip(IM, "Talk_with_Hands_Open", face=True, in_place=True, plant=True),
    "Menu_TalkHip": clip(IM, "Talk_with_Left_Hand_on_Hip", face=True, in_place=True, plant=True),
    "Menu_TalkRightOpen": clip(IM, "Talk_with_Right_Hand_Open", face=True, in_place=True, plant=True),
})

# Core-rule clips, retargeted onto every hero. Chained is authored from each hero's Idle.
SHARED = {
    # Wind-up, lunge, back. The body turns ~65 deg (right shoulder leading) while the tagging
    # hand reaches straight ahead (-Y), so it is left unturned.
    "Tag": clip("meshy/shared_tag.glb", trim=(11 / 24, 27 / 24), in_place=True),
    "Tagged": clip(T, "Slap_Reaction", trim=(18 / 24, 40 / 24)),                 # 0.8 s freeze
    "Stumble": clip(T, "Stumble_Walk", trim=(18 / 24, 36 / 24), in_place=True),   # failed tag, 0.5 s
    "Stunned": clip(T, "Head_Hold_in_Pain", trim=(51.2 / 24, 76.8 / 24), loop=True, blend=6),
    "Jailed": clip(T, "Wave_for_Help", loop=True),
    "Capture": clip("quaternius/UAL1_Standard.glb", "Push_Loop", loop=True, plant=True),
    "Victory": clip(NE, "Victory_Cheer", trim=(0.0, 33 / 24), loop=True, blend=8, plant=True),
}
CHAINED = "Chained"
CHAIN_CALM = tuple(f"mixamorig:{b}" for b in ("Spine", "Spine1", "Spine2", "Neck", "Head"))
LOCOMOTION = ("Idle", "Walking", "Running")
CORE_ORDER = ("Tag", "Tagged", "Stumble", "Stunned", "Jailed", CHAINED, "Capture", "Victory")

# TagCharge (2026-10-17): the held hampas wind-up, played while Hero.is_charging(). Its source is
# one Meshy Prime text-to-motion clip on an SMPL-H rig (retarget_clip maps it; see docs/pipelines/
# blender.md "TagCharge"). The entry only switches on when the file exists, so a checkout without
# it still builds (HeroVisual skips clips a hero does not have).
TAG_CHARGE_SRC = "meshy/shared_tag_charge.glb"
if os.path.exists(os.path.join(MOCAP_DIR, *TAG_CHARGE_SRC.split("/"))):
    SHARED["TagCharge"] = clip(TAG_CHARGE_SRC, loop=True, in_place=True, blend=6)
    CORE_ORDER = CORE_ORDER[:1] + ("TagCharge",) + CORE_ORDER[1:]

# Each hero's own breakdance: Mixamo moves played in order, (file, repeats). Every move here
# starts and ends in the same pose, so the routine loops cleanly.
BREAKDANCE = {
    "tutoy": [("breakdance footwork 2.fbx", 1), ("flair (2).fbx", 2)],   # street kid: footwork into flares
    "nene": [("breakdance uprock var 1.fbx", 2)],                         # bouncy uprock
    "nathan": [("breakdance swipes.fbx", 1)],                             # one self-looping move (the old 1990 + freeze pair left a 2.6 cm seam)
    "jm": [("breakdance freezes.fbx", 1)],                                # big-man power freezes
    "inday": [("brooklyn uprock.fbx", 1)],                                # Brooklyn uprock, dips to the floor
}
CROSSFADE = 8  # frames between moves and at the loop seam
LOOP_EASE = 3  # frames every loop eases into its first frame (unless its entry sets `blend`)
PAD_RADIUS = 0.35  # m of floor travel allowed on the select-screen pad


def log(msg):
    print(f"[build_heroes] {msg}", flush=True)


def clip_order(hero_id):
    skills = [n for n in HERO_CLIPS[hero_id] if n not in LOCOMOTION]
    return list(LOCOMOTION) + ["BreakDance"] + list(CORE_ORDER) + skills


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24


def import_hero(file_name):
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC_DIR, file_name))
    # Meshy leaves a stray 2 m Icosphere at the origin; it would wreck bounds-based scaling.
    for o in list(bpy.data.objects):
        if o.type == "MESH" and len(o.vertex_groups) == 0:
            log(f"  removing stray mesh {o.name}")
            bpy.data.objects.remove(o, do_unlink=True)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rigid_head(arm)
    return arm


def rigid_head(arm):
    """Meshy's auto-weights leave a few % of Shoulder/Neck weight on vertices above the head joint
    (JM: ~10 % on the face), so the face smears whenever the shoulders move and the painted face
    cards (build_face_cards.py) drift off it. Everything above the head joint follows the head
    bone (and its children) alone."""
    head = arm.data.bones["mixamorig:Head"]
    head_z = (arm.matrix_world @ head.head_local).z
    keep = {head.name} | {b.name for b in head.children_recursive}
    moved = 0
    for o in bpy.data.objects:
        if o.type != "MESH" or o.find_armature() is not arm or "mixamorig:Head" not in o.vertex_groups:
            continue
        names = {g.index: g.name for g in o.vertex_groups}
        head_vg = o.vertex_groups["mixamorig:Head"]
        mw = o.matrix_world
        for v in o.data.vertices:
            if (mw @ v.co).z <= head_z:
                continue
            stray = [(g.group, g.weight) for g in v.groups if names[g.group] not in keep]
            if not stray:
                continue
            for gi, _ in stray:
                o.vertex_groups[gi].remove([v.index])
            head_vg.add([v.index], sum(w for _, w in stray), "ADD")
            moved += 1
    log(f"  rigid head: {moved} vertices above the head joint moved onto the Head bone")


def rest_data(arm):
    return {b.name: b.matrix_local.copy() for b in arm.data.bones}


def ordered_bones(arm):
    out = []
    def walk(b):
        out.append(b)
        for c in b.children:
            walk(c)
    for b in arm.data.bones:
        if b.parent is None:
            walk(b)
    return out


def bake(arm, name, offset_frames, hips_scale):
    """Write offset frames onto `arm` as a new action named `name`."""
    rest = rest_data(arm)
    bones = ordered_bones(arm)
    hips_rest = rest["mixamorig:Hips"].to_translation()
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    prev_q = {}
    for fi, (rot, hips_delta) in enumerate(offset_frames):
        pose_m = {}
        for b in bones:
            n = b.name
            # Bones missing from the source (fingers, headfront) follow their parent rigidly.
            d = rot.get(n)
            if d is None:
                p = b.parent
                while p is not None and p.name not in rot:
                    p = p.parent
                d = rot[p.name] if p is not None else Quaternion()
            want_rot = d @ rest[n].to_quaternion()
            if b.parent is None:
                head = hips_rest + hips_delta * hips_scale
                pose_m[n] = Matrix.Translation(head) @ want_rot.to_matrix().to_4x4()
                basis = rest[n].inverted() @ pose_m[n]
            else:
                pm = pose_m[b.parent.name] @ rest[b.parent.name].inverted() @ rest[n]
                basis_q = pm.to_quaternion().inverted() @ want_rot
                basis = basis_q.to_matrix().to_4x4()
                pose_m[n] = pm @ basis
            loc, q, _ = basis.decompose()
            if n in prev_q:
                q.make_compatible(prev_q[n])
            prev_q[n] = q
            pb = arm.pose.bones[n]
            pb.rotation_mode = "QUATERNION"
            pb.location = loc if b.parent is None else Vector()
            pb.rotation_quaternion = q
            pb.keyframe_insert("location", frame=fi)
            pb.keyframe_insert("rotation_quaternion", frame=fi)
    log(f"  baked {name}: {len(offset_frames)} frames")
    return act


def _blend_frame(a, b, t):
    ra, ha = a
    rb, hb = b
    return ({n: q.slerp(rb.get(n, q), t) for n, q in ra.items()}, ha.lerp(hb, t))


def remove_drift(frames):
    """Cancel a move's net travel, height change and spin so its last frame lands on its first."""
    n = len(frames)
    if n < 2:
        return frames
    d = frames[-1][1] - frames[0][1]
    hips0, hips1 = frames[0][0]["mixamorig:Hips"], frames[-1][0]["mixamorig:Hips"]
    dyaw = (retarget_clip._heading(hips1) - retarget_clip._heading(hips0) + math.pi) % (2 * math.pi) - math.pi
    out = []
    for i, (rot, hips) in enumerate(frames):
        t = i / (n - 1)
        turn = Quaternion((0, 0, 1), -dyaw * t)
        out.append(({k: (turn @ q).normalized() for k, q in rot.items()}, turn @ (hips - d * t)))
    return out


def concat(a, b, fade=CROSSFADE):
    """a then b, with the last `fade` frames of a cross-faded into the first `fade` of b."""
    if not a:
        return list(b)
    fade = min(fade, len(a) - 1, len(b) - 1)
    out = list(a[:-fade])
    for i in range(fade):
        t = (i + 1) / (fade + 1)
        out.append(_blend_frame(a[len(a) - fade + i], b[i], t * t * (3 - 2 * t)))
    return out + list(b[fade:])


FOOT_BONES = ("LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase", "LeftToe_End", "RightToe_End")


def _sole_mask(o):
    """Vertices of mesh `o` skinned mostly (> 50 %) to foot and toe bones."""
    feet = {g.index for g in o.vertex_groups if g.name.split(":")[-1] in FOOT_BONES}
    return np.array([sum(g.weight for g in v.groups if g.group in feet) > 0.5 for v in o.data.vertices],
                    dtype=bool)


def _mesh_lows(arm, act, count, soles=False):
    """Lowest skinned-mesh point (armature space Z) on each of the first `count` frames;
    soles=True: lowest point of the feet only."""
    body = [o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm]
    masks = {o.name: _sole_mask(o) for o in body} if soles else {}
    if soles:
        body = [o for o in body if masks[o.name].any()]
    arm.animation_data.action = act
    f0 = int(act.frame_range[0])
    lows = []
    for i in range(count):
        bpy.context.scene.frame_set(f0 + i)
        dg = bpy.context.evaluated_depsgraph_get()
        low = 1e9
        for o in body:
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            co = np.empty(len(me.vertices) * 3, dtype=np.float64)
            me.vertices.foreach_get("co", co)
            mw = np.array(ev.matrix_world)
            z = co.reshape(-1, 3) @ mw[2, :3] + mw[2, 3]
            low = min(low, float((z[masks[o.name]] if soles else z).min()))
            ev.to_mesh_clear()
        lows.append(low)
    return lows


def bake_grounded(arm, name, frames):
    """Bake, then shift the whole clip so its lowest sole touches the floor: retargeted hips
    heights otherwise leave feet a few cm under or over it. Jumps keep their air time (the
    lowest frame is the crouch)."""
    act = bake(arm, name, frames, 1.0)
    dz = -min(_mesh_lows(arm, act, len(frames)))
    if abs(dz) > 0.003:
        bpy.data.actions.remove(act)
        act = bake(arm, name, [(r, h + Vector((0, 0, dz))) for r, h in frames], 1.0)
        log(f"  grounded {name}: {dz * 100:+.1f} cm")
    return act


def bake_planted(arm, name, frames):
    """Bake, then move each frame up or down so its lowest sole sits on the floor. Retargeted
    hips heights drift against the hero's own leg lengths, so standing clips hover a few cm
    (JM's Proud_Strut ~7 cm); in Talbog_Slam JM's hand reaches 11 cm under his feet, so
    whole-clip grounding floated him 11-20 cm. Kills hops: only for clips with a planted foot."""
    act = bake(arm, name, frames, 1.0)
    lows = _mesh_lows(arm, act, len(frames), soles=True)
    bpy.data.actions.remove(act)
    act = bake(arm, name, [(r, h - Vector((0, 0, low))) for (r, h), low in zip(frames, lows)], 1.0)
    log(f"  planted {name}: soles moved {-max(lows) * 100:+.1f} to {-min(lows) * 100:+.1f} cm")
    return act


def bake_on_floor(arm, name, frames):
    """Bake, then lift any frame whose skinned mesh dips under the floor (a kid's big head and
    short arms reach the ground sooner than the adult rig the moves were captured on)."""
    act = bake(arm, name, frames, 1.0)
    raw = [max(0.0, -low) for low in _mesh_lows(arm, act, len(frames))]
    # Widen each lift (running max) then soften it (running mean) so the body eases up and
    # down instead of popping. Indices wrap: the clip loops.
    n, w = len(raw), 3
    wide = [max(raw[(i + k) % n] for k in range(-w, w + 1)) for i in range(n)]
    lifts = [sum(wide[(i + k) % n] for k in range(-w, w + 1)) / (2 * w + 1) for i in range(n)]
    if max(lifts) > 0.003:
        bpy.data.actions.remove(act)
        act = bake(arm, name, [(r, h + Vector((0, 0, d))) for (r, h), d in zip(frames, lifts)], 1.0)
        log(f"  kept {name} above the floor (max lift {max(lifts) * 100:.1f} cm)")
    return act


def retarget_table(arm, table):
    """{our clip name: offset frames}, each source file loaded once."""
    by_file = {}
    for ours, spec in table.items():
        by_file.setdefault(spec["src"], []).append(ours)
    out = {}
    for src_rel, names in by_file.items():
        src, acts = retarget_clip.load_clips(os.path.join(MOCAP_DIR, *src_rel.split("/")))
        for ours in names:
            spec = table[ours]
            if spec["name"]:
                act = acts.get(spec["name"])
                if act is None:
                    raise SystemExit(f"{src_rel}: no clip {spec['name']!r}; has {sorted(acts)}")
            else:
                act = max(acts.values(), key=lambda a: a.frame_range[1] - a.frame_range[0])
            label = f"{ours} <- {os.path.basename(src_rel)}:{spec['name'] or act.name}"
            frames = retarget_clip.offsets_from_rig(src, act, arm, label=label, trim=spec["trim"],
                                                    warp=spec["warp"], loop=spec["loop"])
            if spec["loop"] or spec["in_place"]:
                frames = retarget_clip.in_place(frames, spec["loop"])
            if spec["face"] or spec["turn"]:
                frames = retarget_clip.face_front(frames, turn=spec["turn"], auto=spec["face"])
            # Loops end exactly on their first frame: a source loop that was only nearly closed
            # (under LOOP_SEAM_DEG, e.g. Nathan's run_fast_9: 3 cm) would hitch at every wrap.
            blend = spec["blend"] or (LOOP_EASE if spec["loop"] else 0)
            if blend:
                frames = retarget_clip.loop_blend(frames, blend=blend)
            out[ours] = frames
        retarget_clip.discard(src, list(acts.values()))
    return out


def chained(arm, idle):
    """Chained: the hero's own Idle with both arms held out to the sides, about horizontal,
    as if holding hands in the human chain. The pose is first turned so the chest faces -Y on
    average (else a turned idle would reach one arm forward and the other back), and the spine,
    neck and head keep only a quarter of their motion away from frame 0 (calm: Nathan's
    scheming idle bows deep). Arm directions follow the chest, so breathing and sway still
    read; forearms and hands continue the arm line."""
    rest = rest_data(arm)
    up = Vector((0, 1, 0))
    rest_dir = {n: rest[n].to_quaternion() @ up for n in rest}
    faced = retarget_clip.face_front(idle)
    first = faced[0][0]
    out = []
    for rot, hips in faced:
        r = dict(rot)
        for n in CHAIN_CALM:
            if n in r and n in first:
                r[n] = r[n].slerp(first[n], 0.75).normalized()
        chest = r.get("mixamorig:Spine2", Quaternion())
        for side, sx in (("Left", 1.0), ("Right", -1.0)):
            # Out to the side (+X is the hero's left: they face -Y), a little forward and down.
            arm_dir = (chest @ Vector((sx, -0.12, -0.16))).normalized()
            fore_dir = (chest @ Vector((sx, -0.30, -0.06))).normalized()
            for bone, want in ((f"mixamorig:{side}Arm", arm_dir), (f"mixamorig:{side}ForeArm", fore_dir),
                               (f"mixamorig:{side}Hand", fore_dir)):
                parent = arm.data.bones[bone].parent.name
                d = r.get(bone, r.get(parent, Quaternion()))
                cur = d @ rest_dir[bone]
                r[bone] = (cur.rotation_difference(want) @ d).normalized()
        out.append((r, hips))
    return out


def breakdance(arm, hero_id):
    frames = []
    for file_name, repeats in BREAKDANCE[hero_id]:
        move = remove_drift(retarget_clip.mocap_offsets(os.path.join(MIXAMO_DIR, file_name), arm))
        for _ in range(repeats):
            frames = concat(frames, move)
    return retarget_clip.loop_blend(keep_on_pad(frames), blend=CROSSFADE)


def keep_on_pad(frames, radius=PAD_RADIUS):
    """Uprocks wander up to a metre; centre the routine and shrink its floor travel so the
    dancer stays on the select-screen pad (feet slide a little, which the camera hides)."""
    xy = [Vector((h.x, h.y)) for _, h in frames]
    mid = sum(xy, Vector((0, 0))) / len(xy)
    reach = max((v - mid).length for v in xy)
    k = min(1.0, radius / reach) if reach > 1e-6 else 1.0
    out = []
    for (rot, h), v in zip(frames, xy):
        d = (v - mid) * k
        out.append((rot, Vector((d.x, d.y, h.z))))
    return out


def render_dance_strip(arm, hero_id, count=6):
    """Evenly spaced BreakDance frames from the review camera, for the contact sheet."""
    sc = bpy.context.scene
    act = bpy.data.actions["BreakDance"]
    arm.animation_data.action = act
    f0, f1 = act.frame_range
    paths = []
    for i in range(count):
        f = int(f0 + (f1 - f0) * (i + 0.5) / count)
        sc.frame_set(f)
        path = os.path.join(RENDER_DIR, f"_bd_{hero_id}_{f}.png")
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths


def render_sheet(arm, hero_id):
    """Quarter top-down review sheet: idle / walk / run, matching the game camera."""
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.render.resolution_x, sc.render.resolution_y = 360, 480
    world = bpy.data.worlds.new("W"); sc.world = world
    world.color = (0.8, 0.78, 0.72)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.0; sun.rotation_euler = (math.radians(40), 0, math.radians(30))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.4
    sc.collection.objects.link(cam); sc.camera = cam
    # Game camera sits above and in front (+Z Godot = -Y Blender), looking down ~56 deg.
    cam.location = (0, -5.5, 8.0)
    cam.rotation_euler = (math.radians(34), 0, 0)
    shots = []
    for clip_name, frame in (("Idle", 0), ("Walking", 6), ("Running", 4)):
        arm.animation_data.action = bpy.data.actions[clip_name]
        sc.frame_set(frame)
        path = os.path.join(RENDER_DIR, f"heroes_{hero_id}_{clip_name.lower()}.png")
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        shots.append(path)
    log(f"  renders: {', '.join(os.path.basename(s) for s in shots)}")


# 3x5 pixel font for the moves sheet labels.
_FONT = dict(zip("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-", (
    "010101111101101", "110101110101110", "011100100100011", "110101101101110", "111100110100111",
    "111100110100100", "011100101101011", "101101111101101", "111010010010111", "001001001101010",
    "101101110101101", "100100100100111", "101111111101101", "110101101101101", "010101101101010",
    "110101110100100", "010101101110011", "110101110101101", "011100010001110", "111010010010010",
    "101101101101111", "101101101101010", "101101111111101", "101101010101101", "101101010010010",
    "111001010100111", "111101101101111", "010110010010111", "110001010100111", "110001010001110",
    "101101111001001", "111100110001110", "011100110101010", "111001010010010", "010101010101010",
    "010101011001110", "000000000000111", "000000000000010", "000000111000000")))


def _stamp(img, text, x0, y0, s=2, color=(0.75, 0.05, 0.05)):
    """Write `text` into an (H, W, 4) top-down image."""
    for ci, ch in enumerate(text.upper()):
        g = _FONT.get(ch)
        if not g:
            continue
        for r in range(5):
            for c in range(3):
                if g[r * 3 + c] == "1":
                    y, x = y0 + r * s, x0 + (ci * 4 + c) * s
                    img[y:y + s, x:x + s, :3] = color


def render_moves_sheet(arm, hero_id, names, per_clip=6, per_row=2, tile=(150, 190), suffix="moves"):
    """renders/heroes_<id>_moves.png: `per_clip` evenly spaced frames of every clip (first and
    last included), from the front-right, with a floor and shadows so floating or sunken feet,
    arms through the body and bad trims show up."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light, sh.color_type = "STUDIO", "TEXTURE"
    sh.show_shadows = True
    sc.display.shadow_shift = 0.05
    sc.render.film_transparent = False
    w, h = tile
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    if sc.world is None:
        sc.world = bpy.data.worlds.new("W")
    sc.world.color = (0.82, 0.8, 0.75)
    floor_me = bpy.data.meshes.new("QC_Floor")
    floor_me.from_pydata([(-1.5, -1.5, 0), (1.5, -1.5, 0), (1.5, 1.5, 0), (-1.5, 1.5, 0)], [], [(0, 1, 2, 3)])
    floor = bpy.data.objects.new("QC_Floor", floor_me)
    sc.collection.objects.link(floor)
    cam = bpy.data.objects.new("MovesCam", bpy.data.cameras.new("MovesCam"))
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.5
    sc.collection.objects.link(cam); sc.camera = cam
    d = Vector((0.75, -1.0, 0.42)).normalized()
    cam.location = Vector((0, 0, 0.95)) + d * 8
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    tmp = os.path.join(RENDER_DIR, f"_moves_{hero_id}.png")
    rows = (len(names) + per_row - 1) // per_row
    sheet = np.ones((rows * h, per_row * per_clip * w, 3), np.float32)
    for ci, name in enumerate(names):
        act = bpy.data.actions[name]
        arm.animation_data.action = act
        f0, f1 = (int(round(x)) for x in act.frame_range)
        for k in range(per_clip):
            f = int(round(f0 + (f1 - f0) * k / (per_clip - 1)))
            sc.frame_set(f)
            sc.render.filepath = tmp
            bpy.ops.render.render(write_still=True)
            img = bpy.data.images.load(tmp, check_existing=False)
            px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1].copy()
            bpy.data.images.remove(img)
            if k == 0:
                _stamp(px, name, 3, 3)
            _stamp(px, str(f), 3, h - 13, color=(0.2, 0.2, 0.2))
            px[:, -1, :3] = px[-1, :, :3] = 0.35
            r, c = divmod(ci, per_row)
            y, x = r * h, (c * per_clip + k) * w
            sheet[y:y + h, x:x + w] = px[..., :3]
    if os.path.exists(tmp):
        os.remove(tmp)
    bpy.data.objects.remove(floor, do_unlink=True)
    out = bpy.data.images.new("moves_sheet", sheet.shape[1], sheet.shape[0])
    rgba = np.concatenate([sheet, np.ones(sheet.shape[:2] + (1,), np.float32)], axis=2)
    out.pixels = rgba[::-1].ravel()
    path = os.path.join(RENDER_DIR, f"heroes_{hero_id}_{suffix}.png")
    out.filepath_raw = path; out.file_format = "PNG"; out.save()
    log(f"  moves sheet: {os.path.relpath(path, PROJ)}")


def export(arm, hero_id, names):
    # Clip sources can bring Meshy's stray Icosphere back; the review floor goes too.
    for o in list(bpy.data.objects):
        if o.type == "MESH" and len(o.vertex_groups) == 0:
            bpy.data.objects.remove(o, do_unlink=True)
    ad = arm.animation_data
    while len(ad.nla_tracks):
        ad.nla_tracks.remove(ad.nla_tracks[0])
    for name in names:
        act = bpy.data.actions[name]
        tr = ad.nla_tracks.new(); tr.name = name
        strip = tr.strips.new(name, int(act.frame_range[0]), act); strip.name = name
    ad.action = None
    out = os.path.join(OUT_DIR, f"{hero_id}.glb")
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", export_animations=True,
        export_animation_mode="NLA_TRACKS", export_skins=True,
        export_materials="EXPORT", export_apply=False,
    )
    log(f"  exported {os.path.relpath(out, PROJ)}: {', '.join(names)}")


def build(hero_id):
    log(f"hero {hero_id}")
    reset()
    arm = import_hero(HEROES[hero_id])
    if arm.animation_data is None:
        arm.animation_data_create()
    ad = arm.animation_data
    ad.action = None
    while len(ad.nla_tracks):
        ad.nla_tracks.remove(ad.nla_tracks[0])
    for a in list(bpy.data.actions):  # the one sample clip Meshy shipped
        bpy.data.actions.remove(a)
    table = dict(SHARED)
    table.update(HERO_CLIPS[hero_id])
    for bad in ("Slide", "Dash"):
        assert bad not in table, f"clip name {bad!r} is banned (gate asserts it is absent)"
    clips = retarget_table(arm, table)
    clips[CHAINED] = chained(arm, clips["Idle"])
    names = clip_order(hero_id)
    for name in names:
        if name == "BreakDance":
            bake_on_floor(arm, "BreakDance", breakdance(arm, hero_id))
        elif name in table and table[name]["plant"]:
            bake_planted(arm, name, clips[name])
        elif name in table and table[name]["on_floor"]:
            bake_on_floor(arm, name, clips[name])
        else:
            bake_grounded(arm, name, clips[name])
    render_sheet(arm, hero_id)
    strip = render_dance_strip(arm, hero_id)
    render_moves_sheet(arm, hero_id, [n for n in names if not n.startswith("Menu_")])
    render_moves_sheet(arm, hero_id, [n for n in names if n.startswith("Menu_")], per_row=1,
                       tile=(250, 320), suffix="menu")
    export(arm, hero_id, names)
    return strip


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(RENDER_DIR, exist_ok=True)
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(HEROES)
    dance_strips = {hero_id: build(hero_id) for hero_id in only}
    _contact_sheet(dance_strips, os.path.join(RENDER_DIR, "heroes_breakdance.png"))
    log("done")


def _contact_sheet(strips, out):
    """Rows = heroes, columns = dance frames, packed into one PNG for review."""
    if not strips:
        return
    imgs = {k: [bpy.data.images.load(p) for p in v] for k, v in strips.items()}
    w, h = imgs[next(iter(imgs))][0].size
    cols, rows = max(len(v) for v in imgs.values()), len(imgs)
    sheet = bpy.data.images.new("bd_sheet", cols * w, rows * h, alpha=True)
    px = [0.0] * (cols * w * rows * h * 4)
    for r, (k, row) in enumerate(imgs.items()):
        for c, img in enumerate(row):
            src = list(img.pixels)
            y0 = (rows - 1 - r) * h  # Blender images start at the bottom row
            for y in range(h):
                a = (y * w) * 4
                b = ((y0 + y) * cols * w + c * w) * 4
                px[b:b + w * 4] = src[a:a + w * 4]
    sheet.pixels = px
    sheet.filepath_raw = out
    sheet.file_format = "PNG"
    sheet.save()
    for row in strips.values():
        for p in row:
            os.remove(p)
    log(f"  dance sheet: {os.path.relpath(out, PROJ)}")


main()
