extends SceneTree
func _init() -> void:
	var lib: AnimationLibrary = load("res://assets/personagens_k/anims_k.res")
	var cena: Node3D = load("res://assets/personagens_k/characterMedium.fbx").instantiate()
	root.add_child(cena)
	var ap := AnimationPlayer.new()
	cena.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("q", lib)
	var sk: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	for clip in ["Pistol_Aim_Neutral", "Sword_Idle", "Idle"]:
		ap.play("q/" + clip)
		await process_frame
		ap.seek(0.3, true)
		await process_frame
		await process_frame
		for osso in ["RightHand", "LeftHand", "UpperChest", "Head"]:
			var b := sk.find_bone(osso)
			var g := sk.get_bone_global_pose(b)
			var alvo := Basis()   # frente +Z, cima +Y
			var o := g.basis.orthonormalized().inverse() * alvo
			print(clip, " ", osso, " pos=", g.origin.snapped(Vector3.ONE*0.01), " x=", g.basis.x.normalized().snapped(Vector3.ONE*0.01), " y=", g.basis.y.normalized().snapped(Vector3.ONE*0.01), " z=", g.basis.z.normalized().snapped(Vector3.ONE*0.01), " offset_euler_deg=", (o.get_euler() * 180.0 / PI).snapped(Vector3.ONE*0.1))
	quit()
