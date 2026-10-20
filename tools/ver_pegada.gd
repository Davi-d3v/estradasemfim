extends SceneTree
## godot --path . --rendering-method gl_compatibility -s res://tools/ver_pegada.gd -- saida.png id1 id2 ...
func _initialize() -> void:
	var n := Node.new()
	n.set_script(load("res://tools/ver_pegada_no.gd"))
	root.add_child(n)
