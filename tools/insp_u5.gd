extends SceneTree
func _init() -> void:
	var f: Node3D = load("res://assets/personagens_u/base/Superhero_Female_FullBody.gltf").instantiate()
	var sk: Skeleton3D = f.find_children("*", "Skeleton3D", true, false)[0]
	for mi in sk.get_children():
		if mi is MeshInstance3D:
			var m := PersonagemU._cortar(mi, sk, ["root"], "teste_" + mi.name)
			print(mi.name, " -> ", m.get_surface_count())
	quit()
