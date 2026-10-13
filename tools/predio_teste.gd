extends SceneTree
func _init():
	var m := WorldGen.new()
	root.add_child(m)
	await process_frame
	var pr := m.criar_predio(m, Vector3(500, 0, 5000), 0.0, "sobrado", 9.0, 8.0, 2, 3, "t")
	await process_frame
	var o := pr.global_position
	print("estruturas=", m.estruturas.size(), " vasculhaveis=", m.vasculhaveis.size())
	# porta da frente: centro + largura*0.2
	var fora := o + Vector3(1.8, 0, 6.0)
	var dentro := o + Vector3(1.8, 0, 2.0)
	print("entrar pela porta colide? ", m.colide(fora + Vector3(0,0,-1.9), o + Vector3(1.8, 0, 3.8)))
	print("atravessar parede colide? ", m.colide(o + Vector3(-3, 0, 4.6), o + Vector3(-3, 0, 3.8)))
	# subir a escada: rect x -4.2..-3.1, z -3.7..-0.1 ; sobe para +z
	var p := o + Vector3(-3.65, 0, -3.6)
	var y := o.y
	for i in 40:
		p.z = o.z - 3.6 + i * 0.1
		p.y = y
		y = pr.piso(p)
	print("topo da escada y-base=%.2f (esperado ~3.0)" % (y - o.y))
	p = o + Vector3(2, y - o.y, -2)
	p.y = y
	print("andar de cima piso=%.2f andar=%d" % [pr.piso(p) - o.y, pr.andar_em(pr.local(p).y)])
	var cont := 0
	for v in m.vasculhaveis:
		if v.global_position.y - o.y > 2.5: cont += 1
	print("moveis no 1o andar: ", cont)
	quit()
