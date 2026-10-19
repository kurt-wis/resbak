"""Polish the current full-rig libraries without rebuilding unrelated source assets.

Blender -b --factory-startup --python tools/build_motion_pass.py -- [hero ids]
Writes review GLBs in renders/motion_pass before promotion to assets/characters.
"""
import bpy, sys, math, json
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_heroes as base
from build_hero_polish import key_pose
from build_revision_animations import orient

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'renders/motion_pass'


def ramp(u, a, b):
    t = min(1, max(0, (u-a)/(b-a)))
    return t*t*(3-2*t)


def torso(arm, lean, twist=0):
    for tail in ('Spine', 'Spine1', 'Spine2'):
        pb = arm.pose.bones.get('mixamorig:'+tail)
        if pb:
            m = pb.matrix.copy()
            q = Quaternion((0, 0, 1), twist/3) @ Quaternion((1, 0, 0), lean/3) @ m.to_quaternion()
            pb.matrix = Matrix.Translation(m.translation) @ q.to_matrix().to_4x4()
            bpy.context.view_layer.update()


def cup_hand(arm, side, target, weight):
    upper=arm.pose.bones.get('mixamorig:'+side+'Arm')
    fore=arm.pose.bones.get('mixamorig:'+side+'ForeArm')
    hand=arm.pose.bones.get('mixamorig:'+side+'Hand')
    if not all((upper,fore,hand)):return
    a=upper.matrix.translation.copy()
    l1=(fore.matrix.translation-a).length
    l2=(hand.matrix.translation-fore.matrix.translation).length
    vector=target-a;distance=min(vector.length,(l1+l2)*.98)
    direction=vector.normalized()
    along=(l1*l1-l2*l2+distance*distance)/(2*distance)
    height=math.sqrt(max(.0001,l1*l1-along*along))
    pole=Vector((-1 if side=='Right' else 1,0,-.4))
    pole=(pole-direction*pole.dot(direction)).normalized()
    elbow=a+direction*along+pole*height
    orient(arm,side+'Arm',elbow-a,weight)
    orient(arm,side+'ForeArm',target-fore.matrix.translation,weight)
    orient(arm,side+'Hand',(0,-1,.1),weight)


def reach(arm, side, target, pole, weight=1):
    """Two-bone reach with a stable elbow pole, preserving segment lengths."""
    upper=arm.pose.bones['mixamorig:'+side+'Arm']
    fore=arm.pose.bones['mixamorig:'+side+'ForeArm']
    hand=arm.pose.bones['mixamorig:'+side+'Hand']
    a=upper.matrix.translation.copy()
    l1=(fore.matrix.translation-a).length
    l2=(hand.matrix.translation-fore.matrix.translation).length
    delta=target-a
    distance=min(delta.length,(l1+l2)*.985)
    direction=delta.normalized()
    along=(l1*l1-l2*l2+distance*distance)/(2*distance)
    pole=Vector(pole)
    pole=(pole-direction*pole.dot(direction)).normalized()
    elbow=a+direction*along+pole*math.sqrt(max(0,l1*l1-along*along))
    orient(arm,side+'Arm',elbow-a,weight)
    orient(arm,side+'ForeArm',a+direction*distance-fore.matrix.translation,weight)


def open_palm(arm, weight):
    hand=arm.pose.bones['mixamorig:RightHand']
    m=hand.matrix.copy()
    # Fingers +Z, palm -Y: full-rig hand axes were measured from the mesh.
    rotation=Matrix(((0,0,1),(1,0,0),(0,1,0))).to_quaternion()
    hand.matrix=Matrix.Translation(m.translation)@m.to_quaternion().slerp(rotation,weight).to_matrix().to_4x4()
    bpy.context.view_layer.update()


def brace(arm, u):
    """Lead-foot plant and weight transfer; keep ankles level with the floor."""
    weight=ramp(u,0,.30)*(1-ramp(u,.74,1))
    for side, sign in [('Left',-1),('Right',1)]:
        upper=arm.pose.bones['mixamorig:'+side+'UpLeg']
        lower=arm.pose.bones['mixamorig:'+side+'Leg']
        foot=arm.pose.bones['mixamorig:'+side+'Foot']
        ankle=foot.matrix.copy()
        a=upper.matrix.translation.copy()
        l1=(lower.matrix.translation-a).length
        l2=(ankle.translation-lower.matrix.translation).length
        target=ankle.translation+Vector((0,sign*.22*(l1+l2)*weight,0))
        delta=target-a
        distance=min(delta.length,(l1+l2)*.997)
        direction=delta.normalized()
        along=(l1*l1-l2*l2+distance*distance)/(2*distance)
        pole=Vector((0,-1,0));pole=(pole-direction*pole.dot(direction)).normalized()
        knee=a+direction*along+pole*math.sqrt(max(0,l1*l1-along*along))
        orient(arm,side+'UpLeg',knee-a)
        orient(arm,side+'Leg',target-lower.matrix.translation)
        m=foot.matrix.copy()
        foot.matrix=Matrix.Translation(m.translation)@ankle.to_quaternion().to_matrix().to_4x4()
        bpy.context.view_layer.update()


def overhead_pose(arm, u, pickup=False):
    """Bag pickup / shoulder coil / overhead release / cross-body recovery."""
    gather=ramp(u,0,.30)
    coil=ramp(u,.18,.36)
    release=ramp(u,.37,.50 if pickup else .55)
    follow=ramp(u,.55,.73)
    recover=ramp(u,.76,1)
    envelope=1-recover
    brace(arm,u)
    torso(arm,(-.28*coil+.62*release)*envelope,(-.38*coil+.7*release)*envelope)
    shoulder=arm.pose.bones['mixamorig:RightArm'].matrix.translation.copy()
    length=sum((arm.pose.bones['mixamorig:'+b].matrix.translation-arm.pose.bones['mixamorig:'+a].matrix.translation).length for a,b in [('RightArm','RightForeArm'),('RightForeArm','RightHand')])
    bag=Vector((.18,-.16,-.62))*length
    wind=Vector((-.16,.39,.62))*length
    contact=Vector((-.06,-.94,.12))*length
    across=Vector((.47,-.57,-.46))*length
    offset=bag.lerp(wind,coil).lerp(contact,release).lerp(across,follow)
    reach(arm,'Right',shoulder+offset,(-1,.1,.6),gather*envelope)
    orient(arm,'RightHand',(0,-1,-.35),release*envelope)
    orient(arm,'LeftArm',(.5,-.6,-.3),gather*envelope*.8)
    orient(arm,'LeftForeArm',(-.2,-.65,.4),gather*envelope*.8)


def strike_pose(arm, u):
    if arm.get('hero_id')=='jm':
        overhead_pose(arm,u)
        return
    gather = ramp(u, 0, .32)
    hit = ramp(u, .34, .55)
    recover = ramp(u, .72, 1)
    envelope = 1-recover
    brace(arm,u)
    torso(arm, (-.34*gather + .61*hit)*envelope, (-.28*gather+.5*hit)*envelope)
    shoulder=arm.pose.bones['mixamorig:RightArm'].matrix.translation.copy()
    length=sum((arm.pose.bones['mixamorig:'+b].matrix.translation-arm.pose.bones['mixamorig:'+a].matrix.translation).length for a,b in [('RightArm','RightForeArm'),('RightForeArm','RightHand')])
    offset=Vector((-.28,.02,-.3)).lerp(Vector((-.04,-.97,.04)),hit)*length
    reach(arm,'Right',shoulder+offset,(-1,0,-.7),ramp(u,0,.18)*envelope)
    open_palm(arm,ramp(u,.32,.53)*envelope)
    orient(arm, 'LeftArm', (.55, -.08, -.55), gather*envelope*.65)
    orient(arm, 'LeftForeArm', (-.25, -.45, .6), gather*envelope*.65)


def author(arm, name, neutral, mode):
    old = bpy.data.actions.get(name)
    arm.animation_data.action = None
    if old:
        bpy.data.actions.remove(old)
    count = {'Tag': 24, 'Stumble': 18, 'Ubo': 24, 'Sumbong': 18}[name]
    # The large towel arc needs an exact sampled 55% contact (frame 22).
    # Runtime retimes the source and still displays only 24 poses each second.
    if name=='Tag' and arm.get('hero_id')=='jm':count=40
    for frame in range(count+1):
        bpy.context.scene.frame_set(frame)
        for pb in arm.pose.bones:
            pb.matrix_basis = neutral[pb.name]
        bpy.context.view_layer.update()
        u = frame/count
        if mode == 'strike':
            strike_pose(arm, u)
        elif mode == 'miss':
            # The first miss pose is the strike's exact contact pose, so momentum
            # continues through the transition instead of restarting from Idle.
            strike_pose(arm, .55+.45*ramp(u, 0, .9))
            wobble = math.sin(math.pi*u)*(1-ramp(u, .6, 1))
            torso(arm, .17*wobble, -.18*wobble)
            orient(arm, 'LeftArm', (.85, -.25, -.1), wobble*.8)
            orient(arm, 'RightArm', (-.8, -.5, -.1), wobble*.55)
        elif mode == 'throw':
            overhead_pose(arm,u,pickup=True)
            # Close the existing finger chains around the held packet, opening at release.
            grip=(1-ramp(u,.44,.54))*ramp(u,0,.20)
            for pb in arm.pose.bones:
                if pb.name.startswith('mixamorig:RightHand') and any(finger in pb.name for finger in ('Index','Middle','Ring','Pinky')):
                    pb.rotation_quaternion=pb.rotation_quaternion@Quaternion((1,0,0),.75*grip)
        elif mode == 'shout':
            # Cupped hands, open elbows, a chest inhale and forward projected shout.
            hold = ramp(u, 0, .12)*(1-ramp(u,.72,1))
            torso(arm, (-.12+.3*ramp(u,.10,.30))*hold)
            head=arm.pose.bones.get('mixamorig:Head')
            mouth=head.matrix @ head.bone.matrix_local.inverted() @ Vector(arm['mouth_target'])
            for side, sign in [('Right',-1),('Left',1)]:
                cup_hand(arm,side,mouth+Vector((sign*.10,-.015,-.015)),hold)
            head=arm.pose.bones.get('mixamorig:Head')
            if head:
                head.rotation_quaternion = head.rotation_quaternion @ Quaternion((1,0,0),-.1*hold)
        key_pose(arm,frame)
    action=arm.animation_data.action
    action.name=name
    action.use_fake_user=True
    # Dense 24 fps authored samples are linear; the runtime only displays 24 poses/s.
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation='LINEAR'


def build(hero):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps=24
    source=ROOT/('source_art/heroes/inday_motion_source.glb' if hero=='inday' else f'assets/characters/{hero}.glb')
    bpy.ops.import_scene.gltf(filepath=str(source))
    arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    arm['hero_id']=hero
    if hero=='nene':
        before=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/face_cards/nene_cards.glb'))
        card=next(o for o in bpy.data.objects if o not in before and o.name.startswith('Mouth'))
        mouth=sum((card.matrix_world@v.co for v in card.data.vertices),Vector())/len(card.data.vertices)
        arm['mouth_target']=list(arm.matrix_world.inverted()@mouth)
        for ob in list(bpy.data.objects):
            if ob not in before:bpy.data.objects.remove(ob,do_unlink=True)
    names=[a.name for a in bpy.data.actions]
    while arm.animation_data.nla_tracks:
        arm.animation_data.nla_tracks.remove(arm.animation_data.nla_tracks[0])
    arm.animation_data.action=bpy.data.actions['Idle']
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    neutral={pb.name:pb.matrix_basis.copy() for pb in arm.pose.bones}
    modes=[('Tag','strike'),('Stumble','miss')]
    if hero=='nathan':modes.append(('Ubo','throw'))
    if hero=='nene':modes.append(('Sumbong','shout'))
    for name,mode in modes:
        author(arm,name,neutral,mode)
        if name not in names:names.append(name)
    for name in names:
        action=bpy.data.actions[name]
        track=arm.animation_data.nla_tracks.new()
        track.name=name
        track.strips.new(name,int(action.frame_range[0]),action)
    arm.animation_data.action=None
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{hero}.glb'),export_format='GLB',
        export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True)
    for track in arm.animation_data.nla_tracks:track.mute=True
    base.render_moves_sheet(arm,hero,[n for n,_ in modes],per_row=1,tile=(200,240),suffix='motion',samples=(0,.2,.34,.55,.73,1),view=(-1,-.25,.22))
    print('MOTION_PASS',hero,'bones',len(arm.data.bones),'clips',len(names),flush=True)


if __name__=='__main__':
    ids=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(base.HEROES)
    for hero in ids:build(hero)
