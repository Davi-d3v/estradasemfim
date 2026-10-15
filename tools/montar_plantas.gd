extends SceneTree
## Monta as plantas da Poly Haven (convertidas do .blend por tools/blend_para_obj.py)
## em malhas do Godot com materiais e níveis de detalhe (LOD) automáticos.
## Uso: godot --headless --script res://tools/montar_plantas.gd

const I := "res://_imp_plantas/"
const P := "res://assets/plantas/"

func mat(pasta: String, folha: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var cor := P + pasta + ("/cor.png" if FileAccess.file_exists(P + pasta + "/cor.png") else "/cor.jpg")
	m.albedo_texture = load(cor)
	if FileAccess.file_exists(P + pasta + "/normal.jpg"):
		m.normal_enabled = true
		m.normal_texture = load(P + pasta + "/normal.jpg")
	m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if folha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		m.backlight_enabled = true
		m.backlight = Color(0.25, 0.3, 0.15)
	if pasta == "pinheiro_galho":
		m.albedo_color = Color(0.5, 0.68, 0.45)     # a foto é amarelada demais contra a mata do jogo
	if pasta == "capim":
		m.albedo_color = Color(0.85, 0.9, 0.7)
	ResourceSaver.save(m, P + pasta + "/material.tres")
	return load(P + pasta + "/material.tres")

func superficie(im: ImporterMesh, obj: String, m: Material, alvo := 0) -> void:
	var src: Mesh = load(I + obj)
	var st := SurfaceTool.new()
	st.create_from(src, 0)
	st.index()
	if alvo > 0:
		var arr := st.commit_to_arrays()
		var idx := st.generate_lod(1.0, alvo * 3)
		arr[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		st = SurfaceTool.new()
		st.create_from(am, 0)
	st.generate_normals()
	st.generate_tangents()
	var a := st.commit_to_arrays()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, m)

func salvar(im: ImporterMesh, nome: String) -> void:
	im.generate_lods(25.0, 60.0, [])
	var mesh := im.get_mesh()
	ResourceSaver.save(mesh, P + nome + ".res")
	var tri := 0
	for s in mesh.get_surface_count():
		tri += mesh.surface_get_array_index_len(s) / 3
	print("%s: %d superfícies, %d triângulos, aabb %s" % [nome, mesh.get_surface_count(), tri, mesh.get_aabb().size.snapped(Vector3.ONE * 0.01)])

func _init() -> void:
	var m_sam := mat("samambaia", true)
	for v in ["a", "b", "c", "d"]:
		var im := ImporterMesh.new()
		superficie(im, "fern/fern_02_%s__fern_02.obj" % v, m_sam)
		salvar(im, "samambaia_" + v)
	var m_cap := mat("capim", true)
	var m_cs := mat("capim_seco", true)
	var capins := {"grande": "large_a_LOD2", "medio": "mid_a_LOD1", "alto": "tall_a_LOD1", "baixo": "small_a_LOD1"}
	for k in capins:
		var im := ImporterMesh.new()
		superficie(im, "grass/grass_medium_01_geonodes_%s__grass_medium_01.obj" % capins[k], m_cap)
		salvar(im, "capim_" + k)
		var im2 := ImporterMesh.new()
		superficie(im2, "grass/grass_medium_01_geonodes_%s__grass_medium_01.obj" % capins[k], m_cs)
		salvar(im2, "capim_seco_" + k)
	var im3 := ImporterMesh.new()
	superficie(im3, "trunk/dead_tree_trunk_02_LOD3__dead_tree_trunk_02.obj", mat("tronco_morto", false))
	salvar(im3, "tronco_morto")
	var m_bab := mat("babosa_seca", false)
	for v in ["a", "b"]:
		var im4 := ImporterMesh.new()
		superficie(im4, "quiver/dry_quiver_leaf_%s_LOD3__dry_quiver_leaf.obj" % v, m_bab)
		salvar(im4, "babosa_seca_" + v)
	var im5 := ImporterMesh.new()
	var m_vaso := mat("vaso", false)
	superficie(im5, "potted/potted_plant_02_pot__potted_plant_02_pot.obj", m_vaso)
	superficie(im5, "potted/potted_plant_02_dirt__potted_plant_02_pot.obj", m_vaso, 600)
	superficie(im5, "potted/potted_plant_02_leaves__potted_plant_02_leaves.obj", mat("vaso_folhas", true))
	salvar(im5, "vaso_planta")
	var m_casca := mat("pinheiro_casca", false)
	var m_galho := mat("pinheiro_galho", true)
	for v in ["b", "c"]:
		var im6 := ImporterMesh.new()
		superficie(im6, "fir/fir_tree_01_%s_LOD2__fir_tree_01_trunk_%s.obj" % [v, v], mat("pinheiro_tronco_" + v, false))
		superficie(im6, "fir/fir_tree_01_%s_LOD2__fir_tree_01_bark.obj" % v, m_casca)
		superficie(im6, "fir/fir_tree_01_%s_LOD2__fir_tree_01_dead_branches.obj" % v, m_casca)
		superficie(im6, "fir/fir_tree_01_%s_LOD2__fir_tree_01_twig.obj" % v, m_galho)
		salvar(im6, "pinheiro_" + v)
	quit()
