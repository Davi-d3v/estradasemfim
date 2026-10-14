class_name Assentamento
extends Node3D
## A parte viva de um assentamento: muro em segmentos (cada um com vida), portão,
## torres, holofotes e armadilhas. O estado fica em main.defesa.estado[id] e sobrevive
## a descarregar o chunk; este nó só desenha e responde a colisão e dano.
## Espaço local: o portão fica em +Z (de frente para a estrada de terra).

const R := 30.0          # raio do muro
const N := 20            # segmentos do muro (o 0 é o portão)
const H_TORRE := 3.4     # altura do piso das torres
const ANG_TORRES := [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]
const HP_MADEIRA := 100.0
const HP_CHAPAS := 260.0

var id := ""
var mundo: WorldGen
var defesa: Node
var est: Dictionary
var _segs: Array = []        # Node3D por segmento
var _estagio: Array = []     # 0 inteiro .. 3 caído (para só redesenhar quando muda)
var _torres: Array = []
var _luzes: Array = []
var _arm: Array = []
var _portao_aberto := true
var _mats := {}

func _ready() -> void:
	if mundo:
		mundo.muros.append(self)
	defesa = mundo.get_parent().get("defesa") if mundo else null
	if defesa:
		est = defesa.obter(id, self)
	if est.is_empty():
		return
	for i in N:
		var s := Node3D.new()
		s.set_meta("nao_mesclar", true)
		add_child(s)
		_segs.append(s)
		_estagio.append(-1)
	redesenhar()

func _exit_tree() -> void:
	if mundo:
		mundo.muros.erase(self)

# ------------------------------------------------------------ geometria
static func ang(i: float) -> float:
	return TAU * i / N

static func ponto(i: float, raio: float) -> Vector3:
	var a := ang(i)
	return Vector3(sin(a) * raio, 0, cos(a) * raio)

func local_de(g: Vector3) -> Vector3:
	return global_transform.affine_inverse() * g

func global_de(l: Vector3) -> Vector3:
	return global_transform * l

## Índice contínuo (0..N) do ângulo de um ponto local.
static func indice_f(l: Vector3) -> float:
	return fposmod(atan2(l.x, l.z) / (TAU / N), float(N))

static func indice_em(l: Vector3) -> int:
	return posmod(int(round(indice_f(l))), N)

func hp_max(i: int) -> float:
	var b: float = HP_CHAPAS if est.chapas else HP_MADEIRA
	if i == 0:
		b *= 1.6 if not est.portao else 2.6
		b += est.get("bonus_portao", 0.0)
	return b

func hp(i: int) -> float:
	return est.muro[i]

func fracao(i: int) -> float:
	return clampf(est.muro[i] / hp_max(i), 0.0, 1.0)

func muro_medio() -> float:
	var t := 0.0
	for i in N:
		t += fracao(i)
	return t / N

## Brecha (segmento caído) mais perto de i, até "alcance" segmentos de distância; -1 se não houver.
func brecha_perto(i: int, alcance: int) -> int:
	for k in alcance + 1:
		for s in ([0] if k == 0 else [k, -k]):
			var j := posmod(i + s, N)
			if est.muro[j] <= 0.0:
				return j
	return -1

func mais_danificado() -> int:
	var melhor := -1
	var pior := 0.85
	for i in N:
		var f := fracao(i)
		if f < pior and est.muro[i] > 0.0:
			pior = f
			melhor = i
	if melhor < 0:
		for i in N:
			if est.muro[i] <= 0.0:
				return i
	return melhor

func torre_pos(k: int) -> Vector3:
	var a: float = ANG_TORRES[k]
	var l := Vector3(sin(a), 0, cos(a)) * (R - 3.2)
	l.y = _y(l) + H_TORRE
	return global_de(l)

func _y(l: Vector3) -> float:
	var g := global_de(Vector3(l.x, 0, l.z))
	return mundo.altura(g.x, g.z) - global_position.y

# ------------------------------------------------------------ colisão e dano
## O movimento de a para b atravessa o muro? O jogador passa pelo portão; zumbis e recrutas não.
func colide(a: Vector3, b: Vector3, raio: float, jogador := false) -> bool:
	var lb := local_de(b)
	var rb := Vector2(lb.x, lb.z).length()
	if absf(rb - R) > raio + 1.2:
		return false
	var la := local_de(a)
	var i := indice_em(lb)
	for s in [-1, 0, 1]:
		var j := posmod(i + s, N)
		if est.muro[j] <= 0.0:
			continue
		if j == 0 and (jogador or (_portao_aberto and not defesa.em_onda(id))):
			continue
		var p0 := ponto(j - 0.5, R)
		var p1 := ponto(j + 0.5, R)
		var db := _dist_seg(Vector2(lb.x, lb.z), Vector2(p0.x, p0.z), Vector2(p1.x, p1.z))
		if db < raio + 0.22:
			var da := _dist_seg(Vector2(la.x, la.z), Vector2(p0.x, p0.z), Vector2(p1.x, p1.z))
			if da >= db - 0.001:
				return true
	return false

static func _dist_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func danificar(i: int, d: float) -> void:
	if est.muro[i] <= 0.0:
		return
	est.muro[i] = maxf(0.0, est.muro[i] - d)
	_atualizar_seg(i)
	if est.muro[i] <= 0.0 and defesa:
		defesa.muro_caiu(self, i)

func reparar(i: int, d: float) -> void:
	est.muro[i] = minf(hp_max(i), est.muro[i] + d)
	_atualizar_seg(i)

func reparar_tudo() -> void:
	for i in N:
		est.muro[i] = hp_max(i)
	redesenhar()

## Armadilha do setor em que o ponto local está: consome uma carga e devolve true se pegou.
func armadilha_em(l: Vector3) -> bool:
	var r := Vector2(l.x, l.z).length()
	if r < R + 2.4 or r > R + 4.6:
		return false
	var k := setor(l)
	if est.armadilhas[k] <= 0:
		return false
	est.armadilhas[k] -= 1
	if est.armadilhas[k] % 3 == 0:
		_desenhar_armadilhas()
	return true

static func setor(l: Vector3) -> int:
	return int(fposmod(atan2(l.x, l.z) + PI * 0.25, TAU) / (PI * 0.5)) % 4

func portao(aberto: bool) -> void:
	if aberto == _portao_aberto:
		return
	_portao_aberto = aberto
	_estagio[0] = -1
	_atualizar_seg(0)
	_desenhar_torres()

# ------------------------------------------------------------ desenho
func _m(nome: String, cor: Color, rough := 0.9, metal := 0.0) -> Material:
	var k := nome + cor.to_html()
	if not _mats.has(k):
		_mats[k] = Texturas.material(nome, cor, rough, metal)
	return _mats[k]

func redesenhar() -> void:
	for i in N:
		_estagio[i] = -1
		_atualizar_seg(i)
	_desenhar_torres()
	_desenhar_armadilhas()

func _estagio_de(i: int) -> int:
	var f := fracao(i)
	if est.muro[i] <= 0.0:
		return 3
	if f < 0.34:
		return 2
	if f < 0.67:
		return 1
	return 0

func _atualizar_seg(i: int) -> void:
	if _segs.is_empty():
		return
	var e := _estagio_de(i) + (10 if i == 0 and _portao_aberto else 0) + (20 if est.chapas else 0)
	if e == _estagio[i]:
		return
	_estagio[i] = e
	var s: Node3D = _segs[i]
	for c in s.get_children():
		s.remove_child(c)
		c.queue_free()
	var a := ang(i)
	var l := Vector3(sin(a), 0, cos(a)) * R * cos(PI / N)
	s.position = Vector3(l.x, 0, l.z)
	s.rotation.y = a
	var comp := 2.0 * R * sin(PI / N) + 0.15
	var r := RandomNumberGenerator.new()
	r.seed = hash([id, i, e])
	var estagio := _estagio_de(i)
	if i == 0:
		_desenhar_portao(s, comp, estagio, r)
	elif est.chapas:
		_desenhar_chapas(s, comp, estagio, r)
	else:
		_desenhar_palicada(s, comp, estagio, r)
	B.mesclar(s)

## Altura do chão (local do segmento) num x ao longo do segmento.
func _chao_seg(s: Node3D, x: float) -> float:
	var g := s.global_transform * Vector3(x, 0, 0) if s.is_inside_tree() else global_de(s.transform * Vector3(x, 0, 0))
	return mundo.altura(g.x, g.z) - global_position.y

func _desenhar_palicada(s: Node3D, comp: float, estagio: int, r: RandomNumberGenerator) -> void:
	var tronco := _m("casca", Color(0.36, 0.27, 0.18))
	var ponta := _m("tabuas", Color(0.5, 0.4, 0.28))
	var n := int(comp / 0.27)
	for k in n:
		var x := -comp * 0.5 + (k + 0.5) * comp / n
		var falta := (estagio == 1 and r.randf() < 0.18) or (estagio == 2 and r.randf() < 0.5)
		var y0 := _chao_seg(s, x) - 0.3
		if estagio == 3 or falta:
			if r.randf() < 0.7:
				var hq := r.randf_range(0.3, 0.9)
				B.cyl(s, 0.13, hq, Vector3(x, y0 + hq * 0.5, 0), tronco, Vector3(r.randf_range(-15, 15), 0, r.randf_range(-15, 15)), 6)
			continue
		var h := 3.0 + r.randf_range(-0.25, 0.25)
		var incl := Vector3(r.randf_range(-2, 2), 0, r.randf_range(-3, 3)) * (1.0 + estagio * 4.0)
		B.cyl(s, 0.13, h, Vector3(x, y0 + h * 0.5, 0), tronco, incl, 6)
		B.cyl(s, 0.13, 0.3, Vector3(x, y0 + h + 0.15, 0), ponta, incl, 6, 0.01)
	if estagio < 3:
		# travessas por dentro
		for yy in [0.9, 2.1]:
			B.box(s, Vector3(comp, 0.14, 0.1), Vector3(0, _chao_seg(s, 0.0) + yy, -0.2), ponta)
	else:
		for k in 4:
			B.cyl(s, 0.12, r.randf_range(1.5, 2.8), Vector3(r.randf_range(-comp * 0.4, comp * 0.4), _chao_seg(s, 0.0) + 0.1, r.randf_range(-1.5, 1.5)), tronco, Vector3(90, r.randf() * 360.0, 0), 6)

func _desenhar_chapas(s: Node3D, comp: float, estagio: int, r: RandomNumberGenerator) -> void:
	var poste := _m("casca", Color(0.34, 0.26, 0.18))
	var cores := [Color(0.48, 0.45, 0.4), Color(0.52, 0.3, 0.17), Color(0.34, 0.37, 0.35), Color(0.56, 0.5, 0.42)]
	var n := 4
	var larg := comp / n
	for k in n + 1:
		var x := -comp * 0.5 + k * larg
		if estagio < 3 or r.randf() < 0.5:
			var hp_ := 3.1 if estagio < 3 else r.randf_range(0.5, 1.4)
			B.box(s, Vector3(0.16, hp_, 0.16), Vector3(x, _chao_seg(s, x) + hp_ * 0.5 - 0.3, -0.12), poste)
	for k in n:
		var x := -comp * 0.5 + (k + 0.5) * larg
		var falta := (estagio == 1 and r.randf() < 0.15) or (estagio == 2 and r.randf() < 0.45) or estagio == 3
		var y0 := _chao_seg(s, x)
		var mt := _m("metal", B.worn(cores[r.randi() % cores.size()], r.randf_range(0.2, 0.6)), 0.55, 0.45)
		if falta:
			if r.randf() < 0.6:
				var ch := B.box(s, Vector3(larg, 0.05, 2.4), Vector3(x + r.randf_range(-0.5, 0.5), y0 + 0.1, r.randf_range(0.5, 2.0)), mt)
				ch.rotation.y = r.randf_range(-0.5, 0.5)
			continue
		var amass := estagio * 6.0
		B.box(s, Vector3(larg + 0.04, 2.9, 0.06), Vector3(x, y0 + 1.25, 0), mt, Vector3(r.randf_range(-1, 1) * amass, 0, r.randf_range(-1, 1) * amass * 0.5))
	if estagio < 3:
		B.box(s, Vector3(comp, 0.16, 0.12), Vector3(0, _chao_seg(s, 0.0) + 2.55, -0.18), poste)
		B.box(s, Vector3(comp, 0.16, 0.12), Vector3(0, _chao_seg(s, 0.0) + 0.6, -0.18), poste)

func _desenhar_portao(s: Node3D, comp: float, estagio: int, r: RandomNumberGenerator) -> void:
	var madeira := _m("tabuas", Color(0.42, 0.31, 0.2))
	var tronco := _m("casca", Color(0.34, 0.26, 0.17))
	var metal := _m("metal", B.worn(Color(0.42, 0.4, 0.36), 0.4), 0.5, 0.5)
	var y0 := _chao_seg(s, 0.0)
	var vao := 5.0
	# pilares e laterais do portão
	for sx in [-1.0, 1.0]:
		B.cyl(s, 0.22, 4.4, Vector3(sx * vao * 0.5, y0 + 1.9, 0), tronco, Vector3.ZERO, 8)
		var lado := (comp - vao) * 0.5
		for k in int(lado / 0.27):
			var x = sx * (vao * 0.5 + 0.15 + k * 0.27)
			B.cyl(s, 0.13, 3.0, Vector3(x, _chao_seg(s, x) + 1.2, 0), tronco, Vector3.ZERO, 6)
	# viga de cima com o nome e lampiões dos dois lados
	B.box(s, Vector3(vao + 0.8, 0.35, 0.3), Vector3(0, y0 + 4.0, 0), madeira)
	for sx in [-1.0, 1.0]:
		var lamp := Node3D.new()
		lamp.position = Vector3(sx * (vao * 0.5 + 0.1), y0 + 3.3, 0.35)
		s.add_child(lamp)
		B.box(lamp, Vector3(0.22, 0.3, 0.22), Vector3.ZERO, B.emissive(Color(1.0, 0.7, 0.35), 2.5))
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.68, 0.38)
		ol.light_energy = 1.6
		ol.omni_range = 11.0
		ol.position = Vector3(0, 0, 0.3)
		lamp.add_child(ol)
		_lanternas.append(ol)
		ol.visible = defesa.main.eh_noite() if defesa else false
	var lbl := Label3D.new()
	lbl.text = String(est.nome).to_upper()
	lbl.font_size = 64
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0.06, 0.05, 0.04)
	lbl.modulate = Color(0.92, 0.88, 0.76)
	lbl.pixel_size = 0.006
	lbl.position = Vector3(0, y0 + 4.0, 0.17)
	lbl.shaded = true
	s.add_child(lbl)
	if estagio == 3:
		for k in 3:
			var tb := B.box(s, Vector3(2.4, 0.08, 3.0), Vector3(r.randf_range(-1.5, 1.5), y0 + 0.08 + k * 0.08, r.randf_range(-2.5, -0.5)), madeira)
			tb.rotation.y = r.randf_range(-0.6, 0.6)
		return
	# folhas do portão: fechadas no ataque, abertas para dentro no resto do tempo
	for sx in [-1.0, 1.0]:
		var dob := Node3D.new()
		dob.position = Vector3(sx * vao * 0.5, y0, 0)
		dob.rotation.y = (sx * -1.7) if _portao_aberto else 0.0
		s.add_child(dob)
		var w := vao * 0.5 - 0.1
		var cx = -sx * w * 0.5
		var amass := estagio * 5.0
		B.box(dob, Vector3(w, 2.8, 0.12), Vector3(cx, 1.5, 0), madeira, Vector3(0, 0, r.randf_range(-1, 1) * amass))
		for yy in [0.6, 1.5, 2.4]:
			B.box(dob, Vector3(w, 0.16, 0.08), Vector3(cx, yy, -0.1), madeira)
		B.box(dob, Vector3(w * 1.1, 0.14, 0.08), Vector3(cx, 1.5, -0.12), madeira, Vector3(0, 0, sx * 38.0))
		if est.portao:
			for yy in [0.9, 2.1]:
				B.box(dob, Vector3(w, 0.5, 0.04), Vector3(cx, yy, 0.09), metal)

func _desenhar_torres() -> void:
	for t in _torres:
		if is_instance_valid(t):
			t.queue_free()
	_torres.clear()
	_luzes.clear()
	var madeira := _m("tabuas", Color(0.44, 0.33, 0.21))
	var tronco := _m("casca", Color(0.34, 0.26, 0.17))
	var telha := _m("metal", B.worn(Color(0.42, 0.4, 0.37), 0.4), 0.6, 0.4)
	for k in 4:
		if not est.torres[k]:
			continue
		var a: float = ANG_TORRES[k]
		var l := Vector3(sin(a), 0, cos(a)) * (R - 3.2)
		var t := Node3D.new()
		t.position = Vector3(l.x, _y(l), l.z)
		t.rotation.y = a
		t.set_meta("nao_mesclar", true)
		add_child(t)
		_torres.append(t)
		var h := H_TORRE
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				B.cyl(t, 0.13, h + 1.6, Vector3(sx * 1.1, (h + 1.6) * 0.5 - 0.2, sz * 1.1), tronco, Vector3.ZERO, 6)
		B.box(t, Vector3(2.6, 0.12, 2.6), Vector3(0, h - 0.06, 0), madeira)
		for sz in [-1.0, 1.0]:
			B.box(t, Vector3(2.6, 0.9, 0.06), Vector3(0, h + 0.45, sz * 1.27), madeira)
			B.box(t, Vector3(0.06, 0.9, 2.6), Vector3(sz * 1.27, h + 0.45, 0), madeira)
		# escada (lado de dentro)
		for k2 in 9:
			B.box(t, Vector3(0.6, 0.06, 0.08), Vector3(0, 0.3 + k2 * 0.38, -1.45), madeira)
		for sx in [-0.32, 0.32]:
			B.box(t, Vector3(0.07, h + 0.4, 0.07), Vector3(sx, (h + 0.4) * 0.5, -1.45), madeira, Vector3(-6, 0, 0))
		# X de travamento
		B.box(t, Vector3(0.08, 3.6, 0.08), Vector3(0, h * 0.45, 1.1), madeira, Vector3(0, 0, 38))
		B.box(t, Vector3(0.08, 3.6, 0.08), Vector3(0, h * 0.45, 1.1), madeira, Vector3(0, 0, -38))
		B.box(t, Vector3(3.0, 0.08, 3.0), Vector3(0, h + 1.65, 0), telha, Vector3(6, 0, 0))
		B.mesclar(t)
		if est.holofotes[k]:
			var caixa := Node3D.new()
			caixa.position = Vector3(0, h + 1.05, 1.15)
			t.add_child(caixa)
			B.box(caixa, Vector3(0.45, 0.35, 0.35), Vector3.ZERO, B.mat(Color(0.15, 0.15, 0.14), 0.5, 0.5))
			var lente := B.box(caixa, Vector3(0.36, 0.26, 0.02), Vector3(0, 0, 0.18), B.emissive(Color(1.0, 0.95, 0.8), 3.0))
			var sp := SpotLight3D.new()
			sp.light_color = Color(1.0, 0.95, 0.82)
			sp.light_energy = 9.0
			sp.spot_range = 38.0
			sp.spot_angle = 30.0
			sp.spot_attenuation = 0.7
			sp.rotation.y = PI     # a luz sai pela lente (+Z da caixa)
			caixa.add_child(sp)
			caixa.rotation.x = 0.28
			caixa.set_meta("fase", float(k) * 1.7)
			_luzes.append([sp, lente, caixa])
	_vigias_parados()
	ligar_holofotes(defesa.main.eh_noite() if defesa else false)

## Fora do ataque, um vigia do assentamento fica em cada torre (só enfeite).
func _vigias_parados() -> void:
	if est.fase == "caido" or (defesa and defesa.em_onda(id)):
		return
	var n: int = est.vigias
	for t in _torres:
		if n <= 0:
			break
		n -= 1
		var h := Humanoid.new()
		h.semente = hash([id, t.get_index()])
		h.arma = "rifle"
		h.com_bone = true
		h.visual = "soldado"
		h.anim_parado = "Idle_LookAround"
		h.camisa = Color(0.3, 0.33, 0.25)
		h.position = Vector3(0.3, H_TORRE, 0.4)
		t.add_child(h)


func ligar_holofotes(lig: bool) -> void:
	for par in _luzes:
		if is_instance_valid(par[0]):
			par[0].visible = lig
			par[1].visible = lig
	for l in _lanternas:
		if is_instance_valid(l):
			l.visible = lig

var _t_varre := 0.0
var _lanternas: Array = []

## Os holofotes varrem o setor de cada torre devagar.
func _process(dt: float) -> void:
	_t_varre += dt
	for par in _luzes:
		var cx: Node3D = par[2]
		if is_instance_valid(cx) and par[0].visible:
			cx.rotation.y = sin(_t_varre * 0.35 + float(cx.get_meta("fase", 0.0))) * 0.65

func _desenhar_armadilhas() -> void:
	for a in _arm:
		if is_instance_valid(a):
			a.queue_free()
	_arm.clear()
	var estaca := _m("casca", Color(0.4, 0.3, 0.2))
	for k in 4:
		var cargas: int = est.armadilhas[k]
		if cargas <= 0:
			continue
		var no := Node3D.new()
		no.set_meta("nao_mesclar", true)
		add_child(no)
		_arm.append(no)
		var r := RandomNumberGenerator.new()
		r.seed = hash([id, "arm", k])
		var n := clampi(cargas * 2, 4, 26)
		for q in n:
			var a := k * PI * 0.5 - PI * 0.25 + (q + 0.5) / n * PI * 0.5
			if absf(wrapf(a, -PI, PI)) < 0.12:
				continue   # deixa o caminho do portão livre
			var rr := R + 3.5 + r.randf_range(-0.6, 0.6)
			var l := Vector3(sin(a) * rr, 0, cos(a) * rr)
			var y := _y(l)
			# cavalete de estacas apontadas para fora
			var c := Node3D.new()
			c.position = Vector3(l.x, y, l.z)
			c.rotation.y = a
			no.add_child(c)
			for s in [-1.0, 1.0]:
				B.cyl(c, 0.06, 2.0, Vector3(s * 0.35, 0.55, 0.2), estaca, Vector3(55, 0, s * 25), 5, 0.01)
			B.cyl(c, 0.07, 1.2, Vector3(0, 0.3, 0), estaca, Vector3(0, 0, 90), 5)
		B.mesclar(no)
	# fossos e arame farpado
	var terra := _m("terra_fosso", Color(0.33, 0.24, 0.15))
	var fundo := _m("fundo_fosso", Color(0.05, 0.035, 0.025))
	var arame := _m("arame_farpado", Color(0.35, 0.35, 0.36), 0.5, 0.8)
	var mourao := _m("casca", Color(0.4, 0.3, 0.2))
	var tabua := _m("tabua_ponte", Color(0.42, 0.31, 0.19))
	for k in 4:
		var tem_fosso: bool = est.get("fossos", [false, false, false, false])[k]
		var cargas_arame: int = est.get("arames", [0, 0, 0, 0])[k]
		if not tem_fosso and cargas_arame <= 0:
			continue
		var no2 := Node3D.new()
		no2.set_meta("nao_mesclar", true)
		add_child(no2)
		_arm.append(no2)
		var n2 := 22
		var rf := R + 6.7
		for q in n2:
			var a := k * PI * 0.5 - PI * 0.25 + (q + 0.5) / n2 * PI * 0.5
			var no_portao := absf(wrapf(a, -PI, PI)) < 0.09
			if tem_fosso:
				var lf := Vector3(sin(a) * rf, 0, cos(a) * rf)
				var c := Node3D.new()
				c.position = Vector3(lf.x, _y(lf), lf.z)
				c.rotation.y = a
				no2.add_child(c)
				if no_portao:
					# passagem de tábuas por cima do fosso, no caminho do portão
					for t in 5:
						B.box(c, Vector3(2.5, 0.08, 0.32), Vector3(0, 0.05, -0.8 + t * 0.4), tabua)
				else:
					B.box(c, Vector3(2.5, 0.04, 2.2), Vector3(0, -0.01, 0), fundo)
					for s2 in [-1.0, 1.0]:
						B.sphere(c, 0.7, Vector3(0, 0.0, s2 * 1.5), terra, Vector3(2.0, 0.45, 0.75), 8)
					# estacas no fundo
					for t in 3:
						B.cyl(c, 0.04, 0.6, Vector3(-0.8 + t * 0.8, 0.15, 0.0), mourao, Vector3(0, 0, (t - 1) * 15.0), 4, 0.005)
			if cargas_arame > 0 and q % 2 == 0 and absf(wrapf(a, -PI, PI)) >= 0.12:
				var ra := R + 1.4
				var la := Vector3(sin(a) * ra, 0, cos(a) * ra)
				var c2 := Node3D.new()
				c2.position = Vector3(la.x, _y(la), la.z)
				c2.rotation.y = a
				no2.add_child(c2)
				B.cyl(c2, 0.05, 1.1, Vector3(-1.1, 0.55, 0), mourao, Vector3.ZERO, 5)
				for t in 5:
					if cargas_arame < (t + 1) * 6:
						break
					B.cyl(c2, 0.38, 0.02, Vector3(-0.6 + t * 0.4, 0.42, 0), arame, Vector3(0, 0, 90), 10)
		B.mesclar(no2)
