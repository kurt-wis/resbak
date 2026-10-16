class_name Hud
extends CanvasLayer

## Match HUD (docs/RESBAK.md § 7, strings § 13), built in code for 1920x1080 (canvas_items
## stretch scales it; text is sans-serif and at least 18 px). Presentation only: it reads the
## host, the local hero and the MatchView, and never changes game state.
## Parts (scripts/ui/hud/hud_*.gd): sinking-sun timer + scores + point dots, prisoner tracker,
## minimap, tag feed, S1/S2 + passive, danger border, off-screen arrows, capture rings, jail
## prompt, countdown and between-rounds sequence, scoreboard (hold Tab), banners, and the
## Escape overlay. F10 hides everything but the overlay.

signal resume_requested
signal leave_requested

var host: MatchHost
var local: Hero
var view: MatchView
var input_source: Object ## PlayerInput (reads last_device_gamepad for key labels), optional

var root: Control ## everything F10 hides
var overlay: Control ## pause overlay, always available
var timer: HudTimer
var tracker: HudTracker
var minimap: HudMinimap
var feed: HudFeed
var skills: HudSkills
var danger: HudDanger
var arrows: HudArrows
var rings: HudCaptureRings
var jail: HudJail
var round_ui: HudRound
var banner_part: HudBanner
var scoreboard: HudScoreboard
var pause: HudPause

# Convenience handles kept from the first HUD.
var timer_label: Label
var banner: Label

# Settings cache (Save > Gameplay / Accessibility), refreshed about once a second.
var relative_colours := false
var danger_enabled := true
var feed_visible := true
var minimap_visible := true
var minimap_size := "M"
var minimap_position := "top_right"
var reduce_flashing := false

var force_scoreboard := false ## tests hold the scoreboard without an input event
var _parts: Array[HudPart] = []
var _settings_age := 999
var _hint_shown := false

func setup(p_host: MatchHost, p_local: Hero, p_view: MatchView) -> void:
	host = p_host
	local = p_local
	view = p_view
	layer = 10
	_refresh_settings()
	root = _full_control("HudRoot")
	add_child(root)
	overlay = _full_control("Overlay")
	add_child(overlay)
	danger = _add(HudDanger.new(), root) as HudDanger
	rings = _add(HudCaptureRings.new(), root) as HudCaptureRings
	arrows = _add(HudArrows.new(), root) as HudArrows
	timer = _add(HudTimer.new(), root) as HudTimer
	tracker = _add(HudTracker.new(), root) as HudTracker
	minimap = _add(HudMinimap.new(), root) as HudMinimap
	feed = _add(HudFeed.new(), root) as HudFeed
	skills = _add(HudSkills.new(), root) as HudSkills
	jail = _add(HudJail.new(), root) as HudJail
	round_ui = _add(HudRound.new(), root) as HudRound
	banner_part = _add(HudBanner.new(), root) as HudBanner
	scoreboard = _add(HudScoreboard.new(), root) as HudScoreboard
	pause = _add(HudPause.new(), overlay) as HudPause
	timer_label = timer.timer_label
	banner = banner_part.banner
	host.event.connect(_on_event)

func _full_control(node_name: String) -> Control:
	var c := Control.new()
	c.name = node_name
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _add(part: HudPart, parent: Control) -> HudPart:
	part.bind(self)
	parent.add_child(part)
	_parts.append(part)
	return part

# ---- helpers the parts use ------------------------------------------------------------------
## The team drawn on the left of the score, tracker and scoreboard (own team).
func left_team() -> int:
	return local.team if local else RB.DILAW

## Team colour; Settings > Gameplay > Team colours "Relative" shows own yellow, enemy purple.
func team_color(team: int) -> Color:
	if relative_colours and local:
		return RB.TEAM_COLORS[RB.DILAW if team == local.team else RB.LILA]
	return RB.TEAM_COLORS[team]

func use_gamepad() -> bool:
	return input_source != null and bool(input_source.get("last_device_gamepad"))

## Label of a bound action for the last-used device.
func key_label(action: String) -> String:
	return Controls.label(action, use_gamepad())

func _refresh_settings() -> void:
	_settings_age = 0
	var save := get_node_or_null("/root/Save") if is_inside_tree() else null
	if save == null:
		return
	relative_colours = str(save.get_setting("gameplay", "team_colours")) == "relative"
	danger_enabled = bool(save.get_setting("gameplay", "danger_border"))
	feed_visible = bool(save.get_setting("gameplay", "tag_feed"))
	var size_key := str(save.get_setting("gameplay", "minimap_size"))
	var pos := str(save.get_setting("gameplay", "minimap_position"))
	var changed := size_key != minimap_size or pos != minimap_position
	minimap_size = size_key
	minimap_position = pos
	if changed and minimap:
		minimap.apply_layout()
	reduce_flashing = bool(save.get_setting("accessibility", "reduce_flashing"))

# ---- public API -----------------------------------------------------------------------------
func show_banner(text: String, color: Color = Color.WHITE, secs := 2.0) -> void:
	if banner_part:
		banner_part.show_banner(text, color, secs)

func set_pause_open(on: bool) -> void:
	if pause:
		pause.open(on)

func is_pause_open() -> bool:
	return pause != null and pause.is_open()

## F10: hide or show the whole HUD (clean camera). The pause overlay stays.
func toggle_hidden() -> void:
	if root:
		root.visible = not root.visible

func is_hidden() -> bool:
	return root != null and not root.visible

# ---- frame ----------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if host == null or root == null:
		return
	_settings_age += 1
	if _settings_age > 60:
		_refresh_settings()
	if InputMap.has_action("hide_hud") and Input.is_action_just_pressed("hide_hud"):
		toggle_hidden()
	scoreboard.held = force_scoreboard or (InputMap.has_action("scoreboard") and Input.is_action_pressed("scoreboard"))
	for p in _parts:
		p.refresh(delta)

func _on_event(kind: String, d: Dictionary) -> void:
	for p in _parts:
		p.on_event(kind, d)
	match kind:
		"kaboom":
			show_banner("KABOOM!", HudStyle.GOLD, 1.2)
		"sudden_death":
			show_banner("TAKIPSILIM!", HudStyle.RED, 2.0)
		"match_end":
			var won: bool = local != null and int(d.winner) == local.team
			show_banner("PANALO!" if won else "TALO!", team_color(int(d.winner)), 4.0)
		"jailed":
			_onboarding_hint(d.hero)

## Onboarding hint (first 5 completed matches): the first time a teammate is jailed, 4 s
## above the skills, no pause.
func _onboarding_hint(h: Hero) -> void:
	if _hint_shown or local == null or h.team != local.team or h == local:
		return
	var save := get_node_or_null("/root/Save") if is_inside_tree() else null
	if save == null or int(save.get_profile().get("matches_played", 0)) >= 5:
		return
	_hint_shown = true
	banner_part.show_hint("Resbak! Hawakan ang dulo ng kadena.", 4.0)
