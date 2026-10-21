extends SceneTree
func _initialize() -> void:
	var doc := FBXDocument.new()
	var st := FBXState.new()
	var e := doc.append_from_file(OS.get_cmdline_user_args()[0], st)
	print("err ", e)
	var cena: Node = doc.generate_scene(st)
	var pilha: Array = [[cena, Transform3D()]]
	while not pilha.is_empty():
		var it: Array = pilha.pop_back()
		var n: Node = it[0]
		var t: Transform3D = it[1]
		if n is Node3D and n != cena:
			t = t * (n as Node3D).transform
		if n is MeshInstance3D:
			var im: Mesh = (n as MeshInstance3D).mesh
			for s in im.get_surface_count():
				var a := im.surface_get_arrays(s)
				var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var ab := AABB(t * vs[0], Vector3.ZERO)
				for v in vs:
					ab = ab.expand(t * v)
				var mat := im.surface_get_material(s)
				print(n.name, " s", s, " mat=", mat.resource_name if mat else "-", " v=", vs.size(), " tri=", (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, " aabb=", ab, " skin=", (n as MeshInstance3D).skin != null)
		if n is Skeleton3D:
			var sk := n as Skeleton3D
			print("esqueleto ", sk.get_bone_count(), " t=", t)
		for c in n.get_children():
			pilha.append([c, t])
	quit()
