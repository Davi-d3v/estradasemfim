class_name Objetos3D
## Modelos escaneados do ambientCG (CC0), reduzidos em tools/reduzir_modelos.gd:
## maçã, pão de sementes, baguete, melancia e toco de árvore.

const NOMES := {"maca": "apple001", "pao": "bread001", "baguete": "bread011", "melancia": "melon001", "toco": "treestump001"}
static var _malhas := {}
static var _mats := {}

static func _carregar(id: String) -> Array:
	if not _malhas.has(id):
		var n: String = NOMES[id]
		var caminho := "res://assets/modelos/%s.res" % n
		if not ResourceLoader.exists(caminho):
			_malhas[id] = null
		else:
			_malhas[id] = load(caminho)
			var m := StandardMaterial3D.new()
			m.albedo_texture = load("res://assets/modelos/%s_cor.jpg" % n)
			m.normal_enabled = true
			m.normal_texture = load("res://assets/modelos/%s_normal.jpg" % n)
			m.roughness = 0.85 if id in ["pao", "baguete", "toco"] else 0.45
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if id == "toco":
				m.albedo_color = Color(0.62, 0.6, 0.5)   # foto clara demais para o chão do jogo
			_mats[id] = m
	return [_malhas[id], _mats.get(id)]

## Põe um objeto: pos no chão/apoio, giro em graus no Y, escala uniforme.
static func por(pai: Node3D, id: String, pos: Vector3, giro := 0.0, escala := 1.0, alcance := 40.0) -> MeshInstance3D:
	var d := _carregar(id)
	if d[0] == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = d[0]
	mi.material_override = d[1]
	mi.position = pos
	mi.rotation_degrees.y = giro
	mi.scale = Vector3.ONE * escala
	mi.visibility_range_end = alcance          # coisa pequena: some de longe
	mi.set_meta("nao_mesclar", true)
	if id != "toco":
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi

## Um punhado de comida (cesto de feira, despensa, mesa).
static func monte(pai: Node3D, centro: Vector3, r: RandomNumberGenerator, n := 5, raio := 0.18) -> void:
	var tipos := ["maca", "maca", "maca", "pao", "baguete"]
	for i in n:
		var a := r.randf() * TAU
		var d := r.randf() * raio
		por(pai, tipos[r.randi() % tipos.size()], centro + Vector3(cos(a) * d, 0, sin(a) * d), r.randf() * 360.0, r.randf_range(0.9, 1.1), 30.0)
