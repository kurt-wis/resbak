class_name UboPacket
extends SkillObject

## The Kimkim packet in flight (UBO! UBO!, docs/RESBAK.md § 4 Nathan). Flies a short arc to a
## fixed landing point and turns into a UboCloud on the landing tick. Uses the supplied KimKim model, normalized to a 25 cm held prop.

var from_pos := Vector3.ZERO
var to_pos := Vector3.ZERO
var flight_ticks := 30
var start_tick := 0
var cloud_cfg := {}
var pouch: Node3D

func begin(p_host: MatchHost, p_owner: Hero, p_from: Vector3, p_to: Vector3, p_flight_ticks: int, p_cfg: Dictionary) -> void:
	setup(p_host, p_owner, -1.0)
	name = "UboPacket"
	from_pos = p_from
	to_pos = p_to
	flight_ticks = maxi(1, p_flight_ticks)
	start_tick = p_host.tick
	cloud_cfg = p_cfg
	pouch = _build_pouch()
	add_child(pouch)

static func _build_pouch() -> Node3D:
	var root := preload("res://assets/props/kimkim.glb").instantiate() as Node3D
	root.name = "Pouch"
	return root

## Where the packet is at progress t (0..1): straight line on the ground, parabolic arc up.
func arc_position(t: float) -> Vector3:
	return sample_arc(from_pos, to_pos, t)

static func sample_arc(from: Vector3, to: Vector3, t: float) -> Vector3:
	var p := from.lerp(to, t)
	p.y += 4.0 * 1.4 * t * (1.0 - t)
	return p

func tick(_dt: float) -> void:
	var n := host.tick - start_tick
	var t := clampf(float(n) / flight_ticks, 0.0, 1.0)
	global_position = arc_position(t)
	if pouch:
		pouch.rotation = Vector3(t * TAU * 1.5, t * TAU, 0.0)
	if n >= flight_ticks:
		_land()

func _land() -> void:
	if expired:
		return
	var cloud := UboCloud.new()
	cloud.begin(host, owner_hero, cloud_cfg)
	host.spawn_object(cloud, to_pos)
	cloud.apply_initial_burst()
	cloud.build_visuals()
	host.emit_event("ubo_land", {"hero": owner_hero, "pos": to_pos, "cloud": cloud})
	expire()
