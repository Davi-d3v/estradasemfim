extends SceneTree
func _init():
	var m := WorldGen.new()
	root.add_child(m)
	await process_frame
	var f: Array = m._features(0)
	for x in f:
		if x.tipo == "estrada":
			print(x.id, " pts=", x.pts.size(), " first=", x.pts[0], " bb=", x.bb)
	var n := Node3D.new()
	root.add_child(n)
	var l = m.lugares_da_regiao(0)[0]
	var k := int(floor(l.juncao_z / 64.0))
	m._estradas_terra(n, k * 64.0, k)
	print("children dirt: ", n.get_child_count())
	for c in n.get_children():
		print(c, " ", (c as MeshInstance3D).mesh.get_faces().size())
	quit()
