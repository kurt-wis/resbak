extends RefCounted

## The five hero GLBs and their HeroData files (spec section 4 table; speeds are the v0.1.1
## pacing values, about 10 % under the spec, see docs/status.md).

const SPEC := {
	"tutoy": {"speed": 4.85, "reach": 0.9, "cd1": 8.0, "cd2": 6.0},
	"nene": {"speed": 4.5, "reach": 1.0, "cd1": 10.0, "cd2": 14.0}, # v0.2 SIGAW! / BAWAL!
	"nathan": {"speed": 4.5, "reach": 1.0, "cd1": 10.0, "cd2": 18.0},
	"jm": {"speed": 4.15, "reach": 1.0, "cd1": 12.0, "cd2": 16.0},
	"inday": {"speed": 4.5, "reach": 1.0, "cd1": 24.0, "cd2": 14.0}, # v0.2 HILA!
}

func run(t: TestCtx) -> void:
	t.check(HeroData.ORDER == ["tutoy", "nene", "nathan", "jm", "inday"], "HeroData.ORDER must be the five heroes")
	for hid in HeroData.ORDER:
		var path := "res://assets/characters/%s.glb" % hid
		var packed := load(path) as PackedScene
		if not t.check(packed != null, "%s GLB must load" % hid):
			continue
		var node := packed.instantiate()
		var ap := node.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
		if t.check(ap != null, "%s AnimationPlayer must exist" % hid):
			for clip in ["Idle", "Walking", "Running", "BreakDance", "Tag", "Stumble", "Cough"] + (["Sumbong"] if hid == "nene" else (["Ubo"] if hid == "nathan" else [])):
				if t.check(ap.has_animation(clip), "%s clip %s must exist" % [hid, clip]):
					t.check(ap.get_animation(clip).get_track_count() >= 60, "%s clip %s must animate the full skeleton (>= 60 tracks)" % [hid, clip])
			# retained TagCharge source clip (not used by tap-only tagging): seamless on every hero
			if t.check(ap.has_animation("TagCharge"), "%s clip TagCharge must exist" % hid):
				var tc := ap.get_animation("TagCharge")
				t.check(tc.get_track_count() >= 60, "%s clip TagCharge must animate the full skeleton (>= 60 tracks)" % hid)
				t.check("TagCharge" in HeroVisual.LOOP_CLIPS, "retained TagCharge library clip keeps its loop contract")
			for bad in ["Slide", "Dash"]:
				t.check(not ap.has_animation(bad), "%s must not have an exact '%s' clip" % [hid, bad])
			for clip in (["Tag"] if hid == "jm" else (["Sagip"] if hid == "inday" else [])):
				t.check(ap.has_animation(clip) and ap.get_animation(clip).get_track_count() >= 60, "%s authored %s retains full-skeleton animation" % [hid, clip])
			_reference_poses(t, node, ap, hid)
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
		if hid == "inday":
			var sk := node.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var head := sk.find_bone("mixamorig_Head")
			var parent := head
			for i in range(4):
				var hair := sk.find_bone("mixamorig_Hair%d" % (i + 1))
				t.check(hair >= 0 and sk.get_bone_parent(hair) == parent, "Inday hair joint %d belongs exclusively to the Head chain" % (i + 1))
				parent = hair
		if hid == "jm":
			var sk := node.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var finger := sk.find_bone("mixamorig_RightHandMiddle1")
			var weighted := 0
			for mesh in meshes:
				var bind := -1
				for i in range(mesh.skin.get_bind_count()):
					if mesh.skin.get_bind_bone(i) == finger or mesh.skin.get_bind_name(i) == "mixamorig_RightHandMiddle1":bind = i
				if bind < 0:continue
				for surface in range(mesh.mesh.get_surface_count()):
					var arrays: Array = mesh.mesh.surface_get_arrays(surface)
					for i in range(arrays[Mesh.ARRAY_BONES].size()):
						if arrays[Mesh.ARRAY_BONES][i] == bind and arrays[Mesh.ARRAY_WEIGHTS][i] > 0.01:weighted += 1
			t.check(weighted > 100, "JM's grip joint deforms actual finger vertices rather than an unweighted placeholder")
		t.check(meshes.size() == 1, "%s must have exactly one mesh, got %d" % [hid, meshes.size()])
		node.free()

		var hd := HeroData.load_hero(hid)
		if not t.check(hd != null, "data/heroes/%s.tres must load as HeroData" % hid):
			continue
		var want: Dictionary = SPEC[hid]
		t.check(hd.id == hid, "%s id" % hid)
		t.check(t.near(hd.run_speed, want.speed), "%s run speed %.1f (got %.2f)" % [hid, want.speed, hd.run_speed])
		t.check(t.near(hd.tag_reach, want.reach), "%s tag reach %.1f (got %.2f)" % [hid, want.reach, hd.tag_reach])
		t.check(t.near(hd.skill1_cooldown, want.cd1), "%s S1 cooldown %.0f (got %.1f)" % [hid, want.cd1, hd.skill1_cooldown])
		t.check(t.near(hd.skill2_cooldown, want.cd2), "%s S2 cooldown %.0f (got %.1f)" % [hid, want.cd2, hd.skill2_cooldown])
		t.check(hd.glb == path, "%s .tres must point at %s" % [hid, path])
		t.check(hd.skill1_name != "" and hd.skill2_name != "" and hd.passive_name != "", "%s names its two skills and passive" % hid)
		for pair in [["skill1_script", hd.skill1_script], ["skill2_script", hd.skill2_script], ["passive_script", hd.passive_script]]:
			var s: Script = pair[1]
			t.check(s != null and s.can_instantiate(), "%s %s must be a compiling script" % [hid, pair[0]])
		for pair in [[hd.skill1_script, "skill1_script"], [hd.skill2_script, "skill2_script"]]:
			if pair[0]:
				var sk: Node = pair[0].new()
				t.check(sk is Skill, "%s %s must extend Skill" % [hid, pair[1]])
				sk.free()
		if hd.passive_script:
			var ps: Node = hd.passive_script.new()
			t.check(ps is Passive, "%s passive_script must extend Passive" % hid)
			ps.free()
	t.ok("hero GLBs and HeroData match the spec table")
	for pair in [["res://assets/props/tamaraw_spirit.glb", "Spirit_Charge", 5000], ["res://assets/props/jm_towel.glb", "Towel_Whip", 1500]]:
		var prop := (load(pair[0]) as PackedScene).instantiate()
		var tris := 0
		for mesh in prop.find_children("*", "MeshInstance3D", true, false):
			tris += mesh.mesh.get_faces().size() / 3
		var player := prop.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
		t.check(tris > 0 and tris <= int(pair[2]), "%s stays within its triangle budget" % pair[0])
		t.check(player != null and player.has_animation(pair[1]), "%s exports its authored NLA action" % pair[0])
		prop.free()

func _reference_poses(t: TestCtx, node: Node, ap: AnimationPlayer, hid: String) -> void:
	# Sample the exported clips, so an export/mapping error cannot pass a source-only check.
	t.tree.root.add_child(node)
	var skeleton := node.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hand := skeleton.find_bone("mixamorig_RightHand")
	var shoulder := skeleton.find_bone("mixamorig_RightArm")
	ap.play("Tag")
	ap.seek(ap.get_animation("Tag").length * 0.55, true)
	var contact: Array[Transform3D] = []
	for i in range(skeleton.get_bone_count()):contact.append(skeleton.get_bone_global_pose(i))
	if hid != "jm":
		var upright := contact[hand].basis.y.normalized().dot(Vector3.UP)
		t.check(upright > 0.8, "%s tags with upright open-palm fingers (up %.3f)" % [hid, upright])
	else:
		ap.seek(ap.get_animation("Tag").length * 0.34, true)
		t.check(skeleton.get_bone_global_pose(hand).origin.y > skeleton.get_bone_global_pose(shoulder).origin.y + 0.05, "JM raises the held towel behind the shoulder before snapping")
	ap.play("Stumble")
	ap.seek(0.0, true)
	var largest := 0.0
	for i in range(skeleton.get_bone_count()):largest = maxf(largest, contact[i].origin.distance_to(skeleton.get_bone_global_pose(i).origin))
	t.check(largest < 0.025, "%s miss starts at the exported tag contact (%.4f m)" % [hid, largest])
	if hid == "nathan":
		ap.play("Ubo")
		ap.seek(ap.get_animation("Ubo").length * 0.34, true)
		var raised := skeleton.get_bone_global_pose(hand).origin.y - skeleton.get_bone_global_pose(shoulder).origin.y
		t.check(raised > 0.05, "Nathan gathers the packet above and behind the shoulder (raised %.3f m)" % raised)
	ap.stop()
	t.tree.root.remove_child(node)
