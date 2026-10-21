extends Node3D
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0]
	var anim: String = args[1]
	var lista: Array = args.slice(2)
	var W := 360
	var H := 560
	get_viewport().size = Vector2i(W, H)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, 30, 0)
	luz.shadow_enabled = true
	add_child(luz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.5, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	add_child(env)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	chao.mesh = pm
	add_child(chao)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 30.0
	var final := Image.create(W * lista.size(), H, false, Image.FORMAT_RGB8)
	for i in lista.size():
		var partes: PackedStringArray = String(lista[i]).split(":")
		var h := Humanoid.new()
		h.semente = 11 + i * 7
		if partes[0] == "heroi":
			h.heroi = true
			h.com_mochila = true
		else:
			h.visual = partes[0]
			h.feminino = partes.size() > 2 and partes[2] == "f"
			if partes[0] == "agricultor":
				h.chapeu = true
		h.arma = partes[1] if partes.size() > 1 else ""
		add_child(h)
		for f in 3:
			await get_tree().process_frame
		if anim != "":
			h.loop(anim)
		for f in 6:
			await get_tree().process_frame
		cam.look_at_from_position(Vector3(1.4, 1.35, 4.2), Vector3(0, 0.95, 0), Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var im := get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGB8)
		final.blit_rect(im, Rect2i(0, 0, W, H), Vector2i(i * W, 0))
		h.queue_free()
		await get_tree().process_frame
	final.save_png(saida)
	get_tree().quit()
