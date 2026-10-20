extends SceneTree
## godot --path . --rendering-method gl_compatibility -s res://tools/ver_armas.gd -- saida.png id1 id2 ...
func _initialize() -> void:
	var n := Node.new()
	n.set_script(load("res://tools/ver_armas_no.gd"))
	root.add_child(n)
