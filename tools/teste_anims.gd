extends SceneTree
## Render de conferência: personagens com rosto tocando animações redirecionadas.
## xvfb-run godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s tools/teste_anims.gd -- clipe1,clipe2 saida.png

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var clipes: Array = ["Idle", "Walk", "Jog_Fwd", "Pistol_Aim_Neutral", "Sword_Regular_A", "Zombie_Walk_Fwd"]
	var saida := "res://prints/teste_anims.png"
	var tempo := 0.4
	var lado := false
	var modelos: Array = ["Casual_Male", "Worker_Female", "Doctor_Male_Young", "Soldier_Male", "Casual2_Female", "Zombie_Male"]
	for a in args:
		if a.begins_with("clipes="):
			clipes = a.substr(7).split(",")
		elif a.begins_with("saida="):
			saida = a.substr(6)
		elif a.begins_with("t="):
			tempo = float(a.substr(2))
		elif a == "lado":
			lado = true
		elif a.begins_with("modelos="):
			modelos = a.substr(8).split(",")
	var lib: AnimationLibrary = load("res://assets/personagens/anims_q.res")
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
	var n := clipes.size()
	for i in n:
		var cena: Node3D = load("res://assets/personagens/%s.gltf" % modelos[i % modelos.size()]).instantiate()
		cena.scale = Vector3.ONE * 0.55
		cena.position = Vector3((i - (n - 1) * 0.5) * 1.5, 0, 0)
		if lado:
			cena.rotation.y = PI * 0.5
		mundo.add_child(cena)
		var ap: AnimationPlayer = cena.get_node("AnimationPlayer")
		ap.add_animation_library("q", lib)
		ap.play("q/" + clipes[i])
		ap.seek(tempo * ap.current_animation_length, true)
		ap.pause()
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.1, 3.0 + n * 0.5)
	cam.fov = 50
	mundo.add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.current = true
	for f in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(saida)
	print("salvo ", saida)
	quit()
