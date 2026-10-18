extends SceneTree

## Stills of the Home diorama at chosen loop times (docs/plans/2026-10-17-home-diorama.md).
## Windowed, not --headless:
##   & $env:GODOT --path . --windowed --resolution 1920x1080 -s tools/qc_diorama.gd [-- --times=0,12,24,36,47.9 --out=renders/home_diorama/stills]
## With --write-data it first saves a fresh data/home_diorama.tres from the script defaults.

const SIZE := Vector2i(1920, 1080)
const DEFAULT_TIMES := [0.0, 12.0, 24.0, 36.0, 47.9]
const OUT := "res://renders/home_diorama/stills"

func _initialize() -> void:
	_run.call_deferred()

func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.get_slice("=", 1)
	return fallback

func _run() -> void:
	if "--write-data" in OS.get_cmdline_user_args():
		var err := ResourceSaver.save(HomeDioramaData.new(), HomeDioramaData.PATH)
		print("wrote ", HomeDioramaData.PATH, " err=", err)
	var times: Array = DEFAULT_TIMES
	var raw := _arg("times", "")
	if raw != "":
		times = []
		for s in raw.split(","):
			times.append(float(s))
	var out := _arg("out", OUT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var d := HomeDiorama.new()
	d.manual = true
	vp.add_child(d)
	await process_frame
	await process_frame
	for t in times:
		d.seek_to(t)
		for i in range(4):
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var path := "%s/t%05.1f.png" % [out, t]
		img.save_png(ProjectSettings.globalize_path(path))
		print("still ", path)
	quit()
