class_name HudBanner
extends HudPart

## Big centre banner (KABOOM!, TAKIPSILIM!, PANALO!/TALO!, pause) and the onboarding hint
## above the skills. Real-time timers; the banner pops in and fades out.

var banner: Label
var hint: Label
var _banner_until := 0.0
var _banner_start := 0.0
var _hint_until := 0.0

func _init() -> void:
	banner = HudStyle.label(self, 96, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, 14)
	hint = HudStyle.label(self, 30, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.GOLD, 10)

func _layout() -> void:
	var s := sz()
	banner.position = Vector2(0, s.y * 0.3)
	banner.size = Vector2(s.x, 150)
	banner.pivot_offset = banner.size * 0.5
	hint.position = Vector2(0, 236.0) # under the scorebug and capture alerts, clear of the skill bar
	hint.size = Vector2(s.x, 44)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func show_banner(text: String, color: Color, secs: float) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	_banner_start = _now()
	_banner_until = _banner_start + secs

func show_hint(text: String, secs: float) -> void:
	hint.text = text
	_hint_until = _now() + secs

func refresh(_delta: float) -> void:
	var t := _now()
	if banner.text != "":
		if t > _banner_until:
			banner.text = ""
		else:
			var pop := clampf((t - _banner_start) / 0.18, 0.0, 1.0)
			var sc := lerpf(1.45, 1.0, pop)
			banner.scale = Vector2(sc, sc)
			banner.modulate.a = clampf((_banner_until - t) / 0.3, 0.0, 1.0)
	if hint.text != "" and t > _hint_until:
		hint.text = ""
