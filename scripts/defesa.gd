class_name Defesa
extends Node
## A horda migratória e a defesa dos assentamentos: escolha de ficar, construção,
## postos, ondas que crescem, vitória e derrota. Estado dos assentamentos por id.

const CUSTOS := {
	"chapas": {"nome": "Trocar a paliçada por chapas de metal", "itens": {"sucata": 60, "pecas": 10}, "horas": 6.0,
		"desc": "Muro aguenta 2,6× mais."},
	"portao": {"nome": "Reforçar o portão", "itens": {"sucata": 20, "pecas": 6}, "horas": 2.0,
		"desc": "Portão com chapas e trancas."},
	"torre": {"nome": "Construir torre de vigia", "itens": {"sucata": 25, "pecas": 4}, "horas": 3.0,
		"desc": "Vigias atiram de cima, mais longe."},
	"holofote": {"nome": "Holofote numa torre", "itens": {"pecas": 6, "galoes_diesel": 1}, "horas": 2.0,
		"desc": "À noite, sem luz, os tiros erram muito."},
	"armadilha": {"nome": "Estacas num setor do muro", "itens": {"sucata": 12}, "horas": 1.5,
		"desc": "Ferem e seguram quem passa (12 cargas)."},
}
const NOMES_SETOR := ["do portão", "da esquerda", "dos fundos", "da direita"]

var main: Node
var estado := {}               # id -> Dictionary
var z_horda := -6000.0         # onde está a horda migratória (coordenada z da estrada)
var defendidos := 0
var ativo := ""                # assentamento em que o jogador decidiu ficar
var onda := {}                 # onda em andamento
var nos: Array = []            # defensores em cena (recrutas e moradores)
var _t := 0.0
var _avisou_horda := 0.0
var _reg_onda: Array[String] = []

# ------------------------------------------------------------ consultas
func em_onda(id := "") -> bool:
	return not onda.is_empty() and (id == "" or onda.id == id)

func em_combate() -> bool:
	return not onda.is_empty()

func velocidade_horda() -> float:
	## metros por hora de jogo
	# a horda engrossa e acelera conforme o comboio se afasta do começo
	var cl = main.get("clima")
	var f: float = cl.fator_horda() if cl else 1.0
	return (4000.0 + 900.0 * main.mundo.nivel_ameaca + 45.0 * maxf(0.0, main._foco().z / 1000.0)) / 24.0 * f

func horas_ate(z: float) -> float:
	return maxf(0.0, (z - 250.0 - z_horda) / velocidade_horda())

func km_horda(z: float) -> float:
	return (z - z_horda) / 1000.0

func no_de(id: String) -> Assentamento:
	var v: Variant = main.mundo.lugares_ativos.get(id, null)
	if v == null or not is_instance_valid(v):
		return null
	for c in (v as Node).get_children():
		if c is Assentamento:
			return c
	return null

## Estado do assentamento (cria na primeira vez).
func obter(id: String, a: Assentamento = null) -> Dictionary:
	if estado.has(id):
		return estado[id]
	var l := {}
	for ll in main.mundo.lugares_da_regiao(int(id.split(":")[0])):
		if ll.id == id:
			l = ll
	var r := RandomNumberGenerator.new()
	r.seed = hash([main.mundo.semente, id, "assent"])
	var e := {
		"id": id, "nome": l.get("nome", "Assentamento"), "pos": l.get("pos", a.global_position if a else Vector3.ZERO),
		"nivel": 1, "chapas": false, "portao": false,
		"torres": [true, r.randf() < 0.5, false, false], "holofotes": [false, false, false, false],
		"armadilhas": [0, 0, 0, 0], "muro": [],
		"estoque": {"sucata": r.randi_range(25, 45), "pecas": r.randi_range(6, 12)},
		"fase": "livre", "ondas": 0, "defendido": false, "prox_onda_h": -1.0,
		"vigias": 1 + r.randi_range(0, 1), "armados": 2 + r.randi_range(0, 1), "moradores": 9,
		"lider": ["Dona Rosa", "Seu Arlindo", "Capitão Vidal", "Irmã Lúcia", "Comandante Neves"][r.randi() % 5],
		"postos": {}, "bonus_portao": 0.0,
	}
	if z_horda > float(e.pos.z) + 100.0:
		e.fase = "caido"
	for i in Assentamento.N:
		e.muro.append(Assentamento.HP_MADEIRA * (1.6 if i == 0 else 1.0))
	if e.fase == "caido":
		for i in Assentamento.N:
			if r.randf() < 0.45:
				e.muro[i] = 0.0
	estado[id] = e
	return e

func nivel(e: Dictionary) -> int:
	var pts := 0
	pts += 2 if e.chapas else 0
	pts += 1 if e.portao else 0
	for k in 4:
		pts += (1 if e.torres[k] else 0) + (1 if e.holofotes[k] else 0)
		pts += 1 if e.armadilhas[k] > 0 else 0
	return 1 + pts / 3

# ------------------------------------------------------------ tempo e horda
func passar(h: float) -> void:
	if main.capturando and not get_meta("simular", false):
		return
	z_horda += velocidade_horda() * h
	var foco: Vector3 = main._foco()
	for id in estado:
		var e: Dictionary = estado[id]
		var dentro := foco.distance_to(e.pos) < 75.0
		match e.fase:
			"livre", "preparando":
				if z_horda >= float(e.pos.z) - 250.0:
					if id == ativo and dentro and onda.is_empty():
						iniciar_onda(id)
					elif onda.is_empty() or onda.id != id:
						_cair_sozinho(e)
			"entre_ondas":
				if id == ativo:
					e.prox_onda_h -= h
					if e.prox_onda_h <= 0.0 and onda.is_empty():
						if dentro:
							iniciar_onda(id)
						else:
							e.fase = "aliado"
							ativo = ""
				if id == ativo and not dentro and foco.distance_to(e.pos) > 160.0:
					e.fase = "aliado"
					ativo = ""
					main.hud.aviso("%s fica para trás, agora como aliado." % e.nome)
	# a horda alcança o comboio na estrada
	if onda.is_empty() and foco.z - z_horda < 120.0:
		var l: Dictionary = main.mundo.lugar_em(foco)
		if l.is_empty() or l.tipo != "assentamento":
			_horda_alcancou()
	# avisos conforme ela chega perto
	var km := (foco.z - z_horda) / 1000.0
	if km < 2.0 and _avisou_horda != 2.0:
		_avisou_horda = 2.0
		main.hud.aviso("A horda está a menos de 2 km. Dá para ouvir.")
	elif km < 5.0 and km >= 2.0 and _avisou_horda != 5.0:
		_avisou_horda = 5.0
		main.hud.aviso("A horda está a menos de 5 km atrás do comboio.")
	elif km > 6.0:
		_avisou_horda = 0.0

func _cair_sozinho(e: Dictionary) -> void:
	# sem o jogador, só resiste quem se preparou muito
	var forca: float = nivel(e) * 0.12 + (0.25 if e.defendido else 0.0)
	var r := RandomNumberGenerator.new()
	r.seed = hash([e.id, e.ondas, "sozinho"])
	if r.randf() < forca:
		e.ondas += 1
		e.fase = "aliado" if e.defendido else "livre"
		main.registrar("%s aguentou a horda sozinho." % e.nome)
		return
	e.fase = "caido"
	for i in Assentamento.N:
		if r.randf() < 0.5:
			e.muro[i] = 0.0
	if e.id == ativo:
		ativo = ""
	main.registrar("Pelo rádio: %s caiu para a horda." % e.nome)
	main.hud.aviso("Pelo rádio: %s caiu para a horda." % e.nome)
	var a := no_de(e.id)
	if a:
		a.redesenhar()

func _horda_alcancou() -> void:
	var n := 10 + int(main.mundo.nivel_ameaca) * 3
	var tr: Node3D = main.trailer
	var atras := Vector3(0, 0, -1)
	for i in n:
		var a := randf_range(-1.2, 1.2)
		var p := tr.global_position + (atras.rotated(Vector3.UP, a)) * randf_range(25.0, 40.0)
		p.y = main.mundo.altura(p.x, p.z)
		var z: Zumbi = main.mundo.criar_zumbi(main.mundo, p, 0.0, randi())
		z.estado = Zumbi.Estado.PERSEGUINDO
		z.alvo_pos = tr.global_position
	z_horda = main._foco().z - 2500.0
	main.hud.banner("A horda te alcançou", "%d zumbis em volta do comboio. Fuja ou lute." % n)

# ------------------------------------------------------------ escolha e construção
func ficar(id: String) -> String:
	var e := obter(id)
	ativo = id
	if e.fase == "livre":
		e.fase = "preparando"
	return "Você decidiu ficar. %s agradece; mãos à obra antes que a horda chegue." % e.lider

func partir(id: String) -> String:
	var e := obter(id)
	if ativo == id:
		ativo = ""
	if e.fase == "preparando":
		e.fase = "livre"
	elif e.fase == "entre_ondas":
		e.fase = "aliado"
	return "Você avisou que vai seguir viagem."

func custo(e: Dictionary, chave: String) -> Dictionary:
	return CUSTOS[chave].itens

func pode_pagar(e: Dictionary, itens: Dictionary) -> bool:
	for k in itens:
		if main.estoque.get(k, 0) + e.estoque.get(k, 0) < itens[k]:
			return false
	return true

func pagar(e: Dictionary, itens: Dictionary) -> void:
	for k in itens:
		var falta: int = itens[k]
		var do_lugar: int = mini(e.estoque.get(k, 0), falta)
		if do_lugar > 0:
			e.estoque[k] -= do_lugar
			falta -= do_lugar
		if falta > 0:
			main.estoque[k] -= falta

## Constrói uma melhoria; os moradores ajudam (leva menos tempo com mais gente).
func construir(id: String, chave: String, alvo := -1) -> String:
	var e := obter(id)
	var itens: Dictionary = CUSTOS[chave].itens
	if not pode_pagar(e, itens):
		return "Faltam materiais."
	var horas: float = CUSTOS[chave].horas * (0.7 if e.armados + e.vigias >= 5 else 1.0)
	horas *= 1.0 - 0.15 * mini(main.base.n("mecanico"), 2)
	pagar(e, itens)
	match chave:
		"chapas":
			e.chapas = true
			for i in Assentamento.N:
				e.muro[i] = (Assentamento.HP_CHAPAS if i else Assentamento.HP_CHAPAS * (2.6 if e.portao else 1.6))
		"portao":
			e.portao = true
			e.muro[0] = (Assentamento.HP_CHAPAS if e.chapas else Assentamento.HP_MADEIRA) * 2.6
		"torre":
			e.torres[alvo] = true
		"holofote":
			e.holofotes[alvo] = true
		"armadilha":
			e.armadilhas[alvo] += 12
	e.nivel = nivel(e)
	var a := no_de(id)
	if a:
		a.redesenhar()
	var aviso: String = main.trabalhar(horas)
	return "%s: pronto em %s.%s" % [CUSTOS[chave].nome, main._txt_horas(horas), (" " + aviso) if aviso != "" else ""]

func consertar(id: String) -> String:
	var e := obter(id)
	var a := no_de(id)
	if not a:
		return ""
	var falta := 0.0
	for i in Assentamento.N:
		falta += a.hp_max(i) - e.muro[i]
	if falta < 1.0:
		return "O muro está inteiro."
	var itens := {"sucata": int(ceil(falta / 14.0)), "pecas": int(ceil(falta / 120.0))}
	if not pode_pagar(e, itens):
		return "Faltam materiais para consertar o muro."
	pagar(e, itens)
	a.reparar_tudo()
	var horas := 1.0 + falta / 260.0
	var aviso: String = main.trabalhar(horas)
	return "Muro consertado (%s).%s" % [main._txt_horas(horas), (" " + aviso) if aviso != "" else ""]

func custo_conserto(id: String) -> Dictionary:
	var e := obter(id)
	var a := no_de(id)
	if not a:
		return {}
	var falta := 0.0
	for i in Assentamento.N:
		falta += a.hp_max(i) - e.muro[i]
	if falta < 1.0:
		return {}
	return {"sucata": int(ceil(falta / 14.0)), "pecas": int(ceil(falta / 120.0))}

## Espera até a horda (ou a próxima onda) chegar.
func esperar(id: String) -> String:
	var e := obter(id)
	var h = horas_ate(e.pos.z) if e.fase == "preparando" else e.prox_onda_h
	if h <= 0.05:
		return ""
	main.trabalhar(maxf(0.0, h) + 0.02)
	return ""

# ------------------------------------------------------------ postos
func posto_padrao(rc: Dictionary) -> String:
	match rc.funcao:
		"crianca", "idoso":
			return "centro"
		"vigia":
			return "torre"
		"mecanico":
			return "reparos"
		"medico":
			return "socorro"
	return "portao"

func opcoes_posto(rc: Dictionary) -> Array:
	match rc.funcao:
		"crianca":
			return ["centro"]
		"idoso":
			return ["centro", "socorro"]
		"vigia":
			return ["torre", "portao", "muro"]
		"mecanico":
			return ["reparos", "portao", "muro"]
		"medico":
			return ["socorro", "portao"]
	return ["portao", "muro", "centro"]

func posto_de(e: Dictionary, rc: Dictionary) -> String:
	return e.postos.get(rc.nome, posto_padrao(rc))

func trocar_posto(id: String, nome: String) -> void:
	var e := obter(id)
	for rc in main.base.lista:
		if rc.nome == nome:
			var op := opcoes_posto(rc)
			var i := op.find(posto_de(e, rc))
			e.postos[nome] = op[(i + 1) % op.size()]

const NOMES_POSTO := {"torre": "torre de vigia", "portao": "portão", "muro": "muro do lado da horda",
	"reparos": "reparos no muro", "socorro": "socorro (centro)", "centro": "guarda do centro"}

# ------------------------------------------------------------ ondas
func tamanho_onda(n: int) -> int:
	return mini(160, int(round((14.0 + 5.0 * main.mundo.nivel_ameaca) * pow(1.5, n - 1))))

func iniciar_onda(id: String) -> void:
	var e := obter(id)
	var a := no_de(id)
	if not a:
		return
	var n: int = e.ondas + 1
	var total := tamanho_onda(n)
	# de onde vem: de trás, pela estrada (onde está a horda)
	var atras_l := a.local_de(a.global_position + Vector3(0, 0, -50.0))
	var ang_base := atan2(atras_l.x, atras_l.z)
	# muralha de reboques: o comboio parado no portão reforça a entrada
	var bonus := 0.0
	var portao_g := a.global_de(Assentamento.ponto(0, Assentamento.R))
	for el in main.comboio.cadeia:
		if el.global_position.distance_to(portao_g) < 18.0:
			bonus += 90.0
	if main.picape.global_position.distance_to(portao_g) < 18.0:
		bonus += 60.0
	e.bonus_portao = bonus
	e.muro[0] = minf(a.hp_max(0), e.muro[0] + bonus)
	onda = {"id": id, "n": n, "total": total, "fila": total, "vivos": [], "abates": 0, "ang": ang_base,
		"t_spawn": 0.0, "resistencia": 1.0, "muro_ini": a.muro_medio(), "perdas": [], "t": 0.0}
	e.fase = "onda"
	_reg_onda.clear()
	if main._janela_aberta():
		main._fechar_janela()
	if main.dentro != null:
		main._sair_de_dentro()
	a.portao(false)
	main.base.limpar_cena()
	_criar_defensores(e, a)
	var lado = ["dos fundos", "da direita", "do portão", "da esquerda"][int(fposmod(ang_base + PI * 0.25 + PI, TAU) / (PI * 0.5)) % 4]
	main.hud.banner("Onda %d" % n, "%d zumbis vindo %s. Segurem o muro!" % [total, lado])

func _criar_defensores(e: Dictionary, a: Assentamento) -> void:
	limpar_defensores()
	var centro := a.global_de(Vector3(0, 0, 3.0))
	centro.y = main.mundo.altura(centro.x, centro.z)
	var torres_livres: Array = []
	for k in 4:
		if e.torres[k]:
			torres_livres.append(k)
	var lado_horda: float = onda.ang
	var cont_muro := 0
	var lista: Array = []
	for rc in main.base.presentes():
		lista.append([rc, posto_de(e, rc)])
	var r := RandomNumberGenerator.new()
	r.seed = hash([e.id, "def"])
	for k in e.vigias:
		var d := Recrutas.novo(["Zeca", "Bia", "Nando", "Cris", "Toninho", "Lu"][k % 6], "vigia", r.randi())
		d["morador"] = true
		lista.append([d, "torre"])
	for k in e.armados:
		var d2 := Recrutas.novo(["Mané", "Dora", "Juca", "Rita", "Gil", "Tânia", "Beto"][k % 7], ["agricultor", "batedor"][k % 2], r.randi())
		d2["morador"] = true
		lista.append([d2, "muro"])
	for par in lista:
		var rc: Dictionary = par[0]
		var p: String = par[1]
		var pos := centro
		var olhar := 0.0
		var fixo := false
		if p == "torre" and not torres_livres.is_empty():
			# a torre mais perto do lado da horda primeiro
			torres_livres.sort_custom(func(x, y): return absf(wrapf(Assentamento.ANG_TORRES[x] - lado_horda, -PI, PI)) < absf(wrapf(Assentamento.ANG_TORRES[y] - lado_horda, -PI, PI)))
			var k2: int = torres_livres.pop_front()
			pos = a.torre_pos(k2)
			olhar = a.global_rotation.y + Assentamento.ANG_TORRES[k2]
			fixo = true
		elif p == "torre" or p == "muro":
			var ang: float = lado_horda + (cont_muro - 2) * 0.32
			cont_muro += 1
			var l := Vector3(sin(ang), 0, cos(ang)) * (Assentamento.R - 2.5)
			pos = a.global_de(l)
			olhar = a.global_rotation.y + ang
		elif p == "portao" or p == "reparos":
			var l2 := Vector3(r.randf_range(-2.5, 2.5), 0, Assentamento.R - 3.0)
			pos = a.global_de(l2)
			olhar = a.global_rotation.y
		else:
			pos = centro + Vector3(r.randf_range(-1.5, 1.5), 0, r.randf_range(-1.5, 1.5))
		if not fixo:
			pos.y = main.mundo.altura(pos.x, pos.z)
		var no := Recruta.criar(rc)
		no.main = main
		main.add_child(no)
		no.global_position = pos
		no.rotation.y = olhar
		no.posto = pos
		no.olhar_posto = olhar
		no.fixo = fixo
		no.papel = p
		no.refugio = centro
		no.assent = a
		nos.append(no)

func limpar_defensores() -> void:
	for n in nos:
		if is_instance_valid(n):
			n.queue_free()
	nos.clear()

func morreu(r: Recruta) -> void:
	var rc: Dictionary = r.dados
	nos.erase(r)
	var e: Dictionary = obter(onda.id) if not onda.is_empty() else {}
	if rc.get("morador", false):
		if not e.is_empty():
			if rc.funcao == "vigia":
				e.vigias = maxi(0, e.vigias - 1)
			else:
				e.armados = maxi(0, e.armados - 1)
			e.moradores = maxi(0, e.moradores - 1)
		onda.perdas.append("%s (morador)" % rc.nome)
		main.hud.aviso("%s, morador, caiu no muro." % rc.nome)
	else:
		main.base.lista.erase(rc)
		main.base.distribuir_camas()
		VidaRecrutas.luto(main.base, rc, r.global_position)
		onda.perdas.append(rc.nome)
		main.registrar("%s morreu defendendo %s." % [rc.nome, e.get("nome", "o assentamento")])
		main.hud.aviso("%s morreu defendendo o assentamento." % rc.nome)
	var t := r.create_tween()
	t.tween_property(r, "rotation:x", -1.5, 0.5)
	t.tween_interval(25.0)
	t.tween_callback(r.queue_free)

func muro_caiu(a: Assentamento, i: int) -> void:
	if onda.is_empty():
		return
	var l := Assentamento.ponto(i, 1.0)
	var k := Assentamento.setor(l)
	main.hud.aviso("O muro %s caiu! Tapem a brecha!" % NOMES_SETOR[k] if i != 0 else "O PORTÃO CEDEU!")

## Um zumbi chegou no meio do assentamento e atacou os moradores.
func atacar_povo(dano: float) -> void:
	if onda.is_empty():
		return
	onda.resistencia = maxf(0.0, onda.resistencia - dano)

func processar(dt: float) -> void:
	_t -= dt
	if onda.is_empty():
		if _t <= 0.0:
			_t = 1.0
			for id in estado:
				var a := no_de(id)
				if a:
					a.ligar_holofotes(main.eh_noite())
		return
	var a := no_de(onda.id)
	var e: Dictionary = estado[onda.id]
	if a == null:
		return
	onda.t += dt
	# chegam aos poucos, de um lado, depois de vários
	onda.t_spawn -= dt
	var vivos: Array = onda.vivos.filter(func(z): return is_instance_valid(z) and z.vivo())
	onda.vivos = vivos
	if onda.fila > 0 and onda.t_spawn <= 0.0 and vivos.size() < 45:
		onda.t_spawn = 1.1
		var lote := mini(onda.fila, 3)
		for q in lote:
			var espalha := 0.9 if onda.t < 40.0 else 2.2
			var ang: float = onda.ang + randf_range(-espalha, espalha)
			var rr := Assentamento.R + randf_range(17.0, 26.0)
			var l := Vector3(sin(ang) * rr, 0, cos(ang) * rr)
			var g := a.global_de(l)
			g.y = main.mundo.altura(g.x, g.z)
			# ondas mais altas trazem mais especiais
			var tipo := ""
			if randf() < 0.06 * onda.n:
				tipo = ["corredor", "brutamonte", "corredor", "rastejante", "gritador"][randi() % 5]
			var z: Zumbi = main.mundo.criar_zumbi(main.mundo, g, a.global_rotation.y + ang + PI, randi(), tipo)
			z.cerco = a
			z.estado = Zumbi.Estado.PERSEGUINDO
			onda.vivos.append(z)
			onda.fila -= 1
	# dentro do muro, cada zumbi assusta e machuca os moradores
	var dentro := 0
	for z in vivos:
		var l2: Vector3 = a.local_de(z.global_position)
		var r2 := Vector2(l2.x, l2.z).length()
		if r2 < Assentamento.R - 1.0:
			dentro += 1
			onda.resistencia -= dt * (0.0012 if r2 > 10.0 else 0.0035)
		if a.armadilha_em(l2) and not z.get_meta("estacado", false):
			z.set_meta("estacado", true)
			z.ferir(32.0, (z.global_position - a.global_position).normalized() * 3.0)
			if not z.vivo():
				onda.abates += 1
	onda.dentro = dentro
	onda.resistencia = maxf(0.0, onda.resistencia)
	a.ligar_holofotes(main.eh_noite())
	if onda.resistencia <= 0.0:
		_derrota(e, a)
	elif onda.fila <= 0 and vivos.is_empty():
		_vitoria(e, a)

func abateu(z: Zumbi) -> void:
	if not onda.is_empty() and onda.vivos.has(z):
		onda.abates += 1

func _vitoria(e: Dictionary, a: Assentamento) -> void:
	var n: int = onda.n
	e.ondas = n
	e.fase = "entre_ondas"
	e.prox_onda_h = 16.0 + randf_range(-2.0, 3.0)
	e.bonus_portao = 0.0
	for i in Assentamento.N:
		e.muro[i] = minf(e.muro[i], a.hp_max(i))
	a.portao(true)
	a.redesenhar()
	limpar_defensores()
	var linhas: Array[String] = []
	linhas.append("Onda %d vencida em %s! %d zumbis abatidos." % [n, e.nome, onda.total])
	var primeira = not e.defendido
	if primeira:
		e.defendido = true
		defendidos += 1
		main.mundo.nivel_ameaca += 1.0
		z_horda = float(e.pos.z) - 7000.0
		linhas.append("Assentamento defendido! Total: %d. A horda se espalhou e vai se reagrupar." % defendidos)
		if main.get("comercio"):
			main.comercio.reputacao(e.id, 45.0, "defendeu o assentamento")
			linhas.append("%s agora te trata como aliado: descontos, estoque melhor e presentes." % e.nome)
		_marco(linhas)
	# recompensa: os moradores dividem o que têm (cresce a cada onda)
	var rec := {"comida": 3 + n * 2, "agua": 3 + n * 2, "pecas": 2 + n, "sucata": 8 + n * 5}
	if n >= 2:
		rec["remedio"] = 1 + n / 2
	if n >= 3:
		rec["pneu"] = 1
	var ganhos: Array[String] = []
	for k in rec:
		var q: int = main.adicionar(k, rec[k])
		if q > 0:
			ganhos.append("%d %s" % [q, main.ITENS[k].nome.to_lower()])
	if not ganhos.is_empty():
		linhas.append("Os moradores dividiram: " + ", ".join(ganhos) + ".")
	else:
		linhas.append("Os moradores queriam dividir mantimentos, mas a carga do comboio está cheia.")
	e.estoque.sucata += 10 + n * 4
	e.estoque.pecas += 2 + n
	var muro_agora := a.muro_medio()
	linhas.append("Muro: %d%% (era %d%%). Resistência dos moradores: %d%%." % [int(muro_agora * 100.0), int(onda.muro_ini * 100.0), int(onda.resistencia * 100.0)])
	if not onda.perdas.is_empty():
		linhas.append("Perdas: " + ", ".join(onda.perdas) + ".")
	linhas.append("Próxima onda (%d zumbis) em ~%d h. Dá para partir antes." % [tamanho_onda(n + 1), int(e.prox_onda_h)])
	onda = {}
	main.hud.banner("Onda %d vencida" % n, e.nome)
	main.hud.relatorio = "\n".join(linhas)
	main.hud.relatorio_titulo = "ONDA %d VENCIDA" % n
	main.hud.relatorio_t = 14.0
	main.registrar(linhas[0])

func _marco(linhas: Array[String]) -> void:
	if defendidos in [5, 10, 25]:
		var tipos := ["oficina", "apartamentos", "tanque", "estufa", "armazem", "plataforma"]
		var t: String = tipos[defendidos % tipos.size()]
		main.estoque.projetos.append(t)
		linhas.append("MARCO: %d assentamentos defendidos! Os aliados te deram o projeto de um reboque (%s)." % [defendidos, main.NOMES_TIPO.get(t, t)])

func _derrota(e: Dictionary, a: Assentamento) -> void:
	e.fase = "caido"
	ativo = ""
	for i in Assentamento.N:
		if randf() < 0.4:
			e.muro[i] = 0.0
	a.portao(true)
	a.redesenhar()
	for z in onda.vivos:
		if is_instance_valid(z):
			z.cerco = null
	limpar_defensores()
	var nome: String = e.nome
	onda = {}
	main._morrer("%s caiu. Os zumbis tomaram o assentamento." % nome)

## Sai do jogo de defesa sem resolver (morte do jogador no meio da onda).
func abortar() -> void:
	if onda.is_empty():
		return
	var e: Dictionary = estado[onda.id]
	e.fase = "caido"
	ativo = ""
	var a := no_de(onda.id)
	for z in onda.vivos:
		if is_instance_valid(z):
			z.cerco = null
	limpar_defensores()
	onda = {}
	if a:
		a.portao(true)
		a.redesenhar()

# ------------------------------------------------------------ HUD
func info_hud() -> Dictionary:
	var foco: Vector3 = main._foco()
	if not onda.is_empty():
		var a := no_de(onda.id)
		return {"titulo": "%s — ONDA %d" % [estado[onda.id].nome.to_upper(), onda.n],
			"linha": "%d zumbis restantes%s" % [onda.fila + onda.vivos.size(), ("  ·  %d dentro do muro!" % onda.get("dentro", 0)) if onda.get("dentro", 0) > 0 else ""],
			"muro": a.muro_medio() if a else 0.0, "resistencia": onda.resistencia, "onda": true}
	if ativo != "":
		var e: Dictionary = estado[ativo]
		if foco.distance_to(e.pos) < 90.0:
			var h := horas_ate(e.pos.z) if e.fase == "preparando" else float(e.prox_onda_h)
			var a2 := no_de(ativo)
			return {"titulo": e.nome.to_upper(), "linha": ("A horda chega em ~%d h" if e.fase == "preparando" else "Próxima onda (%d zumbis) em ~%%d h" % tamanho_onda(e.ondas + 1)) % int(ceil(h)),
				"muro": a2.muro_medio() if a2 else 0.0, "resistencia": -1.0, "onda": false}
	return {}

func texto_horda() -> String:
	var km: float = km_horda(main._foco().z)
	if km < 0.0:
		return ""
	return "Horda %.1f km atrás · %s" % [km, WorldGen.FAIXAS[main.mundo.faixa(main._foco().z)].nome]
