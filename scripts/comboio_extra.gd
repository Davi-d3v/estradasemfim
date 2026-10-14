class_name ComboioExtra
extends Node
## O comboio como personagem: desgaste (pneu furado, motor pedindo revisão),
## os reboques raros (hospital, torre de rádio, destilaria, blindado com torreta)
## e a cara do comboio (nome pintado no trailer, assinaturas dos recrutas, troféus no capô).

const NOMES_COMBOIO := ["ESTRADA SEM FIM", "ÚLTIMA PARADA", "TERRA DE NINGUÉM", "SEMPRE EM FRENTE", "BR SEM VOLTA",
	"ARCA DO ASFALTO", "CARAVANA DO FIM", "NÃO PARE", "FILHOS DA ESTRADA", "O ÚLTIMO COMBOIO"]
const ALCOOL_POR_COMIDA := 2.0     # litros de álcool por comida no alambique

var main: Node
var pneu_furado := false
var nome_comboio := ""
var trofeus := 0                   # crânios de brutamonte no capô
var _avisou_motor := false
var _t_torreta := 0.0
var _t_radar := 0.0
var _odo_check := 0.0
var radar: Array = []              # [{pos, cor, letra, nome}] para o mapa

func salvar() -> Dictionary:
	return {"pneu_furado": pneu_furado, "nome": nome_comboio, "trofeus": trofeus}

func carregar(d: Dictionary) -> void:
	pneu_furado = d.get("pneu_furado", false)
	nome_comboio = d.get("nome", "")
	trofeus = d.get("trofeus", 0)
	aplicar_visual()

func reboque(tipo: String) -> Reboque:
	for el in main.comboio.cadeia:
		if el is Reboque and el.tipo == tipo and el.funcional():
			return el
	return null

# ------------------------------------------------------------ a cada quadro
func atualizar(dt: float) -> void:
	var c: Comboio = main.comboio
	_desgaste(dt, c)
	_torreta(dt)
	_t_radar -= dt
	if _t_radar <= 0.0:
		_t_radar = 2.0
		_atualizar_radar()

## Desgaste: estrada de terra e mato furam pneu; o motor gasta com os km.
func _desgaste(dt: float, c: Comboio) -> void:
	if not c.dirigindo or absf(c.velocidade) < 2.0:
		return
	var p: Pickup = main.picape
	var metros := absf(c.velocidade) * dt
	# motor: −1% a cada 4 km (mais rápido com carga acima do limite)
	var gasto := metros / 400000.0 * (1.0 + maxf(0.0, c.razao_carga() - 1.0) * 2.0)
	p.config.motor.condicao = maxf(0.05, p.config.motor.condicao - gasto)
	p.config.pneus.condicao = maxf(0.05, p.config.pneus.condicao - metros / (600000.0 if not (c.na_terra or c.fora_da_estrada) else 120000.0))
	if p.config.motor.condicao < 0.3 and not _avisou_motor:
		_avisou_motor = true
		main.hud.aviso("O motor está falhando: precisa de revisão na oficina (peças).")
	elif p.config.motor.condicao > 0.35:
		_avisou_motor = false
	# motor muito gasto engasga de vez em quando
	if p.config.motor.condicao < 0.3 and randf() < dt * 0.08 * (0.3 - p.config.motor.condicao) * 10.0:
		c.velocidade *= 0.55
		Som.tela("kenney/impact", -12.0, 0.2)
		main.hud.aviso("O motor engasgou.")
	# pneu furado: terra, mato e pneu gasto
	if not pneu_furado:
		var risco := 0.0
		if c.fora_da_estrada:
			risco = 0.0009
		elif c.na_terra:
			risco = 0.00035
		else:
			risco = 0.00002
		risco *= lerpf(2.5, 0.6, p.config.pneus.condicao) / float(maxi(1, p.nivel("pneus")))
		if randf() < risco * metros:
			furar()

func furar() -> void:
	pneu_furado = true
	Som.tela("kenney/impact", -2.0)
	Som.tela("fogo_whoosh", -10.0, 0.3)
	main.hud.banner("PNEU FURADO", "A picape puxa para o lado e não passa de 30 km/h. Pare e troque o pneu (1 pneu, 20 min).")

## Velocidade máxima com pneu furado (m/s).
func limite_velocidade() -> float:
	return 8.5 if pneu_furado else INF

func puxao() -> float:
	return 0.12 if pneu_furado else 0.0

func trocar_pneu() -> String:
	if main.estoque.get("pneu", 0) <= 0:
		return "Sem pneu no estoque. Ache um num carro abandonado ou num reboque."
	main.estoque.pneu -= 1
	main.adicionar("sucata", 2)
	pneu_furado = false
	main._passar_tempo(0.33)
	Som.tela("kenney/weapon_change", -4.0)
	return "Pneu trocado. O furado virou 2 de sucata."

# ------------------------------------------------------------ torreta
func _torreta(dt: float) -> void:
	var r := reboque("torreta")
	if r == null:
		return
	var t: Node3D = r.find_child("Torreta", true, false)
	var fl: Node3D = t.find_child("Flash", true, false) if t else null
	_t_torreta -= dt
	if fl and _t_torreta < 0.12:
		fl.visible = false
	var alcance := float(r.capacidade())
	var alvo: Zumbi = null
	var md := alcance
	for z in main.mundo.zumbis_vivos:
		if not is_instance_valid(z) or not z.vivo():
			continue
		var d: float = z.global_position.distance_to(r.global_position)
		if d < md:
			md = d
			alvo = z
	if alvo == null or t == null:
		return
	# gira a torreta
	var lp: Vector3 = t.get_parent().to_local(alvo.global_position)
	t.rotation.y = lerp_angle(t.rotation.y, atan2(lp.x, lp.z), minf(1.0, dt * 6.0))
	if _t_torreta > 0.0:
		return
	var mun := "municao_rifle" if main.estoque.get("municao_rifle", 0) > 0 else ("municao_pistola" if main.estoque.get("municao_pistola", 0) > 1 else "")
	if mun == "":
		if randf() < 0.02:
			main.hud.aviso("A torreta está sem munição (balas de rifle ou 9 mm).")
		_t_torreta = 2.0
		return
	main.estoque[mun] -= 1 if mun == "municao_rifle" else 2
	_t_torreta = [0.0, 0.55, 0.42, 0.3][r.nivel]
	if fl:
		fl.visible = true
	Som.em("tiro_rifle", t.global_position, -1.0, 0.1, 3.5)
	main.ruido(t.global_position, 55.0, "tiro")
	var acerto := 0.75 - md / alcance * 0.35
	if randf() < acerto:
		alvo.ferir(randf_range(35.0, 60.0), (alvo.global_position - t.global_position).normalized() * 2.5, t.global_position)
		if not alvo.vivo():
			main.abates += 1

# ------------------------------------------------------------ hospital
## Chamado pelo relógio (h horas): cura acelerada e bandagens feitas com tecido.
func passar(h: float) -> void:
	var hosp := reboque("hospital")
	if hosp:
		var f := 0.012 * hosp.capacidade() * h
		var j: Player = main.jogador
		j.vida = minf(1.0, j.vida + f)
		if j.infeccao > 0.0:
			j.infeccao = maxf(0.0, j.infeccao - f * 0.8)
		for rc in main.base.lista:
			if rc.expedicao.is_empty():
				rc.vida = minf(1.0, rc.vida + f * 1.5)
		if main.cachorro and is_instance_valid(main.cachorro) and main.cachorro.vivo():
			main.cachorro.vida = minf(1.0, main.cachorro.vida + f * 1.5)
		var sd: Node = main.get("saude")
		if sd:
			sd.curar("ferida")
			if sd.tem("gripe"):
				sd.doencas.gripe -= h * 1.5
			if sd.tem("intoxicacao"):
				sd.doencas.intoxicacao -= h
		hosp.set_meta("t_bandagem", float(hosp.get_meta("t_bandagem", 0.0)) + h)
		while float(hosp.get_meta("t_bandagem")) >= 8.0:
			hosp.set_meta("t_bandagem", float(hosp.get_meta("t_bandagem")) - 8.0)
			if main.estoque.get("tecido", 0) >= 2:
				main.estoque.tecido -= 2
				main.adicionar("bandagem", 1)
	# alambique trabalhando
	var dest := reboque("destilaria")
	if dest and not dest.trabalho.is_empty():
		dest.trabalho.restante -= h
		if dest.trabalho.restante <= 0.0:
			var l: float = dest.trabalho.litros
			dest.trabalho = {}
			var cabe: float = main.comboio.tanque() - main.comboio.diesel
			var na_picape := minf(l, cabe)
			main.comboio.diesel += na_picape
			var sobra := l - na_picape
			var tq := reboque("tanque")
			if tq and sobra > 0.0:
				var ent := minf(sobra, tq.capacidade() - tq.litros)
				tq.litros += ent
				sobra -= ent
			main.hud.aviso("Destilaria: %d L de álcool prontos (%d L na picape)%s." % [int(l), int(na_picape), (", %d L perdidos sem lugar para guardar" % int(sobra)) if sobra > 0.5 else ""])

# ------------------------------------------------------------ torre de rádio
func _atualizar_radar() -> void:
	radar.clear()
	var r := reboque("radio")
	if r == null:
		main.hud.radar = radar
		return
	var w: WorldGen = main.mundo
	var z0: float = main.comboio.pos.z
	var alcance := float(r.capacidade()) * 1000.0
	var k0 := int(floor(z0 / WorldGen.TAM))
	for k in range(k0 + 1, k0 + int(alcance / WorldGen.TAM) + 1):
		var t := w.tipo_poi(k)
		var z := k * WorldGen.TAM + 32.0
		if t == "evento" and not w.eventos_feitos.has(k):
			var te := w.tipo_evento(k)
			var info: Array = {"saqueadores": [Color(0.95, 0.3, 0.2), "S", "bloqueio de saqueadores"], "carona": [Color(0.5, 0.85, 0.95), "C", "alguém pedindo carona"],
				"acidente": [Color(0.95, 0.75, 0.3), "A", "acidente"], "militar": [Color(0.6, 0.8, 0.4), "M", "comboio militar"],
				"cachorro": [Color(0.9, 0.7, 0.5), "D", "cachorro"]}.get(te, [Color.WHITE, "?", "?"])
			radar.append({"pos": w.ponto_estrada(z, 0.0), "cor": info[0], "letra": info[1], "nome": info[2], "km": (z - z0) / 1000.0})
		elif t.begins_with("reboque") and not w.reboques_levados.has(k):
			radar.append({"pos": w.ponto_estrada(z, 0.0), "cor": Color(0.85, 0.85, 0.85), "letra": "R", "nome": "reboque abandonado", "km": (z - z0) / 1000.0})
		elif t == "posto":
			radar.append({"pos": w.ponto_estrada(z + 12.0, 0.0), "cor": Color(0.95, 0.85, 0.3), "letra": "P", "nome": "posto", "km": (z - z0) / 1000.0})
	main.hud.radar = radar

func texto_radio() -> String:
	if reboque("radio") == null:
		return ""
	var h: float = main.defesa.horas_ate(main.comboio.pos.z)
	return "Horda alcança o comboio parado em %d h %02d min" % [int(h), int(fmod(h, 1.0) * 60.0)]

# ------------------------------------------------------------ painéis dos raros
func painel(r: Reboque) -> Dictionary:
	var linhas: Array = []
	var botoes: Array = []
	if not r.funcional():
		linhas.append(["Está danificado (%d%%). Repare na oficina, aba Engates, para funcionar." % int(r.condicao * 100), Color(0.95, 0.4, 0.3)])
	match r.tipo:
		"hospital":
			linhas.append("Leitos: %d. Com o comboio parado ou andando, cura você, os recrutas e o cachorro e combate a infecção." % r.capacidade())
			linhas.append("A cada 8 h transforma 2 retalhos de tecido em 1 bandagem (tecido: %d)." % main.estoque.get("tecido", 0))
			botoes.append(["Deitar e tratar os ferimentos (3 h)", func():
				main._passar_tempo(3.0)
				main.jogador.vida = minf(1.0, main.jogador.vida + 0.25)
				main.jogador.infeccao = maxf(0.0, main.jogador.infeccao - 0.3)
				return "Três horas num leito de verdade. Você se sente outra pessoa.", r.funcional()])
		"radio":
			linhas.append("Alcance: %d km. O que vem pela frente aparece no mapa." % r.capacidade())
			var t := texto_radio()
			if t != "":
				linhas.append([t, Color(0.95, 0.5, 0.35)])
			var lst: Array = radar.duplicate()
			lst.sort_custom(func(a, b): return a.km < b.km)
			for i in mini(6, lst.size()):
				linhas.append(["  %.1f km — %s" % [lst[i].km, lst[i].nome], lst[i].cor])
			if lst.is_empty():
				linhas.append(["  Nada no ar. Só estática.", Color(0.65, 0.65, 0.62)])
			botoes.append(["Ouvir as frequências (dica do rádio)", func():
				return main.ouvir_radio(), r.funcional()])
		"destilaria":
			var l := float(r.capacidade())
			var com := int(ceil(l / ALCOOL_POR_COMIDA))
			linhas.append("Lote: %d comida → %d L de álcool combustível em %d h. Vai direto para o tanque da picape (o que sobrar, para o tanque de diesel)." % [com, int(l), 4])
			linhas.append(["O motor aceita álcool misturado. Longe dos postos, é o que mantém o comboio andando.", Color(0.7, 0.7, 0.68)])
			if not r.trabalho.is_empty():
				linhas.append(["Destilando: faltam %.1f h." % r.trabalho.restante, Hud.DOURADO])
			botoes.append(["Destilar um lote (%d comida)" % com, func():
				main.estoque.comida -= com
				r.trabalho = {"tipo": "alcool", "litros": l, "restante": 4.0}
				Som.tela("fogueira", -8.0)
				return "O alambique começou a pingar.", r.funcional() and r.trabalho.is_empty() and main.estoque.get("comida", 0) >= com])
		"torreta":
			linhas.append("Alcance: %d m. Atira sozinha em qualquer zumbi perto do comboio, parado ou andando." % r.capacidade())
			linhas.append("Munição: %d balas de rifle (1 por tiro) · %d balas 9 mm (2 por tiro)." % [main.estoque.get("municao_rifle", 0), main.estoque.get("municao_pistola", 0)])
			linhas.append(["Faz muito barulho: atrai zumbis de longe.", Color(0.95, 0.6, 0.35)])
	return {"titulo": r.nome_exibicao().to_upper(), "subtitulo": "%s · nível %d" % [r.info().desc, r.nivel], "linhas": linhas, "botoes": botoes}

# ------------------------------------------------------------ cara do comboio
func painel_visual() -> Dictionary:
	var linhas: Array = ["Nome pintado na lateral do trailer: %s" % (nome_comboio if nome_comboio != "" else "nenhum"),
		"Troféus no capô: %d crânio%s de brutamonte (até 4)" % [trofeus, "" if trofeus == 1 else "s"],
		["Os recrutas com mais de uma semana no comboio assinam a lateral do trailer.", Color(0.7, 0.7, 0.68)]]
	var botoes: Array = []
	var i := NOMES_COMBOIO.find(nome_comboio)
	var prox: String = NOMES_COMBOIO[(i + 1) % NOMES_COMBOIO.size()]
	botoes.append(["Pintar \"%s\" (1 sucata)" % prox, func():
		main.estoque.sucata -= 1
		nome_comboio = prox
		aplicar_visual()
		return "", main.estoque.get("sucata", 0) >= 1])
	if nome_comboio != "":
		botoes.append(["Apagar o nome", func():
			nome_comboio = ""
			aplicar_visual()
			return "", true])
	return {"titulo": "A CARA DO COMBOIO", "subtitulo": "Tinta, sucata e um pouco de orgulho.", "linhas": linhas, "botoes": botoes}

func abateu(z: Zumbi) -> void:
	if z.tipo == "brutamonte" and trofeus < 4:
		trofeus += 1
		aplicar_visual()
		main.hud.aviso("Mais um crânio de brutamonte para o capô (%d/4)." % trofeus)

func assinaturas() -> Array:
	var l: Array = []
	for rc in main.base.lista:
		if int(rc.get("dias", 0)) >= 7:
			l.append(String(rc.nome))
	return l

func aplicar_visual() -> void:
	if main == null:
		return
	main.trailer.nome_comboio = nome_comboio
	main.trailer.assinaturas = assinaturas()
	main.trailer.reconstruir()
	main.picape.trofeus = trofeus
	main.picape.reconstruir()
