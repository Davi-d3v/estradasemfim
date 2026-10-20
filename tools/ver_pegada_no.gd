extends Node
## Personagem segurando cada arma (mirando e baixa), num cenário vazio — rápido para ajustar a pegada.
var h: Humanoid
var mirando := false
func _process(_dt: float) -> void:
	if h and mirando:
		h.pose_mirar(1.0)
		h.mirar_para(Vector3(0, 0, 1))

func _ready() -> void:
	process_priority = -10
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0]
	var ids: Array = args.slice(1)
	var W := 560
	var H := 420
	get_viewport().size = Vector2i(W, H)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-40, -30, 0)
	luz.shadow_enabled = true
	add_child(luz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.5, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	chao.mesh = pm
	add_child(chao)
	h = Humanoid.new()
	h.semente = 7
	h.visual = "civil"
	add_child(h)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 38.0
	var vistas := [Vector3(-2.6, 0.1, 0.5), Vector3(-1.1, 0.25, 2.3), Vector3(1.6, 0.6, -1.6)]
	var final := Image.create(W * 3, H * ids.size() * 2, false, Image.FORMAT_RGB8)
	for i in ids.size():
		h.arma = ids[i]
		h.trocar_arma(ids[i])
		for pose in 2:
			mirando = pose == 0
			for f in 4:
				if pose == 0:
					h.pose_mirar(1.0)
					h.mirar_para(Vector3(0, 0, 1))
				else:
					h.loop("Idle")
				await get_tree().process_frame
			print("  pose ", pose, " baixa=", h.pegada.baixa)
			for v in 3:
				var c := Vector3(0, 1.3, 0)
				cam.look_at_from_position(c + vistas[v], c + Vector3(0, 0, 0.35), Vector3.UP)
				if pose == 0:
					h.pose_mirar(1.0)
					h.mirar_para(Vector3(0, 0, 1))
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var im := get_viewport().get_texture().get_image()
				im.convert(Image.FORMAT_RGB8)
				im.resize(W, H)
				final.blit_rect(im, Rect2i(0, 0, W, H), Vector2i(v * W, (i * 2 + pose) * H))
		print("pegada ", ids[i], " ativo=", h.pegada.ativo, " baixa=", h.pegada.baixa, " peso=", h.pegada.peso, " mira=", h.pegada.mira)
	final.save_png(saida)
	get_tree().quit()
