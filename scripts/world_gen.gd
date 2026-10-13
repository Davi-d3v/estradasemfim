class_name WorldGen
extends Node3D
## Gera a estrada infinita e o mundo em volta, em pedaços (chunks) ao longo de +Z.
## Tudo é determinístico a partir da semente: o mesmo trecho sempre volta igual.

const TAM := 64.0          # comprimento de cada pedaço
const LARG_ESTRADA := 8.0
const ALCANCE_X := 300.0
const PASSO_TERRENO := 4.0
const ATRAS := 3
const FRENTE := 7

@export var semente := 2026
@export var densidade_capim := 5200
@export var gerar_zumbis := true

var _chunks := {}
var _ruido := FastNoiseLite.new()
var _ruido2 := FastNoiseLite.new()
var _ruido3 := FastNoiseLite.new()
var _mat_estrada: ShaderMaterial
var _mat_terreno: ShaderMaterial
var mat_capim: ShaderMaterial
var _mat_terra: ShaderMaterial
var mat_agua: ShaderMaterial
var _malha_capim: ArrayMesh
var _montanhas: MeshInstance3D
## Pontos de interesse forçados (para a cena inicial): índice do chunk -> tipo
var pois_fixos := {}
## Reboques abandonados atualmente gerados no mapa (podem ser engatados).
var reboques_soltos: Array[Reboque] = []
## Reboques já levados pelo jogador: não voltam a aparecer no mesmo trecho.
var reboques_levados := {}
const TIPOS_REBOQUE := ["armazem", "tanque", "oficina", "estufa", "plataforma", "apartamentos"]
## Estado salvo de reboques abandonados (consertos/saque continuam se você voltar).
var estado_reboques := {}
## Carros abandonados gerados (para desmontar) e os que já foram desmontados.
var carros_soltos: Array[Node3D] = []
var carros_desmontados := {}
## Regiões, biomas e lugares.
var reg: Regioes
var _feats := {}            # índice da região -> Array de features (estradas de terra, platôs, rio, barreira)
## Pontos para vasculhar (casas, celeiros, galpões...) e moradores, gerados nos lugares.
var vasculhaveis: Array[Node3D] = []
var vasculhados := {}
var recrutados := {}     # chaves de moradores que entraram no comboio (não reaparecem na vila)
var npcs: Array[Node3D] = []
## Zumbis vivos e ruídos recentes (pos, raio, tempo restante).
var zumbis_vivos: Array = []
var animais: Array = []
## Construções em que dá para entrar (Predio).
var estruturas: Array = []
## Muros de assentamento (Assentamento) carregados.
var muros: Array = []
var ruidos: Array = []
## 0 no começo; sobe com assentamentos defendidos e a distância (etapa 4).
var nivel_ameaca := 0.0
## Lugares (vilas, fazendas, ferro-velhos) já gerados como cena, por id.
var lugares_ativos := {}

## Os shaders do chão usam coordenadas do mundo; longe da origem o float perde precisão
## (fica quadriculado). Recentra a cada 2 km.
func ajustar_origem(p: Vector3) -> void:
	var o := Vector2(floor(p.x / 2048.0) * 2048.0, floor(p.z / 2048.0) * 2048.0)
	_mat_terreno.set_shader_parameter("origem", o)

func _init() -> void:
	_ruido.seed = semente
	_ruido.frequency = 0.012
	_ruido.fractal_octaves = 4
	_ruido2.seed = semente + 1
	_ruido2.frequency = 0.05
	_ruido3.seed = semente + 3
	_ruido3.frequency = 0.0045
	_ruido3.fractal_octaves = 3
	reg = Regioes.new(semente)

func definir_semente(s: int) -> void:
	semente = s
	_ruido.seed = s
	_ruido2.seed = s + 1
	_ruido3.seed = s + 3
	reg = Regioes.new(s)
	_feats.clear()
	_rios.clear()

## Barulhos que atraem zumbis. Somem sozinhos.
func atualizar_ruidos(dt: float) -> void:
	for r in ruidos:
		r.t -= dt
	ruidos = ruidos.filter(func(r): return r.t > 0.0)

func _ready() -> void:
	_mat_estrada = ShaderMaterial.new()
	_mat_estrada.shader = load("res://shaders/road.gdshader")
	_mat_estrada.set_shader_parameter("largura", LARG_ESTRADA)
	_mat_terreno = ShaderMaterial.new()
	_mat_terreno.shader = load("res://shaders/terrain.gdshader")
	mat_capim = ShaderMaterial.new()
	mat_capim.shader = load("res://shaders/grass.gdshader")
	_malha_capim = _criar_malha_capim()
	_mat_terra = ShaderMaterial.new()
	_mat_terra.shader = load("res://shaders/dirt.gdshader")
	mat_agua = ShaderMaterial.new()
	mat_agua.shader = load("res://shaders/agua.gdshader")
	_criar_montanhas()

# ------------------------------------------------------------ funções do mundo
func centro_x(z: float) -> float:
	var c := reg.param(z, "curva")
	return c * (14.0 * sin(z * 0.0042) + 5.0 * sin(z * 0.011 + 1.3)) - 5.0 * sin(1.3)

func elevacao(z: float) -> float:
	var e := reg.param(z, "elev")
	return e * (2.5 * sin(z * 0.006) + 1.2 * sin(z * 0.017 + 0.5))

const VIES_FLORESTA := {"rural": 0.06, "serra": 0.26, "cidade": -1.0, "industrial": -0.6, "alagado": -0.02}

## Quanto o ponto é floresta (0..1): manchas grandes de mata longe da estrada.
func floresta(x: float, z: float) -> float:
	var mx := reg.mistura(z)
	var vies := lerpf(VIES_FLORESTA[mx[0]], VIES_FLORESTA[mx[1]], mx[2])
	if vies < -0.5:
		return 0.0
	var n := _ruido3.get_noise_2d(x, z) * 0.5 + 0.5
	var d := absf(x - centro_x(z))
	return smoothstep(0.5 - vies, 0.62 - vies, n) * smoothstep(13.0, 28.0, d)

## Terreno sem as áreas aplainadas (estradas de terra, platôs). Inclui rios.
func altura_base(x: float, z: float) -> float:
	var d := absf(x - centro_x(z))
	var base := elevacao(z)
	var amp := reg.param(z, "morro")
	var morro := (_ruido.get_noise_2d(x, z) * 0.5 + 0.5) * amp - 3.0 * minf(amp / 14.0, 1.0)
	var t := smoothstep(LARG_ESTRADA * 0.5 + 3.0, 45.0, d)
	var vala := -0.45 * (smoothstep(7.0, 8.0, d) * (1.0 - smoothstep(9.0, 11.0, d)))
	var h := base - 0.05 + (morro + reg.param(z, "baixa")) * t + vala + _ruido2.get_noise_2d(x, z) * 0.25 * t
	var rio := _rio_em(z)
	if not rio.is_empty():
		var dz := absf(z - rio.z)
		if dz < rio.largura * 0.5 + 10.0:
			var prof: float = rio.prof
			if absf(x - rio.vau_x) < 7.0:
				prof = rio.prof_vau
			var cava := 1.0 - smoothstep(rio.largura * 0.5 - 2.0, rio.largura * 0.5 + 8.0, dz)
			h = lerpf(h, rio.margem - prof, cava)
	return h

func altura(x: float, z: float) -> float:
	var h := altura_base(x, z)
	for f in _features(reg.indice(z)):
		var bb: Rect2 = f.bb
		if not bb.has_point(Vector2(x, z)):
			continue
		match f.tipo:
			"estrada":
				var res := _dist_caminho(f.pts, x, z)
				var w := 1.0 - smoothstep(f.get("aplaina", 2.6), f.get("aplaina", 2.6) * 3.4, res.x)
				if w > 0.0:
					h = lerpf(h, res.y - 0.04, w)
			"plato":
				var dd := Vector2(x - f.c.x, z - f.c.z).length()
				var w2 := 1.0 - smoothstep(f.raio, f.raio + 16.0, dd)
				if w2 > 0.0:
					h = lerpf(h, f.c.y, w2)
	return h

## Distância (x) até um caminho e a altura do caminho no ponto mais próximo (y).
func _dist_caminho(pts: PackedVector3Array, x: float, z: float) -> Vector2:
	var melhor := 1e9
	var y := 0.0
	var p := Vector2(x, z)
	for i in pts.size() - 1:
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[i + 1].x, pts[i + 1].z)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < melhor:
			melhor = d
			y = lerpf(pts[i].y, pts[i + 1].y, t)
	return Vector2(melhor, y)

func direcao(z: float) -> Vector3:
	return Vector3(centro_x(z + 1.0) - centro_x(z - 1.0), 0, 2.0).normalized()

func ponto_estrada(z: float, lateral := 0.0) -> Vector3:
	var dir := direcao(z)
	var dir_lado := Vector3(dir.z, 0, -dir.x)
	var p := Vector3(centro_x(z), elevacao(z) + 0.06, z) + dir_lado * -lateral
	return p

# ------------------------------------------------------------ regiões e features
func regiao_em(z: float) -> int:
	return reg.indice(z)

func _rio_em(z: float) -> Dictionary:
	var i := reg.indice(z)
	var m := reg.marco(i)
	if m.tipo != "ponte" or absf(z - m.z) > 40.0:
		return {}
	return _dados_rio(i)

var _rios := {}
func _dados_rio(i: int) -> Dictionary:
	if _rios.has(i):
		return _rios[i]
	var m := reg.marco(i)
	var margem := elevacao(m.z) - 2.6
	var d := {"z": m.z, "largura": 22.0, "prof": 3.2, "prof_vau": 0.95, "margem": margem,
		"agua": margem - 0.45, "vau_x": centro_x(m.z) + m.lado * 55.0}
	_rios[i] = d
	return d

## Nível da água num ponto (rio ou várzea), ou -INF se não houver água.
func agua_em(x: float, z: float) -> float:
	var rio := _rio_em(z)
	if not rio.is_empty() and absf(z - rio.z) < rio.largura * 0.5 + 4.0:
		return rio.agua
	var mx := reg.mistura(z)
	var b: String = mx[0] if mx[2] < 0.5 else mx[1]
	if b == "alagado":
		return elevacao(z) - 0.55
	return -INF

func _features(i: int) -> Array:
	if _feats.has(i):
		return _feats[i]
	var lista: Array = []
	_feats[i] = lista   # evita recursão enquanto calcula
	var hw := LARG_ESTRADA * 0.5
	for j in reg.juncoes(i):
		var dir := direcao(j.z)
		var lado_v: Vector3 = Vector3(dir.z, 0, -dir.x) * -float(j.lado)
		var s0 := ponto_estrada(j.z, j.lado * (hw + 0.2))
		var zf: float = j.z + j.avanco
		var cpos := ponto_estrada(zf, j.lado * j.afast)
		var c1: Vector3 = s0 + lado_v * float(j.afast) * 0.55
		var c2: Vector3 = cpos - direcao(zf) * float(j.avanco) * 0.45 + lado_v * float(j.curva)
		var y_c := 0.0
		for k in 9:
			var a := TAU * k / 9.0
			y_c += altura_base(cpos.x + cos(a) * 12.0 * float(k > 0), cpos.z + sin(a) * 12.0 * float(k > 0))
		y_c = y_c / 9.0 + 0.1
		var agua := agua_em(cpos.x, cpos.z)
		y_c = maxf(y_c, agua + 0.5)
		cpos.y = y_c
		var raio := {"vila": 44.0, "fazenda": 36.0, "ferro_velho": 28.0, "assentamento": 54.0}[j.tipo] as float
		var pts := _bezier(s0, c1, c2, cpos - (cpos - c2).normalized() * (raio - 4.0), elevacao(j.z) + 0.02, y_c, cpos, raio)
		lista.append(_feat_estrada(pts, j.id))
		var pl := {"tipo": "plato", "c": cpos, "raio": raio, "id": j.id, "juncao": j, "livre": Assentamento.R + 6.0 if j.tipo == "assentamento" else raio}
		pl.bb = Rect2(cpos.x - raio - 20.0, cpos.z - raio - 20.0, (raio + 20.0) * 2.0, (raio + 20.0) * 2.0)
		lista.append(pl)
	# lugares escondidos na mata, ligados à estrada por trilhas a pé
	var rf := RandomNumberGenerator.new()
	rf.seed = hash([semente, i, "mata"])
	var zf := reg.inicio(i) + rf.randf_range(400.0, 900.0)
	var nf := 0
	var tipos_mata := ["cabana", "acampamento", "torre", "carro_mata", "serraria", "cabana", "acampamento"]
	var nomes_mata := {"cabana": "Cabana de caça", "acampamento": "Acampamento abandonado", "torre": "Torre de vigia florestal", "carro_mata": "Carro acidentado na mata", "serraria": "Serraria"}
	while zf < reg.marco(i).z - 600.0:
		var lado_f := 1.0 if rf.randf() < 0.5 else -1.0
		var lat_f := rf.randf_range(55.0, 140.0)
		var cpf := ponto_estrada(zf + rf.randf_range(20.0, 60.0), lado_f * lat_f)
		var tipo_f: String = tipos_mata[rf.randi() % tipos_mata.size()]
		var sem_f := rf.randi()
		var livre_f := true
		for f in lista:
			if f.tipo == "plato" and Vector2(cpf.x - f.c.x, cpf.z - f.c.z).length() < f.raio + 40.0:
				livre_f = false
		if livre_f and floresta(cpf.x, cpf.z) > 0.5:
			cpf.y = altura_base(cpf.x, cpf.z) + 0.05
			var raio_f := {"cabana": 12.0, "acampamento": 11.0, "torre": 8.0, "carro_mata": 8.0, "serraria": 16.0}[tipo_f] as float
			var s0f := ponto_estrada(zf, lado_f * (LARG_ESTRADA * 0.5 + 1.5))
			var dirf := (cpf - s0f)
			var meio_f := s0f + dirf * 0.5 + Vector3(dirf.z, 0, -dirf.x).normalized() * rf.randf_range(-15.0, 15.0)
			var ptsf := _bezier(s0f, s0f.lerp(meio_f, 0.6), meio_f.lerp(cpf, 0.4), cpf - dirf.normalized() * (raio_f - 2.0), elevacao(zf), cpf.y)
			var idf := "%d:m%d" % [i, nf]
			lista.append(_feat_estrada(ptsf, idf, 1.8))
			var jf := {"id": idf, "regiao": i, "z": zf, "lado": lado_f, "tipo": tipo_f, "nome": nomes_mata[tipo_f], "semente": sem_f}
			var plf := {"tipo": "plato", "c": cpf, "raio": raio_f, "id": idf, "juncao": jf}
			plf.bb = Rect2(cpf.x - raio_f - 20.0, cpf.z - raio_f - 20.0, (raio_f + 20.0) * 2.0, (raio_f + 20.0) * 2.0)
			lista.append(plf)
			nf += 1
		zf += rf.randf_range(500.0, 1000.0)
	# desvio do marco
	var m := reg.marco(i)
	var lat := 38.0 if m.tipo == "barreira" else 55.0
	var p0 := ponto_estrada(m.z - 160.0, m.lado * (hw + 0.2))
	var p1 := ponto_estrada(m.z - 70.0, m.lado * lat)
	var p2 := ponto_estrada(m.z + 70.0, m.lado * lat)
	var p3 := ponto_estrada(m.z + 160.0, m.lado * (hw + 0.2))
	var pts2 := PackedVector3Array()
	for seg in [[p0, p0 + (p1 - p0) * 0.6, p1 - (p2 - p1) * 0.15, p1], [p1, p1 + (p2 - p1) * 0.33, p2 - (p2 - p1) * 0.33, p2], [p2, p2 + (p2 - p1) * 0.15, p3 - (p3 - p2) * 0.6, p3]]:
		for k in 24:
			var t := k / 24.0
			var q := _bz(seg[0], seg[1], seg[2], seg[3], t)
			pts2.append(Vector3(q.x, 0, q.z))
	pts2.append(Vector3(p3.x, 0, p3.z))
	_alturas_caminho(pts2, elevacao(m.z - 160.0) + 0.02, elevacao(m.z + 160.0) + 0.02)
	lista.append(_feat_estrada(pts2, "desvio:%d" % i))
	return lista

func _bz(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t

func _bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, y_ini: float, y_fim: float, plato_c := Vector3.ZERO, plato_r := 0.0) -> PackedVector3Array:
	var comp := a.distance_to(b) + b.distance_to(c) + c.distance_to(d)
	var n := maxi(int(comp / 5.0), 8)
	var pts := PackedVector3Array()
	for k in n + 1:
		var q := _bz(a, b, c, d, float(k) / n)
		pts.append(Vector3(q.x, 0, q.z))
	_alturas_caminho(pts, y_ini, y_fim, plato_c, plato_r)
	return pts

## Alturas suaves ao longo de um caminho, presas às pontas.
func _alturas_caminho(pts: PackedVector3Array, y_ini: float, y_fim: float, plato_c := Vector3.ZERO, plato_r := 0.0) -> void:
	var ys := PackedFloat32Array()
	for q in pts:
		var y := altura_base(q.x, q.z)
		if plato_r > 0.0:
			# o platô do lugar aplaina o terreno em volta: o caminho segue o mesmo chão
			var dd := Vector2(q.x - plato_c.x, q.z - plato_c.z).length()
			y = lerpf(y, plato_c.y, 1.0 - smoothstep(plato_r, plato_r + 16.0, dd))
		var ag := agua_em(q.x, q.z)
		if ag > -1e8:
			var rio := _rio_em(q.z)
			if rio.is_empty():
				y = maxf(y, ag + 0.3)   # várzea: o aterro fica acima da água
		ys.append(y)
	for rep in 4:
		var nys := ys.duplicate()
		for k in range(1, ys.size() - 1):
			nys[k] = (ys[k - 1] + ys[k] * 2.0 + ys[k + 1]) * 0.25
		ys = nys
	var n := pts.size()
	for k in n:
		var t := float(k) / maxf(n - 1, 1)
		var y := ys[k]
		y = lerpf(y_ini, y, smoothstep(0.0, 0.08, t))
		y = lerpf(y, y_fim, smoothstep(0.92, 1.0, t))
		pts[k] = Vector3(pts[k].x, y, pts[k].z)

func _feat_estrada(pts: PackedVector3Array, id: String, largura := 4.8) -> Dictionary:
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for q in pts:
		mn = Vector2(minf(mn.x, q.x), minf(mn.y, q.z))
		mx = Vector2(maxf(mx.x, q.x), maxf(mx.y, q.z))
	return {"tipo": "estrada", "pts": pts, "id": id, "largura": largura, "aplaina": 2.6 if largura > 3.0 else 1.2, "bb": Rect2(mn - Vector2(12, 12), mx - mn + Vector2(24, 24))}

## Construção que contém o ponto (ou null).
func estrutura_em(p: Vector3, margem := 0.0) -> Predio:
	for e in estruturas:
		if is_instance_valid(e) and e.global_position.distance_squared_to(p) < 900.0 and e.dentro(p, margem):
			return e
	return null

## O movimento atravessa alguma parede de construção?
func colide(a: Vector3, b: Vector3, raio := 0.28, jogador := false) -> bool:
	for mu in muros:
		if is_instance_valid(mu) and mu.global_position.distance_squared_to(b) < 1600.0 and mu.colide(a, b, raio, jogador):
			return true
	for e in estruturas:
		if is_instance_valid(e) and e.global_position.distance_squared_to(b) < 900.0 and e.dentro(b, raio + 0.4):
			if e.colide(a, b, raio):
				return true
	return false

## Cria uma construção apoiada no terreno (base no ponto mais alto da planta).
func criar_predio(pai: Node3D, pos: Vector3, rot_y: float, tipo: String, larg: float, prof: float, andares: int, sem: int, chave: String, cond := -1.0) -> Predio:
	var pr := Predio.new()
	pr.tipo = tipo
	pr.largura = larg
	pr.profundidade = prof
	pr.andares = andares
	pr.semente = sem
	pr.chave = chave
	pr.mundo = self
	pr.condicao = cond if cond >= 0.0 else randf_range(0.25, 0.6)
	var base := -INF
	var minimo := INF
	var xf := Transform3D(Basis(Vector3.UP, rot_y), Vector3(pos.x, 0, pos.z))
	for dx in [-0.5, 0.0, 0.5]:
		for dz in [-0.5, 0.0, 0.5]:
			var q := xf * Vector3(dx * larg, 0, dz * prof)
			var h := altura(q.x, q.z)
			base = maxf(base, h)
			minimo = minf(minimo, h)
	pr.position = Vector3(pos.x, base + 0.12, pos.z)
	pr.rotation.y = rot_y
	pr.set_meta("nao_mesclar", true)
	pai.add_child(pr)
	if base - minimo > 0.2:
		# fundação até o chão
		var f := B.box(pr, Vector3(larg + 0.2, base - minimo + 0.3, prof + 0.2), Vector3(0, -(base - minimo) * 0.5 - 0.12, 0), Texturas.material("concreto", Color(0.5, 0.48, 0.45)))
	return pr

## Está numa estrada de terra?
func em_estrada_de_terra(p: Vector3) -> bool:
	for f in _features(reg.indice(p.z)):
		if f.tipo == "estrada" and (f.bb as Rect2).has_point(Vector2(p.x, p.z)):
			if _dist_caminho(f.pts, p.x, p.z).x < 3.2:
				return true
	return false

## Perto de alguma estrada de terra ou lugar (para não construir prédios em cima).
func perto_de_feature(x: float, z: float, margem: float) -> bool:
	for f in _features(reg.indice(z)):
		var bb: Rect2 = f.bb
		if not bb.grow(margem).has_point(Vector2(x, z)):
			continue
		if f.tipo == "plato":
			if Vector2(x - f.c.x, z - f.c.z).length() < f.get("livre", f.raio) + margem:
				return true
		elif _dist_caminho(f.pts, x, z).x < margem:
			return true
	return false

## O marco bloqueia esta posição? (barreira militar ou ponte quebrada, ou água funda)
func bloqueado(p: Vector3) -> bool:
	var i := reg.indice(p.z)
	var m := reg.marco(i)
	var lat := absf(p.x - centro_x(p.z))
	var dz := absf(p.z - m.z)
	if m.tipo == "barreira" and dz < 2.6 and lat < 30.0:
		return true
	if m.tipo == "ponte" and dz < 5.0 and lat < LARG_ESTRADA * 0.5 + 1.5:
		return true
	var ag := agua_em(p.x, p.z)
	if ag > -1e8 and ag - altura(p.x, p.z) > 1.1:
		return true
	return false

## Lugares de uma região já com posição (para mapa, placas e descoberta).
func lugares_da_regiao(i: int) -> Array:
	var r: Array = []
	for f in _features(i):
		if f.tipo == "plato":
			r.append({"id": f.id, "nome": f.juncao.nome, "tipo": f.juncao.tipo, "pos": f.c, "juncao_z": f.juncao.z, "lado": f.juncao.lado, "raio": f.raio})
	return r

## Lugar em que um ponto está (dentro do platô), ou {}.
func lugar_em(p: Vector3) -> Dictionary:
	for l in lugares_da_regiao(reg.indice(p.z)):
		if Vector2(p.x - l.pos.x, p.z - l.pos.z).length() < l.raio + 4.0:
			return l
	return {}

# ------------------------------------------------------------ atualização
func atualizar(pos: Vector3) -> void:
	var k := int(floor(pos.z / TAM))
	var desejados := {}
	for i in range(k - ATRAS, k + FRENTE + 1):
		desejados[i] = true
		if not _chunks.has(i):
			_chunks[i] = _gerar_chunk(i)
	for i in _chunks.keys():
		if not desejados.has(i):
			for r in reboques_soltos:
				if is_instance_valid(r) and r.has_meta("chunk"):
					var m: Variant = r.get_meta("chunk")
					var ki: int = m if m is int else int(r.get_meta("chunk_k", -999999))
					if ki == i:
						estado_reboques[m] = r.salvar()
						if not (m is int):
							r.queue_free()   # reboque de lugar: filho do mundo, não do chunk
			_chunks[i].queue_free()
			_chunks.erase(i)
	reboques_soltos = reboques_soltos.filter(func(r): return is_instance_valid(r) and not r.is_queued_for_deletion() and not _na_fila(r))
	estruturas = estruturas.filter(func(v): return is_instance_valid(v) and not v.is_queued_for_deletion() and not _na_fila(v))
	vasculhaveis = vasculhaveis.filter(func(v): return is_instance_valid(v) and not v.is_queued_for_deletion() and not _na_fila(v))
	npcs = npcs.filter(func(v): return is_instance_valid(v) and not v.is_queued_for_deletion() and not _na_fila(v))
	zumbis_vivos = zumbis_vivos.filter(func(z): return is_instance_valid(z) and not z.is_queued_for_deletion() and not _na_fila(z))
	animais = animais.filter(func(a): return is_instance_valid(a) and not a.is_queued_for_deletion() and not _na_fila(a))
	carros_soltos = carros_soltos.filter(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion() and not _na_fila(c))
	if _montanhas:
		_montanhas.position = Vector3(pos.x, 0, pos.z)

func _na_fila(n: Node) -> bool:
	var p := n.get_parent()
	while p:
		if p.is_queued_for_deletion():
			return true
		p = p.get_parent()
	return false

func _rng_chunk(k: int, salt := 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([semente, k, salt])
	return r

func bioma_em(z: float) -> String:
	var mx := reg.mistura(z)
	return mx[0] if mx[2] < 0.5 else mx[1]

func _gerar_chunk(k: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Chunk_%d" % k
	add_child(n)
	var z0 := k * TAM
	var zm := z0 + TAM * 0.5
	var bio := bioma_em(zm)
	var ri := reg.indice(zm)
	var marco := reg.marco(ri)
	var perto_marco := absf(zm - marco.z) < 320.0
	_estrada(n, z0)
	_terreno(n, z0)
	_capim(n, z0, k)
	_arvores(n, z0, k)
	if bio != "cidade" or k % 2 == 0:
		_postes(n, z0, k)
	if not perto_marco:
		_carros(n, z0, k)
	match bio:
		"cidade":
			_predios(n, z0, k)
		"industrial":
			_galpoes(n, z0, k)
		"alagado":
			_agua_varzea(n, z0)
	_estradas_terra(n, z0, k)
	if not perto_marco:
		_beira_estrada(n, z0, k, bio)
	if not perto_marco and k > 1:
		Apocalipse.chunk(n, z0, k, self, bio)
	_placas_juncao(n, z0)
	_lugares_no_chunk(n, z0)
	if marco.z >= z0 and marco.z < z0 + TAM:
		if marco.tipo == "barreira":
			_marco_barreira(n, ri, marco)
		else:
			_marco_ponte(n, ri, marco)
	for zp in [marco.z - 420.0, marco.z - 190.0]:
		if zp >= z0 and zp < z0 + TAM:
			_placa_texto(n, zp, LARG_ESTRADA * 0.5 + 2.4, ("PONTE CAÍDA\nDESVIO " if marco.tipo == "ponte" else "BLOQUEIO MILITAR\nDESVIO ") + ("→" if marco.lado > 0 else "←"), Color(0.85, 0.55, 0.1))
	var tipo: String = pois_fixos.get(k, "")
	if tipo == "" and not perto_marco:
		var r := _rng_chunk(k, 99)
		var sorte := r.randf()
		if sorte < 0.14 and bio != "cidade":
			tipo = "posto"
		elif sorte < 0.2:
			tipo = "placa"
		elif sorte < 0.24:
			tipo = "reboque"
		if tipo == "posto" and perto_de_feature(centro_x(z0 + 44.0), z0 + 44.0, 60.0):
			tipo = ""
	if tipo != "":
		for t in tipo.split(","):
			var partes := t.split(":")
			if partes[0] == "reboque":
				_poi_reboque(n, z0, k, partes[1] if partes.size() > 1 else "")
			else:
				call("_poi_" + t, n, z0, k)
	if gerar_zumbis and k != 0:
		_zumbis(n, z0, k)
	if k > 0:
		_animais(n, z0, k, bio)
	var areas := _areas_construidas(n)
	_limpar_vegetacao(n, areas)
	_mata(n, z0, k, areas)
	B.mesclar(n)
	return n

# ------------------------------------------------------------ estrada e terreno
func _estrada(n: Node3D, z0: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var passos := int(TAM / 2.0)
	var hw := LARG_ESTRADA * 0.5
	var rio := _rio_em(z0 + TAM * 0.5)
	for i in passos:
		var za := z0 + i * 2.0
		var zb := za + 2.0
		if not rio.is_empty() and absf(za + 1.0 - rio.z) < 4.5:
			continue
		var la := ponto_estrada(za, -hw)
		var ra := ponto_estrada(za, hw)
		var lb := ponto_estrada(zb, -hw)
		var rb := ponto_estrada(zb, hw)
		var quad := [[la, Vector2(0, za)], [rb, Vector2(1, zb)], [ra, Vector2(1, za)], [la, Vector2(0, za)], [lb, Vector2(0, zb)], [rb, Vector2(1, zb)]]
		for v in quad:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	st.index()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat_estrada
	n.add_child(mi)
	# acostamento de cascalho
	for s in [-1.0, 1.0]:
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in passos:
			var za := z0 + i * 2.0
			var zb := za + 2.0
			var a1 := ponto_estrada(za, s * hw) - Vector3(0, 0.03, 0)
			var a2 := ponto_estrada(za, s * (hw + 1.4)) - Vector3(0, 0.12, 0)
			var b1 := ponto_estrada(zb, s * hw) - Vector3(0, 0.03, 0)
			var b2 := ponto_estrada(zb, s * (hw + 1.4)) - Vector3(0, 0.12, 0)
			for v in ([a1, b2, a2, a1, b1, b2] if s > 0 else [a1, a2, b2, a1, b2, b1]):
				st2.set_normal(Vector3.UP)
				st2.add_vertex(v)
		var ac := MeshInstance3D.new()
		ac.mesh = st2.commit()
		var mc := B.mat(Color(0.3, 0.26, 0.2), 1.0, 0.0, "cascalho")
		mc.cull_mode = BaseMaterial3D.CULL_DISABLED
		ac.material_override = mc
		n.add_child(ac)

func _terreno(n: Node3D, z0: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var nx := int(ALCANCE_X * 2.0 / PASSO_TERRENO)
	var nz := int(TAM / PASSO_TERRENO)
	var cx0 := roundf(centro_x(z0 + TAM * 0.5) / PASSO_TERRENO) * PASSO_TERRENO
	for iz in nz + 1:
		var z := z0 + iz * PASSO_TERRENO
		var seco := reg.cor(z, "seco")
		var verde := reg.cor(z, "verde")
		var cz := centro_x(z)
		var rio := _rio_em(z)
		var no_rio: bool = not rio.is_empty() and absf(z - rio.z) < rio.largura * 0.5 + 10.0
		for ix in nx + 1:
			var x := cx0 - ALCANCE_X + ix * PASSO_TERRENO
			var d := absf(x - cz)
			var h := altura(x, z)
			if d < LARG_ESTRADA * 0.5 + 0.5 and not no_rio:
				h = elevacao(z) - 0.3
			var terra := 1.0 - smoothstep(5.0, 9.0, d)
			var fl := floresta(x, z)
			var cs := seco.lerp(Color(0.2, 0.15, 0.09), fl * 0.4)
			var cv := verde.lerp(Color(0.1, 0.12, 0.06), fl * 0.4)
			st.set_color(Color(cs.r, cs.g, cs.b, terra))
			st.set_custom(0, Color(cv.r, cv.g, cv.b, fl))
			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, h, z))
	for iz in nz:
		for ix in nx:
			var a := iz * (nx + 1) + ix
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(d)
			st.add_index(a)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mesh := st.commit()
	# garante normais para cima (independente da ordem dos vértices)
	var arr := mesh.surface_get_arrays(0)
	var normais: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	if normais.size() > 0 and normais[normais.size() / 2].y < 0.0:
		for i in normais.size():
			normais[i] = -normais[i]
		arr[Mesh.ARRAY_NORMAL] = normais
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for i in range(0, idx.size(), 3):
			var t := idx[i + 1]
			idx[i + 1] = idx[i + 2]
			idx[i + 2] = t
		arr[Mesh.ARRAY_INDEX] = idx
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat_terreno
	n.add_child(mi)

func _criar_malha_capim() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in 7:
		var ang := r.randf() * TAU
		var off := Vector3(r.randf_range(-0.12, 0.12), 0, r.randf_range(-0.12, 0.12))
		var h := r.randf_range(0.55, 1.0)
		var w := 0.045
		var lado := Vector3(cos(ang), 0, sin(ang)) * w
		var incl := Vector3(cos(ang + 1.57), 0, sin(ang + 1.57)) * r.randf_range(0.05, 0.25)
		var a := off - lado
		var b := off + lado
		var mid_a := off - lado * 0.6 + Vector3(0, h * 0.5, 0) + incl * 0.4
		var mid_b := off + lado * 0.6 + Vector3(0, h * 0.5, 0) + incl * 0.4
		var tip := off + Vector3(0, h, 0) + incl
		var verts := [[a, 0.0], [b, 0.0], [mid_b, 0.5], [a, 0.0], [mid_b, 0.5], [mid_a, 0.5], [mid_a, 0.5], [mid_b, 0.5], [tip, 1.0]]
		for v in verts:
			st.set_uv(Vector2(0, v[1]))
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	return st.commit()

func _capim(n: Node3D, z0: float, k: int) -> void:
	var r := _rng_chunk(k, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _malha_capim
	var pts: Array[Transform3D] = []
	var cores: Array[Color] = []
	var zm := z0 + TAM * 0.5
	var alvo := int(densidade_capim * reg.param(zm, "capim"))
	var tint := reg.cor(zm, "capim_cor")
	var tentativas := alvo * 2
	for i in tentativas:
		if pts.size() >= alvo:
			break
		var z := z0 + r.randf() * TAM
		# mais denso perto da estrada
		var lado := 1.0 if r.randf() > 0.5 else -1.0
		var dist := LARG_ESTRADA * 0.5 + 1.6 + pow(r.randf(), 2.2) * 70.0
		var x := centro_x(z) + lado * dist
		if _ruido2.get_noise_2d(x * 2.0, z * 2.0) < -0.35 and dist > 12.0:
			continue
		if floresta(x, z) > 0.55 and r.randf() < 0.8:
			continue
		var y := altura(x, z)
		if y < agua_em(x, z) - 0.25:
			continue
		var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(0.7, 1.5)), Vector3(x, y - 0.05, z))
		pts.append(t)
		var seco := r.randf()
		cores.append(tint * Color(1, 1, 1).lerp(Color(0.75, 0.85, 0.6), seco * 0.5) * r.randf_range(0.8, 1.15))
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, pts[i])
		mm.set_instance_color(i, cores[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat_capim
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mmi)

# ------------------------------------------------------------ vegetação e props
func _arvore(n: Node3D, p: Vector3, r: RandomNumberGenerator) -> void:
	var t := Node3D.new()
	t.position = p
	t.rotation.y = r.randf() * TAU
	n.add_child(t)
	var h := r.randf_range(4.0, 8.0)
	var tronco := B.mat(Color(0.2, 0.15, 0.11), 1.0, 0.0, "tronco")
	B.cyl(t, 0.18, h, Vector3(0, h * 0.5, 0), tronco, Vector3(r.randf_range(-4, 4), 0, r.randf_range(-4, 4)), 7, 0.1)
	var morta := r.randf() < 0.18
	if morta:
		for i in 4:
			var g := B.cyl(t, 0.05, h * 0.4, Vector3(0, h * r.randf_range(0.55, 0.9), 0), tronco, Vector3(r.randf_range(30, 60), r.randf() * 360, 0), 5, 0.02)
		return
	var base_folha := Color(0.09, 0.12, 0.05).lerp(Color(0.18, 0.18, 0.07), r.randf())
	var copa := r.randf_range(1.8, 3.0)
	for i in r.randi_range(16, 26):
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * copa
		var off := Vector3(cos(a) * d, h - 0.6 + r.randf_range(-0.6, 1.4) * (1.0 - d / copa * 0.5), sin(a) * d)
		var cor := base_folha * r.randf_range(0.75, 1.25)
		var folha := B.mat(Color(snappedf(cor.r, 0.02), snappedf(cor.g, 0.02), snappedf(cor.b, 0.02)), 1.0)
		B.sphere(t, r.randf_range(0.55, 1.0), off, folha, Vector3(1, r.randf_range(0.55, 0.85), 1), 6)
	# galhos aparentes
	for i in 3:
		B.cyl(t, 0.06, copa, Vector3(0, h * 0.85, 0), tronco, Vector3(r.randf_range(40, 70), r.randf() * 360, 0), 5, 0.03)

func _arvores(n: Node3D, z0: float, k: int) -> void:
	var r := _rng_chunk(k, 2)
	var zm := z0 + TAM * 0.5
	var bio := bioma_em(zm)
	var fator := reg.param(zm, "arvores")
	var grupos := int(round(r.randi_range(1, 4) * fator))
	for g in grupos:
		var zc := z0 + r.randf() * TAM
		var lado := 1.0 if r.randf() > 0.5 else -1.0
		var dc := r.randf_range(16.0, 140.0)
		for i in r.randi_range(2, 7):
			var z := zc + r.randf_range(-10, 10)
			var x := centro_x(z) + lado * (dc + r.randf_range(-8, 8))
			if perto_de_feature(x, z, 7.0):
				continue
			var y := altura(x, z)
			match bio:
				"serra":
					_araucaria(n, Vector3(x, y - 0.2, z), r)
				"alagado":
					_arvore_morta(n, Vector3(x, y - 0.2, z), r)
				_:
					_arvore(n, Vector3(x, y - 0.2, z), r)
	# arbustos baixos
	for i in int(r.randi_range(4, 10) * clampf(fator, 0.3, 1.5)):
		var z := z0 + r.randf() * TAM
		var x := centro_x(z) + (1.0 if r.randf() > 0.5 else -1.0) * r.randf_range(8, 50)
		if perto_de_feature(x, z, 4.0):
			continue
		B.sphere(n, r.randf_range(0.5, 1.2), Vector3(x, altura(x, z), z), B.mat(Color(0.13, 0.15, 0.07), 1.0, 0.0, "arbusto"), Vector3(1.3, 0.7, 1.1), 8)
	if bio == "alagado":
		# taboas na beira d'água
		for i in 14:
			var z := z0 + r.randf() * TAM
			var x := centro_x(z) + (1.0 if r.randf() > 0.5 else -1.0) * r.randf_range(9, 60)
			var y := altura(x, z)
			if absf(y - agua_em(x, z)) < 0.5:
				for q in 5:
					B.cyl(n, 0.015, 1.6, Vector3(x + r.randf_range(-0.4, 0.4), y + 0.8, z + r.randf_range(-0.4, 0.4)), B.mat(Color(0.3, 0.33, 0.15), 0.9, 0.0, "taboa"), Vector3(r.randf_range(-8, 8), 0, r.randf_range(-8, 8)), 4)

func _araucaria(n: Node3D, p: Vector3, r: RandomNumberGenerator) -> void:
	var t := Node3D.new()
	t.position = p
	t.rotation.y = r.randf() * TAU
	n.add_child(t)
	var h := r.randf_range(10.0, 16.0)
	var tronco := B.mat(Color(0.25, 0.18, 0.13), 1.0, 0.0, "tronco_arauc")
	B.cyl(t, 0.25, h, Vector3(0, h * 0.5, 0), tronco, Vector3.ZERO, 7, 0.14)
	var folha := B.mat(Color(0.08, 0.13, 0.07), 1.0, 0.0, "folha_arauc")
	var raio := r.randf_range(3.0, 4.2)
	for k in 3:
		var y := h - 0.6 + k * 0.5
		var disco := B.cyl(t, raio * (0.55 - k * 0.12), 0.7, Vector3(0, y, 0), folha, Vector3.ZERO, 9, raio * (1.0 - k * 0.22))
	for k in 6:
		var a := TAU * k / 6.0
		var galho := B.cyl(t, 0.07, raio * 0.95, Vector3(cos(a) * raio * 0.38, h - 1.0, sin(a) * raio * 0.38), tronco, Vector3.ZERO, 5, 0.04)
		galho.rotation = Vector3(0, -a, 0)
		galho.rotate_object_local(Vector3.FORWARD, deg_to_rad(-55))

func _arvore_morta(n: Node3D, p: Vector3, r: RandomNumberGenerator) -> void:
	var t := Node3D.new()
	t.position = p
	t.rotation.y = r.randf() * TAU
	n.add_child(t)
	var h := r.randf_range(4.0, 9.0)
	var tronco := B.mat(Color(0.28, 0.25, 0.22), 1.0, 0.0, "tronco_morto")
	B.cyl(t, 0.2, h, Vector3(0, h * 0.5, 0), tronco, Vector3(r.randf_range(-8, 8), 0, r.randf_range(-8, 8)), 6, 0.06)
	for i in r.randi_range(3, 6):
		B.cyl(t, 0.06, h * 0.45, Vector3(0, h * r.randf_range(0.45, 0.9), 0), tronco, Vector3(r.randf_range(25, 70), r.randf() * 360, 0), 5, 0.015)

func _postes(n: Node3D, z0: float, k: int) -> void:
	var madeira := B.mat(Color(0.18, 0.14, 0.1), 1.0, 0.0, "poste")
	var fio := B.mat(Color(0.05, 0.05, 0.05), 0.8, 0.0, "fio")
	var topo_ant := Vector3.ZERO
	for i in 2:
		var z := z0 + i * 32.0
		var p := ponto_estrada(z, LARG_ESTRADA * 0.5 + 3.5)
		p.y = altura(p.x, z)
		var inc := sin(z * 0.37) * 4.0
		var poste := Node3D.new()
		poste.position = p
		poste.rotation_degrees = Vector3(0, 0, inc)
		n.add_child(poste)
		B.cyl(poste, 0.13, 9.0, Vector3(0, 4.5, 0), madeira, Vector3.ZERO, 7, 0.1)
		B.box(poste, Vector3(1.8, 0.12, 0.12), Vector3(0, 8.4, 0), madeira)
		var topo := p + Vector3(-sin(deg_to_rad(inc)) * 8.5, 8.5, 0)
		var prox_z := z + 32.0
		var prox := ponto_estrada(prox_z, LARG_ESTRADA * 0.5 + 3.5)
		prox.y = altura(prox.x, prox_z)
		var inc2 := sin(prox_z * 0.37) * 4.0
		var topo2 := prox + Vector3(-sin(deg_to_rad(inc2)) * 8.5, 8.5, 0)
		for s in [-0.8, 0.8]:
			_fio(n, topo + Vector3(s, 0, 0), topo2 + Vector3(s, 0, 0), fio)

func _fio(n: Node3D, a: Vector3, b: Vector3, m: Material) -> void:
	var segs := 6
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.9, 0)
		var mid := (prev + p) * 0.5
		var comp := prev.distance_to(p)
		var mi := B.cyl(n, 0.012, comp, mid, m, Vector3.ZERO, 4)
		mi.look_at_from_position(mid, p, Vector3.UP if absf((p - prev).normalized().y) < 0.99 else Vector3.RIGHT)
		mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		prev = p

func carro_abandonado(n: Node3D, pos: Vector3, rot_y: float, r: RandomNumberGenerator, chave := "") -> Node3D:
	var desmontado := carros_desmontados.has(chave)
	var c := Node3D.new()
	if chave != "":
		c.set_meta("chave", chave)
		c.set_meta("semente", r.seed)
		if not desmontado:
			carros_soltos.append(c)
	c.position = pos
	c.rotation.y = rot_y
	n.add_child(c)
	var queimado := r.randf() < 0.45
	var cores := [Color(0.35, 0.12, 0.1), Color(0.25, 0.3, 0.35), Color(0.55, 0.52, 0.45), Color(0.18, 0.22, 0.15), Color(0.6, 0.55, 0.4)]
	var base: Color = cores[r.randi() % cores.size()]
	var cor := B.worn(base, 0.2 if queimado else 0.55)
	if queimado:
		cor = cor.lerp(Color(0.12, 0.09, 0.07), 0.6)
	var pintura := B.pintura(cor, 0.15 if queimado else 0.4, 0.8, 0.2, 0.7)
	var perfil := PackedVector2Array([
		Vector2(-2.2, 0.35), Vector2(-1.75, 0.35), Vector2(-1.65, 0.62), Vector2(-1.15, 0.62), Vector2(-1.05, 0.35),
		Vector2(1.05, 0.35), Vector2(1.15, 0.62), Vector2(1.65, 0.62), Vector2(1.75, 0.35), Vector2(2.2, 0.38),
		Vector2(2.25, 0.75), Vector2(1.0, 0.85), Vector2(0.45, 1.3), Vector2(-0.9, 1.32), Vector2(-1.5, 0.88), Vector2(-2.22, 0.82)])
	B.extruded(c, perfil, 1.75, Vector3.ZERO, pintura)
	var jan := PackedVector2Array([Vector2(-1.35, 0.9), Vector2(0.95, 0.9), Vector2(0.45, 1.26), Vector2(-0.85, 1.27)])
	B.extruded(c, jan, 1.76, Vector3.ZERO, B.mat(Color(0.03, 0.03, 0.03), 0.3, 0.2, "vidro_quebrado"))
	var pneu_y := 0.32
	for z in [-1.4, 1.4]:
		for s in [-1.0, 1.0]:
			if r.randf() < 0.2 or desmontado:
				continue
			var w := B.wheel(c, Vector3(s * 0.78, pneu_y - (0.12 if r.randf() < 0.4 else 0.0), z), 0.32, 0.22, Color(0.2, 0.15, 0.1))
	if r.randf() < 0.5:
		var porta := B.box(c, Vector3(0.05, 0.5, 0.9), Vector3(1.2, 0.65, 0.5), pintura)
		porta.rotation_degrees.y = -50
	c.rotation.z = r.randf_range(-0.05, 0.05)
	if desmontado:
		c.position.y -= 0.22
		c.rotation.z = 0.0
	B.atualizar_pintura(pintura, c)
	return c

## Troca um carro pela carcaça desmontada (sem rodas).
func marcar_desmontado(c: Node3D) -> void:
	var chave: String = c.get_meta("chave", "")
	carros_desmontados[chave] = true
	carros_soltos.erase(c)
	var r := RandomNumberGenerator.new()
	r.seed = c.get_meta("semente", 0)
	var pai := c.get_parent()
	var pos := c.position
	var rot := c.rotation.y
	c.queue_free()
	carro_abandonado(pai, pos, rot, r, chave)

func _carros(n: Node3D, z0: float, k: int) -> void:
	if k in [-1, 0]:
		return
	var r := _rng_chunk(k, 3)
	var qtd := r.randi_range(0, 3)
	for i in qtd:
		var z := z0 + r.randf() * TAM
		var lat := r.randf_range(-LARG_ESTRADA * 0.5 - 4.0, LARG_ESTRADA * 0.5 + 4.0)
		var p := ponto_estrada(z, lat)
		p.y = maxf(altura(p.x, z), elevacao(z)) - 0.02
		var d := direcao(z)
		var ang := atan2(d.x, d.z) + r.randf_range(-0.6, 0.6) + (PI if r.randf() < 0.3 else 0.0)
		var rc := RandomNumberGenerator.new()
		rc.seed = r.randi()
		carro_abandonado(n, p, ang, rc, "%d:%d" % [k, i])

# ------------------------------------------------------------ florestas
## Construções (Predio) já postas no chunk: [inversa da transformação, meia-largura, meia-profundidade].
func _areas_construidas(n: Node3D) -> Array:
	var res: Array = []
	var pilha: Array = [[n, Transform3D.IDENTITY]]
	while not pilha.is_empty():
		var it: Array = pilha.pop_back()
		var nd: Node = it[0]
		var t: Transform3D = it[1]
		for c in nd.get_children():
			if c is Node3D:
				var tc: Transform3D = t * (c as Node3D).transform
				if c is Predio:
					res.append([tc.affine_inverse(), c.largura * 0.5 + 3.0, c.profundidade * 0.5 + 3.0])
				else:
					pilha.append([c, tc])
	return res

## Tira capim/árvores que nasceram dentro de construções (o mato é gerado antes delas).
func _limpar_vegetacao(n: Node3D, areas: Array) -> void:
	if areas.is_empty():
		return
	var pilha: Array = [[n, Transform3D.IDENTITY]]
	while not pilha.is_empty():
		var it: Array = pilha.pop_back()
		var t: Transform3D = it[1]
		for c in (it[0] as Node).get_children():
			if c is Predio or not (c is Node3D):
				continue
			var tc: Transform3D = t * (c as Node3D).transform
			if c is MultiMeshInstance3D and c.multimesh:
				var mm: MultiMesh = c.multimesh
				for i in mm.instance_count:
					var ti: Transform3D = mm.get_instance_transform(i)
					var w: Vector3 = tc * ti.origin
					for a in areas:
						var l: Vector3 = a[0] * Vector3(w.x, 0, w.z)
						if absf(l.x) < a[1] - 2.6 and absf(l.z) < a[2] - 2.6:
							mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), ti.origin))
							break
			pilha.append([c, tc])

## Bichos do mato longe da estrada: veados e javalis na mata, capivaras perto de água.
func _animais(n: Node3D, z0: float, k: int, bio: String) -> void:
	var r := _rng_chunk(k, 77)
	var chance := {"serra": 0.55, "rural": 0.4, "alagado": 0.6, "industrial": 0.08, "cidade": 0.03}.get(bio, 0.3) as float
	if r.randf() > chance:
		return
	var tipos: Array = ["veado", "veado", "javali"]
	if bio == "alagado":
		tipos = ["capivara", "capivara", "veado"]
	elif bio == "rural":
		tipos = ["veado", "capivara", "javali", "veado"]
	var tipo: String = tipos[r.randi() % tipos.size()]
	var zc := z0 + r.randf_range(8.0, TAM - 8.0)
	var lado := 1.0 if r.randf() < 0.5 else -1.0
	var c := ponto_estrada(zc, lado * r.randf_range(30.0, 140.0))
	var n_grupo := r.randi_range(1, 4) if tipo != "javali" else r.randi_range(1, 3)
	for i in n_grupo:
		var p := c + Vector3(r.randf_range(-6, 6), 0, r.randf_range(-6, 6))
		if perto_de_feature(p.x, p.z, 4.0):
			continue
		var ag := agua_em(p.x, p.z)
		p.y = altura(p.x, p.z)
		if ag > -1e8 and ag - p.y > 0.6:
			continue
		var an := Animal.new()
		an.tipo = tipo
		an.mundo = self
		an.semente = r.randi()
		an.chave = "an:%d:%d" % [k, i]
		an.set_meta("nao_mesclar", true)
		an.position = p
		n.add_child(an)

func _mata(n: Node3D, z0: float, k: int, areas: Array = []) -> void:
	var r := _rng_chunk(k, 30)
	var cz := centro_x(z0 + TAM * 0.5)
	var bio := bioma_em(z0 + TAM * 0.5)
	var listas := {}
	var add := func(tipo: String, t: Transform3D, cor: Color):
		if not listas.has(tipo):
			listas[tipo] = []
		listas[tipo].append([t, cor])
	var passo := 5.0
	# mata fechada em volta dos assentamentos (o muro fica numa clareira)
	var aneis: Array = []
	for ri in [reg.indice(z0), reg.indice(z0 + TAM)]:
		for f in _features(ri):
			if f.tipo == "plato" and f.juncao.tipo == "assentamento" and absf(f.c.z - (z0 + TAM * 0.5)) < 140.0:
				aneis.append(f.c)
	var x := cz - 280.0
	while x < cz + 280.0:
		var z := z0
		while z < z0 + TAM:
			var px := x + r.randf_range(0.0, passo)
			var pz := z + r.randf_range(0.0, passo)
			var fl := floresta(px, pz)
			for ca in aneis:
				var dd := Vector2(px - ca.x, pz - ca.z).length()
				if dd > Assentamento.R + 9.0 and dd < Assentamento.R + 55.0 and absf(px - cz) > 16.0:
					fl = maxf(fl, 0.8 - (dd - Assentamento.R - 9.0) * 0.006)
			var livre := true
			for a in areas:
				var l: Vector3 = a[0] * Vector3(px, 0, pz)
				if absf(l.x) < a[1] and absf(l.z) < a[2]:
					livre = false
					break
			if livre and fl > 0.05 and r.randf() < fl * 0.9 and not perto_de_feature(px, pz, 5.0):
				var y := altura(px, pz)
				if y > agua_em(px, pz) - 0.1:
					var tipo := "folhosa"
					var sorte := r.randf()
					match bio:
						"serra":
							tipo = "pinheiro" if sorte < 0.55 else "folhosa"
						"rural":
							tipo = "eucalipto" if sorte < 0.3 else ("pinheiro" if sorte < 0.55 else "folhosa")
						"alagado":
							tipo = "folhosa"
					var esc := r.randf_range(0.75, 1.3)
					var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(esc, esc * r.randf_range(0.9, 1.15), esc)), Vector3(px, y - 0.15, pz))
					add.call(tipo, t, Color(1, 1, 1) * r.randf_range(0.8, 1.15))
					# sub-bosque em volta
					for q in r.randi_range(1, 3):
						var sx := px + r.randf_range(-2.5, 2.5)
						var sz := pz + r.randf_range(-2.5, 2.5)
						var tipo_s: String = ["samambaia", "samambaia", "arbusto", "arbusto", "toco", "pedra", "tronco_caido", "cogumelos", "capim_alto", "samambaia"][r.randi() % 10]
						if tipo_s == "tronco_caido" and r.randf() < 0.6:
							tipo_s = "samambaia"
						var es := r.randf_range(0.7, 1.4)
						var ts := Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * es), Vector3(sx, altura(sx, sz) - 0.05, sz))
						add.call(tipo_s, ts, Color(1, 1, 1) * r.randf_range(0.75, 1.2))
			elif livre and fl <= 0.05 and r.randf() < 0.22 and not perto_de_feature(px, pz, 3.0) and absf(px - cz) > 9.0:
				# campo aberto: capim alto, flores, arbustos secos, uma taquara ou um jerivá de vez em quando
				var yc := altura(px, pz)
				if yc > agua_em(px, pz) - 0.1:
					var so := r.randf()
					var tc: String = "capim_alto"
					if so < 0.25:
						tc = "flores"
					elif so < 0.42:
						tc = "arbusto_seco" if bio in ["cidade", "industrial", "rural"] else "arbusto"
					elif so < 0.47 and bio in ["rural", "serra", "alagado"]:
						tc = "taquara"
					elif so < 0.5 and bio in ["rural", "alagado"]:
						tc = "jeriva"
					var ec := r.randf_range(0.7, 1.3)
					add.call(tc, Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * ec), Vector3(px, yc - 0.05, pz)), Color(1, 1, 1) * r.randf_range(0.8, 1.15))
			z += passo
		x += passo
	for tipo in listas:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = Floresta.malha(tipo)
		var l: Array = listas[tipo]
		mm.instance_count = l.size()
		for i in l.size():
			mm.set_instance_transform(i, l[i][0])
			mm.set_instance_color(i, l[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.set_meta("nao_mesclar", true)
		if tipo in ["samambaia", "arbusto", "pedra", "toco", "capim_alto", "flores", "cogumelos", "arbusto_seco"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 110.0
		n.add_child(mmi)

# ------------------------------------------------------------ cidade, indústria, várzea
func _predios(n: Node3D, z0: float, k: int) -> void:
	var r := _rng_chunk(k, 7)
	var concreto := B.mat(Color(0.5, 0.48, 0.45), 0.95, 0.0, "concreto")
	var calcada := B.mat(Color(0.42, 0.41, 0.39), 0.95, 0.0, "calcada")
	for s in [-1.0, 1.0]:
		var z := z0 + r.randf_range(0.0, 6.0)
		while z < z0 + TAM - 6.0:
			var larg := r.randf_range(9.0, 16.0)
			var zc := z + larg * 0.5
			var recuo := r.randf_range(15.0, 22.0)
			var p := ponto_estrada(zc, s * recuo)
			if perto_de_feature(p.x, p.z, 14.0):
				z += larg + 4.0
				continue
			var andares := r.randi_range(1, 5)
			var prof := r.randf_range(8.0, 14.0)
			if r.randf() < 0.3:
				var dd := direcao(zc)
				var rot := atan2(dd.x, dd.z) + (-PI * 0.5 if s > 0 else PI * 0.5)
				var pe := ponto_estrada(zc, s * (recuo + prof * 0.5))
				criar_predio(n, pe, rot, "apto", minf(larg, 12.0), minf(prof, 10.0), clampi(andares, 2, 4), r.randi(), "apto:%d:%d" % [k, int(zc)])
				z += larg + r.randf_range(1.0, 5.0)
				continue
			var y := minf(altura(p.x, p.z), elevacao(zc))
			var pr := Node3D.new()
			pr.position = Vector3(p.x, y, p.z)
			var d := direcao(zc)
			pr.rotation.y = atan2(d.x, d.z) + (PI * 0.5 if s > 0 else -PI * 0.5)
			n.add_child(pr)
			var cores := [Color(0.72, 0.68, 0.6), Color(0.6, 0.55, 0.5), Color(0.75, 0.62, 0.5), Color(0.55, 0.6, 0.62), Color(0.68, 0.7, 0.66)]
			var cor: Color = cores[r.randi() % cores.size()]
			var h := andares * 3.1
			var desabado := r.randf() < 0.18
			if desabado:
				h *= 0.45
			B.box(pr, Vector3(larg, h, prof), Vector3(0, h * 0.5, -prof * 0.5), B.mat(B.worn(cor, r.randf_range(0.3, 0.7)), 0.9))
			var vidro := B.mat(Color(0.06, 0.07, 0.08), 0.2, 0.3, "janela_predio")
			for a in int(h / 3.1):
				for w in int(larg / 2.4):
					if r.randf() < 0.85:
						B.box(pr, Vector3(1.1, 1.3, 0.05), Vector3(-larg * 0.5 + 1.4 + w * 2.4, 1.9 + a * 3.1, 0.01), vidro)
			if andares <= 2 and r.randf() < 0.6:
				# loja térrea com toldo
				var toldo := B.box(pr, Vector3(larg * 0.9, 0.06, 1.6), Vector3(0, 3.0, 0.75), B.mat(Color.from_hsv(r.randf(), 0.5, 0.45), 0.9))
				toldo.rotation.x = 0.25
			if desabado:
				for e in 10:
					var pd := B.box(pr, Vector3(r.randf_range(0.6, 2.5), r.randf_range(0.3, 1.0), r.randf_range(0.6, 2.0)), Vector3(r.randf_range(-larg * 0.5, larg * 0.5), 0.3, r.randf_range(-1.0, 3.0)), concreto)
					pd.rotation = Vector3(r.randf(), r.randf() * 3.0, r.randf())
			B.box(pr, Vector3(larg, 0.15, 4.0), Vector3(0, 0.07, 2.2), calcada)
			z += larg + r.randf_range(1.0, 5.0)

func _galpoes(n: Node3D, z0: float, k: int) -> void:
	var r := _rng_chunk(k, 8)
	if r.randf() < 0.35:
		return
	var s := 1.0 if r.randf() < 0.5 else -1.0
	var zc := z0 + r.randf_range(15.0, TAM - 15.0)
	var p := ponto_estrada(zc, s * r.randf_range(40.0, 70.0))
	if perto_de_feature(p.x, p.z, 30.0):
		return
	var y := altura(p.x, p.z)
	var g := Node3D.new()
	g.position = Vector3(p.x, y - 0.3, p.z)
	var d := direcao(zc)
	g.rotation.y = atan2(d.x, d.z) + r.randf_range(-0.2, 0.2)
	n.add_child(g)
	var chapa := B.mat(B.worn(Color(0.55, 0.56, 0.55), r.randf_range(0.3, 0.6)), 0.6, 0.5)
	var larg := r.randf_range(20.0, 32.0)
	var comp := r.randf_range(30.0, 50.0)
	var h := r.randf_range(7.0, 10.0)
	B.box(g, Vector3(larg, h, comp), Vector3(0, h * 0.5, 0), chapa)
	var arco := PackedVector2Array()
	for i in 9:
		var a := PI * i / 8.0
		arco.append(Vector2(-cos(a) * comp * 0.5, h + sin(a) * 2.5))
	arco.append(Vector2(comp * 0.5, h))
	B.box(g, Vector3(larg + 0.4, 0.3, comp + 0.4), Vector3(0, h + 0.1, 0), B.mat(Color(0.4, 0.42, 0.42), 0.6, 0.5))
	for i in 4:
		B.box(g, Vector3(0.06, 4.5, 4.0), Vector3(-s * (larg * 0.5 + 0.01), 2.25, -comp * 0.3 + i * comp * 0.2), B.mat(Color(0.18, 0.2, 0.22), 0.6, 0.5))
	if r.randf() < 0.6:
		var ch := B.cyl(g, 1.2, 26.0, Vector3(larg * 0.3, 13.0, comp * 0.5 + 3.0), B.mat(B.worn(Color(0.55, 0.3, 0.22), 0.4), 0.9), Vector3.ZERO, 12, 0.9)
		B.cyl(g, 1.0, 1.0, Vector3(larg * 0.3, 25.0, comp * 0.5 + 3.0), B.mat(Color(0.85, 0.82, 0.78), 0.9), Vector3.ZERO, 12)
	# cerca e contêineres
	for i in r.randi_range(2, 5):
		var ct := B.box(g, Vector3(2.4, 2.6, 6.0), Vector3(s * (larg * 0.5 + 6.0), 1.3, -comp * 0.4 + i * 6.5), B.mat(B.worn(Color.from_hsv(r.randf(), 0.6, 0.45), 0.4), 0.6, 0.4))
		ct.rotation.y = r.randf_range(-0.2, 0.2)
	for i in 12:
		B.box(g, Vector3(0.08, 2.2, 0.08), Vector3(-s * (larg * 0.5 + 10.0), 1.1, -comp * 0.5 + i * comp / 11.0), B.mat(Color(0.3, 0.3, 0.3), 0.5, 0.7))
	B.box(g, Vector3(0.03, 1.8, comp), Vector3(-s * (larg * 0.5 + 10.0), 1.2, 0), B.mat(Color(0.25, 0.25, 0.25, 1), 0.6, 0.7))

func _agua_varzea(n: Node3D, z0: float) -> void:
	var zm := z0 + TAM * 0.5
	var y := agua_em(centro_x(zm), zm)
	var pm := PlaneMesh.new()
	pm.size = Vector2(ALCANCE_X * 2.0, TAM + 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat_agua
	mi.position = Vector3(centro_x(zm), y, zm)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)

# ------------------------------------------------------------ estradas de terra, placas e lugares
func _estradas_terra(n: Node3D, z0: float, k: int) -> void:
	var regs := {reg.indice(z0): true, reg.indice(z0 + TAM): true}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var algum := false
	for ri in regs:
		for f in _features(ri):
			if f.tipo != "estrada":
				continue
			var bb: Rect2 = f.bb
			if bb.position.y > z0 + TAM or bb.end.y < z0:
				continue
			var pts: PackedVector3Array = f.pts
			var larg: float = f.get("largura", 4.8)
			var acum := 0.0
			for i in pts.size() - 1:
				var a := pts[i]
				var b := pts[i + 1]
				var seg := a.distance_to(b)
				var meio := (a.z + b.z) * 0.5
				if meio >= z0 and meio < z0 + TAM:
					var da := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)])
					var db := (pts[mini(i + 2, pts.size() - 1)] - pts[i])
					var la := Vector3(-da.z, 0, da.x).normalized() * larg * 0.5
					var lb := Vector3(-db.z, 0, db.x).normalized() * larg * 0.5
					# subdivide e cola cada vértice no chão de verdade (o mesmo que o jogador pisa)
					var nsub := maxi(1, int(ceil(seg / 1.5)))
					for sb in nsub:
						var t0 := float(sb) / nsub
						var t1 := float(sb + 1) / nsub
						var p0 := a.lerp(b, t0)
						var p1 := a.lerp(b, t1)
						var l0 := la.lerp(lb, t0)
						var l1 := la.lerp(lb, t1)
						var cs := [p0 - l0, p0 + l0, p1 - l1, p1 + l1]
						for ci in 4:
							var q: Vector3 = cs[ci]
							cs[ci] = Vector3(q.x, altura(q.x, q.z) + 0.09, q.z)
						var u0 := (acum + seg * t0) / 4.0
						var u1 := (acum + seg * t1) / 4.0
						var v := [[cs[0], Vector2(0, u0)], [cs[3], Vector2(1, u1)], [cs[1], Vector2(1, u0)],
							[cs[0], Vector2(0, u0)], [cs[2], Vector2(0, u1)], [cs[3], Vector2(1, u1)]]
						var c0: Vector3 = cs[0]
						var nrm: Vector3 = (cs[3] - c0).cross(cs[1] - c0)
						if nrm.y < 0.0:
							v = [v[0], v[2], v[1], v[3], v[5], v[4]]
						for q in v:
							st.set_normal(Vector3.UP)
							st.set_uv(q[1])
							st.add_vertex(q[0])
					algum = true
				acum += seg
	if not algum:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat_terra
	n.add_child(mi)

func _placas_juncao(n: Node3D, z0: float) -> void:
	for l in lugares_da_regiao(reg.indice(z0 + TAM * 0.5)):
		if not l.tipo in ["vila", "fazenda", "ferro_velho", "assentamento"]:
			continue
		var zj: float = l.juncao_z - 14.0
		if zj < z0 or zj >= z0 + TAM:
			continue
		var dist := int(round(Vector2(l.pos.x - centro_x(l.juncao_z), l.pos.z - l.juncao_z).length() / 50.0) * 50.0)
		var seta := "→" if l.lado > 0 else "←"
		_placa_texto(n, zj, l.lado * (LARG_ESTRADA * 0.5 + 2.4), "%s\n%d m  %s" % [l.nome.to_upper(), dist, seta], Color(0.85, 0.85, 0.78))

func _placa_texto(n: Node3D, z: float, lateral: float, texto: String, cor: Color) -> void:
	var p := ponto_estrada(z, lateral)
	p.y = altura(p.x, z)
	var pl := Node3D.new()
	pl.position = p
	var d := direcao(z)
	pl.rotation.y = atan2(d.x, d.z) + PI
	n.add_child(pl)
	var fundo := B.mat(B.worn(Color(0.07, 0.25, 0.16) if cor.r > 0.8 and cor.g > 0.8 else Color(0.1, 0.1, 0.1), 0.55), 0.7, 0.2)
	var metal := B.mat(Color(0.35, 0.35, 0.35), 0.5, 0.7)
	for x in [-1.3, 1.3]:
		B.cyl(pl, 0.05, 2.6, Vector3(x, 1.3, -0.05), metal, Vector3.ZERO, 6)
	B.box(pl, Vector3(3.6, 1.4, 0.05), Vector3(0, 2.1, 0), fundo)
	var lbl := Label3D.new()
	lbl.text = texto
	lbl.font_size = 64
	lbl.modulate = cor
	lbl.outline_size = 0
	lbl.pixel_size = 0.0058
	lbl.position = Vector3(0, 2.1, 0.04)
	lbl.shaded = true
	pl.add_child(lbl)

func _lugares_no_chunk(n: Node3D, z0: float) -> void:
	var regs := {reg.indice(z0): true, reg.indice(z0 + TAM): true}
	for ri in regs:
		for f in _features(ri):
			if f.tipo == "plato" and f.c.z >= z0 and f.c.z < z0 + TAM:
				var node := Lugares.construir(n, f, self)
				lugares_ativos[f.id] = node

## Reboque abandonado num lugar fixo (ferro-velho etc.). chave identifica para não reaparecer.
func reboque_abandonado_em(pos: Vector3, rot_y: float, chave: String, r: RandomNumberGenerator) -> void:
	if reboques_levados.has(chave):
		return
	var reb := Reboque.new()
	reb.tipo = TIPOS_REBOQUE[r.randi() % TIPOS_REBOQUE.size()]
	reb.nivel = 1
	if estado_reboques.has(chave):
		reb.carregar(estado_reboques[chave])
	else:
		reb.gerar_abandonado(r)
	pos.y = altura(pos.x, pos.z)
	reb.position = pos
	reb.rotation.y = rot_y
	reb.set_meta("chunk", chave)
	reb.set_meta("chunk_k", int(floor(pos.z / TAM)))
	add_child(reb)
	reboques_soltos.append(reb)

# ------------------------------------------------------------ beira da estrada (densidade)
const OUTDOORS := ["VOTE ZÉ CARLOS", "PNEUS BOM PREÇO 2 KM", "HOTEL ESTRELA 5 KM", "JESUS VOLTARÁ", "CHURRASCARIA GAÚCHA", "FARMÁCIA POPULAR"]

func _lugar_livre(x: float, z: float, raio: float) -> bool:
	return not perto_de_feature(x, z, raio) and agua_em(x, z) < altura(x, z) - 0.2

func _beira_estrada(n: Node3D, z0: float, k: int, bio: String) -> void:
	var r := _rng_chunk(k, 20)
	var lado := 1.0 if r.randf() < 0.5 else -1.0
	match bio:
		"rural", "serra":
			if r.randf() < 0.35:
				_casa_beira(n, z0 + r.randf_range(10.0, TAM - 10.0), lado * r.randf_range(22.0, 38.0), k, r)
			if bio == "rural" and r.randf() < 0.55:
				_cerca_pasto(n, z0, -lado, r)
			if r.randf() < 0.12:
				_cruz(n, z0 + r.randf() * TAM, -lado * (LARG_ESTRADA * 0.5 + 2.2), r)
		"cidade":
			_lojas(n, z0, k, r)
		"industrial":
			if r.randf() < 0.25:
				_caminhao_tombado(n, z0 + r.randf_range(10.0, TAM - 10.0), lado * r.randf_range(6.0, 12.0), r)
		"alagado":
			if r.randf() < 0.2:
				_casa_beira(n, z0 + r.randf_range(10.0, TAM - 10.0), lado * r.randf_range(14.0, 22.0), k, r, true)
	if r.randf() < 0.1:
		_outdoor(n, z0 + r.randf() * TAM, -lado * r.randf_range(14.0, 20.0), r)
	if r.randf() < 0.08:
		_ponto_onibus(n, z0 + r.randf() * TAM, lado * (LARG_ESTRADA * 0.5 + 2.0), r)
	if bio != "cidade" and r.randf() < 0.06:
		_engavetamento(n, z0 + TAM * 0.5, r, k)

func _casa_beira(n: Node3D, z: float, lat: float, k: int, r: RandomNumberGenerator, palafita := false) -> void:
	var p := ponto_estrada(z, lat)
	if not _lugar_livre(p.x, p.z, 14.0):
		return
	var d := direcao(z)
	var rot := atan2(d.x, d.z) + (-PI * 0.5 if lat > 0 else PI * 0.5) + r.randf_range(-0.15, 0.15)
	var sobrado := r.randf() < 0.35 and not palafita
	var pr := criar_predio(n, p, rot, "sobrado" if sobrado else "casa", r.randf_range(7.5, 10.0), r.randf_range(7.0, 8.5), 2 if sobrado else 1, r.randi(), "cb:%d:%d" % [k, int(z)])
	if palafita:
		pr.position.y = maxf(pr.position.y, agua_em(p.x, p.z) + 1.0)
		var mad := B.mat(Color(0.28, 0.2, 0.13), 0.95, 0.0, "palafita")
		for dx in [-3.5, 3.5]:
			for dz in [-3.0, 3.0]:
				B.box(pr, Vector3(0.22, 2.4, 0.22), Vector3(dx, -1.2, dz), mad)
	# cerquinha, caixa de correio e às vezes um carro no quintal
	var mad2 := B.mat(Color(0.75, 0.72, 0.66), 0.9, 0.0, "cerquinha")
	var fz := pr.profundidade * 0.5 + 3.0
	for i in 11:
		if absf(-5.0 + i) < 1.0:
			continue
		var q := pr.transform * Vector3(-5.0 + i, 0, fz)
		q.y = altura(q.x, q.z)
		B.box(n, Vector3(0.08, 0.9, 0.08), q + Vector3(0, 0.45, 0), mad2)
	var cx := pr.transform * Vector3(5.6, 0, fz + 0.4)
	cx.y = altura(cx.x, cx.z)
	B.box(n, Vector3(0.35, 0.25, 0.25), cx + Vector3(0, 1.1, 0), B.mat(Color(0.7, 0.15, 0.1), 0.6, 0.3))
	B.box(n, Vector3(0.06, 1.0, 0.06), cx + Vector3(0, 0.5, 0), mad2)
	if r.randf() < 0.5:
		var rc := RandomNumberGenerator.new()
		rc.seed = r.randi()
		carro_abandonado(n, pr.transform * Vector3(pr.largura * 0.5 + 3.0, 0, 2.0), rot + 0.3, rc, "casa:%d:%d" % [k, int(z)])
	if r.randf() < 0.5:
		criar_zumbi(n, pr.global_transform * Vector3(r.randf_range(-2, 2), 0, r.randf_range(-2, 1)) if pr.is_inside_tree() else pr.position, r.randf() * TAU, r.randi())

func _cerca_pasto(n: Node3D, z0: float, lado: float, r: RandomNumberGenerator) -> void:
	var lat := LARG_ESTRADA * 0.5 + r.randf_range(9.0, 14.0)
	var mad := B.mat(Color(0.3, 0.24, 0.17), 0.95, 0.0, "cerca_pasto")
	var arame := B.mat(Color(0.35, 0.35, 0.35), 0.5, 0.7, "arame")
	var prev := Vector3.ZERO
	for i in 17:
		var z := z0 + i * 4.0
		var p := ponto_estrada(z, lado * lat)
		if perto_de_feature(p.x, p.z, 6.0):
			prev = Vector3.ZERO
			continue
		p.y = altura(p.x, p.z)
		B.box(n, Vector3(0.12, 1.3, 0.12), p + Vector3(0, 0.65, 0), mad, Vector3(r.randf_range(-6, 6), 0, r.randf_range(-6, 6)))
		if prev != Vector3.ZERO and r.randf() > 0.08:
			for h in [0.55, 1.0]:
				var a := prev + Vector3(0, h, 0)
				var b := p + Vector3(0, h, 0)
				var f := B.box(n, Vector3(0.015, 0.015, a.distance_to(b)), (a + b) * 0.5, arame)
				f.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
		prev = p
	# gado morto ou fardos no pasto
	if r.randf() < 0.4:
		var p2 := ponto_estrada(z0 + r.randf() * TAM, lado * (lat + r.randf_range(8.0, 25.0)))
		p2.y = altura(p2.x, p2.z)
		for q in r.randi_range(2, 4):
			B.cyl(n, 0.6, 1.2, p2 + Vector3(q * 1.5, 0.6, r.randf_range(-1, 1)), B.mat(Color(0.75, 0.62, 0.3), 1.0, 0.0, "feno"), Vector3(90, r.randf() * 90.0, 0), 10)

func _cruz(n: Node3D, z: float, lat: float, r: RandomNumberGenerator) -> void:
	var p := ponto_estrada(z, lat)
	p.y = altura(p.x, p.z)
	var branco := B.mat(Color(0.85, 0.85, 0.82), 0.9, 0.0, "cruz")
	B.box(n, Vector3(0.1, 1.1, 0.06), p + Vector3(0, 0.55, 0), branco)
	B.box(n, Vector3(0.55, 0.08, 0.06), p + Vector3(0, 0.8, 0), branco)
	for q in 4:
		B.sphere(n, 0.06, p + Vector3(r.randf_range(-0.4, 0.4), 0.06, r.randf_range(-0.3, 0.3)), B.mat(Color.from_hsv(r.randf(), 0.7, 0.8), 0.8), Vector3.ONE, 6)

func _outdoor(n: Node3D, z: float, lat: float, r: RandomNumberGenerator) -> void:
	var p := ponto_estrada(z, lat)
	if perto_de_feature(p.x, p.z, 8.0):
		return
	p.y = altura(p.x, p.z)
	var o := Node3D.new()
	o.position = p
	var d := direcao(z)
	o.rotation.y = atan2(d.x, d.z) + PI + r.randf_range(-0.3, 0.3)
	n.add_child(o)
	var metal := B.mat(Color(0.3, 0.3, 0.3), 0.5, 0.6, "metal_outdoor")
	for x in [-2.5, 2.5]:
		B.box(o, Vector3(0.25, 5.0, 0.25), Vector3(x, 2.5, 0), metal)
	B.box(o, Vector3(8.0, 3.2, 0.15), Vector3(0, 6.2, 0), B.mat(B.worn(Color.from_hsv(r.randf(), 0.5, 0.6), 0.35), 0.9))
	if r.randf() < 0.5:
		var rasgo := B.box(o, Vector3(2.5, 1.6, 0.02), Vector3(r.randf_range(-2.5, 2.5), 5.8, 0.09), B.mat(Color(0.45, 0.42, 0.38), 0.9))
		rasgo.rotation.z = r.randf_range(-0.4, 0.4)
	var lbl := Label3D.new()
	lbl.text = OUTDOORS[r.randi() % OUTDOORS.size()]
	lbl.font_size = 160
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0.1, 0.08, 0.06)
	lbl.modulate = Color(0.95, 0.92, 0.82)
	lbl.pixel_size = 0.006
	lbl.width = 1200
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.position = Vector3(0, 6.2, 0.1)
	lbl.shaded = true
	o.add_child(lbl)

func _ponto_onibus(n: Node3D, z: float, lat: float, r: RandomNumberGenerator) -> void:
	var p := ponto_estrada(z, lat)
	if perto_de_feature(p.x, p.z, 5.0):
		return
	p.y = altura(p.x, p.z)
	var o := Node3D.new()
	o.position = p
	var d := direcao(z)
	o.rotation.y = atan2(d.x, d.z) + (PI * 0.5 if lat > 0 else -PI * 0.5)
	n.add_child(o)
	var conc := B.mat(Color(0.55, 0.53, 0.5), 0.95, 0.0, "concreto")
	B.box(o, Vector3(3.2, 0.15, 1.6), Vector3(0, 0.07, 0), conc)
	B.box(o, Vector3(3.2, 2.4, 0.12), Vector3(0, 1.2, -0.75), conc)
	for x in [-1.55, 1.55]:
		B.box(o, Vector3(0.12, 2.4, 1.6), Vector3(x, 1.2, 0), conc)
	B.box(o, Vector3(3.5, 0.12, 1.9), Vector3(0, 2.45, 0.05), conc)
	B.box(o, Vector3(2.6, 0.1, 0.45), Vector3(0, 0.5, -0.45), conc)
	if r.randf() < 0.6:
		var h := criar_zumbi(n, o.transform * Vector3(0.4, 0, -0.2), o.rotation.y + PI, r.randi())

func _engavetamento(n: Node3D, z: float, r: RandomNumberGenerator, k: int) -> void:
	var lado := 1.0 if r.randf() < 0.5 else -1.0
	for i in r.randi_range(4, 7):
		var p := ponto_estrada(z + r.randf_range(-12.0, 12.0), lado * r.randf_range(0.5, LARG_ESTRADA * 0.5 + 2.0))
		p.y = elevacao(p.z)
		var d := direcao(p.z)
		var rc := RandomNumberGenerator.new()
		rc.seed = r.randi()
		carro_abandonado(n, p, atan2(d.x, d.z) + r.randf_range(-1.2, 1.2), rc, "eng:%d:%d" % [k, i])
	_caminhao_tombado(n, z + 4.0, -lado * 1.5, r)

func _caminhao_tombado(n: Node3D, z: float, lat: float, r: RandomNumberGenerator) -> void:
	var p := ponto_estrada(z, lat)
	p.y = maxf(altura(p.x, p.z), elevacao(z))
	var c := Node3D.new()
	c.position = p
	var d := direcao(z)
	c.rotation.y = atan2(d.x, d.z) + r.randf_range(-0.8, 0.8)
	n.add_child(c)
	var corpo := Node3D.new()
	corpo.rotation.z = PI * 0.5 * (1.0 if r.randf() < 0.5 else -1.0)
	corpo.position.y = 1.25
	c.add_child(corpo)
	var cab := B.mat(B.worn(Color.from_hsv(r.randf(), 0.5, 0.5), 0.3), 0.7, 0.3)
	B.box(corpo, Vector3(2.4, 2.5, 2.2), Vector3(0, 0, 4.3), cab)
	B.box(corpo, Vector3(2.5, 2.8, 7.5), Vector3(0, 0.15, -0.6), B.mat(B.worn(Color(0.75, 0.74, 0.7), 0.4), 0.7, 0.4))
	for zz in [4.0, -2.0, -3.4]:
		for s in [-1.0, 1.0]:
			B.wheel(corpo, Vector3(s * 1.1, -1.3, zz), 0.5, 0.35)
	for q in 6:
		var cx := B.box(c, Vector3(0.7, 0.5, 0.6), Vector3(r.randf_range(-3, 3), 0.25, r.randf_range(-5, 3)), B.mat(Color(0.5, 0.38, 0.22), 0.9, 0.0, "caixa_carga"))
		cx.rotation.y = r.randf() * 3.0

func _lojas(n: Node3D, z0: float, k: int, r: RandomNumberGenerator) -> void:
	if r.randf() > 0.5:
		return
	var tipos := [["MERCADINHO", Color(0.15, 0.25, 0.45)], ["FARMÁCIA", Color(0.1, 0.5, 0.25)], ["AUTO PEÇAS", Color(0.55, 0.15, 0.1)], ["FERRAGENS", Color(0.45, 0.35, 0.1)]]
	var t: Array = tipos[r.randi() % tipos.size()]
	var lado := 1.0 if r.randf() < 0.5 else -1.0
	var z := z0 + r.randf_range(14.0, TAM - 14.0)
	var p := ponto_estrada(z, lado * 12.5)
	if perto_de_feature(p.x, p.z, 12.0):
		return
	var d := direcao(z)
	var rot := atan2(d.x, d.z) + (-PI * 0.5 if lado > 0 else PI * 0.5)
	var andares := r.randi_range(1, 3)
	var pr := criar_predio(n, p, rot, "loja", r.randf_range(10.0, 13.0), r.randf_range(9.0, 11.0), andares, r.randi(), "loja:%d" % k)
	pr.set_meta("tabela_loja", "farmacia" if t[0] == "FARMÁCIA" else ("galpao" if t[0] == "AUTO PEÇAS" else "loja"))
	var placa := Node3D.new()
	placa.position = Vector3(0, 2.75, pr.profundidade * 0.5 + 0.15)
	pr.add_child(placa)
	B.box(placa, Vector3(pr.largura * 0.8, 0.7, 0.2), Vector3.ZERO, B.mat(t[1], 0.7))
	var lbl := Label3D.new()
	lbl.text = t[0]
	lbl.font_size = 110
	lbl.outline_size = 0
	lbl.modulate = Color(0.95, 0.93, 0.85)
	lbl.pixel_size = 0.006
	lbl.position = Vector3(0, 0, 0.11)
	lbl.shaded = true
	placa.add_child(lbl)
	for q in r.randi_range(1, 3):
		criar_zumbi(n, pr.transform * Vector3(r.randf_range(-4, 4), 0, pr.profundidade * 0.5 + r.randf_range(1, 5)), r.randf() * TAU, r.randi())

# ------------------------------------------------------------ marcos
func _marco_barreira(n: Node3D, ri: int, m: Dictionary) -> void:
	var r := _rng_chunk(ri, 50)
	var concreto := B.mat(Color(0.62, 0.6, 0.56), 0.95, 0.0, "concreto_claro")
	var listra := B.mat(Color(0.8, 0.45, 0.08), 0.8)
	var saco := B.mat(Color(0.48, 0.42, 0.3), 1.0, 0.0, "sacos")
	var oliva := B.mat(B.worn(Color(0.26, 0.3, 0.18), 0.5), 0.8, 0.2)
	var lat := -29.0
	while lat <= 29.0:
		var p := ponto_estrada(m.z, lat)
		p.y = maxf(altura(p.x, p.z), elevacao(m.z) if absf(lat) < LARG_ESTRADA * 0.5 + 1.0 else -INF)
		var bl := Node3D.new()
		bl.position = p
		var d := direcao(m.z)
		bl.rotation.y = atan2(d.x, d.z) + PI * 0.5 + r.randf_range(-0.08, 0.08)
		n.add_child(bl)
		var perfil := PackedVector2Array([Vector2(-0.35, 0), Vector2(0.35, 0), Vector2(0.18, 0.3), Vector2(0.1, 0.85), Vector2(-0.1, 0.85), Vector2(-0.18, 0.3)])
		B.extruded(bl, perfil, 1.9, Vector3.ZERO, concreto)
		if int(lat) % 4 == 0:
			B.box(bl, Vector3(1.0, 0.18, 0.02), Vector3(0, 0.55, 0.13), listra)
		lat += 2.0
	# sacos de areia, caminhão e torre
	for s in [-1.0, 1.0]:
		for k in 8:
			var p := ponto_estrada(m.z + 3.5, s * (LARG_ESTRADA * 0.5 + 1.0 + k * 0.7))
			p.y = altura(p.x, p.z)
			for q in 2:
				B.box(n, Vector3(0.65, 0.28, 0.4), p + Vector3(0, 0.15 + q * 0.28, 0), saco)
	var pc := ponto_estrada(m.z + 9.0, -m.lado * 3.0)
	pc.y = elevacao(m.z + 9.0)
	var cam := Node3D.new()
	cam.position = pc
	var dd := direcao(m.z)
	cam.rotation.y = atan2(dd.x, dd.z) + 0.4
	n.add_child(cam)
	B.box(cam, Vector3(2.4, 2.0, 2.2), Vector3(0, 1.6, 2.8), oliva)
	B.box(cam, Vector3(2.5, 0.4, 6.0), Vector3(0, 0.75, -0.6), oliva)
	var lona := B.box(cam, Vector3(2.5, 2.3, 4.6), Vector3(0, 2.1, -1.3), B.mat(Color(0.3, 0.32, 0.2), 1.0))
	for z in [2.6, -0.8, -2.6]:
		for s in [-1.0, 1.0]:
			B.wheel(cam, Vector3(s * 1.15, 0.5, z), 0.5, 0.35)
	var torre := ponto_estrada(m.z + 6.0, m.lado * 14.0)
	torre.y = altura(torre.x, torre.z)
	var madeira := B.mat(Color(0.3, 0.24, 0.17), 0.95)
	for dx in [-1.2, 1.2]:
		for dz in [-1.2, 1.2]:
			B.box(n, Vector3(0.2, 6.0, 0.2), torre + Vector3(dx, 3.0, dz), madeira)
	B.box(n, Vector3(3.0, 0.2, 3.0), torre + Vector3(0, 5.8, 0), madeira)
	B.box(n, Vector3(3.0, 1.0, 3.0), torre + Vector3(0, 6.4, 0), saco)
	var hol := OmniLight3D.new()
	hol.light_color = Color(1.0, 0.85, 0.6)
	hol.light_energy = 0.0
	hol.position = torre + Vector3(0, 7.5, 0)
	n.add_child(hol)
	_placa_texto(n, m.z - 8.0, -2.0, "PARE\nÁREA MILITAR", Color(0.95, 0.3, 0.2))
	# arame farpado estendido no acostamento
	for s in [-1.0, 1.0]:
		for k in 14:
			var p := ponto_estrada(m.z - 1.6, s * (8.0 + k * 1.6))
			p.y = altura(p.x, p.z)
			var aro := B.cyl(n, 0.4, 0.03, p + Vector3(0, 0.4, 0), B.mat(Color(0.35, 0.35, 0.35), 0.4, 0.8, "arame"), Vector3(0, 0, 90), 10)
	for i in 5:
		var p := ponto_estrada(m.z - r.randf_range(4.0, 14.0), r.randf_range(-12.0, 12.0))
		p.y = maxf(altura(p.x, p.z), elevacao(p.z))
		var z := criar_zumbi(n, p, r.randf() * TAU, r.randi())

func _marco_ponte(n: Node3D, ri: int, m: Dictionary) -> void:
	var r := _rng_chunk(ri, 51)
	var rio := _dados_rio(ri)
	var concreto := B.mat(Color(0.58, 0.56, 0.52), 0.95, 0.0, "concreto_claro")
	# água do rio
	var pm := PlaneMesh.new()
	pm.size = Vector2(ALCANCE_X * 2.0, rio.largura + 6.0)
	var agua := MeshInstance3D.new()
	agua.mesh = pm
	agua.material_override = mat_agua
	agua.position = Vector3(centro_x(m.z), rio.agua, m.z)
	agua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(agua)
	# tabuleiro da ponte (a estrada por cima) com o meio caído
	var hw := LARG_ESTRADA * 0.5
	for lado_z in [-1.0, 1.0]:
		var za: float = m.z + lado_z * 4.5
		var zb: float = m.z + lado_z * (rio.largura * 0.5 + 6.0)
		var mid := (za + zb) * 0.5
		var p := Vector3(centro_x(mid), elevacao(mid) - 0.45, mid)
		B.box(n, Vector3(LARG_ESTRADA + 1.4, 0.8, absf(zb - za)), p, concreto)
		for s in [-1.0, 1.0]:
			B.box(n, Vector3(0.25, 1.0, absf(zb - za)), p + Vector3(s * (hw + 0.6), 0.9, 0), concreto)
		var pil := Vector3(centro_x(za + lado_z * 3.0), 0, za + lado_z * 3.0)
		for s in [-1.0, 1.0]:
			var topo := elevacao(pil.z) - 0.8
			var base: float = rio.margem - rio.prof
			B.box(n, Vector3(1.2, topo - base, 1.2), Vector3(pil.x + s * 2.5, (topo + base) * 0.5, pil.z), concreto)
	# pedaço caído dentro d'água
	var laje := B.box(n, Vector3(LARG_ESTRADA + 1.2, 0.7, 8.5), Vector3(centro_x(m.z) + 0.8, rio.agua + 0.1, m.z + 0.6), concreto)
	laje.rotation = Vector3(0.35, 0.1, -0.12)
	for k in 6:
		var ent := B.box(n, Vector3(r.randf_range(0.5, 1.5), r.randf_range(0.3, 0.8), r.randf_range(0.5, 1.4)), Vector3(centro_x(m.z) + r.randf_range(-6, 6), rio.agua + 0.1, m.z + r.randf_range(-4, 4)), concreto)
		ent.rotation = Vector3(r.randf(), r.randf() * 3.0, r.randf())
	# carro que caiu pela ponte
	var cp := Vector3(centro_x(m.z) - 2.5, rio.agua - 0.4, m.z - 2.0)
	var rc := RandomNumberGenerator.new()
	rc.seed = r.randi()
	var car := carro_abandonado(n, cp, 0.9, rc)
	car.rotation.x = 0.5
	# estacas marcando o vau
	for k in 4:
		for s in [-1.0, 1.0]:
			var x: float = rio.vau_x + s * 3.0
			var z: float = m.z - rio.largura * 0.5 + k * rio.largura / 3.0
			B.cyl(n, 0.07, 2.2, Vector3(x, rio.agua + 0.6, z), B.mat(Color(0.85, 0.85, 0.8), 0.8, 0.0, "estaca"), Vector3.ZERO, 6)
			B.box(n, Vector3(0.16, 0.25, 0.16), Vector3(x, rio.agua + 1.6, z), B.mat(Color(0.85, 0.3, 0.1), 0.8))

# ------------------------------------------------------------ pontos de interesse
func _poi_posto(n: Node3D, z0: float, k: int) -> void:
	var r := _rng_chunk(k, 4)
	var z := z0 + 44.0
	var lado := -1.0 if (r.randf() < 0.6 or pois_fixos.has(k)) else 1.0
	var c := ponto_estrada(z, lado * 21.0)
	c.y = elevacao(z) - 0.02
	var p := Node3D.new()
	p.position = c
	var d := direcao(z)
	p.rotation.y = atan2(d.x, d.z)
	n.add_child(p)
	var concreto := B.mat(Color(0.42, 0.4, 0.37), 0.95, 0.0, "concreto")
	var vermelho := B.mat(B.worn(Color(0.62, 0.1, 0.07), 0.4), 0.8)
	var branco := B.mat(B.worn(Color(0.8, 0.78, 0.72), 0.45), 0.85)
	# piso
	B.box(p, Vector3(26, 0.12, 24), Vector3(0, 0.0, 0), concreto)
	# cobertura das bombas
	B.box(p, Vector3(12, 0.7, 8), Vector3(lado * 4.0, 5.6, 0), branco)
	B.box(p, Vector3(12.05, 0.35, 8.05), Vector3(lado * 4.0, 5.45, 0), vermelho)
	for dx in [-4.5, 4.5]:
		for dz in [-2.5, 2.5]:
			B.box(p, Vector3(0.4, 5.3, 0.4), Vector3(lado * 4.0 + dx, 2.65, dz), branco)
	for dz in [-2.5, 2.5]:
		B.box(p, Vector3(1.6, 0.25, 0.9), Vector3(lado * 4.0, 0.15, dz), concreto)
		for dx in [-0.4, 0.4]:
			var bomba := B.box(p, Vector3(0.55, 1.6, 0.5), Vector3(lado * 4.0 + dx, 1.05, dz), vermelho)
			if r.randf() < 0.3:
				bomba.rotation_degrees.x = 70
				bomba.position.y = 0.45
	# loja
	var lx := lado * 10.5
	B.box(p, Vector3(5, 3.6, 14), Vector3(lx, 1.8, 0), branco)
	B.box(p, Vector3(5.1, 0.5, 14.1), Vector3(lx, 3.4, 0), vermelho)
	var esc := B.mat(Color(0.04, 0.04, 0.04), 0.4, 0.2, "vidro_quebrado")
	B.box(p, Vector3(0.05, 1.8, 9), Vector3(lx - lado * 2.53, 1.5, 0.5), esc)
	# placa alta
	B.cyl(p, 0.15, 8.0, Vector3(lado * 2.0, 4.0, 10.5), branco, Vector3.ZERO, 8)
	var placa := B.box(p, Vector3(3.2, 1.5, 0.3), Vector3(lado * 2.0, 8.3, 10.5), vermelho)
	placa.rotation_degrees.z = 7
	var lbl := Label3D.new()
	lbl.text = "POSTO"
	lbl.font_size = 140
	lbl.outline_size = 0
	lbl.modulate = Color(0.9, 0.85, 0.75)
	lbl.position = Vector3(lado * 2.0, 8.3, 10.67)
	lbl.rotation_degrees = Vector3(0, 0, 7)
	lbl.pixel_size = 0.006
	p.add_child(lbl)
	var lbl2 := lbl.duplicate()
	lbl2.position.z = 10.33
	lbl2.rotation_degrees = Vector3(0, 180, -7)
	p.add_child(lbl2)
	# entulho
	for i in 18:
		var e := B.box(p, Vector3(r.randf_range(0.2, 1.2), r.randf_range(0.05, 0.3), r.randf_range(0.2, 1.0)), Vector3(r.randf_range(-12, 12), 0.1, r.randf_range(-11, 11)), concreto if r.randf() < 0.6 else vermelho)
		e.rotation_degrees = Vector3(r.randf_range(-15, 15), r.randf() * 360, r.randf_range(-15, 15))

func _poi_placa(n: Node3D, z0: float, k: int) -> void:
	var z := z0 + 20.0
	var p := ponto_estrada(z, LARG_ESTRADA * 0.5 + 2.4)
	p.y = altura(p.x, z)
	var pl := Node3D.new()
	pl.position = p
	var d := direcao(z)
	pl.rotation.y = atan2(d.x, d.z) + PI + 0.25
	pl.rotation_degrees.z = -6
	n.add_child(pl)
	var verde := B.mat(B.worn(Color(0.08, 0.3, 0.18), 0.55), 0.7, 0.2)
	var metal := B.mat(Color(0.35, 0.35, 0.35), 0.5, 0.7)
	for x in [-1.1, 1.1]:
		B.cyl(pl, 0.05, 2.6, Vector3(x, 1.3, -0.05), metal, Vector3.ZERO, 6)
	B.box(pl, Vector3(3.2, 1.5, 0.05), Vector3(0, 2.1, 0), verde)
	B.box(pl, Vector3(3.05, 1.35, 0.01), Vector3(0, 2.1, 0.03), B.mat(Color(0.75, 0.75, 0.7), 0.6))
	B.box(pl, Vector3(2.95, 1.25, 0.01), Vector3(0, 2.1, 0.035), verde)
	var lbl := Label3D.new()
	lbl.text = "ZONA\nSEGURA  →"
	lbl.font_size = 96
	lbl.line_spacing = -12
	lbl.modulate = Color(0.82, 0.82, 0.76)
	lbl.outline_size = 0
	lbl.pixel_size = 0.0055
	lbl.position = Vector3(0, 2.1, 0.045)
	lbl.shaded = true
	pl.add_child(lbl)

func _poi_reboque(n: Node3D, z0: float, k: int, tipo := "") -> void:
	if reboques_levados.has(k):
		return
	var r := _rng_chunk(k, 6)
	if tipo == "":
		tipo = TIPOS_REBOQUE[r.randi() % TIPOS_REBOQUE.size()]
	var z := z0 + 30.0
	var lado := 1.0 if r.randf() < 0.5 else -1.0
	var p := ponto_estrada(z, lado * (LARG_ESTRADA * 0.5 + 4.0))
	p.y = altura(p.x, z)
	var reb := Reboque.new()
	reb.tipo = tipo
	reb.nivel = 1
	if estado_reboques.has(k):
		reb.carregar(estado_reboques[k])
	else:
		reb.gerar_abandonado(r)
	reb.position = p
	var d := direcao(z)
	reb.rotation.y = atan2(d.x, d.z) + r.randf_range(-0.5, 0.5) + (PI if r.randf() < 0.5 else 0.0)
	reb.rotation.z = (0.09 if reb.defeitos.has("eixo") else 0.03) * lado
	reb.set_meta("chunk", k)
	n.add_child(reb)
	reboques_soltos.append(reb)

## Posição aproximada de um reboque que ainda vai ser gerado (para o marcador do rádio).
func posicao_poi_reboque(k: int) -> Vector3:
	return ponto_estrada(k * TAM + 30.0, 0.0)

func _poi_vazio(_n: Node3D, _z0: float, _k: int) -> void:
	pass

# ------------------------------------------------------------ zumbis
func _zumbis(n: Node3D, z0: float, k: int) -> void:
	var r := _rng_chunk(k, 5)
	for i in r.randi_range(0, 3):
		var z := z0 + r.randf() * TAM
		var lat := r.randf_range(-25, 25)
		var p := ponto_estrada(z, lat)
		p.y = altura(p.x, z) if absf(lat) > 5.0 else elevacao(z) + 0.06
		criar_zumbi(n, p, r.randf() * TAU, r.randi())

func sortear_tipo_zumbi(r: RandomNumberGenerator) -> String:
	var a := nivel_ameaca + absf(r.randf()) * 0.0
	var x := r.randf()
	var especiais := clampf(0.12 + a * 0.05, 0.12, 0.5)
	if x > especiais:
		return "comum"
	var y := r.randf()
	if y < 0.4:
		return "corredor"
	if y < 0.62:
		return "rastejante"
	if y < 0.82:
		return "gritador"
	return "brutamonte"

func criar_zumbi(n: Node3D, p: Vector3, rot_y: float, sem: int, tipo := "") -> Zumbi:
	var r := RandomNumberGenerator.new()
	r.seed = sem
	var z := Zumbi.new()
	z.mundo = self
	z.semente = sem
	var peles := [Color(0.48, 0.5, 0.42), Color(0.42, 0.4, 0.36), Color(0.55, 0.52, 0.45)]
	z.pele = peles[r.randi() % peles.size()]
	z.camisa = Color.from_hsv(r.randf(), r.randf_range(0.1, 0.4), r.randf_range(0.12, 0.35))
	z.calca = Color.from_hsv(r.randf(), r.randf_range(0.1, 0.3), r.randf_range(0.1, 0.25))
	z.configurar(tipo if tipo != "" else sortear_tipo_zumbi(r))
	z.position = p
	z.rotation.y = rot_y
	n.add_child(z)
	zumbis_vivos.append(z)
	return z

## Silhuetas baratas para hordas distantes.
func silhueta(n: Node3D, p: Vector3, r: RandomNumberGenerator) -> void:
	var s := Node3D.new()
	s.position = p
	s.rotation.y = r.randf() * TAU
	n.add_child(s)
	var m := B.mat(Color(0.08, 0.07, 0.07), 1.0, 0.0, "silhueta")
	B.capsule(s, 0.16, 0.85, Vector3(0, 1.25, 0), m, Vector3(r.randf_range(8, 25), 0, r.randf_range(-10, 10)))
	B.sphere(s, 0.11, Vector3(0, 1.75, 0.1), m)
	B.capsule(s, 0.08, 0.95, Vector3(-0.08, 0.47, 0), m)
	B.capsule(s, 0.08, 0.95, Vector3(0.08, 0.47, 0.05), m)
	B.capsule(s, 0.05, 0.6, Vector3(-0.22, 1.35, 0.25), m, Vector3(-75, 0, 0))

# ------------------------------------------------------------ montanhas ao longe
func _criar_montanhas() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 160
	var raio := 950.0
	var nz := FastNoiseLite.new()
	nz.seed = semente + 7
	nz.frequency = 2.2
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var h0 := 40.0 + (nz.get_noise_1d(float(i) / segs) * 0.5 + 0.5) * 120.0
		var h1 := 40.0 + (nz.get_noise_1d(float(i + 1) / segs) * 0.5 + 0.5) * 120.0
		var b0 := Vector3(cos(a0) * raio, -20, sin(a0) * raio)
		var b1 := Vector3(cos(a1) * raio, -20, sin(a1) * raio)
		var t0 := Vector3(cos(a0) * raio * 0.97, h0, sin(a0) * raio * 0.97)
		var t1 := Vector3(cos(a1) * raio * 0.97, h1, sin(a1) * raio * 0.97)
		for v in [b0, t0, t1, b0, t1, b1]:
			st.set_normal(-Vector3(v.x, 0, v.z).normalized())
			st.add_vertex(v)
	_montanhas = MeshInstance3D.new()
	_montanhas.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.14, 0.17)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_montanhas.material_override = m
	_montanhas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_montanhas)
