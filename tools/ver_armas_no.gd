extends Node
## Vista lateral (de +Z) e de cima de cada arma normalizada, com grade de 10 cm e os pontos:
## vermelho = mão direita (origem), verde = mão esquerda, ciano = boca, amarelo = ombro.

func visiveis(n: Node, t: Transform3D, lista: Array) -> void:
	if n is Node3D and not (n as Node3D).visible:
		return
	var tt := t
	if n is Node3D:
		tt = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and not n.has_meta("marca"):
		lista.append(tt * (n as MeshInstance3D).get_aabb())
	for c in n.get_children():
		visiveis(c, tt, lista)

func marca(pai: Node3D, p: Vector3, cor: Color, r: float) -> void:
	var mk := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = r
	sp.height = r * 2.0
	mk.mesh = sp
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.no_depth_test = true
	mt.albedo_color = cor
	mk.material_override = mt
	mk.position = p
	mk.set_meta("marca", true)
	pai.add_child(mk)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0]
	var ids := args.slice(1)
	var W := 1200
	var H := 420
	get_viewport().size = Vector2i(W, H)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, 25, 0)
	add_child(luz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.32, 0.35)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.9, 0.9)
	add_child(env)
	var final := Image.create(W, H * ids.size() * 2, false, Image.FORMAT_RGB8)
	for i in ids.size():
		var m := ArmasHD.montar(ids[i])
		add_child(m)
		var l: Array = []
		visiveis(m, Transform3D(), l)
		var ab: AABB = l[0]
		for a in l:
			ab = ab.merge(a)
		print("%s: visível %s de %s a %s" % [ids[i], ab.size.snapped(Vector3.ONE * 0.001), ab.position.snapped(Vector3.ONE * 0.001), ab.end.snapped(Vector3.ONE * 0.001)])
		var r := ab.size.x * 0.012
		marca(m, Vector3.ZERO, Color.RED, r)
		marca(m, m.get_meta("apoio"), Color.GREEN, r)
		marca(m, m.get_meta("boca"), Color.CYAN, r)
		marca(m, m.get_meta("ombro"), Color.YELLOW, r)
		# grade de 10 cm no plano z = 0
		var g := Node3D.new()
		add_child(g)
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = Color(0.45, 0.47, 0.5)
		for k in range(-20, 21):
			for eixo in 2:
				var mi := MeshInstance3D.new()
				var bx := BoxMesh.new()
				bx.size = Vector3(4.0, 0.002, 0.002) if eixo == 0 else Vector3(0.002, 4.0, 0.002)
				mi.mesh = bx
				mi.material_override = mt
				mi.position = Vector3(0, k * 0.1, -0.5) if eixo == 0 else Vector3(k * 0.1, 0, -0.5)
				g.add_child(mi)
		for v in 2:
			var cam := Camera3D.new()
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.keep_aspect = Camera3D.KEEP_WIDTH
			cam.size = maxf(ab.size.x, ab.size.y * float(W) / float(H)) * 1.15
			add_child(cam)
			var c := ab.get_center()
			if v == 0:
				cam.look_at_from_position(c + Vector3(0, 0, 3), c, Vector3.UP)
			else:
				cam.look_at_from_position(c + Vector3(0, 3, 0), c, Vector3(0, 0, -1))
			cam.current = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var im := get_viewport().get_texture().get_image()
			im.convert(Image.FORMAT_RGB8)
			im.resize(W, H)
			final.blit_rect(im, Rect2i(0, 0, W, H), Vector2i(0, (i * 2 + v) * H))
			cam.queue_free()
		m.queue_free()
		g.queue_free()
		await get_tree().process_frame
	final.save_png(saida)
	get_tree().quit()
