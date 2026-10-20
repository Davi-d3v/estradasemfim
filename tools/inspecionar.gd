extends SceneTree
## Fotografa modelos de 3 lados (vista de +X, +Y, +Z) com eixos coloridos, para decidir
## como alinhar armas e objetos. Uso (com xvfb):
##   godot --path . --rendering-method gl_compatibility -s res://tools/inspecionar.gd -- saida.png a.glb b.glb ...

func _initialize() -> void:
	var n := Node.new()
	n.set_script(load("res://tools/inspecionar_no.gd"))
	root.add_child(n)
