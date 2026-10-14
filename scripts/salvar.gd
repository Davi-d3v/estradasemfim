class_name Salvar
## Salvar e carregar o jogo inteiro (user://save.dat).
## Salva sozinho ao dormir, a cada 10 minutos de jogo e ao fechar; F5 salva na hora.
## Antes de sobrescrever um jogo de outro mundo, o arquivo antigo vira save_anterior.dat.

const ARQ := "user://save.dat"
const ANTERIOR := "user://save_anterior.dat"
const VERSAO := 1

static func existe() -> bool:
	return FileAccess.file_exists(ARQ)

## Resumo para o menu: {modo, dia, km, data} ou {} se não houver save.
static func resumo() -> Dictionary:
	var d := _ler(ARQ)
	if d.is_empty():
		return {}
	return {"modo": d.get("modo", ""), "dia": d.get("dia", 1), "km": d.get("comboio", {}).get("odometro", 0.0) / 1000.0,
		"data": d.get("data", ""), "reboques": d.get("reboques", []).size(), "recrutas": d.get("recrutas", []).size()}

static func _ler(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return {}
	var v = f.get_var(false)
	if typeof(v) != TYPE_DICTIONARY or int(v.get("versao", 0)) != VERSAO:
		return {}
	return v

static func apagar() -> void:
	if existe():
		DirAccess.rename_absolute(ProjectSettings.globalize_path(ARQ), ProjectSettings.globalize_path(ANTERIOR))

## Guarda o arquivo atual como "anterior" se ele for de outro mundo (novo jogo).
static func preservar_se_outro_mundo(semente: int) -> void:
	var d := _ler(ARQ)
	if not d.is_empty() and int(d.get("semente", 0)) != semente:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(ARQ), ProjectSettings.globalize_path(ANTERIOR))

# ------------------------------------------------------------ salvar
static func salvar(m: Node) -> bool:
	if m.capturando or not m.jogando or m.get("_morto"):
		return false
	var d := {}
	d.versao = VERSAO
	d.data = Time.get_datetime_string_from_system(false, true)
	d.modo = Jogo.modo
	d.semente = Jogo.semente
	d.mortes = Jogo.mortes
	d.dia = m.dia
	d.hora = m.hora
	d.abates = m.abates
	d.estoque = m.estoque.duplicate(true)
	d.conhecidos = m.conhecidos.duplicate(true)
	d.marcadores = Array(m.marcadores)
	d.avisou_marco = m._avisou_marco.duplicate(true)
	d.clima = m.clima.salvar()
	d.progresso = m.progresso.salvar()
	d.comercio = m.comercio.salvar()
	var j: Player = m.jogador
	d.jogador = {"pos": j.global_position, "yaw": j.yaw, "vida": j.vida, "sede": j.sede, "fome": j.fome,
		"estamina": j.estamina, "infeccao": j.infeccao, "dentro": m.dentro == m.trailer}
	var c: Comboio = m.comboio
	d.comboio = {"pos": c.pos, "yaw": c.yaw, "diesel": c.diesel, "odometro": c.odometro, "temperatura": c.temperatura}
	d.picape = {"config": m.picape.config.duplicate(true), "cor": m.picape.cor, "condicao": m.picape.condicao}
	d.trailer = {"config": m.trailer.config.duplicate(true), "cor": m.trailer.cor_pintura,
		"carroceria": m.trailer.condicao_carroceria, "luz_vermelha": m.trailer.luz_vermelha}
	var rebs: Array = []
	for i in range(1, c.cadeia.size()):
		var r = c.cadeia[i]
		if r is Reboque:
			var rd: Dictionary = r.salvar()
			rd.comida = r.comida
			rd.agua = r.agua
			rd.trabalho = r.trabalho.duplicate(true)
			rebs.append(rd)
	d.reboques = rebs
	d.recrutas = m.base.lista.duplicate(true)
	var e: Equipamento = m.equip
	d.equip = {"sel": e.sel, "pentes": e.pentes.duplicate(true), "cond_armas": e.cond_armas.duplicate(true),
		"armadura": e.armadura.duplicate(true)}
	var df: Defesa = m.defesa
	var est: Dictionary = df.estado.duplicate(true)
	for id in est:
		# uma onda em andamento não é salva: o assentamento volta para "aguardando"
		if est[id].get("fase", "") == "onda":
			est[id].fase = "entre_ondas"
	d.defesa = {"estado": est, "z_horda": df.z_horda, "defendidos": df.defendidos, "ativo": df.ativo}
	var w: WorldGen = m.mundo
	d.mundo = {"vasculhados": w.vasculhados.duplicate(true), "recrutados": w.recrutados.duplicate(true),
		"reboques_levados": w.reboques_levados.duplicate(true), "estado_reboques": w.estado_reboques.duplicate(true),
		"carros_desmontados": w.carros_desmontados.duplicate(true), "eventos_feitos": w.eventos_feitos.duplicate(true)}
	_limpar_objetos(d)
	var tmp := ARQ + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(d, false)
	f.close()
	# troca atômica: nunca fica um arquivo pela metade
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(ARQ))
	return true

## Tira referências a nós (não dá para salvar objetos).
static func _limpar_objetos(v) -> void:
	if v is Dictionary:
		for k in v.keys():
			if v[k] is Object:
				v.erase(k)
			else:
				_limpar_objetos(v[k])
	elif v is Array:
		for i in range(v.size() - 1, -1, -1):
			if v[i] is Object:
				v.remove_at(i)
			else:
				_limpar_objetos(v[i])

# ------------------------------------------------------------ carregar
## Lê o save e prepara o Jogo (modo/semente). A cena é recarregada depois e aplicar() completa.
static func preparar() -> bool:
	var d := _ler(ARQ)
	if d.is_empty():
		return false
	Jogo.modo = d.modo
	Jogo.semente = d.semente
	Jogo.mortes = d.get("mortes", 0)
	Jogo.carregar = true
	return true

static func aplicar(m: Node) -> bool:
	var d := _ler(ARQ)
	if d.is_empty():
		return false
	m.dia = d.dia
	m.hora = d.hora
	m.abates = d.abates
	m.estoque.clear()
	m.estoque.merge(d.estoque, true)
	m.conhecidos.clear()
	m.conhecidos.merge(d.conhecidos, true)
	m.marcadores.assign(d.marcadores)
	m._avisou_marco = d.get("avisou_marco", {})
	if d.has("clima"):
		m.clima.carregar(d.clima)
	if d.has("progresso"):
		m.progresso.carregar(d.progresso)
	if d.has("comercio"):
		m.comercio.carregar(d.comercio)
	# mundo (antes de gerar os chunks de novo)
	var w: WorldGen = m.mundo
	for k in d.mundo:
		var alvo: Dictionary = w.get(k)
		alvo.clear()
		alvo.merge(d.mundo[k], true)
	# picape e trailer
	# saves antigos não têm os módulos novos: completa com os padrões
	var pc: Dictionary = d.picape.config
	for k in m.picape.config:
		if not pc.has(k):
			pc[k] = m.picape.config[k].duplicate()
	m.picape.config = pc
	m.picape.cor = d.picape.cor
	m.picape.condicao = d.picape.condicao
	m.picape.reconstruir()
	var tc: Dictionary = d.trailer.config
	for k in m.trailer.config:
		if not tc.has(k):
			tc[k] = m.trailer.config[k].duplicate()
	m.trailer.config = tc
	m.trailer.cor_pintura = d.trailer.cor
	m.trailer.condicao_carroceria = d.trailer.carroceria
	m.trailer.luz_vermelha = d.trailer.luz_vermelha
	m.trailer.reconstruir()
	# reboques
	var c: Comboio = m.comboio
	for rd in d.reboques:
		var r: Reboque = m._novo_reboque(rd.tipo, rd.nivel, rd.condicao)
		r.carregar(rd)
		r.comida = rd.get("comida", 0.0)
		r.agua = rd.get("agua", 0.0)
		r.trabalho = rd.get("trabalho", {})
		r.reconstruir()
		c.engatar(r, true)
	c.diesel = d.comboio.diesel
	c.odometro = d.comboio.odometro
	c.temperatura = d.comboio.temperatura
	c.posicionar_livre(d.comboio.pos, d.comboio.yaw, 0.0)
	w.atualizar(d.comboio.pos)
	# recrutas
	m.base.lista.clear()
	m.base.lista.append_array(d.recrutas)
	m.base.distribuir_camas()
	# defesa
	var df: Defesa = m.defesa
	df.estado = d.defesa.estado
	df.z_horda = d.defesa.z_horda
	df.defendidos = d.defesa.defendidos
	df.ativo = d.defesa.get("ativo", "")
	for id in df.estado:
		var es: Dictionary = df.estado[id]
		if es.get("fase", "") == "entre_ondas" and float(es.get("prox_onda_h", -1.0)) < 0.5:
			es.prox_onda_h = 2.0
	# jogador e equipamento
	var j: Player = m.jogador
	var jd: Dictionary = d.jogador
	for k in ["vida", "sede", "fome", "estamina", "infeccao"]:
		j.set(k, jd[k])
	j.yaw = jd.yaw
	j.position = jd.pos
	j.position.y = j.chao(jd.pos)
	var e: Equipamento = m.equip
	e.pentes = d.equip.pentes
	e.cond_armas = d.equip.cond_armas
	e.armadura = d.equip.armadura
	j.atualizar_armadura(e.armadura)
	e.sel = ""
	e.selecionar(d.equip.sel if (d.equip.sel == "facao" or m.estoque.get(d.equip.sel, 0) > 0) else "facao")
	m._atualizar_ceu()
	if jd.get("dentro", false):
		m.call_deferred("_entrar_em", m.trailer)
	return true
