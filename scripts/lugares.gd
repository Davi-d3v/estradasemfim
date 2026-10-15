class_name Lugares
## Monta as cenas dos lugares no fim das estradas de terra: vila, fazenda e ferro-velho.
## Cada lugar registra no mundo o que dá para vasculhar e quem mora lá.

const NOMES_PESSOAS := ["Dona Cida", "Seu Jorge", "Tião", "Marta", "Joana", "Beto", "Neide", "Rafa", "Carlinhos",
	"Lurdes", "Zé Preto", "Ana", "Pedrão", "Sônia", "Dinho", "Irene"]
const FUNCOES := {
	"vendedor": ["Troco o que precisar. Diesel e remédio valem ouro aqui.", "Comida eu tenho. Sabe consertar gerador?"],
	"vigia": ["A horda passou perto semana passada. Fica de olho na estrada.", "De noite ninguém entra. Nem você."],
	"mecanico": ["Esse seu trailer já viu dias melhores, hein.", "Se achar um eixo inteiro, guarda. Vale muito."],
	"agricultor": ["A terra ainda dá. Falta é gente pra plantar.", "Chuva boa este mês. A horta agradece."],
	"medico": ["Mordida? Não esconde. Infecção mata mais que zumbi.", "Remédio está acabando. Hospital da cidade, talvez."],
	"batedor": ["Conheço cada trilha daqui até a serra.", "Saio de madrugada e volto antes do almoço. Sempre volto."],
	"lider": ["Aqui todo mundo trabalha e todo mundo come.", "A horda vem. Sempre vem."],
	"morador": ["Dizem que na serra tem um assentamento grande.", "Meu filho foi pro litoral e nunca voltou.", "Fica pra janta, se quiser."],
}

static func construir(n: Node3D, f: Dictionary, m: WorldGen) -> Node3D:
	var j: Dictionary = f.juncao
	var raiz := Node3D.new()
	raiz.position = f.c
	# frente do lugar virada para o fim da estrada de terra
	var est: Dictionary = {}
	for ff in m._features(j.regiao):
		if ff.tipo == "estrada" and ff.id == f.id:
			est = ff
	var alvo: Vector3 = est.pts[est.pts.size() - 1] if not est.is_empty() else f.c + Vector3(0, 0, -10)
	var dir := Vector3(alvo.x - f.c.x, 0, alvo.z - f.c.z).normalized()
	raiz.rotation.y = atan2(dir.x, dir.z)
	n.add_child(raiz)
	var r := RandomNumberGenerator.new()
	r.seed = j.semente
	match j.tipo:
		"vila":
			_vila(raiz, f, r, m)
		"fazenda":
			_fazenda(raiz, f, r, m)
		"ferro_velho":
			_ferro_velho(raiz, f, r, m)
		"cabana":
			_cabana(raiz, f, r, m)
		"acampamento":
			_acampamento(raiz, f, r, m)
		"torre":
			_torre(raiz, f, r, m)
		"carro_mata":
			_carro_mata(raiz, f, r, m)
		"serraria":
			_serraria(raiz, f, r, m)
		"assentamento":
			_assentamento(raiz, f, r, m)
		"base_militar":
			Exploracao.base_militar(raiz, f, r, m)
		"presidio":
			Exploracao.presidio(raiz, f, r, m)
		"shopping":
			Exploracao.shopping(raiz, f, r, m)
	return raiz

## Porão com alçapão (fazendas, cabanas).
static func _porao(p: Node3D, pos: Vector3, m: WorldGen, chave: String) -> void:
	var s := Subsolo.new()
	s.tipo = "porao"
	s.chave = chave
	s.mundo = m
	s.position = Vector3(pos.x, _altura_local(p, m, pos), pos.z)
	s.set_meta("nao_mesclar", true)
	p.add_child(s)
	m.subsolos.append(s)

# ------------------------------------------------------------ utilidades
static func _altura_local(raiz: Node3D, m: WorldGen, local: Vector3) -> float:
	var g := raiz.transform * local
	return m.altura(g.x, g.z) - raiz.position.y

static func _casa(p: Node3D, pos: Vector3, rot_y: float, larg: float, prof: float, cor: Color, r: RandomNumberGenerator, telhado := Color(0.45, 0.2, 0.14)) -> Node3D:
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = rot_y
	p.add_child(c)
	var h := 2.7
	var parede := B.mat(B.worn(cor, r.randf_range(0.35, 0.7)), 0.9)
	B.box(c, Vector3(larg, h, prof), Vector3(0, h * 0.5, 0), parede)
	var tri := PackedVector2Array([Vector2(-prof * 0.5 - 0.3, h), Vector2(prof * 0.5 + 0.3, h), Vector2(0, h + 1.3)])
	B.extruded(c, tri, larg + 0.5, Vector3.ZERO, B.mat(B.worn(telhado, 0.5), 0.85))
	var escuro := B.mat(Color(0.08, 0.07, 0.06), 0.9, 0.0, "vao_escuro")
	B.box(c, Vector3(0.9, 1.9, 0.05), Vector3(0, 0.95, prof * 0.5 + 0.01), B.mat(Color(0.3, 0.2, 0.12), 0.8))
	for x in [-larg * 0.3, larg * 0.3]:
		var tab := r.randf() < 0.4
		B.box(c, Vector3(0.8, 0.8, 0.05), Vector3(x, 1.5, prof * 0.5 + 0.01), B.mat(Color(0.45, 0.32, 0.2), 0.9) if tab else escuro)
		if tab:
			for k in 3:
				B.box(c, Vector3(0.95, 0.12, 0.04), Vector3(x, 1.25 + k * 0.25, prof * 0.5 + 0.05), B.mat(Color(0.4, 0.28, 0.17), 0.9), Vector3(0, 0, r.randf_range(-8, 8)))
	return c

static func _pessoa(p: Node3D, pos: Vector3, rot_y: float, funcao: String, r: RandomNumberGenerator, m: WorldGen, chave: String) -> Humanoid:
	var h := Humanoid.new()
	h.semente = r.randi()
	h.pele = [Color(0.72, 0.52, 0.4), Color(0.55, 0.38, 0.27), Color(0.38, 0.26, 0.18), Color(0.8, 0.62, 0.5)][r.randi() % 4]
	h.camisa = Color.from_hsv(r.randf(), r.randf_range(0.2, 0.55), r.randf_range(0.25, 0.55))
	h.calca = Color.from_hsv(r.randf_range(0.55, 0.65), r.randf_range(0.2, 0.4), r.randf_range(0.15, 0.35))
	h.com_bone = r.randf() < 0.4
	h.arma = "facao" if funcao == "vigia" else ""
	h.feminino = r.randf() < 0.42
	h.visual = {"vendedor": "civil", "vigia": "soldado", "mecanico": "trabalhador", "agricultor": "trabalhador",
		"medico": "medico", "batedor": "civil", "lider": "idoso", "morador": "civil"}.get(funcao, "civil")
	if funcao == "morador" and r.randf() < 0.3:
		h.visual = ["idoso", "cozinheiro", "cowboy"][r.randi() % 3]
	h.anim_parado = {"vendedor": "Idle_Talking", "vigia": "Idle_LookAround", "mecanico": "Idle_Tired", "medico": "Idle_FoldArms",
		"lider": "Idle_FoldArms", "agricultor": "Idle"}.get(funcao, ["Idle", "Idle_Talking", "Idle_LookAround", "Idle_TalkingPhone"][r.randi() % 4])
	h.sujeira = r.randf_range(0.0, 0.35)
	h.position = pos
	h.rotation.y = rot_y
	p.add_child(h)
	var nome: String = NOMES_PESSOAS[r.randi() % NOMES_PESSOAS.size()]
	var falas: Array = FUNCOES[funcao]
	h.set_meta("nome", nome)
	h.set_meta("funcao", funcao)
	h.set_meta("fala", falas[r.randi() % falas.size()])
	h.set_meta("chave", chave)
	if m.recrutados.has(chave):
		h.visible = false
		h.queue_free()
		return h
	m.npcs.append(h)
	return h

static func _vasculhavel(p: Node3D, pos: Vector3, nome: String, tabela: String, horas: float, m: WorldGen, chave: String) -> void:
	var v := Node3D.new()
	v.position = pos
	p.add_child(v)
	v.set_meta("nome", nome)
	v.set_meta("tabela", tabela)
	v.set_meta("horas", horas)
	v.set_meta("chave", chave)
	m.vasculhaveis.append(v)

static func _placa(p: Node3D, pos: Vector3, rot_y: float, texto: String, cor := Color(0.82, 0.8, 0.72)) -> void:
	var lbl := Label3D.new()
	lbl.text = texto
	lbl.font_size = 110
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0.05, 0.04, 0.03)
	lbl.modulate = cor
	lbl.pixel_size = 0.006
	lbl.position = pos
	lbl.rotation.y = rot_y
	lbl.shaded = true
	lbl.double_sided = false
	p.add_child(lbl)

static func _muro(p: Node3D, raio: float, abertura: float, r: RandomNumberGenerator, m: WorldGen, chapas: bool) -> void:
	var n := int(TAU * raio / 3.4)
	var madeira := B.mat(Color(0.3, 0.22, 0.15), 0.95, 0.0, "poste_madeira")
	for i in n:
		var a := TAU * (i + 0.5) / n
		if absf(wrapf(a, -PI, PI)) < abertura:
			continue
		var pos := Vector3(sin(a) * raio, 0, cos(a) * raio)
		var y := _altura_local(p, m, pos)
		if chapas:
			var cor = [Color(0.45, 0.42, 0.38), Color(0.5, 0.28, 0.16), Color(0.32, 0.35, 0.33), Color(0.55, 0.5, 0.42)][r.randi() % 4]
			var ch := B.box(p, Vector3(3.5, 2.5 + r.randf_range(-0.2, 0.3), 0.08), pos + Vector3(0, y + 1.25, 0), B.mat(B.worn(cor, r.randf_range(0.2, 0.6)), 0.6, 0.5))
			ch.rotation.y = a
			ch.rotation.z = r.randf_range(-0.03, 0.03)
		else:
			for k in 2:
				var tab := B.box(p, Vector3(3.4, 0.12, 0.06), pos + Vector3(0, y + 0.45 + k * 0.45, 0), madeira)
				tab.rotation.y = a
		B.box(p, Vector3(0.14, 2.8 if chapas else 1.3, 0.14), Vector3(sin(a - PI / n) * raio, y + (1.4 if chapas else 0.65), cos(a - PI / n) * raio), madeira)

# ------------------------------------------------------------ vila
static func _poste_luz(p: Node3D, pos: Vector3, m: WorldGen) -> void:
	var y := _altura_local(p, m, pos)
	var metal := B.mat(Color(0.2, 0.2, 0.2), 0.5, 0.6, "poste_luz")
	B.cyl(p, 0.06, 3.6, pos + Vector3(0, y + 1.8, 0), metal, Vector3.ZERO, 6)
	B.box(p, Vector3(0.6, 0.05, 0.05), pos + Vector3(0.25, y + 3.55, 0), metal)
	B.sphere(p, 0.12, pos + Vector3(0.5, y + 3.45, 0), B.emissive(Color(1.0, 0.75, 0.4), 2.5))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.4)
	l.light_energy = 0.9
	l.omni_range = 8.0
	l.position = pos + Vector3(0.5, y + 3.2, 0)
	l.set_meta("nao_mesclar", true)
	p.add_child(l)

static func _caixas(p: Node3D, pos: Vector3, r: RandomNumberGenerator, n: int) -> void:
	var cores := [Color(0.5, 0.38, 0.22), Color(0.42, 0.32, 0.2), Color(0.25, 0.32, 0.2)]
	for k in n:
		var c := B.box(p, Vector3(0.6, 0.5, 0.6), pos + Vector3((k % 3) * 0.65, 0.25 + (k / 3) * 0.5, r.randf_range(-0.1, 0.1)), B.mat(cores[k % 3], 0.9))
		c.rotation.y = r.randf_range(-0.3, 0.3)

static func _barril(p: Node3D, pos: Vector3, cor: Color) -> void:
	B.cyl(p, 0.3, 0.9, pos + Vector3(0, 0.45, 0), B.mat(B.worn(cor, 0.4), 0.6, 0.4), Vector3.ZERO, 12)
	for y in [0.15, 0.75]:
		B.cyl(p, 0.31, 0.04, pos + Vector3(0, y, 0), B.mat(Color(0.15, 0.15, 0.15), 0.6, 0.6), Vector3.ZERO, 12)

static func _varal(p: Node3D, a: Vector3, b: Vector3, r: RandomNumberGenerator) -> void:
	var madeira := B.mat(Color(0.32, 0.23, 0.15), 0.9)
	for q in [a, b]:
		B.box(p, Vector3(0.08, 2.0, 0.08), q + Vector3(0, 1.0, 0), madeira)
	var meio := (a + b) * 0.5 + Vector3(0, 1.9, 0)
	var fio := B.box(p, Vector3(0.01, 0.01, a.distance_to(b)), meio, B.mat(Color(0.8, 0.8, 0.75), 0.9))
	fio.look_at_from_position(meio, b + Vector3(0, 1.9, 0), Vector3.UP)
	for k in 5:
		var t := (k + 1) / 6.0
		var q := a.lerp(b, t) + Vector3(0, 1.55, 0)
		var roupa := B.box(p, Vector3(0.45, 0.6, 0.02), q, B.mat(Color.from_hsv(r.randf(), 0.5, 0.6), 0.95))
		roupa.look_at_from_position(q, q + (b - a).cross(Vector3.UP), Vector3.UP)

static func _barraca(p: Node3D, pos: Vector3, rot: float, cor_lona: Color, mercadoria: Array, r: RandomNumberGenerator, comida := false) -> Node3D:
	var b := Node3D.new()
	b.position = pos
	b.rotation.y = rot
	p.add_child(b)
	var madeira := B.mat(Color(0.32, 0.23, 0.15), 0.9)
	for dx in [-1.4, 1.4]:
		for dz in [-0.9, 0.9]:
			B.box(b, Vector3(0.1, 2.2, 0.1), Vector3(dx, 1.1, dz), madeira)
	var lona := B.box(b, Vector3(3.3, 0.05, 2.4), Vector3(0, 2.25, 0), B.mat(cor_lona, 0.9))
	lona.rotation.x = 0.12
	B.box(b, Vector3(2.8, 0.9, 0.7), Vector3(0, 0.45, 0.6), madeira)
	for k in 5:
		B.box(b, Vector3(0.45, 0.3, 0.4), Vector3(-1.0 + k * 0.5, 1.05, 0.6), B.mat(mercadoria[k % mercadoria.size()], 0.8))
	return b

static func _vila(p: Node3D, f: Dictionary, r: RandomNumberGenerator, m: WorldGen) -> void:
	var raio: float = f.raio
	var j: Dictionary = f.juncao
	_muro(p, raio, 0.16, r, m, true)
	var madeira := B.mat(Color(0.32, 0.23, 0.15), 0.9)
	# portão e duas torres de vigia
	for s in [-1.0, 1.0]:
		var portao := B.box(p, Vector3(3.6, 2.6, 0.1), Vector3(s * 5.5, 1.3, raio + 1.2), B.mat(B.worn(Color(0.4, 0.38, 0.35), 0.4), 0.6, 0.5))
		portao.rotation.y = s * 1.1
	for tx in [-9.0, 9.0]:
		for dx in [-1.0, 1.0]:
			for dz in [-1.0, 1.0]:
				B.box(p, Vector3(0.2, 5.0, 0.2), Vector3(tx + dx * 1.1, 2.5, raio - 1.5 + dz * 1.1), madeira)
		B.box(p, Vector3(2.8, 0.15, 2.8), Vector3(tx, 4.6, raio - 1.5), madeira)
		B.box(p, Vector3(2.8, 0.9, 0.08), Vector3(tx, 5.1, raio - 0.1), madeira)
		var telha := B.box(p, Vector3(3.2, 0.08, 3.2), Vector3(tx, 6.6, raio - 1.5), B.mat(Color(0.4, 0.38, 0.35), 0.6, 0.5))
		telha.rotation.z = 0.08
		for dx in [-1.3, 1.3]:
			B.box(p, Vector3(0.12, 1.8, 0.12), Vector3(tx + dx, 5.6, raio - 1.5), madeira)
	_placa(p, Vector3(0, 3.6, raio + 0.3), PI, j.nome.to_upper())
	_placa(p, Vector3(0, 3.6, raio + 0.4), 0.0, j.nome.to_upper())
	# rua principal de terra e praça
	var chao := B.mat(Color(0.36, 0.29, 0.21), 1.0, 0.0, "rua_vila")
	# rua principal de paralelepípedo com calçadas; transversal de terra batida
	VilaExtra.rua(p, Vector3(0, 0, raio + 2.0), Vector3(0, 0, -raio + 19.0), 5.0, r)
	VilaExtra.rua(p, Vector3(-raio * 0.7, 0, -6.0), Vector3(-3.4, 0, -6.0), 4.0, r, true)
	VilaExtra.rua(p, Vector3(3.4, 0, -6.0), Vector3(raio * 0.7, 0, -6.0), 4.0, r, true)
	B.cyl(p, 8.0, 0.07, Vector3(0, 0.04, 4.0), Texturas.material("pedra", Color(0.38, 0.36, 0.32), 0.95), Vector3.ZERO, 28)
	# casas em duas fileiras ao longo das ruas
	var cores := [Color(0.75, 0.68, 0.55), Color(0.6, 0.66, 0.6), Color(0.78, 0.6, 0.45), Color(0.65, 0.6, 0.7), Color(0.8, 0.76, 0.66), Color(0.7, 0.5, 0.42)]
	var lotes: Array = []
	for s in [-1.0, 1.0]:
		for k in 4:
			lotes.append([Vector3(s * 10.0, 0, raio - 12.0 - k * 9.0), -s * PI * 0.5])
		for k in 3:
			lotes.append([Vector3(s * (15.0 + k * 9.5), 0, -15.0), 0.0])
			lotes.append([Vector3(s * (15.0 + k * 9.5), 0, 3.0), PI])
	var idx := 0
	for lt in lotes:
		var pos: Vector3 = lt[0]
		if pos.length() > raio - 6.0:
			continue
		var casa := _casa_viva(p, pos, lt[1], r.randf_range(6.4, 7.2), r.randf_range(6.0, 6.8), r, m, "%s:casa%d" % [j.id, idx], r.randf_range(0.65, 0.9), false)
		# quintal: horta, barril ou caixas atrás
		var atras: Vector3 = casa.transform * Vector3(0, 0, -4.8)
		match idx % 3:
			0:
				for q in 3:
					B.box(p, Vector3(2.4, 0.2, 0.5), atras + Vector3(0, 0.1, q * 0.7 - 0.7), B.mat(Color(0.22, 0.32, 0.12), 0.9, 0.0, "canteiro"))
			1:
				_barril(p, atras + Vector3(0.8, 0, 0), Color(0.2, 0.35, 0.55))
				_barril(p, atras + Vector3(-0.2, 0, 0.3), Color(0.55, 0.15, 0.1))
			2:
				_caixas(p, atras + Vector3(-0.8, 0, 0), r, 4)
		idx += 1
	# igreja com torre do sino, cemitério ao lado (fundo da vila)
	var ig := Node3D.new()
	ig.position = Vector3(0, _altura_local(p, m, Vector3(0, 0, -raio + 11.0)), -raio + 11.0)
	p.add_child(ig)
	VilaExtra.igreja(ig, r, m)
	_vasculhavel(p, Vector3(0, 1.0, -raio + 11.0), "Sacristia da igreja", "casa", 1.0, m, j.id + ":igreja")
	# praça: poço, fogueira, bancos
	var concreto := B.mat(Color(0.5, 0.48, 0.45), 0.95)
	B.cyl(p, 0.9, 0.8, Vector3(0, 0.4, 4.0), concreto, Vector3.ZERO, 14)
	B.box(p, Vector3(2.2, 0.1, 0.1), Vector3(0, 2.0, 4.0), madeira)
	for s in [-1.0, 1.0]:
		B.box(p, Vector3(0.1, 1.7, 0.1), Vector3(s * 1.0, 1.1, 4.0), madeira)
	_vasculhavel(p, Vector3(0, 1.0, 4.0), "Poço da vila", "poco", 0.25, m, j.id + ":poco")
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var bc := B.box(p, Vector3(1.8, 0.1, 0.45), Vector3(sin(a) * 5.5, 0.45, 4.0 + cos(a) * 5.5), madeira)
		bc.rotation.y = a
	B.cyl(p, 0.35, 0.9, Vector3(4.0, 0.45, 9.0), B.mat(Color(0.25, 0.2, 0.15), 0.7, 0.6), Vector3.ZERO, 12)
	B.sphere(p, 0.3, Vector3(4.0, 1.0, 9.0), B.emissive(Color(1.0, 0.5, 0.15), 3.0))
	var fogo := OmniLight3D.new()
	fogo.light_color = Color(1.0, 0.55, 0.25)
	fogo.light_energy = 1.6
	fogo.omni_range = 9.0
	fogo.position = Vector3(4.0, 1.6, 9.0)
	fogo.set_meta("nao_mesclar", true)
	p.add_child(fogo)
	# mercado: três barracas
	var comida := [Color(0.85, 0.5, 0.12), Color(0.3, 0.5, 0.2), Color(0.6, 0.15, 0.1)]
	var pecas := [Color(0.35, 0.35, 0.38), Color(0.5, 0.42, 0.3), Color(0.2, 0.2, 0.2)]
	var remed := [Color(0.9, 0.9, 0.88), Color(0.8, 0.15, 0.12), Color(0.3, 0.55, 0.75)]
	_barraca(p, Vector3(-7.0, 0, -2.5), 0.0, Color(0.2, 0.35, 0.45), comida, r, true)
	_barraca(p, Vector3(-11.5, 0, -2.5), 0.0, Color(0.5, 0.35, 0.15), pecas, r)
	_barraca(p, Vector3(7.0, 0, -2.5), 0.0, Color(0.45, 0.15, 0.15), remed, r)
	_pessoa(p, Vector3(-7.0, 0, -3.0), 0.0, "vendedor", r, m, j.id + ":vendedor")
	_pessoa(p, Vector3(-11.5, 0, -3.0), 0.0, "mecanico", r, m, j.id + ":vend_pecas")
	_pessoa(p, Vector3(7.0, 0, -3.0), 0.0, "medico", r, m, j.id + ":vend_remedio")
	# oficina comunitária com gerador
	var of := Node3D.new()
	of.position = Vector3(raio - 14.0, _altura_local(p, m, Vector3(raio - 14.0, 0, -22.0)), -22.0)
	of.rotation.y = -0.6
	p.add_child(of)
	var chapa := B.mat(B.worn(Color(0.45, 0.45, 0.42), 0.4), 0.6, 0.5)
	for s in [-1.0, 1.0]:
		B.box(of, Vector3(0.1, 3.2, 6.0), Vector3(s * 3.5, 1.6, 0), chapa)
	B.box(of, Vector3(7.0, 3.2, 0.1), Vector3(0, 1.6, -3.0), chapa)
	B.box(of, Vector3(7.6, 0.08, 6.6), Vector3(0, 3.3, 0), chapa)
	B.box(of, Vector3(3.0, 0.9, 0.9), Vector3(-1.5, 0.45, -2.3), madeira)
	B.box(of, Vector3(0.9, 0.7, 0.7), Vector3(2.2, 0.35, 1.8), B.mat(Color(0.8, 0.55, 0.1), 0.6))
	# caixa d'água alta
	var cx := Vector3(-raio + 12.0, 0, -20.0)
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			B.box(p, Vector3(0.18, 7.0, 0.18), cx + Vector3(dx, _altura_local(p, m, cx) + 3.5, dz), madeira)
	B.cyl(p, 1.6, 2.2, cx + Vector3(0, _altura_local(p, m, cx) + 8.1, 0), B.mat(B.worn(Color(0.6, 0.6, 0.62), 0.5), 0.5, 0.6), Vector3.ZERO, 16)
	# varais, carroça, caixas e barris espalhados, postes de luz
	_varal(p, Vector3(-16, 0, 8), Vector3(-11, 0, 9), r)
	_varal(p, Vector3(12, 0, 10), Vector3(17, 0, 9), r)
	var car := Node3D.new()
	car.position = Vector3(-4.0, 0, 15.0)
	car.rotation.y = 0.5
	p.add_child(car)
	B.box(car, Vector3(1.4, 0.5, 2.4), Vector3(0, 0.8, 0), madeira)
	for s in [-1.0, 1.0]:
		B.cyl(car, 0.55, 0.08, Vector3(s * 0.8, 0.55, 0), madeira, Vector3(0, 0, 90), 12)
	B.box(car, Vector3(0.08, 0.08, 1.8), Vector3(0.3, 0.7, 2.0), madeira)
	_caixas(car, Vector3(-0.4, 1.05, -0.6), r, 3)
	_caixas(p, Vector3(-14.0, 0, -6.5), r, 6)
	_caixas(p, Vector3(10.0, 0, -6.5), r, 5)
	for q in [Vector3(-2.5, 0, 12), Vector3(9.0, 0, -18.0), Vector3(-9.0, 0, -18.0)]:
		_barril(p, q, Color(0.2, 0.35, 0.2))
	for q in [Vector3(3.2, 0, raio - 6.0), Vector3(-3.2, 0, 16.0), Vector3(3.2, 0, -10.0), Vector3(-3.2, 0, -26.0), Vector3(14.0, 0, -4.0), Vector3(-18.0, 0, -4.0)]:
		if q.length() < raio - 2.0:
			_poste_luz(p, q, m)
	# espaços vazios: parquinho, torres internas, hortas, galinheiro, árvores...
	var ocup: Array = [[Vector3(0, 0, 0), 0.0]]
	for z in range(int(-raio), int(raio) + 1, 3):
		ocup.append([Vector3(0, 0, z), 4.6])            # rua principal + calçadas
	for x in range(int(-raio * 0.7), int(raio * 0.7) + 1, 3):
		ocup.append([Vector3(x, 0, -6.0), 3.8])          # rua transversal
	ocup.append([Vector3(0, 0, 4.0), 9.5])               # praça
	for lt in lotes:
		ocup.append([lt[0], 7.5])
		ocup.append([lt[0] + Vector3(lt[0].x * 0.0, 0, 0) + (Vector3(-sin(lt[1]), 0, -cos(lt[1])) * 4.8), 3.0])
	ocup.append([Vector3(0, 0, -raio + 11.0), 10.5])     # igreja
	ocup.append([Vector3(-12.0, 0, -raio + 10.0), 7.5])  # cemitério
	ocup.append([Vector3(-9.0, 0, -2.5), 5.0])           # mercado
	ocup.append([Vector3(7.0, 0, -2.5), 3.0])
	ocup.append([Vector3(raio - 14.0, 0, -22.0), 5.5])   # oficina
	ocup.append([Vector3(-raio + 12.0, 0, -20.0), 3.0])  # caixa d'água
	for tx in [-9.0, 9.0]:
		ocup.append([Vector3(tx, 0, raio - 1.5), 3.0])
	ocup.append([Vector3(-4.0, 0, 15.0), 2.5])           # carroça
	for q in [Vector3(-13.5, 0, 8.5), Vector3(14.5, 0, 9.5)]:
		ocup.append([q, 3.0])                            # varais
	var feitos := VilaExtra.preencher(p, raio, ocup, r, m, {"grandes": [["parquinho", 6.0], ["horta", 4.2], ["galinheiro", 3.2], ["torre", 2.2], ["torre", 2.2], ["cisterna", 1.6], ["horta", 4.2]]})
	var nt := 0
	for fz in feitos:
		if fz[0] == "torre":
			_pessoa(fz[2], Vector3(0.3, 5.6, 0.3), 0.0, "vigia", r, m, "%s:torre%d" % [j.id, nt])
			nt += 1
		elif fz[0] == "parquinho":
			_pessoa(p, fz[1] + Vector3(-4.5, 0, 3.0), r.randf() * TAU, "morador", r, m, j.id + ":parque")
	# guardas e moradores
	_pessoa(p, Vector3(-9.0, 4.7, raio - 1.5), 0.0, "vigia", r, m, j.id + ":vigia")
	_pessoa(p, Vector3(9.0, 4.7, raio - 1.5), 0.0, "vigia", r, m, j.id + ":vigia2")
	_pessoa(p, Vector3(4.0, 0, raio - 3.0), PI, "vigia", r, m, j.id + ":portao")
	var funcoes := ["mecanico", "agricultor", "medico", "morador", "vigia", "batedor", "morador", "agricultor"]
	for i in r.randi_range(6, 9):
		var a := r.randf() * TAU
		var d := r.randf_range(2.0, raio - 12.0)
		var fn: String = funcoes[r.randi() % funcoes.size()]
		_pessoa(p, Vector3(sin(a) * d * 0.4, 0, cos(a) * d), r.randf() * TAU, fn, r, m, "%s:p%d" % [j.id, i])

# ------------------------------------------------------------ fazenda
static func _fazenda(p: Node3D, f: Dictionary, r: RandomNumberGenerator, m: WorldGen) -> void:
	var raio: float = f.raio
	var j: Dictionary = f.juncao
	_muro(p, raio, 0.16, r, m, false)
	_placa(p, Vector3(0, 2.4, raio + 0.5), 0.0, j.nome.to_upper(), Color(0.95, 0.88, 0.7))
	var madeira := B.mat(Color(0.32, 0.23, 0.15), 0.9)
	for s in [-1.0, 1.0]:
		B.box(p, Vector3(0.25, 3.0, 0.25), Vector3(s * 3.2, 1.5, raio), madeira)
	B.box(p, Vector3(6.8, 0.3, 0.25), Vector3(0, 3.0, raio), madeira)
	# casa-sede com varanda
	var gpos := p.transform * Vector3(-11, 0, 4)
	var sede := m.criar_predio(p.get_parent(), gpos, p.rotation.y + PI * 0.5, "sede", 11.0, 9.0, 2, r.randi(), j.id + ":sede")
	# celeiro vermelho
	var cel := Node3D.new()
	cel.position = Vector3(10, 0, -8)
	cel.rotation.y = -PI * 0.5
	p.add_child(cel)
	var verm := B.mat(B.worn(Color(0.55, 0.12, 0.08), 0.45), 0.9)
	B.box(cel, Vector3(10, 5, 8), Vector3(0, 2.5, 0), verm)
	var tri := PackedVector2Array([Vector2(-4.4, 5), Vector2(4.4, 5), Vector2(2.6, 6.8), Vector2(0, 7.6), Vector2(-2.6, 6.8)])
	B.extruded(cel, tri, 10.4, Vector3.ZERO, B.mat(Color(0.35, 0.33, 0.3), 0.6, 0.5))
	B.box(cel, Vector3(0.05, 3.6, 3.2), Vector3(5.01, 1.8, 0), B.mat(Color(0.08, 0.06, 0.05), 1.0))
	for s in [-1.0, 1.0]:
		var porta := B.box(cel, Vector3(0.1, 3.6, 1.6), Vector3(5.5, 1.8, s * 2.3), B.mat(Color(0.85, 0.82, 0.75), 0.9))
		porta.rotation.y = s * 0.8
	for k in 6:
		B.cyl(cel, 0.55, 1.1, Vector3(3.5 - (k % 3) * 1.2, 0.55 + (k / 3) * 1.1, -2.5), B.mat(Color(0.75, 0.62, 0.3), 1.0), Vector3(90, 0, 0), 10)  # fardos de feno
	_vasculhavel(p, Vector3(10, 1.0, -8), "Celeiro", "celeiro", 1.0, m, j.id + ":celeiro")
	# silo e caixa d'água
	B.cyl(p, 2.2, 9.0, Vector3(17, 4.5, 3), B.mat(B.worn(Color(0.7, 0.7, 0.68), 0.5), 0.5, 0.6), Vector3.ZERO, 18)
	B.sphere(p, 2.2, Vector3(17, 9.0, 3), B.mat(Color(0.6, 0.6, 0.58), 0.5, 0.6), Vector3(1, 0.5, 1), 16)
	B.cyl(p, 1.2, 1.6, Vector3(-4, 5.2, -14), B.mat(Color(0.2, 0.35, 0.55), 0.6), Vector3.ZERO, 14)
	for dx in [-0.8, 0.8]:
		for dz in [-0.8, 0.8]:
			B.box(p, Vector3(0.15, 4.4, 0.15), Vector3(-4 + dx, 2.2, -14 + dz), madeira)
	_vasculhavel(p, Vector3(-4, 1.0, -14), "Caixa d'água", "poco", 0.25, m, j.id + ":agua")
	if r.randf() < 0.75:
		_porao(p, Vector3(-11, 0, 12.5), m, j.id + ":porao")
	# trator velho
	var tr := Node3D.new()
	tr.position = Vector3(2, 0, -16)
	tr.rotation.y = 0.6
	p.add_child(tr)
	var tcor := B.mat(B.worn(Color(0.2, 0.42, 0.18), 0.35), 0.7, 0.2)
	B.box(tr, Vector3(1.2, 1.0, 2.4), Vector3(0, 1.2, 0.3), tcor)
	B.box(tr, Vector3(1.0, 1.2, 1.0), Vector3(0, 2.1, -0.6), tcor)
	B.cyl(tr, 0.06, 1.0, Vector3(0.3, 2.2, 1.0), B.mat(Color(0.1, 0.1, 0.1), 0.7), Vector3.ZERO, 6)
	for s in [-1.0, 1.0]:
		var rg := B.wheel(tr, Vector3(s * 0.9, 0.8, -0.6), 0.8, 0.45, Color(0.7, 0.55, 0.1))
		var rp := B.wheel(tr, Vector3(s * 0.75, 0.45, 1.2), 0.45, 0.25, Color(0.7, 0.55, 0.1))
	# roçado: fileiras de milho
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var planta := CylinderMesh.new()
	planta.top_radius = 0.0
	planta.bottom_radius = 0.12
	planta.height = 1.6
	planta.radial_segments = 4
	mm.mesh = planta
	var pts: Array[Transform3D] = []
	for row in 9:
		for k in 22:
			var pos := Vector3(-24 + k * 1.1 + r.randf_range(-0.2, 0.2), 0, -6 - row * 1.4 + r.randf_range(-0.2, 0.2))
			if pos.length() > raio - 3.0 or (pos - Vector3(-11, 0, 4)).length() < 7.0:
				continue
			pts.append(Transform3D(Basis().scaled(Vector3.ONE * r.randf_range(0.7, 1.2)), pos + Vector3(0, 0.8, 0)))
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, pts[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = B.mat(Color(0.42, 0.45, 0.16), 0.9, 0.0, "milho")
	p.add_child(mmi)
	# alguns zumbis vagando (fazenda abandonada)
	for i in r.randi_range(1, 3):
		var a := r.randf() * TAU
		var g := p.transform * Vector3(sin(a) * 15.0, 0, cos(a) * 15.0)
		g.y = m.altura(g.x, g.z)
		m.criar_zumbi(m, g, r.randf() * TAU, r.randi())

# ------------------------------------------------------------ ferro-velho
static func _ferro_velho(p: Node3D, f: Dictionary, r: RandomNumberGenerator, m: WorldGen) -> void:
	var raio: float = f.raio
	var j: Dictionary = f.juncao
	_muro(p, raio, 0.2, r, m, true)
	_placa(p, Vector3(0, 3.4, raio + 0.3), 0.0, j.nome.to_upper(), Color(0.95, 0.75, 0.25))
	# galpão
	var gal := Node3D.new()
	gal.position = Vector3(-12, 0, -6)
	gal.rotation.y = PI * 0.5
	p.add_child(gal)
	var chapa := B.mat(B.worn(Color(0.45, 0.45, 0.42), 0.35), 0.6, 0.5)
	for s in [-1.0, 1.0]:
		B.box(gal, Vector3(0.1, 4.0, 9.0), Vector3(s * 5.0, 2.0, 0), chapa)
	B.box(gal, Vector3(10, 4, 0.1), Vector3(0, 2, -4.5), chapa)
	var teto := B.box(gal, Vector3(10.6, 0.08, 9.6), Vector3(0, 4.3, 0), chapa)
	teto.rotation.x = 0.06
	B.box(gal, Vector3(3.0, 0.9, 1.0), Vector3(-2.5, 0.45, -3.5), B.mat(Color(0.35, 0.3, 0.25), 0.8))  # bancada
	Kit.por(gal, "saw", Vector3(-3.2, 0.91, -3.4), Vector3(90, 10, 0))
	Kit.por(gal, "hammer", Vector3(-2.4, 0.91, -3.3), Vector3(90, -40, 0))
	Kit.por(gal, "handdrill", Vector3(-1.8, 0.91, -3.6), Vector3(90, 70, 0))
	Kit.por(gal, "grindstone", Vector3(0.2, 0.0, -3.6), Vector3(0, 90, 0))
	Kit.por(gal, "anvil", Vector3(1.6, 0.0, -3.4), Vector3(0, 15, 0))
	Kit.por(gal, "shovel", Vector3(-4.85, 0.75, -1.5), Vector3(0, 90, -12))
	Kit.por(gal, "pickaxe", Vector3(-4.85, 0.55, -0.6), Vector3(0, 90, 70))
	Kit.por(gal, "bucket_metal", Vector3(-0.8, 0.0, -2.6), Vector3(0, 30, 0))
	for k in 8:
		B.wheel(gal, Vector3(3.2, 0.3 + k * 0.28, -2.8), 0.42, 0.26).rotation_degrees.z = 90
	_vasculhavel(p, Vector3(-12, 1.0, -6), "Galpão de peças", "galpao", 1.5, m, j.id + ":galpao")
	# contêineres
	for i in 2:
		var cpos := Vector3(13, 1.3 + i * 2.6, -10 + i * 0.4)
		var ct := B.box(p, Vector3(2.4, 2.6, 6.0), cpos, B.mat(B.worn([Color(0.15, 0.3, 0.5), Color(0.6, 0.2, 0.1)][i], 0.4), 0.6, 0.4))
		ct.rotation.y = 0.2 + i * 0.08
	_vasculhavel(p, Vector3(13, 1.0, -10), "Contêiner", "container", 0.75, m, j.id + ":cont")
	# guindaste
	var amar := B.mat(B.worn(Color(0.85, 0.6, 0.1), 0.4), 0.6, 0.4)
	B.box(p, Vector3(2.2, 1.2, 3.5), Vector3(4, 0.9, -15), amar)
	var lanca := B.box(p, Vector3(0.4, 0.4, 9.0), Vector3(4, 5.0, -11), amar)
	lanca.rotation.x = -0.6
	B.cyl(p, 0.02, 3.0, Vector3(4, 5.2, -7.4), B.mat(Color(0.1, 0.1, 0.1), 0.6), Vector3.ZERO, 4)
	# pilhas de pneus
	for i in 3:
		for k in r.randi_range(3, 6):
			var pn := B.wheel(p, Vector3(-4 + i * 1.3, 0.15 + k * 0.28, 14 + r.randf_range(-0.3, 0.3)), 0.42, 0.26)
			pn.rotation_degrees.z = 90
	# carros empilhados: os de baixo podem ser desmontados
	for i in r.randi_range(7, 10):
		var a := r.randf_range(-2.4, 2.4) + PI
		var d := r.randf_range(8.0, raio - 5.0)
		var lp := Vector3(sin(a) * d, 0, cos(a) * d)
		var g := p.transform * lp
		g.y = m.altura(g.x, g.z) - 0.02
		var rc := RandomNumberGenerator.new()
		rc.seed = r.randi()
		var c := m.carro_abandonado(m, g, r.randf() * TAU, rc, "%s:car%d" % [j.id, i])
		if r.randf() < 0.35:
			var rc2 := RandomNumberGenerator.new()
			rc2.seed = r.randi()
			var de_cima := m.carro_abandonado(c, Vector3(r.randf_range(-0.3, 0.3), 1.15, r.randf_range(-0.3, 0.3)), r.randf_range(-0.4, 0.4), rc2)
	# às vezes um reboque abandonado guardado no pátio
	if r.randf() < 0.45:
		m.reboque_abandonado_em(p.transform * Vector3(8, 0, 8), p.rotation.y + 1.2, "fv:" + j.id, r)
	for i in r.randi_range(1, 3):
		var a := r.randf() * TAU
		var g := p.transform * Vector3(sin(a) * 12.0, 0, cos(a) * 12.0)
		g.y = m.altura(g.x, g.z)
		m.criar_zumbi(m, g, r.randf() * TAU, r.randi())

# ------------------------------------------------------------ lugares na mata
static func _zumbis_lugar(p: Node3D, n: int, raio: float, r: RandomNumberGenerator, m: WorldGen) -> void:
	for i in n:
		var a := r.randf() * TAU
		var g := p.transform * Vector3(sin(a) * raio, 0, cos(a) * raio)
		g.y = m.altura(g.x, g.z)
		m.criar_zumbi(m, g, r.randf() * TAU, r.randi())

static func _cabana(p: Node3D, f: Dictionary, r: RandomNumberGenerator, m: WorldGen) -> void:
	var j: Dictionary = f.juncao
	var pr := m.criar_predio(p.get_parent(), p.transform * Vector3(0, 0, -1.0), p.rotation.y, "cabana", 6.0, 5.0, 1, r.randi(), j.id + ":cab")
	var casca := Texturas.material("casca", Color(0.32, 0.25, 0.19))
	# lenha empilhada, cepo com machado, latrina
	for i in 12:
		B.cyl(p, 0.13, 1.0, Vector3(4.2, 0.15 + (i / 4) * 0.25, -2.5 + (i % 4) * 0.27), casca, Vector3(90, 0, 0), 7)
	B.cyl(p, 0.35, 0.6, Vector3(3.2, 0.3, 2.0), casca, Vector3.ZERO, 8)
	B.box(p, Vector3(0.04, 0.6, 0.04), Vector3(3.2, 0.85, 2.0), B.mat(Color(0.5, 0.35, 0.2)), Vector3(0, 0, 25))
	var lat := Texturas.material("tabuas", Color(0.4, 0.3, 0.2))
	B.box(p, Vector3(1.2, 2.2, 1.2), Vector3(-5.0, 1.1, -3.0), lat)
	if r.randf() < 0.5:
		_porao(p, Vector3(-1.5, 0, 3.6), m, j.id + ":porao")
	_zumbis_lugar(p, r.randi_range(0, 2), 7.0, r, m)

static func _barraca_camp(p: Node3D, pos: Vector3, rot: float, cor: Color) -> void:
	var b := Node3D.new()
	b.position = pos
	b.rotation.y = rot
	p.add_child(b)
	var lona := Texturas.material("tecido", cor)
	var tri := PackedVector2Array([Vector2(-1.1, 0), Vector2(1.1, 0), Vector2(0, 1.25)])
	var corpo := B.extruded(b, tri, 2.2, Vector3.ZERO, lona)
	corpo.rotation.y = PI * 0.5
	B.box(b, Vector3(2.2, 0.02, 2.2), Vector3(0, 0.01, 0), Texturas.material("tecido", cor.darkened(0.4)))

static func _acampamento(p: Node3D, f: Dictionary, r: RandomNumberGenerator, m: WorldGen) -> void:
	var j: Dictionary = f.juncao
	var cores := [Color(0.25, 0.4, 0.2), Color(0.6, 0.35, 0.1), Color(0.2, 0.3, 0.5)]
	for i in 3:
		var a := TAU * i / 3.0 + 0.3
		var pos := Vector3(sin(a) * 4.5, 0, cos(a) * 4.5)
		pos.y = _altura_local(p, m, pos)
		_barraca_camp(p, pos, a + PI, cores[i])
		_vasculhavel(p, pos + Vector3(0, 0.6, 0), "Barraca", "acampamento", 0.2, m, "%s:b%d" % [j.id, i])
	# fogueira apagada, panela, cadeiras dobráveis, mochila caída
	for k in 8:
		var a := TAU * k / 8.0
		B.sphere(p, 0.14, Vector3(cos(a) * 0.5, 0.07, sin(a) * 0.5), Texturas.material("pedra", Color(0.4, 0.4, 0.4)), Vector3(1, 0.7, 1), 5)
	B.cyl(p, 0.35, 0.05, Vector3(0, 0.03, 0), B.mat(Color(0.08, 0.07, 0.06), 1.0), Vector3.ZERO, 10)
	B.cyl(p, 0.18, 0.2, Vector3(0.1, 0.15, 0.0), Texturas.material("metal", Color(0.3, 0.3, 0.3), 0.5, 0.6), Vector3.ZERO, 10)
	B.box(p, Vector3(0.4, 0.5, 0.25), Vector3(1.6, 0.25, 1.2), Texturas.material("tecido", Color(0.3, 0.32, 0.2)), Vector3(0, 0.6, 1.4))
	_vasculhavel(p, Vector3(1.6, 0.4, 1.2), "Mochila largada", "acampamento", 0.1, m, j.id + ":moch")
	_varal(p, Vector3(-3, 0, -1), Vector3(2, 0, -3), r)
	_zumbis_lugar(p, r.randi_range(1, 3), 8.0, r, m)

static func _torre(p: Node3D, f: Dictionary, r: RandomNumberGenerator, m: WorldGen) -> void:
	var j: Dictionary = f.juncao
	var pr := m.criar_predio(p.get_parent(), p.global_position, p.rotation.y, "torre", 3.2, 3.2 + Predio.ESC_COMP * 0.0, 4, r.randi(), j.id + ":torre")
	pr.profundidade = 4.0
	pr.construir()
	var topo := Node3D.new()
	topo.position = Vector3(1.0, (pr.andares - 1) * Predio.H + 0.6, 0.8)
	pr.add_child(topo)
	topo.set_meta("nome", "Caixa do vigia florestal")
	topo.set_meta("tabela", "torre")
	topo.set_meta("horas", 0.25)
	topo.set_meta("chave", j.id + ":topo")
	m.vasculhaveis.append(topo)
	B.box(pr, Vector3(0.6, 0.4, 0.4), topo.position + Vector3(0, -0.4, 0), Texturas.material("metal", Color(0.25, 0.35, 0.25), 0.5, 0.4))
	_zumbis_lugar(p, r.randi_range(0, 2), 6.0, r, m)

static func _carro_mata(p: Node3D, f: Dictionary, r: RandomNumberGenerator, m: WorldGen) -> void:
	var j: Dictionary = f.juncao
	var rc := RandomNumberGenerator.new()
	rc.seed = r.randi()
	var c := m.carro_abandonado(p, Vector3(0, 0.2, 0), 0.4, rc)
	c.rotation = Vector3(0.12, 0.4, 0.2)
	var casca := Texturas.material("casca", Color(0.32, 0.25, 0.19))
	B.cyl(p, 0.4, 9.0, Vector3(1.0, 4.5, 2.6), casca, Vector3.ZERO, 8, 0.25)
	_vasculhavel(p, Vector3(0.8, 0.8, 0.0), "Carro acidentado", "carro_mata", 0.5, m, j.id + ":carro")
	B.box(p, Vector3(0.6, 0.4, 0.25), Vector3(-1.8, 0.2, 1.2), Texturas.material("tecido", Color(0.15, 0.15, 0.2)), Vector3(0, 0.7, 1.4))
	_vasculhavel(p, Vector3(-1.8, 0.4, 1.2), "Mala jogada", "acampamento", 0.1, m, j.id + ":mala")
	_zumbis_lugar(p, r.randi_range(1, 2), 5.0, r, m)

static func _serraria(p: Node3D, f: Dictionary, r: RandomNumberGenerator, m: WorldGen) -> void:
	var j: Dictionary = f.juncao
	var madeira := Texturas.material("tabuas", Color(0.4, 0.3, 0.2))
	var chapa := Texturas.material("metal", Color(0.5, 0.5, 0.48), 0.6, 0.5)
	# galpão aberto sobre pilares
	for x in [-5.0, 0.0, 5.0]:
		for z in [-3.5, 3.5]:
			B.box(p, Vector3(0.25, 4.0, 0.25), Vector3(x, 2.0, z), madeira)
	var tel := B.box(p, Vector3(11.0, 0.1, 8.0), Vector3(0, 4.1, 0), chapa)
	tel.rotation.x = 0.06
	# máquina de serra e esteira
	B.box(p, Vector3(4.5, 0.9, 1.0), Vector3(0, 0.45, 0), Texturas.material("metal", Color(0.3, 0.32, 0.3), 0.5, 0.6))
	B.cyl(p, 0.7, 0.04, Vector3(0, 1.1, 0), Texturas.material("metal", Color(0.7, 0.7, 0.7), 0.3, 0.9), Vector3(90, 0, 0), 24)
	_vasculhavel(p, Vector3(2.0, 1.0, 1.2), "Bancada da serraria", "serraria", 1.0, m, j.id + ":banc")
	# pilhas de toras
	var casca := Texturas.material("casca", Color(0.32, 0.25, 0.19))
	for pilha in 2:
		for i in 10:
			B.cyl(p, 0.3, 5.0, Vector3(-9.5 + pilha * 19.0, 0.3 + (i / 4) * 0.5, -2.0 + (i % 4) * 0.62), casca, Vector3(0, 0, 90), 8)
	m.criar_predio(p.get_parent(), p.transform * Vector3(0, 0, -9.5), p.rotation.y, "casa", 6.0, 5.0, 1, r.randi(), j.id + ":escrit")
	_zumbis_lugar(p, r.randi_range(1, 3), 9.0, r, m)

# ------------------------------------------------------------ assentamento
## Comunidade murada que o jogador pode defender da horda. A parte que muda (muro,
## portão, torres, holofotes, estacas) fica no nó Assentamento; aqui vai o resto.
static func _assentamento(p: Node3D, f: Dictionary, r: RandomNumberGenerator, m: WorldGen) -> void:
	var j: Dictionary = f.juncao
	var a := Assentamento.new()
	a.id = f.id
	a.mundo = m
	a.set_meta("nao_mesclar", true)
	p.add_child(a)
	var defesa: Node = m.get_parent().get("defesa")
	var e: Dictionary = defesa.obter(f.id, a) if defesa else {}
	var caido: bool = e.get("fase", "") == "caido"
	var R := Assentamento.R
	var madeira := B.mat(Color(0.32, 0.23, 0.15), 0.9)
	var chao := B.mat(Color(0.36, 0.29, 0.21), 1.0, 0.0, "rua_vila")
	# caminho do portão até a praça e a praça
	VilaExtra.rua(p, Vector3(0, 0, R + 1.0), Vector3(0, 0, 5.0), 4.5, r, true)
	B.cyl(p, 7.5, 0.05, Vector3(0, 0.035, 2.0), chao, Vector3.ZERO, 24)
	# placa na estrada de chegada
	var placa := Node3D.new()
	placa.position = Vector3(6.0, _altura_local(p, m, Vector3(6.0, 0, R + 12.0)), R + 12.0)
	placa.rotation.y = 0.35
	p.add_child(placa)
	for sx in [-1.3, 1.3]:
		B.box(placa, Vector3(0.14, 2.6, 0.14), Vector3(sx, 1.3, -0.05), madeira)
	B.box(placa, Vector3(3.2, 1.2, 0.08), Vector3(0, 2.0, 0), B.mat(Color(0.42, 0.32, 0.2), 0.9))
	var nome_l := Label3D.new()
	nome_l.text = String(j.nome).to_upper()
	nome_l.font_size = 72
	nome_l.pixel_size = 0.0042
	nome_l.modulate = Color(0.95, 0.9, 0.78)
	nome_l.outline_size = 8
	nome_l.outline_modulate = Color(0.05, 0.04, 0.03)
	nome_l.position = Vector3(0, 2.25, 0.05)
	nome_l.double_sided = false
	placa.add_child(nome_l)
	var aviso := Label3D.new()
	aviso.text = "ARMAS NA MÃO, NÃO NA CARA"
	aviso.font_size = 64
	aviso.pixel_size = 0.005
	aviso.modulate = Color(0.9, 0.35, 0.25)
	aviso.outline_size = 6
	aviso.outline_modulate = Color(0.05, 0.04, 0.03)
	aviso.position = Vector3(0, 1.7, 0.05)
	aviso.double_sided = false
	placa.add_child(aviso)
	# casas em volta da praça (deixa a frente livre)
	var cores := [Color(0.75, 0.68, 0.55), Color(0.6, 0.66, 0.6), Color(0.78, 0.6, 0.45), Color(0.65, 0.6, 0.7), Color(0.8, 0.76, 0.66), Color(0.7, 0.5, 0.42)]
	var queimado := Color(0.16, 0.14, 0.12)
	var angs := [0.95, 1.6, 2.25, 2.9, 3.55, 4.2, 4.85, 5.4]
	for k in angs.size():
		var an: float = angs[k] + r.randf_range(-0.08, 0.08)
		var d := r.randf_range(17.0, 21.0)
		var pos := Vector3(sin(an) * d, 0, cos(an) * d)
		var cor: Color = queimado if caido and r.randf() < 0.6 else cores[r.randi() % cores.size()]
		var casa := _casa_viva(p, pos, an + PI, r.randf_range(6.5, 7.5), r.randf_range(6.0, 6.8), r, m, "%s:casa%d" % [j.id, k], r.randf_range(0.6, 0.85) if not caido else 0.15, caido)
		var atras: Vector3 = casa.transform * Vector3(0, 0, -4.0)
		if k % 2 == 0:
			for q in 3:
				var cant := B.box(p, Vector3(2.4, 0.2, 0.5), atras + Vector3(0, 0.1, q * 0.7 - 0.7), B.mat(Color(0.22, 0.32, 0.12), 0.9, 0.0, "canteiro"))
				cant.rotation.y = an
		else:
			_barril(p, atras + Vector3(0.8, 0, 0), Color(0.2, 0.35, 0.55))
	# galpão comunitário aberto (onde o líder fica), com mesa e mapa
	var gal := Node3D.new()
	gal.position = Vector3(0, _altura_local(p, m, Vector3(0, 0, -6.0)), -6.0)
	p.add_child(gal)
	var chapa := B.mat(B.worn(Color(0.45, 0.45, 0.42), 0.4), 0.6, 0.5)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.cyl(gal, 0.12, 3.2, Vector3(sx * 4.0, 1.6, sz * 2.5), madeira, Vector3.ZERO, 6)
	B.box(gal, Vector3(9.0, 0.08, 6.0), Vector3(0, 3.25, 0), chapa, Vector3(4, 0, 0))
	B.box(gal, Vector3(3.2, 0.08, 1.4), Vector3(0, 0.85, 0), madeira)
	for sx in [-1.4, 1.4]:
		B.box(gal, Vector3(0.08, 0.85, 1.2), Vector3(sx, 0.42, 0), madeira)
	B.box(gal, Vector3(1.6, 0.02, 1.0), Vector3(0.3, 0.88, 0), B.mat(Color(0.82, 0.76, 0.6), 0.9))   # mapa aberto
	B.box(gal, Vector3(2.4, 1.4, 0.06), Vector3(0, 1.8, -2.45), madeira)
	_placa(gal, Vector3(0, 2.3, -2.4), 0.0, "QUADRO DE TURNOS", Color(0.95, 0.9, 0.75))
	for q in 6:
		B.box(gal, Vector3(0.3, 0.22, 0.01), Vector3(-0.8 + (q % 3) * 0.8, 1.9 - (q / 3) * 0.4, -2.41), B.mat(Color(0.9, 0.88, 0.78), 0.9))
	# fogueira da praça
	B.cyl(p, 0.7, 0.25, Vector3(3.5, 0.12, 4.0), B.mat(Color(0.35, 0.33, 0.3), 0.9), Vector3.ZERO, 10)
	if not caido:
		B.sphere(p, 0.35, Vector3(3.5, 0.5, 4.0), B.emissive(Color(1.0, 0.5, 0.15), 3.0))
		var fogo := OmniLight3D.new()
		fogo.light_color = Color(1.0, 0.55, 0.25)
		fogo.light_energy = 1.8
		fogo.omni_range = 10.0
		fogo.position = Vector3(3.5, 1.4, 4.0)
		fogo.set_meta("nao_mesclar", true)
		p.add_child(fogo)
	for k in 5:
		var an2 := TAU * k / 5.0
		var tora := B.cyl(p, 0.2, 1.6, Vector3(3.5 + sin(an2) * 2.2, 0.2, 4.0 + cos(an2) * 2.2), B.mat(Color(0.36, 0.27, 0.18), 0.95), Vector3(0, 0, 90), 8)
		tora.rotation.y = an2
	# caixa d'água e horta grande nos fundos
	var cx := Vector3(-11.0, 0, -12.0)
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			B.box(p, Vector3(0.18, 6.0, 0.18), cx + Vector3(dx, _altura_local(p, m, cx) + 3.0, dz), madeira)
	B.cyl(p, 1.5, 2.0, cx + Vector3(0, _altura_local(p, m, cx) + 7.0, 0), B.mat(B.worn(Color(0.6, 0.6, 0.62), 0.5), 0.5, 0.6), Vector3.ZERO, 16)
	for q in 6:
		B.box(p, Vector3(6.0, 0.22, 0.7), Vector3(10.0, 0.11 + _altura_local(p, m, Vector3(10, 0, -12)), -15.0 + q * 1.2), B.mat(Color(0.2, 0.3, 0.1) if not caido else Color(0.22, 0.18, 0.12), 0.9, 0.0, "horta_a" if not caido else "horta_morta"))
	_varal(p, Vector3(-8, 0, 6), Vector3(-4, 0, 9), r)
	# vazios do assentamento: árvores, parquinho, galinheiro, lenha, barricadas
	if not caido:
		var oc: Array = []
		for z in range(0, int(R) + 2, 3):
			oc.append([Vector3(0, 0, z), 3.6])
		oc.append([Vector3(0, 0, 2.0), 8.0])
		oc.append([Vector3(0, 0, -6.0), 6.0])
		oc.append([Vector3(-11.0, 0, -12.0), 3.0])
		oc.append([Vector3(10.0, 0, -12.0), 5.0])
		for k in angs.size():
			var an4: float = angs[k]
			oc.append([Vector3(sin(an4) * 19.0, 0, cos(an4) * 19.0), 5.2])
		oc.append([Vector3(-6, 0, 7.5), 3.0])
		VilaExtra.preencher(p, R - 2.0, oc, r, m, {"grandes": [["parquinho", 5.5], ["horta", 4.0], ["galinheiro", 3.0], ["barricada", 2.6], ["barricada", 2.6], ["cisterna", 1.6]], "denso": true})
	_caixas(p, Vector3(6.5, 0, -2.0), r, 5)
	_caixas(p, Vector3(-6.0, 0, 14.0), r, 4)
	for q in [Vector3(2.8, 0, 15.0), Vector3(-2.8, 0, 22.0), Vector3(-9.0, 0, -2.0), Vector3(9.0, 0, 3.0)]:
		_poste_luz(p, q, m)
	if caido:
		# só restos: dá para vasculhar o que sobrou, e os mortos ficaram
		_vasculhavel(p, Vector3(0, 1.0, -6.0), "Depósito do assentamento", "galpao", 1.5, m, j.id + ":restos1")
		_vasculhavel(p, Vector3(-11.0, 1.0, -10.0), "Restos da cozinha", "loja", 0.75, m, j.id + ":restos2")
		_zumbis_lugar(p, 9, 18.0, r, m)
		return
	# líder e moradores
	var lid := _pessoa(p, Vector3(1.6, 0, -4.6), 0.15, "lider", r, m, j.id + ":lider")
	lid.set_meta("nome", e.get("lider", "Dona Rosa"))
	lid.set_meta("assent", f.id)
	lid.com_bone = true
	# comerciante do assentamento (troca, pedidos e reputação)
	var vend := _pessoa(p, Vector3(-4.5, 0, -6.0), 0.4, "vendedor", r, m, j.id + ":vendedor")
	vend.set_meta("nao_mesclar", true)
	var funcoes := ["agricultor", "mecanico", "medico", "morador", "batedor", "vigia", "morador"]
	for i in r.randi_range(5, 7):
		var an3 := r.randf() * TAU
		var d3 := r.randf_range(4.0, 14.0)
		_pessoa(p, Vector3(sin(an3) * d3, 0, cos(an3) * d3 * 0.7 - 1.0), r.randf() * TAU, funcoes[r.randi() % funcoes.size()], r, m, "%s:p%d" % [j.id, i])

## Casa de verdade (Predio: dá para entrar e vasculhar) com quintal: muro baixo e
## portãozinho, vasos, botijão, tanque, bicicleta, casinha de cachorro, varanda.
## Devolve um Node3D na mesma posição/rotação local (para pôr coisas atrás dela).
static func _casa_viva(p: Node3D, pos: Vector3, rot_y: float, larg: float, prof: float, r: RandomNumberGenerator, m: WorldGen, chave: String, cond: float, queimada: bool) -> Node3D:
	var g := p.transform * pos
	var pr := m.criar_predio(p.get_parent(), g, p.rotation.y + rot_y, "casa", larg, prof, 1, r.randi(), chave, cond)
	var ref := Node3D.new()
	ref.position = pos + Vector3(0, _altura_local(p, m, pos), 0)
	ref.rotation.y = rot_y
	p.add_child(ref)
	if queimada:
		pr.set_meta("queimada", true)
		for q in 4:
			B.box(ref, Vector3(r.randf_range(0.6, 1.4), 0.08, r.randf_range(0.6, 1.2)), Vector3(r.randf_range(-larg * 0.5, larg * 0.5), 0.05, prof * 0.5 + r.randf_range(0.5, 2.0)), B.mat(Color(0.1, 0.09, 0.08), 1.0, 0.0, "cinza_queimado"))
		return ref
	var hd := prof * 0.5
	var hw := larg * 0.5
	var madeira := B.mat(Color(0.36, 0.25, 0.15), 0.9, 0.0, "madeira_quintal")
	var tijolo := Texturas.material("tijolo", Color(0.6, 0.34, 0.24))
	var reboco := Texturas.material("reboco", Color(0.8, 0.77, 0.7))
	# varanda com colunas e banco (metade das casas)
	if r.randf() < 0.5:
		var piso := Texturas.material("piso_ceramica", Color(0.55, 0.32, 0.25))
		B.box(ref, Vector3(larg * 0.75, 0.18, 1.9), Vector3(-hw * 0.2, 0.09, hd + 0.95), piso)
		B.box(ref, Vector3(larg * 0.8, 0.12, 2.2), Vector3(-hw * 0.2, 2.75, hd + 1.0), Texturas.material("telha", Color(0.5, 0.24, 0.15)), Vector3(-8, 0, 0))
		for sx in [-0.55, 0.15]:
			B.box(ref, Vector3(0.18, 2.6, 0.18), Vector3(sx * larg, 1.4, hd + 1.8), reboco)
		B.box(ref, Vector3(1.4, 0.08, 0.4), Vector3(-hw * 0.6, 0.5, hd + 0.35), madeira)
		for sx in [-0.6, 0.6]:
			B.box(ref, Vector3(0.06, 0.4, 0.35), Vector3(-hw * 0.6 + sx, 0.3, hd + 0.35), madeira)
		if r.randf() < 0.5:
			# rede pendurada
			var rede := B.box(ref, Vector3(1.6, 0.05, 0.6), Vector3(-hw * 0.2, 1.3, hd + 1.45), B.mat(Color.from_hsv(r.randf(), 0.6, 0.6), 0.95))
			rede.rotation.z = 0.05
	# muro baixo com portão na frente
	var dz := hd + 3.2
	var cor_muro: Color = [Color(0.85, 0.82, 0.74), Color(0.75, 0.7, 0.6), Color(0.62, 0.55, 0.48)][r.randi() % 3]
	var mm := Texturas.material("reboco", cor_muro)
	var abertura := 1.2
	var porta_x := larg * 0.2
	for lado in [-1.0, 1.0]:
		var x0 := -hw - 0.5 if lado < 0 else porta_x + abertura * 0.5
		var x1 := porta_x - abertura * 0.5 if lado < 0 else hw + 0.5
		B.box(ref, Vector3(x1 - x0, 0.9, 0.18), Vector3((x0 + x1) * 0.5, 0.45, dz), mm)
		B.box(ref, Vector3(x1 - x0 + 0.04, 0.06, 0.24), Vector3((x0 + x1) * 0.5, 0.92, dz), Texturas.material("concreto", Color(0.6, 0.58, 0.55)))
	for sx in [-1.0, 1.0]:
		B.box(ref, Vector3(0.18, 0.9, dz - hd + 0.1), Vector3(sx * (hw + 0.5), 0.45, hd + (dz - hd) * 0.5), mm)
	var portao := Node3D.new()
	portao.position = Vector3(porta_x - abertura * 0.5, 0, dz)
	portao.rotation.y = r.randf_range(-1.6, 0.0)
	ref.add_child(portao)
	var ferro := B.mat(Color(0.2, 0.19, 0.18), 0.6, 0.7, "ferro_portao")
	for q in 7:
		B.box(portao, Vector3(0.03, 1.0, 0.03), Vector3(0.1 + q * 0.17, 0.55, 0), ferro)
	for q in 2:
		B.box(portao, Vector3(1.15, 0.04, 0.04), Vector3(0.6, 0.15 + q * 0.85, 0), ferro)
	# quintal: vasos, botijão, tanque, bicicleta, casinha de cachorro
	var vaso := B.mat(Color(0.6, 0.3, 0.18), 0.9, 0.0, "vaso_barro")
	var folha := B.mat(Color(0.18, 0.38, 0.15), 0.9, 0.0, "folha_vaso")
	for q in r.randi_range(2, 5):
		var vp := Vector3(r.randf_range(-hw, hw), 0, hd + r.randf_range(0.5, 2.6))
		if absf(vp.x - porta_x) < 1.0:
			continue
		B.cyl(ref, 0.2, 0.35, vp + Vector3(0, 0.17, 0), vaso, Vector3.ZERO, 8, 0.26)
		B.sphere(ref, 0.3, vp + Vector3(0, 0.55, 0), folha, Vector3(1, 0.8 + r.randf() * 0.6, 1), 6)
	var lado_s := -1.0 if r.randf() < 0.5 else 1.0
	if r.randf() < 0.7:
		B.cyl(ref, 0.18, 0.55, Vector3(lado_s * (hw + 0.3), 0.3, -hd + 1.0), B.mat(Color(0.75, 0.15, 0.1), 0.5, 0.4, "botijao"), Vector3.ZERO, 10)
	if r.randf() < 0.6:
		var tq := Vector3(-lado_s * (hw + 0.45), 0, -hd + 1.5)
		B.box(ref, Vector3(0.6, 0.85, 0.6), tq + Vector3(0, 0.42, 0), Texturas.material("concreto", Color(0.65, 0.63, 0.6)))
		B.box(ref, Vector3(0.62, 0.12, 0.62), tq + Vector3(0, 0.9, 0), Texturas.material("concreto", Color(0.6, 0.58, 0.55)))
	if r.randf() < 0.35:
		var bic := Node3D.new()
		bic.position = Vector3(hw - 0.3, 0, hd + 0.5)
		bic.rotation = Vector3(0, PI * 0.5, 0.08)
		ref.add_child(bic)
		var cor_b := B.mat(Color.from_hsv(r.randf(), 0.7, 0.55), 0.5, 0.5)
		for sz in [-0.5, 0.5]:
			B.cyl(bic, 0.33, 0.03, Vector3(0, 0.34, sz), B.mat(Color(0.08, 0.08, 0.08), 0.8), Vector3(0, 0, 90), 14)
		B.box(bic, Vector3(0.04, 0.04, 1.0), Vector3(0, 0.55, 0), cor_b, Vector3(-10, 0, 0))
		B.box(bic, Vector3(0.04, 0.5, 0.04), Vector3(0, 0.6, -0.15), cor_b, Vector3(15, 0, 0))
		B.box(bic, Vector3(0.45, 0.03, 0.03), Vector3(0, 0.95, 0.42), B.mat(Color(0.1, 0.1, 0.1), 0.6))
	if r.randf() < 0.3:
		var cc := Vector3(lado_s * (hw - 0.6), 0, -hd - 1.2)
		B.box(ref, Vector3(0.9, 0.7, 1.1), cc + Vector3(0, 0.35, 0), madeira)
		var tri := PackedVector2Array([Vector2(-0.6, 0.7), Vector2(0.6, 0.7), Vector2(0, 1.1)])
		var tt := B.extruded(ref, tri, 1.2, cc, B.mat(Color(0.5, 0.22, 0.14), 0.85, 0.0, "telha_casinha"))
		tt.rotation.y = PI * 0.5
		tt.position = cc
	return ref
