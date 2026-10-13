extends SceneTree
func _init():
	var m := WorldGen.new()
	root.add_child(m)
	await process_frame
	var z := m.criar_zumbi(m, Vector3.ZERO, 0.0, 5, "comum")
	print("apos criar ombro=", z.ombro_e.rotation.x, " filhos=", z.get_child_count())
	z._fase = 1.0
	z._animar(0.5)
	print("apos animar ombro=", z.ombro_e.rotation.x)
	await process_frame
	print("frame ombro=", z.ombro_e.rotation.x if is_instance_valid(z.ombro_e) else -99, " filhos=", z.get_child_count())
	quit()
