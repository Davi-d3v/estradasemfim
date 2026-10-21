extends Node3D
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0]
	var lista: Array = args.slice(1)
	var cel := 700
	get_viewport().size = Vector2i(cel, cel)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-60, 30, 0)
	add_child(luz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.32, 0.35)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var final := Image.create(cel * lista.size(), cel, false, Image.FORMAT_RGB8)
	for i in lista.size():
		var partes: PackedStringArray = String(lista[i]).split(":")
		var p := Predio.new()
		p.tipo = partes[0]
		p.semente = int(partes[1]) if partes.size() > 1 else 1
		p.condicao = 0.6
		if p.tipo == "loja":
			p.largura = 12.0
			p.profundidade = 10.0
		add_child(p)
		if p.telhado:
			p.telhado.visible = false
		for k in range(1, p.andar_nos.size()):
			p.andar_nos[k].visible = false
		p.corte(0)
		var r := maxf(p.largura, p.profundidade)
		if OS.get_environment("VISTA") == "cima":
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = r * 1.15
			cam.look_at_from_position(Vector3(0, 20.0, 0.001), Vector3(0, 0, 0), Vector3(0, 0, -1))
			cam.near = 0.05
		else:
			cam.fov = 50.0
			cam.look_at_from_position(Vector3(0, r * 1.25, r * 0.55), Vector3(0, 0, 0.3), Vector3.UP)
		for f in 3:
			await RenderingServer.frame_post_draw
		var im := get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGB8)
		final.blit_rect(im, Rect2i(0, 0, cel, cel), Vector2i(i * cel, 0))
		p.queue_free()
		await get_tree().process_frame
	final.save_png(saida)
	get_tree().quit()
