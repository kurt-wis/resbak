class_name IyakDecoy
extends SkillObject

## IYAK! decoy (docs/RESBAK.md § 4 Nene S1): a still copy of Nene that cries for 5 s. No
## collision; it is a tag candidate of Nene's team, so an enemy tag on it is a failed tag
## (TagSystem, via is_tag_decoy) and it stays. Shows on the enemy minimap as Nene: the HUD
## reads `minimap_as_hero`.

var minimap_as_hero: Hero ## the hero this marker should be drawn as (enemy minimap)
var model: Node3D
var tears: CPUParticles3D

func setup(p_host: MatchHost, p_owner: Hero, seconds: float = -1.0) -> void:
	super.setup(p_host, p_owner, seconds)
	is_tag_decoy = true
	decoy_radius = host.tuning.body_radius
	minimap_as_hero = p_owner
	name = "IyakDecoy"

func _ready() -> void:
	if owner_hero == null:
		return
	var outline: Material = owner_hero.visual.outline_mat if owner_hero.visual else null
	model = NeneModel.build(owner_hero.data, outline)
	if model == null:
		return
	add_child(model)
	NeneModel.face(model, owner_hero.facing)
	NeneModel.play(model, ["Iyak", "Idle"])
	tears = Vfx.emitter(self, Color(0.62, 0.84, 1.0, 0.9), 14, 0.7, 0.06, 1.2, Vector3(0, owner_hero.data.model_height * 0.82, 0), false)
	tears.emitting = true

func on_decoy_tagged(_tagger: Hero) -> void:
	Vfx.burst(host.world, global_position + Vector3(0, 1.0, 0), Color(1, 1, 1, 0.7), 8, 2.0, 0.3, 0.1)

func _on_expire() -> void:
	if host and host.world and is_inside_tree():
		Vfx.burst(host.world, global_position + Vector3(0, 0.9, 0), Color(0.62, 0.84, 1.0, 0.8), 14, 2.0, 0.5, 0.1)
