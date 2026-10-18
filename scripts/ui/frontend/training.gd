extends FrontScreen

var hero_choice: OptionButton
var map_choice: OptionButton
var targets: OptionButton

func build() -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(180, 100)
	column.custom_minimum_size = Vector2(1300, 800)
	column.add_theme_constant_override("separation", 24)
	content.add_child(column)
	column.add_child(FE.bi_box("ENSAYO", "Training & testing", 64, FE.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	column.add_child(FE.label("Test tags, movement and skills. No time limit or match score.", 28, FE.CHALK_DIM))
	hero_choice = OptionButton.new()
	hero_choice.custom_minimum_size = Vector2(700, 76)
	var saved := String(Save.get_profile().get("home_hero", "jm"))
	for id in HeroData.ORDER:
		hero_choice.add_item(HeroData.load_hero(id).display_name)
		hero_choice.set_item_metadata(hero_choice.item_count - 1, id)
		if id == saved:
			hero_choice.select(hero_choice.item_count - 1)
	column.add_child(FE.label("Character", 28, FE.CHALK))
	column.add_child(hero_choice)
	map_choice = OptionButton.new()
	map_choice.custom_minimum_size = Vector2(700, 76)
	map_choice.add_item("Barangay Court")
	map_choice.set_item_metadata(0, "barangay_court")
	map_choice.add_item("Konstruksyon")
	map_choice.set_item_metadata(1, "construction_site")
	column.add_child(FE.label("Testing map", 28, FE.CHALK))
	column.add_child(map_choice)
	targets = OptionButton.new()
	targets.custom_minimum_size = Vector2(700, 76)
	targets.add_item("Stationary dummies")
	targets.add_item("Active bots")
	column.add_child(targets)
	var start := btn("Training", "FREE TRAINING", "Start testing", Vector2(700, 90), 36, false, true)
	column.add_child(start)
	start.pressed.connect(start_training)
	var tutorial := btn("Tutorial", "TURO NI KUYA TANOD", "Guided tutorial", Vector2(700, 90), 32)
	column.add_child(tutorial)
	tutorial.pressed.connect(start_tutorial)
	var back := btn("Back", "BUMALIK", "Back", Vector2(230, 72), 28)
	back.position = Vector2(1550, 940)
	content.add_child(back)
	back.pressed.connect(on_back)

func first_focus() -> Control:
	return buttons.get("Training")

func on_back() -> void:
	go("home")

func start_training() -> void:
	Session.prepare_training(String(hero_choice.get_selected_metadata()), String(map_choice.get_selected_metadata()), targets.selected == 1)
	go_call("training", func(): Session.start_match())

func start_tutorial() -> void:
	Tutorial.prepare_session(String(hero_choice.get_selected_metadata()))
	go_call("tutorial", func(): Session.start_match())
