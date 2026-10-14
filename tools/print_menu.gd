extends SceneTree
func _init() -> void:
	var cena: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(cena)
	for f in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://prints/129_menu_continuar.png")
	print("salvo")
	quit()
