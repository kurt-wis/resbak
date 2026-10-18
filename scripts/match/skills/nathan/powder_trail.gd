class_name PowderTrail
extends SkillObject

## BUGA! powder trail (docs/RESBAK.md § 4 Nathan): follows the hit enemy for 4 s, a drifting
## pink trail everyone can see. The "Nathan's team sees them everywhere" part is the reveal
## (Hero.reveal_to), set by Buga; this object is the visible side and ends early if the
## target is tagged. Hitting the same enemy again refreshes it instead of stacking.

var target: Hero
var emitter: CPUParticles3D
var ring: Node3D

func begin(p_host: MatchHost, p_owner: Hero, p_target: Hero, seconds: float) -> void:
	setup(p_host, p_owner, seconds)
	name = "PowderTrail"
	target = p_target

## Call after host.spawn_object(): builds the particles at the target's feet.
func build_visuals() -> void:
	emitter = Vfx.emitter(self, PowderFx.PINK, 48, 1.4, 0.32, 0.5, Vector3(0, 0.35, 0), true)
	emitter.gravity = Vector3(0, 0.15, 0)
	emitter.emitting = true
	ring = Vfx.ground_ring(self, global_position, 0.55, Color(PowderFx.PINK.r, PowderFx.PINK.g, PowderFx.PINK.b, 0.55), 0.14)

func refresh(seconds: float) -> void:
	ticks_left = maxi(ticks_left, RB.ticks(seconds))

func tick(dt: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_free():
		expire()
		return
	global_position = target.global_position
	if ring:
		ring.global_position = target.global_position + Vector3(0, 0.06, 0)
	super.tick(dt)
	if ticks_left > 0 and ticks_left < 20 and emitter:
		emitter.emitting = false
