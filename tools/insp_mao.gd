extends SceneTree
func _init() -> void:
	var lib: AnimationLibrary = load("res://assets/personagens/anims_q.res")
	var cena: Node3D = load("res://assets/personagens/Casual_Male.gltf").instantiate()
	root.add_child(cena)
	var ap: AnimationPlayer = cena.get_node("AnimationPlayer")
	ap.add_animation_library("q", lib)
	var sk: Skeleton3D = cena.find_child("Skeleton3D", true, false)
	for clip in ["Pistol_Aim_Neutral", "Sword_Idle", "Idle"]:
		ap.play("q/" + clip)
		await process_frame
		ap.seek(0.3, true)
		await process_frame
		await process_frame
		for osso in ["Fist.R", "Fist.L", "LowerArm.R", "Torso", "Head"]:
			var b := sk.find_bone(osso)
			var g := sk.get_bone_global_pose(b)
			var alvo := Basis()   # frente +Z, cima +Y
			var o := g.basis.orthonormalized().inverse() * alvo
			print(clip, " ", osso, " pos=", g.origin.snapped(Vector3.ONE*0.01), " x=", g.basis.x.normalized().snapped(Vector3.ONE*0.01), " y=", g.basis.y.normalized().snapped(Vector3.ONE*0.01), " z=", g.basis.z.normalized().snapped(Vector3.ONE*0.01), " offset_euler_deg=", (o.get_euler() * 180.0 / PI).snapped(Vector3.ONE*0.1))
	quit()
