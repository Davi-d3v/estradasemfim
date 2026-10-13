extends SceneTree
func _init() -> void:
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
	var tipos := ["javali", "capivara", "javali", "capivara", "veado", "lobo"]
	var lista := []
	for i in tipos.size():
		var an := Animal.new()
		an.tipo = tipos[i]
		an.semente = i
		an.position = Vector3(0, 0, (i - 2.5) * 1.8)
		mundo.add_child(an)
		an.set_process(false)
		an.rotation.y = 0.0
		lista.append(an)
	await process_frame
	for an in lista:
		an.rotation.y = 0.0
	for an in lista:
		print(an.tipo, " rot=", an.rotation, " corpo=", an._corpo.rotation if an._corpo else null)
	for i in lista.size():
		if i >= 2 and i < 4:
			lista[i]._animar(4.0, 0.3)
	var cam := Camera3D.new()
	cam.position = Vector3(5.0, 1.0, -3.0)
	cam.fov = 50
	mundo.add_child(cam)
	cam.look_at(Vector3(0, 0.4, 0))
	cam.current = true
	for f in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://prints/teste_bichos.png")
	print("salvo")
	quit()
