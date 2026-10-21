extends SceneTree
## Folha de personagens: cada papel (ou "heroi") de 3/4 de frente, numa animação.
## godot --path . --rendering-method gl_compatibility -s res://tools/ver_personagens.gd -- saida.png animacao papel[:arma] ...
func _initialize() -> void:
	var n := Node3D.new()
	n.set_script(load("res://tools/ver_personagens_no.gd"))
	root.add_child(n)
