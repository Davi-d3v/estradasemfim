extends SceneTree
## Lista os nós com malha de um modelo (caminho, tamanho e centro no espaço da cena).
## Uso: godot --headless --path . -s res://tools/listar_nos.gd -- res://modelo.glb
func _initialize() -> void:
	for arq in OS.get_cmdline_user_args():
		var m: Node3D = load(arq).instantiate()
		print("== ", arq)
		_lista(m, m, Transform3D())
		m.free()
	quit()

func _lista(n: Node, raiz: Node3D, pai: Transform3D) -> void:
	var t := pai
	if n is Node3D and n != raiz:
		t = pai * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var a: AABB = t * mi.get_aabb()
		var tri := 0
		for s in mi.mesh.get_surface_count():
			var li: int = mi.mesh.surface_get_array_index_len(s)
			tri += (li if li > 0 else mi.mesh.surface_get_array_len(s)) / 3
		print("  %s | tam %s | centro %s | tri %d" % [raiz.get_path_to(mi), a.size.snapped(Vector3.ONE * 0.001), a.get_center().snapped(Vector3.ONE * 0.001), tri])
	for c in n.get_children():
		_lista(c, raiz, t)
