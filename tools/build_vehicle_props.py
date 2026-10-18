"""
build_vehicle_props.py - Mathew's Meshy vehicles -> game-ready Konstruksyon props (2026-10-17).

Mathew remodelled the Konstruksyon vehicles in Meshy. The raw downloads (source_art/props/vehicles/)
are each one textured mesh, ~0.95 m long, centred on the origin (not grounded), front at -X.
This script makes them floor props that drop into the old vehicle nodes of construction_site.tscn:

  * rotated 180 deg about Z, so the front (cab / digger arm) faces +X like the old box-built vehicles
  * grounded (lowest point at Z = 0) and centred on X/Y
  * uniformly scaled to fit inside the old vehicle's local footprint (FIT below, metres L x W x H),
    so the new model replaces the old one without changing lanes; the scene's StaticBody boxes are
    refitted to the printed sizes
  * textures downscaled to TEX px (they are small on screen; 2048 px x 3 maps x 5 trucks was ~60 MB VRAM)

Output: assets/props/vehicles/<name>.glb   (+ <name>.tscn that instances it; the map instances the .tscn)
Run:    & $env:BLENDER -b --python tools/build_vehicle_props.py            (all five)
        & $env:BLENDER -b --python tools/build_vehicle_props.py -- pickup  (one)
Then:   & $env:BLENDER -b --python tools/qc_asset.py -- assets/props/vehicles/<name>.glb --height 0 --max-tris 10000
"""
import bpy, os, sys, math
from mathutils import Vector, Matrix

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
SRC = os.path.join(PROJ, "source_art", "props", "vehicles")
OUT = os.path.join(PROJ, "assets", "props", "vehicles")
TEX = 1024
# name: (node name in the .tscn, fit box L x W x H in the old vehicle node's local metres)
FIT = {
    "jeepney": ("Jeepney", (6.32, 2.47, 2.81)),        # RoadAndWalkways/PhilippineJeepney
    "pickup": ("Pickup", (4.86, 2.30, 2.47)),          # the three pickups (their nodes scale 0.82/0.72/0.65)
    "hauler": ("Hauler", (5.70, 2.30, 2.57)),          # ConstructionEquipment/DumpTruck (+ its mirror twin)
    "digger": ("Digger", (6.00, 3.00, 3.30)),          # ConstructionEquipment/OrangeTrackedExcavator
    "wheel_loader": ("WheelLoader", (5.00, 1.80, 2.20)),  # ConstructionEquipment/CompactYellowLoader
}


def log(msg):
    print(f"[vehicle_props] {msg}", flush=True)


def bounds(objs):
    # from the vertices: Object.bound_box is cached and goes stale after mesh.transform()
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def build(name):
    node, fit = FIT[name]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name + ".glb"))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    # flatten any import hierarchy into plain world-space meshes
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in [o for o in bpy.data.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o)
    turn = Matrix.Rotation(math.pi, 4, "Z")
    for o in meshes:
        o.data.transform(turn @ o.matrix_world)
        o.matrix_world = Matrix.Identity(4)
    lo, hi = bounds(meshes)
    size = hi - lo
    s = min(fit[0] / size.x, fit[1] / size.y, fit[2] / size.z)
    shift = Vector((-(lo.x + hi.x) * 0.5, -(lo.y + hi.y) * 0.5, -lo.z))
    for o in meshes:
        o.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(shift))
        o.data.update()
        o.name = node if len(meshes) == 1 else f"{node}_{o.name}"
    for img in bpy.data.images:
        if img.size[0] > TEX or img.size[1] > TEX:
            img.scale(min(TEX, img.size[0]), min(TEX, img.size[1]))
            img.pack()
    lo, hi = bounds(meshes)
    size = hi - lo
    tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
    os.makedirs(OUT, exist_ok=True)
    glb = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_materials="EXPORT",
                              export_image_format="AUTO", export_yup=True, export_apply=True)
    with open(os.path.join(OUT, name + ".tscn"), "w", newline="\n") as f:
        f.write('[gd_scene load_steps=2 format=3]\n\n')
        f.write(f'[ext_resource type="PackedScene" path="res://assets/props/vehicles/{name}.glb" id="1_{name}"]\n\n')
        f.write(f'[node name="{node}" instance=ExtResource("1_{name}")]\n')
    log(f"{name}: scale {s:.3f}  size L {size.x:.2f} W {size.y:.2f} H {size.z:.2f}  tris {tris}  -> {glb}")
    print(f"SIZE {name} {size.x:.3f} {size.y:.3f} {size.z:.3f}", flush=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name in (argv or list(FIT)):
        build(name)


main()
