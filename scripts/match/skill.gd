class_name Skill
extends Node

## Base for every active skill (S1 / S2). One instance per hero per slot, child of the Hero.
## The host calls the hooks below in tick order (docs/RESBAK.md § 12 "Tick order"):
##   step 2 (actions):  try_cast() on a fresh press, on_recast() if pressed again while active,
##                      tick_action() every tick while active
##   step 3 (movement): move() instead of normal movement while controls_movement() is true,
##                      then tick() every tick (active or not)
## Rules every skill shares (spec § 4 "Roster rules"): no casting in countdown, Tagged,
## Jailed, Chained, capturing, stumble or stun; the cooldown starts on cast; aim past range
## = max range; on the caster's tag, ongoing effects listed in the spec end (end("tagged")),
## while placed objects (walls, decoys, clouds, patches) last their full time.

var hero: Hero
var host: MatchHost
var slot := 0 ## 0 = S1, 1 = S2
var cooldown := 10.0 ## seconds, from HeroData
var cd_ticks := 0 ## ticks until ready
var active := false
var cast_tick := -1 ## host tick of the last cast

## Spec type: RB.SkillKind.OFFENSIVE / MOVEMENT / NEITHER. EP ends early on Offensive or Movement.
func kind() -> int:
	return RB.SkillKind.NEITHER

func skill_name() -> String:
	if hero == null or hero.data == null:
		return name
	return hero.data.skill1_name if slot == 0 else hero.data.skill2_name

## Shortcut to this hero's HeroData values.
func v(key: String, fallback: Variant = null) -> Variant:
	return hero.data.v(key, fallback)

func is_ready() -> bool:
	return cd_ticks <= 0

func cd_fraction() -> float:
	var total := RB.ticks(cooldown)
	return 0.0 if total <= 0 else clampf(float(cd_ticks) / total, 0.0, 1.0)

func can_cast() -> bool:
	return host != null and host.skills_enabled() and hero.can_use_skills() and is_ready() and not active and _can_cast_extra()

## Called by the host on a press. Starts the cooldown, tells the hero (EP / passives end
## early as the spec says), then runs the skill. Returns true if it cast.
func try_cast(frame: InputFrame) -> bool:
	if not can_cast():
		return false
	cd_ticks = RB.ticks(cooldown)
	cast_tick = host.tick
	hero.notify_skill_cast(self)
	_cast(frame)
	host.emit_event("skill_cast", {"hero": hero, "slot": slot, "skill": skill_name()})
	return true

# ---- override these -------------------------------------------------------------------

## Extra cast conditions (e.g. LUSOT! needs ground). Base rules are already checked.
func _can_cast_extra() -> bool:
	return true

## The cast itself. Set `active = true` for skills with a duration.
func _cast(_frame: InputFrame) -> void:
	pass

## The key was pressed again while active (TAMARAW!!! and IHIP! end on it).
func on_recast(_frame: InputFrame) -> void:
	pass

## Every tick while active, in the actions step (aim tracking, channel checks).
func tick_action(_frame: InputFrame) -> void:
	pass

## True while this skill drives the hero's movement (dashes, jumps, charges, channels).
func controls_movement() -> bool:
	return false

## Move the hero this tick (only called while controls_movement()). Use hero.move_body().
func move(_dt: float) -> void:
	pass

## Every tick after movement, active or not (timers, effects, objects).
func tick(_dt: float) -> void:
	pass

## Stop an ongoing effect. reason: "tagged", "recast", "expired", "pushed", "stunned",
## "round_end", "reset", "capture". Must be safe to call when not active.
func end(_reason: String) -> void:
	active = false

## Things that happened to the owner: "tag_pressed", "skill_cast" (data = the other Skill),
## "capture_start", "rescue" (data = Array of freed heroes), "pushed" and "stunned"
## (data = by_enemy_skill). E.g. BAWAL!'s sign drops on tag_pressed / capture_start; the old
## IYAK! see-through ended on tag_pressed / skill_cast /
## capture_start / rescue; IHIP! ends on pushed / stunned.
func on_owner_event(_event: String, _data: Variant) -> void:
	pass

## While true the hero can't press Tag (TAMARAW!!!, TALBOG! airborne, IHIP!).
func blocks_tagging() -> bool:
	return false

## While true the hero can't cast its other skill (IHIP!).
func blocks_other_skills() -> bool:
	return false

## While false pushes are ignored (TALBOG! airborne).
func can_be_pushed() -> bool:
	return true

## While true the hero is not affected by slows' speed part (no skill uses this yet).
func ignores_slows() -> bool:
	return false

## Fixed speed while active (HARUROT!, TAMARAW!!! = 9 m/s: no bonus, slows still apply), or -1.
func fixed_speed() -> float:
	return -1.0

## Tag landing hook, asked for every enemy tag landing this tick (LUSOT! perfect slide).
## Return true to make that tag miss entirely; the TagSystem then stuns the tagger
## (perfect_stun seconds from the evading skill) instead of the failed-tag stumble.
func evade_tag(_tagger: Hero, _lunge_dir: Vector3) -> bool:
	return false

## Rescue by skill (HILA!): a world point that counts as this hero's touch for a chain tip
## (within rescue_touch_radius() plus the normal rescue touch), or Vector3.INF for none.
## The JailSystem checks it in step 6, after touch rescues.
func rescue_touch_point() -> Vector3:
	return Vector3.INF

func rescue_touch_radius() -> float:
	return 0.0

## An enemy tag landed on this hero (step 7). Return true to cancel it: no tag, no stats
## (BAWAL! curses the tagger instead). Asked before the passive's absorb_tag.
func absorb_tag(_tagger: Hero) -> bool:
	return false

## While true this hero shows a "don't hit me" warning (BAWAL!); bots think twice.
func warded() -> bool:
	return false

## Seconds the tagger is stunned after evade_tag() returned true.
func evade_stun_seconds() -> float:
	return 0.0

## Round reset: end effects, clear cooldown (the host resets cd_ticks after this).
func on_round_reset() -> void:
	end("reset")

## For the HUD: extra state text such as "1.2 s" while channelling; "" for none.
func hud_note() -> String:
	return ""
