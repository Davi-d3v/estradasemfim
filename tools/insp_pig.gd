extends SceneTree
func _init() -> void:
	var c: Node3D = load("res://assets/animais/Porco.fbx").instantiate()
	root.add_child(c)
	var ap: AnimationPlayer = c.find_children("*", "AnimationPlayer", true, false)[0]
	print("anims ", ap.get_animation_list())
	for mi in c.find_children("*", "MeshInstance3D", true, false):
		for k in mi.mesh.get_surface_count():
			var mt = mi.mesh.surface_get_material(k)
			print("  mat ", k, " ", mt.resource_name if mt else "", " ", mt.albedo_color if mt is StandardMaterial3D else "")
		print(mi.name, " aabb ", (mi as MeshInstance3D).get_aabb(), " gx ", (mi as Node3D).global_transform.basis.get_scale())
	quit()
