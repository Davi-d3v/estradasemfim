extends SceneTree
func _init() -> void:
	var f: Node3D = load("res://assets/personagens_u/base/Superhero_Female_FullBody.gltf").instantiate()
	var sk: Skeleton3D = f.find_children("*", "Skeleton3D", true, false)[0]
	for mi in sk.get_children():
		if mi is MeshInstance3D:
			var arr: Array = mi.mesh.surface_get_arrays(0)
			var b = arr[Mesh.ARRAY_BONES]
			print(mi.name, " bones type=", typeof(b), " n=", b.size(), " first=", b.slice(0, 8), " w=", arr[Mesh.ARRAY_WEIGHTS].slice(0, 8), " idx=", arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] else -1, " bind0bone=", mi.skin.get_bind_bone(0), " find=", sk.find_bone(mi.skin.get_bind_name(6)))
	quit()
