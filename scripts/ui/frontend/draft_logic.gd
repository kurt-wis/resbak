class_name DraftLogic
extends RefCounted

## Snake draft rules (docs/RESBAK.md § 6 "Roulette and draft"). Pure logic, no UI:
## order A1, B1, B2, A2, A3, B3, B4, A4, A5, B5 with A = Dilaw (team 0) and B = Lila;
## pick n belongs to panel slot n of its team (vs Bots: the player is Dilaw slot 1);
## 12 s per pick; timeout takes the hovered hero, else a random available one; bots lock
## a random available hero 2 s into their turn; no duplicate hero within a team (enemy
## picks are allowed). 5 heroes and 5 slots per team, so each team ends up with all five.

## [team, team_slot] per pick.
const ORDER := [[0, 0], [1, 0], [1, 1], [0, 1], [0, 2], [1, 2], [1, 3], [0, 3], [0, 4], [1, 4]]
const TURN_SECS := 12.0
const BOT_LOCK_SECS := 2.0
const HUMAN_TEAM := 0
const HUMAN_SLOT := 0

var picks: Array = [[], []] ## per team: hero ids in team_slot order
var turn := 0
var rng := RandomNumberGenerator.new()

func _init(seed_value := 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

func is_done() -> bool:
	return turn >= ORDER.size()

func team_now() -> int:
	return ORDER[turn][0]

func slot_now() -> int:
	return ORDER[turn][1]

func is_human_turn() -> bool:
	return not is_done() and team_now() == HUMAN_TEAM and slot_now() == HUMAN_SLOT

## Heroes this team can still take (roster order).
func available(team: int) -> Array:
	var out: Array = []
	for hid in HeroData.ORDER:
		if not (hid in picks[team]):
			out.append(hid)
	return out

func can_pick(hero_id: String) -> bool:
	return not is_done() and hero_id in available(team_now())

## Lock a hero for the current turn. Returns false if not allowed.
func pick(hero_id: String) -> bool:
	if not can_pick(hero_id):
		return false
	picks[team_now()].append(hero_id)
	turn += 1
	return true

## Timeout / bot choice: the hovered hero if still available, else random available.
func auto_pick(hovered := "") -> String:
	var pool := available(team_now())
	var choice: String = hovered if hovered in pool else pool[rng.randi() % pool.size()]
	pick(choice)
	return choice

## Session lineup: Dilaw 0-4 then Lila 0-4, the human on Dilaw slot 1.
func lineup(player_name: String) -> Array:
	var out: Array = []
	for team in range(2):
		for ts in range(picks[team].size()):
			var hid: String = picks[team][ts]
			var human: bool = team == HUMAN_TEAM and ts == HUMAN_SLOT
			var data := HeroData.load_hero(hid)
			out.append({"hero_id": hid, "team": team, "team_slot": ts, "is_bot": not human,
				"name": player_name if human else data.display_name + " (Bot)"})
	return out
