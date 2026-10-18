extends SceneTree

## Hand-motion QC for the Home diorama (spec § 6 Home). Builds the diorama manually stepped, runs it
## 1/60 s at a time for one full 48 s loop plus a couple of seconds past the wrap, and tracks the world
## positions of every hero's hands. A pop at an animation boundary (a gesture cut mid-motion, a
## base-idle seam) shows up as a spike in the hand's speed or in its frame-to-frame velocity change.
## Headless works:
##   & $env:GODOT --headless --path . -s tools/qc_home_motion.gd [-- --out=renders/qc/home_motion.json]
## The gate (scripts/tests/suites/home.gd) runs the same HomeMotion sampler against fixed thresholds.

const OUT := "res://renders/qc/home_motion.json"
const STEP := 1.0 / 60.0
const EXTRA := 2.0 ## seconds simulated past the wrap

func _initialize() -> void:
	_run.call_deferred()

func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.get_slice("=", 1)
	return fallback

func _run() -> void:
	var d := HomeDiorama.new()
	d.manual = true
	root.add_child(d)
	await process_frame
	await process_frame
	var res: Dictionary = HomeMotion.measure(d, EXTRA)
	var spikes: Array = res.spikes
	spikes.sort_custom(func(a, b): return a.dv > b.dv)
	print("== top 10 hand velocity-change spikes (m/s per frame) ==")
	for i in range(mini(10, spikes.size())):
		var s: Dictionary = spikes[i]
		print("  t=%6.2f  %-7s %-22s  dv=%.3f  speed=%.2f  during %s" % [s.t, s.hero, s.bone, s.dv, s.speed, s.active])
	for hero in res.heroes:
		var h: Dictionary = res.heroes[hero]
		print("%-7s peak speed %.2f m/s @%.2f (%s) | peak dv %.3f m/s/frame @%.2f (%s)" % [hero, h.peak_speed, h.peak_speed_t,
				h.peak_speed_active, h.peak_dv, h.peak_dv_t, h.peak_dv_active])
	res.erase("spikes")
	res["top_spikes"] = spikes.slice(0, 10)
	var path := ProjectSettings.globalize_path(_arg("out", OUT))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "\t"))
	f.close()
	print("wrote ", path)
	quit()
