extends RefCounted

## The five hero GLBs and their HeroData files (spec section 4 table).

const SPEC := {
	"tutoy": {"speed": 5.4, "reach": 1.0, "cd1": 8.0, "cd2": 6.0},
	"nene": {"speed": 5.0, "reach": 1.2, "cd1": 14.0, "cd2": 10.0},
	"nathan": {"speed": 5.0, "reach": 1.2, "cd1": 10.0, "cd2": 18.0},
	"jm": {"speed": 4.6, "reach": 1.2, "cd1": 12.0, "cd2": 16.0},
	"inday": {"speed": 5.0, "reach": 1.2, "cd1": 15.0, "cd2": 12.0},
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
			for clip in ["Idle", "Walking", "Running", "BreakDance"]:
				if t.check(ap.has_animation(clip), "%s clip %s must exist" % [hid, clip]):
					t.check(ap.get_animation(clip).get_track_count() >= 60, "%s clip %s must animate the full skeleton (>= 60 tracks)" % [hid, clip])
			for bad in ["Slide", "Dash"]:
				t.check(not ap.has_animation(bad), "%s must not have an exact '%s' clip" % [hid, bad])
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
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
