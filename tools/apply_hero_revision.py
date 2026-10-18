"""One-time source migration for the approved October hero revision."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def edit(path, before, after):
    p=ROOT/path
    s=p.read_text(encoding='utf-8')
    if before not in s: raise RuntimeError(f'Missing anchor: {path}: {before[:70]}')
    p.write_text(s.replace(before,after),encoding='utf-8')

edit('scripts/match/hero.gd','\tblind_ticks = 0','\tblind_ticks = 0\n\tcast_lock_ticks = 0\n\tcough_ticks = 0')
edit('data/heroes/jm.tres','"talbog_stun": 2.0,','"talbog_stun": 2.0,\n"talbog_recovery": 0.35,\n"tamaraw_recovery": 0.5,')
edit('scripts/match/skills/tutoy/harurot.gd',' and not (host.tick == cast_tick and hero.frame.skill_aimed)','')
edit('scripts/match/skill_aim.gd','Allies run faster in this lane / tap STOP','Place a fixed wind lane')
edit('scripts/match/input_frame.gd','var skill_aimed := false','var tag_preparing := false ## held preparation, permits normal locomotion\nvar skill_aimed := false')
edit('scripts/match/input_frame.gd','\tf.skill_aimed = skill_aimed','\tf.skill_aimed = skill_aimed\n\tf.tag_preparing = tag_preparing')
edit('scripts/match/player_input.gd','\tif _tag_release_pending:\n\t\tf.pressed','\tf.tag_preparing = tag_aiming and not tag_aim_cancelled\n\tif _tag_release_pending:\n\t\tf.pressed')
edit('scripts/match/hero.gd','\tif is_winding_up() and lunge_dir','\tif frame.tag_preparing and can_press_tag():\n\t\tfacing = host.tag_system.aim_direction(self)\n\t\treturn\n\tif is_winding_up() and lunge_dir')
edit('scripts/match/hero_visual.gd','const UPPER_ACTIONS := [','const UPPER_ACTIONS := [ "TagCharge", "Cough",')
edit('scripts/match/hero_visual.gd','\tif hila_pose_active():\n\t\treturn ["Sagip"','\tif h.frame.tag_preparing and h.can_press_tag():\n\t\treturn ["TagCharge", -1.0, -11]\n\tif h.cough_ticks > 0 and has_clip("Cough"):\n\t\treturn ["Cough", h.tuning.smoke_cough_animation, -12]\n\tif hila_pose_active():\n\t\treturn ["Sagip"')
edit('scripts/match/match_view.gd','\t\th.visual.set_view_alpha(alpha)','\t\tvar fade_step := delta / maxf(host.tuning.smoke_visibility_fade, 0.01)\n\t\th.visual.set_view_alpha(move_toward(h.visual._alpha, alpha, fade_step))')
edit('scripts/match/skills/nathan/ubo_cloud.gd','\t\t\tenemy.blind(blind_time)','\t\t\tenemy.blind(blind_time)\n\t\t\tenemy.cough_ticks = RB.ticks(host.tuning.smoke_cough_animation)')
edit('scripts/match/skills/nathan/ubo_cloud.gd','\t\t\t\tVfx.popup_text(e.visual.extras, e.global_position, "*UBO!*", PowderFx.PINK, 90, 0.9)','\t\t\t\te.cough_ticks = RB.ticks(host.tuning.smoke_cough_animation)')
p=ROOT/'scripts/match/skills/nathan/ubo_packet.gd';s=p.read_text(encoding='utf-8');a=s.index('static func _build_pouch()');b=s.index('## Where the packet',a)
s=s[:a]+'''static func _build_pouch() -> Node3D:
	var root := preload("res://assets/props/kimkim.glb").instantiate() as Node3D
	root.name = "Pouch"
	return root

'''+s[b:];s=s.replace('The mesh is procedural\n## (source_art/heroes/KimKim_Asset.glb is not importable): a small candy pouch with a label.','Uses the supplied KimKim model, normalized to a 25 cm held prop.');p.write_text(s,encoding='utf-8')
p=ROOT/'scripts/match/skills/nene/sigaw_word.gd';s=p.read_text(encoding='utf-8');a=s.index('\tlabel = Label3D.new()');b=s.index('\tfor i in range(3):',a);s=s[:a]+s[b:];p.write_text(s,encoding='utf-8')
p=ROOT/'scripts/match/skills/nene/bawal.gd';s=p.read_text(encoding='utf-8');a=s.index('func _show_sign(');b=s.index('func hud_note()',a);s=s[:a]+'''func _show_sign(_on: bool) -> void:
	# HeroVisual reads warded() and applies a red glow to the skinned body.
	pass

'''+s[b:];p.write_text(s,encoding='utf-8')
for f in ['character_toon.gdshader','character_toon_fade.gdshader']:
    p=ROOT/'shaders'/f;s=p.read_text(encoding='utf-8');s=s.replace('void fragment() {','uniform float ward_strength : hint_range(0.0, 1.0) = 0.0;\n\nvoid fragment() {');idx=s.index('\n}',s.index('void fragment()'))
    s=s[:idx]+'''\n	float ward_rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 1.8);
	ALBEDO = mix(ALBEDO, vec3(0.95, 0.035, 0.055), ward_strength * 0.35);
	EMISSION += vec3(1.0, 0.025, 0.04) * ward_strength * (0.25 + ward_rim * 1.5);
'''+s[idx:];p.write_text(s,encoding='utf-8')
edit('scripts/match/hero_visual.gd','\t_update_sabay_fall()','\tvar ward := 1.0 if hero.is_warded() else 0.0\n\tfor entry in _opaque + _faded:\n\t\t(entry[2] as ShaderMaterial).set_shader_parameter("ward_strength", ward)\n\t_update_sabay_fall()')
edit('scripts/match/hero_accents.gd','\t\tif towel_player and hero.visual.tag_pose_active():','\t\tif towel_player and not hero.visual.tag_pose_active():\n\t\t\ttowel_player.seek(0.0, true)\n\t\tif towel_player and hero.visual.tag_pose_active():')
edit('scripts/ui/hud/hud_minimap.gd','else sz().y - margin - h # top: under the face row','else sz().y - margin - h - 236.0 # reserve the feed below')
edit('scripts/ui/hud/hud_minimap.gd','\trect = Rect2(sz().x','\tif hud.touch and hud.touch.visible:\n\t\ty = 132.0 # keep the combined map/feed stack clear of large action controls\n\trect = Rect2(sz().x')
edit('scripts/ui/hud/hud_feed.gd','\t\tvar w := HudStyle.text_width(l.text, FONT) + 40.0\n\t\tvar r := Rect2(MARGIN, TOP + i * (LINE_H + 6.0), w, LINE_H)','\t\tvar map_rect := hud.minimap.rect\n\t\tvar w := maxf(map_rect.size.x, 350.0)\n\t\tvar r := Rect2(sz().x - MARGIN - w, map_rect.end.y + 14.0 + i * (LINE_H + 6.0), w, LINE_H)')
edit('scripts/ui/hud/hud_feed.gd','HORIZONTAL_ALIGNMENT_LEFT, -1, 6 if a > 0.5 else 0)','HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0, 6 if a > 0.5 else 0)')
print('Applied source revision')
