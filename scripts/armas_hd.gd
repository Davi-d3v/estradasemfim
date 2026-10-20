class_name ArmasHD
## Armas com modelo detalhado (Sketchfab, enviadas pelo Davi). Cada modelo vem num
## tamanho e numa orientação diferentes; aqui eles são normalizados para o padrão do
## jogo: cano para +X, em cima +Y, origem na empunhadura (onde a mão direita segura),
## em metros reais. Os pontos da mão esquerda (guarda-mão) e da boca do cano ficam
## em metros nesse mesmo espaço.
##
## Dados por arma:
##   arquivo   — glb em assets/
##   esconder  — pedaços do nome de nós a esconder (chão do cenário, peças soltas, pentes extras)
##   frente    — eixo do modelo para onde o cano aponta
##   cima      — eixo do modelo que aponta para cima
##   comprimento — comprimento real em metros (da coronha à boca)
##   mao       — empunhadura: (fração do comprimento a partir da coronha, fração da altura a partir de baixo)
##   apoio     — guarda-mão (mão esquerda), mesmo formato
##   boca      — altura do cano (fração da altura)
##   ombro     — onde a coronha encosta no ombro (mesmo formato de "mao")

const DADOS := {
	"m1911": {"arquivo": "res://assets/armas_hd/m1911.glb", "esconder": [], "frente": Vector3(0, -0.485, 0.875), "cima": Vector3(0, 0.875, 0.485),
		"comprimento": 0.22, "mao": Vector2(0.22, 0.42), "apoio": Vector2(0.2, 0.15), "boca": 0.87},
	"kar98k": {"arquivo": "res://assets/armas_hd/kar98k.glb", "esconder": [], "frente": Vector3(-1, 0, 0), "cima": Vector3(0, 1, 0),
		"comprimento": 1.11, "mao": Vector2(0.281, 0.34), "apoio": Vector2(0.553, 0.40), "boca": 0.555, "ombro": Vector2(0.01, 0.2)},
	"saiga9": {"arquivo": "res://assets/armas_hd/saiga9.glb", "esconder": [], "frente": Vector3(1, 0, 0), "cima": Vector3(0, 1, 0),
		"comprimento": 0.86, "mao": Vector2(0.319, 0.34), "apoio": Vector2(0.60, 0.55), "boca": 0.80, "ombro": Vector2(0.02, 0.47)},
	"acr": {"arquivo": "res://assets/armas_hd/acr.glb", "esconder": ["GroundPlane", "Bullet", "Suppresor", "Scope", "Foregrip", "Pmag"], "frente": Vector3(0.966, 0.259, 0), "cima": Vector3(-0.259, 0.966, 0),
		"comprimento": 1.0, "mao": Vector2(0.30, 0.25), "apoio": Vector2(0.58, 0.55), "boca": 0.74, "ombro": Vector2(0.045, 0.4)},
	"svd": {"arquivo": "res://assets/armas_hd/svd.glb", "esconder": ["Floor", "Bullets", "Laying Mag", "Dragunov 2", "RootNode/Scope"], "frente": Vector3(-1, 0, 0), "cima": Vector3(0, 1, 0),
		"comprimento": 1.22, "mao": Vector2(0.24, 0.30), "apoio": Vector2(0.54, 0.43), "boca": 0.61, "ombro": Vector2(0.015, 0.25)},
	"prototipo": {"arquivo": "res://assets/armas_hd/prototipo.glb", "esconder": [], "frente": Vector3(0, 0, 1), "cima": Vector3(0, 1, 0),
		"comprimento": 0.92, "mao": Vector2(0.39, 0.48), "apoio": Vector2(0.65, 0.58), "boca": 0.71, "ombro": Vector2(0.02, 0.6)},
	"bullpup": {"arquivo": "res://assets/sketchfab_padrao/bullpup.glb", "esconder": [], "frente": Vector3(0, 0, 1), "cima": Vector3(0, 1, 0),
		"comprimento": 0.76, "mao": Vector2(0.51, 0.36), "apoio": Vector2(0.73, 0.50), "boca": 0.54, "ombro": Vector2(0.02, 0.45)},
}

static var _cache := {}   # id -> {base: Transform3D (modelo -> padrão), apoio, boca, ombro}

static func existe(id: String) -> bool:
	return DADOS.has(id) and ResourceLoader.exists(DADOS[id].arquivo)

## Caixa justa dos vértices visíveis, já girados (rot) — girar uma caixa a incharia.
static func _aabb(n: Node, t: Transform3D, d: Dictionary, lim: Array, caminho: String, rot: Basis) -> void:
	var tt := t
	if n is Node3D:
		tt = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and not _escondido(caminho, d):
		var me: Mesh = (n as MeshInstance3D).mesh
		var tr := Transform3D(rot, Vector3.ZERO) * tt
		for s in me.get_surface_count():
			var vs: PackedVector3Array = me.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in vs:
				var p: Vector3 = tr * v
				if lim.is_empty():
					lim.append(p)
					lim.append(p)
				else:
					lim[0] = (lim[0] as Vector3).min(p)
					lim[1] = (lim[1] as Vector3).max(p)
	for c in n.get_children():
		_aabb(c, tt, d, lim, caminho + "/" + c.name, rot)

static func _escondido(caminho: String, d: Dictionary) -> bool:
	for e in d.esconder:
		if caminho.contains(e):
			return true
	return false

static func _esconder(n: Node, d: Dictionary, caminho: String) -> void:
	if n is Node3D and _escondido(caminho, d):
		(n as Node3D).visible = false
		return
	if n is MeshInstance3D:
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_esconder(c, d, caminho + "/" + c.name)

## Calcula (uma vez) a transformação do modelo para o espaço padrão.
static func _preparar(id: String, m: Node3D) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var d: Dictionary = DADOS[id]
	var fx: Vector3 = (d.frente as Vector3).normalized()
	var fy: Vector3 = (d.cima as Vector3).normalized()
	var fz := fx.cross(fy)
	# rotação: eixo "frente" do modelo vira +X, "cima" vira +Y
	var rot := Basis(fx, fy, fz).transposed()
	var lim: Array = []
	_aabb(m, Transform3D(), d, lim, "", rot)
	var mn: Vector3 = lim[0]
	var mx: Vector3 = lim[1]
	var esc: float = float(d.comprimento) / maxf(mx.x - mn.x, 0.0001)
	mn *= esc
	mx *= esc
	var tam := mx - mn
	var ponto := func(v: Vector2) -> Vector3:
		return Vector3(mn.x + tam.x * v.x, mn.y + tam.y * v.y, (mn.z + mx.z) * 0.5)
	var mao: Vector3 = ponto.call(d.mao)
	var r := {
		"base": Transform3D(rot.scaled(Vector3.ONE * esc), -mao),
		"apoio": ponto.call(d.apoio) - mao,
		"boca": Vector3(mx.x, mn.y + tam.y * float(d.boca), (mn.z + mx.z) * 0.5) - mao,
		"ombro": ponto.call(d.get("ombro", Vector2(0.0, 0.5))) - mao,
		"tamanho": tam,
	}
	_cache[id] = r
	return r

## Nó com a arma no espaço padrão (origem na empunhadura, cano +X, cima +Y).
static func montar(id: String) -> Node3D:
	var d: Dictionary = DADOS[id]
	var m: Node3D = (load(d.arquivo) as PackedScene).instantiate()
	var info := _preparar(id, m)
	_esconder(m, d, "")
	var raiz := Node3D.new()
	raiz.name = "ArmaHD"
	m.transform = info.base * m.transform
	raiz.add_child(m)
	raiz.set_meta("apoio", info.apoio)
	raiz.set_meta("boca", info.boca)
	raiz.set_meta("ombro", info.ombro)
	return raiz

static func info(id: String) -> Dictionary:
	if not _cache.has(id):
		var m: Node3D = (load(DADOS[id].arquivo) as PackedScene).instantiate()
		_preparar(id, m)
		m.free()
	return _cache[id]
