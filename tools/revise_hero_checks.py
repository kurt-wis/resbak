from pathlib import Path
R=Path(__file__).resolve().parents[1]
p=R/'scripts/tests/suites/kit_inday.gd';s=p.read_text(encoding='utf-8')
a=s.index('\tawait _ihip_basics(t)');b=s.index('\tawait _hila_cast(t)',a);s=s[:a]+'\tawait _placed_wind(t)\n\tawait _wind_priority(t)\n'+s[b:]
s=s.replace('skills[0].cooldown == 15.0','skills[0].cooldown == 24.0').replace('IHIP! 15 s','IHIP! 24 s')
a=s.index('func _ihip_basics(');b=s.index('func _hila_cast(',a)
s=s[:a]+'''func _placed_wind(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var ally: Hero = host.heroes[3]
	var enemy: Hero = host.heroes[0]
	var inp := t.inputs(host)
	TestCtx.put(inday, -4, 0)
	TestCtx.put(ally, 2, 2.0)
	TestCtx.put(enemy, 0, 0.7)
	inp.aim_at(inday, Vector3(8, 0, 0))
	_cast(t, host, inday, 0)
	var skill := _ihip(inday)
	var lane: SkillObject = skill.last_lane
	var origin := lane.global_position
	t.check(skill.lane_active() and not skill.active and not skill.controls_movement(), "IHIP places an independent lane")
	t.check(t.near(skill.lane_length(), 12.0) and t.near(lane.width_m, 4.5), "approved 12 m by 4.5 m lane")
	t.check(skill.cd_ticks == RB.ticks(24.0) - 1, "24 s cooldown starts at placement")
	t.check(t.near(ally.biggest_bonus(), 0.4), "teammate receives +40% speed")
	t.check(t.near(enemy.strongest_slow(), 0.25) and t.near(inday.strongest_slow(), 0.25), "enemies and owner receive 25% slow")
	t.check(not inday.can_move() and inday.is_taggable(), "brief casting plant retains tag eligibility")
	inp.move(inday, Vector2(0, -1))
	inp.aim_at(inday, Vector3(-4, 0, 10))
	t.steps(host, 45)
	t.check(inday.global_position.distance_to(origin) > 0.2 and inday.can_press_tag(), "Inday moves and tags after the cast plant")
	t.check(lane.global_position.is_equal_approx(origin) and skill.lane_dir().dot(Vector3.RIGHT) > 0.99, "placed wind never follows owner or later aim")
	TestCtx.put(ally, 2, 2.4)
	t.steps(host, 1)
	t.check(t.near(ally.biggest_bonus(), 0.0), "bonus removed immediately on lane exit")
	TestCtx.put(enemy, 0, 2.4)
	t.steps(host, 1)
	t.check(t.near(enemy.strongest_slow(), 0.0) and not host.tag_system.wind_disadvantaged(enemy), "enemy exit removes slow and priority disadvantage")
	inday.on_tagged(enemy)
	t.steps(host, 1)
	t.check(skill.lane_active(), "placed wind persists after owner is tagged")
	t.steps(host, lane.ticks_left)
	t.check(not skill.lane_active(), "placed wind expires at its five-second lifetime")
	await t.free_match(host)
	# Obstacle clamp uses the fixed cast line.
	host = _live(t)
	inday = _inday(host)
	TestCtx.put(inday, -4, 0)
	_wall(host, Vector3(1, 1, 0), Vector3(0.2, 2, 8))
	t.inputs(host).aim_at(inday, Vector3(8, 0, 0))
	_cast(t, host, inday, 0)
	t.check(_ihip(inday).lane_length() < 5.1 and not _ihip(inday).in_lane(Vector3(2, 0, 0)), "solid wall clips the placed lane")
	await t.free_match(host)
	t.ok("placed wind: tuning, movement, lifetime, membership and wall clamp")

func _land_pair(host: MatchHost, a: Hero, b: Hero, simultaneous := true) -> Array:
	for h in [a, b]:
		h.tag_started_tick = host.tick - RB.ticks(host.tuning.tag_windup)
		h.windup_end_tick = host.tick
		h.strike_reach = h.tag_reach()
	a.lunge_dir = RB.flat(b.global_position - a.global_position).normalized()
	b.lunge_dir = -a.lunge_dir
	a.strike_target_slot = b.slot
	b.strike_target_slot = a.slot
	if not simultaneous:
		b.windup_end_tick += 1
	return host.tag_system.resolve()

func _wind_priority(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var ally: Hero = host.heroes[3]
	var enemy: Hero = host.heroes[0]
	TestCtx.put(inday, -4, 0)
	t.inputs(host).aim_at(inday, Vector3(8, 0, 0))
	_cast(t, host, inday, 0)
	TestCtx.put(ally, 1, 0)
	TestCtx.put(enemy, 2, 0)
	var results := _land_pair(host, ally, enemy)
	t.check(results.size() == 2 and results[0].type == "outprioritized" and results[1].type == "hit", "unaffected ally wins reciprocal same-tick tag against enemy in lane")
	TestCtx.put(inday, 1, 0)
	TestCtx.put(ally, -9, -10)
	results = _land_pair(host, inday, enemy)
	t.check(results.size() == 2 and results[0].type == "sabay" and results[1].type == "sabay", "two disadvantaged fighters retain Sabay")
	results = _land_pair(host, enemy, inday, false)
	t.check(results.size() == 1 and results[0].type == "hit", "earlier clean hit wins even for a disadvantaged fighter")
	TestCtx.put(inday, -4, -5)
	TestCtx.put(ally, 1, 3)
	TestCtx.put(enemy, 2, 3)
	results = _land_pair(host, ally, enemy)
	t.check(results.size() == 2 and results[0].type == "sabay" and results[1].type == "sabay", "two fighters outside wind retain Sabay")
	await t.free_match(host)
	t.ok("wind priority only breaks an otherwise simultaneous reciprocal tie")

'''+s[b:]
s=s.replace('t.check(inday.can_press_tag(), "HILA! does not stop her tagging")','t.check(not inday.can_press_tag(), "HILA briefly plants her during casting")')
p.write_text(s,encoding='utf-8')
p=R/'scripts/tests/suites/hero_assets.gd';s=p.read_text(encoding='utf-8').replace('"cd1": 15.0','"cd1": 24.0').replace('"Towel_Whip", 200','"Towel_Whip", 1500').replace('["Idle", "Walking", "Running", "BreakDance"]','["Idle", "Walking", "Running", "BreakDance", "Tag", "Cough"]');p.write_text(s,encoding='utf-8')
p=R/'scripts/tests/suites/kit_nene.gd';s=p.read_text(encoding='utf-8').replace('sk.sign_label != null and sk.sign_label.visible','sk.sign_label == null and nene.is_warded()').replace('not sk.sign_label.visible','sk.sign_label == null').replace('the BAWAL! sign hangs over her head','BAWAL uses body glow without a floating sign');p.write_text(s,encoding='utf-8')
print('Revised behavior checks')
