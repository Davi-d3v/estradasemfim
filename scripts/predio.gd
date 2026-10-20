class_name Predio
extends Node3D
## Construção em que dá para entrar: andares, cômodos com portas, escadas e
## móveis que podem ser vasculhados um a um. Gera também a colisão (paredes)
## e a altura do piso para o jogador e os zumbis.
## Espaço local: frente (porta principal) em +Z, origem no centro do térreo.

const H := 3.0          # altura de cada andar
const ESP := 0.18       # espessura das paredes
const PORTA := 1.05     # largura das portas internas
const ESC_LARG := 1.1   # largura da escada
const ESC_COMP := 3.6   # comprimento da escada

var tipo := "casa"      # casa, sobrado, loja, apto, cabana, sede, torre
var largura := 9.0      # X
var profundidade := 8.0 # Z
var andares := 1
var semente := 0
var chave := ""         # prefixo único (para lembrar o que já foi vasculhado)
var mundo: WorldGen
var condicao := 0.5     # 0 destruído .. 1 inteiro

var andar_nos: Array[Node3D] = []   # geometria por andar (para esconder ao entrar)
var telhado: Node3D
var paredes: Array = []             # por andar: Array de [Vector2 a, Vector2 b]
var escadas: Array = []             # [{andar, rect: Rect2, dir: 1 (sobe para +Z) ou -1}]
var furos: Array = []               # por andar (>0): Rect2 do vão da escada
var comodos: Array = []             # por andar: Array de {rect, uso}
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _cor_detalhe := Color(0.3, 0.42, 0.36)

func _ready() -> void:
	_rng.seed = semente
	construir()
	if mundo:
		mundo.estruturas.append(self)

# ---------------------------------------------------------------- consultas (espaço do mundo)
func local(p: Vector3) -> Vector3:
	return global_transform.affine_inverse() * p

func dentro(p: Vector3, margem := 0.0) -> bool:
	var l := local(p)
	return absf(l.x) < largura * 0.5 + margem and absf(l.z) < profundidade * 0.5 + margem and l.y > -1.5 and l.y < andares * H + 0.5

func andar_em(y_local: float) -> int:
	return clampi(int(floor((y_local + 0.4) / H)), 0, andares - 1)

## Altura do piso sob o ponto, dado onde o pé está agora (sobe degraus, cai em vãos).
func piso(p: Vector3) -> float:
	var l := local(p)
	var c := Vector2(l.x, l.z)
	var melhor := -INF
	for k in andares:
		var hk := k * H
		if k > 0 and (furos[k] as Rect2).has_point(c):
			continue
		if hk <= l.y + 0.65:
			melhor = maxf(melhor, hk)
	for e in escadas:
		var r: Rect2 = e.rect
		if r.has_point(c):
			var t := (c.y - r.position.y) / r.size.y
			if e.dir < 0:
				t = 1.0 - t
			var he: float = e.andar * H + clampf(t, 0.0, 1.0) * H
			if he <= l.y + 0.65:
				melhor = maxf(melhor, he)
	if melhor == -INF:
		melhor = 0.0
	return (global_transform * Vector3(l.x, melhor, l.z)).y

## O movimento de a para b (mundo) atravessa uma parede?
func colide(a: Vector3, b: Vector3, raio := 0.28) -> bool:
	var la := local(a)
	var lb := local(b)
	var k := andar_em(la.y)
	var p := Vector2(lb.x, lb.z)
	for s in paredes[k]:
		if _dist_seg(p, s[0], s[1]) < raio + ESP * 0.5:
			# só bloqueia se estava se aproximando (permite sair se ficou preso)
			var antes := _dist_seg(Vector2(la.x, la.z), s[0], s[1])
			if antes >= _dist_seg(p, s[0], s[1]) - 0.001:
				return true
	return false

func _dist_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Esconde andares acima do jogador e o telhado (vista em corte ao entrar).
func corte(andar_jogador: int) -> void:
	for k in andar_nos.size():
		andar_nos[k].visible = andar_jogador < 0 or k <= andar_jogador
	if telhado:
		telhado.visible = andar_jogador < 0

# ---------------------------------------------------------------- construção
func _m(nome: String, cor: Color, rough := 0.9, metal := 0.0) -> Material:
	if not _mats.has(nome):
		_mats[nome] = Texturas.material(nome, cor, rough, metal)
	return _mats[nome]

func construir() -> void:
	for c in get_children():
		c.queue_free()
	andar_nos.clear()
	paredes.clear()
	_panos_livres.clear()
	escadas.clear()
	furos.clear()
	comodos.clear()
	var cores := [Color(0.82, 0.76, 0.64), Color(0.66, 0.72, 0.68), Color(0.84, 0.66, 0.52), Color(0.72, 0.7, 0.76), Color(0.88, 0.84, 0.74), Color(0.7, 0.52, 0.42)]
	var cor_ext: Color = cores[_rng.randi() % cores.size()]
	_cor_detalhe = [Color(0.25, 0.4, 0.33), Color(0.45, 0.22, 0.15), Color(0.22, 0.3, 0.45), Color(0.85, 0.82, 0.74), Color(0.35, 0.25, 0.16)][_rng.randi() % 5]
	var ext := _m("reboco", B.worn(cor_ext, condicao))
	if tipo in ["cabana", "torre"]:
		ext = _m("tabuas", Color(0.42, 0.3, 0.2))
	elif tipo in ["loja", "apto"] and _rng.randf() < 0.5:
		ext = _m("tijolo", Color(0.62, 0.34, 0.24))
	var int_cor: Color = [Color(0.85, 0.82, 0.74), Color(0.75, 0.8, 0.78), Color(0.86, 0.78, 0.68)][_rng.randi() % 3]
	var interno := _m("reboco_int", B.worn(int_cor, condicao + 0.2))
	var piso_m := _m("piso_madeira" if tipo != "loja" else "piso_ceramica", Color(0.45, 0.32, 0.2) if tipo != "loja" else Color(0.7, 0.68, 0.62))
	# plano dos cômodos: o mesmo layout de paredes em todos os andares
	var plano := _plano()
	# escada: encostada na parede de trás, à esquerda
	var esc := Rect2(-largura * 0.5 + 0.3, -profundidade * 0.5 + 0.3, ESC_LARG, ESC_COMP)
	if tipo == "torre":
		esc = Rect2(-ESC_LARG * 0.5, -profundidade * 0.5 + 0.2, ESC_LARG, profundidade - 0.4)
	for k in andares:
		var no := Node3D.new()
		no.name = "Andar%d" % k
		add_child(no)
		andar_nos.append(no)
		var segs: Array = []
		var y0 := k * H
		# piso (com vão da escada a partir do 1º andar)
		var furo := Rect2() if k == 0 else esc
		furos.append(furo)
		_laje(no, y0, furo, piso_m if k > 0 or tipo != "torre" else _m("tabuas", Color(0.4, 0.3, 0.2)))
		if tipo == "torre":
			# torre: só pilares e guarda-corpo, sem paredes
			_torre_andar(no, k, y0, segs)
		else:
			_paredes_ext(no, k, y0, ext, interno, segs)
			for w in plano.paredes:
				_parede_int(no, w, y0, interno, segs, k)
			var lista: Array = []
			for r in plano.comodos:
				var uso: String = r.uso
				if k > 0 and tipo == "loja":
					uso = ["quarto", "sala", "cozinha", "banheiro"][(lista.size() + k) % 4]
				elif k > 0 and tipo == "sobrado" and uso in ["cozinha", "sala"]:
					uso = "quarto"
				lista.append({"rect": r.rect, "uso": uso})
				_mobiliar(no, r.rect, uso, y0, k, esc)
			comodos.append(lista)
		paredes.append(segs)
		if k < andares - 1:
			escadas.append({"andar": k, "rect": esc, "dir": 1})
			_escada(no, esc, y0)
	# laje / telhado
	telhado = Node3D.new()
	telhado.name = "Telhado"
	add_child(telhado)
	_telhado(andares * H)
	# luz fraca entrando pelas janelas (cômodos não ficam pretos)
	for k in andares:
		var l := OmniLight3D.new()
		l.light_color = Color(0.9, 0.85, 0.75)
		l.light_energy = 0.35
		l.omni_range = maxf(largura, profundidade) * 0.8
		l.position = Vector3(0, k * H + 2.4, 0)
		andar_nos[k].add_child(l)
	if tipo in ["casa", "sobrado", "sede"]:
		_fachada(cor_ext)
	for no in andar_nos:
		B.mesclar(no)
	B.mesclar(telhado)

## Divide a planta em cômodos (BSP simples) e devolve paredes internas com portas.
func _plano() -> Dictionary:
	var r0 := Rect2(-largura * 0.5, -profundidade * 0.5, largura, profundidade)
	var comodos_l: Array = []
	var paredes_l: Array = []
	if tipo in ["torre"]:
		return {"comodos": [], "paredes": []}
	if tipo == "cabana":
		return {"comodos": [{"rect": r0, "uso": "cabana"}], "paredes": []}
	if tipo == "loja":
		# loja: salão grande na frente e depósito atrás
		var zc := r0.position.y + profundidade * 0.32
		comodos_l.append({"rect": Rect2(r0.position.x, zc, largura, r0.end.y - zc), "uso": "loja"})
		comodos_l.append({"rect": Rect2(r0.position.x, r0.position.y, largura, zc - r0.position.y), "uso": "deposito"})
		paredes_l.append({"a": Vector2(r0.position.x, zc), "b": Vector2(r0.end.x, zc), "porta": largura * 0.25})
		return {"comodos": comodos_l, "paredes": paredes_l}
	# casa/sobrado/apto/sede: frente = sala; fundos divididos em 2-3 cômodos
	var zc := r0.position.y + profundidade * _rng.randf_range(0.42, 0.52)
	comodos_l.append({"rect": Rect2(r0.position.x, zc, largura, r0.end.y - zc), "uso": "sala"})
	paredes_l.append({"a": Vector2(r0.position.x, zc), "b": Vector2(r0.end.x, zc), "porta": _rng.randf_range(-largura * 0.15, largura * 0.25)})
	var n_fundo := 3 if largura > 8.5 else 2
	var x := r0.position.x
	var usos := ["cozinha", "quarto", "banheiro"] if n_fundo == 3 else ["cozinha", "quarto"]
	if _rng.randf() < 0.5:
		usos.reverse()
	for i in n_fundo:
		var w := largura / n_fundo
		comodos_l.append({"rect": Rect2(x, r0.position.y, w, zc - r0.position.y), "uso": usos[i]})
		if i > 0:
			paredes_l.append({"a": Vector2(x, r0.position.y), "b": Vector2(x, zc), "porta": INF})   # sem porta entre cômodos de fundo
		x += w
	return {"comodos": comodos_l, "paredes": paredes_l}

func _laje(no: Node3D, y: float, furo: Rect2, m: Material) -> void:
	var r := Rect2(-largura * 0.5, -profundidade * 0.5, largura, profundidade)
	if furo.size == Vector2.ZERO:
		B.box(no, Vector3(largura, 0.14, profundidade), Vector3(0, y - 0.07, 0), m)
		return
	# quatro pedaços em volta do vão
	var partes := [
		Rect2(r.position.x, r.position.y, furo.position.x - r.position.x, r.size.y),
		Rect2(furo.end.x, r.position.y, r.end.x - furo.end.x, r.size.y),
		Rect2(furo.position.x, furo.end.y, furo.size.x, r.end.y - furo.end.y),
		Rect2(furo.position.x, r.position.y, furo.size.x, furo.position.y - r.position.y)]
	for q in partes:
		if q.size.x > 0.01 and q.size.y > 0.01:
			B.box(no, Vector3(q.size.x, 0.14, q.size.y), Vector3(q.get_center().x, y - 0.07, q.get_center().y), m)

var _panos_livres: Array = []   # [{a, b, n}] trechos de parede externa sem aberturas

func _panos_cheios(aberturas: Array, comp: float) -> Array:
	var r: Array = []
	var pos := 0.35                      # longe do pilar do canto
	var ord := aberturas.duplicate()
	ord.sort_custom(func(p, q): return p[0] < q[0])
	for ab in ord:
		var ini: float = ab[0] - ab[1] * 0.5 - 0.15
		if ini - pos > 0.9:
			r.append([pos, ini])
		pos = maxf(pos, ab[0] + ab[1] * 0.5 + 0.15)
	if comp - 0.35 - pos > 0.9:
		r.append([pos, comp - 0.35])
	return r

## Paredes externas com janelas e a porta da frente (térreo).
func _paredes_ext(no: Node3D, k: int, y0: float, ext: Material, interno: Material, segs: Array) -> void:
	var hw := largura * 0.5
	var hd := profundidade * 0.5
	var lados := [
		{"a": Vector2(-hw, hd), "b": Vector2(hw, hd), "frente": true},
		{"a": Vector2(hw, -hd), "b": Vector2(-hw, -hd), "frente": false},
		{"a": Vector2(-hw, -hd), "b": Vector2(-hw, hd), "frente": false},
		{"a": Vector2(hw, hd), "b": Vector2(hw, -hd), "frente": false}]
	var vidro := _m("vidro_sujo", Color(0.12, 0.14, 0.15), 0.2)
	var tabua := _m("tabuas", Color(0.42, 0.3, 0.2))
	for lado in lados:
		var a: Vector2 = lado.a
		var b: Vector2 = lado.b
		var comp := a.distance_to(b)
		var dir := (b - a) / comp
		var aberturas: Array = []   # [centro ao longo, largura, base, topo, porta?]
		if lado.frente and k == 0:
			aberturas.append([comp * 0.5 + (largura * 0.2 if tipo != "loja" else 0.0), 1.1 if tipo != "loja" else largura * 0.55, 0.0, 2.2, true])
		var n_jan := int(comp / 3.2)
		for i in n_jan:
			var c := (i + 0.5) * comp / n_jan
			var livre := true
			for ab in aberturas:
				if absf(c - ab[0]) < ab[1] * 0.5 + 0.8:
					livre = false
			if livre and _rng.randf() < 0.8:
				aberturas.append([c, 1.1, 1.0, 2.2, false])
		aberturas.sort_custom(func(p, q): return p[0] < q[0])
		var pos := 0.0
		var segs_lado: Array = []
		for ab in aberturas + [[comp + 10.0, 0.0, 0.0, 0.0, false]]:
			var ini: float = ab[0] - ab[1] * 0.5
			if ab[0] > comp + 5.0:
				ini = comp
			if ini > pos + 0.01:
				_pano(no, a + dir * pos, a + dir * ini, y0, y0 + H, ext, interno)
				segs_lado.append([pos, ini])
			if ab[0] > comp + 5.0:
				break
			var fim: float = ab[0] + ab[1] * 0.5
			# acima e abaixo da abertura
			if ab[2] > 0.0:
				_pano(no, a + dir * ini, a + dir * fim, y0, y0 + ab[2], ext, interno)
			_pano(no, a + dir * ini, a + dir * fim, y0 + ab[3], y0 + H, ext, interno)
			var meio = a + dir * ab[0]
			var n := Vector3(-dir.y, 0, dir.x)
			if not ab[4]:
				# janela: vidro quebrado ou tábuas pregadas
				var jan := Node3D.new()
				jan.position = Vector3(meio.x, y0 + (ab[2] + ab[3]) * 0.5, meio.y)
				jan.rotation.y = atan2(dir.x, dir.y) - PI * 0.5
				no.add_child(jan)
				var residencial := tipo in ["casa", "sobrado", "sede"]
				if _rng.randf() < (1.0 - condicao) * 0.55:
					for q in 3:
						var t := B.box(jan, Vector3(1.3, 0.16, 0.04), Vector3(0, -0.4 + q * 0.4, 0.12), tabua, Vector3(0, 0, _rng.randf_range(-10, 10)))
				elif _rng.randf() < 0.35 + condicao * 0.5:
					B.box(jan, Vector3(1.05, 1.15, 0.02), Vector3.ZERO, vidro)
					# caixilho em cruz
					B.box(jan, Vector3(0.04, 1.15, 0.04), Vector3(0, 0, 0.02), _m("metal", Color(0.25, 0.25, 0.24), 0.5, 0.5))
					B.box(jan, Vector3(1.05, 0.04, 0.04), Vector3(0, 0.1, 0.02), _m("metal", Color(0.25, 0.25, 0.24), 0.5, 0.5))
				if residencial or tipo == "cabana":
					var mold := _m("madeira_movel", _cor_detalhe) if tipo != "cabana" else tabua
					for sy in [-1.0, 1.0]:
						B.box(jan, Vector3(1.28, 0.08, 0.1), Vector3(0, sy * 0.6, 0.04), mold)
						B.box(jan, Vector3(0.08, 1.28, 0.1), Vector3(sy * 0.6, 0, 0.04), mold)
					var sorte := _rng.randf()
					if sorte < 0.55 and tipo != "cabana":
						# venezianas abertas, uma às vezes caída de lado
						for sx in [-1.0, 1.0]:
							var vz := Node3D.new()
							vz.position = Vector3(sx * 0.64, 0, 0.08)
							vz.rotation.y = sx * (_rng.randf_range(1.3, 1.75) if _rng.randf() < 0.85 else _rng.randf_range(0.3, 0.8))
							jan.add_child(vz)
							var folha := Node3D.new()
							folha.position = Vector3(sx * 0.3, 0, 0)
							vz.add_child(folha)
							B.box(folha, Vector3(0.58, 1.18, 0.04), Vector3.ZERO, _m("porta", _cor_detalhe))
							for q in 5:
								B.box(folha, Vector3(0.5, 0.03, 0.05), Vector3(0, -0.45 + q * 0.22, 0.02), _m("porta", _cor_detalhe.darkened(0.15)))
					elif sorte < 0.8:
						# grade de ferro
						var ferro := _m("metal", Color(0.18, 0.17, 0.16), 0.6, 0.7)
						for q in 6:
							B.box(jan, Vector3(0.025, 1.15, 0.025), Vector3(-0.5 + q * 0.2, 0, 0.1), ferro)
						for q in 2:
							B.box(jan, Vector3(1.1, 0.03, 0.03), Vector3(0, -0.35 + q * 0.7, 0.1), ferro)
				B.box(jan, Vector3(1.2, 0.08, 0.26), Vector3(0, -0.6, 0.05), _m("concreto", Color(0.6, 0.58, 0.55)))
				segs_lado.append([ini, fim])   # janela bloqueia a passagem
			if ab[4] and tipo in ["casa", "sobrado", "sede"]:
				_fachada_porta(no, Vector3(meio.x, y0, meio.y), atan2(dir.x, dir.y) - PI * 0.5)
			if ab[4] and tipo != "loja" and _rng.randf() < 0.5:
				# porta de madeira entreaberta
				var porta := B.box(no, Vector3(0.05, 2.15, 1.0), Vector3(meio.x, y0 + 1.08, meio.y) + Vector3(dir.x, 0, dir.y) * -0.5, _m("porta", Color(0.36, 0.24, 0.15)))
				porta.rotation.y = atan2(dir.x, dir.y) + 0.9
			pos = fim
		for sg in segs_lado:
			segs.append([a + dir * sg[0], a + dir * sg[1]])
		# panos de parede inteiros (sem porta nem janela) no térreo: onde cabe pichação
		if k == 0 and not lado.frente:
			for sg in _panos_cheios(aberturas, comp):
				_panos_livres.append({"a": a + dir * sg[0], "b": a + dir * sg[1], "n": Vector3(-dir.y, 0, dir.x)})

## Pano de parede entre dois pontos (face externa e interna com materiais diferentes).
func _pano(no: Node3D, a: Vector2, b: Vector2, y_a: float, y_b: float, ext: Material, interno: Material) -> void:
	var comp := a.distance_to(b)
	if comp < 0.01 or y_b - y_a < 0.01:
		return
	var meio := (a + b) * 0.5
	var ang := atan2(b.y - a.y, b.x - a.x)
	var n := Vector2(-(b - a).y, (b - a).x).normalized()   # aponta para dentro
	for lado in [[ext, -1.0], [interno, 1.0]]:
		var c = meio + n * lado[1] * ESP * 0.25
		var bx := B.box(no, Vector3(comp, y_b - y_a, ESP * 0.5), Vector3(c.x, (y_a + y_b) * 0.5, c.y), lado[0])
		bx.rotation.y = -ang

func _parede_int(no: Node3D, w: Dictionary, y0: float, m: Material, segs: Array, k: int) -> void:
	var a: Vector2 = w.a
	var b: Vector2 = w.b
	var comp := a.distance_to(b)
	var dir := (b - a) / comp
	var c_porta: float = w.porta
	var tem_porta := c_porta != INF
	if tem_porta:
		c_porta = clampf(comp * 0.5 + c_porta, PORTA, comp - PORTA)
	else:
		c_porta = comp * 0.5
		tem_porta = true   # sempre há passagem para não prender o jogador
	var ini := c_porta - PORTA * 0.5
	var fim := c_porta + PORTA * 0.5
	# não deixa a parede atravessar o vão da escada
	for parte in [[0.0, ini], [fim, comp]]:
		if parte[1] - parte[0] > 0.05:
			_pano(no, a + dir * parte[0], a + dir * parte[1], y0, y0 + H, m, m)
			segs.append([a + dir * parte[0], a + dir * parte[1]])
	_pano(no, a + dir * ini, a + dir * fim, y0 + 2.2, y0 + H, m, m)

func _escada(no: Node3D, r: Rect2, y0: float) -> void:
	var m := _m("tabuas", Color(0.4, 0.29, 0.19))
	var n := 14
	for i in n:
		var t := (i + 0.5) / n
		var z := r.position.y + t * r.size.y
		var y := y0 + t * H
		B.box(no, Vector3(r.size.x, 0.12, r.size.y / n + 0.02), Vector3(r.get_center().x, y - 0.06, z), m)
		B.box(no, Vector3(r.size.x, y - y0, 0.04), Vector3(r.get_center().x, y0 + (y - y0) * 0.5, z + r.size.y / n * 0.5), m)
	# corrimão
	var a := Vector3(r.end.x, y0 + 0.9, r.position.y)
	var b := Vector3(r.end.x, y0 + H + 0.9, r.end.y)
	var cr := B.box(no, Vector3(0.05, 0.05, a.distance_to(b)), (a + b) * 0.5, _m("metal", Color(0.2, 0.2, 0.2), 0.5, 0.6))
	cr.look_at_from_position((a + b) * 0.5, b, Vector3.UP)

func _torre_andar(no: Node3D, k: int, y0: float, segs: Array) -> void:
	var m := _m("tabuas", Color(0.4, 0.3, 0.2))
	var hw := largura * 0.5
	var hd := profundidade * 0.5
	for x in [-hw, hw]:
		for z in [-hd, hd]:
			B.box(no, Vector3(0.22, H, 0.22), Vector3(x, y0 + H * 0.5, z), m)
	if k == andares - 1:
		# plataforma de vigia com guarda-corpo e cobertura
		for lado in [[Vector2(-hw, hd), Vector2(hw, hd)], [Vector2(hw, -hd), Vector2(-hw, -hd)], [Vector2(-hw, -hd), Vector2(-hw, hd)], [Vector2(hw, hd), Vector2(hw, -hd)]]:
			var a: Vector2 = lado[0]
			var b: Vector2 = lado[1]
			var meio := (a + b) * 0.5
			var g := B.box(no, Vector3(a.distance_to(b), 1.0, 0.06), Vector3(meio.x, y0 + 0.5, meio.y), m)
			g.rotation.y = -atan2(b.y - a.y, b.x - a.x)
			segs.append([a, b])

func _telhado(y: float) -> void:
	var hw := largura * 0.5 + 0.4
	var hd := profundidade * 0.5 + 0.4
	var telha := _m("telha_velha" if condicao < 0.35 else "telha", Color(0.52, 0.24, 0.15))
	if tipo in ["loja", "apto"]:
		B.box(telhado, Vector3(largura + 0.1, 0.25, profundidade + 0.1), Vector3(0, y + 0.1, 0), _m("concreto", Color(0.55, 0.53, 0.5)))
		B.box(telhado, Vector3(largura + 0.1, 0.8, 0.15), Vector3(0, y + 0.5, profundidade * 0.5), _m("concreto", Color(0.55, 0.53, 0.5)))
		if _rng.randf() < 0.6:
			B.box(telhado, Vector3(1.6, 1.2, 1.2), Vector3(largura * 0.25, y + 0.85, -profundidade * 0.2), _m("metal", Color(0.6, 0.6, 0.6), 0.5, 0.6))
		return
	if tipo == "torre":
		var cob := B.box(telhado, Vector3(largura + 0.8, 0.1, profundidade + 0.8), Vector3(0, y + 1.6, 0), _m("tabuas", Color(0.35, 0.26, 0.18)))
		for x in [-largura * 0.5, largura * 0.5]:
			for z in [-profundidade * 0.5, profundidade * 0.5]:
				B.box(telhado, Vector3(0.14, 1.6, 0.14), Vector3(x, y + 0.8, z), _m("tabuas", Color(0.35, 0.26, 0.18)))
		return
	# duas águas
	var alt := minf(largura, profundidade) * 0.32
	var tri := PackedVector2Array([Vector2(-hd, y), Vector2(hd, y), Vector2(0, y + alt)])
	B.extruded(telhado, tri, largura + 0.8, Vector3.ZERO, telha)
	B.box(telhado, Vector3(largura, 0.1, profundidade), Vector3(0, y + 0.02, 0), _m("reboco_int", Color(0.8, 0.78, 0.72)))
	# cumeeira, testeiras e oitões
	var madeira := _m("madeira_movel", Color(0.32, 0.22, 0.14))
	B.box(telhado, Vector3(largura + 0.9, 0.14, 0.26), Vector3(0, y + alt + 0.02, 0), Texturas.material("telha", Color(0.43, 0.19, 0.12)))
	for sz in [-1.0, 1.0]:
		B.box(telhado, Vector3(largura + 0.85, 0.18, 0.05), Vector3(0, y - 0.02, sz * (hd + 0.02)), madeira)
	if tipo != "cabana":
		# calha e condutor
		var calha := _m("metal", Color(0.55, 0.55, 0.53), 0.5, 0.6)
		B.box(telhado, Vector3(largura + 0.8, 0.1, 0.12), Vector3(0, y - 0.1, hd + 0.08), calha)
		B.cyl(telhado, 0.045, y, Vector3(largura * 0.5 + 0.25, y * 0.5 - 0.1, hd + 0.05), calha, Vector3.ZERO, 6)
	if tipo != "cabana" and _rng.randf() < 0.7:
		var ch := Vector3(largura * 0.28, 0, -profundidade * 0.15)
		B.box(telhado, Vector3(0.7, 1.9, 0.7), ch + Vector3(0, y + alt * 0.7, 0), _m("tijolo", Color(0.55, 0.3, 0.22)))
		B.box(telhado, Vector3(0.85, 0.1, 0.85), ch + Vector3(0, y + alt * 0.7 + 0.98, 0), _m("concreto", Color(0.5, 0.48, 0.45)))
	elif tipo == "cabana":
		B.cyl(telhado, 0.12, 1.4, Vector3(largura * 0.3, y + alt * 0.6, -profundidade * 0.1), _m("metal", Color(0.2, 0.2, 0.2), 0.5, 0.6), Vector3.ZERO, 8)
	if tipo in ["casa", "sobrado"]:
		if _rng.randf() < 0.55:
			# antena de TV torta
			var ant := Node3D.new()
			ant.position = Vector3(-largura * 0.3, y + alt * 0.6, -profundidade * 0.05)
			ant.rotation.z = _rng.randf_range(-0.25, 0.25)
			telhado.add_child(ant)
			var al := _m("metal", Color(0.6, 0.6, 0.6), 0.4, 0.8)
			B.cyl(ant, 0.02, 2.0, Vector3(0, 1.0, 0), al, Vector3.ZERO, 5)
			for q in 4:
				B.box(ant, Vector3(0.9 - q * 0.15, 0.02, 0.02), Vector3(0, 1.4 + q * 0.18, 0), al)
		if _rng.randf() < 0.45:
			# caixa d'água azul de fibra
			B.cyl(telhado, 0.65, 0.8, Vector3(-largura * 0.15, y + alt * 0.55 + 0.4, -profundidade * 0.25), _m("metal", Color(0.18, 0.35, 0.6), 0.6, 0.1), Vector3.ZERO, 14)

# ---------------------------------------------------------------- móveis e o que vasculhar
func _container(no: Node3D, pos: Vector3, nome: String, tabela: String, horas: float) -> void:
	var v := Node3D.new()
	v.position = pos
	no.add_child(v)
	v.set_meta("nome", nome)
	v.set_meta("tabela", tabela)
	v.set_meta("horas", horas)
	v.set_meta("chave", "%s:%s:%d" % [chave, nome, int(pos.x * 10) * 1000 + int(pos.z * 10) + int(pos.y) * 7])
	if mundo:
		mundo.vasculhaveis.append(v)

func _mobiliar(no: Node3D, r: Rect2, uso: String, y0: float, k: int, esc: Rect2) -> void:
	var mad := _m("madeira_movel", Color(0.4, 0.27, 0.16), 0.75)
	var branco := _m("esmalte", Color(0.86, 0.85, 0.8), 0.4)
	var tecido := Texturas.material("tecido", Color.from_hsv(_rng.randf(), 0.35, 0.45), 0.95)
	var r2 := r.grow(-0.45)
	var livre := func(p: Vector2, raio: float) -> bool:
		return not esc.grow(raio + 0.3).has_point(p)
	# cantos do cômodo encostados nas paredes
	var cantos := [Vector2(r2.position.x, r2.position.y), Vector2(r2.end.x, r2.position.y), Vector2(r2.position.x, r2.end.y), Vector2(r2.end.x, r2.end.y)]
	match uso:
		"sala":
			var p: Vector2 = Vector2(r2.get_center().x, r2.position.y + 0.5)
			if livre.call(p, 1.2):
				if Props.existe("sofa"):
					Props.por(no, "sofa", Vector3(p.x, y0, p.y - 0.15), 0.0, _rng.randf_range(0.9, 1.0))
				else:
					B.box(no, Vector3(2.0, 0.45, 0.85), Vector3(p.x, y0 + 0.22, p.y), tecido)
					B.box(no, Vector3(2.0, 0.55, 0.2), Vector3(p.x, y0 + 0.65, p.y - 0.35), tecido)
					for s in [-1.0, 1.0]:
						B.box(no, Vector3(0.2, 0.6, 0.85), Vector3(p.x + s * 1.0, y0 + 0.4, p.y), tecido)
			var e: Vector2 = cantos[1]
			if livre.call(e, 0.6):
				if Props.existe("estante_livros"):
					Props.por(no, "estante_livros", Vector3(e.x - 0.5, y0, e.y + 0.05), 0.0, 0.85)
				else:
					B.box(no, Vector3(0.9, 1.9, 0.38), Vector3(e.x - 0.2, y0 + 0.95, e.y + 0.05), mad)
					for q in 3:
						for b in 4:
							B.box(no, Vector3(0.06, 0.26, 0.2), Vector3(e.x - 0.5 + b * 0.12, y0 + 0.6 + q * 0.5, e.y + 0.05), Texturas.material("tecido", Color.from_hsv(_rng.randf(), 0.5, 0.5)))
				_container(no, Vector3(e.x - 0.2, y0 + 1.0, e.y + 0.4), "Estante", "estante", 0.25)
			var mc := r2.get_center()
			B.box(no, Vector3(1.1, 0.42, 0.6), Vector3(mc.x, y0 + 0.21, mc.y), mad)
			# em cima da mesinha: jornais velhos e o cinzeiro
			Props.por(no, "jornais" if _rng.randf() < 0.5 else "jornal", Vector3(mc.x - 0.2, y0 + 0.42, mc.y), _rng.randf() * 360.0, 0.8, 30.0, false)
			Props.por(no, "cinzeiro_cheio" if _rng.randf() < 0.6 else "cinzeiro", Vector3(mc.x + 0.3, y0 + 0.42, mc.y + 0.1), _rng.randf() * 360.0, 1.0, 25.0, false)
			var c3s: Vector2 = cantos[2]
			if _rng.randf() < 0.6 and livre.call(c3s, 0.7):
				Props.por(no, "poltrona" if _rng.randf() < 0.5 else "poltrona2", Vector3(c3s.x + 0.2, y0, c3s.y - 0.2), 135.0 + _rng.randf_range(-15, 15))
			if _rng.randf() < 0.35:
				Props.por(no, "garrafa", Vector3(mc.x + _rng.randf_range(-0.4, 0.4), y0 + 0.42, mc.y - 0.15), 0.0, 1.0, 25.0, false)
		"cozinha":
			var c0: Vector2 = cantos[0]
			if livre.call(c0, 1.2):
				B.box(no, Vector3(2.2, 0.9, 0.6), Vector3(c0.x + 1.1, y0 + 0.45, c0.y), branco)
				B.box(no, Vector3(2.25, 0.05, 0.65), Vector3(c0.x + 1.1, y0 + 0.92, c0.y), _m("granito", Color(0.25, 0.25, 0.25), 0.3))
				_container(no, Vector3(c0.x + 1.1, y0 + 0.8, c0.y + 0.5), "Armário da cozinha", "armario", 0.25)
				# fogareiro com panela, latas e o botijão do lado
				Props.por(no, "fogareiro", Vector3(c0.x + 1.6, y0 + 0.945, c0.y), 0.0, 0.9, 30.0, false)
				if _rng.randf() < 0.6:
					Props.por(no, "panela" if _rng.randf() < 0.5 else "panela2", Vector3(c0.x + 1.6, y0 + 1.06, c0.y), _rng.randf() * 360.0, 1.0, 25.0, false)
				for i in _rng.randi_range(0, 3):
					Props.por(no, ["lata", "lata_baixa", "pote"][_rng.randi() % 3], Vector3(c0.x + 0.3 + i * 0.16, y0 + 0.945, c0.y - 0.1 + _rng.randf() * 0.15), _rng.randf() * 360.0, 1.0, 20.0, false)
				Props.por(no, "botijao", Vector3(c0.x + 2.5, y0, c0.y), _rng.randf() * 360.0, 1.0, 30.0, false)
			var c1: Vector2 = cantos[1]
			if livre.call(c1, 0.6):
				B.box(no, Vector3(0.7, 1.75, 0.65), Vector3(c1.x - 0.1, y0 + 0.88, c1.y + 0.05), branco)
				B.box(no, Vector3(0.04, 0.5, 0.04), Vector3(c1.x - 0.35, y0 + 1.2, c1.y + 0.4), _m("metal", Color(0.6, 0.6, 0.6), 0.3, 0.8))
				_container(no, Vector3(c1.x - 0.1, y0 + 1.0, c1.y + 0.5), "Geladeira", "geladeira", 0.1)
			var m := r2.get_center()
			B.box(no, Vector3(1.2, 0.05, 0.8), Vector3(m.x, y0 + 0.75, m.y), mad)
			for s in [Vector2(-0.5, -0.3), Vector2(0.5, -0.3), Vector2(-0.5, 0.3), Vector2(0.5, 0.3)]:
				B.box(no, Vector3(0.05, 0.73, 0.05), Vector3(m.x + s.x, y0 + 0.37, m.y + s.y), mad)
			if Props.existe("cadeira"):
				Props.por(no, "cadeira" if _rng.randf() < 0.5 else "cadeira2", Vector3(m.x + 0.2, y0, m.y + 0.55), 180.0 + _rng.randf_range(-20, 20))
				if _rng.randf() < 0.5:
					Props.por(no, "cadeira2", Vector3(m.x - 0.3, y0, m.y - 0.6), _rng.randf_range(-25, 25))
				Props.por(no, "prato", Vector3(m.x + 0.2, y0 + 0.775, m.y + 0.15), 0.0, 1.0, 20.0, false)
				if _rng.randf() < 0.5:
					Props.por(no, "frigideira", Vector3(m.x - 0.3, y0 + 0.775, m.y - 0.1), _rng.randf() * 360.0, 1.0, 20.0, false)
			else:
				var cad := B.box(no, Vector3(0.42, 0.04, 0.42), Vector3(m.x + 0.9, y0 + 0.02, m.y + 0.4), mad)
				cad.rotation = Vector3(1.5, 0.4, 0)
		"quarto":
			var c2: Vector2 = cantos[0]
			if livre.call(c2 + Vector2(0.8, 1.0), 1.0):
				B.box(no, Vector3(1.5, 0.35, 2.0), Vector3(c2.x + 0.75, y0 + 0.2, c2.y + 1.0), mad)
				B.box(no, Vector3(1.45, 0.18, 1.95), Vector3(c2.x + 0.75, y0 + 0.46, c2.y + 1.0), _m("colchao", Color(0.8, 0.78, 0.72)))
				B.box(no, Vector3(1.5, 0.06, 1.3), Vector3(c2.x + 0.75, y0 + 0.58, c2.y + 1.3), tecido)
				B.box(no, Vector3(1.5, 0.9, 0.08), Vector3(c2.x + 0.75, y0 + 0.6, c2.y - 0.02), mad)
				B.box(no, Vector3(0.45, 0.5, 0.4), Vector3(c2.x + 1.8, y0 + 0.25, c2.y + 0.2), mad)
				_container(no, Vector3(c2.x + 1.8, y0 + 0.6, c2.y + 0.5), "Criado-mudo", "gaveta", 0.1)
				Props.por(no, "abajur", Vector3(c2.x + 1.8, y0 + 0.5, c2.y + 0.2), _rng.randf() * 360.0, 0.9, 25.0, false)
			var c4q: Vector2 = cantos[2]
			if livre.call(c4q, 0.8) and r2.size.y > 3.2 and _rng.randf() < 0.7:
				Props.por(no, "comoda" if _rng.randf() < 0.5 else "comoda2", Vector3(c4q.x + 0.7, y0, c4q.y - 0.05), 180.0, 0.9)
				_container(no, Vector3(c4q.x + 0.7, y0 + 0.8, c4q.y - 0.6), "Cômoda", "gaveta", 0.15)
			var c3: Vector2 = cantos[1]
			if livre.call(c3, 0.8):
				B.box(no, Vector3(1.2, 2.0, 0.55), Vector3(c3.x - 0.4, y0 + 1.0, c3.y + 0.1), mad)
				B.box(no, Vector3(0.02, 1.8, 0.02), Vector3(c3.x - 0.4, y0 + 1.0, c3.y + 0.39), _m("metal", Color(0.2, 0.2, 0.2)))
				_container(no, Vector3(c3.x - 0.4, y0 + 1.0, c3.y + 0.6), "Guarda-roupa", "guarda_roupa", 0.25)
		"banheiro":
			var c4: Vector2 = cantos[0]
			if livre.call(c4, 0.6):
				B.box(no, Vector3(0.5, 0.8, 0.4), Vector3(c4.x + 0.25, y0 + 0.4, c4.y), branco)
				B.box(no, Vector3(0.5, 0.6, 0.12), Vector3(c4.x + 0.25, y0 + 1.5, c4.y - 0.1), _m("vidro_sujo", Color(0.5, 0.55, 0.58), 0.1, 0.4))
				_container(no, Vector3(c4.x + 0.25, y0 + 1.0, c4.y + 0.4), "Armarinho do banheiro", "banheiro", 0.1)
			var c5: Vector2 = cantos[3]
			if livre.call(c5, 0.6):
				B.box(no, Vector3(0.45, 0.42, 0.6), Vector3(c5.x - 0.1, y0 + 0.21, c5.y - 0.2), branco)
		"loja":
			for i in 3:
				var x := r2.position.x + (i + 0.5) * r2.size.x / 3.0
				var z1 := r2.get_center().y
				if Props.existe("estante_ferro_larga"):
					# duas estantes de ferro costas com costas, de frente para os corredores
					for lado in [-1.0, 1.0]:
						Props.por(no, "estante_ferro_larga", Vector3(x + lado * 0.3, y0, z1), 90.0 * lado, 0.95)
					for b in 6:
						if _rng.randf() < 0.5:
							Props.por(no, ["lata", "lata_baixa", "pote"][_rng.randi() % 3], Vector3(x + _rng.randf_range(-0.25, 0.25), y0 + [0.07, 0.62, 1.15][_rng.randi() % 3], z1 - 0.75 + b * 0.3), _rng.randf() * 360.0, 1.0, 20.0, false)
					_container(no, Vector3(x + 0.5, y0 + 1.0, z1), "Prateleira", "prateleira", 0.2)
					continue
				B.box(no, Vector3(0.6, 1.7, 3.2), Vector3(x, y0 + 0.85, z1), _m("metal", Color(0.55, 0.55, 0.55), 0.5, 0.5))
				for q in 4:
					B.box(no, Vector3(0.65, 0.04, 3.2), Vector3(x, y0 + 0.2 + q * 0.45, z1), _m("metal", Color(0.4, 0.4, 0.4), 0.5, 0.5))
					for b in 5:
						if _rng.randf() < 0.45:
							B.box(no, Vector3(0.22, 0.25, 0.2), Vector3(x + _rng.randf_range(-0.15, 0.15), y0 + 0.35 + q * 0.45, z1 - 1.3 + b * 0.65), Texturas.material("tecido", Color.from_hsv(_rng.randf(), 0.6, 0.6), 0.7))
				_container(no, Vector3(x + 0.5, y0 + 1.0, z1), "Prateleira", "prateleira", 0.2)
			B.box(no, Vector3(2.0, 1.0, 0.7), Vector3(r2.end.x - 1.0, y0 + 0.5, r2.end.y - 0.5), mad)
			_container(no, Vector3(r2.end.x - 1.0, y0 + 1.0, r2.end.y - 1.1), "Caixa registradora", "gaveta", 0.1)
			if _rng.randf() < 0.4:
				Props.por(no, "dinheiro", Vector3(r2.end.x - 1.2, y0 + 1.0, r2.end.y - 0.5), _rng.randf() * 360.0, 1.0, 20.0, false)
		"deposito":
			for i in 5:
				var p2 := Vector2(_rng.randf_range(r2.position.x, r2.end.x), _rng.randf_range(r2.position.y, r2.end.y))
				if livre.call(p2, 0.6):
					B.box(no, Vector3(0.7, 0.6, 0.7), Vector3(p2.x, y0 + 0.3, p2.y), _m("papelao", Color(0.55, 0.42, 0.27)), Vector3(0, _rng.randf() * 90, 0))
			_container(no, Vector3(r2.get_center().x, y0 + 0.8, r2.get_center().y), "Caixas do depósito", "caixa", 0.4)
			var cd: Vector2 = cantos[0]
			if livre.call(cd + Vector2(0.6, 0), 0.8):
				Props.por(no, "estante_ferro", Vector3(cd.x + 0.6, y0, cd.y + 0.1), 0.0)
			if _rng.randf() < 0.5:
				Props.por(no, "lixo", Vector3(r2.end.x - 0.3, y0, r2.end.y - 0.3), _rng.randf() * 360.0)
		"cabana":
			var c6: Vector2 = cantos[0]
			B.box(no, Vector3(0.9, 0.35, 1.9), Vector3(c6.x + 0.45, y0 + 0.2, c6.y + 0.95), mad)
			B.box(no, Vector3(0.85, 0.12, 1.85), Vector3(c6.x + 0.45, y0 + 0.42, c6.y + 0.95), tecido)
			var c7: Vector2 = cantos[1]
			B.box(no, Vector3(1.0, 0.8, 0.5), Vector3(c7.x - 0.3, y0 + 0.4, c7.y + 0.1), mad)
			B.box(no, Vector3(0.9, 0.5, 0.3), Vector3(c7.x - 0.3, y0 + 1.4, c7.y), mad)
			_container(no, Vector3(c7.x - 0.3, y0 + 0.9, c7.y + 0.5), "Baú do caçador", "cacador", 0.3)
			B.cyl(no, 0.3, 1.0, Vector3(r2.end.x - 0.3, y0 + 0.5, r2.end.y - 0.3), _m("metal", Color(0.15, 0.15, 0.15), 0.6, 0.6), Vector3.ZERO, 10)
	# sujeira e entulho no chão (lugar abandonado)
	for i in int((1.0 - condicao) * 6.0):
		var pz := Vector2(_rng.randf_range(r2.position.x, r2.end.x), _rng.randf_range(r2.position.y, r2.end.y))
		if livre.call(pz, 0.2):
			var e2 := B.box(no, Vector3(_rng.randf_range(0.1, 0.4), 0.03, _rng.randf_range(0.1, 0.3)), Vector3(pz.x, y0 + 0.02, pz.y), _m("papelao", Color(0.5, 0.45, 0.38)))
			e2.rotation.y = _rng.randf() * 3.0

# ---------------------------------------------------------------- fachada (casas)
## Batente, degrau, marquise com mãos-francesas, número e luminária na porta da frente.
func _fachada_porta(no: Node3D, p: Vector3, rot: float) -> void:
	var f := Node3D.new()
	f.position = p
	f.rotation.y = rot
	no.add_child(f)
	var mold := _m("madeira_movel", _cor_detalhe)
	var conc := _m("concreto", Color(0.62, 0.6, 0.56))
	for sx in [-1.0, 1.0]:
		B.box(f, Vector3(0.1, 2.3, 0.12), Vector3(sx * 0.6, 1.15, 0.05), mold)
	B.box(f, Vector3(1.32, 0.12, 0.12), Vector3(0, 2.28, 0.05), mold)
	B.box(f, Vector3(1.6, 0.16, 0.55), Vector3(0, 0.02, 0.36), conc)        # degrau
	if _rng.randf() < 0.75:
		B.box(f, Vector3(1.9, 0.1, 0.9), Vector3(0, 2.62, 0.45), conc)      # marquise
		for sx in [-0.8, 0.8]:
			B.box(f, Vector3(0.06, 0.06, 0.62), Vector3(sx, 2.35, 0.3), mold, Vector3(-40, 0, 0))
	var placa := Label3D.new()
	placa.text = str(10 + _rng.randi() % 890)
	placa.font_size = 48
	placa.pixel_size = 0.004
	placa.modulate = Color(0.12, 0.12, 0.14)
	placa.position = Vector3(0.95, 1.85, 0.11)
	placa.double_sided = false
	B.box(f, Vector3(0.3, 0.18, 0.02), Vector3(0.95, 1.85, 0.1), _m("esmalte", Color(0.9, 0.88, 0.8)))
	f.add_child(placa)
	B.box(f, Vector3(0.14, 0.2, 0.12), Vector3(-0.95, 2.05, 0.14), B.mat(Color(0.2, 0.2, 0.2), 0.5, 0.6))

## Barrado de pintura, cantoneiras e um ou outro detalhe encostado na parede.
func _fachada(cor_ext: Color) -> void:
	var no := andar_nos[0]
	var hw := largura * 0.5 + ESP * 0.5 + 0.015
	var hd := profundidade * 0.5 + ESP * 0.5 + 0.015
	var barrado := _m("reboco", B.worn(cor_ext.darkened(0.35), condicao))
	var canto := _m("reboco", B.worn(cor_ext.lightened(0.2), condicao))
	B.box(no, Vector3(largura + 0.25, 0.55, 0.02), Vector3(0, 0.27, hd), barrado)
	B.box(no, Vector3(largura + 0.25, 0.55, 0.02), Vector3(0, 0.27, -hd), barrado)
	B.box(no, Vector3(0.02, 0.55, profundidade + 0.25), Vector3(hw, 0.27, 0), barrado)
	B.box(no, Vector3(0.02, 0.55, profundidade + 0.25), Vector3(-hw, 0.27, 0), barrado)
	var htot := H * andares
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.box(no, Vector3(0.26, htot, 0.26), Vector3(sx * (largura * 0.5), htot * 0.5, sz * (profundidade * 0.5)), canto)
	# fiação e relógio de luz
	B.box(no, Vector3(0.3, 0.4, 0.15), Vector3(-largura * 0.5 + 0.5, 1.5, hd + 0.08), _m("metal", Color(0.55, 0.55, 0.52), 0.5, 0.5))
	if _rng.randf() < 0.5:
		# ar-condicionado na lateral
		B.box(no, Vector3(0.3, 0.5, 0.8), Vector3(hw + 0.15, 2.2, profundidade * 0.15), _m("esmalte", Color(0.85, 0.85, 0.82)))
		for q in 4:
			B.box(no, Vector3(0.02, 0.4, 0.04), Vector3(hw + 0.31, 2.2, profundidade * 0.15 - 0.3 + q * 0.2), _m("metal", Color(0.3, 0.3, 0.3), 0.5, 0.5))
	# pichações de verdade (tags) só em pano de parede inteiro, do tamanho que cabe
	if _rng.randf() < 0.8 and not _panos_livres.is_empty():
		var panos := _panos_livres.duplicate()
		for q in mini(_rng.randi_range(1, 3), panos.size()):
			var pn: Dictionary = panos.pop_at(_rng.randi() % panos.size())
			var comp_p: float = (pn.a as Vector2).distance_to(pn.b)
			var larg := minf(_rng.randf_range(1.0, 2.0), comp_p - 0.3)
			if larg < 0.6:
				continue
			var t := _rng.randf_range(larg * 0.5 + 0.15, comp_p - larg * 0.5 - 0.15) / comp_p
			var c2: Vector2 = (pn.a as Vector2).lerp(pn.b, t)
			var nn: Vector3 = pn.n
			var base := c2 + Vector2(nn.x, nn.z) * (ESP * 0.5 + 0.02)
			Grafite.colar(no, Vector3(base.x, _rng.randf_range(1.05, 1.45), base.y), nn, larg, _rng)
