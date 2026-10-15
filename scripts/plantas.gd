class_name Plantas
## Plantas da Poly Haven (CC0), enviadas pelo Davi como .blend e convertidas sem Blender
## (tools/blend_para_obj.py + tools/montar_plantas.gd): samambaias, tufos de capim
## (verde e seco), tronco morto caído, folhas secas, planta em vaso e pinheiros.

const DIR := "res://assets/plantas/"
static var _malhas := {}

static func malha(nome: String) -> Mesh:
	if not _malhas.has(nome):
		var c := DIR + nome + ".res"
		_malhas[nome] = load(c) if ResourceLoader.exists(c) else null
	return _malhas[nome]

static func _mmi(n: Node3D, nome: String, ts: Array, alcance: float) -> void:
	var m := malha(nome)
	if m == null or ts.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = ts.size()
	for i in ts.size():
		mm.set_instance_transform(i, ts[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.visibility_range_end = alcance
	mi.visibility_range_end_margin = 8.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)

static func _t(p: Vector3, r: RandomNumberGenerator, esc: float) -> Transform3D:
	var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * esc)
	return Transform3D(b, p)

## Plantas rasteiras de um trecho: samambaias na mata, tufos de capim na beira da estrada,
## tronco caído e folhas secas. Tudo em MultiMesh (barato) e some de longe.
static func trecho(m: WorldGen, n: Node3D, z0: float, k: int, bio: String) -> void:
	if malha("samambaia_a") == null:
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash([m.semente, k, "plantas"])
	var seco := bio in ["industrial", "cidade"] or m.reg.param(z0, "capim") < 0.6
	var sam := {"samambaia_a": [], "samambaia_b": [], "samambaia_c": [], "samambaia_d": []}
	var cap := {"alto": [], "baixo": [], "medio": []}
	var hw := WorldGen.LARG_ESTRADA * 0.5
	var tem_agua := not m._rio_em(z0 + WorldGen.TAM * 0.5).is_empty() or bio == "alagado"
	# samambaias: onde a mata é fechada (e um pouco na beira da estrada, na sombra)
	if bio != "cidade":
		for i in 60:
			var z := z0 + r.randf() * WorldGen.TAM
			var lado := 1.0 if r.randf() > 0.5 else -1.0
			var x := m.centro_x(z) + lado * (hw + 3.0 + pow(r.randf(), 1.5) * 45.0)
			if m.floresta_rapida(x, z) < 0.35 and r.randf() < 0.85:
				continue
			if m.perto_de_feature(x, z, 3.0):
				continue
			var y := m.altura(x, z)
			if tem_agua and y < m.agua_em(x, z) - 0.2:
				continue
			var v: String = sam.keys()[r.randi() % 4]
			sam[v].append(_t(Vector3(x, y - 0.03, z), r, r.randf_range(1.6, 2.6)))
	# tufos de capim de verdade, mais densos junto do acostamento
	for i in 70:
		var z := z0 + r.randf() * WorldGen.TAM
		var lado := 1.0 if r.randf() > 0.5 else -1.0
		var x := m.centro_x(z) + lado * (hw + 1.7 + pow(r.randf(), 2.0) * 22.0)
		if m.perto_de_feature(x, z, 2.0):
			continue
		var y := m.altura(x, z)
		if tem_agua and y < m.agua_em(x, z) - 0.2:
			continue
		var v: String = ["alto", "alto", "baixo", "medio"][r.randi() % 4]
		cap[v].append(_t(Vector3(x, y - 0.02, z), r, r.randf_range(2.4, 3.8)))
	for v in sam:
		_mmi(n, v, sam[v], 55.0)
	for v in cap:
		_mmi(n, ("capim_seco_" if seco else "capim_") + v, cap[v], 45.0)
	# tronco morto caído na mata, com folhas secas em volta
	if bio != "cidade" and r.randf() < 0.45:
		var z := z0 + r.randf_range(6.0, WorldGen.TAM - 6.0)
		var lado := 1.0 if r.randf() > 0.5 else -1.0
		var x := m.centro_x(z) + lado * r.randf_range(hw + 6.0, hw + 30.0)
		if not m.perto_de_feature(x, z, 5.0):
			var y := m.altura(x, z)
			var mi := MeshInstance3D.new()
			mi.mesh = malha("tronco_morto")
			if mi.mesh:
				mi.position = Vector3(x, y - 0.15, z)
				mi.rotation.y = r.randf() * TAU
				mi.scale = Vector3.ONE * r.randf_range(1.2, 1.6)
				mi.visibility_range_end = 120.0
				mi.set_meta("nao_mesclar", true)
				n.add_child(mi)
				var fs: Array = []
				for q in r.randi_range(4, 9):
					var a := r.randf() * TAU
					var d := r.randf_range(0.6, 2.4)
					var p := Vector3(x + cos(a) * d, 0, z + sin(a) * d)
					p.y = m.altura(p.x, p.z) - 0.02
					var b := Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5 + r.randf_range(-0.2, 0.2))
					fs.append(Transform3D(b.scaled(Vector3.ONE * r.randf_range(1.2, 2.0)), p + Vector3(0, 0.03, 0)))
				_mmi(n, "babosa_seca_a", fs.slice(0, fs.size() / 2), 40.0)
				_mmi(n, "babosa_seca_b", fs.slice(fs.size() / 2), 40.0)

## Pinheiro (árvore inteira) para a mata.
static func pinheiro(n: Node3D, p: Vector3, r: RandomNumberGenerator) -> bool:
	var m := malha("pinheiro_c" if r.randf() < 0.6 else "pinheiro_b")
	if m == null:
		return false
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = p
	mi.rotation.y = r.randf() * TAU
	mi.scale = Vector3.ONE * r.randf_range(0.85, 1.2)
	mi.visibility_range_end = 380.0
	mi.set_meta("nao_mesclar", true)
	n.add_child(mi)
	return true

## Planta em vaso (quintais e varandas).
static func vaso(n: Node3D, p: Vector3, r: RandomNumberGenerator) -> bool:
	var m := malha("vaso_planta")
	if m == null:
		return false
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = p
	mi.rotation.y = r.randf() * TAU
	mi.scale = Vector3.ONE * r.randf_range(0.8, 1.1)
	mi.visibility_range_end = 60.0
	mi.set_meta("nao_mesclar", true)
	n.add_child(mi)
	return true
