extends SceneTree
func _init() -> void:
	var c: Node3D = load("res://assets/personagens_u/base/Superhero_Female_FullBody.gltf").instantiate()
	var sk: Skeleton3D = c.find_children("*", "Skeleton3D", true, false)[0]
	for mi in sk.get_children():
		if mi is MeshInstance3D:
			var arr: Array = mi.mesh.surface_get_arrays(0)
			print(mi.name, " surf=", mi.mesh.get_surface_count(), " verts=", arr[0].size(), " bones=", arr[Mesh.ARRAY_BONES].size() if arr[Mesh.ARRAY_BONES] else 0, " binds=", mi.skin.get_bind_count() if mi.skin else 0, " name0=", mi.skin.get_bind_name(0) if mi.skin else "", " bone0=", mi.skin.get_bind_bone(0) if mi.skin else -2)
	quit()
