extends SceneTree
func _init() -> void:
	for p in ["res://assets/personagens_u/base/Superhero_Male_FullBody.gltf", "res://assets/personagens_u/outfits/Male_Peasant.gltf", "res://assets/personagens_u/outfits/Female_Peasant.gltf", "res://assets/personagens_u/hair/Hair_Beard.gltf", "res://assets/personagens/UAL1.glb"]:
		var c: Node3D = load(p).instantiate()
		var sk: Skeleton3D = c.find_children("*", "Skeleton3D", true, false)[0]
		var ms := []
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			ms.append([String(c.get_path_to(mi)), mi.mesh.get_surface_count(), mi.get_aabb().size.snapped(Vector3.ONE*0.01)])
		print(p.get_file(), " skel=", c.get_path_to(sk), " bones=", sk.get_bone_count(), " b0..=", [sk.get_bone_name(0), sk.get_bone_name(1), sk.get_bone_name(2)], " meshes=", ms, " head=", sk.find_bone("Head"))
		c.free()
	quit()
