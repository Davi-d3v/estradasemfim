extends SceneTree
## Vê o térreo de prédios mobiliados de cima (sem telhado).
## godot --path . --rendering-method gl_compatibility -s res://tools/ver_predio.gd -- saida.png tipo:semente ...
func _initialize() -> void:
	var n := Node3D.new()
	n.set_script(load("res://tools/ver_predio_no.gd"))
	root.add_child(n)
