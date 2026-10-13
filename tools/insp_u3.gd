extends SceneTree
func _init() -> void:
	var d := PersonagemU.montar(true, "Hair_Long", false)
	var sk: Skeleton3D = d.esqueleto
	for mi in sk.get_children():
		if mi is MeshInstance3D:
			print(mi.name, " vis=", mi.visible, " surf=", mi.mesh.get_surface_count(), " aabb=", mi.mesh.get_aabb() if mi.mesh.get_surface_count() > 0 else null, " skin=", mi.skin)
	var f: Node3D = load("res://assets/personagens_u/base/Superhero_Female_FullBody.gltf").instantiate()
	var m: Node3D = load("res://assets/personagens_u/base/Superhero_Male_FullBody.gltf").instantiate()
	for c in [f, m]:
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name).to_lower().begins_with("superhero"):
				print(mi.name, " head bind=", PersonagemU._bind(mi, "Head").origin, " n0=", mi.skin.get_bind_name(5), mi.skin.get_bind_name(30))
	quit()
