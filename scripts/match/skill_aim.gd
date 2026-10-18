class_name SkillAim
extends RefCounted

## Per-kit UI contract. Gameplay values remain in HeroData; no simulation state is changed.
static func profile(skill: Skill) -> Dictionary:
	var h := skill.hero
	var v := h.data.values
	var result := {"mode": "self", "icon": "shield", "hint": "Release to activate", "range": 0.0, "width": h.tuning.body_radius * 2.0, "radius": h.tuning.body_radius, "angle": 0.0, "color": h.data.color}
	match h.data.id + str(skill.slot):
		"jm0":
			result.merge({"mode": "point", "icon": "jump", "hint": "Choose landing + wall direction", "range": float(v.talbog_range), "radius": float(v.talbog_push_radius)}, true)
		"jm1":
			result.merge({"mode": "path", "icon": "charge", "hint": "Charge; steer after release / tap STOP", "range": float(v.tamaraw_speed) * float(v.tamaraw_time) * h.tuning.move_speed_scale * (1.0 - h.strongest_slow())}, true)
		"tutoy0":
			result.merge({"mode": "path", "icon": "sprint", "hint": "Burst; keep steering with the movement stick", "range": float(v.harurot_speed) * float(v.harurot_time) * h.tuning.move_speed_scale * (1.0 - h.strongest_slow())}, true)
		"tutoy1":
			result.merge({"mode": "path", "icon": "slide", "hint": "Slide this way / vault low props", "range": float(v.lusot_distance)}, true)
		"nene0":
			result.merge({"mode": "line", "icon": "shout", "hint": "First enemy: stun / first ally: dash", "range": float(v.sigaw_range), "width": float(v.sigaw_radius) * 2.0}, true)
		"nene1":
			result.merge({"icon": "shield", "hint": "Protect yourself / punish an enemy tag"}, true)
		"nathan0":
			result.merge({"mode": "cone", "icon": "cone", "hint": "Powder cone / walls block hits", "range": float(v.buga_length), "angle": float(v.buga_width_deg)}, true)
		"nathan1":
			result.merge({"mode": "point", "icon": "cloud", "hint": "Choose where the hiding cloud lands", "range": float(v.ubo_range), "radius": float(v.ubo_radius)}, true)
		"inday0":
			result.merge({"mode": "lane", "icon": "wind", "hint": "Allies run faster in this lane / tap STOP", "range": float(v.ihip_length), "width": float(v.ihip_width)}, true)
		"inday1":
			result.merge({"mode": "line", "icon": "hand", "hint": "Reach a teammate or chain tip to rescue + pull", "range": float(v.hila_range), "radius": float(v.hila_grab), "width": float(v.hila_grab) * 2.0}, true)
	return result

static func describe(skill: Skill, frame: InputFrame) -> Dictionary:
	var result := profile(skill)
	var h := skill.hero
	var dir := frame.aim_direction(h.global_position)
	if dir == Vector3.ZERO:
		dir = h.aim if h.aim.length() > 0.01 else h.facing
	if not frame.skill_aimed and h.data.id == "tutoy" and h.wish_dir != Vector3.ZERO:
		dir = h.wish_dir
	dir = RB.flat(dir).normalized()
	var reach: float = result.range
	if result.mode == "point" and frame.aim_distance(h.global_position) >= 0.0:
		reach = minf(reach, frame.aim_distance(h.global_position))
	if result.mode in ["path", "lane", "line"]:
		var mask := RB.MASK_LOS
		if h.data.id == "tutoy" and skill.slot == 1 or h.data.id == "inday" and skill.slot == 1:
			mask = RB.L_WORLD | RB.L_SKILL_WALL
		var hit := h.host.ray_hit(h.global_position, h.global_position + dir * reach, mask)
		if not hit.is_empty():
			reach = maxf(0.0, RB.flat_dist(h.global_position, hit.position))
	result.direction = dir
	result.point = h.global_position + dir * reach
	result.distance = reach
	result.wall = []
	return result

## Stick distance selects a point, never increases its maximum range.
static func apply_input(frame: InputFrame, h: Hero, button: int, direction: Vector2, fraction: float) -> void:
	var slot := 0 if button == RB.BTN_SKILL1 else 1
	var config := profile(h.skills[slot])
	if config.mode == "self" or direction == Vector2.ZERO:
		return
	frame.skill_aimed = true
	frame.aim_dir = direction.normalized()
	if config.mode == "point" and fraction >= 0.0:
		frame.has_aim = true
		frame.aim_point = h.global_position + Vector3(direction.x, 0, direction.y).normalized() * float(config.range) * clampf(fraction, 0.0, 1.0)

## Code-native ability icons, drawn inside the actual touch buttons.
static func draw_icon(canvas: CanvasItem, kind: String, at: Vector2, scale: float, color: Color) -> void:
	var s := scale
	match kind:
		"jump":
			canvas.draw_arc(at + Vector2(-s * 0.3, s * 0.3), s, PI, TAU, 20, color, 3, true)
			canvas.draw_line(at + Vector2(s * 0.7, 0), at + Vector2(s * 0.7, s * 0.6), color, 3, true)
			for i in range(3):
				canvas.draw_rect(Rect2(at + Vector2(-s + i * s * 0.7, s * 0.65), Vector2(s * 0.6, s * 0.3)), color, false, 2)
		"charge", "sprint", "slide":
			for i in range(2):
				var x := -s * 0.5 + i * s * 0.65
				canvas.draw_polyline(PackedVector2Array([at + Vector2(x - s * 0.4, -s * 0.6), at + Vector2(x + s * 0.3, 0), at + Vector2(x - s * 0.4, s * 0.6)]), color, 3, true)
			if kind == "slide":
				canvas.draw_line(at + Vector2(-s, s * 0.9), at + Vector2(s, s * 0.9), color, 3, true)
			elif kind == "charge":
				canvas.draw_arc(at + Vector2(0, -s * 0.4), s, PI, TAU, 12, color, 3, true)
			else:
				canvas.draw_line(at + Vector2(-s * 1.2, s * 0.6), at + Vector2(-s * 0.6, s * 0.6), color, 3, true)
		"shield":
			canvas.draw_polyline(PackedVector2Array([at + Vector2(-s * 0.8, -s * 0.7), at + Vector2(s * 0.8, -s * 0.7), at + Vector2(s * 0.6, s * 0.35), at + Vector2(0, s), at + Vector2(-s * 0.6, s * 0.35), at + Vector2(-s * 0.8, -s * 0.7)]), color, 3, true)
		"cloud":
			for offset in [Vector2(-0.55, 0.2), Vector2(0, -0.2), Vector2(0.55, 0.2)]:
				canvas.draw_arc(at + offset * s, s * 0.6, 0, TAU, 20, color, 3, true)
		"hand":
			canvas.draw_rect(Rect2(at + Vector2(-s * 0.5, 0), Vector2(s, s * 0.75)), color, false, 3)
			for i in range(4):
				var x := -s * 0.5 + i * s / 3.0
				canvas.draw_line(at + Vector2(x, 0), at + Vector2(x, -s * (0.65 + (0.2 if i in [1, 2] else 0.0))), color, 3, true)
			canvas.draw_line(at + Vector2(-s * 0.5, s * 0.5), at + Vector2(-s, 0), color, 3, true)
		"cone", "wind", "shout":
			for side in [-1.0, 0.0, 1.0]:
				canvas.draw_line(at + Vector2(-s, 0 if kind != "wind" else side * s * 0.55), at + Vector2(s, side * s * 0.7), color, 3, true)
			if kind == "shout":
				canvas.draw_circle(at + Vector2(-s, 0), s * 0.35, color)
