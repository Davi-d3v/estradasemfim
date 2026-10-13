extends SceneTree
func _init():
	var m := WorldGen.new()
	root.add_child(m)
	await process_frame
	var t0 := Time.get_ticks_msec()
	print("indice 0: ", m.reg.indice(0.0), " fim0=", m.reg.fim(0))
	var t1 := Time.get_ticks_msec()
	var f := m._features(0)
	print("features0: ", f.size(), " ms=", Time.get_ticks_msec() - t1)
	t1 = Time.get_ticks_msec()
	for i in 1000:
		m.altura(randf_range(-200, 200), randf_range(0, 2000))
	print("1000 alturas ms=", Time.get_ticks_msec() - t1)
	t1 = Time.get_ticks_msec()
	m._gerar_chunk(3)
	print("chunk ms=", Time.get_ticks_msec() - t1)
	quit()
