"""Separate near-coplanar source triangles without dropping textured fabric faces."""
from mathutils import Vector
from mathutils.bvhtree import BVHTree

def repair(mesh, eps=.001):
    def inside(p,a,b,c,n):
        return all((v-u).cross(p-u).dot(n)>=-1e-9 for u,v in ((a,b),(b,c),(c,a)))
    total=0
    for iteration in range(12):
        mesh.update();mesh.calc_loop_triangles()
        verts=[v.co.copy() for v in mesh.vertices]
        tris=[tuple(t.vertices) for t in mesh.loop_triangles]
        normals=[t.normal.copy() for t in mesh.loop_triangles]
        tree=BVHTree.FromPolygons(verts,tris)
        fixes={}
        for ti,t in enumerate(tris):
            a,b,c=(verts[i] for i in t);n=normals[ti];cen=(a+b+c)/3
            for p in (cen,cen.lerp(a,.6),cen.lerp(b,.6),cen.lerp(c,.6)):
                for _,_,tj,_ in tree.find_nearest_range(p,eps):
                    if tj is None or tj<=ti or set(t)&set(tris[tj]) or n.dot(normals[tj])<.999:continue
                    a2,b2,c2=(verts[i] for i in tris[tj]);n2=normals[tj]
                    q=p-n2*n2.dot(p-a2)
                    if inside(q,a2,b2,c2,n2):fixes[tj]=n2
        if not fixes:break
        shifts={}
        for ti,n in fixes.items():
            for vi in tris[ti]:shifts[vi]=n*.0025
        for vi,shift in shifts.items():mesh.vertices[vi].co+=shift
        total+=len(fixes)
        print('Fabric separation iteration',iteration,'faces',len(fixes),flush=True)
    mesh.update()
    return total
