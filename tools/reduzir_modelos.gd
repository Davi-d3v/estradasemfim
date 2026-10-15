extends SceneTree
## Reduz os modelos 3D do ambientCG (50 mil+ triângulos) para algo leve para o jogo,
## usando o simplificador do Godot (meshoptimizer). Uso:
##   godot --headless --script res://tools/reduzir_modelos.gd

const ALVOS := {"3DApple001": 1600, "3DBread001": 1800, "3DBread011": 1600, "3DMelon001": 1800, "3DTreeStump001": 9000}

func _init() -> void:
	for nome in ALVOS:
		var m: Mesh = load("res://_imp/%s/m.obj" % nome)
		if m == null:
			print("falhou ", nome)
			continue
		var st := SurfaceTool.new()
		st.create_from(m, 0)
		if nome == "3DTreeStump001":
			# o escaneamento traz um pedaço grande de chão: fica só o toco e as raízes
			var a0 := st.commit_to_arrays()
			var v0: PackedVector3Array = a0[Mesh.ARRAY_VERTEX]
			var n0: PackedVector3Array = a0[Mesh.ARRAY_NORMAL]
			var u0: PackedVector2Array = a0[Mesh.ARRAY_TEX_UV]
			var i0: PackedInt32Array = a0[Mesh.ARRAY_INDEX] if a0[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var topo := Vector3.ZERO
			for v in v0:
				if v.y > topo.y:
					topo = v
			var n_in := i0.size() if i0.size() > 0 else v0.size()
			st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var mapa := {}
			var c := 0
			for t in range(0, n_in, 3):
				var ok := true
				for q in 3:
					var vi: int = i0[t + q] if i0.size() > 0 else t + q
					if Vector2(v0[vi].x - topo.x, v0[vi].z - topo.z).length() > 0.38:
						ok = false
				if not ok:
					continue
				for q in 3:
					var vi: int = i0[t + q] if i0.size() > 0 else t + q
					if not mapa.has(vi):
						mapa[vi] = c
						c += 1
						st.set_normal(n0[vi])
						st.set_uv(u0[vi])
						st.add_vertex(v0[vi] - Vector3(topo.x, 0, topo.z))
					st.add_index(mapa[vi])
		st.index()
		var arr := st.commit_to_arrays()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var alvo: int = ALVOS[nome] * 3
		var novo := st.generate_lod(2.0, alvo)
		# compacta: só os vértices usados
		var mapa := {}
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		var nidx := PackedInt32Array()
		var cont := 0
		for i in novo:
			if not mapa.has(i):
				mapa[i] = cont
				cont += 1
				st2.set_normal(ns[i])
				st2.set_uv(uvs[i])
				st2.add_vertex(vs[i])
			st2.add_index(mapa[i])
		st2.generate_tangents()
		var fim := st2.commit()
		print("%s: %d -> %d triângulos" % [nome, idx.size() / 3, novo.size() / 3])
		ResourceSaver.save(fim, "res://assets/modelos/%s.res" % nome.to_lower().replace("3d", ""))
	quit()
