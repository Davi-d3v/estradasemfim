extends SceneTree
func _init() -> void:
	var cena: Node3D = load("res://assets/personagens/Casual_Male.gltf").instantiate()
	root.add_child(cena)
	var sk: Skeleton3D = cena.find_child("Skeleton3D", true, false)
	var mi: MeshInstance3D = cena.find_children("*", "MeshInstance3D", true, false)[0]
	var skin: Skin = mi.skin
	print("binds=", skin.get_bind_count(), " node3d scale arm=", cena.get_node("CharacterArmature").transform)
	for i in skin.get_bind_count():
		var nm := skin.get_bind_name(i)
		var bi := skin.get_bind_bone(i)
		var g := skin.get_bind_pose(i).affine_inverse()
		print(i, " ", nm, " bone=", bi, " ", sk.get_bone_name(bi) if bi >= 0 else "", " pos=", g.origin.snapped(Vector3.ONE * 0.001), " y=", g.basis.y.normalized().snapped(Vector3.ONE * 0.01), " esc=", g.basis.get_scale().snapped(Vector3.ONE*0.01))
	quit()
