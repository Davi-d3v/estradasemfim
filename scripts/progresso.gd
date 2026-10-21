class_name Progresso
extends Node
## Progresso sem fim: marcos (a Zona Segura é o primeiro), metas anunciadas pelo
## rádio (depósitos, comboios caídos, pedidos de socorro) e o mistério da horda
## (cartas e fitas achadas pelo caminho, guardadas no diário).

const MARCOS := [
	{"nome": "Zona Segura", "km": 40.0, "tema": "zona", "radio": "...aqui é a Zona Segura, km 40 da rodovia. Temos muro, água e médico. Venham durante o dia..."},
	{"nome": "Refinaria Esperança", "km": 95.0, "tema": "refinaria", "radio": "...Refinaria Esperança chamando. Temos diesel para quem chegar. Km 95. A estrada até aqui é ruim..."},
	{"nome": "Base Aérea Abandonada", "km": 155.0, "tema": "base", "radio": "...(chiado)... base aérea, km 155... os militares sabiam o que era a horda... os arquivos ainda estão lá..."},
	{"nome": "Usina da Serra", "km": 220.0, "tema": "usina", "radio": "...a Usina da Serra ainda tem luz. Quem chegar ganha uma cama e um lugar no muro. Km 220..."},
	{"nome": "Porto Seco", "km": 290.0, "tema": "porto", "radio": "...Porto Seco, km 290. Os navios não voltaram, mas os contêineres estão cheios..."},
]
## Depois da lista, marcos genéricos cada vez mais longe.
const NOMES_EXTRA := ["Posto Avançado", "Colônia do Fim", "Forte da Estrada", "Último Refúgio", "Cidade Murada"]

const TIPOS_MISSAO := {
	"diesel": {"nome": "Depósito de combustível", "radio": "...tem um depósito de combustível intacto perto do km %d. Ninguém conseguiu chegar ainda...", "tabela": "deposito_diesel"},
	"remedios": {"nome": "Hospital de campanha", "radio": "...hospital de campanha abandonado no km %d. Deixamos remédio lá quando fugimos...", "tabela": "hospital_campanha"},
	"militar": {"nome": "Comboio militar caído", "radio": "...um comboio do exército tombou no km %d. Carga intacta. Cuidado com os fardados...", "tabela": "militar"},
	"socorro": {"nome": "Pedido de socorro", "radio": "...SOCORRO! Estamos presos num posto no km %d, cercados! Por favor, alguém!...", "tabela": ""},
	"sinal": {"nome": "Sinal estranho", "radio": "...(bip... bip... bip)... sinal automático vindo do km %d. Parece uma gravação...", "tabela": ""},
}

## O mistério: cartas, fitas e páginas, na ordem em que contam a história.
const CARTAS := [
	["Bilhete num para-brisa", "\"Se achar isso, não vai para o norte. Eles vêm de lá. Todos vêm de lá. — R.\""],
	["Página de diário", "\"Dia 3. O rádio fala de 'surto respiratório'. Ninguém fala de gente mordendo gente. Mas eu vi.\""],
	["Fita cassete (gravada às pressas)", "\"...não é vírus comum, o laboratório da serra sabia... eles chamavam de Projeto Maré...\""],
	["Crachá queimado", "LABORATÓRIO SERRA ALTA — Dra. M. Salgado — Nível 4. No verso, à caneta: \"a maré sobe com o barulho\"."],
	["Carta de mãe", "\"Filho, seu pai saiu para buscar remédio e não voltou. Vou para a Zona Segura. Se ler isso, me procura lá.\""],
	["Relatório militar (rasgado)", "\"...os infectados se agrupam e migram em massa. Hipótese: seguem o som contínuo de motores e geradores...\""],
	["Fita cassete 2", "\"Dra. Salgado falando. Se alguém ouvir: a horda não é aleatória. Ela segue as estradas. Ela segue a gente.\""],
	["Mapa rabiscado", "Um mapa com a rodovia marcada de vermelho e um círculo: \"onde a maré começou\". Fica muito além da Usina da Serra."],
	["Diário de caminhoneiro", "\"Rodei 400 km sem parar. Quando parei, eles chegaram em duas horas. Quanto mais longe, mais rápido eles vêm.\""],
	["Fita cassete 3", "\"...tem uma cura? Não. Tem um jeito de parar? Talvez. O sinal do laboratório chama a maré. Se desligar o sinal...\""],
	["Ordem de evacuação", "\"Todo o pessoal civil deve seguir para a Refinaria Esperança. A Zona Segura será abandonada.\" Assinado, Cel. Vidal."],
	["Página de diário 2", "\"A Zona Segura caiu? Não. Ela continua de pé. O coronel mentiu para levar todo mundo para longe.\""],
	["Fita cassete 4", "\"Dra. Salgado. Última gravação. O sinal está na base aérea. Eles transmitem de lá. Que Deus me perdoe.\""],
	["Carta sem assinatura", "\"Os da base aérea não são militares. São o que sobrou do Projeto Maré. Eles querem a horda viva.\""],
	["Caderno de rádio", "Frequências anotadas. Uma delas circulada três vezes: \"a que ninguém responde\"."],
	["Última página", "\"Se a maré segue o som, então quem controla o som controla a maré. A estrada não acaba. Nem eles.\""],
]

var main: Node
var marco_idx := 0               # próximo marco a alcançar
var alcancados: Array = []
var missoes := {}                # id -> {tipo, z, lat, k, prazo, estado}
var cartas: Array = []           # índices já achados
var _proxima_id := 1
var _t_radio := 2.0              # horas de jogo até o rádio anunciar algo
var _premio_aberto := -1
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

## Marco i (infinito: depois da lista, a cada 65–80 km).
static func marco(i: int) -> Dictionary:
	if i < MARCOS.size():
		return MARCOS[i]
	var ult: Dictionary = MARCOS[MARCOS.size() - 1]
	var n := i - MARCOS.size() + 1
	var km: float = ult.km + n * 72.0
	var nome: String = "%s %d" % [NOMES_EXTRA[(n - 1) % NOMES_EXTRA.size()], int(km)]
	return {"nome": nome, "km": km, "tema": ["zona", "refinaria", "base", "usina", "porto"][n % 5],
		"radio": "...%s, km %d. Ainda tem gente aqui. Ainda tem muro. Venham..." % [nome, int(km)]}

func z_marco(i: int) -> float:
	return float(marco(i).km) * 1000.0

## Registra os marcos no gerador do mundo (chamar no início e depois de carregar).
func registrar_no_mundo() -> void:
	for i in range(maxi(0, marco_idx - 1), marco_idx + 2):
		var k := int(floor(z_marco(i) / WorldGen.TAM))
		main.mundo.pois_fixos[k] = "marco"
		main.mundo.marcos_k[k] = i
	for id in missoes:
		var ms: Dictionary = missoes[id]
		if ms.estado == "ativa" or ms.estado == "feita":
			main.mundo.pois_fixos[ms.k] = "missao"
			main.mundo.missoes_k[ms.k] = id

# ------------------------------------------------------------ a cada quadro
func atualizar(dt: float) -> void:
	var foco: Vector3 = main._foco()
	# chegou no marco
	var zm := z_marco(marco_idx)
	if foco.z > zm - 30.0 and absf(foco.x - main.mundo.centro_x(zm)) < 60.0 and _premio_aberto < 0:
		_chegou(marco_idx)
	if _premio_aberto >= 0:
		if main.comboio.dirigindo:
			main.comboio.velocidade = 0.0
		if not main.painel.visible:
			main._abrir_painel(_painel_premio)
		return
	# missões: concluir, expirar
	for id in missoes.keys():
		var ms: Dictionary = missoes[id]
		if ms.estado != "ativa":
			continue
		if ms.tipo == "socorro":
			_checar_socorro(id, ms, foco)
		elif ms.tipo == "sinal":
			if main.mundo.vasculhados.has("missao:%d" % id):
				_concluir(id, "Você achou a origem do sinal: uma van com o rádio ainda ligado.")
		elif main.mundo.vasculhados.has("missao:%d" % id):
			_concluir(id, "%s saqueado." % TIPOS_MISSAO[ms.tipo].nome)

## Horas de jogo passando (rádio, prazos).
func passar(h: float) -> void:
	_t_radio -= h
	for id in missoes:
		var ms: Dictionary = missoes[id]
		if ms.estado == "ativa" and ms.prazo > 0.0:
			ms.prazo -= h
			if ms.prazo <= 0.0:
				ms.estado = "falhou"
				_tirar_marcador(ms)
				main.hud.aviso("O rádio silenciou. Ninguém mais responde do km %d." % int(ms.z / 1000.0))
				main.registrar("Você não chegou a tempo no km %d." % int(ms.z / 1000.0))
	if _t_radio <= 0.0 and main.jogando and not main.capturando:
		_t_radio = _rng.randf_range(5.0, 10.0)
		if _ativas() < 2:
			nova_missao()

func _ativas() -> int:
	var n := 0
	for id in missoes:
		if missoes[id].estado == "ativa":
			n += 1
	return n

# ------------------------------------------------------------ marcos
func _chegou(i: int) -> void:
	_premio_aberto = i
	if not alcancados.has(i):
		alcancados.append(i)
	var mc := marco(i)
	main.hud.banner(String(mc.nome).to_upper(), "Você chegou. Marco %d alcançado." % (i + 1))
	Som.tela("radio_estatica", -8.0)
	if main.comboio.dirigindo:
		main.comboio.velocidade = 0.0
	main._abrir_painel(_painel_premio)

const RECRUTAS_ESPECIAIS := [["Sargento Lima", "vigia"], ["Dra. Helena", "medico"], ["Mestre Dito", "mecanico"],
	["Dona Cida", "agricultor"], ["Kauã", "batedor"], ["Tenente Rosa", "vigia"], ["Seu Bené", "mecanico"]]
const REBOQUES_PREMIO := ["tanque", "oficina", "estufa", "apartamentos", "armazem", "plataforma"]

func _painel_premio() -> Dictionary:
	var i := _premio_aberto
	if i < 0:
		return {"titulo": "", "linhas": [], "botoes": []}
	var mc := marco(i)
	var reb: String = REBOQUES_PREMIO[i % REBOQUES_PREMIO.size()]
	if i >= 1 and i % 2 == 1:
		reb = ["hospital", "radio", "destilaria", "torreta"][(i / 2) % 4]   # raros a partir do segundo marco
	var esp: Array = RECRUTAS_ESPECIAIS[i % RECRUTAS_ESPECIAIS.size()]
	var prox := marco(i + 1)
	return {"titulo": String(mc.nome).to_upper(), "subtitulo": "Muro de contêineres, gente armada nas torres e cheiro de comida quente. Por uma noite, dá para respirar.",
		"linhas": ["O responsável oferece uma recompensa a quem chega até aqui. Escolha uma:",
			["Próximo marco anunciado no rádio: %s, km %d." % [prox.nome, int(prox.km)], Color(0.7, 0.7, 0.68)]],
		"botoes": [
			["Reboque: %s (nível 3)" % Reboque.TIPOS[reb].nome, func(): return _premio(i, "reboque", reb), main.comboio.cadeia.size() < 7],
			["Recruta: %s (%s experiente)" % [esp[0], Recrutas.FUNCOES[esp[1]].nome.to_lower()], func(): return _premio(i, "recruta", esp), true],
			["Conserto completo + diesel, comida, água e munição", func(): return _premio(i, "suprimentos", ""), true],
		]}

func _premio(i: int, tipo: String, dado) -> String:
	var txt := ""
	match tipo:
		"reboque":
			var r: Reboque = main._novo_reboque(dado, 3, 1.0)
			if r.tipo == "tanque":
				r.litros = r.capacidade() * 0.8 if r.has_method("capacidade") else 400.0
			r.reconstruir()
			main.comboio.engatar(r, true)
			txt = "Um %s novo foi engatado no fim do comboio." % Reboque.TIPOS[dado].nome.to_lower()
		"recruta":
			var rc := Recrutas.novo(dado[0], dado[1], _rng.randi())
			rc.moral = 0.95
			rc.especial = true
			rc.nivel = 3
			main.base.lista.append(rc)
			main.base.distribuir_camas()
			txt = "%s se junta ao comboio. Dizem que nunca errou um tiro — ou um diagnóstico." % dado[0]
		"suprimentos":
			for slot in main.picape.config:
				main.picape.config[slot].condicao = 1.0
			for slot in main.trailer.config:
				main.trailer.config[slot].condicao = 1.0
			main.picape.condicao = 1.0
			main.trailer.condicao_carroceria = 1.0
			main.picape.reconstruir()
			main.trailer.reconstruir()
			main.comboio.diesel = main.comboio.tanque()
			for k in {"comida": 15, "agua": 15, "galoes_diesel": 2, "municao_pistola": 30, "cartucho": 12, "municao_rifle": 15, "remedio": 3, "bandagem": 4}.keys():
				main.adicionar(k, {"comida": 15, "agua": 15, "galoes_diesel": 2, "municao_pistola": 30, "cartucho": 12, "municao_rifle": 15, "remedio": 3, "bandagem": 4}[k])
			txt = "Picape e trailer consertados, tanque cheio e a carga reforçada."
	# o marco sempre rende uma peça do mistério
	var carta := _proxima_carta()
	if carta >= 0:
		txt += "\nNo mural de recados você acha: %s." % CARTAS[carta][0].to_lower()
	marco_idx = i + 1
	_premio_aberto = -1
	registrar_no_mundo()
	main.call_deferred("_fechar_janela")
	main.hud.relatorio = txt + "\n\nRádio: " + String(marco(marco_idx).radio)
	main.hud.relatorio_titulo = String(marco(i).nome)
	main.hud.relatorio_t = 10.0
	main.salvar_jogo(true)
	return ""

# ------------------------------------------------------------ missões do rádio
func nova_missao(tipo := "") -> int:
	var foco: Vector3 = main._foco()
	if tipo == "":
		var tipos := ["diesel", "remedios", "socorro", "sinal"]
		if marco_idx >= 1:
			tipos.append("militar")
		tipo = tipos[_rng.randi() % tipos.size()]
	var z := foco.z + _rng.randf_range(2600.0, 6000.0)
	# não em cima de marco
	if absf(z - z_marco(marco_idx)) < 600.0:
		z += 900.0
	var k := int(floor(z / WorldGen.TAM))
	while main.mundo.pois_fixos.has(k) or main.mundo._chunks.has(k):
		k += 1
	var id := _proxima_id
	_proxima_id += 1
	var lado := -1.0 if _rng.randf() < 0.5 else 1.0
	var ms := {"tipo": tipo, "k": k, "z": k * WorldGen.TAM + 32.0, "lat": lado * _rng.randf_range(16.0, 24.0),
		"prazo": _rng.randf_range(9.0, 15.0) if tipo == "socorro" else -1.0, "estado": "ativa", "sem": _rng.randi()}
	missoes[id] = ms
	main.mundo.pois_fixos[k] = "missao"
	main.mundo.missoes_k[k] = id
	var alvo: Vector3 = main.mundo.ponto_estrada(ms.z, ms.lat)
	ms.marcador = alvo
	main.marcadores.append(alvo)
	var txt: String = TIPOS_MISSAO[tipo].radio % int(ms.z / 1000.0)
	main.hud.mensagem_radio = txt
	main.hud.relatorio = txt + ("\n(Prazo: ~%d horas)" % int(ms.prazo) if ms.prazo > 0.0 else "")
	main.hud.relatorio_titulo = "Rádio"
	main.hud.relatorio_t = 8.0
	main._t_radio = 3.0
	return id

func _tirar_marcador(ms: Dictionary) -> void:
	if ms.has("marcador"):
		var alvo: Vector3 = ms.marcador
		main.marcadores.assign(main.marcadores.filter(func(m): return m.distance_to(alvo) > 1.0))

func _concluir(id: int, txt: String) -> void:
	var ms: Dictionary = missoes[id]
	ms.estado = "feita"
	_tirar_marcador(ms)
	if ms.tipo == "sinal":
		var c := _proxima_carta()
		if c >= 0:
			txt += "\nNo banco do motorista: %s." % CARTAS[c][0].to_lower()
	main.hud.relatorio = txt
	main.hud.relatorio_titulo = TIPOS_MISSAO[ms.tipo].nome
	main.hud.relatorio_t = 7.0

func _checar_socorro(id: int, ms: Dictionary, foco: Vector3) -> void:
	var c: Vector3 = main.mundo.ponto_estrada(ms.z, ms.lat)
	if Vector2(foco.x - c.x, foco.z - c.z).length() > 22.0:
		return
	for z in main.mundo.zumbis_vivos:
		if is_instance_valid(z) and z.get_meta("missao", -1) == id and z.vivo():
			return
	# todos os zumbis do cerco caíram: os sobreviventes saem
	var nomes := []
	var r := RandomNumberGenerator.new()
	r.seed = ms.sem
	for i in r.randi_range(1, 3):
		var nome: String = Eventos.NOMES[r.randi() % Eventos.NOMES.size()]
		var fn: String = ["vigia", "medico", "mecanico", "agricultor", "batedor"][r.randi() % 5]
		var rc := Recrutas.novo(nome, fn, r.randi())
		rc.moral = 0.9
		main.base.lista.append(rc)
		nomes.append(nome)
	main.base.distribuir_camas()
	main.adicionar("comida", r.randi_range(2, 6))
	main.adicionar("municao_pistola", r.randi_range(6, 14))
	_concluir(id, "Os sobreviventes saem do posto: %s. Eles agradecem e entram para o comboio." % ", ".join(nomes))

# ------------------------------------------------------------ mistério
func _proxima_carta() -> int:
	for i in CARTAS.size():
		if not cartas.has(i):
			cartas.append(i)
			main.hud.banner("Achou: " + CARTAS[i][0], "Leia no diário [J]")
			return i
	return -1

## Chance de achar uma peça do mistério ao vasculhar (chamado pelo main).
func talvez_carta(chave: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(chave + "carta")
	if r.randf() > 0.06:
		return ""
	var c := _proxima_carta()
	return "" if c < 0 else CARTAS[c][0]

func painel_diario() -> Dictionary:
	var linhas: Array = []
	if cartas.is_empty():
		linhas.append("Nada ainda. Cartas, fitas e páginas aparecem no saque, nos marcos e nos sinais do rádio.")
	for i in cartas:
		linhas.append([CARTAS[i][0].to_upper(), Hud.DOURADO])
		linhas.append(CARTAS[i][1])
	var marcos_txt := []
	for i in alcancados:
		marcos_txt.append(marco(i).nome)
	var prox := marco(marco_idx)
	linhas.append(["Marcos alcançados: %s" % (", ".join(marcos_txt) if not marcos_txt.is_empty() else "nenhum"), Color(0.7, 0.7, 0.68)])
	linhas.append(["Próximo: %s, km %d (faltam %.1f km)" % [prox.nome, int(prox.km), maxf(0.0, (z_marco(marco_idx) - main._foco().z) / 1000.0)], Color(0.7, 0.7, 0.68)])
	return {"titulo": "DIÁRIO DA ESTRADA", "subtitulo": "%d de %d peças da história" % [cartas.size(), CARTAS.size()], "linhas": linhas, "botoes": []}

## Ponto do mundo para onde o objetivo aponta: a missão ativa mais próxima ou o próximo marco.
func alvo() -> Dictionary:
	var foco: Vector3 = main._foco()
	var melhor := -1
	var dmin := INF
	for id in missoes:
		var ms: Dictionary = missoes[id]
		if ms.estado == "ativa":
			var d: float = ms.z - foco.z
			if d > -200.0 and d < dmin:
				dmin = d
				melhor = id
	if melhor >= 0 and dmin <= 9000.0:
		var ms: Dictionary = missoes[melhor]
		return {"pos": main.mundo.ponto_estrada(ms.z, ms.lat), "nome": TIPOS_MISSAO[ms.tipo].nome}
	var prox := marco(marco_idx)
	return {"pos": main.mundo.ponto_estrada(z_marco(marco_idx), 0.0), "nome": String(prox.nome)}

## Texto do objetivo no HUD enquanto dirige.
func objetivo() -> Array:
	var foco: Vector3 = main._foco()
	var prox := marco(marco_idx)
	var sub := "%s em %.1f km" % [prox.nome, maxf(0.0, (z_marco(marco_idx) - foco.z) / 1000.0)]
	var melhor := -1
	var dmin := INF
	for id in missoes:
		var ms: Dictionary = missoes[id]
		if ms.estado == "ativa":
			var d: float = ms.z - foco.z
			if d > -200.0 and d < dmin:
				dmin = d
				melhor = id
	if melhor >= 0:
		var ms: Dictionary = missoes[melhor]
		var txt: String = "%s: %.1f km" % [TIPOS_MISSAO[ms.tipo].nome, maxf(0.0, dmin / 1000.0)]
		if ms.prazo > 0.0:
			txt += " (prazo %d h)" % int(ceil(ms.prazo))
		return [prox.nome if dmin > 9000.0 else TIPOS_MISSAO[ms.tipo].nome, txt + " · " + sub]
	return ["Rumo a: " + String(prox.nome), sub]

func salvar() -> Dictionary:
	var ms := missoes.duplicate(true)
	return {"marco_idx": marco_idx, "alcancados": alcancados.duplicate(), "missoes": ms, "cartas": cartas.duplicate(), "proxima_id": _proxima_id, "t_radio": _t_radio}

func carregar(d: Dictionary) -> void:
	marco_idx = d.get("marco_idx", 0)
	alcancados = d.get("alcancados", [])
	missoes = d.get("missoes", {})
	cartas = d.get("cartas", [])
	_proxima_id = d.get("proxima_id", 1)
	_t_radio = d.get("t_radio", 3.0)
	registrar_no_mundo()
