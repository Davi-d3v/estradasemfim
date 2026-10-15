class_name Floresta
## Malhas das árvores e do sub-bosque (uma vez só), usadas com MultiMesh em cada trecho.

static var malhas := {}
static var mat_folhas := {}
static var _shader_folha: Shader

static func folha(estilo: int, a: Color, b: Color) -> ShaderMaterial:
	var k := "%d_%s" % [estilo, a.to_html()]
	if mat_folhas.has(k):
		return mat_folhas[k]
	if _shader_folha == null:
		_shader_folha = load("res://shaders/folha.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader_folha
	m.set_shader_parameter("estilo", estilo)
	m.set_shader_parameter("cor_a", a)
	m.set_shader_parameter("cor_b", b)
	mat_folhas[k] = m
	return m

## Junta uma árvore montada com primitivas numa única malha (uma superfície por material).
static func _juntar(raiz: Node3D) -> ArrayMesh:
	var grupos := {}
	var ordem: Array = []
	_coletar(raiz, Transform3D.IDENTITY, grupos, ordem)
	var malha := ArrayMesh.new()
	for mat in ordem:
		var st: SurfaceTool = grupos[mat]
		st.commit(malha)
		malha.surface_set_material(malha.get_surface_count() - 1, mat)
	raiz.free()
	return malha

static func _coletar(n: Node, xf: Transform3D, grupos: Dictionary, ordem: Array) -> void:
	for c in n.get_children():
		var cx: Transform3D = xf * c.transform
		if c is MeshInstance3D:
			var mat: Material = c.material_override
			if not grupos.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				grupos[mat] = st
				ordem.append(mat)
			(grupos[mat] as SurfaceTool).append_from(c.mesh, 0, cx)
		_coletar(c, cx, grupos, ordem)

static func _cartao(p: Node3D, pos: Vector3, tam: Vector2, rot: Vector3, m: Material) -> void:
	var q := QuadMesh.new()
	q.size = tam
	q.center_offset = Vector3(0, tam.y * 0.5, 0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)

## Árvores e arbustos são modelos da Poly Haven (assets/plantas/arv_*.res).
## "tipo:variante" escolhe a variante (ex.: "folhosa:b").
const MODELOS := {
	"pinheiro": ["arv_abeto_b", "arv_abeto_c"],
	"eucalipto": ["arv_abeto_c", "arv_abeto_b"],
	"folhosa": ["arv_pachira_d", "arv_abeto_c", "arv_pachira_a", "arv_abeto_b", "arv_pachira_c"],
	"jeriva": ["arv_pachira_d", "arv_pachira_a"],
	"taquara": ["arv_pinheirinho_a", "arv_pinheirinho_b", "arv_pinheirinho_c"],
	"pinheirinho": ["arv_pinheirinho_a", "arv_pinheirinho_b", "arv_pinheirinho_c"],
	"arbusto": ["arv_arbusto_medium", "arv_arbusto_large", "arv_arbusto_small"],
	"arbusto_seco": ["arv_arbusto_small", "arv_arbusto_medium"],
}

static func variantes(tipo: String) -> int:
	return MODELOS[tipo].size() if MODELOS.has(tipo) else 1

static func malha(tipo: String) -> Mesh:
	if malhas.has(tipo):
		return malhas[tipo]
	var partes := tipo.split(":")
	if MODELOS.has(partes[0]):
		var lista: Array = MODELOS[partes[0]]
		var v := int(partes[1]) if partes.size() > 1 else 0
		var m := Plantas.malha(lista[v % lista.size()])
		if m:
			malhas[tipo] = m
			return m
	var r := RandomNumberGenerator.new()
	r.seed = hash(tipo)
	var raiz := Node3D.new()
	var casca := Texturas.material("casca", Color(0.32, 0.25, 0.19))
	match tipo:
		"pinheiro":
			var h := 14.0
			B.cyl(raiz, 0.28, h, Vector3(0, h * 0.5, 0), casca, Vector3.ZERO, 7, 0.08)
			var ag := folha(1, Color(0.07, 0.13, 0.07), Color(0.13, 0.2, 0.09))
			for k in 9:
				var y := h * 0.38 + k * (h * 0.62 / 9.0)
				var raio := lerpf(2.6, 0.5, float(k) / 9.0)
				for i in 7:
					var a := TAU * i / 7.0 + k * 0.5
					_cartao(raiz, Vector3(0, y, 0), Vector2(1.0, raio), Vector3(-1.2, a, 0), ag)
			_cartao(raiz, Vector3(0, h - 0.6, 0), Vector2(0.6, 1.4), Vector3(0, 0, 0), ag)
			_cartao(raiz, Vector3(0, h - 0.6, 0), Vector2(0.6, 1.4), Vector3(0, PI * 0.5, 0), ag)
		"folhosa":
			var h := 9.0
			B.cyl(raiz, 0.32, h * 0.6, Vector3(0, h * 0.3, 0), casca, Vector3(3, 0, 2), 7, 0.2)
			var fo := folha(0, Color(0.1, 0.17, 0.06), Color(0.22, 0.3, 0.1))
			for i in 5:
				var a := TAU * i / 5.0 + r.randf() * 0.5
				var g := B.cyl(raiz, 0.12, 3.6, Vector3(cos(a) * 0.9, h * 0.58, sin(a) * 0.9), casca, Vector3.ZERO, 5, 0.05)
				g.rotation = Vector3(0, -a, 0)
				g.rotate_object_local(Vector3.FORWARD, -0.75)
			for i in 26:
				var a := r.randf() * TAU
				var d := sqrt(r.randf()) * 3.2
				var c := Vector3(cos(a) * d, h * 0.62 + r.randf_range(0.0, 3.0) * (1.0 - d / 4.5), sin(a) * d)
				var t := r.randf_range(1.8, 2.8)
				_cartao(raiz, c - Vector3(0, t * 0.5, 0), Vector2(t, t), Vector3(r.randf_range(-0.6, 0.6), r.randf() * TAU, 0), fo)
				_cartao(raiz, c - Vector3(0, t * 0.5, 0), Vector2(t, t), Vector3(r.randf_range(-0.6, 0.6), r.randf() * TAU, 0), fo)
		"eucalipto":
			var h := 18.0
			B.cyl(raiz, 0.24, h, Vector3(0, h * 0.5, 0), Texturas.material("casca", Color(0.62, 0.58, 0.5)), Vector3.ZERO, 7, 0.07)
			var fo2 := folha(0, Color(0.16, 0.22, 0.14), Color(0.3, 0.36, 0.25))
			for i in 14:
				var a := r.randf() * TAU
				var d := r.randf_range(0.3, 2.2)
				var c := Vector3(cos(a) * d, h * 0.7 + r.randf_range(0.0, h * 0.3), sin(a) * d)
				var t := r.randf_range(1.5, 2.4)
				_cartao(raiz, c - Vector3(0, t * 0.5, 0), Vector2(t * 0.8, t), Vector3(r.randf_range(-0.3, 0.3), r.randf() * TAU, 0), fo2)
		"samambaia":
			var sa := folha(2, Color(0.12, 0.22, 0.07), Color(0.25, 0.35, 0.1))
			for i in 9:
				var a := TAU * i / 9.0 + r.randf() * 0.3
				_cartao(raiz, Vector3.ZERO, Vector2(0.45, r.randf_range(0.8, 1.2)), Vector3(-0.9 - r.randf() * 0.4, a, 0), sa)
		"arbusto":
			var ab := folha(0, Color(0.09, 0.15, 0.06), Color(0.18, 0.25, 0.08))
			for i in 7:
				var t := r.randf_range(1.0, 1.6)
				_cartao(raiz, Vector3(r.randf_range(-0.4, 0.4), -0.1, r.randf_range(-0.4, 0.4)), Vector2(t, t), Vector3(r.randf_range(-0.3, 0.3), r.randf() * TAU, 0), ab)
		"tronco_caido":
			var tc := B.cyl(raiz, 0.32, 6.0, Vector3(0, 0.25, 0), casca, Vector3(0, 0, 90), 8, 0.26)
			for i in 3:
				B.cyl(raiz, 0.07, 0.9, Vector3(-2.0 + i * 1.6, 0.55, 0.15), casca, Vector3(40, 0, 20), 5, 0.02)
			var mu := folha(0, Color(0.15, 0.22, 0.08), Color(0.3, 0.35, 0.12))
			_cartao(raiz, Vector3(1.0, 0.3, 0.3), Vector2(1.0, 0.5), Vector3(-1.4, 0, 0), mu)
		"toco":
			B.cyl(raiz, 0.38, 0.7, Vector3(0, 0.35, 0), casca, Vector3.ZERO, 8, 0.33)
			B.cyl(raiz, 0.33, 0.02, Vector3(0, 0.71, 0), Texturas.material("madeira_movel", Color(0.6, 0.48, 0.32)), Vector3.ZERO, 8)
		"capim_alto":
			var ca := folha(2, Color(0.3, 0.32, 0.12), Color(0.55, 0.5, 0.25))
			for i in 7:
				var a := TAU * i / 7.0 + r.randf() * 0.4
				_cartao(raiz, Vector3.ZERO, Vector2(0.35, r.randf_range(0.9, 1.5)), Vector3(-0.25 - r.randf() * 0.3, a, 0), ca)
		"flores":
			var fl := folha(0, Color(0.85, 0.75, 0.15), Color(0.95, 0.9, 0.7))
			var fl2 := folha(0, Color(0.7, 0.25, 0.5), Color(0.9, 0.6, 0.75))
			var haste := folha(2, Color(0.15, 0.28, 0.08), Color(0.28, 0.4, 0.12))
			for i in 6:
				var a := TAU * i / 6.0
				_cartao(raiz, Vector3.ZERO, Vector2(0.25, 0.5), Vector3(-0.4, a, 0), haste)
			for i in 9:
				var c := Vector3(r.randf_range(-0.4, 0.4), r.randf_range(0.35, 0.55), r.randf_range(-0.4, 0.4))
				_cartao(raiz, c, Vector2(0.16, 0.16), Vector3(-1.5, r.randf() * TAU, 0), fl if i % 3 else fl2)
		"taquara":
			var bambu := Texturas.material("casca", Color(0.42, 0.5, 0.22))
			var fb := folha(2, Color(0.15, 0.25, 0.08), Color(0.3, 0.4, 0.14))
			for i in 14:
				var a := r.randf() * TAU
				var d := r.randf() * 0.7
				var h := r.randf_range(4.5, 7.5)
				var cm := B.cyl(raiz, 0.045, h, Vector3(cos(a) * d, h * 0.5, sin(a) * d), bambu, Vector3(r.randf_range(-12, 12), 0, r.randf_range(-12, 12)), 5)
				for q in 4:
					_cartao(raiz, Vector3(cos(a) * d * 1.4, h * (0.55 + q * 0.12), sin(a) * d * 1.4), Vector2(0.5, 1.4), Vector3(-1.0, r.randf() * TAU, 0), fb)
		"jeriva":
			var h := 9.0
			B.cyl(raiz, 0.2, h, Vector3(0, h * 0.5, 0), Texturas.material("casca", Color(0.45, 0.42, 0.38)), Vector3(2, 0, 0), 8, 0.17)
			var fj := folha(2, Color(0.12, 0.22, 0.08), Color(0.28, 0.38, 0.14))
			for i in 12:
				var a := TAU * i / 12.0
				_cartao(raiz, Vector3(0, h - 0.2, 0), Vector2(0.9, 3.6), Vector3(-0.6 - r.randf() * 0.9, a, 0), fj)
			B.sphere(raiz, 0.4, Vector3(0.2, h - 0.6, 0), Texturas.material("casca", Color(0.75, 0.45, 0.12)), Vector3(0.7, 1.4, 0.7), 6)
		"cogumelos":
			var chapeu := B.mat(Color(0.75, 0.62, 0.45), 0.8)
			var pe := B.mat(Color(0.88, 0.85, 0.78), 0.9)
			for i in 5:
				var c := Vector3(r.randf_range(-0.3, 0.3), 0, r.randf_range(-0.3, 0.3))
				var h := r.randf_range(0.08, 0.18)
				B.cyl(raiz, 0.02, h, c + Vector3(0, h * 0.5, 0), pe, Vector3.ZERO, 5)
				B.sphere(raiz, 0.07, c + Vector3(0, h, 0), chapeu, Vector3(1, 0.5, 1), 6)
		"arbusto_seco":
			var sec := Texturas.material("casca", Color(0.4, 0.32, 0.22))
			for i in 10:
				var g := B.cyl(raiz, 0.02, r.randf_range(0.8, 1.4), Vector3(0, 0.4, 0), sec, Vector3(r.randf_range(-50, 50), r.randf() * 360.0, r.randf_range(-50, 50)), 4)
			var fs := folha(0, Color(0.32, 0.26, 0.12), Color(0.45, 0.38, 0.18))
			for i in 3:
				_cartao(raiz, Vector3(r.randf_range(-0.3, 0.3), 0.1, r.randf_range(-0.3, 0.3)), Vector2(0.9, 0.9), Vector3(0, r.randf() * TAU, 0), fs)
		"pedra":
			var pd := Texturas.material("pedra", Color(0.45, 0.44, 0.42))
			B.sphere(raiz, 0.8, Vector3(0, 0.2, 0), pd, Vector3(1.4, 0.7, 1.1), 7)
			B.sphere(raiz, 0.5, Vector3(0.8, 0.1, 0.3), pd, Vector3(1.0, 0.6, 1.2), 6)
	var m := _juntar(raiz)
	malhas[tipo] = m
	return m
