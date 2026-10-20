extends Node3D
## Folha de contato dos Props: cada objeto visto de 3/4 de frente (frente = +Z), com a
## grade de 1 m no chão e um boneco de 1,75 m de referência.
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0]
	var ids: Array = args.slice(1)
	if ids.is_empty():
		ids = Props.C.keys()
	var cel := 320
	var cols := 6
	var linhas := int(ceil(ids.size() / float(cols)))
	get_viewport().size = Vector2i(cel, cel)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45, 35, 0)
	add_child(luz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.34, 0.37)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.85, 0.85)
	add_child(env)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	chao.mesh = pm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.4, 0.42, 0.45)
	chao.material_override = mt
	add_child(chao)
	var boneco := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 1.75
	boneco.mesh = cap
	boneco.position = Vector3(-1.2, 0.875, -0.5)
	add_child(boneco)
	var final := Image.create(cel * cols, cel * linhas, false, Image.FORMAT_RGB8)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	for i in ids.size():
		var n := Props.por(self, ids[i], Vector3.ZERO, 0.0, 1.0, 1000.0)
		var t: Vector3 = Props.tamanho(ids[i])
		print("%s: %s" % [ids[i], t.snapped(Vector3.ONE * 0.01)])
		var r := maxf(t.length(), 0.3)
		boneco.visible = r > 1.2
		cam.fov = 40.0
		cam.look_at_from_position(Vector3(r * 0.9, r * 0.7 + t.y * 0.3, r * 1.4), Vector3(0, t.y * 0.45, 0), Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var im := get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGB8)
		im.resize(cel, cel)
		final.blit_rect(im, Rect2i(0, 0, cel, cel), Vector2i((i % cols) * cel, (i / cols) * cel))
		if n:
			n.queue_free()
		await get_tree().process_frame
	final.save_png(saida)
	get_tree().quit()
