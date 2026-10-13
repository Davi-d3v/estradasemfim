extends SceneTree
func _init() -> void:
	var cena: Node3D = load("res://assets/personagens/UAL1.glb").instantiate()
	root.add_child(cena)
	var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
	var sk: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	for clip in ["Pistol_Aim_Neutral", "Idle"]:
		ap.play(clip)
		await process_frame
		ap.seek(0.3, true)
		await process_frame
		await process_frame
		for osso in ["hand_r", "spine_03", "Head"]:
			var g := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(osso))
			print(clip, " ", osso, " pos=", g.origin.snapped(Vector3.ONE*0.01), " x=", g.basis.x.normalized().snapped(Vector3.ONE*0.01), " y=", g.basis.y.normalized().snapped(Vector3.ONE*0.01), " z=", g.basis.z.normalized().snapped(Vector3.ONE*0.01))
	quit()
