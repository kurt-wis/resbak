class_name DireDiretsoComponent
extends Node

## Momentum Acceleration Engine for Batang Hamog.
## +5% per stack every 1.5s up to 4 stacks (+20%). Resets on stop,
## 180 reversal, tag attempt, enemy skill hit. Disabled while carrying flag.

@export var base_run_speed: float = 5.0
@export var stack_interval: float = 1.5
@export var max_stacks: int = 4
@export var bonus_per_stack: float = 0.05

var momentum_stacks: int = 0
var stack_timer: float = 0.0
var prev_forward: Vector3 = Vector3.ZERO
var is_carrying_flag: bool = false

func reset_momentum() -> void:
	momentum_stacks = 0
	stack_timer = 0.0

func force_flag_carry(flag: bool) -> void:
	is_carrying_flag = flag
	if flag:
		reset_momentum()

func on_tag_attempt() -> void:
	reset_momentum()
	prev_forward = Vector3.ZERO

func on_hit_by_skill() -> void:
	reset_momentum()
	prev_forward = Vector3.ZERO

func speed_bonus() -> float:
	return 1.0 + float(momentum_stacks) * bonus_per_stack

func update_momentum(delta: float, horiz_vel: Vector3) -> void:
	if is_carrying_flag:
		reset_momentum()
		return
	var speed := horiz_vel.length()
	if speed < base_run_speed * 0.95:
		reset_momentum()
		if speed > 0.1:
			prev_forward = horiz_vel.normalized()
		else:
			prev_forward = Vector3.ZERO
		return
	var cur_dir := horiz_vel.normalized()
	if prev_forward.length() > 0.1:
		if cur_dir.dot(prev_forward) < -0.5:
			reset_momentum()
			prev_forward = cur_dir
			return
	prev_forward = cur_dir
	stack_timer += delta
	while stack_timer >= stack_interval and momentum_stacks < max_stacks:
		stack_timer -= stack_interval
		momentum_stacks = mini(momentum_stacks + 1, max_stacks)
	if momentum_stacks >= max_stacks:
		stack_timer = 0.0
