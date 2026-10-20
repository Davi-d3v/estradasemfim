extends SceneTree
## godot --path . --rendering-method gl_compatibility -s res://tools/ver_props.gd -- saida.png [ids...]
func _initialize() -> void:
	var n := Node3D.new()
	n.set_script(load("res://tools/ver_props_no.gd"))
	root.add_child(n)
