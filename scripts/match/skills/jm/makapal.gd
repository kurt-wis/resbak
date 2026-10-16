extends Passive

## JM passive MAKAPAL! (docs/RESBAK.md § 4 JM, "Passive MAKAPAL!").
## JM starts each round with a guard. The first successful tag on JM only breaks it: no jail,
## no tagger stumble, no JM freeze (TagSystem reports a "guard_break" event and still counts the
## tag for sudden death, Impact and badges). After a break JM can't press Tag for 1.5 s
## (tag_block_ticks) and the guard returns 15 s after the break; if JM is jailed (or still frozen
## in a tag) when that time is up it returns the moment he is freed. A tag that lands while JM is
## capturing ignores the guard (and keeps it). The guard state is kept in jail and restored on
## round reset. A shield icon above JM shows the state to everyone (visual extras).

var guard := true
var regen_ticks := 0 ## ticks until the guard wants to return (0 = not regenerating)
var regen_pending := false ## the 15 s ran out while JM was not Free: restore when freed
var _icon: Sprite3D
var _icon_tex_on: ImageTexture
var _icon_tex_off: ImageTexture
var _icon_state := -1

func absorb_tag(tagger: Hero) -> bool:
	if not guard or hero.capturing:
		return false
	guard = false
	regen_pending = false
	regen_ticks = maxi(1, RB.ticks(v("makapal_regen_time")))
	hero.tag_block_ticks = maxi(hero.tag_block_ticks, RB.ticks(v("makapal_no_tag_time")))
	host.add_stat(tagger, "guard_breaks")
	if hero.visual:
		hero.visual.play_action("GuardBreak")
		Vfx.burst(host.world, hero.global_position + Vector3(0, 1.0, 0), Color("9fd8ff"), 18, 3.0, 0.5, 0.12)
	_refresh_icon()
	return true

func tick(_dt: float) -> void:
	if regen_ticks > 0:
		regen_ticks -= 1
		if regen_ticks == 0:
			if hero.is_free():
				_restore()
			else:
				regen_pending = true
	_refresh_icon()

func on_freed(_rescuer: Hero) -> void:
	if regen_pending:
		_restore()

func on_round_reset() -> void:
	guard = true
	regen_ticks = 0
	regen_pending = false
	_refresh_icon()

func _restore() -> void:
	guard = true
	regen_ticks = 0
	regen_pending = false
	_refresh_icon()

## HUD passive icon: JM guard on/off, fill = how far the guard has come back.
func hud_state() -> Dictionary:
	if guard:
		return {"fill": 1.0, "on": true, "note": ""}
	var total := float(RB.ticks(v("makapal_regen_time")))
	var left := float(regen_ticks)
	var fill := 1.0 if regen_pending else clampf(1.0 - left / maxf(total, 1.0), 0.0, 1.0)
	var note := "%.0f s" % ceilf(RB.seconds(regen_ticks)) if regen_ticks > 0 else ""
	return {"fill": fill, "on": false, "note": note}

# ---- presentation -----------------------------------------------------------------------
func _refresh_icon() -> void:
	if hero == null or hero.visual == null or hero.visual.extras == null:
		return
	if _icon == null:
		_icon_tex_on = _shield_texture(Color("7fd0ff"), Color("eaf8ff"))
		_icon_tex_off = _shield_texture(Color(0.45, 0.47, 0.52, 1.0), Color(0.7, 0.72, 0.76, 1.0))
		_icon = Sprite3D.new()
		_icon.name = "GuardIcon"
		_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_icon.no_depth_test = true
		_icon.pixel_size = 0.011
		_icon.position = Vector3(0, hero.data.model_height + 0.95, 0)
		hero.visual.extras.add_child(_icon)
	var st := 1 if guard else 0
	if st != _icon_state:
		_icon_state = st
		_icon.texture = _icon_tex_on if guard else _icon_tex_off
		_icon.modulate = Color.WHITE if guard else Color(1, 1, 1, 0.55)
	var shown := true
	if hero.visual.model:
		shown = hero.visual.model.visible
	_icon.visible = shown

## 48 x 48 heater-shield picture: rim colour round a lighter face, pixel-drawn so no font or
## texture file is needed.
static func _shield_texture(rim: Color, face: Color) -> ImageTexture:
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var u := (x + 0.5) / n * 2.0 - 1.0 # -1..1
			var w := (y + 0.5) / n # 0 top .. 1 bottom
			var half := 0.82 * (1.0 - pow(maxf(w - 0.45, 0.0) / 0.55, 1.6)) # wide top, tapering to a point
			var inside := absf(u) <= half and w > 0.04 and w < 0.97
			if not inside:
				continue
			var inner := absf(u) <= half * 0.62 and w > 0.14 and w < 0.88
			img.set_pixel(x, y, face if inner else rim)
	return ImageTexture.create_from_image(img)
