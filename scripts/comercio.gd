class_name Comercio
extends Node
## Comércio de verdade, reputação e facções de saqueadores.
##  - Cada lugar tem o que SOBRA (vende barato) e o que FALTA (paga caro). O preço
##    muda de vila para vila, então vale levar remédio de onde sobra para onde falta.
##  - A troca é por "crédito" com o comerciante: vender coloca crédito, comprar gasta.
##    O crédito fica guardado com aquele comerciante.
##  - Pedidos: "me traga 10 de remédio" — rende itens raros e reputação.
##  - Reputação por lugar: desconto, estoque melhor e, como aliado, presentes.
##  - Facções de saqueadores lembram de você: quem pagou passa de graça,
##    quem furou ou atirou paga em dobro (ou leva emboscada).

## valor-base de cada item (em "crédito")
const VALOR := {
	"comida": 4, "agua": 3, "carne_assada": 5, "carne_crua": 3, "remedio": 18, "bandagem": 6, "analgesico": 8,
	"pecas": 8, "sucata": 1, "pneu": 22, "eixo": 30, "chapa": 9, "cordame": 4, "tecido": 2, "garrafa": 1,
	"galoes_diesel": 28, "municao_pistola": 2, "cartucho": 3, "municao_rifle": 4, "virote": 2,
	"molotov": 9, "sinalizador": 7, "pele": 6, "couro": 12,
	"pistola": 60, "espingarda": 110, "rifle": 160, "machado": 25, "besta": 70,
	"colete_couro": 45, "capuz_couro": 25, "calca_couro": 35, "bracadeiras": 18,
}
## o que cada tipo de banca negocia
const BANCAS := {
	"geral": ["comida", "agua", "carne_assada", "galoes_diesel", "tecido", "garrafa", "cordame", "molotov", "sinalizador", "pele", "couro"],
	"pecas": ["pecas", "sucata", "pneu", "eixo", "chapa", "municao_pistola", "cartucho", "municao_rifle", "pistola", "espingarda", "rifle", "machado"],
	"remedio": ["remedio", "bandagem", "analgesico", "agua", "comida"],
	"marco": ["comida", "agua", "galoes_diesel", "pecas", "remedio", "bandagem", "municao_pistola", "cartucho", "municao_rifle", "rifle", "espingarda", "colete_couro"],
}
const RARIDADE := {"pistola": 1, "espingarda": 2, "rifle": 3, "besta": 2, "eixo": 1, "colete_couro": 2}
const NIVEIS_REP := [[0, "Desconhecido"], [20, "Conhecido"], [45, "Amigo"], [75, "Aliado"]]

const FACCOES := [
	{"nome": "Os Abutres", "cor": Color(0.85, 0.25, 0.15), "km": 0.0, "pedagio": 1.0},
	{"nome": "Irmandade do Asfalto", "cor": Color(0.25, 0.45, 0.85), "km": 15.0, "pedagio": 1.4},
	{"nome": "Carniceiros da BR", "cor": Color(0.55, 0.15, 0.55), "km": 40.0, "pedagio": 1.8},
	{"nome": "Reis do Sertão", "cor": Color(0.85, 0.7, 0.15), "km": 80.0, "pedagio": 2.2},
]

var main: Node
var lugares := {}       # id -> {rep, credito{banca:int}, estoque{banca:{item:n}}, dia_estoque, pedido{}}
var faccoes := {}       # nome -> {respeito, odio}
var _banca_aberta := {}  # {id, banca, nome}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

# ------------------------------------------------------------ dados do lugar
func _lugar(id: String) -> Dictionary:
	if not lugares.has(id):
		var r := RandomNumberGenerator.new()
		r.seed = hash(id + "mercado")
		var itens := VALOR.keys()
		var sobra := []
		var falta := []
		for i in 3:
			var it0: String = itens[r.randi() % itens.size()]
			if not sobra.has(it0):
				sobra.append(it0)
		for i in 3:
			var it: String = itens[r.randi() % itens.size()]
			if not sobra.has(it) and not falta.has(it):
				falta.append(it)
		# o que é escasso no mundo costuma faltar
		var escasso: String = ["remedio", "galoes_diesel", "municao_rifle", "pecas"][r.randi() % 4]
		if r.randf() < 0.5 and not falta.has(escasso) and not sobra.has(escasso):
			falta.append(escasso)
		lugares[id] = {"rep": 0.0, "credito": {}, "estoque": {}, "dia_estoque": -1, "sobra": sobra, "falta": falta, "pedido": {}}
	return lugares[id]

static func nivel_rep(rep: float) -> String:
	var n: String = NIVEIS_REP[0][1]
	for nv in NIVEIS_REP:
		if rep >= nv[0]:
			n = nv[1]
	return n

func desconto(id: String) -> float:
	var rep: float = _lugar(id).rep
	return 0.0 if rep < 20 else (0.05 if rep < 45 else (0.12 if rep < 75 else 0.2))

func reputacao(id: String, delta: float, motivo := "") -> void:
	var l := _lugar(id)
	var antes := nivel_rep(l.rep)
	l.rep = clampf(l.rep + delta, -50.0, 100.0)
	var depois := nivel_rep(l.rep)
	if depois != antes and delta > 0.0:
		main.hud.aviso("Reputação: agora você é %s aqui%s." % [depois.to_lower(), (" (" + motivo + ")") if motivo != "" else ""])

## Multiplicador de preço do item neste lugar.
func _mult(id: String, item: String) -> float:
	var l := _lugar(id)
	var m := 1.0
	if l.sobra.has(item):
		m = 0.6
	elif l.falta.has(item):
		m = 1.7
	# longe do começo tudo fica mais caro (e diesel ainda mais)
	var km: float = main._foco().z / 1000.0
	m *= 1.0 + clampf(km / 120.0, 0.0, 0.6)
	if item == "galoes_diesel":
		m *= 1.0 + clampf(km / 60.0, 0.0, 1.0)
	return m

func preco_compra(id: String, item: String) -> int:
	return maxi(1, int(round(VALOR[item] * _mult(id, item) * (1.0 - desconto(id)))))

func preco_venda(id: String, item: String) -> int:
	return maxi(1, int(round(VALOR[item] * _mult(id, item) * (0.55 + desconto(id) * 0.5))))

func _estoque_banca(id: String, banca: String) -> Dictionary:
	var l := _lugar(id)
	var dia: int = main.dia
	if l.dia_estoque != dia or not l.estoque.has(banca):
		if l.dia_estoque != dia:
			l.estoque = {}
		l.dia_estoque = dia
		var r := RandomNumberGenerator.new()
		r.seed = hash([id, banca, dia])
		var e := {}
		var rep: float = l.rep
		for item in BANCAS[banca]:
			var rar: int = RARIDADE.get(item, 0)
			if rar > 0 and rep < 20.0 * rar - 5.0 and r.randf() < 0.85:
				continue   # coisa rara só para quem já é conhecido
			if r.randf() < (0.85 if l.sobra.has(item) else 0.55):
				var base := 1 if VALOR[item] > 40 else (r.randi_range(2, 8) if VALOR[item] > 6 else r.randi_range(4, 18))
				if l.sobra.has(item):
					base *= 2
				if l.falta.has(item):
					base = maxi(0, base / 3)
				if base > 0:
					e[item] = base
		l.estoque[banca] = e
	return l.estoque[banca]

# ------------------------------------------------------------ painel de troca
## Banca de um NPC (ou "" se ele não comercia).
static func banca_de(h: Node3D) -> String:
	var ch: String = h.get_meta("chave", "")
	var fn: String = h.get_meta("funcao", "")
	if ch.begins_with("marco:") and fn == "vendedor":
		return "marco"
	if ch.ends_with(":vend_pecas"):
		return "pecas"
	if ch.ends_with(":vend_remedio"):
		return "remedio"
	if fn == "vendedor":
		return "geral"
	return ""

static func lugar_de(h: Node3D) -> String:
	var ch: String = h.get_meta("chave", "")
	# chave = "<id do lugar>:<quem>" (o id do lugar pode ter ":" no meio)
	var i := ch.rfind(":")
	return ch.substr(0, i) if i > 0 else ch

func abrir(h: Node3D) -> void:
	_banca_aberta = {"id": lugar_de(h), "banca": banca_de(h), "nome": h.get_meta("nome", "Comerciante"), "fala": h.get_meta("fala", "")}
	_lugar(_banca_aberta.id)
	main._abrir_painel(painel)

func painel() -> Dictionary:
	var id: String = _banca_aberta.get("id", "")
	if id == "":
		return {"titulo": "", "linhas": [], "botoes": []}
	var banca: String = _banca_aberta.banca
	var l := _lugar(id)
	var cred: int = l.credito.get("lugar", 0)
	var linhas: Array = ["\"%s\"" % _banca_aberta.fala]
	var nomes_sobra := []
	for it in l.sobra:
		nomes_sobra.append(main.ITENS[it].nome.to_lower() if main.ITENS.has(it) else it)
	var nomes_falta := []
	for it in l.falta:
		nomes_falta.append(main.ITENS[it].nome.to_lower() if main.ITENS.has(it) else it)
	linhas.append(["Aqui sobra: %s.   Aqui falta: %s." % [", ".join(nomes_sobra), ", ".join(nomes_falta)], Color(0.7, 0.7, 0.68)])
	linhas.append(["Reputação: %s (%d)%s   ·   Seu crédito neste lugar: %d" % [nivel_rep(l.rep), int(l.rep), ("  ·  desconto de %d%%" % int(desconto(id) * 100.0)) if desconto(id) > 0.0 else "", cred], Hud.DOURADO])
	linhas.append(["Venda o que tem para ganhar crédito; o crédito vale em todas as bancas daqui.", Color(0.7, 0.7, 0.68)])
	var botoes: Array = []
	# pedido
	var ped: Dictionary = l.pedido
	if ped.is_empty() and l.rep >= -10.0:
		ped = _novo_pedido(id, banca)
		l.pedido = ped
	if not ped.is_empty():
		var tem: int = main.estoque.get(ped.item, 0)
		var txt_rec := "%d %s" % [ped.premio_qtd, main.ITENS[ped.premio].nome.to_lower()]
		linhas.append(["Pedido: \"Me traga %d %s.\" Recompensa: %s + reputação. (Você tem %d.)" % [ped.qtd, main.ITENS[ped.item].nome.to_lower(), txt_rec, tem], Color(0.6, 0.85, 0.6)])
		botoes.append(["Entregar pedido", _entregar.bind(id), tem >= ped.qtd])
	# vender: o que o jogador tem e esta banca compra
	for item in BANCAS[banca]:
		var tem: int = main.estoque.get(item, 0)
		if tem <= 0:
			continue
		var pv := preco_venda(id, item)
		var lote := _lote(item)
		var n := mini(lote, tem)
		botoes.append(["Vender %d %s (+%d)" % [n, main.ITENS[item].nome.to_lower(), pv * n], _vender.bind(id, banca, item, n), true])
	# comprar: estoque da banca
	var est := _estoque_banca(id, banca)
	for item in est:
		var pc := preco_compra(id, item)
		var lote := mini(_lote(item), est[item])
		botoes.append(["Comprar %d %s (−%d)" % [lote, main.ITENS[item].nome.to_lower(), pc * lote], _comprar.bind(id, banca, item, lote), cred >= pc * lote])
	if botoes.is_empty():
		linhas.append("Você não tem nada que interesse e a banca está vazia hoje.")
	return {"titulo": "%s — troca" % _banca_aberta.nome, "subtitulo": {"geral": "Mantimentos e utilidades", "pecas": "Peças, ferragens e armas", "remedio": "Remédios", "marco": "Armazém do marco"}[banca], "linhas": linhas, "botoes": botoes}

func _lote(item: String) -> int:
	if VALOR[item] <= 2:
		return 10
	if VALOR[item] <= 5:
		return 3
	return 1

func _vender(id: String, banca: String, item: String, n: int) -> String:
	if main.estoque.get(item, 0) < n:
		return "Você não tem isso."
	var l := _lugar(id)
	var ganho := preco_venda(id, item) * n
	main.estoque[item] -= n
	l.credito["lugar"] = l.credito.get("lugar", 0) + ganho
	var est := _estoque_banca(id, banca)
	est[item] = est.get(item, 0) + n
	reputacao(id, 0.6 + (1.5 if l.falta.has(item) else 0.0), "trouxe o que faltava" if l.falta.has(item) else "")
	Som.tela("clique_ui", -6.0)
	return "Vendido: %d %s (+%d de crédito)." % [n, main.ITENS[item].nome.to_lower(), ganho]

func _comprar(id: String, banca: String, item: String, n: int) -> String:
	var l := _lugar(id)
	var custo := preco_compra(id, item) * n
	if l.credito.get("lugar", 0) < custo:
		return "Crédito insuficiente."
	var entrou: int = main.adicionar(item, n)
	if entrou <= 0:
		return "Não cabe na carga."
	var pago := preco_compra(id, item) * entrou
	l.credito["lugar"] -= pago
	var est := _estoque_banca(id, banca)
	est[item] -= entrou
	if est[item] <= 0:
		est.erase(item)
	reputacao(id, 0.4)
	Som.tela("clique_ui", -6.0)
	return "Comprado: %d %s (−%d)." % [entrou, main.ITENS[item].nome.to_lower(), pago]

func _novo_pedido(id: String, banca: String) -> Dictionary:
	var l := _lugar(id)
	var r := RandomNumberGenerator.new()
	r.seed = hash([id, banca, main.dia, "pedido"])
	var opcoes: Array = l.falta.filter(func(x): return VALOR.get(x, 0) <= 30)
	if opcoes.is_empty():
		opcoes = ["remedio", "comida", "pecas", "galoes_diesel"]
	var item: String = opcoes[r.randi() % opcoes.size()]
	var qtd := clampi(int(60.0 / VALOR[item]), 2, 20)
	var premios := ["municao_rifle", "pneu", "remedio", "galoes_diesel", "chapa", "molotov"]
	if l.rep >= 40.0:
		premios += ["rifle", "espingarda", "colete_couro"]
	var premio: String = premios[r.randi() % premios.size()]
	var pq := maxi(1, int(round(VALOR[item] * qtd * 1.5 / VALOR[premio])))
	return {"item": item, "qtd": qtd, "premio": premio, "premio_qtd": pq}

func _entregar(id: String) -> String:
	var l := _lugar(id)
	var ped: Dictionary = l.pedido
	if ped.is_empty() or main.estoque.get(ped.item, 0) < ped.qtd:
		return "Você ainda não tem o suficiente."
	main.estoque[ped.item] -= ped.qtd
	var entrou: int = main.adicionar(ped.premio, ped.premio_qtd)
	l.pedido = {}
	l.dia_pedido = main.dia
	reputacao(id, 14.0, "pedido entregue")
	return "Pedido entregue! Você recebeu %d %s." % [entrou, main.ITENS[ped.premio].nome.to_lower()]

## Presente diário de quem é aliado (chamado ao chegar no lugar).
func presente_aliado(id: String) -> String:
	var l := _lugar(id)
	if l.rep < 75.0 or l.get("dia_presente", -1) == main.dia:
		return ""
	l.dia_presente = main.dia
	var it: String = ["comida", "agua", "municao_pistola", "remedio", "galoes_diesel"][_rng.randi() % 5]
	var n: int = main.adicionar(it, 1 if VALOR[it] > 10 else 4)
	return "Os aliados daqui separaram um presente: %d %s." % [n, main.ITENS[it].nome.to_lower()] if n > 0 else ""

# ------------------------------------------------------------ facções
func faccao_em(z: float) -> Dictionary:
	var km := z / 1000.0
	var f: Dictionary = FACCOES[0]
	for fc in FACCOES:
		if km >= fc.km:
			f = fc
	return f

func _fac(nome: String) -> Dictionary:
	if not faccoes.has(nome):
		faccoes[nome] = {"respeito": 0, "odio": 0}
	return faccoes[nome]

## O que a facção acha de você: "amigo", "neutro", "inimigo".
func relacao(nome: String) -> String:
	var f := _fac(nome)
	if f.odio >= 2:
		return "inimigo"
	if f.respeito >= 2 and f.odio == 0:
		return "amigo"
	return "neutro"

func registrar_faccao(nome: String, resultado: String) -> void:
	var f := _fac(nome)
	match resultado:
		"pagou":
			f.respeito += 1
		"furou", "atirou":
			f.odio += 1
		"desviou":
			pass

func salvar() -> Dictionary:
	return {"lugares": lugares.duplicate(true), "faccoes": faccoes.duplicate(true)}

func carregar(d: Dictionary) -> void:
	lugares = d.get("lugares", {})
	faccoes = d.get("faccoes", {})
