extends SceneTree
## Monta as árvores da Poly Haven (reduzidas por tools/reduzir_arvore.py, em res://_imp_arv/)
## em malhas com LOD automático. Uso: godot --headless --script res://tools/montar_arvores.gd

const I := "res://_imp_arv/"
const P := "res://assets/plantas/"

func mat(pasta: String, folha: bool, recorte := false) -> Material:
	var caminho := P + pasta + "/material.tres"
	var m := StandardMaterial3D.new()
	var cor := P + pasta + ("/cor.png" if FileAccess.file_exists(P + pasta + "/cor.png") else "/cor.jpg")
	m.albedo_texture = load(cor)
	if FileAccess.file_exists(P + pasta + "/normal.jpg"):
		m.normal_enabled = true
		m.normal_texture = load(P + pasta + "/normal.jpg")
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if folha:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		m.backlight_enabled = true
		m.backlight = Color(0.2, 0.25, 0.12)
		if recorte:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.4
	if pasta == "pinheiro_galho":
		m.albedo_color = Color(0.5, 0.68, 0.45)
	ResourceSaver.save(m, caminho)
	return load(caminho)

func sup(im: ImporterMesh, obj: String, m: Material, alvo := 0, escala := 1.0) -> void:
	var src: Mesh = load(I + obj)
	if src == null:
		print("falta ", obj)
		return
	var st := SurfaceTool.new()
	st.create_from(src, 0)
	st.index()
	if alvo > 0 and src.surface_get_array_index_len(0) / 3 > alvo:
		var arr := st.commit_to_arrays()
		arr[Mesh.ARRAY_INDEX] = st.generate_lod(2.0, alvo * 3)
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		st = SurfaceTool.new()
		st.create_from(am, 0)
	if escala != 1.0:
		var a2 := st.commit_to_arrays()
		var vs: PackedVector3Array = a2[Mesh.ARRAY_VERTEX]
		for i in vs.size():
			vs[i] *= escala
		a2[Mesh.ARRAY_VERTEX] = vs
		var am2 := ArrayMesh.new()
		am2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
		st = SurfaceTool.new()
		st.create_from(am2, 0)
	st.generate_normals()
	st.generate_tangents()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays(), [], {}, m)

func salvar(im: ImporterMesh, nome: String) -> void:
	im.generate_lods(25.0, 60.0, [])
	var mesh := im.get_mesh()
	ResourceSaver.save(mesh, P + nome + ".res")
	var tri := 0
	for s in mesh.get_surface_count():
		tri += mesh.surface_get_array_index_len(s) / 3
	print("%s: %d triângulos, tamanho %s" % [nome, tri, mesh.get_aabb().size.snapped(Vector3.ONE * 0.1)])

func _init() -> void:
	var mc := mat("pinheirinho_casca", false)
	var mg := mat("pinheirinho_galho", true)
	for v in ["a", "b", "c"]:
		var im := ImporterMesh.new()
		sup(im, "pinheirinho/pine_sapling_small_%s__pine_sapling_small_bark.obj" % v, mc, 0, 1.6)
		sup(im, "pinheirinho/pine_sapling_small_%s__pine_sapling_small_twig.obj" % v, mg, 0, 1.6)
		salvar(im, "arv_pinheirinho_" + v)
	# pine_sapling_medium ficou de fora: as agulhas são geometria (2,6 milhões de triângulos) e ralas demais reduzidas
	var mc3 := mat("pachira_casca", false)
	var mf3 := mat("pachira_folhas", true)
	for v in ["a", "b", "c", "d"]:
		var im := ImporterMesh.new()
		# a pachira do arquivo é de vaso (1-2 m): no jogo vira árvore de copa (x4)
		sup(im, "pachira/pachira_aquatica_01_bark_%s__pachira_aquatica_01_bark.obj" % v, mc3, 2000, 4.2)
		sup(im, "pachira/pachira_aquatica_01_leaves_%s__pachira_aquatica_01_leaves.obj" % v, mf3, 0, 4.2)
		salvar(im, "arv_pachira_" + v)
	var md := mat("didelta", true)
	for v in ["large", "medium", "small"]:
		var im := ImporterMesh.new()
		sup(im, "didelta/didelta_spinosa_%s_LOD0__didelta_spinosa.obj" % v, md, 0, 1.3)
		salvar(im, "arv_arbusto_" + v)
	var mcasca: Material = load(P + "pinheiro_casca/material.tres")
	var mgalho := mat("pinheiro_galho", true, true)
	for v in ["b", "c"]:
		var im := ImporterMesh.new()
		sup(im, "abeto/fir_tree_01_%s_LOD2__fir_tree_01_trunk_%s.obj" % [v, v], load(P + "pinheiro_tronco_%s/material.tres" % v), 2500)
		sup(im, "abeto/fir_tree_01_%s_LOD2__fir_tree_01_bark.obj" % v, mcasca, 1500)
		sup(im, "abeto/fir_tree_01_%s_LOD2__fir_tree_01_dead_branches.obj" % v, mcasca, 800)
		sup(im, "abeto/fir_tree_01_%s_LOD2__fir_tree_01_twig.obj" % v, mgalho)
		salvar(im, "arv_abeto_" + v)
	quit()
