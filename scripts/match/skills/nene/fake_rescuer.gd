class_name NeneFakeRescuer
extends SkillObject

## SUMBONG KITA! fake rescuer (docs/RESBAK.md § 4 Nene S2): a copy of Nene that runs from the
## cast point toward the chain tip (no chain: the jail marker) at 5 m/s for 3 s, then
## vanishes. No collision, no rescue (the JailSystem never sees it), no shadow. It is a tag
## candidate of Nene's team, so tagging it is a failed tag. The target is re-read every tick,
## so it follows a chain that grows, moves or is let go.

var speed := 5.0
var model: Node3D

func setup(p_host: MatchHost, p_owner: Hero, seconds: float = -1.0) -> void:
	super.setup(p_host, p_owner, seconds)
	is_tag_decoy = true
	decoy_radius = host.tuning.body_radius
	speed = float(p_owner.data.v("sumbong_fake_speed"))
	name = "NeneFakeRescuer"

func _ready() -> void:
	if owner_hero == null:
		return
	var outline: Material = owner_hero.visual.outline_mat if owner_hero.visual else null
	model = NeneModel.build(owner_hero.data, outline, false)
	if model == null:
		return
	add_child(model)
	NeneModel.play(model, ["Running", "Walking", "Idle"])

## Where the fake is running to: the tip of the chain in the jail holding Nene's team, else
## that jail's marker.
func target_point() -> Vector3:
	var jail_owner := RB.other_team(team)
	var p := host.jail_system.rescue_point(jail_owner)
	if p == Vector3.INF:
		p = host.layout.marker(jail_owner)
	return RB.flat(p) + Vector3(0, global_position.y, 0)

func tick(dt: float) -> void:
	var to := target_point() - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.05:
		var step := minf(speed * dt, dist)
		global_position += to / dist * step
		NeneModel.face(model, to)
	super.tick(dt)
