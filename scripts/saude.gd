class_name Saude
extends Node
## Sobrevivência além da fome e sede: sono/cansaço, doenças (gripe, intoxicação,
## ferida inflamada) e comida quente feita na fogueira (café, sopa, ensopado).

const DOENCAS := {
	"gripe": {"nome": "Gripe", "desc": "Fôlego curto (estamina até 60%) e tosse que os zumbis ouvem."},
	"intoxicacao": {"nome": "Intoxicação alimentar", "desc": "Sede o tempo todo e o corpo fraco."},
	"ferida": {"nome": "Ferida aberta", "desc": "Precisa de curativo em até 6 h, ou inflama."},
	"inflamada": {"nome": "Ferida inflamada", "desc": "Febre e vida caindo. Só antibiótico resolve."},
}

var main: Node
var cansaco := 0.15          # 0 descansado .. 1 caindo de sono
var doencas := {}            # id -> horas restantes (ferida: horas até inflamar)
var _t_tosse := 0.0
var _t_cochilo := 0.0
var _cochilando := 0.0
var _avisou_sono := 0.0
var _molhado := 0.0          # segundos tomando chuva sem abrigo

func salvar() -> Dictionary:
	return {"cansaco": cansaco, "doencas": doencas.duplicate()}

func carregar(d: Dictionary) -> void:
	cansaco = d.get("cansaco", 0.15)
	doencas = d.get("doencas", {}).duplicate()

func tem(id: String) -> bool:
	return doencas.has(id)

func pegar(id: String, horas: float, aviso := true) -> void:
	if doencas.has(id):
		doencas[id] = maxf(doencas[id], horas)
		return
	doencas[id] = horas
	if aviso:
		var txt: Variant = {"gripe": "Você pegou uma gripe. Fôlego curto e tosse alta: os zumbis vão ouvir.",
			"intoxicacao": "Algo que você comeu não caiu bem. Intoxicação alimentar.",
			"ferida": "A mordida abriu uma ferida. Faça um curativo nas próximas 6 h.",
			"inflamada": "A ferida inflamou. Febre. Só antibiótico resolve."}[id]
		main.hud.aviso(txt)

func curar(id: String) -> void:
	doencas.erase(id)

# ------------------------------------------------------------ relógio (h horas de jogo)
func passar(h: float) -> void:
	var j: Player = main.jogador
	# sono
	if main.get("_dormindo"):
		cansaco = maxf(0.0, cansaco - h / 6.5)
	else:
		cansaco = minf(1.0, cansaco + h / 22.0 * (1.25 if main.comboio.dirigindo else 1.0))
		if cansaco > 0.85 and _avisou_sono <= 0.0:
			_avisou_sono = 3.0
			main.hud.aviso("Você mal consegue manter os olhos abertos. Precisa dormir.")
		_avisou_sono -= h
	# doenças
	for id in doencas.keys():
		doencas[id] -= h
		match id:
			"intoxicacao":
				j.sede = maxf(0.0, j.sede - 0.06 * h)
				j.vida = maxf(0.05, j.vida - 0.012 * h)
			"inflamada":
				j.vida = maxf(0.05, j.vida - 0.02 * h)
				doencas[id] = 999.0   # não sara sozinha
			"gripe":
				j.vida = maxf(0.05, j.vida - 0.003 * h)
		if doencas.has(id) and doencas[id] <= 0.0:
			doencas.erase(id)
			if id == "ferida":
				pegar("inflamada", 999.0)
			else:
				main.hud.aviso("%s passou." % DOENCAS[id].nome)

## Depois de uma noite de sono: frio e chuva sem abrigo dão gripe.
func dormiu(horas: float, abrigado: bool) -> String:
	var clima: Node = main.get("clima")
	var molhado: bool = clima != null and (clima.chuva > 0.3 or clima.neve > 0.3)
	var inverno: bool = clima != null and clima.estacao() == "Inverno"
	var risco := 0.0
	if not abrigado:
		risco = 0.12 + (0.2 if molhado else 0.0) + (0.15 if inverno else 0.0)
	elif inverno:
		risco = 0.05
	if not tem("gripe") and randf() < risco:
		pegar("gripe", randf_range(40.0, 70.0), false)
		return "Você acordou com o nariz escorrendo e a garganta raspando: gripe."
	return ""

## Mordida ou arranhão: ferida aberta (a não ser que já esteja tratada).
func ferido_por_zumbi() -> void:
	if not tem("inflamada") and randf() < 0.45:
		pegar("ferida", 6.0)

## Comer: lata vencida às vezes faz mal; carne crua, muito mais.
func comeu(id: String) -> void:
	var chance: float = {"comida": 0.03, "carne_crua": 0.4}.get(id, 0.0)
	if chance > 0.0 and randf() < chance:
		pegar("intoxicacao", randf_range(10.0, 20.0))

## Itens que tratam doenças (chamado ao usar).
func tratar(id: String) -> String:
	var t := _tratar(id)
	for k in doencas.keys():
		if doencas[k] <= 0.0:
			doencas.erase(k)
	return t

func _tratar(id: String) -> String:
	match id:
		"bandagem":
			if tem("ferida"):
				curar("ferida")
				return " A ferida está limpa e coberta."
		"antibiotico":
			var t := ""
			if tem("inflamada") or tem("ferida"):
				t = " A febre vai baixar."
			curar("inflamada")
			curar("ferida")
			if tem("gripe"):
				doencas.gripe = minf(doencas.gripe, 12.0)
			return t
		"remedio", "analgesico":
			if tem("gripe"):
				doencas.gripe -= 15.0
				return " A gripe aliviou."
		"sopa", "cha":
			if tem("gripe"):
				doencas.gripe -= 20.0
			if tem("intoxicacao"):
				doencas.intoxicacao -= 6.0
			return " Quentinho por dentro."
		"cafe":
			cansaco = maxf(0.0, cansaco - 0.35)
			return " Acordou."
		"ensopado":
			cansaco = maxf(0.0, cansaco - 0.1)
	return ""

# ------------------------------------------------------------ por quadro
func atualizar(dt: float) -> void:
	var j: Player = main.jogador
	# gripe: fôlego curto e tosse
	if tem("gripe"):
		j.estamina = minf(j.estamina, 0.6)
		_t_tosse -= dt
		if _t_tosse <= 0.0:
			_t_tosse = randf_range(25.0, 50.0)
			Som.tela("esforco", -4.0, 0.2)
			main.ruido(j.global_position, 22.0)
			main.hud.aviso("*cof cof* (a tosse ecoou)")
	# tomar chuva por muito tempo sem abrigo dá gripe
	var cl: Node = main.get("clima")
	if cl and (cl.chuva > 0.4 or cl.neve > 0.4) and main.dentro == null and not main.comboio.dirigindo:
		_molhado += dt
		if _molhado > 240.0:
			_molhado = 0.0
			if not tem("gripe") and randf() < 0.35:
				pegar("gripe", randf_range(30.0, 60.0))
	else:
		_molhado = maxf(0.0, _molhado - dt * 0.5)
	# cansaço: estamina recupera menos; dirigindo, cochila
	if cansaco > 0.6:
		j.estamina = minf(j.estamina, lerpf(1.0, 0.55, (cansaco - 0.6) / 0.4))
	var c: Comboio = main.comboio
	if c.dirigindo and cansaco > 0.75 and absf(c.velocidade) > 5.0:
		_t_cochilo -= dt
		if _t_cochilo <= 0.0 and _cochilando <= 0.0:
			_t_cochilo = randf_range(25.0, 60.0) * lerpf(1.0, 0.4, (cansaco - 0.75) / 0.25)
			_cochilando = randf_range(0.8, 1.6)
			main.hud.aviso("Você cochilou ao volante!")
		if _cochilando > 0.0:
			_cochilando -= dt
			c.esterco = move_toward(c.esterco, 0.45, dt * 0.8)   # a picape vai saindo da pista
	else:
		_cochilando = 0.0
	main.hud.cochilo = clampf(_cochilando, 0.0, 1.0)
	main.hud.sono = 1.0 - cansaco
	main.hud.doencas = doencas.keys().map(func(id): return DOENCAS[id].nome)

func texto() -> String:
	var l: Array[String] = []
	l.append("Sono: %s" % ("descansado" if cansaco < 0.35 else ("cansado" if cansaco < 0.65 else ("exausto" if cansaco < 0.85 else "caindo de sono"))))
	for id in doencas:
		l.append("%s — %s" % [DOENCAS[id].nome, DOENCAS[id].desc])
	return "\n".join(l)
