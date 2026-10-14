class_name Eventos
extends Node
## Eventos na estrada: escolhas difíceis que aparecem pelo caminho.
##  - saqueadores: bloqueio com pedágio (pagar, furar ou procurar desvio)
##  - carona: sobrevivente pedindo ajuda (pode ser isca)
##  - acidente: ônibus tombado com pedidos de socorro (ajudar custa tempo e é arriscado)
##  - militar: comboio do exército abandonado, cheio de munição e de zumbis fardados
## Os eventos ficam em mundo.eventos_ativos (por chunk); o que foi resolvido fica em
## mundo.eventos_feitos (salvo no jogo) e não volta a acontecer.

const TIPOS := ["saqueadores", "carona", "acidente", "militar"]
const NOMES := ["Jonas", "Cida", "Beto", "Rita", "Zeca", "Lurdes", "Nando", "Graça", "Téo", "Dalva", "Miro", "Socorro"]

var main: Node
var _atual := {}        # evento com painel aberto
var _t_checar := 0.0

# ------------------------------------------------------------ geração (chamada pelo WorldGen)
static func construir(m: WorldGen, n: Node3D, z0: float, k: int) -> void:
	var r := m._rng_chunk(k, 77)
	var tipo: String = TIPOS[r.randi() % TIPOS.size()]
	tipo = m.eventos_tipo.get(k, tipo)
	var z := z0 + 32.0
	var feito: Dictionary = m.eventos_feitos.get(k, {})
	var d := m.direcao(z)
	var rot := atan2(d.x, d.z)
	var raiz := Node3D.new()
	raiz.name = "Evento_%d" % k
	n.add_child(raiz)
	var e := {"k": k, "tipo": tipo, "z": z, "pos": m.ponto_estrada(z, 0.0), "no": raiz, "resolvido": not feito.is_empty()}
	match tipo:
		"saqueadores":
			_saqueadores(m, raiz, z, rot, r, feito)
		"carona":
			_montar_carona(m, raiz, z, rot, r, feito)
			e.pos = m.ponto_estrada(z, 6.0)
		"acidente":
			_acidente(m, raiz, z, rot, r, feito)
		"militar":
			_militar(m, raiz, z, rot, r, k)
			e.resolvido = true   # não tem escolha: é só um lugar perigoso para saquear
	m.eventos_ativos[k] = e

static func _saqueadores(m: WorldGen, raiz: Node3D, z: float, rot: float, r: RandomNumberGenerator, feito: Dictionary) -> void:
	var lar := WorldGen.LARG_ESTRADA
	# placas de aviso antes do bloqueio
	for zz in [z - 120.0, z - 60.0]:
		var pl := m.ponto_estrada(zz, lar * 0.5 + 2.0)
		pl.y = m.elevacao(zz) + 1.8
		Lugares._placa(raiz, pl, rot + PI, "PEDÁGIO\nPARE O CARRO", Color(0.85, 0.2, 0.15))
	var sem := r.randi()
	_bloqueio(m, raiz, z, rot, sem, feito.get("resultado", "") in ["pagou", "furou"])

## Monta o bloqueio (fechado, com saqueadores) ou aberto (carros empurrados para o acostamento).
static func _bloqueio(m: WorldGen, raiz: Node3D, z: float, rot: float, sem: int, aberto: bool) -> void:
	var lar := WorldGen.LARG_ESTRADA
	var r := RandomNumberGenerator.new()
	r.seed = sem
	raiz.set_meta("bloqueio", [z, rot, sem])
	var bloco := Node3D.new()
	bloco.name = "Bloqueio"
	bloco.set_meta("nao_mesclar", true)   # precisa sumir inteiro quando o caminho abre
	var c := m.ponto_estrada(z, 0.0)
	c.y = m.elevacao(z)
	bloco.position = c
	bloco.rotation.y = rot
	raiz.add_child(bloco)
	var rc1 := RandomNumberGenerator.new()
	rc1.seed = r.randi()
	var rc2 := RandomNumberGenerator.new()
	rc2.seed = r.randi()
	if aberto:
		m.carro_abandonado(bloco, Vector3(-(lar * 0.5 + 2.6), 0.02, -1.5), PI * 0.5 - 0.35, rc1)
		m.carro_abandonado(bloco, Vector3(lar * 0.5 + 2.6, 0.02, 2.0), PI * 0.5 + 0.3, rc2)
		var saco_a := B.mat(Color(0.6, 0.55, 0.4), 0.95, 0.0, "saco_areia")
		for i in 3:
			B.box(bloco, Vector3(0.9, 0.38, 0.5), Vector3(-(lar * 0.5 + 0.8), 0.2, -3.5 + i * 1.0), saco_a, Vector3(0, 90, 0))
		var preto_a := B.mat(Color(0.05, 0.05, 0.05), 0.9)
		B.cyl(bloco, 0.42, 0.22, Vector3(lar * 0.5 + 0.9, 0.12, -1.8), preto_a, Vector3.ZERO, 12)
		return
	m.carro_abandonado(bloco, Vector3(-2.3, 0.02, -0.8), PI * 0.5 - 0.15, rc1)
	m.carro_abandonado(bloco, Vector3(2.3, 0.02, 0.8), PI * 0.5 + 0.15, rc2)
	var saco := B.mat(Color(0.6, 0.55, 0.4), 0.95, 0.0, "saco_areia")
	for i in 6:
		B.box(bloco, Vector3(0.9, 0.38, 0.5), Vector3(-2.6 + i * 1.05, 0.2, -3.0), saco)
	# pneus queimando
	var preto := B.mat(Color(0.05, 0.05, 0.05), 0.9)
	for s in [-1.0, 1.0]:
		var pp := Vector3(s * (lar * 0.5 - 0.6), 0, -1.8)
		for q in 3:
			B.cyl(bloco, 0.42, 0.22, pp + Vector3(0, 0.12 + q * 0.22, 0), preto, Vector3.ZERO, 12)
		B.sphere(bloco, 0.5, pp + Vector3(0, 0.95, 0), B.emissive(Color(1.0, 0.45, 0.1), 3.0), Vector3(1, 1.4, 1), 8)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.5, 0.2)
		l.light_energy = 1.6
		l.omni_range = 9.0
		l.position = pp + Vector3(0, 1.5, 0)
		l.set_meta("nao_mesclar", true)
		bloco.add_child(l)
	# faixa de madeira com PEDÁGIO pintado, virada para quem chega
	var tabua := B.mat(Color(0.32, 0.24, 0.16), 0.95, 0.0, "poste_madeira")
	for s in [-1.0, 1.0]:
		B.box(bloco, Vector3(0.12, 2.9, 0.12), Vector3(s * 1.5, 1.45, -3.3), tabua)
	B.box(bloco, Vector3(3.4, 0.75, 0.06), Vector3(0, 2.55, -3.25), tabua)
	Lugares._placa(bloco, Vector3(0, 2.55, -3.33), PI, "PEDÁGIO", Color(0.92, 0.88, 0.8))
	# os saqueadores
	for i in 3:
		var h := Humanoid.new()
		h.semente = r.randi()
		h.visual = "civil"
		h.feminino = r.randf() < 0.3
		h.arma = ["rifle", "espingarda", "pistola"][i]
		h.anim_parado = "Pistol_Idle" if i != 1 else "Idle_FoldArms"
		h.com_bone = r.randf() < 0.6
		h.position = Vector3(-2.5 + i * 2.5, 0, -4.2 + r.randf_range(-0.4, 0.4))
		h.rotation.y = r.randf_range(-0.3, 0.3)
		h.set_meta("nao_mesclar", true)
		bloco.add_child(h)

static func _montar_carona(m: WorldGen, raiz: Node3D, z: float, rot: float, r: RandomNumberGenerator, feito: Dictionary) -> void:
	if not feito.is_empty():
		return
	var p := m.ponto_estrada(z, WorldGen.LARG_ESTRADA * 0.5 + 0.6)
	p.y = m.elevacao(z) + 0.15
	var h := Humanoid.new()
	h.semente = r.randi()
	h.feminino = r.randf() < 0.45
	h.com_mochila = true
	h.anim_parado = "Idle_Talking"
	h.position = p
	h.rotation.y = rot + PI * 0.5
	h.set_meta("nao_mesclar", true)
	raiz.add_child(h)
	var placa := Node3D.new()
	placa.position = p
	placa.rotation.y = rot + PI
	raiz.add_child(placa)
	B.box(placa, Vector3(0.06, 1.5, 0.06), Vector3(0.7, 0.75, 0.6), B.mat(Color(0.35, 0.25, 0.15), 0.9))
	B.box(placa, Vector3(0.9, 0.55, 0.03), Vector3(0.7, 1.45, 0.6), B.mat(Color(0.75, 0.68, 0.5), 0.95))
	Lugares._placa(placa, Vector3(0.7, 1.45, 0.62), 0.0, "AJUDA", Color(0.1, 0.08, 0.06))
	var bolsa := B.mat(Color(0.3, 0.25, 0.2), 0.95)
	B.box(placa, Vector3(0.5, 0.35, 0.3), Vector3(-0.6, 0.18, 0.2), bolsa)

static func _acidente(m: WorldGen, raiz: Node3D, z: float, rot: float, r: RandomNumberGenerator, feito: Dictionary) -> void:
	var c := m.ponto_estrada(z, 2.0)
	c.y = m.elevacao(z) + 1.25
	var bus := Node3D.new()
	bus.name = "Onibus"
	bus.position = c
	# deitado sobre o lado esquerdo: o teto aponta para o meio da estrada, as rodas para o mato
	bus.rotation = Vector3(0, rot + 0.3, PI * 0.5)
	raiz.add_child(bus)
	var lata := B.pintura(Color(0.78, 0.62, 0.14), 0.3)
	var faixa := B.mat(Color(0.12, 0.12, 0.12), 0.7)
	var vid := B.mat(Color(0.1, 0.12, 0.14), 0.15, 0.4)
	var chassi := B.mat(Color(0.08, 0.08, 0.08), 0.9)
	B.box(bus, Vector3(2.5, 2.7, 11.0), Vector3.ZERO, lata)
	B.box(bus, Vector3(2.54, 0.18, 11.02), Vector3(0, -0.5, 0), faixa)
	for s in [-1.0, 1.0]:
		for i in 6:
			B.box(bus, Vector3(0.04, 0.85, 1.45), Vector3(s * 1.26, 0.6, -3.9 + i * 1.6), vid)
	B.box(bus, Vector3(2.2, 1.1, 0.04), Vector3(0, 0.5, 5.51), vid)        # para-brisa
	B.box(bus, Vector3(2.2, 0.7, 0.04), Vector3(0, 0.75, -5.51), vid)      # vidro traseiro
	B.box(bus, Vector3(2.3, 0.3, 10.4), Vector3(0, -1.45, 0), chassi)
	for zz in [-3.6, 3.6]:
		for s in [-1.0, 1.0]:
			var w := B.wheel(bus, Vector3(s * 0.95, -1.55, zz), 0.55, 0.35)
			w.rotation_degrees.z = 90
	# malas espalhadas
	var cores_mala := [Color(0.25, 0.12, 0.1), Color(0.12, 0.15, 0.25), Color(0.2, 0.2, 0.18), Color(0.4, 0.3, 0.15)]
	for i in 7:
		var q := m.ponto_estrada(z + r.randf_range(-7, 7), r.randf_range(-3.5, -0.5))
		q.y = m.elevacao(z) + 0.18
		B.box(raiz, Vector3(0.55, 0.35, 0.75), q, B.mat(cores_mala[i % 4], 0.85), Vector3(0, r.randf() * 180, r.randf_range(-8, 8)))
	var vidro := B.mat(Color(0.6, 0.65, 0.7), 0.2, 0.3)
	for i in 14:
		B.box(raiz, Vector3(r.randf_range(0.05, 0.2), 0.01, r.randf_range(0.05, 0.2)), m.ponto_estrada(z + r.randf_range(-6, 6), r.randf_range(-3, 5)) + Vector3(0, 0.0, 0), vidro)
	# malas e corpos cobertos
	var lona := B.mat(Color(0.45, 0.48, 0.5), 0.95)
	for i in 3:
		var q := m.ponto_estrada(z + r.randf_range(-7, 7), r.randf_range(-4.5, -2.0))
		q.y = m.elevacao(z) + 0.12
		B.box(raiz, Vector3(0.6, 0.22, 1.8), q, lona, Vector3(0, r.randf() * 180, 0))
	if feito.is_empty():
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.85, 0.5)
		l.light_energy = 0.8
		l.omni_range = 6.0
		l.position = c + Vector3(0, 1.0, 0)
		l.set_meta("nao_mesclar", true)
		raiz.add_child(l)

static func _militar(m: WorldGen, raiz: Node3D, z: float, rot: float, r: RandomNumberGenerator, k: int) -> void:
	var verde := B.pintura(Color(0.26, 0.3, 0.2), 0.4)
	var lona := B.mat(Color(0.32, 0.34, 0.24), 0.95)
	for i in 2:
		var lado := -1.0 if i == 0 else 1.0
		var c := m.ponto_estrada(z + i * 12.0, lado * 3.0)
		c.y = m.elevacao(z)
		var cam := Node3D.new()
		cam.position = c
		cam.rotation.y = rot + r.randf_range(-0.25, 0.25)
		raiz.add_child(cam)
		B.box(cam, Vector3(2.4, 1.6, 2.2), Vector3(0, 1.5, 3.0), verde)
		B.box(cam, Vector3(2.4, 0.3, 6.0), Vector3(0, 0.9, -1.0), verde)
		var tl := B.box(cam, Vector3(2.5, 2.0, 5.6), Vector3(0, 2.1, -1.0), lona)
		for zz in [2.8, -0.5, -2.8]:
			for s in [-1.0, 1.0]:
				var w := B.wheel(cam, Vector3(s * 1.15, 0.55, zz), 0.55, 0.35)
				w.rotation_degrees.y = 90
		Lugares._vasculhavel(cam, Vector3(0, 1.2, -3.8), "Carga militar", "militar", 1.0, m, "evento:%d:carga%d" % [k, i])
	# cerca de arame e cones
	# arame farpado em espiral (anéis finos) e cavaletes
	var arame := B.mat(Color(0.22, 0.22, 0.21), 0.6, 0.7)
	var cav := B.mat(Color(0.3, 0.22, 0.14), 0.95)
	for i in 34:
		var q := m.ponto_estrada(z - 8.0, -6.6 + i * 0.4)
		q.y = m.elevacao(z) + 0.38
		B.cyl(raiz, 0.36, 0.025, q, arame, Vector3(0, rad_to_deg(rot) + 90.0, 90.0 + (i % 2) * 14.0), 10)
	for s in [-1.0, 1.0]:
		var q := m.ponto_estrada(z - 10.0, s * 4.5)
		var pl := Node3D.new()
		pl.position = q
		pl.rotation.y = rot + PI
		raiz.add_child(pl)
		B.box(pl, Vector3(0.1, 2.4, 0.1), Vector3(-1.3, 1.2, 0), cav)
		B.box(pl, Vector3(0.1, 2.4, 0.1), Vector3(1.3, 1.2, 0), cav)
		B.box(pl, Vector3(3.0, 1.0, 0.05), Vector3(0, 1.9, 0), B.mat(Color(0.85, 0.78, 0.2), 0.8))
		Lugares._placa(pl, Vector3(0, 1.9, 0.04), 0.0, "ÁREA MILITAR\nQUARENTENA", Color(0.08, 0.07, 0.05))
	# zumbis fardados
	for i in r.randi_range(6, 10):
		var q := m.ponto_estrada(z + r.randf_range(-6, 18), r.randf_range(-8, 8))
		q.y = maxf(m.altura(q.x, q.z), m.elevacao(z)) + 0.05
		var zb := m.criar_zumbi(raiz, q, r.randf() * TAU, r.randi(), "brutamonte" if i == 0 else "comum")
		zb.cores = {"roupa": Color(0.55, 0.62, 0.42)}

# ------------------------------------------------------------ em jogo
func atualizar(dt: float) -> void:
	_t_checar -= dt
	if not _atual.is_empty():
		if main.comboio.dirigindo:
			main.comboio.velocidade = 0.0
		if not main.painel.visible:
			# fechou o painel sem escolher (Esc)
			if _atual.tipo == "saqueadores":
				main._abrir_painel(_painel)    # bloqueio não se ignora
			else:
				_fim("ignorou", "Você seguiu sem parar.")
		return
	if _t_checar > 0.0 or main.painel.visible:
		return
	_t_checar = 0.25
	var foco: Vector3 = main.comboio.pos if main.comboio.dirigindo else main.jogador.global_position
	for k in main.mundo.eventos_ativos:
		var e: Dictionary = main.mundo.eventos_ativos[k]
		if e.resolvido or not is_instance_valid(e.no):
			continue
		var dz: float = float(e.z) - foco.z
		var dist := Vector2(foco.x - e.pos.x, foco.z - e.pos.z).length()
		var gatilho := 40.0 if e.tipo == "saqueadores" else 22.0
		# só dispara vindo de trás (o comboio sempre vai para +z)
		if dist < gatilho and dz > -6.0:
			_disparar(e)
			return

func _disparar(e: Dictionary) -> void:
	_atual = e
	var c: Comboio = main.comboio
	if c.dirigindo:
		c.velocidade = 0.0
	Som.tela("clique_ui", -4.0)
	main._abrir_painel(_painel)

func _fim(chave_resultado: String, texto: String) -> String:
	var e := _atual
	e.resolvido = true
	main.mundo.eventos_feitos[e.k] = {"tipo": e.tipo, "resultado": chave_resultado}
	_atual = {}
	main.call_deferred("_fechar_janela")
	main.hud.relatorio = texto
	main.hud.relatorio_titulo = {"saqueadores": "Pedágio", "carona": "Carona", "acidente": "Acidente"}.get(e.tipo, "")
	main.hud.relatorio_t = 7.0
	if chave_resultado in ["pagou", "furou"] and is_instance_valid(e.no):
		var b: Node = e.no.get_node_or_null("Bloqueio")
		if b:
			# tira os saqueadores e abre caminho: os carros vão para o acostamento
			b.name = "Bloqueio_velho"
			b.queue_free()
			var info: Array = e.no.get_meta("bloqueio", [e.z, 0.0, 0])
			_bloqueio(main.mundo, e.no, info[0], info[1], info[2], true)
	elif e.tipo in ["carona", "acidente"] and is_instance_valid(e.no):
		for h in e.no.get_children():
			if h is Humanoid or h is OmniLight3D:
				h.queue_free()
	return ""

func _painel() -> Dictionary:
	var e := _atual
	if e.is_empty():
		return {"titulo": "", "linhas": [], "botoes": []}
	var est: Dictionary = main.estoque
	match e.tipo:
		"saqueadores":
			var comida_paga := maxi(3, int(est.get("comida", 0) * 0.3))
			var tem_galao: bool = est.get("galoes_diesel", 0) > 0
			var para: int = main.picape.nivel("parachoque") if main.picape.config.has("parachoque") else 0
			var vigias: int = main.base.presentes("vigia").size()
			return {"titulo": "BLOQUEIO NA ESTRADA", "subtitulo": "Carros atravessados, pneus queimando e três armas apontadas para o seu para-brisa.",
				"linhas": ["\"Pedágio, amigo. %d de comida%s e cada um segue seu rumo.\"" % [comida_paga, " e um galão de diesel" if tem_galao else ""],
					["Comida: %d · Galões: %d · Para-choque nível %d · Vigias no comboio: %d" % [est.get("comida", 0), est.get("galoes_diesel", 0), para, vigias], Color(0.7, 0.7, 0.68)]],
				"botoes": [
					["Pagar o pedágio", func(): return _pagar(comida_paga, tem_galao), est.get("comida", 0) >= comida_paga],
					["Furar o bloqueio (acelerar)", func(): return _furar(para, vigias), true],
					["Dar meia-volta e achar um desvio (3 h, 10 L)", func(): return _desvio(), main.comboio.diesel > 10.0],
					["Atirar primeiro", func(): return _atirar(vigias), est.get("municao_pistola", 0) + est.get("cartucho", 0) + est.get("municao_rifle", 0) >= 6],
				]}
		"carona":
			return {"titulo": "ALGUÉM PEDINDO CARONA", "subtitulo": "Uma pessoa acena com uma placa escrita AJUDA. Parece sozinha. Parece.",
				"linhas": ["\"Por favor! Tô a pé faz três dias. Eu trabalho, eu ajudo, só não me deixa aqui.\""],
				"botoes": [
					["Dar carona (vira recruta)", func(): return _carona(), true],
					["Dar comida e água, mas seguir", func(): return _dar_comida(), est.get("comida", 0) > 0 and est.get("agua", 0) > 0],
					["Seguir viagem", func(): return _fim("ignorou", "Você não parou. Pelo retrovisor, a pessoa ficou cada vez menor."), true],
				]}
		"acidente":
			return {"titulo": "ÔNIBUS TOMBADO", "subtitulo": "Lá de dentro vêm batidas no vidro. Pode ser gente presa. Pode não ser.",
				"linhas": ["Procurar sobreviventes leva tempo e faz barulho."],
				"botoes": [
					["Procurar sobreviventes (1 h)", func(): return _socorrer(), true],
					["Saquear as malas e sair (20 min)", func(): return _malas(), true],
					["Seguir viagem", func(): return _fim("ignorou", "Você deixou o ônibus para trás. As batidas no vidro não pararam."), true],
				]}
	return {"titulo": "", "linhas": [], "botoes": []}

# ------------------------------------------------------------ resultados
func _pagar(comida: int, galao: bool) -> String:
	main.estoque.comida -= comida
	if galao:
		main.estoque.galoes_diesel -= 1
	return _fim("pagou", "Você pagou %d de comida%s. Eles afastaram os carros e acenaram.\n\"Boa viagem. A estrada é longa.\"" % [comida, " e um galão" if galao else ""])

func _furar(para: int, vigias: int) -> String:
	var r := randf()
	var p: Pickup = main.picape
	var dano := 0.45 - para * 0.1
	if p.config.has("parachoque"):
		p.config.parachoque.condicao = maxf(0.0, p.config.parachoque.condicao - dano)
	else:
		dano += 0.15
		p.condicao = maxf(0.1, p.condicao - 0.12)
	p.condicao = maxf(0.1, p.condicao - 0.08)
	p.reconstruir()
	var linhas := ["Você meteu o pé. O para-choque bateu nos carros (−%d%%)." % int(dano * 100.0)]
	Som.tela("kenney/impact", 2.0)
	Som.em("tiro_rifle", main.comboio.pos, 0.0, 0.05, 3.0)
	if r > 0.45 + vigias * 0.12:
		var f := randf_range(0.12, 0.3)
		main.jogador.vida = maxf(0.05, main.jogador.vida - f)
		linhas.append("Um tiro atravessou a cabine: você foi atingido (−%d%% de vida)." % int(f * 100.0))
	else:
		linhas.append("As balas acertaram a lataria. Ninguém se feriu.")
	if randf() < 0.4:
		var alvo: String = ["frente", "janelas", "traseira"][randi() % 3]
		main.trailer.danificar(alvo, 0.2)
		linhas.append("O trailer levou tiros.")
	main.comboio.velocidade = 12.0
	return _fim("furou", "\n".join(linhas))

func _desvio() -> String:
	main.comboio.diesel -= 10.0
	main._passar_tempo(3.0)
	var z: float = float(_atual.z) + 30.0
	main.comboio.posicionar(z, -0.5, 0.0)
	main.mundo.atualizar(main.comboio.pos)
	_atual.resolvido = true
	var e := _atual
	main.mundo.eventos_feitos[e.k] = {"tipo": e.tipo, "resultado": "desviou"}
	_atual = {}
	main.call_deferred("_fechar_janela")
	main.hud.relatorio = "Três horas de estrada de chão e mato alto depois, você saiu na rodovia do outro lado do bloqueio."
	main.hud.relatorio_titulo = "Desvio"
	main.hud.relatorio_t = 7.0
	return ""

func _atirar(vigias: int) -> String:
	var gasto := 6
	for m in ["municao_rifle", "cartucho", "municao_pistola"]:
		var tira := mini(gasto, main.estoque.get(m, 0))
		main.estoque[m] = main.estoque.get(m, 0) - tira
		gasto -= tira
	Som.em("tiro_espingarda", main.comboio.pos, 0.0, 0.05, 4.0)
	var chance := 0.35 + vigias * 0.15
	var linhas := ["Você abriu fogo primeiro."]
	if randf() < chance:
		var ganho := {"comida": randi_range(3, 8), "municao_pistola": randi_range(4, 12), "galoes_diesel": randi_range(1, 2), "sucata": randi_range(5, 12)}
		for k in ganho:
			main.adicionar(k, ganho[k])
		linhas.append("Os saqueadores fugiram e largaram tudo: %d comida, %d balas, %d galão(ões), %d sucata." % [ganho.comida, ganho.municao_pistola, ganho.galoes_diesel, ganho.sucata])
	else:
		var f := randf_range(0.2, 0.4)
		main.jogador.vida = maxf(0.05, main.jogador.vida - f)
		var vivos: Array = main.base.lista.filter(func(x): return x.vida > 0.0)
		if not vivos.is_empty() and randf() < 0.5:
			var v: Dictionary = vivos[randi() % vivos.size()]
			v.vida = maxf(0.0, v.vida - 0.5)
			linhas.append("%s foi balead%s." % [v.nome, _o(v.nome)])
		linhas.append("Troca de tiros feia. Você foi ferido (−%d%%), mas eles recuaram." % int(f * 100.0))
	main.ruido(main.comboio.pos, 80.0, "tiro")
	return _fim("furou", "\n".join(linhas))

func _carona() -> String:
	var nome: String = NOMES[randi() % NOMES.size()]
	if randf() < 0.22:
		var leva := {"sucata": int(main.estoque.get("sucata", 0) * 0.3), "pecas": int(main.estoque.get("pecas", 0) * 0.3), "comida": int(main.estoque.get("comida", 0) * 0.3)}
		for k in leva:
			main.estoque[k] = main.estoque.get(k, 0) - leva[k]
		return _fim("isca", "Era isca. Enquanto %s distraía você, dois comparsas limparam a caçamba:\n−%d sucata, −%d peças, −%d comida." % [nome, leva.sucata, leva.pecas, leva.comida])
	var funcao: String = ["batedor", "agricultor", "mecanico", "medico", "vigia"][randi() % 5]
	main.base.lista.append(Recrutas.novo(nome, funcao, randi()))
	main.base.distribuir_camas()
	return _fim("recruta", "%s subiu na caçamba. Diz que é %s.\n\"Não vou te decepcionar.\"" % [nome, {"batedor": "batedor", "agricultor": "agricultor", "mecanico": "mecânico", "medico": "médico", "vigia": "atirador"}[funcao]])

func _dar_comida() -> String:
	main.estoque.comida -= 1
	main.estoque.agua -= 1
	var dica: String = main.ouvir_radio() if main.has_method("ouvir_radio") else ""
	return _fim("ajudou", "Você deixou comida e água. Em troca, ouviu uma dica:\n%s" % dica)

func _socorrer() -> String:
	main._passar_tempo(1.0)
	main.ruido(main.comboio.pos, 45.0)
	if randf() < 0.55:
		var nome: String = NOMES[randi() % NOMES.size()]
		main.base.lista.append(Recrutas.novo(nome, ["medico", "mecanico", "agricultor"][randi() % 3], randi()))
		main.base.lista[-1].vida = 0.5
		main.base.distribuir_camas()
		main.adicionar("remedio", randi_range(1, 2))
		main.adicionar("bandagem", randi_range(1, 3))
		return _fim("salvou", "Você quebrou o vidro e tirou %s lá de dentro: machucad%s, mas viv%s. Ainda achou uma maleta de primeiros socorros." % [nome, _o(nome), _o(nome)])
	# eram zumbis
	var r := RandomNumberGenerator.new()
	r.randomize()
	var base: Vector3 = _atual.pos
	for i in 6:
		var p := base + Vector3(r.randf_range(-5, 5), 0, r.randf_range(-5, 5))
		p.y = main.mundo.altura(p.x, p.z) + 0.05
		main.mundo.criar_zumbi(main.mundo, p, r.randf() * TAU, r.randi())
	return _fim("zumbis", "Quando o vidro cedeu, não saiu gente. Saíram eles.\nSeis zumbis, e estão vindo.")

func _malas() -> String:
	main._passar_tempo(0.33)
	var ganho := {"comida": randi_range(1, 4), "agua": randi_range(1, 3), "tecido": randi_range(1, 3), "remedio": randi_range(0, 1)}
	for k in ganho:
		if ganho[k] > 0:
			main.adicionar(k, ganho[k])
	return _fim("saqueou", "Nas malas: %d comida, %d água, %d tecido%s." % [ganho.comida, ganho.agua, ganho.tecido, ", um remédio" if ganho.remedio > 0 else ""])

static func _o(nome: String) -> String:
	return "a" if nome.ends_with("a") or nome in ["Lurdes", "Socorro"] else "o"
