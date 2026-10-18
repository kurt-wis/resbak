# Graph Report - resbak  (2026-10-19)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 366 nodes · 784 edges · 31 communities (16 shown, 15 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 14 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c7ff3e67`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- os
- build_heroes.py
- numpy
- build_home_props.py
- math
- build_jm_botsog.py
- build_sand_castle.py
- CLAUDE.md
- make_home_ground.py
- Batang Hamog
- make_home_ui.py
- Skin
- Home Diorama Plan
- Inday
- Plan: Konstruksyon overhaul, remaining work (2026-10-17)
- Konstruksyon Remaining Report
- Meshy Godot Plugin README
- Audio Credits
- Lola Bystander
- Manong Bystander
- Student Bystander
- Wall decal generation prompts
- Luckiest Guy License
- Architecture
- Base Freshness Priority Engine
- Status
- renders/ README
- scripts/map_pipeline/ README
- Shared Tag Charge Mocap

## God Nodes (most connected - your core abstractions)
1. `log()` - 19 edges
2. `fin()` - 17 edges
3. `build()` - 16 edges
4. `prim()` - 15 edges
5. `offsets_from_rig()` - 15 edges
6. `fresh()` - 14 edges
7. `hexc()` - 14 edges
8. `mat()` - 14 edges
9. `deselect_all()` - 14 edges
10. `log()` - 13 edges

## Surprising Connections (you probably didn't know these)
- `integration_test.gd` --references--> `hero_visual.gd`  [INFERRED]
  scripts/tests/README.md → docs/plans/2026-10-17-konstruksyon-remaining.md
- `Plan: Konstruksyon overhaul, remaining work (2026-10-17)` --references--> `integration_test.gd`  [EXTRACTED]
  docs/plans/2026-10-17-konstruksyon-remaining.md → scripts/tests/README.md
- `breakdance()` --calls--> `loop_blend()`  [EXTRACTED]
  tools/build_heroes.py → tools/retarget_clip.py
- `breakdance()` --calls--> `mocap_offsets()`  [EXTRACTED]
  tools/build_heroes.py → tools/retarget_clip.py
- `chained()` --calls--> `face_front()`  [EXTRACTED]
  tools/build_heroes.py → tools/retarget_clip.py

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Design Documentation Flow** — docs_readme, docs_resbak_md, docs_status_md, docs_decisions [EXTRACTED 1.00]
- **Hero Animation Pipeline** — meshy_api, tools_build_heroes, tools_qc_asset, tag_charge_animation [EXTRACTED 1.00]
- **Core Hero Roster** — docs_archive_characters_03_batang_hamog_batang_hamog, docs_archive_characters_04_nathan_nathan, docs_archive_characters_05_inday_inday [EXTRACTED 1.00]
- **Home Diorama Assets** — assets_props_vehicles_jeepney, assets_characters_bystanders_tindera, assets_characters_bystanders_lola, assets_characters_bystanders_manong, assets_characters_bystanders_student [EXTRACTED 1.00]
- **Character Design Evolution** — docs_archive_resbak, docs_archive_characters_01_jm_botsog, docs_archive_characters_02_nene, docs_glossary [INFERRED 0.80]
- **Integration Gate Flow** — scripts_tests_integration_test, docs_plans_2026_10_17_konstruksyon_remaining, renders_readme [INFERRED 0.85]
- **Agawan Base Core Systems** — docs_archive_gameplay_agawan_base_rules_freshness_engine, docs_archive_gameplay_agawan_base_rules_agawan_base, docs_archive_characters_05_inday_sagip [INFERRED 0.90]

## Communities (31 total, 15 thin omitted)

### Community 0 - "os"
Cohesion: 0.07
Nodes (28): build(), build(), log(), main(), measure(), pose_at(), tris(), main() (+20 more)

### Community 1 - "build_heroes.py"
Cohesion: 0.08
Nodes (30): TagCharge Animation, bake(), bake_grounded(), bake_on_floor(), bake_planted(), _blend_frame(), breakdance(), build() (+22 more)

### Community 2 - "numpy"
Cohesion: 0.12
Nodes (31): arc_d(), atlas(), blank(), build(), cell_grid(), cov(), ell_d(), ell_k() (+23 more)

### Community 3 - "build_home_props.py"
Cohesion: 0.14
Nodes (26): bounds(), build_backpack(), build_bench(), build_bottle_crate(), build_meshy(), build_palamig_bag(), build_paper_fan(), build_payong() (+18 more)

### Community 4 - "math"
Cohesion: 0.08
Nodes (21): retarget_table(), discard(), face_front(), _heading(), _import(), in_place(), _interp(), is_meshy_rig() (+13 more)

### Community 5 - "build_jm_botsog.py"
Cohesion: 0.18
Nodes (26): add_chalk_to_mat(), bmesh_scale_lower_cheeks(), build(), clear_scene(), create_prim(), deselect_all(), do_render(), hex_to_rgb() (+18 more)

### Community 6 - "build_sand_castle.py"
Cohesion: 0.25
Nodes (10): box(), build(), cone(), cyl(), export(), finish(), log(), material() (+2 more)

### Community 7 - "CLAUDE.md"
Cohesion: 0.15
Nodes (13): Agawan Base, architecture.md, Character Dossier: JM (Botsog), Character Dossier: Nene, Archive README, RESBAK Design Specification (Legacy), Decision log, Glossary (+5 more)

### Community 8 - "make_home_ground.py"
Cohesion: 0.35
Nodes (8): facade(), ground_concrete(), crack(), ground_dirt(), main(), periodic_noise(), shade(), wrap_draw()

### Community 9 - "Batang Hamog"
Cohesion: 0.20
Nodes (10): Batang Hamog, DIRE-DIRETSO, HARUROT!, LUSOT!, BUGA!, MAY TIRA PA!, Nathan, UBO! UBO! (+2 more)

### Community 10 - "make_home_ui.py"
Cohesion: 0.48
Nodes (4): cardboard(), main(), tape(), value_noise()

### Community 12 - "Home Diorama Plan"
Cohesion: 0.40
Nodes (5): Tindera Bystander, Jeepney Asset, Home Diorama Plan, Home Test Suite, Hero Picker UI

### Community 13 - "Inday"
Cohesion: 0.40
Nodes (5): IHIP!, Inday, SAGIP!, TAKBO NA!, Agawan Base Rules

### Community 14 - "Plan: Konstruksyon overhaul, remaining work (2026-10-17)"
Cohesion: 0.50
Nodes (5): Plan: Konstruksyon overhaul, remaining work (2026-10-17), Jail Chain Presentation, Meshy MCP Server / API, hero_visual.gd, integration_test.gd

### Community 15 - "Konstruksyon Remaining Report"
Cohesion: 0.50
Nodes (4): Konstruksyon Remaining Report, Audio Autoload, match_view.gd, vfx.gd

### Community 16 - "Meshy Godot Plugin README"
Cohesion: 0.67
Nodes (3): Meshy Godot Plugin README, Godot Engine, Meshy.ai

## Knowledge Gaps
- **36 isolated node(s):** `TagCharge Animation`, `Tindera Bystander`, `Jeepney Asset`, `Home Test Suite`, `Hero Picker UI` (+31 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 129 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `batang_hamog.glb` connect `Batang Hamog` to `build_heroes.py`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **What connects `TagCharge Animation`, `Tindera Bystander`, `Jeepney Asset` to the rest of the system?**
  _36 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `os` be split into smaller, more focused modules?**
  _Cohesion score 0.06778476589797344 - nodes in this community are weakly interconnected._
- **Should `build_heroes.py` be split into smaller, more focused modules?**
  _Cohesion score 0.07653061224489796 - nodes in this community are weakly interconnected._
- **Should `numpy` be split into smaller, more focused modules?**
  _Cohesion score 0.11627906976744186 - nodes in this community are weakly interconnected._
- **Should `build_home_props.py` be split into smaller, more focused modules?**
  _Cohesion score 0.13588850174216027 - nodes in this community are weakly interconnected._
- **Should `math` be split into smaller, more focused modules?**
  _Cohesion score 0.08205128205128205 - nodes in this community are weakly interconnected._