class_name BaseRecrutas
extends Node
## Tudo o que os recrutas fazem pela base: camas, comida, moral, automação
## das áreas do comboio, expedições do batedor e os corpos 3D no acampamento.

var main: Node
var lista: Array = []          # Dictionaries (ver Recrutas.de_npc)
var nos: Array = []            # Recruta em cena (só com o comboio parado)
var _h_dia := 0.0              # horas acumuladas até a próxima refeição
var _t_cena := 0.0
var _acordados_t := 0.0        # horas em que todo mundo fica acordado (ataque noturno)
var registro: Array[String] = []   # o que aconteceu enquanto o tempo passava (relatório)
var _abates_noite := {}
var _pecas_feitas := 0
var _colhido := 0
var _reparos := 0.0

# ------------------------------------------------------------ consultas
func camas() -> int:
	var n := 0
	for el in main.comboio.cadeia:
		if el is Reboque and el.tipo == "apartamentos" and el.funcional():
			n += el.capacidade()
	return n

func camas_livres() -> int:
	return camas() - lista.size()

func presentes(funcao := "") -> Array:
	var r: Array = []
	for rc in lista:
		if rc.expedicao.is_empty() and rc.vida > 0.0 and (funcao == "" or rc.funcao == funcao):
			r.append(rc)
	return r

func n(funcao: String) -> int:
	return presentes(funcao).size()

## Força de uma função somando o nível de cada um (nível 1 = 1,0; nível 5 = 1,6).
func forca(funcao: String) -> float:
	var f := 0.0
	for rc in presentes(funcao):
		f += VidaRecrutas.mult(rc)
	return f

func reboque(tipo: String) -> Reboque:
	for el in main.comboio.cadeia:
		if el is Reboque and el.tipo == tipo:
			return el
	return null

func texto_hud() -> String:
	var c := camas()
	if c == 0 and lista.is_empty():
		return ""
	return "Recrutas %d / %d" % [lista.size(), c]

## Atualiza quem dorme em cada cama dos apartamentos.
func distribuir_camas() -> void:
	var i := 0
	for el in main.comboio.cadeia:
		if el is Reboque and el.tipo == "apartamentos":
			var cap: int = el.capacidade()
			el.moradores = lista.slice(i, i + cap)
			i += cap

# ------------------------------------------------------------ recrutar
func pode_recrutar(h: Node3D) -> String:
	if camas_livres() <= 0:
		return "Sem cama livre no comboio." if camas() > 0 else "Precisa de um reboque de apartamentos funcionando."
	if not main.tem_itens(Recrutas.pedido_de(h)):
		return "Falta o que foi pedido."
	return ""

func recrutar(h: Humanoid) -> String:
	var motivo := pode_recrutar(h)
	if motivo != "":
		return motivo
	main.gastar(Recrutas.pedido_de(h))
	var rc := Recrutas.de_npc(h)
	lista.append(rc)
	main.mundo.recrutados[rc.id] = true
	main.mundo.npcs.erase(h)
	h.queue_free()
	distribuir_camas()
	main.hud.aviso("%s (%s) entrou para o comboio!" % [rc.nome, Recrutas.titulo(rc).to_lower()])
	main._fechar_janela()
	return ""

func dispensar(rc: Dictionary) -> String:
	lista.erase(rc)
	distribuir_camas()
	_remover_no(rc)
	return "%s pegou suas coisas e seguiu sozinho pela estrada." % rc.nome

# ------------------------------------------------------------ tempo passando
## Chamado a cada avanço do relógio (h em horas de jogo).
func passar(h: float) -> void:
	if lista.is_empty():
		return
	_acordados_t = maxf(0.0, _acordados_t - h)
	_expedicoes(h)
	_medico(h)
	_mecanico(h)
	_h_dia += h
	while _h_dia >= 24.0:
		_h_dia -= 24.0
		_refeicao_do_dia()

func _refeicao_do_dia() -> void:
	var apto := reboque("apartamentos")
	var conforto := 0.0 if apto == null else (apto.nivel - 1) * 0.04
	for rc in lista.duplicate():
		if not rc.expedicao.is_empty():
			continue
		var comeu: bool = main.estoque.get("comida", 0) > 0 and main.estoque.get("agua", 0) > 0
		if comeu:
			main.estoque.comida -= 1
			main.estoque.agua -= 1
			rc.fome = 0.0
			rc.moral = clampf(rc.moral + 0.05 + conforto, 0.0, 1.0)
		else:
			rc.fome += 1.0
			rc.moral = clampf(rc.moral - 0.2, 0.0, 1.0)
			rc.vida = maxf(0.05, rc.vida - 0.15)
			registro.append("%s passou o dia sem comer." % rc.nome)
	var r := RandomNumberGenerator.new()
	r.seed = hash([main.dia, lista.size(), main.mundo.semente])
	VidaRecrutas.dia(self, r)
	distribuir_camas()

func _medico(h: float) -> void:
	if n("medico") == 0:
		return
	var med := forca("medico")
	var j: Player = main.jogador
	var antes := j.infeccao
	j.vida = minf(1.0, j.vida + 0.02 * h * med)
	if j.infeccao > 0.0:
		j.infeccao = maxf(0.0, j.infeccao - 0.04 * h * med)
		if antes > 0.0 and j.infeccao <= 0.0:
			registro.append("A médica conteve a sua infecção." if _fem("medico") else "O médico conteve a sua infecção.")
	var cuidou := j.vida < 1.0 or j.infeccao > 0.0
	for rc in lista:
		if rc.vida < 1.0 and rc.expedicao.is_empty():
			rc.vida = minf(1.0, rc.vida + 0.03 * h * med)
			cuidou = true
	if cuidou:
		for m in presentes("medico"):
			VidaRecrutas.ganhar_xp(self, m, 0.4 * h)

func _mecanico(h: float) -> void:
	var mec := forca("mecanico") + 0.5 * n("idoso")
	if mec <= 0.0:
		return
	# conserta aos poucos o reboque (ou trailer) mais estragado, gastando sucata
	_reparos += h * 0.015 * mec
	while _reparos >= 0.05 and main.estoque.get("sucata", 0) > 0:
		_reparos -= 0.05
		var pior: Node3D = null
		var pc := 0.95
		for el in main.comboio.cadeia:
			if el is Reboque and el.condicao < pc:
				pc = el.condicao
				pior = el
		if pior == null:
			_reparos = 0.0
			break
		pior.condicao = minf(1.0, pior.condicao + 0.05)
		main.estoque.sucata -= 1
		for m in presentes("mecanico"):
			VidaRecrutas.ganhar_xp(self, m, 0.6)
	# oficina parada: começa a fabricar peças sozinha (guarda 10 de sucata de reserva)
	var of := reboque("oficina")
	if of and of.funcional() and of.trabalho.is_empty() and main.estoque.get("sucata", 0) >= 18:
		main.estoque.sucata -= 8
		of.trabalho = {"tipo": "pecas", "qtd": 2, "restante": 2.0 / float(of.nivel) / (1.0 + 0.25 * maxf(0.0, mec - 1.0)), "auto": true}
		for m in presentes("mecanico"):
			VidaRecrutas.ganhar_xp(self, m, 1.0)

## Estufa: o agricultor aumenta a produção e colhe sozinho.
func bonus_estufa() -> float:
	var ag := presentes("agricultor")
	var b := 0.0
	for i in mini(ag.size(), 2):
		b += 0.5 * VidaRecrutas.mult(ag[i])
	return 1.0 + b + 0.2 * mini(n("idoso"), 1)

func colher_estufa(r: Reboque) -> void:
	if n("agricultor") == 0:
		return
	var c := int(r.comida)
	if c > 0:
		var ent: int = main.adicionar("comida", c)
		r.comida -= ent
		_colhido += ent
		for a in presentes("agricultor"):
			VidaRecrutas.ganhar_xp(self, a, 0.3 * ent)
	var a := int(r.agua)
	if a > 0:
		r.agua -= main.adicionar("agua", a)

func pecas_feitas(qtd: int) -> void:
	_pecas_feitas += qtd

func _fem(funcao: String) -> bool:
	for rc in presentes(funcao):
		return VidaRecrutas.fem(rc)
	return false

# ------------------------------------------------------------ batedor
func enviar_expedicao(rc: Dictionary, horas: float) -> String:
	if not rc.expedicao.is_empty():
		return ""
	if rc.vida < 0.5:
		return "%s está ferido demais para sair." % rc.nome
	rc.expedicao = {"restante": horas, "horas": horas, "ameaca": main.mundo.nivel_ameaca}
	_remover_no(rc)
	distribuir_camas()
	return "%s saiu em expedição (%d h)." % [rc.nome, int(horas)]

func _expedicoes(h: float) -> void:
	for rc in lista.duplicate():
		if rc.expedicao.is_empty():
			continue
		rc.expedicao.restante -= h
		if rc.expedicao.restante > 0.0:
			continue
		var horas: float = rc.expedicao.horas
		var ameaca: float = rc.expedicao.ameaca
		rc.expedicao = {}
		var r := RandomNumberGenerator.new()
		r.seed = hash(rc.id) + main.dia * 97 + int(main.hora * 10.0)
		var risco := horas / 6.0 * (1.0 - 0.1 * (int(rc.get("nivel", 1)) - 1))
		if r.randf() < 0.03 * risco * (1.0 + ameaca * 0.3):
			lista.erase(rc)
			registro.append("%s saiu em expedição e não voltou." % rc.nome)
			VidaRecrutas.luto(self, rc, Vector3.ZERO, false)
			continue
		if r.randf() < 0.18 * risco:
			rc.vida = maxf(0.15, rc.vida - r.randf_range(0.25, 0.5))
			registro.append("%s voltou ferido da expedição." % rc.nome)
		var tabela := {"sucata": r.randi_range(3, 8), "comida": r.randi_range(1, 3), "agua": r.randi_range(0, 2), "pecas": r.randi_range(0, 2)}
		var ganhos: Array[String] = []
		var mult := horas / 6.0 * VidaRecrutas.mult(rc)
		VidaRecrutas.ganhar_xp(self, rc, horas * 0.5)
		for k in tabela:
			var q := int(round(tabela[k] * mult))
			if q > 0:
				var e: int = main.adicionar(k, q)
				if e > 0:
					ganhos.append("%d %s" % [e, main.ITENS[k].nome.to_lower()])
		for raro in [["remedio", 0.15], ["galoes_diesel", 0.15], ["pneu", 0.1]]:
			if r.randf() < raro[1] * mult:
				if main.adicionar(raro[0], 1) > 0:
					ganhos.append("1 %s" % main.ITENS[raro[0]].nome.to_lower())
		registro.append("%s voltou da expedição com %s." % [rc.nome, ", ".join(ganhos) if not ganhos.is_empty() else "as mãos vazias (sem espaço na carga)"])
	distribuir_camas()

func _moral_todos(d: float) -> void:
	for rc in lista:
		rc.moral = clampf(rc.moral + d, 0.0, 1.0)

# ------------------------------------------------------------ segurança da noite
## Quanto os vigias reduzem o risco de ataque (valor negativo).
func bonus_seguranca() -> float:
	return -0.15 * mini(n("vigia"), 2)

## Relatório do que os recrutas fizeram enquanto o jogador dormia.
func relatorio() -> Array[String]:
	var l: Array[String] = []
	if _colhido > 0:
		l.append("Colheita automática: %d comida." % _colhido)
	if _pecas_feitas > 0:
		l.append("A oficina fabricou %d peças sozinha." % _pecas_feitas)
	for nome in _abates_noite:
		l.append("%s abateu %d zumbi%s." % [nome, _abates_noite[nome], "s" if _abates_noite[nome] > 1 else ""])
	l.append_array(registro)
	_colhido = 0
	_pecas_feitas = 0
	_abates_noite.clear()
	registro.clear()
	return l

func abate(r: Recruta) -> void:
	main.abates += 1
	if r.dados.funcao in ["vigia", "batedor"]:
		VidaRecrutas.ganhar_xp(self, r.dados, 1.5)
	_abates_noite[r.dados.nome] = _abates_noite.get(r.dados.nome, 0) + 1

func morreu(r: Recruta) -> void:
	var rc: Dictionary = r.dados
	lista.erase(rc)
	nos.erase(r)
	distribuir_camas()
	VidaRecrutas.luto(self, rc, r.global_position)
	main.hud.aviso("%s morreu defendendo o comboio." % rc.nome)
	registro.append("%s morreu defendendo o comboio." % rc.nome)
	# corpo cai e some depois
	var t := r.create_tween()
	t.tween_property(r, "rotation:x", -1.5, 0.5)
	t.tween_interval(30.0)
	t.tween_callback(r.queue_free)

## Modo infinito: ao cair, parte dos recrutas morre.
func penalidade(r: RandomNumberGenerator) -> String:
	var mortos: Array[String] = []
	for rc in lista.duplicate():
		if r.randf() < 0.4 and rc.funcao != "crianca":
			lista.erase(rc)
			mortos.append(rc.nome)
		else:
			rc.vida = minf(rc.vida, 0.35)
			rc.moral = clampf(rc.moral - 0.25, 0.0, 1.0)
	limpar_cena()
	distribuir_camas()
	if lista.is_empty() and mortos.is_empty():
		return "Recrutas mortos: nenhum (o comboio não tinha recrutas)."
	if mortos.is_empty():
		return "Recrutas mortos: nenhum, mas todos estão feridos e abalados."
	return "Recrutas mortos: " + ", ".join(mortos)

# ------------------------------------------------------------ cena 3D
func atualizar_cena(dt: float) -> void:
	if main.defesa and main.defesa.em_combate():
		return
	_t_cena -= dt
	if _t_cena > 0.0:
		return
	_t_cena = 0.5
	var parado: bool = not main.comboio.dirigindo and absf(main.comboio.velocidade) < 0.5
	var perto: bool = main._foco().distance_to(main.trailer.global_position) < 80.0
	if not parado or not perto or main._morto:
		limpar_cena()
		return
	# à noite só os vigias ficam acordados, a não ser que haja ataque
	var noite: bool = main.hora >= 22.0 or main.hora < 5.0
	if noite and _ameaca_perto(25.0):
		if _acordados_t <= 0.0:
			main.hud.aviso("Os recrutas acordaram com o barulho!")
		_acordados_t = 0.5
	var dormir: bool = noite and _acordados_t <= 0.0
	for el in main.comboio.cadeia:
		if el is Reboque and el.tipo == "apartamentos" and el.dormindo != dormir:
			el.dormindo = dormir
			el.reconstruir()
	var deveria: Array = []
	for rc in presentes():
		if not dormir or rc.funcao == "vigia":
			deveria.append(rc)
	for r in nos.duplicate():
		if not is_instance_valid(r) or not deveria.has(r.dados):
			if is_instance_valid(r) and r.vivo():
				r.queue_free()
			nos.erase(r)
	var postos := _postos()
	var contagem := {}
	for rc in deveria:
		var ja := false
		for r in nos:
			if r.dados == rc:
				ja = true
		var k: int = contagem.get(rc.funcao, 0)
		contagem[rc.funcao] = k + 1
		if ja:
			continue
		var p: Array = _posto(postos, rc.funcao, k)
		var r := Recruta.criar(rc)
		r.main = main
		main.add_child(r)
		r.posto = p[0]
		r.olhar_posto = p[1]
		r.global_position = p[0]
		r.rotation.y = p[1]
		nos.append(r)

func _ameaca_perto(raio: float) -> bool:
	for z in main.mundo.zumbis_vivos:
		if is_instance_valid(z) and z.vivo() and z.global_position.distance_to(main.trailer.global_position) < raio:
			return true
	return false

func limpar_cena() -> void:
	for r in nos:
		if is_instance_valid(r):
			r.queue_free()
	nos.clear()

func _remover_no(rc: Dictionary) -> void:
	for r in nos.duplicate():
		if is_instance_valid(r) and r.dados == rc:
			r.queue_free()
			nos.erase(r)

func _chao(p: Vector3) -> Vector3:
	p.y = main.jogador.chao(p)
	return p

## Pontos de trabalho de cada função em volta do comboio: {funcao: [[pos, yaw], ...]}.
func _postos() -> Dictionary:
	var tr: Node3D = main.trailer
	var pk: Node3D = main.picape
	var ps := {}
	var ang := func(de: Vector3, para: Vector3) -> float:
		return atan2(para.x - de.x, para.z - de.z)
	# mecânico: ao lado da oficina, ou no capô da picape
	var of := reboque("oficina")
	var lista_m: Array = []
	if of:
		for k in 2:
			var p := _chao(of.global_transform * Vector3(of.info().larg * 0.5 + 0.7, 0, 0.6 - k * 1.3))
			lista_m.append([p, ang.call(p, of.global_position)])
	var cap := _chao(pk.global_transform * Vector3(0.6, 0, 3.0))
	lista_m.append([cap, ang.call(cap, pk.global_transform * Vector3(0, 0, 2.0))])
	ps["mecanico"] = lista_m
	# agricultor: na porta da estufa, ou numa horta ao lado do trailer
	var es := reboque("estufa")
	var lista_a: Array = []
	if es:
		for k in 2:
			var p := _chao(es.global_transform * Vector3(-es.info().larg * 0.5 - 0.6, 0, 0.5 - k * 1.2))
			lista_a.append([p, ang.call(p, es.global_position)])
	var horta := _chao(tr.global_transform * Vector3(3.2, 0, -1.6))
	lista_a.append([horta, tr.global_rotation.y + PI * 0.5])
	ps["agricultor"] = lista_a
	# médico e batedor: perto da fogueira (lado da cozinha) e da porta dos apartamentos
	var fog := tr.global_transform * Vector3(-3.6, 0, 0.6)
	ps["medico"] = [[_chao(fog + tr.global_transform.basis * Vector3(-0.9, 0, -0.9)), ang.call(fog + tr.global_transform.basis * Vector3(-0.9, 0, -0.9), fog)],
		[_chao(fog + tr.global_transform.basis * Vector3(0.9, 0, 1.1)), ang.call(fog + tr.global_transform.basis * Vector3(0.9, 0, 1.1), fog)]]
	var apto := reboque("apartamentos")
	var base_b: Vector3 = apto.global_transform * Vector3(-1.9, 0, -0.8) if apto else fog + Vector3(1.5, 0, 0)
	ps["batedor"] = [[_chao(base_b), ang.call(base_b, fog)], [_chao(base_b + Vector3(0.9, 0, 0.6)), ang.call(base_b, fog)]]
	# idoso: sentado do outro lado da fogueira; criança: brincando entre a fogueira e os apartamentos
	var tb: Basis = tr.global_transform.basis
	var lado_i := fog + tb * Vector3(-1.2, 0, 0.2)
	ps["idoso"] = [[_chao(lado_i), ang.call(lado_i, fog)], [_chao(fog + tb * Vector3(0.2, 0, -1.3)), ang.call(fog + tb * Vector3(0.2, 0, -1.3), fog)]]
	var brinca := (fog + base_b) * 0.5 + tb * Vector3(-1.4, 0, 0.0)
	ps["crianca"] = [[_chao(brinca), ang.call(brinca, fog)], [_chao(brinca + tb * Vector3(0.0, 0, 1.2)), ang.call(brinca, fog)]]
	# vigias: na frente da picape e atrás do último reboque, olhando para fora
	var ult: Node3D = main.comboio.cadeia[main.comboio.cadeia.size() - 1]
	var frente := _chao(pk.global_transform * Vector3(-2.5, 0, 6.5))
	var tras := _chao(ult.global_transform * Vector3(2.5, 0, -ult.comprimento() * 0.5 - 4.5))
	var lado := _chao(tr.global_transform * Vector3(5.5, 0, 0))
	ps["vigia"] = [[frente, pk.global_rotation.y], [tras, ult.global_rotation.y + PI], [lado, tr.global_rotation.y + PI * 0.5]]
	return ps

func _posto(ps: Dictionary, funcao: String, k: int) -> Array:
	var l: Array = ps.get(funcao, [])
	if l.is_empty():
		return [main.trailer.global_position + Vector3(2, 0, 0), 0.0]
	var p: Array = l[mini(k, l.size() - 1)].duplicate()
	if k >= l.size():
		p[0] = p[0] + Vector3(0.8 * (k - l.size() + 1), 0, 0.5)
	return p

func posicoes() -> Array[Vector3]:
	var r: Array[Vector3] = []
	for rc in nos:
		if is_instance_valid(rc):
			r.append(rc.global_position)
	return r
