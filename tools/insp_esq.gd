extends SceneTree
func _init() -> void:
	for p in ["res://assets/personagens/Casual_Male.gltf", "res://assets/personagens/Casual_Female.gltf", "res://assets/personagens/UAL1.glb"]:
		var cena: Node3D = load(p).instantiate()
		root.add_child(cena)
		var sk: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
		print("== ", p, " skel path=", cena.get_path_to(sk), " xform=", sk.global_transform, " ap root=", ap.root_node, " ap path=", cena.get_path_to(ap))
		for mi in cena.find_children("*", "MeshInstance3D", true, false):
			print("  mesh ", cena.get_path_to(mi), " aabb=", mi.get_aabb(), " surf=", mi.mesh.get_surface_count(), " skin=", mi.skin != null)
		for b in sk.get_bone_count():
			if p.ends_with("UAL1.glb") and b > 70:
				break
			var g := sk.global_transform * sk.get_bone_global_rest(b)
			print("  ", b, " ", sk.get_bone_name(b), " par=", sk.get_bone_parent(b), " pos=", g.origin.snapped(Vector3.ONE * 0.001), " y=", g.basis.y.snapped(Vector3.ONE * 0.01))
		var lib := ap.get_animation_library(ap.get_animation_library_list()[0])
		var a := lib.get_animation(lib.get_animation_list()[0])
		print("  anim ", lib.get_animation_list().slice(0, 5), " tracks ex: ", a.track_get_path(0), " type ", a.track_get_type(0))
		cena.free()
	quit()
