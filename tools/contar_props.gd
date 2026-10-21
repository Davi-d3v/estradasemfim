extends SceneTree
## Triângulos e pedaços (MeshInstance) de cada objeto do catálogo Props e de cada arma HD.
func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	for id in Props.C.keys():
		var m := Props._molde(id)
		if m == null:
			continue
		var tri := 0
		for c in m.get_children():
			var mi := c as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var li: int = mi.mesh.surface_get_array_index_len(s)
				tri += (li if li > 0 else mi.mesh.surface_get_array_len(s)) / 3
		print("%-20s %7d tri  %3d pedaços" % [id, tri, m.get_child_count()])
	print("tempo ", Time.get_ticks_msec() - t0, " ms  memória ", OS.get_static_memory_usage() / 1000000, " MB")
	quit()
