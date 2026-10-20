extends Node

func aabb_de(n: Node, base: Transform3D, ab: Array) -> void:
	var t := base
	if n is Node3D:
		t = base * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var a: AABB = t * (n as MeshInstance3D).get_aabb()
		ab.append(a)
	for c in n.get_children():
		aabb_de(c, t, ab)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0]
	var vp := get_viewport()
	vp.size = Vector2i(1500, 500 * (args.size() - 1))
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-40, 30, 0)
	add_child(luz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var img_final := Image.create(1500, 500 * (args.size() - 1), false, Image.FORMAT_RGB8)
	for i in range(1, args.size()):
		var m: Node3D
		if args[i].begins_with("arma:"):
			m = ArmasHD.montar(args[i].substr(5))
			for k in 4:
				var mk := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = 0.015
				sp.height = 0.03
				mk.mesh = sp
				var mt2 := StandardMaterial3D.new()
				mt2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mt2.no_depth_test = true
				mt2.albedo_color = [Color.RED, Color.GREEN, Color.CYAN, Color.YELLOW][k]
				mk.material_override = mt2
				mk.position = [Vector3.ZERO, m.get_meta("apoio"), m.get_meta("boca"), m.get_meta("ombro")][k]
				m.add_child(mk)
		else:
			var cena: PackedScene = load(args[i])
			m = cena.instantiate()
		add_child(m)
		var lista: Array = []
		aabb_de(m, Transform3D(), lista)
		var ab: AABB = lista[0]
		for a in lista:
			ab = ab.merge(a)
		print("%s: tamanho %s centro %s" % [args[i].get_file(), ab.size.snapped(Vector3.ONE * 0.001), ab.get_center().snapped(Vector3.ONE * 0.001)])
		var c := ab.get_center()
		var r := ab.size.length() * 0.6
		# eixos
		var eixos := Node3D.new()
		add_child(eixos)
		for k in 3:
			var mi := MeshInstance3D.new()
			var bx := BoxMesh.new()
			var s := Vector3.ONE * r * 0.01
			s[k] = r * 1.2
			bx.size = s
			mi.mesh = bx
			var mt := StandardMaterial3D.new()
			mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mt.albedo_color = [Color.RED, Color.GREEN, Color.BLUE][k]
			mi.material_override = mt
			var p := c
			p[k] += r * 0.6
			mi.position = p
			eixos.add_child(mi)
		for v in 3:
			var cam := Camera3D.new()
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = r * 1.7
			add_child(cam)
			var dir: Vector3 = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)][v]
			var up := Vector3.UP if v != 1 else Vector3(0, 0, -1)
			cam.look_at_from_position(c + dir * r * 3.0, c, up)
			cam.near = 0.001 * r
			cam.far = r * 10.0
			cam.current = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var sub := vp.get_texture().get_image()
			sub.convert(Image.FORMAT_RGB8)
			var w := sub.get_width()
			var h := sub.get_height()
			var lado := mini(w, h)
			sub = sub.get_region(Rect2i((w - lado) / 2, (h - lado) / 2, lado, lado))
			sub.resize(500, 500)
			img_final.blit_rect(sub, Rect2i(0, 0, 500, 500), Vector2i(v * 500, (i - 1) * 500))
			cam.queue_free()
		m.queue_free()
		eixos.queue_free()
		await get_tree().process_frame
	img_final.save_png(saida)
	get_tree().quit()
