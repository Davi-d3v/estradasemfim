extends SceneTree
## Conferência do Humanoid (modelo + arma + animação travada), vários lado a lado.
## args: poses=Anim:arma:frac,... lado saida=res://prints/x.png
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var poses: Array = ["Idle::0.3", "Pistol_Aim_Neutral:pistola:0.3", "Pistol_Aim_Neutral:espingarda:0.3", "Sword_Regular_A:facao:0.4", "Sword_Heavy_A:machado:0.45", "Pistol_Idle:rifle:0.3"]
	var saida := "res://prints/teste_humanoide.png"
	var lado := false
	var dist := 0.0
	for a in args:
		if a.begins_with("poses="):
			poses = a.substr(6).split(",")
		elif a.begins_with("saida="):
			saida = a.substr(6)
		elif a == "lado":
			lado = true
		elif a.begins_with("dist="):
			dist = float(a.substr(5))
	var mundo := Node3D.new()
	root.add_child(mundo)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.72)
	env.environment.ambient_light_energy = 0.8
	mundo.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-45, 35, 0)
	mundo.add_child(sol)
	var chao := MeshInstance3D.new()
	chao.mesh = PlaneMesh.new()
	chao.mesh.size = Vector2(30, 30)
	mundo.add_child(chao)
	var n := poses.size()
	var hs: Array = []
	for i in n:
		var p: PackedStringArray = String(poses[i]).split(":")
		var h := Humanoid.new()
		h.cores = {"cabelo": "Hair_SimpleParted", "barba": true, "roupa": Color(0.72, 0.8, 0.62), "pele": Color(0.92, 0.84, 0.78), "cor_cabelo": Color(0.12, 0.08, 0.05)}
		h.com_mochila = true
		h.com_bone = true
		h.arma = p[1] if p.size() > 1 else ""
		h.position = Vector3((i - (n - 1) * 0.5) * 1.3, 0, 0)
		if lado:
			h.rotation.y = PI * 0.5
		mundo.add_child(h)
		hs.append([h, p[0], float(p[2]) if p.size() > 2 else 0.3, p.size() > 3])
	await process_frame
	for e in hs:
		e[0].fixar(e[1], e[2])
		if e[3]:
			e[0].arma_costas(true)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.3, (dist if dist > 0.0 else 2.6 + n * 0.55))
	cam.fov = 50
	mundo.add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.current = true
	for f in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida)
	print("salvo ", saida)
	quit()
