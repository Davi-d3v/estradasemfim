extends SceneTree
func _init() -> void:
	var cena: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(cena)
	for f in 5:
		await process_frame
	cena._comecar("infinito")
	cena.tutorial.iniciar()
	for p in Tutorial.PASSOS:
		print(p.cond, " -> ", cena.tutorial._cumpriu(p.cond, 0.1))
	cena.jogador.position += Vector3(6, 0, 0)
	print("mover depois -> ", cena.tutorial._cumpriu("mover", 0.1))
	quit()
