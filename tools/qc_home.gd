extends SceneTree

## Screenshots of the whole Home screen: the live 3D diorama plus the 2D front end on top, at
## 1920x1080, for lining up against the reference (source_art/reference/home_target.webp).
## Windowed, not --headless (the screen skips its diorama when headless):
##   & $env:GODOT --path . --windowed --resolution 1920x1080 -s tools/qc_home.gd [-- --out=renders/home_diorama/home.png --wait=90]
## Add `--home-ref` before `-s` (a game flag, not a user arg) to include the 50 % reference overlay.
##
## The window is 1920x1080 but the print below shares no PNG with it: the stills land in `--out`.

const OUT := "res://renders/home_diorama/home.png"

func _initialize() -> void:
	_run.call_deferred()

func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.get_slice("=", 1)
	return fallback

func _run() -> void:
	var out := _arg("out", OUT)
	var wait := int(_arg("wait", "90"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var packed: PackedScene = load("res://scenes/frontend/home.tscn")
	if packed == null:
		push_error("qc_home: cannot load home.tscn")
		quit(1)
		return
	var screen := packed.instantiate()
	screen.navigate = false
	root.add_child(screen)
	for i in range(wait):
		await process_frame
		if i % 10 == 0:
			await RenderingServer.frame_post_draw
	for i in range(6):
		await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(out))
	print("home still ", out, " ", img.get_width(), "x", img.get_height())
	var ref := "--home-ref" in OS.get_cmdline_args() or "--home-ref" in OS.get_cmdline_user_args()
	print("reference overlay ", "on" if ref else "off")
	quit()
