extends SceneTree
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var lado := "lado" in args
	var u1: Node = load("res://assets/personagens/UAL1.glb").instantiate()
	var u2: Node = load("res://assets/personagens/UAL2.glb").instantiate()
	var l1: AnimationLibrary = u1.find_children("*", "AnimationPlayer", true, false)[0].get_animation_library("")
	var l2: AnimationLibrary = u2.find_children("*", "AnimationPlayer", true, false)[0].get_animation_library("")
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
	var cfg := [[false, "Hair_SimpleParted", true, "Idle"], [true, "Hair_Long", false, "Walk"], [false, "Hair_Buzzed", false, "Pistol_Aim_Neutral"], [true, "Hair_Buns", false, "Idle_Talking"], [false, "Hair_SimpleParted", false, "Zombie_Walk_Fwd"]]
	var n := cfg.size()
	for i in n:
		var c: Array = cfg[i]
		var d := PersonagemU.montar(c[0], c[1], c[2])
		var r: Node3D = d.raiz
		r.position = Vector3((i - (n - 1) * 0.5) * 1.1, 0, 0)
		if lado:
			r.rotation.y = PI * 0.5
		mundo.add_child(r)
		var ap: AnimationPlayer = d.player
		ap.add_animation_library("a", l1)
		ap.add_animation_library("b", l2)
		var nome: String = ("a/" if l1.has_animation(c[3]) else "b/") + c[3]
		ap.play(nome)
		ap.seek(0.4, true)
		ap.pause()
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.25, 4.6)
	cam.fov = 50
	mundo.add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.current = true
	for f in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://prints/teste_u%s.png" % ("_lado" if lado else ""))
	print("salvo")
	quit()
