class_name RB
extends RefCounted

## Shared match constants: teams, physics layers, input bits, skill kinds.
## Tuning numbers do NOT live here; they live in data/tuning.tres (Tuning) and
## data/heroes/*.tres (HeroData), per docs/RESBAK.md § 1 ("named constants in tuning.tres
## or HeroData .tres, never hard-coded").

const TICK_RATE := 60

# Teams. Dilaw (yellow) plays on the left (-X) for everyone, Lila (purple) on the right.
const DILAW := 0
const LILA := 1
const TEAM_NAMES := ["Dilaw", "Lila"]
const TEAM_FULL_NAMES := ["Purok Dilaw", "Purok Lila"]
const TEAM_COLORS := [Color("f5c518"), Color("9b59d6")]

# Physics layers (bit values). Map statics from barangay_court.tscn sit on layer 1.
const L_WORLD := 1 ## layer 1: walls, floor, props, stage
const L_HERO := 2 ## layer 2: free heroes, solid to each other (body blocking)
const L_GHOST := 4 ## layer 3: heroes that pass through players (Tagged, Jailed, Chained, EP)
const L_SKILL_WALL := 8 ## layer 4: TALBOG! earth walls, solid for everyone
const L_VAULTABLE := 16 ## layer 5: props LUSOT! can vault (solid otherwise)
const L_POLE := 32 ## layer 6: active base poles (solid)
const MASK_MOVE := L_WORLD | L_SKILL_WALL | L_VAULTABLE | L_POLE ## what every hero collides with
const MASK_LOS := L_WORLD | L_SKILL_WALL | L_VAULTABLE ## what blocks skills' line of sight

# Input buttons (InputFrame.held / InputFrame.pressed bit masks).
const BTN_TAG := 1
const BTN_SKILL1 := 2
const BTN_SKILL2 := 4
const BTN_INTERACT := 8
const BTN_PING := 16

# Skill kinds (spec § 4 "Types"). EP ends early on an Offensive or Movement skill.
enum SkillKind { OFFENSIVE, MOVEMENT, NEITHER }

static func ticks(seconds: float) -> int:
	return int(round(seconds * TICK_RATE))

static func seconds(tick_count: int) -> float:
	return float(tick_count) / TICK_RATE

static func other_team(team: int) -> int:
	return LILA if team == DILAW else DILAW

## Flat (XZ) distance between two world points.
static func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
