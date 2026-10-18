from pathlib import Path
R=Path(__file__).resolve().parents[1]
p=R/'scripts/tests/suites/kit_nathan.gd';s=p.read_text(encoding='utf-8');s=s.replace('\tpas.on_round_reset()\n\thost.clear_objects()\n\tfor s in n.skills:', '\tt.steps(host, n.cast_lock_ticks)\n\tpas.on_round_reset()\n\thost.clear_objects()\n\tfor s in n.skills:')
s=s.replace('\tt.steps(host, gap)\n\tinp.move(n, second)', '\tt.steps(host, maxi(gap, n.cast_lock_ticks))\n\tinp.move(n, second)')
s=s.replace('turn 5 ticks later drops a patch','turn after the cast plant drops a patch')
s=s.replace('\tt.steps(host, 4)\n\tinp.move(n, Vector2(-1, 0))', '\tt.steps(host, maxi(4, n.cast_lock_ticks))\n\tinp.move(n, Vector2(-1, 0))')
p.write_text(s,encoding='utf-8')
p=R/'scripts/tests/suites/kit_nene.gd';s=p.read_text(encoding='utf-8').replace('\tt.check(nene.is_warded(), "cast again")\n\t_press', '\tt.check(nene.is_warded(), "cast again")\n\tt.check(not nene.can_press_tag(), "ward cast briefly plants Nene")\n\tt.steps(host, nene.cast_lock_ticks)\n\t_press');p.write_text(s,encoding='utf-8')
p=R/'scripts/tests/suites/kit_jm.gd';s=p.read_text(encoding='utf-8').replace('\tsk.cd_ticks = 0','\tt.steps(host, jm.cast_lock_ticks)\n\tsk.cd_ticks = 0');p.write_text(s,encoding='utf-8')
for f,needles in [('scripts/match/skills/jm/makapal.gd',['Vfx.popup_text']),('scripts/match/skills/tutoy/lusot.gd',['Vfx.popup_text']),('scripts/match/skills/nathan/tira_patch.gd',['Vfx.popup_text']),('scripts/ui/hud/hud_powder.gd',['var caption :=','HudStyle.text(self, caption'])]:
    p=R/f;s=p.read_text(encoding='utf-8');s='\n'.join(line for line in s.splitlines() if not any(needle in line for needle in needles))+'\n';p.write_text(s,encoding='utf-8')
print('Recovery scenarios aligned')
