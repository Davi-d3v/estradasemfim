class_name VidaRecrutas
## A vida dos recrutas: personalidade (traço), experiência e nível na função,
## amizades, brigas e casais, luto e túmulos na beira da estrada, e quem vai embora.
## Os dados ficam no próprio Dictionary do recruta (salvo junto com ele).

const TRACOS := {
	"corajoso": {"nome": "Corajoso", "fem": "Corajosa", "desc": "Não recua na luta até estar quase morto."},
	"medroso": {"nome": "Medroso", "fem": "Medrosa", "desc": "Às vezes larga o posto e corre para o trailer quando os zumbis chegam."},
	"otimista": {"nome": "Otimista", "fem": "Otimista", "desc": "Levanta o ânimo de todo mundo."},
	"rabugento": {"nome": "Rabugento", "fem": "Rabugenta", "desc": "Briga fácil, mas trabalha direito."},
	"trabalhador": {"nome": "Trabalhador", "fem": "Trabalhadora", "desc": "Aprende rápido o próprio ofício."},
	"preguicoso": {"nome": "Preguiçoso", "fem": "Preguiçosa", "desc": "Aprende devagar, mas nunca reclama."},
	"leal": {"nome": "Leal", "fem": "Leal", "desc": "Nunca abandona o comboio, nem com fome."},
	"ganancioso": {"nome": "Ganancioso", "fem": "Gananciosa", "desc": "Se for embora, leva mais coisa junto."},
}

## Nível 1 a 5 na função: cada nível rende 15% a mais.
const XP_NIVEL := [0.0, 10.0, 25.0, 45.0, 70.0]
const TITULOS := ["novato", "experiente", "bom", "veterano", "mestre"]

# ------------------------------------------------------------ dados
## Completa campos que faltam (recrutas antigos de saves anteriores, ou recém-chegados).
static func garantir(rc: Dictionary) -> void:
	if not rc.has("traco"):
		var ks := TRACOS.keys()
		rc.traco = ks[absi(hash(str(rc.get("id", rc.nome)) + "traco")) % ks.size()]
	if not rc.has("xp"):
		rc.xp = 0.0
	if not rc.has("nivel"):
		rc.nivel = 1
	if not rc.has("relacoes"):
		rc.relacoes = {}
	if not rc.has("par"):
		rc.par = ""
	if not rc.has("dias"):
		rc.dias = 0

const MASCULINOS_EM_A := ["Zeca", "Juca", "Luca", "Joca", "Bira", "Nicola", "Seu Zé"]

static func fem(rc: Dictionary) -> bool:
	return eh_nome_feminino(String(rc.nome))

static func eh_nome_feminino(n: String) -> bool:
	if n in MASCULINOS_EM_A or n.begins_with("Seu "):
		return false
	return n in Recrutas.FEMININOS or n.begins_with("Dona ") or n in ["Lurdes", "Socorro", "Bia", "Nina", "Lili", "Duda", "Graça"] or (n.ends_with("a") and not n.ends_with("ça"))

static func txt_traco(rc: Dictionary) -> String:
	garantir(rc)
	var t: Dictionary = TRACOS[rc.traco]
	return t.fem if fem(rc) else t.nome

static func txt_nivel(rc: Dictionary) -> String:
	garantir(rc)
	if rc.funcao in ["crianca", "idoso"]:
		return ""
	return "nível %d (%s)" % [rc.nivel, TITULOS[rc.nivel - 1]]

## Multiplicador do rendimento pelo nível.
static func mult(rc: Dictionary) -> float:
	return 1.0 + 0.15 * (int(rc.get("nivel", 1)) - 1)

## Ganha experiência no ofício; devolve texto se subiu de nível.
static func ganhar_xp(base: Node, rc: Dictionary, q: float) -> void:
	garantir(rc)
	var f := 1.0
	match rc.traco:
		"trabalhador": f = 1.5
		"preguicoso": f = 0.55
	if base.n("idoso") > 0 and rc.funcao != "idoso":
		f *= 1.25          # alguém mais velho ensinando
	rc.xp += q * f
	while rc.nivel < 5 and rc.xp >= XP_NIVEL[rc.nivel]:
		rc.nivel += 1
		base.registro.append("%s agora é %s %s na função de %s." % [rc.nome, "uma" if fem(rc) else "um", TITULOS[rc.nivel - 1], Recrutas.titulo(rc).to_lower()])
		rc.moral = clampf(rc.moral + 0.1, 0.0, 1.0)

static func relacao(a: Dictionary, b: Dictionary) -> float:
	return float(a.get("relacoes", {}).get(b.id, 0.0))

static func _mudar_relacao(a: Dictionary, b: Dictionary, d: float) -> void:
	garantir(a)
	garantir(b)
	a.relacoes[b.id] = clampf(relacao(a, b) + d, -1.0, 1.0)
	b.relacoes[a.id] = clampf(relacao(b, a) + d, -1.0, 1.0)

static func par_de(lista: Array, rc: Dictionary) -> Dictionary:
	if String(rc.get("par", "")) == "":
		return {}
	for o in lista:
		if o.id == rc.par:
			return o
	return {}

static func txt_relacao(v: float) -> String:
	if v > 0.6:
		return "muito amigos"
	if v > 0.25:
		return "amigos"
	if v < -0.6:
		return "se odeiam"
	if v < -0.25:
		return "se estranham"
	return "se conhecem"

# ------------------------------------------------------------ o dia a dia
## Chamado uma vez por dia (depois da refeição). r: RNG do dia.
static func dia(base: Node, r: RandomNumberGenerator) -> void:
	var lista: Array = base.lista
	var presentes: Array = lista.filter(func(x): return x.expedicao.is_empty() and x.vida > 0.0)
	for rc in lista:
		garantir(rc)
		rc.dias += 1
	# ânimo de quem está por perto
	var anima := 0.0
	for rc in presentes:
		match rc.traco:
			"otimista": anima += 0.025
			"rabugento": anima -= 0.015
	anima += 0.03 * base.n("crianca") + 0.02 * base.n("idoso")
	for rc in presentes:
		rc.moral = clampf(rc.moral + anima - (0.02 if rc.traco == "otimista" and anima > 0.0 else 0.0), 0.0, 1.0)
	# casais: ficam juntos e se animam
	for rc in presentes:
		if not par_de(lista, rc).is_empty():
			rc.moral = clampf(rc.moral + 0.03, 0.0, 1.0)
	# um ou dois encontros por dia entre pares de recrutas
	if presentes.size() >= 2:
		for vez in mini(3, presentes.size() - 1):
			var a: Dictionary = presentes[r.randi() % presentes.size()]
			var b: Dictionary = presentes[r.randi() % presentes.size()]
			if a == b:
				continue
			_encontro(base, a, b, r)
	# quem está pensando em ir embora
	for rc in lista.duplicate():
		if not rc.expedicao.is_empty():
			continue
		if rc.moral < 0.3 and rc.moral >= 0.15 and r.randf() < 0.5:
			base.registro.append("%s anda calad%s, olhando para a estrada." % [rc.nome, "a" if fem(rc) else "o"])
		if rc.moral < 0.15:
			if rc.traco == "leal" or rc.funcao == "crianca":
				if r.randf() < 0.5:
					base.registro.append("%s está no limite, mas disse que não abandona o comboio." % rc.nome)
				continue
			_ir_embora(base, rc, r)

static func _encontro(base: Node, a: Dictionary, b: Dictionary, r: RandomNumberGenerator) -> void:
	var briguento := 0
	for x in [a, b]:
		if x.traco in ["rabugento", "ganancioso"]:
			briguento += 1
	var fome: bool = base.main.estoque.get("comida", 0) <= base.lista.size()
	var p_briga := 0.12 + 0.18 * briguento + (0.2 if fome else 0.0)
	var rel := relacao(a, b)
	if r.randf() < p_briga:
		_mudar_relacao(a, b, -0.3)
		a.moral = clampf(a.moral - 0.06, 0.0, 1.0)
		b.moral = clampf(b.moral - 0.06, 0.0, 1.0)
		var motivos := ["pela última lata de feijão", "por causa de quem dorme perto da porta", "por causa do barulho à noite",
			"por quem devia ter ficado de vigia", "por uma faca que sumiu", "por nada, e por tudo"]
		base.registro.append("%s e %s brigaram %s." % [a.nome, b.nome, motivos[r.randi() % motivos.size()]])
		if relacao(a, b) < -0.7 and r.randf() < 0.35:
			# briga feia: alguém se machuca
			var ferido: Dictionary = a if r.randf() < 0.5 else b
			ferido.vida = maxf(0.2, ferido.vida - 0.2)
			base.registro.append("A briga ficou feia: %s saiu machucad%s." % [ferido.nome, "a" if fem(ferido) else "o"])
		# casal que se odeia termina
		if a.par == b.id and relacao(a, b) < -0.2:
			a.par = ""
			b.par = ""
			base.registro.append("%s e %s não estão mais juntos." % [a.nome, b.nome])
		return
	_mudar_relacao(a, b, r.randf_range(0.14, 0.3))
	rel = relacao(a, b)
	if rel > 0.6 and a.par == "" and b.par == "" and a.funcao != "crianca" and b.funcao != "crianca" and r.randf() < 0.3:
		a.par = b.id
		b.par = a.id
		base.registro.append("%s e %s estão juntos agora. O comboio inteiro já sabia." % [a.nome, b.nome])
		a.moral = clampf(a.moral + 0.15, 0.0, 1.0)
		b.moral = clampf(b.moral + 0.15, 0.0, 1.0)
	elif r.randf() < 0.3:
		var cenas := ["passaram a noite contando histórias de antes", "dividiram um cigarro na caçamba", "consertaram juntos a porta do reboque",
			"riram de alguma coisa que ninguém mais entendeu", "cantaram baixinho perto da fogueira"]
		base.registro.append("%s e %s %s." % [a.nome, b.nome, cenas[r.randi() % cenas.size()]])

static func _ir_embora(base: Node, rc: Dictionary, r: RandomNumberGenerator) -> void:
	var main: Node = base.main
	base.lista.erase(rc)
	base._remover_no(rc)
	var leva := {"comida": mini(2, main.estoque.get("comida", 0))}
	if rc.traco == "ganancioso":
		leva.comida = mini(5, main.estoque.get("comida", 0))
		leva.agua = mini(3, main.estoque.get("agua", 0))
		for arma in ["pistola", "espingarda", "rifle"]:
			if main.estoque.get(arma, 0) > 0 and main.equip.sel != arma:
				leva[arma] = 1
				break
	var itens: Array[String] = []
	for k in leva.keys():
		if leva[k] <= 0:
			leva.erase(k)
			continue
		main.estoque[k] = main.estoque.get(k, 0) - leva[k]
	for k in leva:
		var it: Dictionary = main.ITENS[k]
		itens.append("%d %s" % [leva[k], it.get("um", it.nome.to_lower()) if leva[k] == 1 else it.nome.to_lower()])
	# o par vai junto, às vezes
	var par := par_de(base.lista, rc)
	var txt := "%s foi embora durante a noite%s." % [rc.nome, (" levando " + ", ".join(itens)) if not itens.is_empty() else ""]
	if not par.is_empty():
		if r.randf() < 0.5 and par.traco != "leal":
			base.lista.erase(par)
			base._remover_no(par)
			txt = "%s e %s foram embora juntos durante a noite%s." % [rc.nome, par.nome, (" levando " + ", ".join(itens)) if not itens.is_empty() else ""]
		else:
			par.par = ""
			par.moral = clampf(par.moral - 0.3, 0.0, 1.0)
	base.registro.append(txt)
	for o in base.lista:
		o.moral = clampf(o.moral - 0.05, 0.0, 1.0)
	base.distribuir_camas()

# ------------------------------------------------------------ morte e luto
static func luto(base: Node, rc: Dictionary, pos: Vector3, tumulo := true) -> void:
	var main: Node = base.main
	for o in base.lista:
		if o == rc:
			continue
		var perda := 0.12 + maxf(0.0, relacao(o, rc)) * 0.25
		if o.get("par", "") == rc.id:
			perda = 0.45
			o.par = ""
			base.registro.append("%s perdeu %s. Não falou com ninguém o dia inteiro." % [o.nome, rc.nome])
		o.moral = clampf(o.moral - perda, 0.0, 1.0)
	if not tumulo:
		return
	# túmulo na beira da estrada
	var w: WorldGen = main.mundo
	var p := pos
	if p == Vector3.ZERO:
		p = main.trailer.global_position
	var z := p.z
	var lado := 1.0 if (p.x - w.centro_x(z)) >= 0.0 else -1.0
	var t := w.ponto_estrada(z, lado * (WorldGen.LARG_ESTRADA * 0.5 + 1.4))
	var k := int(floor(z / WorldGen.TAM))
	var l: Array = w.tumulos.get(k, [])
	l.append({"pos": t, "nome": rc.nome, "dia": main.dia})
	w.tumulos[k] = l
	w.construir_tumulo(t, rc.nome, main.dia)
