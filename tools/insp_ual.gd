extends SceneTree
func _init() -> void:
	for p in ["res://assets/personagens/UAL1.glb", "res://assets/personagens/UAL2.glb"]:
		var cena: Node3D = load(p).instantiate()
		var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
		print(p, " ", ap.get_animation_list())
		if p.ends_with("1.glb"):
			var sk: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
			var t := Transform3D()
			var n: Node = sk
			while n != cena:
				t = (n as Node3D).transform * t
				n = n.get_parent()
			print("skel chain xform=", t, " path=", cena.get_path_to(sk))
			for b in sk.get_bone_count():
				var g := t * sk.get_bone_global_rest(b)
				var nm := sk.get_bone_name(b)
				if nm.contains("thumb") or nm.contains("index") or nm.contains("middle") or nm.contains("ring") or nm.contains("pinky"):
					continue
				print("  ", b, " ", nm, " par=", sk.get_bone_parent(b), " pos=", g.origin.snapped(Vector3.ONE * 0.001), " y=", g.basis.y.normalized().snapped(Vector3.ONE * 0.01))
		cena.free()
	quit()
