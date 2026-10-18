class_name HomeMotion
extends RefCounted

## Hand-motion sampler for the Home diorama (used by tools/qc_home_motion.gd and the `home` gate suite).
## Steps a manually driven HomeDiorama at 60 Hz over one loop plus a little past the wrap and records,
## per hero, the peak speed of the hands and the peak frame-to-frame change of their velocity. A hand
## that is yanked by a gesture cut mid-motion, or by a base-idle loop seam, shows as a velocity-change
## spike; a smooth hand does not. Presentation QC only: nothing here touches gameplay.

const BONES := ["mixamorig_LeftHand", "mixamorig_RightHand", "mixamorig_LeftHandIndex1", "mixamorig_RightHandIndex1"]
const STEP := 1.0 / 60.0
const SKIP := 0.3 ## seconds ignored at the start (the tree's first frames settle from the rest pose)
const SPIKE_FLOOR := 0.02 ## m/s per frame: smaller velocity changes are not worth listing

## Returns {"duration", "heroes": {hero: {peak_speed, peak_speed_t, peak_speed_active, peak_dv, peak_dv_t,
## peak_dv_active, bones: {bone: {peak_speed, peak_dv}}}}, "spikes": [{t, hero, bone, dv, speed, active}]}.
## `dv` is |v_now - v_prev| in m/s for one 1/60 s step; `speed` is m/s. `extra` seconds run past the wrap.
static func measure(d: HomeDiorama, extra := 2.0) -> Dictionary:
	d.seek_to(0.0)
	var heroes := {}
	var prev_pos := {}
	var prev_vel := {}
	var spikes: Array = []
	for hero in d.actors:
		heroes[hero] = {"peak_speed": 0.0, "peak_speed_t": 0.0, "peak_speed_active": "",
				"peak_dv": 0.0, "peak_dv_t": 0.0, "peak_dv_active": "", "bones": {}}
	var total: float = d.data.loop_length + extra
	var steps := int(total / STEP)
	for i in range(steps):
		d.step(STEP)
		var tt := (i + 1) * STEP
		for hero in d.actors:
			var a: DioramaActor = d.actors[hero]
			var h: Dictionary = heroes[hero]
			for bn in BONES:
				var bi := a.skeleton.find_bone(bn)
				if bi < 0:
					continue
				var p: Vector3 = a.skeleton.global_transform * a.skeleton.get_bone_global_pose(bi).origin
				var key := "%s/%s" % [hero, bn]
				var vel := Vector3.ZERO
				var have_vel := false
				if prev_pos.has(key):
					vel = (p - prev_pos[key]) / STEP
					have_vel = true
				if tt >= SKIP and have_vel:
					var speed := vel.length()
					var bone_d: Dictionary = h.bones.get(bn, {"peak_speed": 0.0, "peak_dv": 0.0})
					bone_d.peak_speed = maxf(bone_d.peak_speed, speed)
					var active := active_at(d, hero, fposmod(tt, d.data.loop_length))
					if speed > h.peak_speed:
						h.peak_speed = speed
						h.peak_speed_t = tt
						h.peak_speed_active = active
					if prev_vel.has(key):
						var dv: float = (vel - prev_vel[key]).length()
						bone_d.peak_dv = maxf(bone_d.peak_dv, dv)
						if dv > h.peak_dv:
							h.peak_dv = dv
							h.peak_dv_t = tt
							h.peak_dv_active = active
						if dv >= SPIKE_FLOOR:
							spikes.append({"t": snappedf(tt, 0.001), "hero": hero, "bone": bn,
									"dv": snappedf(dv, 0.0001), "speed": snappedf(speed, 0.001), "active": active})
					h.bones[bn] = bone_d
				prev_pos[key] = p
				if have_vel:
					prev_vel[key] = vel
	for hero in heroes:
		var h: Dictionary = heroes[hero]
		for k in ["peak_speed", "peak_speed_t", "peak_dv", "peak_dv_t"]:
			h[k] = snappedf(h[k], 0.0001)
		for bn in h.bones:
			h.bones[bn].peak_speed = snappedf(h.bones[bn].peak_speed, 0.0001)
			h.bones[bn].peak_dv = snappedf(h.bones[bn].peak_dv, 0.0001)
	return {"duration": total, "hz": roundi(1.0 / STEP), "heroes": heroes, "spikes": spikes}

## What is driving `hero`'s upper body at loop time `u`: the base clip, or the scheduled gesture
## (marked fade-in / fade-out while the OneShot is blending in or out).
static func active_at(d: HomeDiorama, hero: String, u: float) -> String:
	for g in d.data.gestures:
		if String(g.hero) != hero:
			continue
		if u >= float(g.t) and u < float(g.t) + float(g.dur) + d.data.gesture_fade_out:
			var tag := String(g.clip)
			if u < float(g.t) + d.data.gesture_fade_in:
				tag += " (fade-in)"
			elif u >= float(g.t) + float(g.dur):
				tag += " (fade-out)"
			return tag
	return String(d.data.cast[hero].get("base", ""))
