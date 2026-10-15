extends Node3D
## Cena principal: mundo procedural, ciclo dia/noite, comboio, jogador, interiores e HUD.

@export var hora := 18.78
@export var velocidade_tempo := 1.0 / 60.0  # horas de jogo por segundo real
@export var dia := 3

## Volume que cada item ocupa na carga.
const ITENS := {
	"pecas": {"nome": "Peças", "vol": 1.0},
	"sucata": {"nome": "Sucata", "vol": 0.5},
	"comida": {"nome": "Comida", "vol": 1.0},
	"agua": {"nome": "Água", "vol": 1.0},
	"galoes_diesel": {"nome": "Galões de diesel (20 L)", "um": "galão de diesel (20 L)", "vol": 3.0},
	"pneu": {"nome": "Pneus", "um": "pneu", "vol": 5.0},
	"eixo": {"nome": "Eixos", "um": "eixo", "vol": 8.0},
	"remedio": {"nome": "Remédios", "um": "remédio", "vol": 0.5},
	# armas
	"pe_de_cabra": {"nome": "Pés de cabra", "um": "pé de cabra", "vol": 2.0},
	"taco": {"nome": "Tacos com pregos", "um": "taco com pregos", "vol": 2.0},
	"machado": {"nome": "Machados", "um": "machado", "vol": 3.0},
	"pistola": {"nome": "Pistolas", "um": "pistola", "vol": 1.5},
	"espingarda": {"nome": "Espingardas", "um": "espingarda", "vol": 4.0},
	"rifle": {"nome": "Rifles", "um": "rifle", "vol": 4.0},
	"besta": {"nome": "Bestas", "um": "besta", "vol": 3.0},
	# munição
	"municao_pistola": {"nome": "Balas 9 mm", "um": "bala 9 mm", "vol": 0.05},
	"cartucho": {"nome": "Cartuchos 12", "um": "cartucho 12", "vol": 0.1},
	"municao_rifle": {"nome": "Balas de rifle", "um": "bala de rifle", "vol": 0.08},
	"virote": {"nome": "Virotes", "um": "virote", "vol": 0.15},
	# consumíveis
	"bandagem": {"nome": "Bandagens", "um": "bandagem", "vol": 0.3},
	"analgesico": {"nome": "Analgésicos", "um": "analgésico", "vol": 0.2},
	"molotov": {"nome": "Coquetéis molotov", "um": "coquetel molotov", "vol": 1.0},
	"sinalizador": {"nome": "Sinalizadores", "um": "sinalizador", "vol": 0.5},
	"carne_crua": {"nome": "Carne crua", "um": "pedaço de carne crua", "vol": 1.0},
	"carne_assada": {"nome": "Carne assada", "um": "pedaço de carne assada", "vol": 1.0},
	# materiais
	"tecido": {"nome": "Retalhos de tecido", "um": "retalho de tecido", "vol": 0.3},
	"garrafa": {"nome": "Garrafas vazias", "um": "garrafa vazia", "vol": 0.5},
	"pele": {"nome": "Peles cruas", "um": "pele crua", "vol": 2.0},
	"couro": {"nome": "Couro curtido", "um": "couro curtido", "vol": 1.5},
	"chapa": {"nome": "Chapas de metal", "um": "chapa de metal", "vol": 2.0},
	"cordame": {"nome": "Cordas", "um": "corda", "vol": 0.5},
	# armaduras
	"capuz_couro": {"nome": "Capuzes de couro", "um": "capuz de couro", "vol": 1.5},
	"colete_couro": {"nome": "Coletes de couro", "um": "colete de couro", "vol": 3.0},
	"calca_couro": {"nome": "Calças de couro", "um": "calça de couro", "vol": 2.5},
	"bracadeiras": {"nome": "Braçadeiras de couro", "um": "par de braçadeiras", "vol": 1.0},
	# exploração
	"binoculo": {"nome": "Binóculos", "um": "binóculo", "vol": 1.0},
	# saúde e cozinha
	"antibiotico": {"nome": "Antibióticos", "um": "antibiótico", "vol": 0.2},
	"po_cafe": {"nome": "Pó de café", "um": "pacote de café", "vol": 0.4},
	"cafe": {"nome": "Café quente", "um": "copo de café", "vol": 0.5},
	"sopa": {"nome": "Sopa", "um": "pote de sopa", "vol": 1.0},
	"ensopado": {"nome": "Ensopado de caça", "um": "pote de ensopado", "vol": 1.0},
	"lanterna": {"nome": "Lanternas", "um": "lanterna", "vol": 0.5},
	"cartao_militar": {"nome": "Cartões de acesso militar", "um": "cartão de acesso militar", "vol": 0.05},
	"chaves_presidio": {"nome": "Molhos de chaves do presídio", "um": "molho de chaves do presídio", "vol": 0.2},
	"chave_cofre": {"nome": "Chaves de cofre", "um": "chave de cofre", "vol": 0.05},
}
## Custo para construir um reboque na oficina móvel (além do projeto).
const CUSTO_CONSTRUCAO := {"pneu": 2, "eixo": 1, "sucata": 60, "pecas": 15}
const NOMES_TIPO := {"armazem": "Armazém", "tanque": "Tanque de diesel", "oficina": "Oficina móvel", "estufa": "Estufa", "plataforma": "Plataforma de carga", "apartamentos": "Apartamentos",
	"hospital": "Hospital de campanha", "radio": "Torre de rádio", "destilaria": "Destilaria", "torreta": "Blindado com torreta"}

var mundo: WorldGen
var sol: DirectionalLight3D
var ambiente: Environment
var ceu: ShaderMaterial
var jogador: Player
var hud: Hud
var trailer: Trailer
var picape: Pickup
var comboio: Comboio
var oficina: Oficina
var painel: Painel
var fp: PrimeiraPessoa
var dentro: Node3D = null          # veículo em que o jogador está (primeira pessoa)
var estoque := {"pecas": 9, "sucata": 30, "galoes_diesel": 2, "comida": 5, "agua": 6, "pneu": 1, "eixo": 0, "remedio": 1, "pistola": 1, "municao_pistola": 14, "bandagem": 2, "sinalizador": 1, "tecido": 2, "garrafa": 1, "projetos": []}
var _tempo := 0.0
var capturando := false
var _rng_radio := RandomNumberGenerator.new()
var _rng_eventos := RandomNumberGenerator.new()
var marcadores: Array[Vector3] = []
var menu: Menu
var jogando := false
var _t_motor := 0.0
var _t_horda_noturna := 0.0
var _morto := false
var abates := 0
## Lugares descobertos: id -> {nome, tipo, pos, regiao}
var conhecidos := {}
var acampamento: Node3D = null
var _regiao_atual := -1
var _avisou_marco := {}
var _t_mapa := 0.0
var base: BaseRecrutas
var fumacas: Node3D
var cinzas: CPUParticles3D
var equip: Equipamento
var tutorial: Tutorial
var eventos: Eventos
var clima: Clima
var progresso: Progresso
var combate_comboio: CombateComboio
var comercio: Comercio
var cachorro: Cachorro = null
var comboio_extra: ComboioExtra
var exploracao: Exploracao
var saude: Saude
var _dormindo := false
var horda_visivel: HordaVisivel
var retrovisor: Retrovisor
var _t_autosave := 0.0
var _t_radio := 0.0
var _compartimento_preso := false     # prints: deixa a porta aberta ao fechar o painel
var criacao: Criacao
var defesa: Defesa
var recrutas_nos: Array:
	get:
		if not base:
			return []
		if defesa and not defesa.nos.is_empty():
			return base.nos + defesa.nos
		return base.nos
## O que se acha ao vasculhar cada tipo de lugar: item -> [mín, máx, chance]
const TABELAS := {
	"casa": {"po_cafe": [1, 1, 0.25], "comida": [1, 4, 0.9], "agua": [1, 3, 0.8], "pecas": [0, 2, 0.5], "galoes_diesel": [1, 1, 0.2], "municao_pistola": [3, 8, 0.15], "bandagem": [1, 2, 0.3], "tecido": [1, 3, 0.4], "garrafa": [1, 2, 0.3]},
	"celeiro": {"comida": [3, 7, 1.0], "sucata": [2, 6, 0.7], "pecas": [0, 1, 0.3]},
	"galpao": {"pecas": [2, 5, 1.0], "sucata": [6, 14, 1.0], "pneu": [1, 2, 0.4], "eixo": [1, 1, 0.3], "pe_de_cabra": [1, 1, 0.2], "machado": [1, 1, 0.1], "cordame": [1, 2, 0.4], "garrafa": [1, 3, 0.3]},
	"container": {"sucata": [4, 10, 1.0], "pecas": [1, 3, 0.7], "galoes_diesel": [1, 2, 0.3], "chapa": [1, 2, 0.25], "cordame": [1, 2, 0.3]},
	"poco": {"agua": [4, 8, 1.0]},
	"loja": {"po_cafe": [1, 3, 0.4], "comida": [3, 8, 1.0], "agua": [2, 6, 0.9], "remedio": [0, 1, 0.2], "garrafa": [1, 3, 0.5], "bandagem": [0, 1, 0.2]},
	"farmacia": {"antibiotico": [1, 2, 0.45], "remedio": [2, 5, 1.0], "comida": [0, 2, 0.4], "agua": [1, 2, 0.5], "bandagem": [2, 5, 1.0], "analgesico": [1, 3, 0.8]},
	"estante": {"pecas": [0, 1, 0.3], "remedio": [0, 1, 0.15], "sucata": [0, 2, 0.4], "municao_pistola": [2, 6, 0.08], "sinalizador": [1, 1, 0.06]},
	"armario": {"po_cafe": [1, 1, 0.3], "comida": [1, 4, 0.85], "agua": [0, 2, 0.5]},
	"geladeira": {"comida": [0, 2, 0.4], "agua": [1, 3, 0.7]},
	"gaveta": {"pecas": [0, 1, 0.35], "remedio": [0, 1, 0.25], "sucata": [1, 2, 0.4], "municao_pistola": [2, 6, 0.12], "pistola": [1, 1, 0.025], "analgesico": [1, 1, 0.15], "lanterna": [1, 1, 0.08], "chave_cofre": [1, 1, 0.025]},
	"guarda_roupa": {"sucata": [1, 3, 0.5], "remedio": [0, 1, 0.12], "galoes_diesel": [1, 1, 0.05], "tecido": [1, 4, 0.6], "cartucho": [2, 4, 0.06], "espingarda": [1, 1, 0.02]},
	"banheiro": {"antibiotico": [1, 1, 0.12], "remedio": [1, 2, 0.6], "agua": [0, 1, 0.3], "bandagem": [1, 2, 0.4], "analgesico": [1, 1, 0.3]},
	"prateleira": {"comida": [1, 4, 0.8], "agua": [1, 3, 0.6], "remedio": [0, 1, 0.15]},
	"caixa": {"comida": [1, 5, 0.6], "sucata": [2, 6, 0.7], "pecas": [0, 2, 0.4], "pneu": [1, 1, 0.12], "sinalizador": [1, 1, 0.1], "garrafa": [1, 2, 0.3], "taco": [1, 1, 0.06]},
	"cacador": {"binoculo": [1, 1, 0.15], "lanterna": [1, 1, 0.15], "comida": [2, 5, 0.9], "remedio": [0, 1, 0.3], "galoes_diesel": [1, 1, 0.25], "pecas": [0, 2, 0.4], "espingarda": [1, 1, 0.3], "cartucho": [3, 8, 0.8], "besta": [1, 1, 0.12], "virote": [3, 6, 0.4], "pele": [1, 2, 0.4]},
	"acampamento": {"comida": [1, 3, 0.8], "agua": [1, 3, 0.8], "remedio": [0, 1, 0.3], "sucata": [1, 3, 0.5], "molotov": [1, 2, 0.3], "municao_pistola": [2, 6, 0.3], "bandagem": [1, 2, 0.4]},
	"torre": {"comida": [1, 2, 0.6], "agua": [1, 2, 0.6], "remedio": [1, 2, 0.4], "pecas": [0, 1, 0.3], "rifle": [1, 1, 0.15], "municao_rifle": [2, 6, 0.5], "sinalizador": [1, 2, 0.5], "binoculo": [1, 1, 0.3], "lanterna": [1, 1, 0.3], "chaves_presidio": [1, 1, 0.05]},
	"carro_mata": {"sucata": [3, 8, 1.0], "pecas": [1, 2, 0.6], "galoes_diesel": [1, 1, 0.3], "remedio": [0, 1, 0.2], "sinalizador": [1, 1, 0.3], "pistola": [1, 1, 0.06], "municao_pistola": [3, 9, 0.35]},
	"militar": {"cartao_militar": [1, 1, 0.07], "binoculo": [1, 1, 0.12], "lanterna": [1, 1, 0.2], "municao_rifle": [6, 18, 0.9], "municao_pistola": [6, 16, 0.8], "cartucho": [3, 8, 0.5], "comida": [2, 6, 0.8], "agua": [2, 5, 0.7], "bandagem": [1, 4, 0.7], "remedio": [1, 2, 0.5], "rifle": [1, 1, 0.25], "sinalizador": [1, 3, 0.5], "galoes_diesel": [1, 2, 0.5], "chapa": [1, 2, 0.3]},
	"deposito_diesel": {"galoes_diesel": [3, 6, 1.0], "pecas": [1, 3, 0.6], "sucata": [3, 8, 0.8], "molotov": [1, 3, 0.5]},
	"hospital_campanha": {"remedio": [3, 6, 1.0], "bandagem": [3, 8, 1.0], "analgesico": [2, 5, 0.9], "agua": [2, 5, 0.7], "comida": [1, 4, 0.5]},
	"arsenal": {"rifle": [1, 2, 0.9], "municao_rifle": [20, 45, 1.0], "espingarda": [1, 1, 0.5], "cartucho": [10, 24, 0.9], "pistola": [1, 2, 0.6], "municao_pistola": [20, 40, 0.9], "sinalizador": [2, 4, 0.7], "molotov": [2, 4, 0.4], "binoculo": [1, 1, 0.5], "lanterna": [1, 1, 0.6]},
	"almoxarifado": {"antibiotico": [1, 3, 0.6], "po_cafe": [2, 5, 0.8], "comida": [8, 16, 1.0], "agua": [6, 12, 1.0], "remedio": [2, 5, 0.9], "bandagem": [3, 8, 1.0], "tecido": [4, 10, 0.8], "lanterna": [1, 1, 0.5], "analgesico": [2, 4, 0.7]},
	"armaria": {"espingarda": [1, 2, 0.9], "cartucho": [12, 30, 1.0], "pistola": [1, 2, 0.8], "municao_pistola": [20, 40, 1.0], "colete_couro": [1, 1, 0.3]},
	"cofre": {"remedio": [3, 6, 0.9], "municao_rifle": [10, 25, 0.7], "galoes_diesel": [2, 3, 0.7], "binoculo": [1, 1, 0.4], "chaves_presidio": [1, 1, 0.3], "cartao_militar": [1, 1, 0.3]},
	"esconderijo": {"comida": [2, 6, 0.9], "agua": [2, 5, 0.8], "remedio": [1, 2, 0.4], "municao_pistola": [4, 12, 0.4], "galoes_diesel": [1, 1, 0.3], "lanterna": [1, 1, 0.2], "bandagem": [1, 3, 0.5]},
	"presidio": {"comida": [0, 2, 0.4], "tecido": [1, 3, 0.6], "sucata": [1, 4, 0.6], "taco": [1, 1, 0.1], "analgesico": [1, 2, 0.2], "chaves_presidio": [1, 1, 0.06]},
	"serraria": {"sucata": [5, 12, 1.0], "pecas": [1, 4, 0.8], "eixo": [1, 1, 0.15], "galoes_diesel": [1, 2, 0.35], "machado": [1, 1, 0.35], "cordame": [1, 3, 0.5]},
}
var _frame_fechou := -10

func _ready() -> void:
	capturando = "--capturar" in OS.get_cmdline_user_args()
	if "--carregar" in OS.get_cmdline_user_args():
		Salvar.preparar()
	_rng_eventos.seed = 12345
	_ambiente()
	mundo = WorldGen.new()
	# testes e prints precisam do mundo inteiro na hora; jogando, os trechos longe nascem aos poucos
	mundo.gradual = not capturando
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--teste") or arg == "--perfil" or arg == "--gradual-teste":
			mundo.gradual = arg == "--gradual-teste"
	if not capturando:
		mundo.definir_semente(Jogo.semente)
	mundo.pois_fixos = {0: "posto", 1: "placa"}
	add_child(mundo)
	_rig()
	base = BaseRecrutas.new()
	base.main = self
	add_child(base)
	defesa = Defesa.new()
	defesa.main = self
	add_child(defesa)
	jogador = Player.new()
	jogador.mundo = mundo
	add_child(jogador)
	jogador.position = mundo.ponto_estrada(-4.0, -0.6)
	_acoes_extras()
	equip = Equipamento.new()
	equip.main = self
	add_child(equip)
	criacao = Criacao.new()
	criacao.main = self
	mundo.atualizar(jogador.position)
	_horda()
	fp = PrimeiraPessoa.new()
	add_child(fp)
	fp.interagiu.connect(_acao_interior)
	var cl := CanvasLayer.new()
	add_child(cl)
	hud = Hud.new()
	hud.jogador = jogador
	hud.dia = dia
	hud.estoque = estoque
	cl.add_child(hud)
	oficina = Oficina.new()
	oficina.trailer = trailer
	oficina.picape = picape
	oficina.comboio = comboio
	oficina.estoque = estoque
	oficina.desengatar.connect(_desengatar)
	oficina.visible = false
	oficina.fechado.connect(_fechar_janela)
	cl.add_child(oficina)
	painel = Painel.new()
	painel.fechado.connect(_fechar_janela)
	cl.add_child(painel)
	var som := Som.new()
	som.main = self
	add_child(som)
	eventos = Eventos.new()
	eventos.main = self
	add_child(eventos)
	clima = Clima.new()
	clima.main = self
	add_child(clima)
	progresso = Progresso.new()
	progresso.main = self
	add_child(progresso)
	combate_comboio = CombateComboio.new()
	combate_comboio.main = self
	add_child(combate_comboio)
	comercio = Comercio.new()
	comercio.main = self
	add_child(comercio)
	progresso.registrar_no_mundo()
	# o primeiro cachorro aparece cedo na estrada (se não for aceito, outros aparecem depois)
	if not mundo.pois_fixos.has(12):
		mundo.pois_fixos[12] = "evento"
		mundo.eventos_tipo[12] = "cachorro"
	comboio_extra = ComboioExtra.new()
	comboio_extra.main = self
	add_child(comboio_extra)
	exploracao = Exploracao.new()
	exploracao.main = self
	add_child(exploracao)
	saude = Saude.new()
	saude.main = self
	add_child(saude)
	horda_visivel = HordaVisivel.new()
	horda_visivel.main = self
	add_child(horda_visivel)
	retrovisor = Retrovisor.new()
	retrovisor.main = self
	cl.add_child(retrovisor)
	tutorial = Tutorial.new()
	tutorial.main = self
	cl.add_child(tutorial)
	menu = Menu.new()
	menu.escolheu.connect(_comecar)
	menu.continuar.connect(_acordar_apos_queda)
	menu.recomecar.connect(_novo_jogo)
	menu.carregar.connect(_carregar_jogo)
	cl.add_child(menu)
	menu.visible = false
	_atualizar_ceu()
	if capturando:
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		if "--trailer" in OS.get_cmdline_user_args():
			_capturar_trailer()
		elif "--eventos" in OS.get_cmdline_user_args():
			_capturar_eventos()
		elif "--saude" in OS.get_cmdline_user_args():
			_capturar_saude()
		elif "--defesa2" in OS.get_cmdline_user_args():
			_capturar_defesa2()
		elif "--exploracao" in OS.get_cmdline_user_args():
			_capturar_exploracao()
		elif "--reboques-raros" in OS.get_cmdline_user_args():
			_capturar_raros()
		elif "--vida" in OS.get_cmdline_user_args():
			_capturar_vida()
		elif "--cachorro" in OS.get_cmdline_user_args():
			_capturar_cachorro()
		elif "--acampamento" in OS.get_cmdline_user_args():
			_capturar_acampamento()
		elif "--refino" in OS.get_cmdline_user_args():
			_capturar_refino()
		elif "--comercio" in OS.get_cmdline_user_args():
			_capturar_comercio()
		elif "--comboio-combate" in OS.get_cmdline_user_args():
			_capturar_combate_comboio()
		elif "--progresso" in OS.get_cmdline_user_args():
			_capturar_progresso()
		elif "--clima" in OS.get_cmdline_user_args():
			_capturar_clima()
		elif "--perigo" in OS.get_cmdline_user_args():
			_capturar_perigo()
		elif "--horda" in OS.get_cmdline_user_args():
			_capturar_horda()
		elif "--modelos" in OS.get_cmdline_user_args():
			_capturar_modelos()
		elif "--rodada5" in OS.get_cmdline_user_args():
			_capturar_r5()
		elif "--rodada4" in OS.get_cmdline_user_args():
			_capturar_defesa()
		elif "--rodada3" in OS.get_cmdline_user_args():
			_capturar_recrutas()
		else:
			_capturar()
	elif "--teste-defesa" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_defesa()
	elif "--teste-armas" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_armas()
	elif "--teste-recrutas" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_recrutas()
	elif "--fluidez" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_fluidez()
	elif "--perfil" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_perfil_chunks()
	elif "--teste-longo" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_longo()
	elif "--teste-saude" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_saude()
	elif "--teste-defesa2" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_defesa2()
	elif "--teste-exploracao" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_exploracao()
	elif "--teste-reboques" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_reboques()
	elif "--teste-vida" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_vida()
	elif "--teste-fisica" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_fisica()
	elif "--teste-cachorro" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_cachorro()
	elif "--teste-comercio" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_comercio()
	elif "--teste-comboio" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_comboio()
	elif "--teste-progresso" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_progresso()
	elif "--teste-clima" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_clima()
	elif "--teste-perigo" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_perigo()
	elif "--teste-eventos" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_eventos()
	elif "--teste-salvar" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste_salvar()
	elif "--teste" in OS.get_cmdline_user_args():
		Jogo.modo = Jogo.MODO_INFINITO
		jogando = true
		_teste()
	elif Jogo.carregar:
		Jogo.carregar = false
		jogando = true
		if Salvar.aplicar(self):
			hud.banner("Jogo carregado", "Dia %d · %.1f km rodados" % [dia, comboio.odometro / 1000.0])
		if "--carregar" in OS.get_cmdline_user_args() and "--sair" in OS.get_cmdline_user_args():
			await get_tree().process_frame
			var tipos: Array = []
			for i in range(1, comboio.cadeia.size()):
				tipos.append([comboio.cadeia[i].tipo, comboio.cadeia[i].nivel, comboio.cadeia[i].get("litros")])
			print("TC dia=", dia, " hora=", hora, " abates=", abates, " sucata=", estoque.sucata, " esping=", estoque.get("espingarda"), " reboques=", tipos,
				" recrutas=", base.lista.map(func(x): return x.nome), " diesel=", comboio.diesel, " odo=", comboio.odometro, " pos=", comboio.pos.snapped(Vector3.ONE * 0.1),
				" motor=", picape.config.motor.nivel, " despensa=", trailer.config.lateral_direita.nivel, " sel=", equip.sel, " pente=", equip.pentes.get("espingarda"),
				" armadura=", equip.armadura.keys(), " vida=", jogador.vida, " vasc=", mundo.vasculhados.has("teste:x"), " evento55=", mundo.eventos_feitos.get(55, {}), " horda=", defesa.z_horda, " modo=", Jogo.modo)
			get_tree().quit()
		_t_autosave = 0.0
	elif Jogo.modo == "":
		hud.visible = false
		jogador.set_process(false)
		menu.mostrar_inicio()
	else:
		jogando = true

## Teste do salvar: muda bastante coisa e salva. Depois rodar com --carregar e conferir.
func _teste_salvar() -> void:
	await get_tree().process_frame
	estoque.sucata = 77
	estoque.espingarda = 1
	estoque.cartucho = 9
	estoque.colete_couro = 1
	dia = 9
	hora = 13.5
	abates = 42
	picape.config.motor.nivel = 3
	trailer.config.lateral_direita.nivel = 3
	trailer.cor_pintura = Color(0.2, 0.4, 0.3)
	comboio.engatar(_novo_reboque("armazem", 2, 0.8), true)
	var tq := _novo_reboque("tanque", 1, 0.6)
	tq.litros = 123.0
	comboio.engatar(tq, true)
	print("TS cadeia=", comboio.cadeia.size())
	base.lista.append(Recrutas.novo("Tião", "vigia", 77))
	base.lista.append(Recrutas.novo("Marta", "medico", 78))
	comboio.diesel = 33.0
	comboio.odometro = 12345.0
	comboio.posicionar(900.0, -0.5, 0.0)
	jogador.position = comboio.pos + Vector3(3, 0, 0)
	equip.vestir("colete_couro")
	equip.selecionar("espingarda")
	equip.pentes["espingarda"] = 2
	jogador.vida = 0.66
	mundo.vasculhados["teste:x"] = true
	mundo.eventos_feitos[55] = {"tipo": "saqueadores", "resultado": "pagou"}
	defesa.z_horda = -3333.0
	var ok := Salvar.salvar(self)
	print("TS salvo=", ok, " resumo=", Salvar.resumo())
	get_tree().quit()

## Teste da etapa 9: lugares grandes, trancas, subsolo no escuro, binóculo e esconderijos.
func _teste_exploracao() -> void:
	await get_tree().process_frame
	for ri in 30:
		for l in mundo.lugares_da_regiao(ri):
			if l.tipo in ["base_militar", "presidio", "shopping"]:
				print("TX lugar: %s '%s' região %d km %.1f" % [l.tipo, l.nome, ri, l.pos.z / 1000.0])
	for t in ["base_militar", "presidio", "shopping", "fazenda"]:
		var l := _achar_lugar(t)
		if l.is_empty():
			for ri in range(12, 40):
				for ll in mundo.lugares_da_regiao(ri):
					if ll.tipo == t and l.is_empty():
						l = ll
		if l.is_empty():
			print("TX %s: não encontrado" % t)
			continue
		jogador.position = l.pos + Vector3(0, 0, 0)
		jogador.position.y = jogador.chao(jogador.position)
		mundo.atualizar(l.pos)
		await get_tree().process_frame
		var tr: Array = mundo.vasculhaveis.filter(func(v): return is_instance_valid(v) and v.has_meta("tranca") and v.global_position.distance_to(l.pos) < 80.0)
		var zs: int = mundo.zumbis_vivos.filter(func(z): return is_instance_valid(z) and z.global_position.distance_to(l.pos) < 70.0).size()
		var ss: Array = mundo.subsolos.filter(func(x): return is_instance_valid(x) and x.global_position.distance_to(l.pos) < 80.0)
		var est: int = mundo.estruturas.filter(func(x): return is_instance_valid(x) and x.global_position.distance_to(l.pos) < 80.0).size()
		print("TX %s: trancas=%d zumbis=%d subsolos=%d predios=%d" % [t, tr.size(), zs, ss.size(), est])
		if not tr.is_empty():
			var v: Node3D = tr[0]
			var pn := exploracao.painel_tranca(v)
			print("TX   tranca: %s | %s" % [pn.titulo, pn.linhas[0]])
			if t == "base_militar":
				estoque.pe_de_cabra = 1
				var z0 := mundo.zumbis_vivos.size()
				var h0 := hora
				pn.botoes[1][1].call()
				await get_tree().process_frame
				await get_tree().process_frame
				print("TX   arrombou: horas %.1f -> %.1f, zumbis %d -> %d, aberto=%s, rifles=%d" % [h0, hora, z0, mundo.zumbis_vivos.size(), str(not exploracao.trancado(v)), estoque.get("rifle", 0)])
			else:
				estoque[v.get_meta("tranca")] = 1
				pn.botoes[0][1].call()
				await get_tree().process_frame
				await get_tree().process_frame
				print("TX   chave: aberto=%s vasculhado=%s" % [str(not exploracao.trancado(v)), str(mundo.vasculhados.has(v.get_meta("chave")))])
		mundo.atualizar(l.pos)
		await get_tree().process_frame
		ss = mundo.subsolos.filter(func(x): return is_instance_valid(x) and x.global_position.distance_to(l.pos) < 80.0)
		if not ss.is_empty():
			var sb: Subsolo = ss[0]
			for luz in [false, true]:
				estoque.lanterna = 1 if luz else 0
				jogador.vida = 1.0
				jogador.infeccao = 0.0
				_entrar_em(sb)
				await get_tree().process_frame
				var its: Array = fp.interativos.map(func(x): return x.id)
				print("TX   %s (%s): ocupado=%s interativos=%s sol=%s amb=%.2f" % [sb.nome_exibicao(), "com lanterna" if luz else "no escuro", str(sb.ocupado), str(its), str(sol.visible), ambiente.ambient_light_energy])
				if its.size() > 1:
					_acao_interior(its[0])
					await get_tree().process_frame
					print("TX     vasculhou %s: vida %.2f infecção %.2f · %s" % [its[0], jogador.vida, jogador.infeccao, hud.relatorio.replace("\n", " ").substr(0, 90)])
				_sair_de_dentro()
				await get_tree().process_frame
			print("TX   saiu: sol=%s amb=%.2f" % [str(sol.visible), ambiente.ambient_light_energy])
	# binóculo
	var lb := _achar_lugar("vila")
	jogador.position = lb.pos + Vector3(0, 0, 40)
	jogador.position.y = jogador.chao(jogador.position)
	mundo.atualizar(jogador.position)
	await get_tree().process_frame
	jogador.yaw = atan2(lb.pos.x - jogador.position.x, lb.pos.z - jogador.position.z)
	estoque.binoculo = 1
	exploracao._alternar_zoom()
	for i in 3:
		await get_tree().process_frame
	exploracao._observar()
	print("TX binóculo: fov=%.0f marcados=%d texto='%s'" % [jogador.camera.fov, exploracao.marcados.size(), hud.binoculo_txt])
	exploracao._alternar_zoom()
	# pichações com esconderijo
	var n_p := 0
	var n_e := 0
	for k in range(3, 400):
		var r := RandomNumberGenerator.new()
		r.seed = hash([mundo.semente, k, "apoc"])
	print("TX esconderijos carregados: ", mundo.vasculhaveis.filter(func(v): return is_instance_valid(v) and String(v.get_meta("chave")).begins_with("esconderijo")).size())
	get_tree().quit()

## Teste da etapa 8: reboques raros, desgaste, álcool, torreta, rádio e visual.
func _teste_reboques() -> void:
	await get_tree().process_frame
	# sorteio dos raros por distância
	var cont := {}
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for km in [10.0, 60.0, 130.0]:
		var c := {}
		for i in 400:
			var t := Reboque.sortear_tipo(r, km * 1000.0)
			c[t] = c.get(t, 0) + 1
		print("TB sorteio km %d: %s" % [int(km), str(c)])
	for t in ["hospital", "radio", "destilaria", "torreta"]:
		comboio.engatar(_novo_reboque(t, 2, 1.0), true)
	print("TB cadeia: ", comboio.cadeia.map(func(x): return x.tipo if x is Reboque else x.name))
	await get_tree().process_frame
	# hospital
	jogador.vida = 0.4
	jogador.infeccao = 0.3
	estoque.tecido = 6
	var b0: int = estoque.get("bandagem", 0)
	_passar_tempo(10.0)
	print("TB hospital: vida 0.40 -> %.2f, infecção 0.30 -> %.2f, bandagens %d -> %d" % [jogador.vida, jogador.infeccao, b0, estoque.bandagem])
	# destilaria
	var dest := comboio_extra.reboque("destilaria")
	estoque.comida = 30
	comboio.diesel = 20.0
	var pn := comboio_extra.painel(dest)
	var msg = pn.botoes[0][1].call()
	_passar_tempo(4.5)
	print("TB destilaria: '%s' comida 30 -> %d, diesel 20 -> %.0f" % [msg, estoque.comida, comboio.diesel])
	# rádio
	comboio_extra._atualizar_radar()
	print("TB radio: %d itens no mapa; %s" % [comboio_extra.radar.size(), ", ".join(comboio_extra.radar.slice(0, 5).map(func(x): return "%.1f km %s" % [x.km, x.nome]))])
	print("TB radio horda: ", comboio_extra.texto_radio())
	# torreta
	estoque.municao_rifle = 30
	var tor := comboio_extra.reboque("torreta")
	var zs: Array = []
	for i in 4:
		var zp := tor.global_position + Vector3(8 + i * 2.0, 0, 6 - i * 3.0)
		zp.y = mundo.altura(zp.x, zp.z)
		var zb := mundo.criar_zumbi(mundo, zp, 0.0, 50 + i, "comum")
		zb.set_process(false)
		zs.append(zb)
	var t := 0.0
	while t < 8.0 and zs.any(func(z): return is_instance_valid(z) and z.vivo()):
		comboio_extra._torreta(0.05)
		t += 0.05
		await get_tree().process_frame
	print("TB torreta: %d/4 abatidos em %.1f s, munição 30 -> %d" % [zs.filter(func(z): return not z.vivo()).size(), t, estoque.municao_rifle])
	# desgaste: motor e pneu
	var m0: float = picape.config.motor.condicao
	comboio.dirigindo = true
	comboio.fora_da_estrada = true
	comboio.velocidade = 12.0
	var furou_em := -1.0
	for i in 3000:
		comboio_extra._desgaste(0.1, comboio)
		comboio.velocidade = 12.0
		if comboio_extra.pneu_furado and furou_em < 0.0:
			furou_em = i * 0.1 * 12.0
	comboio.dirigindo = false
	comboio.fora_da_estrada = false
	print("TB desgaste: 3,6 km fora da estrada: motor %.3f -> %.3f, pneu furou em %.0f m, limite %.1f m/s" % [m0, picape.config.motor.condicao, furou_em, comboio_extra.limite_velocidade()])
	estoque.pneu = 1
	print("TB troca: ", comboio_extra.trocar_pneu(), " furado=", comboio_extra.pneu_furado)
	# visual
	comboio_extra.nome_comboio = "ÚLTIMA PARADA"
	comboio_extra.trofeus = 3
	comboio_extra.aplicar_visual()
	print("TB visual: nome=", trailer.nome_comboio, " trofeus=", picape.trofeus)
	print("TB save=", Salvar.salvar(self), " extra=", comboio_extra.salvar())
	get_tree().quit()

## Teste da vida dos recrutas: traços, níveis, amizades, brigas, casais, quem vai embora, luto e túmulo.
func _teste_vida() -> void:
	await get_tree().process_frame
	comboio.engatar(_novo_reboque("apartamentos", 3, 1.0), true)
	comboio.engatar(_novo_reboque("estufa", 2, 1.0), true)
	var nomes := [["Tião", "vigia"], ["Marta", "medico"], ["Beto", "mecanico"], ["Rita", "agricultor"], ["Zeca", "batedor"], ["Seu Zé", "idoso"], ["Bia", "crianca"]]
	for i in nomes.size():
		var rc := Recrutas.novo(nomes[i][0], nomes[i][1], 100 + i)
		VidaRecrutas.garantir(rc)
		base.lista.append(rc)
	base.lista[0].traco = "rabugento"
	base.lista[4].traco = "ganancioso"
	base.distribuir_camas()
	estoque.merge({"comida": 200, "agua": 200, "sucata": 80, "pistola": 1}, true)
	trailer.condicao_carroceria = 0.5
	for rc in base.lista:
		print("TV %s: %s, %s, traço %s" % [rc.nome, Recrutas.titulo(rc), VidaRecrutas.txt_nivel(rc), VidaRecrutas.txt_traco(rc)])
	var eventos_txt: Array = []
	for d in 30:
		_passar_tempo(24.0)
		eventos_txt.append_array(base.relatorio())
	print("TV --- 30 dias, %d linhas no relatório; amostra:" % eventos_txt.size())
	var vistos := {}
	for l in eventos_txt:
		for pal in ["brigaram", "juntos", "agora é", "foi embora", "calad", "histórias", "machucad", "não abandona", "não estão mais"]:
			if pal in l and not vistos.has(pal):
				vistos[pal] = true
				print("TV   ", l)
	for rc in base.lista:
		var par := VidaRecrutas.par_de(base.lista, rc)
		print("TV %s: %s, moral %.2f, xp %.0f%s" % [rc.nome, VidaRecrutas.txt_nivel(rc), rc.moral, rc.xp, (", junto com " + par.nome) if not par.is_empty() else ""])
	# moral no chão: leal fica, ganancioso vai embora levando coisa
	for rc in base.lista:
		rc.moral = 0.05
	base.lista[1].traco = "leal"
	var antes := base.lista.size()
	var pist0: int = estoque.get("pistola", 0)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	VidaRecrutas.dia(base, r)
	print("TV moral zero: %d -> %d recrutas; ficaram: %s; pistola %d -> %d" % [antes, base.lista.size(), ", ".join(base.lista.map(func(x): return x.nome)), pist0, estoque.get("pistola", 0)])
	print("TV relatorio: ", " | ".join(base.relatorio()))
	# morte e luto
	if base.lista.size() >= 1:
		var morto: Dictionary = base.lista[0]
		for rc in base.lista:
			rc.moral = 0.8
		base.lista.erase(morto)
		VidaRecrutas.luto(base, morto, trailer.global_position)
		print("TV luto: túmulos=", mundo.tumulos, " moral dos outros=", base.lista.map(func(x): return snappedf(x.moral, 0.01)))
	var ok := Salvar.salvar(self)
	print("TV save=", ok)
	get_tree().quit()

## Teste do cachorro: adoção, seguir, latir, farejar, caçar, defender, caçamba e save.
## Física: zumbis não atravessam picape/trailer nem a cerca do acampamento; você passa pelo portão.
func _teste_fisica() -> void:
	await get_tree().process_frame
	comboio.set_physics_process(false)
	var z := 14 * WorldGen.TAM + 20.0
	comboio.posicionar(z, -0.5, 0.0)
	jogador.position = mundo.ponto_estrada(z, 6.0)
	mundo.atualizar(jogador.position)
	await get_tree().process_frame
	_limpar_zumbis_perto(comboio.pos, 120.0)
	var dentro_caixa := func(v: Node3D, p: Vector3) -> bool:
		var c: Vector4 = v.caixa_colisao()
		var l: Vector3 = v.global_transform.affine_inverse() * p
		return absf(l.x - c.x) < c.z - 0.05 and absf(l.z - c.y) < c.w - 0.05
	# 1) zumbi do outro lado da picape, correndo atrás de você: não pode entrar na caixa
	var pk: Node3D = picape
	jogador.global_position = pk.global_transform * Vector3(-4.0, 0, 0)
	jogador.global_position.y = jogador.chao(jogador.global_position)
	var zp: Vector3 = pk.global_transform * Vector3(4.0, 0, 0.3)
	zp.y = mundo.altura(zp.x, zp.z)
	var zb := mundo.criar_zumbi(mundo, zp, 0.0, 5, "corredor")
	zb.estado = Zumbi.Estado.PERSEGUINDO
	var invadiu := 0
	var t := 0.0
	jogador.vida = 1e6
	while t < 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if dentro_caixa.call(pk, zb.global_position):
			invadiu += 1
		if "--debug" in OS.get_cmdline_user_args() and Engine.get_process_frames() % 20 == 0:
			print("TFd ", pk.global_transform.affine_inverse() * zb.global_position, " est=", zb.estado)
	print("TF picape: zumbi entrou na caixa %d quadros; chegou a %.1f m de você (contornou=%s)" % [invadiu, zb.global_position.distance_to(jogador.global_position), zb.global_position.distance_to(jogador.global_position) < 2.5])
	var cruzou := 0
	for v in [picape, trailer]:
		var c: Vector4 = v.caixa_colisao()
		for k in 9:
			var zz: float = c.y - c.w + c.w * 2.0 * k / 8.0
			var a: Vector3 = v.global_transform * Vector3(c.z + 0.6, 0, zz)
			var b: Vector3 = v.global_transform * Vector3(c.z - 0.2, 0, zz)
			if not mundo.colide(a, b, 0.25):
				cruzou += 1
	print("TF caixas: movimentos que atravessaram a lateral = %d (esperado 0)" % cruzou)
	zb.queue_free()
	await get_tree().process_frame
	# 2) acampamento: zumbis em volta tentando chegar até você
	jogador.global_position = trailer.global_transform * Vector3(-3.0, 0, -1.0)
	jogador.global_position.y = jogador.chao(jogador.global_position)
	_alternar_acampamento()
	var ac: Acampamento = acampamento
	print("TF cerca: %d pontos, perímetro %.0f m, portão %.1f m" % [ac.anel.size(), _perimetro(ac.anel), ac.portao_a.distance_to(ac.portao_b)])
	var zs: Array = []
	for k in 10:
		var ang := TAU * k / 10.0
		var p := comboio.pos + Vector3(sin(ang), 0, cos(ang)) * 28.0
		p.y = mundo.altura(p.x, p.z)
		var zz := mundo.criar_zumbi(mundo, p, 0.0, 30 + k, "corredor" if k % 2 == 0 else "comum")
		zz.estado = Zumbi.Estado.PERSEGUINDO
		zs.append(zz)
	var entraram := {}
	t = 0.0
	while t < 25.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		for zz in zs:
			if is_instance_valid(zz) and Geometry2D.is_point_in_polygon(Vector2(zz.global_position.x, zz.global_position.z), ac.anel):
				entraram[zz] = true
	var na_cerca := 0
	for zz in zs:
		if is_instance_valid(zz) and Acampamento._dist_seg(Vector2(zz.global_position.x, zz.global_position.z), ac.anel[0], ac.anel[0]) >= 0.0:
			var dmin := INF
			for i in ac.anel.size():
				dmin = minf(dmin, Acampamento._dist_seg(Vector2(zz.global_position.x, zz.global_position.z), ac.anel[i], ac.anel[(i + 1) % ac.anel.size()]))
			if dmin < 2.0:
				na_cerca += 1
	print("TF acampamento: zumbis que entraram = %d de %d; encostados na cerca = %d" % [entraram.size(), zs.size(), na_cerca])
	# 3) portão: você passa, zumbi não
	var pc := (ac.portao_a + ac.portao_b) * 0.5
	var dentro_v := (Vector2(trailer.global_position.x, trailer.global_position.z) - pc).normalized()
	var fora3 := Vector3(pc.x - dentro_v.x * 0.5, 0, pc.y - dentro_v.y * 0.5)
	var dentro3 := Vector3(pc.x + dentro_v.x * 0.5, 0, pc.y + dentro_v.y * 0.5)
	print("TF portão: você passa=%s  zumbi passa=%s" % [not mundo.colide(fora3, dentro3, 0.28, true), not mundo.colide(fora3, dentro3, 0.25)])
	# 4) desmontar libera
	_alternar_acampamento()
	await get_tree().process_frame
	print("TF desmontado: obstáculos extra = %d" % mundo.obstaculos_extra.size())
	# 5) pulo
	jogador.global_position = trailer.global_transform * Vector3(4.0, 0, 0)
	jogador.camera.current = true
	jogador.set_process(true)
	jogador.estamina = 1.0
	await get_tree().process_frame
	Input.action_press("pular")
	await get_tree().process_frame
	Input.action_release("pular")
	var alt_max := 0.0
	var t_ar := 0.0
	for f in 120:
		await get_tree().process_frame
		alt_max = maxf(alt_max, jogador.no_ar)
		if jogador.no_ar > 0.0:
			t_ar += get_process_delta_time()
	print("TF pulo: altura máx %.2f m, %.2f s no ar, no chão de novo=%s" % [alt_max, t_ar, jogador.no_ar == 0.0])
	get_tree().quit()

func _perimetro(a: PackedVector2Array) -> float:
	var s := 0.0
	for i in a.size():
		s += a[i].distance_to(a[(i + 1) % a.size()])
	return s

func _teste_cachorro() -> void:
	await get_tree().process_frame
	var z := 12 * WorldGen.TAM + 32.0
	jogador.position = mundo.ponto_estrada(z - 12.0, 0.0)
	jogador.position.y = jogador.chao(jogador.position)
	mundo.atualizar(jogador.position)
	await get_tree().process_frame
	_limpar_zumbis_perto(jogador.position, 80.0)
	var e: Dictionary = mundo.eventos_ativos.get(12, {})
	print("TK evento: ", e.get("tipo", "-"), " resolvido=", e.get("resolvido", "-"))
	eventos._t_checar = 0.0
	eventos.atualizar(0.1)
	print("TK painel: ", eventos._painel().titulo)
	eventos._painel().botoes[0][1].call()
	await get_tree().process_frame
	print("TK adotou: ", cachorro != null, " nome=", cachorro.nome if cachorro else "", " raca=", cachorro.raca if cachorro else "")
	# seguir
	var t := 0.0
	for i in 120:
		jogador.position += Vector3(0, 0, 0.08)
		jogador.position.y = jogador.chao(jogador.position)
		await get_tree().process_frame
	print("TK distancia apos andar: %.1f m" % cachorro.global_position.distance_to(jogador.global_position))
	# zumbi longe: latido
	var zp := jogador.position + Vector3(20, 0, 15)
	zp.y = mundo.altura(zp.x, zp.z)
	var zb := mundo.criar_zumbi(mundo, zp, 0.0, 5, "comum")
	zb.set_process(false)
	cachorro._t_latido = 0.0
	await get_tree().process_frame
	print("TK aviso: ", hud._aviso_txt if "_aviso_txt" in hud else "")
	# zumbi colado: defende
	zb.global_position = jogador.global_position + Vector3(2.5, 0, 0)
	cachorro._t_latido = 0.0
	var tt := 0.0
	while tt < 10.0 and zb.vivo():
		await get_tree().process_frame
		tt += get_process_delta_time()
	print("TK defendeu em %.1f s: zumbi vivo=" % tt, zb.vivo(), " vida zumbi=", zb.vida, " cachorro vida=", cachorro.vida, " estado=", cachorro.estado)
	# caça
	var an := Animal.new()
	an.tipo = "veado"
	an.mundo = mundo
	an.semente = 9
	var ap := jogador.position + Vector3(-10, 0, 6)
	ap.y = mundo.altura(ap.x, ap.z)
	an.position = ap
	mundo.add_child(an)
	mundo.animais.append(an)
	await get_tree().process_frame
	an.ferir(20.0, Vector3.ZERO, jogador.global_position)
	var tc := 0.0
	var log_t := 0.0
	while tc < 20.0 and an.vivo():
		await get_tree().process_frame
		tc += get_process_delta_time()
		if tc - log_t > 1.0:
			log_t = tc
			print("TK  t=%.0f cao=%d dist_cao_veado=%.1f veado_jog=%.1f veado_estado=%d" % [tc, cachorro.estado, cachorro.global_position.distance_to(an.global_position), an.global_position.distance_to(jogador.global_position), an.estado])
	print("TK caca: veado vivo=", an.vivo(), " vida=", an.vida, " em %.1f s" % tc)
	# faro
	var v := Node3D.new()
	mundo.add_child(v)
	cachorro.global_position = jogador.global_position + Vector3(1.5, 0, 1.0)
	v.global_position = jogador.global_position + Vector3(6, 1.0, -4)
	v.set_meta("nome", "Mochila esquecida")
	v.set_meta("tabela", "acampamento")
	v.set_meta("horas", 0.25)
	v.set_meta("chave", "teste:faro")
	mundo.vasculhaveis.append(v)
	cachorro._t_faro = 0.0
	cachorro.estado = Cachorro.Estado.SEGUINDO
	for i in 30:
		await get_tree().process_frame
	print("TK faro: estado=", cachorro.estado, " (FAREJANDO=", Cachorro.Estado.FAREJANDO, ")")
	# caçamba
	_entrar_no_carro()
	await get_tree().process_frame
	await get_tree().process_frame
	print("TK cacamba: estado=", cachorro.estado, " dist picape=%.1f" % cachorro.global_position.distance_to(picape.global_position))
	_sair_do_carro()
	var sv := cachorro.salvar()
	print("TK save: ", sv.nome, " ", sv.raca, " vida=", sv.vida)
	get_tree().quit()

## Teste do comércio: preços por lugar, troca, pedido, reputação e facções.
func _teste_comercio() -> void:
	await get_tree().process_frame
	var cm := comercio
	for id in ["vila_a", "vila_b", "vila_c"]:
		var l := cm._lugar(id)
		print("TM %s sobra=%s falta=%s remedio compra=%d venda=%d | diesel compra=%d" % [id, str(l.sobra), str(l.falta), cm.preco_compra(id, "remedio"), cm.preco_venda(id, "remedio"), cm.preco_compra(id, "galoes_diesel")])
	estoque.remedio = 6
	estoque.sucata = 40
	var id := "vila_a"
	print("TM vender: ", cm._vender(id, "remedio", "remedio", 3), " credito=", cm._lugar(id).credito)
	var est := cm._estoque_banca(id, "remedio")
	print("TM estoque banca: ", est)
	for it in est:
		print("TM comprar: ", cm._comprar(id, "remedio", it, 1))
		break
	cm._banca_aberta = {"id": id, "banca": "geral", "nome": "Zé", "fala": "Oi"}
	var pn := cm.painel()
	print("TM painel geral: botoes=%d | %s" % [pn.botoes.size(), pn.linhas[2][0]])
	var ped: Dictionary = cm._lugar(id).pedido
	print("TM pedido: ", ped)
	estoque[ped.item] = ped.qtd + 1
	print("TM entregar: ", cm._entregar(id), " rep=", cm._lugar(id).rep, " ", Comercio.nivel_rep(cm._lugar(id).rep), " desconto=", cm.desconto(id))
	cm.reputacao(id, 60.0)
	print("TM aliado presente: ", cm.presente_aliado(id), " desconto=", cm.desconto(id))
	# facções
	cm.registrar_faccao("Os Abutres", "pagou")
	cm.registrar_faccao("Os Abutres", "pagou")
	cm.registrar_faccao("Irmandade do Asfalto", "furou")
	cm.registrar_faccao("Irmandade do Asfalto", "atirou")
	print("TM relacoes: abutres=%s irmandade=%s carniceiros=%s" % [cm.relacao("Os Abutres"), cm.relacao("Irmandade do Asfalto"), cm.relacao("Carniceiros da BR")])
	# evento de saqueadores com facção inimiga
	var k := 400
	mundo.pois_fixos[k] = "evento"
	mundo.eventos_tipo[k] = "saqueadores"
	var z := k * WorldGen.TAM + 32.0
	comboio.posicionar(z - 60.0, -0.5, 0.0)
	jogador.position = mundo.ponto_estrada(z - 30.0, 0.0)
	mundo.atualizar(jogador.position)
	await get_tree().process_frame
	var e: Dictionary = mundo.eventos_ativos.get(k, {})
	eventos._atual = e
	estoque.comida = 20
	var pnl := eventos._painel()
	print("TM bloqueio: ", pnl.titulo, " | ", pnl.linhas[0])
	var sv := cm.salvar()
	cm.carregar(sv)
	print("TM save ok: lugares=", cm.lugares.size(), " faccoes=", cm.faccoes.size())
	get_tree().quit()

## Teste do combate com o comboio: agarrar, soltar no ziguezague, espinhos e atirador.
func _teste_comboio() -> void:
	await get_tree().process_frame
	var cc := combate_comboio
	for caso in ["sem nada", "ziguezague", "espinhos", "atirador"]:
		for z in mundo.zumbis_vivos.duplicate():
			if is_instance_valid(z):
				z.queue_free()
		mundo.zumbis_vivos.clear()
		cc.agarrados.clear()
		picape.config.espinhos.nivel = 2 if caso == "espinhos" else 0
		picape.config.posto_tiro.nivel = 2 if caso == "atirador" else 0
		picape.reconstruir()
		base.lista.clear()
		if caso == "atirador":
			base.lista.append(Recrutas.novo("Tião", "vigia", 5))
			estoque.municao_rifle = 30
		comboio.posicionar(3000.0, -0.5, 0.0)
		jogador.vida = 1.0
		mundo.atualizar(comboio.pos)
		_entrar_no_carro()
		await get_tree().process_frame
		comboio.velocidade = 8.0
		# zumbis em volta da picape correndo junto
		for i in 6:
			var lado := -1.0 if i % 2 == 0 else 1.0
			var p := picape.global_transform * Vector3(lado * 1.6, 0, -1.5 + (i / 2) * 1.0)
			p.y = mundo.altura(p.x, p.z)
			var z := mundo.criar_zumbi(mundo, p, 0.0, 100 + i, "comum")
			z.estado = Zumbi.Estado.PERSEGUINDO
		var vida0 := jogador.vida
		var max_ag := 0
		var t := 0.0
		while t < 8.0:
			comboio.velocidade = 8.0
			if caso == "ziguezague" and t > 2.0:
				comboio.esterco = 0.8 if int(t * 3.0) % 2 == 0 else -0.8
			else:
				comboio.esterco = 0.0
			await get_tree().process_frame
			t += get_process_delta_time()
			max_ag = maxi(max_ag, cc.agarrados.size())
		var mortos := 0
		for z in mundo.zumbis_vivos:
			pass
		print("TCC %s: max agarrados=%d agora=%d vida %.2f->%.2f municao=%d atirador=%s abates=%d vmax x%.2f" % [caso, max_ag, cc.agarrados.size(), vida0, jogador.vida, estoque.get("municao_rifle", 0), str(is_instance_valid(cc.atirador)), abates, cc.fator_velocidade()])
		_sair_do_carro()
	get_tree().quit()

## Teste do progresso: marco, prêmio, missões do rádio, prazo e diário.
func _teste_progresso() -> void:
	await get_tree().process_frame
	print("TG objetivo inicial: ", progresso.objetivo())
	# chegar na Zona Segura
	var zm := progresso.z_marco(0)
	comboio.posicionar(zm - 20.0, -0.5, 0.0)
	jogador.position = comboio.pos + Vector3(3, 0, 0)
	mundo.atualizar(comboio.pos)
	await get_tree().process_frame
	print("TG marco gerado: ", mundo.get_node_or_null("Chunk_%d" % int(floor(zm / WorldGen.TAM))) != null and mundo.find_child("Marco_0", true, false) != null,
		" zumbis perto=", mundo.zumbis_vivos.filter(func(z): return is_instance_valid(z) and z.global_position.distance_to(comboio.pos) < 60.0).size())
	progresso.atualizar(0.1)
	print("TG painel premio: ", painel.visible, " titulo=", progresso._painel_premio().titulo)
	var n0 := base.lista.size()
	progresso._painel_premio().botoes[1][1].call()
	await get_tree().process_frame
	print("TG apos premio: marco_idx=", progresso.marco_idx, " recrutas ", n0, "->", base.lista.size(), " cartas=", progresso.cartas, " | ", hud.relatorio.replace("\n", " | "))
	# missões
	for tipo in ["diesel", "remedios", "militar", "sinal", "socorro"]:
		var id := progresso.nova_missao(tipo)
		var ms: Dictionary = progresso.missoes[id]
		var alvo := mundo.ponto_estrada(ms.z, ms.lat)
		comboio.posicionar(ms.z - 40.0, -0.5, 0.0)
		jogador.position = alvo + Vector3(1.0, 0, 1.0)
		jogador.position.y = mundo.altura(jogador.position.x, jogador.position.z)
		mundo.atualizar(jogador.position)
		await get_tree().process_frame
		var no := mundo.find_child("Missao_%d" % id, true, false)
		var zs := mundo.zumbis_vivos.filter(func(z): return is_instance_valid(z) and z.get_meta("missao", -1) == id)
		if tipo == "socorro":
			for z in zs:
				z.ferir(9999.0)
		else:
			for v in mundo.vasculhaveis:
				if is_instance_valid(v) and v.get_meta("chave") == "missao:%d" % id:
					_vasculhar(v)
		progresso.atualizar(0.1)
		print("TG missao %s: construida=%s zumbis=%d estado=%s marcadores=%d | %s" % [tipo, str(no != null), zs.size(), ms.estado, marcadores.size(), hud.relatorio.replace("\n", " | ").substr(0, 140)])
	var idp := progresso.nova_missao("socorro")
	progresso.passar(20.0)
	print("TG prazo: ", progresso.missoes[idp].estado)
	print("TG diario: ", progresso.painel_diario().subtitulo, " objetivo=", progresso.objetivo())
	var sv := progresso.salvar()
	progresso.carregar(sv)
	print("TG save/load marco_idx=", progresso.marco_idx, " missoes=", progresso.missoes.size())
	get_tree().quit()

## Teste do clima: estados por estação e frenagem no seco, molhado e neve.
func _teste_clima() -> void:
	await get_tree().process_frame
	for d in [1, 11, 21, 31]:
		dia = d
		var cont := {}
		for i in 400:
			clima._t_troca = 0.0
			clima.passar(0.1)
			cont[clima.estado] = cont.get(clima.estado, 0) + 1
		print("TC2 estacao=%s %s" % [clima.estacao(), str(cont)])
	dia = 3
	for e in ["limpo", "chuva", "tempestade", "neve"]:
		clima.forcar(e)
		comboio.aderencia_clima = clima.aderencia()
		comboio.posicionar(1000.0, -0.5, 0.0)
		comboio.velocidade = 20.0
		comboio.dirigindo = true
		Input.action_press("freio")
		var z0 := comboio.pos.z
		var t := 0.0
		while comboio.velocidade > 0.3 and t < 10.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
		Input.action_release("freio")
		comboio.dirigindo = false
		print("TC2 %s aderencia=%.2f frenagem de 72 km/h: %.1f m em %.1f s | horda x%.2f visao x%.2f audicao x%.2f" % [e, clima.aderencia(), comboio.pos.z - z0, t, clima.fator_horda(), clima.fator_visao(), clima.fator_audicao()])
	get_tree().quit()

## Teste do perigo pela distância: tipos de zumbi, ninhos, diesel e avisos.
func _teste_perigo() -> void:
	await get_tree().process_frame
	var r := RandomNumberGenerator.new()
	for km in [0.0, 6.0, 16.0, 32.0, 55.0, 90.0]:
		for nt in [false, true]:
			mundo.noite = nt
			var cont := {}
			for i in 2000:
				var t := mundo.sortear_tipo_zumbi(r, km * 1000.0)
				cont[t] = cont.get(t, 0) + 1
			print("TP km=%d noite=%s faixa=%s perigo=%.1f diesel=%.2f tipos=%s" % [km, str(nt), WorldGen.FAIXAS[mundo.faixa(km * 1000.0)].nome, mundo.perigo(km * 1000.0), mundo.fartura_diesel(km * 1000.0), str(cont)])
	mundo.noite = false
	# ninhos gerados ao andar pela zona vermelha
	var achou: Ninho = null
	var total := 0
	for zz in range(16000, 40000, 400):
		comboio.posicionar(float(zz), -0.5, 0.0)
		jogador.position = comboio.pos
		mundo.atualizar(comboio.pos)
		await get_tree().process_frame
		total = maxi(total, mundo.ninhos.size())
		if achou == null and not mundo.ninhos.is_empty():
			achou = mundo.ninhos[0]
	print("TP ninhos vistos (máx simultâneos)=", total, " achou=", achou != null)
	if achou:
		jogador.position = achou.global_position + Vector3(3, 0, 0)
		var vivos0 := mundo.zumbis_vivos.size()
		achou._t = 0.0
		await get_tree().process_frame
		await get_tree().process_frame
		print("TP ninho soltou zumbi: ", mundo.zumbis_vivos.size() > vivos0)
		estoque.galoes_diesel = 1
		estoque.molotov = 0
		_queimar_ninho(achou)
		print("TP queimou: ", achou.queimado, " galoes=", estoque.galoes_diesel, " | ", hud.relatorio.replace("\n", " | "))
	# blindado aguenta tiro
	var zb := mundo.criar_zumbi(mundo, jogador.position + Vector3(0, 0, 8), 0.0, 1, "blindado")
	zb.ferir(30.0)
	print("TP blindado vida apos tiro 30: ", zb.vida, " / 150")
	print("TP avisos=", _avisou_marco.keys().filter(func(k): return str(k).begins_with("faixa")))
	get_tree().quit()

## Teste dos eventos na estrada: cada tipo dispara e cada escolha tem efeito.
func _teste_eventos() -> void:
	await get_tree().process_frame
	var tipos := ["saqueadores", "carona", "acidente", "militar"]
	var escolhas := {"saqueadores": [0, 1, 2, 3], "carona": [0, 1, 2], "acidente": [0, 1, 2]}
	var k := 30
	for t in tipos:
		for esc in escolhas.get(t, [-1]):
			mundo.pois_fixos[k] = "evento"
			mundo.eventos_tipo[k] = t
			k += 3
	k = 30
	for t in tipos:
		var lista: Array = escolhas.get(t, [-1])
		for esc in lista:
			estoque.merge({"comida": 20, "agua": 10, "galoes_diesel": 2, "municao_pistola": 20, "sucata": 30, "pecas": 6}, true)
			comboio.diesel = 40.0
			jogador.vida = 1.0
			var z := k * WorldGen.TAM + 32.0
			comboio.posicionar(z - 60.0, -0.5, 0.0)
			jogador.position = mundo.ponto_estrada(z - (30.0 if t == "saqueadores" else 14.0), 0.0)
			jogador.position.y = jogador.chao(jogador.position)
			mundo.atualizar(jogador.position)
			await get_tree().process_frame
			var e: Dictionary = mundo.eventos_ativos.get(k, {})
			print("TE k=%d tipo=%s criado=%s resolvido=%s zumbis_perto=%d" % [k, t, str(not e.is_empty()), str(e.get("resolvido", "-")), mundo.zumbis_vivos.filter(func(zz): return is_instance_valid(zz) and zz.global_position.distance_to(e.get("pos", Vector3.ZERO)) < 30.0).size()])
			if esc < 0:
				k += 3
				continue
			eventos._t_checar = 0.0
			eventos.atualizar(0.1)
			print("TE   painel=%s titulo=%s" % [str(painel.visible), eventos._painel().get("titulo", "")])
			var antes := {"comida": estoque.comida, "recrutas": base.lista.size(), "vida": jogador.vida, "z": comboio.pos.z, "hora": hora, "diesel": comboio.diesel}
			var bt: Array = eventos._painel().botoes[esc]
			var msg = bt[1].call()
			await get_tree().process_frame
			await get_tree().process_frame
			print("TE   escolha='%s' msg='%s' comida %d->%d recrutas %d->%d vida %.2f->%.2f z %.0f->%.0f diesel %.0f->%.0f" % [bt[0], str(msg), antes.comida, estoque.comida, antes.recrutas, base.lista.size(), antes.vida, jogador.vida, antes.z, comboio.pos.z, antes.diesel, comboio.diesel])
			print("TE   relatorio: ", hud.relatorio.replace("\n", " | "), " feito=", mundo.eventos_feitos.get(k, {}), " painel=", painel.visible)
			eventos.atualizar(0.3)
			print("TE   redisparou=", not eventos._atual.is_empty())
			k += 3
	get_tree().quit()

## Teste automático: zumbis cercando o jogador, golpes, atropelamento e morte.
func _teste() -> void:
	await get_tree().process_frame
	var p := jogador.global_position
	for i in 6:
		var a := TAU * i / 6.0
		var q := p + Vector3(cos(a), 0, sin(a)) * 6.0
		q.y = mundo.altura(q.x, q.z)
		mundo.criar_zumbi(mundo, q, 0.0, i, ["comum", "corredor", "brutamonte", "gritador", "rastejante", "comum"][i])
	for f in 600:
		await get_tree().process_frame
		if f % 20 == 0:
			var perto: Node3D = null
			for z in mundo.zumbis_vivos:
				if is_instance_valid(z) and z.vivo() and (perto == null or z.global_position.distance_to(jogador.global_position) < perto.global_position.distance_to(jogador.global_position)):
					perto = z
			if perto:
				var v := perto.global_position - jogador.global_position
				jogador.yaw = atan2(v.x, v.z)
			equip._cd = 0.0
			equip.golpear()
	print("TESTE vida=%.2f infeccao=%.2f abates=%d vivos=%d morto=%s" % [jogador.vida, jogador.infeccao, abates, mundo.zumbis_vivos.size(), _morto])
	jogador.vida = 0.0
	for f in 5:
		await get_tree().process_frame
	print("TESTE apos morte: morto=%s menu=%s reboques=%d" % [_morto, menu.visible, comboio.cadeia.size()])
	_acordar_apos_queda()
	print("TESTE acordou: dentro=%s vida=%.2f hora=%.1f" % [dentro != null, jogador.vida, hora])
	get_tree().quit()

## Teste: armas de fogo, molotov, armadura, caça, criação.
func _teste_armas() -> void:
	await get_tree().process_frame
	var p := jogador.global_position
	estoque.pistola = 1
	estoque.municao_pistola = 30
	estoque.espingarda = 1
	estoque.cartucho = 6
	estoque.molotov = 2
	estoque.sucata = 0
	estoque.comida = 2
	estoque.agua = 2
	equip.selecionar("pistola")
	equip.recarregar()
	await get_tree().create_timer(1.8).timeout
	print("TA pente=%d reserva=%d slots=%s" % [equip.pentes.get("pistola", 0), estoque.municao_pistola, str(equip.slots())])
	var zs: Array = []
	for i in 4:
		var q := p + jogador.global_transform.basis.z * 0.0 + Vector3(sin(jogador.yaw), 0, cos(jogador.yaw)) * (8.0 + i * 4.0) + Vector3(randf_range(-0.3, 0.3), 0, 0)
		q.y = mundo.altura(q.x, q.z)
		var z := mundo.criar_zumbi(mundo, q, 0.0, 50 + i, "comum")
		zs.append(z)
	jogador.pitch = -0.05
	jogador.camera.position = Vector3(0, 0, 0)
	jogador._process(0.0)
	var mortos := 0
	for tiro in 12:
		var alvo: Zumbi = null
		for z in zs:
			if is_instance_valid(z) and z.vivo():
				alvo = z
				break
		if alvo == null:
			break
		var cam := jogador.camera
		cam.look_at(alvo.global_position + Vector3(0, 1.2, 0), Vector3.UP)
		equip._cd = 0.0
		equip.atirar()
		await get_tree().process_frame
	for z in zs:
		if not is_instance_valid(z) or not z.vivo():
			mortos += 1
	print("TA tiros: mortos=%d/4 pente=%d" % [mortos, equip.pentes.get("pistola", 0)])
	# molotov
	var zf := mundo.criar_zumbi(mundo, p + Vector3(4, 0, 4), 0.0, 77, "comum")
	var mv := Arremesso.new()
	mv.main = self
	mv.tipo = "molotov"
	add_child(mv)
	mv.global_position = zf.global_position + Vector3(0, 2.0, 0)
	for f in 300:
		await get_tree().process_frame
	print("TA molotov: zumbi vivo=%s vida=%.0f" % [zf.vivo(), zf.vida])
	# caça e criação
	var an := Animal.new()
	an.tipo = "veado"
	an.mundo = mundo
	an.semente = 5
	add_child(an)
	an.global_position = p + Vector3(6, 0, 0)
	an.ferir(500.0)
	_esfolar(an)
	print("TA caça: carne=%d pele=%d" % [estoque.get("carne_crua", 0), estoque.get("pele", 0)])
	for k in ITENS:
		estoque[k] = 0
	print("TA carga cap=%d" % capacidade_carga())
	estoque.pele = 8
	estoque.cordame = 3
	estoque.sucata = 30
	estoque.galoes_diesel = 0
	estoque.pneu = 0
	estoque.carne_crua = 1
	estoque.pecas = 10
	_alternar_acampamento()
	print("TA ", criacao.fazer("curtir", 6))
	print("TA ", criacao.fazer("colete_couro"))
	print("TA ", criacao.fazer("assar", 1))
	print("TA ", equip.vestir("colete_couro"))
	var antes := equip.defesa()
	var of := _novo_reboque("oficina", 2, 0.9)
	of.global_position = comboio.engate_livre() - trailer.global_transform.basis.z * of.engate_frente_z()
	of.global_rotation.y = trailer.global_rotation.y
	comboio.engatar(of, true)
	jogador.global_position = of.global_position + Vector3(2, 0, 0)
	print("TA ", criacao.fazer("chapa", 2))
	print("TA ", criacao.reforcar("torso"))
	print("TA defesa %.2f -> %.2f, mordida %.2f, dano 0.2 vira %.3f" % [antes, equip.defesa(), equip.protecao_mordida(), equip.absorver(0.2)])
	_abrir_painel(criacao.painel)
	await get_tree().process_frame
	print("TA painel ok")
	get_tree().quit()

## Teste: apartamentos, recrutar, automação, combate dos recrutas e morte.
func _teste_recrutas() -> void:
	await get_tree().process_frame
	var ap := _novo_reboque("apartamentos", 2, 0.9)
	ap.global_position = comboio.engate_livre() - trailer.global_transform.basis.z * ap.engate_frente_z()
	ap.global_rotation.y = trailer.global_rotation.y
	comboio.engatar(ap, true)
	var es := _novo_reboque("estufa", 2, 0.9)
	es.global_position = comboio.engate_livre() - ap.global_transform.basis.z * es.engate_frente_z()
	es.global_rotation.y = trailer.global_rotation.y
	comboio.engatar(es, true)
	print("TR camas=%d" % base.camas())
	estoque.comida = 20
	estoque.agua = 20
	for fn in ["vigia", "mecanico", "agricultor", "batedor"]:
		base.lista.append(Recrutas.novo("T-" + fn, fn, hash(fn)))
	base.distribuir_camas()
	print("TR recrutas=%d texto=%s" % [base.lista.size(), base.texto_hud()])
	_entrar_em(trailer)
	for f in 3:
		await get_tree().process_frame
	base.atualizar_cena(1.0)
	print("TR nos=%d" % base.nos.size())
	var p := trailer.global_position
	for i in 6:
		var a := TAU * i / 6.0
		var q := p + Vector3(cos(a), 0, sin(a)) * 14.0
		q.y = mundo.altura(q.x, q.z)
		var z := mundo.criar_zumbi(mundo, q, 0.0, 100 + i, "comum")
		z.estado = Zumbi.Estado.PERSEGUINDO
	var antes := abates
	for f in 900:
		await get_tree().process_frame
	var vivos := 0
	for z in mundo.zumbis_vivos:
		if is_instance_valid(z) and z.global_position.distance_to(p) < 30.0:
			vivos += 1
	print("TR abates_recrutas=%d zumbis_perto=%d recrutas=%d" % [abates - antes, vivos, base.lista.size()])
	for rc in base.lista:
		print("TR   %s vida=%.2f abates=%d" % [rc.nome, rc.vida, rc.abates])
	# automação: um dia inteiro
	var c0: int = estoque.comida
	_passar_tempo(24.0)
	print("TR depois de 24h: comida %d -> %d, estufa=%.1f relatorio=%s" % [c0, estoque.comida, es.comida, str(base.relatorio())])
	var bat: Dictionary = base.presentes("batedor")[0] if not base.presentes("batedor").is_empty() else {}
	if not bat.is_empty():
		print("TR expedicao: ", base.enviar_expedicao(bat, 12.0))
		_passar_tempo(13.0)
		print("TR volta: ", str(base.relatorio()))
	var r := RandomNumberGenerator.new()
	r.seed = 3
	print("TR penalidade: ", base.penalidade(r))
	get_tree().quit()

## Teste automático da defesa: fica no primeiro assentamento, constrói e aguenta uma onda.
func _teste_defesa() -> void:
	await get_tree().process_frame
	var l := {}
	for ll in mundo.lugares_da_regiao(0):
		if ll.tipo == "assentamento":
			l = ll
	print("TD lugar=%s pos=%s" % [l.nome, l.pos])
	jogador.position = l.pos + Vector3(0, 0, 3)
	mundo.atualizar(l.pos)
	for f in 3:
		await get_tree().process_frame
	var a := defesa.no_de(l.id)
	print("TD no=%s muros=%d" % [a != null, mundo.muros.size()])
	var g := a.global_de(Assentamento.ponto(0, Assentamento.R + 9.0))
	comboio.posicionar_livre(g, a.global_rotation.y + PI * 0.5, 0.0)
	var ap := _novo_reboque("apartamentos", 2, 0.9)
	ap.global_position = comboio.engate_livre() - trailer.global_transform.basis.z * ap.engate_frente_z()
	ap.global_rotation.y = trailer.global_rotation.y
	comboio.engatar(ap, true)
	for fn in ["vigia", "mecanico", "medico", "batedor"]:
		base.lista.append(Recrutas.novo("T-" + fn, fn, hash(fn)))
	base.distribuir_camas()
	estoque.sucata = 200
	estoque.pecas = 60
	estoque.galoes_diesel = 3
	print("TD ", defesa.ficar(l.id))
	print("TD ", defesa.construir(l.id, "torre", 1))
	print("TD ", defesa.construir(l.id, "holofote", 0))
	print("TD ", defesa.construir(l.id, "armadilha", 2))
	print("TD nivel=%d muro=%.2f" % [defesa.nivel(defesa.obter(l.id)), a.muro_medio()])
	# colisão: zumbi não atravessa o muro, jogador passa pelo portão
	var fora := a.global_de(Assentamento.ponto(5, Assentamento.R + 0.6))
	var dentro_p := a.global_de(Assentamento.ponto(5, Assentamento.R - 0.6))
	var portao_f := a.global_de(Assentamento.ponto(0, Assentamento.R + 0.5))
	var portao_d := a.global_de(Assentamento.ponto(0, Assentamento.R - 0.5))
	print("TD colide muro=%s portao_jogador=%s" % [mundo.colide(fora, dentro_p, 0.25), mundo.colide(portao_f, portao_d, 0.28, true)])
	defesa.z_horda = float(l.pos.z) - 262.0
	jogador.visible = false
	_passar_tempo(0.2)
	print("TD onda=%s total=%d defensores=%d" % [defesa.em_combate(), defesa.onda.get("total", 0), defesa.nos.size()])
	Engine.time_scale = 3.0
	for w in 3:
		if w > 0:
			defesa.esperar(l.id)
			print("TD esperou: onda=%s n=%d total=%d" % [defesa.em_combate(), defesa.onda.get("n", 0), defesa.onda.get("total", 0)])
		for f in 12000:
			await get_tree().process_frame
			if f % 900 == 0 and defesa.em_combate():
				var o: Dictionary = defesa.onda
				print("TD t=%d fila=%d vivos=%d dentro=%d muro=%.2f resist=%.2f" % [f, o.fila, o.vivos.size(), o.get("dentro", 0), a.muro_medio(), o.resistencia])
			if not defesa.em_combate():
				break
		print("TD apos onda %d: fase=%s relatorio=%s" % [w + 1, defesa.obter(l.id).fase, hud.relatorio.replace("\n", " | ")])
		if defesa.obter(l.id).fase == "caido" or _morto:
			break
	Engine.time_scale = 1.0
	var e: Dictionary = defesa.obter(l.id)
	print("TD fim fase=%s ondas=%d defendidos=%d ameaca=%.0f morto=%s" % [e.fase, e.ondas, defesa.defendidos, mundo.nivel_ameaca, _morto])
	print("TD relatorio=", hud.relatorio.replace("\n", " | "))
	print("TD recrutas=%d" % base.lista.size())
	get_tree().quit()

## Dirige a 90 km/h por 1,5 km medindo o tempo de cada quadro (engasgos).
func _teste_fluidez() -> void:
	mundo.gradual = "--sem-gradual" not in OS.get_cmdline_user_args()
	await get_tree().process_frame
	_entrar_no_carro()
	var z := 100.0
	var tempos: Array[float] = []
	var ultimo := Time.get_ticks_usec()
	while z < 1600.0:
		z += 25.0 / 60.0
		comboio.diesel = 60.0
		comboio.posicionar(z, -0.5, 0.0)
		await get_tree().process_frame
		var agora := Time.get_ticks_usec()
		tempos.append((agora - ultimo) / 1000.0)
		ultimo = agora
	tempos.sort()
	var n := tempos.size()
	var acima := tempos.filter(func(t): return t > 100.0).size()
	print("FL gradual=%s quadros=%d mediana=%.1f ms p95=%.1f p99=%.1f max=%.1f quadros>100ms=%d" % [str(mundo.gradual), n, tempos[n / 2], tempos[int(n * 0.95)], tempos[int(n * 0.99)], tempos[n - 1], acima])
	get_tree().quit()

## Mede o custo de gerar trechos (cada etapa) para achar o que engasga.
func _perfil_chunks() -> void:
	await get_tree().process_frame
	mundo.perfil.clear()
	var piores: Array = []
	for k in range(20, 80):
		var t := Time.get_ticks_usec()
		var n := mundo._gerar_chunk(k)
		var dt := (Time.get_ticks_usec() - t) / 1000.0
		piores.append([dt, k, mundo.bioma_em(k * 64.0)])
		n.queue_free()
		await get_tree().process_frame
	# confere a grade contra o cálculo exato
	var g := mundo.grade(40)
	var maxd := 0.0
	var soma := 0.0
	var rr := RandomNumberGenerator.new()
	for i in 2000:
		var z := 40 * 64.0 + rr.randf() * 64.0
		var x := mundo.centro_x(z) + rr.randf_range(-280.0, 280.0)
		var dd := absf(mundo.altura(x, z) - mundo.altura_exata(x, z))
		maxd = maxf(maxd, dd)
		soma += dd
	var nos := 0.0
	for iz in 17:
		for ix in range(0, 150, 7):
			var x2: float = float(g.cx0) + ix * 4.0
			var z2: float = 40 * 64.0 + iz * 4.0
			nos = maxf(nos, absf(g.h[iz * 151 + ix] - mundo.altura_exata(x2, z2)))
	print("PF grade: erro nos nós %.4f m; entre nós média %.3f m, máx %.3f m" % [nos, soma / 2000.0, maxd])
	mundo.perfil.clear()
	var t37 := Time.get_ticks_usec()
	mundo._grades.erase(37)
	var n37 := mundo._gerar_chunk(37)
	print("PF trecho 37: %.0f ms · %s" % [(Time.get_ticks_usec() - t37) / 1000.0, str(mundo.perfil.keys().map(func(kk): return "%s %.0f" % [kk, mundo.perfil[kk] / 1000.0]))])
	n37.queue_free()
	piores.sort_custom(func(a, b): return a[0] > b[0])
	var tot := 0.0
	for p in piores:
		tot += p[0]
	print("PF média %.1f ms por trecho; piores: %s" % [tot / piores.size(), str(piores.slice(0, 6))])
	var et: Array = mundo.perfil.keys()
	et.sort_custom(func(a, b): return mundo.perfil[a] > mundo.perfil[b])
	for e in et:
		print("PF   %-22s %.1f ms/trecho" % [e, mundo.perfil[e] / 1000.0 / piores.size()])
	get_tree().quit()

## Teste longo: dirige 60 km de estrada (geração de trechos com tudo ligado), passa dias, salva e carrega.
func _teste_longo() -> void:
	await get_tree().process_frame
	estoque.merge({"comida": 80, "agua": 80, "galoes_diesel": 10}, true)
	_entrar_no_carro()
	var t0 := Time.get_ticks_msec()
	var erros_antes := 0
	var zmax := 15000.0
	var z := 0.0
	var passo := 0
	while z < zmax:
		z += 90.0
		comboio.diesel = 60.0
		comboio.posicionar(z, -0.5, 0.0)
		mundo.atualizar(comboio.pos)
		_passar_tempo(0.15)
		jogador.vida = 1.0
		await get_tree().process_frame
		passo += 1
		if passo % 25 == 0:
			print("TL km %d · dia %d %.0fh · trechos %d · zumbis %d · eventos %d · lugares %d · subsolos %d · %d ms" % [int(z / 1000.0), dia, hora, mundo.get_child_count(), mundo.zumbis_vivos.size(), mundo.eventos_ativos.size(), mundo.lugares_ativos.size(), mundo.subsolos.size(), Time.get_ticks_msec() - t0])
			if _morto:
				print("TL morreu: ", _morto)
				break
	_sair_do_carro()
	print("TL fim: km %.1f, dia %d, faixa %s, reboques %d, recrutas %d" % [z / 1000.0, dia, WorldGen.FAIXAS[mundo.faixa(z)].nome, comboio.cadeia.size() - 1, base.lista.size()])
	print("TL save=", Salvar.salvar(self))
	get_tree().quit()

## Teste da etapa 11: sono, cochilo, gripe, intoxicação, ferida que inflama, antibiótico, cozinha e save.
func _teste_saude() -> void:
	await get_tree().process_frame
	saude.cansaco = 0.1
	_passar_tempo(16.0)
	print("TH 16 h acordado: cansaço %.2f" % saude.cansaco)
	_passar_tempo(4.0)
	print("TH 20 h acordado: cansaço %.2f" % saude.cansaco)
	# cochilo ao volante
	_entrar_no_carro()
	comboio.velocidade = 15.0
	saude.cansaco = 0.95
	saude._t_cochilo = 0.0
	var cochilos := 0
	for i in 300:
		comboio.velocidade = 15.0
		saude.atualizar(0.1)
		if saude._cochilando > 0.0:
			cochilos += 1
	print("TH dirigindo exausto: quadros cochilando=%d esterco=%.2f" % [cochilos, comboio.esterco])
	_sair_do_carro()
	# dormir resolve
	hora = 22.0
	dormir()
	print("TH dormiu: cansaço %.2f" % saude.cansaco)
	# gripe dormindo sem abrigo (forçado)
	var g := 0
	for i in 50:
		saude.doencas.erase("gripe")
		if saude.dormiu(8.0, false) != "":
			g += 1
	print("TH gripe dormindo ao relento: %d/50" % g)
	saude.pegar("gripe", 40.0)
	jogador.estamina = 1.0
	saude.atualizar(0.1)
	print("TH com gripe: estamina limitada a %.2f" % jogador.estamina)
	# intoxicação com carne crua
	var it := 0
	for i in 100:
		saude.doencas.erase("intoxicacao")
		saude.comeu("carne_crua")
		if saude.tem("intoxicacao"):
			it += 1
	print("TH carne crua intoxica: %d/100" % it)
	# ferida que inflama e antibiótico
	saude.doencas.clear()
	saude.pegar("ferida", 6.0)
	_passar_tempo(7.0)
	print("TH ferida sem curativo depois de 7 h: %s" % str(saude.doencas.keys()))
	var v0 := jogador.vida
	_passar_tempo(5.0)
	print("TH inflamada 5 h: vida %.2f -> %.2f" % [v0, jogador.vida])
	print("TH antibiótico: ", saude.tratar("antibiotico"), " -> ", saude.doencas.keys())
	saude.pegar("ferida", 6.0)
	print("TH curativo a tempo: ", saude.tratar("bandagem"), " -> ", saude.doencas.keys())
	# cozinha
	estoque.merge({"po_cafe": 2, "agua": 10, "comida": 10, "carne_crua": 4}, true)
	_alternar_acampamento()
	for rid in ["cafe", "sopa", "ensopado"]:
		print("TH receita %s: pode=%s · %s" % [rid, str(criacao.pode(rid)), criacao.fazer(rid)])
	print("TH cozinha: café %d sopa %d ensopado %d" % [estoque.get("cafe", 0), estoque.get("sopa", 0), estoque.get("ensopado", 0)])
	saude.cansaco = 0.8
	print("TH café: ", saude.tratar("cafe"), " cansaço %.2f" % saude.cansaco)
	saude.pegar("gripe", 20.0)
	print("TH sopa na gripe: ", saude.tratar("sopa"), " gripe %.0f h" % saude.doencas.get("gripe", 0.0))
	print("TH save: ", saude.salvar(), " ok=", Salvar.salvar(self))
	get_tree().quit()

## Teste da etapa 10: obras por setor (fosso, arame), onda noturna com chefe, aliados e consequências.
func _teste_defesa2() -> void:
	await get_tree().process_frame
	var l := {}
	for ll in mundo.lugares_da_regiao(0):
		if ll.tipo == "assentamento":
			l = ll
	jogador.position = l.pos + Vector3(0, 0, 3)
	mundo.atualizar(l.pos)
	for f in 3:
		await get_tree().process_frame
	var a := defesa.no_de(l.id)
	estoque.merge({"sucata": 300, "pecas": 80, "cordame": 12, "comida": 60, "agua": 60, "galoes_diesel": 3}, true)
	for fn in ["vigia", "vigia", "batedor"]:
		base.lista.append(Recrutas.novo("T-" + fn, fn, hash(fn)))
	print("TD2 ", defesa.ficar(l.id))
	var sh := defesa.setor_da_horda(l.id)
	print("TD2 horda vem pelo setor ", Defesa.NOMES_SETOR[sh])
	for obra in ["fosso", "arame", "armadilha", "torre"]:
		print("TD2 ", defesa.construir(l.id, obra, sh))
	var e: Dictionary = defesa.obter(l.id)
	print("TD2 setor: ", _resumo_setor(e, sh), " · nível ", defesa.nivel(e))
	var pn := _painel_setor(l.id, sh)
	print("TD2 painel setor: %s | %s" % [pn.titulo, " / ".join(pn.botoes.map(func(b): return b[0]))])
	# onda 3 (chefe), à noite
	e.ondas = 2
	e.fase = "entre_ondas"
	hora = 23.0
	jogador.visible = false
	defesa.iniciar_onda(l.id)
	print("TD2 onda: n=%d total=%d noturna=%s chefe=%s (%s)" % [defesa.onda.n, defesa.onda.total, str(defesa.onda.noturna), str(defesa.onda.chefe), defesa.onda.chefe_nome])
	Engine.time_scale = 3.0
	var viu_lento := 0
	var arame0: int = e.arames[sh]
	for f in (14000 if not "--rapido" in OS.get_cmdline_user_args() else 0):
		await get_tree().process_frame
		if not defesa.em_combate():
			break
		for z in defesa.onda.vivos:
			if is_instance_valid(z) and z.has_meta("lento"):
				viu_lento += 1
		if f % 1500 == 0:
			print("TD2 t=%d fila=%d vivos=%d muro=%.2f resist=%.2f · %s" % [f, defesa.onda.fila, defesa.onda.vivos.size(), a.muro_medio(), defesa.onda.resistencia, defesa.info_hud().linha])
	Engine.time_scale = 1.0
	print("TD2 fim: fase=%s, zumbis lentos (quadros)=%d, arame %d -> %d" % [e.fase, viu_lento, arame0, e.arames[sh]])
	print("TD2 relatorio: ", hud.relatorio.replace("\n", " | ").substr(0, 400))
	# aliado: presentes e a horda passando de novo
	e.fase = "aliado"
	for k in ["sucata", "pecas", "comida", "agua", "cordame"]:
		estoque[k] = 5
	var c0: int = estoque.comida
	var r0 := base.lista.size()
	for d in 6:
		defesa._aliados(24.0)
	print("TD2 aliado: comida %d -> %d, recrutas %d -> %d" % [c0, estoque.comida, r0, base.lista.size()])
	defesa.z_horda = float(e.pos.z)
	defesa._aliados(1.0)
	print("TD2 horda passou pelo aliado: fase=%s" % e.fase)
	print("TD2 registro: ", " | ".join(base.registro.slice(-4)))
	get_tree().quit()

## Teclas novas (armas e barra rápida), criadas por código para não depender do project.godot.
func _acoes_extras() -> void:
	var teclas := {"binoculo": KEY_Z, "diario": KEY_J, "salvar": KEY_F5, "recarregar": KEY_R, "criar": KEY_B, "slot_1": KEY_1, "slot_2": KEY_2, "slot_3": KEY_3, "slot_4": KEY_4,
		"slot_5": KEY_5, "slot_6": KEY_6, "slot_7": KEY_7, "slot_8": KEY_8, "slot_9": KEY_9}
	for a in teclas:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var ev := InputEventKey.new()
			ev.physical_keycode = teclas[a]
			InputMap.action_add_event(a, ev)
	var botoes := {"mirar": MOUSE_BUTTON_RIGHT, "slot_prox": MOUSE_BUTTON_WHEEL_DOWN, "slot_ant": MOUSE_BUTTON_WHEEL_UP}
	for a in botoes:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var eb := InputEventMouseButton.new()
			eb.button_index = botoes[a]
			InputMap.action_add_event(a, eb)

## Loops de ambiente e motor, conforme lugar, hora e veículo.
func _sons_ambiente(dt: float) -> void:
	var noite := eh_noite()
	var abrigado := dentro != null
	Som.loop("vento", -30.0 if abrigado else (-24.0 if comboio.dirigindo else -16.0))
	Som.loop("noite_grilos", (-20.0 if not abrigado else -30.0) if noite and not comboio.dirigindo else -80.0)
	var v := absf(comboio.velocidade)
	Som.loop("kenney/engine", (-8.0 if comboio.diesel > 0.0 else -80.0) if comboio.dirigindo else -80.0, 0.55 + clampf(v / 22.0, 0.0, 1.0) * 0.85, "Motor")
	_t_radio = maxf(0.0, _t_radio - dt)
	Som.loop("radio_estatica", -12.0 if _t_radio > 0.0 else -80.0)
	if noite and randf() < dt * 0.01:
		for an in mundo.animais:
			if is_instance_valid(an) and an.tipo == "lobo" and an.global_position.distance_to(jogador.global_position) < 120.0:
				Som.em("lobo_uivo", an.global_position + Vector3(0, 1.0, 0), 4.0, 0.1, 8.0)
				break

func _carregar_jogo() -> void:
	if Salvar.preparar():
		get_tree().reload_current_scene()

## Salva agora (F5, ao dormir, periodicamente e ao fechar). mudo = sem aviso na tela.
func salvar_jogo(mudo := false) -> void:
	if Salvar.salvar(self):
		_t_autosave = 0.0
		if not mudo:
			hud.aviso("Jogo salvo.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and jogando and not capturando:
		salvar_jogo(true)

func _comecar(m: String) -> void:
	Salvar.preservar_se_outro_mundo(Jogo.semente)
	Jogo.modo = m
	jogando = true
	hud.visible = true
	jogador.set_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.banner("Modo: " + ("Sobrevivência total" if m == Jogo.MODO_TOTAL else "Estrada sem fim"), "Boa sorte na estrada.")
	if not Tutorial.ja_visto():
		get_tree().create_timer(3.0).timeout.connect(tutorial.iniciar)

func _novo_jogo() -> void:
	Jogo.semente = randi()
	Jogo.modo = ""
	get_tree().reload_current_scene()

# ------------------------------------------------------------ ambiente
func _ambiente() -> void:
	ceu = ShaderMaterial.new()
	ceu.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = ceu
	ambiente = Environment.new()
	ambiente.background_mode = Environment.BG_SKY
	ambiente.sky = sky
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	ambiente.ambient_light_sky_contribution = 0.85
	ambiente.ambient_light_energy = 1.0
	ambiente.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.tonemap_exposure = 1.05
	ambiente.tonemap_white = 6.0
	ambiente.glow_enabled = true
	ambiente.glow_intensity = 0.6
	ambiente.glow_bloom = 0.08
	ambiente.glow_hdr_threshold = 0.9
	ambiente.fog_enabled = true
	ambiente.fog_density = 0.0028
	ambiente.fog_sky_affect = 0.25
	ambiente.fog_aerial_perspective = 0.4
	ambiente.adjustment_enabled = true
	ambiente.adjustment_contrast = 1.12
	ambiente.adjustment_saturation = 0.86
	ambiente.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = ambiente
	add_child(we)
	# fim do mundo ao longe: colunas de fumaça de cidades queimando e cinza no ar
	fumacas = Node3D.new()
	add_child(fumacas)
	var rr := RandomNumberGenerator.new()
	rr.seed = 666
	for i in 4:
		var f := Apocalipse.fumaca(14.0, 160.0)
		f.amount = 30
		var a := rr.randf_range(0.0, TAU)
		f.position = Vector3(cos(a) * rr.randf_range(320.0, 450.0), -10.0, sin(a) * rr.randf_range(320.0, 450.0) + 150.0)
		fumacas.add_child(f)
	cinzas = CPUParticles3D.new()
	cinzas.amount = 140
	cinzas.lifetime = 7.0
	cinzas.preprocess = 7.0
	cinzas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	cinzas.emission_box_extents = Vector3(18, 6, 18)
	cinzas.gravity = Vector3(0.25, -0.35, 0.1)
	cinzas.initial_velocity_min = 0.0
	cinzas.initial_velocity_max = 0.2
	var qm := QuadMesh.new()
	qm.size = Vector2(0.035, 0.035)
	cinzas.mesh = qm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.75, 0.73, 0.7, 0.75)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	cinzas.material_override = cm
	cinzas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cinzas)
	sol = DirectionalLight3D.new()
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 70.0
	sol.shadow_blur = 1.5
	sol.light_angular_distance = 1.0
	add_child(sol)

func _atualizar_ceu() -> void:
	if fumacas and mundo and jogador:
		var fc := _foco()
		fumacas.position = Vector3(fc.x, mundo.elevacao(fc.z), fc.z)
		var cam0 := get_viewport().get_camera_3d()
		mundo.ajustar_origem(cam0.global_position if cam0 else fc)
		var cam := get_viewport().get_camera_3d()
		cinzas.global_position = (cam.global_position if cam else fc) + Vector3(0, 2.0, 0)
	var t := (hora - 6.5) / 12.75
	var alt := sin(t * PI)
	var az := (1.0 - t) * PI - 0.3
	var dir_sol := Vector3(sin(az) * cos(asin(clampf(alt, -1, 1))), alt, cos(az) * cos(asin(clampf(alt, -1, 1)))).normalized()
	var luz_dir := dir_sol
	var dia_f := smoothstep(0.0, 0.35, alt)        # 0 entardecer .. 1 dia pleno
	var noite_f := 1.0 - smoothstep(-0.12, 0.02, alt)
	if alt < -0.02:
		# lua do lado oposto
		luz_dir = Vector3(-dir_sol.x, 0.55, -dir_sol.z).normalized()
	sol.look_at_from_position(Vector3.ZERO, -luz_dir, Vector3.UP if absf(luz_dir.y) < 0.99 else Vector3.RIGHT)
	var cor_tarde := Color(1.0, 0.55, 0.28)
	var cor_dia := Color(1.0, 0.95, 0.88)
	var cor_lua := Color(0.45, 0.55, 0.85)
	var cor_luz := cor_tarde.lerp(cor_dia, dia_f).lerp(cor_lua, noite_f)
	sol.light_color = cor_luz
	sol.light_energy = lerpf(lerpf(1.5, 1.25, dia_f), 0.32, noite_f)
	# céu
	var topo := Color(0.17, 0.12, 0.3).lerp(Color(0.22, 0.42, 0.75), dia_f).lerp(Color(0.02, 0.025, 0.05), noite_f)
	var meio := Color(0.52, 0.26, 0.4).lerp(Color(0.45, 0.62, 0.85), dia_f).lerp(Color(0.06, 0.08, 0.14), noite_f)
	var horiz := Color(1.0, 0.42, 0.15).lerp(Color(0.75, 0.82, 0.88), dia_f).lerp(Color(0.1, 0.11, 0.17), noite_f)
	# tempo fechado: céu cinza, sol fraco, relâmpago clareia tudo
	if clima:
		var k := clima.nuvens * 0.75
		var cinza := Color(0.36, 0.38, 0.42).lerp(Color(0.03, 0.035, 0.05), noite_f)
		topo = topo.lerp(cinza * 0.8, k)
		meio = meio.lerp(cinza, k)
		horiz = horiz.lerp(cinza * 1.1, k)
		sol.light_energy *= 1.0 - clima.nuvens * 0.55
		if clima.flash > 0.0:
			sol.light_energy += clima.flash * 2.5
			topo = topo.lerp(Color(0.7, 0.72, 0.85), clima.flash * 0.7)
			meio = meio.lerp(Color(0.8, 0.82, 0.92), clima.flash * 0.7)
		ceu.set_shader_parameter("cobertura", 0.45 + clima.nuvens * 0.55)
	ceu.set_shader_parameter("cor_topo", topo)
	ceu.set_shader_parameter("cor_meio", meio)
	ceu.set_shader_parameter("cor_horizonte", horiz)
	ceu.set_shader_parameter("cor_sol", Color(1.0, 0.7, 0.35).lerp(Color(1, 0.97, 0.9), dia_f) * (1.0 - noite_f))
	ceu.set_shader_parameter("cor_nuvem_sombra", Color(0.24, 0.14, 0.27).lerp(Color(0.62, 0.66, 0.72), dia_f).lerp(Color(0.03, 0.03, 0.05), noite_f))
	ceu.set_shader_parameter("cor_nuvem_luz", Color(1.0, 0.48, 0.22).lerp(Color(0.98, 0.98, 0.97), dia_f).lerp(Color(0.12, 0.13, 0.18), noite_f))
	ceu.set_shader_parameter("estrelas", noite_f)
	ceu.set_shader_parameter("tempo_nuvem", _tempo)
	var zf := _foco().z if mundo else 0.0
	var cor_bioma := mundo.reg.cor(zf, "nevoa_cor") if mundo else Color(0.55, 0.33, 0.35)
	ambiente.fog_light_color = Color(0.55, 0.33, 0.35).lerp(cor_bioma, 0.6).lerp(Color(0.7, 0.75, 0.82), dia_f * 0.8).lerp(Color(0.03, 0.035, 0.06), noite_f)
	if mundo:
		ambiente.fog_density = mundo.reg.param(zf, "nevoa")
		if clima:
			ambiente.fog_density += clima.neblina * 0.03 + clima.chuva * 0.006 + clima.neve * 0.01
			ambiente.fog_light_color = ambiente.fog_light_color.lerp(Color(0.52, 0.54, 0.58).lerp(Color(0.04, 0.045, 0.06), noite_f), maxf(clima.neblina, clima.nuvens) * 0.7)
	ambiente.ambient_light_energy = lerpf(1.1, 0.9, dia_f) * lerpf(1.0, 0.6, noite_f)
	if trailer:
		trailer.luz_interna = alt < 0.2
	if dentro is Subsolo:
		# lá embaixo não chega luz nenhuma
		ambiente.ambient_light_energy = 0.02
		ambiente.ambient_light_sky_contribution = 0.0
		ambiente.fog_enabled = false
		sol.visible = false


# ------------------------------------------------------------ ciclo principal
## Pausa curtinha no impacto (dá peso ao golpe).
func impacto(pausa := 0.05) -> void:
	if capturando:
		return
	Engine.time_scale = 0.08
	get_tree().create_timer(pausa, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

func _process(dt: float) -> void:
	if capturando:
		return
	if not jogando or _morto:
		return
	_tempo += dt
	mundo.noite = eh_noite()
	comboio.aderencia_clima = clima.aderencia()
	picape.ligar_farol(comboio.dirigindo and (eh_noite() or hora < 6.3 or hora > 18.6 or clima.neblina > 0.5 or clima.chuva > 0.6))
	_avisar_faixa()
	progresso.atualizar(dt)
	if Input.is_action_just_pressed("diario") and not _janela_aberta():
		_abrir_painel(progresso.painel_diario)
	_sons_ambiente(dt)
	eventos.atualizar(dt)
	comboio_extra.atualizar(dt)
	exploracao.atualizar(dt)
	saude.atualizar(dt)
	_t_autosave += dt
	if _t_autosave > 600.0 and not comboio.dirigindo and defesa.onda.is_empty():
		salvar_jogo(true)
	if Input.is_action_just_pressed("salvar"):
		salvar_jogo()
	_passar_tempo(dt * velocidade_tempo)
	_atualizar_acao(dt)
	_combate(dt)
	equip.atualizar(dt, jogador.visible and not comboio.dirigindo and dentro == null and not _janela_aberta() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	defesa.processar(dt)
	base.atualizar_cena(dt)
	_atualizar_ceu()
	var foco := _foco()
	if comboio.dirigindo:
		jogador.position = comboio.porta_motorista()
	mundo.atualizar(foco)
	mundo.processar_fila()
	mundo.mat_capim.set_shader_parameter("tempo", _tempo)
	mundo.ajustar_origem(foco)
	mundo.mat_agua.set_shader_parameter("tempo", _tempo)
	for mf in Floresta.mat_folhas.values():
		mf.set_shader_parameter("tempo", _tempo)
	_t_mapa -= dt
	if _t_mapa <= 0.0:
		_t_mapa = 0.4
		_verificar_mapa(foco)
	_atualizar_hud()
	_interacao()

## Avança o relógio e tudo que depende dele (produção, fome, sede).
func _passar_tempo(h: float) -> void:
	hora += h
	while hora >= 24.0:
		hora -= 24.0
		dia += 1
	_produzir(h)
	base.passar(h)
	if comboio_extra:
		comboio_extra.passar(h)
	if defesa:
		defesa.passar(h)
	if clima:
		clima.passar(h)
	if progresso:
		progresso.passar(h)
	if saude:
		saude.passar(h)
	# inverno: o corpo gasta mais para se aquecer (mais ainda na neve, fora do abrigo)
	var frio := 1.0
	if clima and clima.estacao() == "Inverno":
		frio = 1.3 + (0.3 if clima.neve > 0.3 and dentro == null else 0.0)
	jogador.fome = maxf(0.0, jogador.fome - 0.02 * h * frio)
	jogador.sede = maxf(0.0, jogador.sede - 0.035 * h)
	if jogador.fome <= 0.0 or jogador.sede <= 0.0:
		jogador.vida = maxf(0.05, jogador.vida - 0.02 * h)

func eh_noite() -> bool:
	return hora >= 19.3 or hora < 5.5

## Tarefas que levam horas (consertar, desmontar). Trabalhar no escuro é perigoso.
## Trabalho feito na hora (construir, consertar, criar): o relógio NÃO pula;
## você fica alguns segundos ocupado, com a barra de progresso, enquanto o mundo segue.
func trabalhar(horas: float, texto := "Trabalhando…", anim := "Fixing_Kneeling") -> String:
	iniciar_acao(texto, segundos_acao(horas), Callable(), false, anim)
	if eh_noite() and dentro == null and anim == "Fixing_Kneeling":
		ruido(jogador.global_position, 22.0)   # marteladas no escuro chamam atenção
	return ""

# ------------------------------------------------------------ ações em tempo real
var _acao := {}   # {texto, t, dur, fim, cancelavel}

## Quanto tempo real (s) leva uma tarefa que antes "comia" h horas do dia.
static func segundos_acao(horas: float) -> float:
	return clampf(1.5 + horas * 5.0, 1.5, 12.0)

func ocupado() -> bool:
	return not _acao.is_empty()

## Começa uma ação de alguns segundos. fim é chamado quando a barra enche.
## Cancelável: andar (WASD) interrompe e nada acontece.
func iniciar_acao(texto: String, seg: float, fim := Callable(), cancelavel := true, anim := "Farm_Harvest") -> bool:
	if ocupado():
		return false
	_acao = {"texto": texto, "t": 0.0, "dur": seg, "fim": fim, "cancelavel": cancelavel}
	jogador.preso = not cancelavel
	jogador.anim_trabalho = anim
	hud.acao_txt = texto
	hud.acao_prog = 0.0
	if capturando or "--teste" in " ".join(OS.get_cmdline_user_args()):
		_terminar_acao()   # testes e prints: sem esperar
	return true

func _terminar_acao() -> void:
	var f: Callable = _acao.get("fim", Callable())
	_acao = {}
	jogador.preso = false
	jogador.anim_trabalho = ""
	hud.acao_txt = ""
	if f.is_valid():
		f.call()

func _atualizar_acao(dt: float) -> void:
	if _acao.is_empty():
		return
	if _acao.cancelavel and Input.get_vector("move_left", "move_right", "move_back", "move_forward").length() > 0.3:
		_acao = {}
		jogador.anim_trabalho = ""
		hud.acao_txt = ""
		hud.aviso("Interrompido.")
		return
	_acao.t += dt
	hud.acao_prog = _acao.t / _acao.dur
	if _acao.t >= _acao.dur:
		_terminar_acao()

func _produzir(h: float) -> void:
	for el in comboio.cadeia:
		if not (el is Reboque) or not el.funcional():
			continue
		var r: Reboque = el
		match r.tipo:
			"estufa":
				var bonus := base.bonus_estufa()
				r.comida = minf(r.comida + r.capacidade() * bonus * h / 24.0, r.capacidade() * 2.0)
				r.agua = minf(r.agua + [0, 3, 5, 8][r.nivel] * h / 24.0, 20.0)
				base.colher_estufa(r)
			"oficina":
				if not r.trabalho.is_empty():
					r.trabalho.restante -= h
					if r.trabalho.restante <= 0.0:
						_concluir_trabalho(r)

# ------------------------------------------------------------ carga
func capacidade_carga() -> int:
	var cap: int = [0, 45, 65, 95][picape.nivel("cacamba")] + trailer.capacidade_carga()
	for el in comboio.cadeia:
		if el is Reboque:
			cap += el.capacidade_carga()
	return cap

func volume_usado() -> float:
	var v := 0.0
	for k in ITENS:
		v += estoque.get(k, 0) * ITENS[k].vol
	return v

## Adiciona até onde couber. Devolve quantos entraram.
func adicionar(item: String, qtd: int) -> int:
	var livre := capacidade_carga() - volume_usado()
	var cabem := int(floor(livre / ITENS[item].vol + 0.0001))
	var n := clampi(qtd, 0, maxi(cabem, 0))
	estoque[item] = estoque.get(item, 0) + n
	return n

func tem_itens(itens: Dictionary) -> bool:
	for k in itens:
		if estoque.get(k, 0) < itens[k]:
			return false
	return true

func gastar(itens: Dictionary) -> void:
	for k in itens:
		estoque[k] -= itens[k]

func _txt_itens(itens: Dictionary) -> String:
	var p: Array[String] = []
	for k in itens:
		var tem: int = estoque.get(k, 0)
		var nm: String = ITENS[k].get("um", ITENS[k].nome.to_lower()) if itens[k] == 1 else ITENS[k].nome.to_lower()
		p.append("%d %s (tem %d)" % [itens[k], nm, tem])
	return ", ".join(p)

# ------------------------------------------------------------ combate
func ruido(pos: Vector3, raio: float, _tipo := "") -> void:
	if clima and _tipo != "grito":
		raio *= clima.fator_audicao()
	mundo.ruidos.append({"pos": pos, "raio": raio, "t": 2.5})

func _golpe(origem: Vector3, frente: Vector3) -> void:
	ruido(origem, 10.0)
	var acertou := false
	for z in mundo.zumbis_vivos.duplicate():
		if not is_instance_valid(z) or not z.vivo():
			continue
		var v: Vector3 = z.global_position - origem
		v.y = 0.0
		var d := v.length()
		if d < 2.1 and (d < 0.6 or v.normalized().dot(frente) > 0.45):
			var dano := randf_range(26.0, 38.0)
			if jogador.agachado and z.estado == Zumbi.Estado.VAGANDO:
				dano *= 3.0   # golpe furtivo
			z.ferir(dano, frente * 6.0, origem)
			acertou = true
			if not z.vivo():
				abates += 1
	if acertou:
		hud.acerto()

func zumbi_atacou(z: Zumbi, alvo: Dictionary) -> void:
	if _morto:
		return
	var info: Dictionary = z.info()
	if alvo.tipo == "jogador":
		jogador.levar_dano(equip.absorver(info.dano / 100.0))
		hud.dano()
		var chance := (0.1 if z.tipo != "rastejante" else 0.25) * (1.0 - equip.protecao_mordida())
		if randf() < chance:
			jogador.infeccao = maxf(jogador.infeccao, 0.05)
			hud.aviso("Você foi mordido! Tome um remédio [H] antes que a infecção avance.")
			saude.ferido_por_zumbi()
		elif randf() < 0.12:
			saude.ferido_por_zumbi()
		return
	if alvo.tipo == "recruta":
		var rc: Recruta = alvo.no
		if is_instance_valid(rc) and rc.vivo():
			rc.ferir(info.dano / 100.0 * 0.8)
			if not rc.vivo():
				if defesa.nos.has(rc):
					defesa.morreu(rc)
				else:
					base.morreu(rc)
		return
	if alvo.tipo == "muro":
		var a: Assentamento = alvo.no
		if is_instance_valid(a):
			a.danificar(alvo.idx, info.dano * ({"brutamonte": 2.5, "colosso": 5.0}.get(z.tipo, 1.0) as float))
		return
	if alvo.tipo == "povo":
		defesa.atacar_povo(0.004 + info.dano * 0.0004)
		return
	var v: Node3D = alvo.no
	var dano: float = info.dano_veic
	if v == trailer:
		var protege: float = 1.0 - trailer.config.janelas.nivel * 0.2 * trailer.config.janelas.condicao
		var slots := trailer.config.keys()
		trailer.config[slots[randi() % slots.size()]].condicao = maxf(0.0, trailer.config[slots[randi() % slots.size()]].condicao - dano * protege)
		trailer.condicao_carroceria = maxf(0.05, trailer.condicao_carroceria - dano * 0.5 * protege)
	elif v == picape:
		var prot: float = 1.0 - picape.nivel("protecao") * 0.25
		var slot: String = ["parachoque", "protecao", "santo_antonio", "pneus", "motor"][randi() % 5]
		picape.config[slot].condicao = maxf(0.0, picape.config[slot].condicao - dano * prot)
	elif v is Reboque:
		v.condicao = maxf(0.0, v.condicao - dano)
	if Engine.get_process_frames() % 2 == 0:
		hud.aviso("Zumbis atacando o %s!" % v.nome_exibicao().to_lower())

func _combate(dt: float) -> void:
	mundo.atualizar_ruidos(dt)
	# barulho do motor e da corrida
	_t_motor -= dt
	if _t_motor <= 0.0:
		_t_motor = 0.5
		if comboio.dirigindo:
			ruido(comboio.pos, 22.0 + absf(comboio.velocidade) * 1.6 + (12.0 if comboio.superaquecido else 0.0))
		elif jogador.visible and Input.is_action_pressed("sprint") and not jogador.agachado:
			ruido(jogador.global_position, 11.0)
	# atropelar
	if comboio.dirigindo and absf(comboio.velocidade) > 2.5:
		var fr := picape.global_transform.basis.z
		for z in mundo.zumbis_vivos.duplicate():
			if not is_instance_valid(z) or not z.vivo():
				continue
			var local: Vector3 = picape.global_transform.affine_inverse() * z.global_position
			if absf(local.x) < 1.25 and local.z > -2.9 and local.z < 3.3:
				var vel := absf(comboio.velocidade)
				var forte := vel > 7.0 or picape.nivel("parachoque") >= 3
				z.ferir(400.0 if forte else 35.0, fr * vel * 0.8)
				Som.em("kenney/impact", z.global_position + Vector3(0, 1.0, 0), 2.0, 0.1, 2.0)
				if not z.vivo():
					abates += 1
				var desgaste := 0.04 * (vel / 15.0) / maxf(1.0, picape.nivel("parachoque"))
				if z.tipo == "brutamonte":
					desgaste *= 4.0
					comboio.velocidade *= 0.55
				picape.config.parachoque.condicao = maxf(0.0, picape.config.parachoque.condicao - desgaste)
				comboio.velocidade *= 0.93
	# grupos que chegam à noite atraídos pelo comboio parado
	if eh_noite() and not comboio.dirigindo and not defesa.em_combate():
		_t_horda_noturna -= dt * velocidade_tempo
		if _t_horda_noturna <= 0.0:
			_t_horda_noturna = randf_range(0.6, 1.2)   # horas de jogo
			var seg := seguranca_local()
			var chance = 0.45 + seg[0]
			if seg[0] > -1.0 and randf() < chance and _foco().distance_to(trailer.global_position) < 60.0:
				_grupo_noturno(randi_range(2, 4 + int(mundo.perigo(_foco().z) * 0.7)) + base.n("vigia"))
	# morte
	if jogador.vida <= 0.0:
		_morrer("Os zumbis te pegaram.")
	elif jogador.infeccao >= 1.0:
		_morrer("A infecção tomou conta do seu corpo.")

func _grupo_noturno(n: int) -> void:
	var a := randf() * TAU
	var centro := trailer.global_position + Vector3(cos(a), 0, sin(a)) * 38.0
	for i in n:
		var p := centro + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		p.y = mundo.altura(p.x, p.z)
		var z := mundo.criar_zumbi(mundo, p, a + PI, randi(), "corredor" if randf() < 0.25 + 0.06 * mundo.faixa(p.z) else "")
		z.estado = Zumbi.Estado.INVESTIGANDO
		z.alvo_pos = trailer.global_position
	var vig := base.presentes("vigia")
	if not vig.is_empty():
		var dirs := ["norte", "noroeste", "oeste", "sudoeste", "sul", "sudeste", "leste", "nordeste"]
		var ang := fposmod(atan2(-(centro.x - trailer.global_position.x), centro.z - trailer.global_position.z), TAU)
		hud.aviso("%s: \"Zumbis vindo do %s! %d deles!\"" % [vig[0].nome, dirs[int(round(ang / (TAU / 8.0))) % 8], n])
	else:
		hud.aviso("Algo se move no escuro...")

func abate_recruta(r: Recruta) -> void:
	base.abate(r)

## Anota algo para o relatório da manhã.
func registrar(t: String) -> void:
	base.registro.append(t)

func _usar_remedio() -> String:
	if estoque.get("remedio", 0) <= 0:
		return "Sem remédios."
	estoque.remedio -= 1
	var tinha := jogador.infeccao > 0.0
	jogador.infeccao = maxf(0.0, jogador.infeccao - 0.6)
	jogador.vida = minf(1.0, jogador.vida + 0.15)
	return "Remédio tomado." + (" A infecção recuou." if tinha else "") + saude.tratar("remedio")

# ------------------------------------------------------------ morte e modos
func _morrer(causa: String) -> void:
	if _morto:
		return
	_morto = true
	Jogo.mortes += 1
	defesa.abortar()
	if dentro != null:
		_sair_de_dentro()
	if comboio.dirigindo:
		_sair_do_carro()
	jogador.set_process(false)
	var km := comboio.odometro / 1000.0
	if Jogo.modo == Jogo.MODO_TOTAL:
		Salvar.apagar()
		menu.mostrar_morte(causa, ["Você sobreviveu %d dias e rodou %.1f km." % [dia, km],
			"Zumbis abatidos: %d   ·   Lugares descobertos: %d" % [abates, conhecidos.size()],
			"No modo Sobrevivência total, tudo recomeça do zero."], true)
	else:
		menu.mostrar_morte(causa, _penalidades(), false)

## Modo infinito: perdas pesadas, mas o jogo continua.
func _penalidades() -> Array:
	var linhas: Array = []
	var r := RandomNumberGenerator.new()
	r.randomize()
	var perdidos: Array[String] = []
	var quebrados: Array[String] = []
	for i in range(comboio.cadeia.size() - 1, 0, -1):
		var reb: Reboque = comboio.cadeia[i]
		if r.randf() < 0.35:
			perdidos.append(reb.nome_exibicao())
			comboio.desengatar(i)
			reb.queue_free()
		else:
			reb.condicao *= 0.3
			quebrados.append(reb.nome_exibicao())
			reb.reconstruir()
	if not perdidos.is_empty():
		linhas.append("Reboques perdidos: " + ", ".join(perdidos))
	if not quebrados.is_empty():
		linhas.append("Reboques muito danificados: " + ", ".join(quebrados))
	for slot in trailer.config:
		trailer.config[slot].condicao *= 0.5
	trailer.condicao_carroceria = maxf(0.1, trailer.condicao_carroceria * 0.6)
	trailer.reconstruir()
	for slot in picape.config:
		picape.config[slot].condicao *= 0.6
	picape.reconstruir()
	linhas.append("O trailer e a picape foram depredados (−50% / −40% de condição).")
	var perdeu: Array[String] = []
	for k in ITENS:
		var antes: int = estoque.get(k, 0)
		if antes > 0:
			estoque[k] = int(antes * 0.5)
			if antes - estoque[k] > 0:
				perdeu.append("%d %s" % [antes - estoque[k], ITENS[k].nome.to_lower()])
	if not perdeu.is_empty():
		linhas.append("Carga saqueada: " + ", ".join(perdeu))
	comboio.diesel *= 0.5
	linhas.append(base.penalidade(r))
	return linhas

func _acordar_apos_queda() -> void:
	_morto = false
	if acampamento:
		_alternar_acampamento()
	for z in mundo.zumbis_vivos.duplicate():
		if is_instance_valid(z) and z.global_position.distance_to(trailer.global_position) < 50.0:
			z.queue_free()
	var horas := (24.0 - hora + 7.0) if hora >= 7.0 else (7.0 - hora)
	_passar_tempo(horas)
	_atualizar_ceu()
	jogador.vida = 0.45
	jogador.infeccao = 0.0
	jogador.estamina = 0.6
	jogador.set_process(true)
	_entrar_em(trailer)
	hud.relatorio = "Você acordou no trailer, ferido. O comboio pagou o preço."
	salvar_jogo(true)
	hud.relatorio_titulo = ""
	hud.relatorio_t = 6.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ------------------------------------------------------------ mapa: regiões, descobertas, acampamento
func _foco() -> Vector3:
	if dentro is Subsolo:
		return dentro.global_position
	if comboio and (comboio.dirigindo or dentro != null):
		return comboio.pos
	return jogador.position if jogador else Vector3.ZERO

func _verificar_mapa(p: Vector3) -> void:
	var ri := mundo.regiao_em(p.z)
	if ri != _regiao_atual:
		_regiao_atual = ri
		var b: Dictionary = mundo.reg.info_bioma(ri)
		hud.banner(mundo.reg.nome(ri), "%s · região %d" % [b.nome, ri + 1])
	var m := mundo.reg.marco(ri)
	if not _avisou_marco.has(ri) and m.z - p.z < 1500.0 and m.z > p.z:
		_avisou_marco[ri] = true
		hud.aviso(("Adiante: ponte caída. Procure o vau." if m.tipo == "ponte" else "Adiante: bloqueio militar. Procure o desvio."))
	for l in mundo.lugares_da_regiao(ri):
		if conhecidos.has(l.id):
			continue
		var placa := mundo.ponto_estrada(l.juncao_z, 0.0)
		if p.distance_to(placa) < 70.0 or Vector2(p.x - l.pos.x, p.z - l.pos.z).length() < 130.0:
			conhecidos[l.id] = {"nome": l.nome, "tipo": l.tipo, "pos": l.pos, "regiao": ri}
			hud.aviso("Descoberto: %s" % l.nome)

## Aviso ao entrar numa faixa de perigo nova (uma vez por jogo).
func _avisar_faixa() -> void:
	var f := mundo.faixa(_foco().z)
	var chave := "faixa%d" % f
	if f == 0 or _avisou_marco.has(chave):
		return
	_avisou_marco[chave] = true
	var fx: Dictionary = WorldGen.FAIXAS[f]
	hud.banner(fx.nome.to_upper(), "km %d · %s" % [int(fx.km), fx.txt])
	Som.tela("radio_estatica", -10.0)

## O comboio ganha um cachorro.
func adotar_cachorro(nome: String, raca: String, pos: Vector3, vida := 1.0) -> void:
	if cachorro and is_instance_valid(cachorro):
		cachorro.queue_free()
	cachorro = Cachorro.new()
	cachorro.main = self
	cachorro.nome = nome
	cachorro.raca = raca
	cachorro.vida = vida
	add_child(cachorro)
	cachorro.global_position = pos
	cachorro.global_position.y = jogador.chao(pos)

func _queimar_ninho(ni: Ninho) -> void:
	if estoque.get("molotov", 0) > 0:
		estoque.molotov -= 1
	elif estoque.get("galoes_diesel", 0) > 0:
		estoque.galoes_diesel -= 1
	else:
		hud.aviso("Precisa de um molotov ou de um galão de diesel para queimar o ninho.")
		return
	hud.relatorio = ni.queimar(self)
	hud.relatorio_titulo = "Ninho queimado"
	hud.relatorio_t = 7.0

func _vasculhar(v: Node3D) -> void:
	if mundo.vasculhados.has(String(v.get_meta("chave"))):
		return
	iniciar_acao("Vasculhando: %s" % String(v.get_meta("nome")).to_lower(), segundos_acao(v.get_meta("horas")), _vasculhar_fim.bind(v))

func _vasculhar_fim(v: Node3D) -> void:
	if not is_instance_valid(v):
		return
	var chave: String = v.get_meta("chave")
	var tab_nome: String = v.get_meta("tabela")
	var pai := v.get_parent()
	while pai and not (pai is Predio):
		pai = pai.get_parent()
	if pai and pai.has_meta("tabela_loja") and tab_nome == "prateleira":
		tab_nome = pai.get_meta("tabela_loja")
	var tabela: Dictionary = TABELAS[tab_nome]
	var r := RandomNumberGenerator.new()
	r.seed = hash(chave)
	var ev := ""
	var ganhos: Array[String] = []
	var fartura := mundo.fartura_diesel(v.global_position.z)
	for item in tabela:
		var t: Array = tabela[item]
		var chance: float = t[2] * (fartura if item == "galoes_diesel" else 1.0)
		if r.randf() > chance:
			continue
		var n := adicionar(item, r.randi_range(t[0], t[1]))
		if n > 0:
			ganhos.append("%d %s" % [n, ITENS[item].nome.to_lower()])
	mundo.vasculhados[chave] = true
	if cachorro and is_instance_valid(cachorro) and cachorro.vivo() and cachorro.global_position.distance_to(v.global_position) < 8.0 and r.randf() < 0.35:
		var extra: String = ["comida", "municao_pistola", "bandagem", "pecas", "remedio"][r.randi() % 5]
		var ne := adicionar(extra, 1 if extra == "remedio" else r.randi_range(1, 3))
		if ne > 0:
			ganhos.append("%d %s (o %s achou)" % [ne, ITENS[extra].nome.to_lower(), cachorro.nome])
	if base.n("crianca") > 0 and v.global_position.distance_to(trailer.global_position) < 150.0 and r.randf() < 0.3:
		var miudo: String = ["municao_pistola", "bandagem", "pecas", "remedio", "comida"][r.randi() % 5]
		var nm := adicionar(miudo, 1)
		if nm > 0:
			ganhos.append("1 %s (%s achou num cantinho)" % [ITENS[miudo].nome.to_lower(), base.presentes("crianca")[0].nome])
	var carta := progresso.talvez_carta(chave)
	if carta != "":
		ganhos.append(carta.to_lower())
	hud.aviso("%s: %s" % [v.get_meta("nome"), ", ".join(ganhos) if not ganhos.is_empty() else "nada que coubesse na carga"])
	if ev != "":
		hud.relatorio = ev
		hud.relatorio_titulo = ""
		hud.relatorio_t = 5.0

func _painel_npc(h: Node3D) -> Dictionary:
	var funcao: String = h.get_meta("funcao")
	if funcao == "lider":
		return _painel_lider(h.get_meta("assent"), h.get_meta("nome"))
	var titulos := {"vendedor": "Vendedor", "vigia": "Vigia", "mecanico": "Mecânico", "agricultor": "Agricultor", "medico": "Médico", "morador": "Morador", "batedor": "Batedor"}
	var linhas: Array = ["\"%s\"" % h.get_meta("fala")]
	var botoes: Array = []
	var banca := Comercio.banca_de(h)
	if banca != "":
		var lid := Comercio.lugar_de(h)
		var lg := comercio._lugar(lid)
		linhas.append(["Comerciante · reputação: %s · crédito: %d" % [Comercio.nivel_rep(lg.rep), lg.credito.get("lugar", 0)], Hud.DOURADO])
		botoes.append(["Negociar", func(): comercio.abrir(h); return "", true])
		var pres := comercio.presente_aliado(lid)
		if pres != "":
			linhas.append([pres, Color(0.6, 0.85, 0.6)])
	if Recrutas.pode_recrutar(h):
		var fr: String = Recrutas.funcao_de_npc(funcao, h)
		var info: Dictionary = Recrutas.FUNCOES[fr]
		var ped := Recrutas.pedido_de(h)
		var ttl := Recrutas.titulo({"funcao": fr, "nome": h.get_meta("nome")})
		linhas.append(["Pode entrar para o comboio como %s." % ttl.to_lower(), Hud.DOURADO])
		linhas.append("Na base: %s." % info.auto)
		linhas.append("Na defesa: %s." % info.defesa.to_lower())
		linhas.append("Pede para vir: %s." % _txt_itens(ped))
		var c := base.camas()
		linhas.append(["Camas no comboio: %d ocupadas de %d." % [base.lista.size(), c], Color(0.75, 0.75, 0.72) if base.camas_livres() > 0 else Color(0.95, 0.45, 0.3)])
		var motivo := base.pode_recrutar(h)
		if motivo != "":
			linhas.append([motivo, Color(0.95, 0.45, 0.3)])
		botoes.append(["Convidar para o comboio", base.recrutar.bind(h), motivo == ""])
	return {"titulo": "%s — %s" % [h.get_meta("nome"), titulos.get(funcao, "Morador")], "linhas": linhas, "botoes": botoes}

# ------------------------------------------------------------ assentamento: conversa com o líder
var _lider_aberto := []
func _painel_lider_atual() -> Dictionary:
	return _painel_lider(_lider_aberto[0], _lider_aberto[1]) if _lider_aberto.size() == 2 else {"titulo": "", "linhas": [], "botoes": []}

func _painel_lider(id: String, nome_lider: String) -> Dictionary:
	_lider_aberto = [id, nome_lider]
	var e: Dictionary = defesa.obter(id)
	var a: Assentamento = defesa.no_de(id)
	var linhas: Array = []
	var botoes: Array = []
	var cinza := Color(0.7, 0.7, 0.68)
	var vermelho := Color(0.95, 0.45, 0.3)
	var fases := {"livre": "esperando a horda", "preparando": "se preparando com você", "onda": "sob ataque",
		"entre_ondas": "entre uma onda e outra", "aliado": "aliado", "caido": "caído"}
	linhas.append(["Nível %d · %s · %d moradores (%d vigias, %d armados)%s" % [defesa.nivel(e), fases.get(e.fase, e.fase), e.moradores, e.vigias, e.armados,
		(" · defendido %d onda%s" % [e.ondas, "s" if e.ondas > 1 else ""]) if e.ondas > 0 else ""], Hud.DOURADO])
	if a:
		var torres := 0
		var holo := 0
		for k in 4:
			torres += 1 if e.torres[k] else 0
			holo += 1 if e.holofotes[k] else 0
		var est_arm := 0
		for k in 4:
			est_arm += e.armadilhas[k]
		linhas.append("Muro de %s: %d%%  ·  Portão %s  ·  Torres: %d (holofotes: %d)  ·  Estacas: %d cargas" % [
			"chapas" if e.chapas else "paliçada", int(a.muro_medio() * 100.0), "reforçado" if e.portao else "de madeira", torres, holo, est_arm])
	linhas.append("Depósito do assentamento: %d sucata, %d peças (usado antes do seu estoque)." % [e.estoque.sucata, e.estoque.pecas])
	var h: float = defesa.horas_ate(e.pos.z)
	match e.fase:
		"livre":
			linhas.append("\"A horda vem pela estrada, %.1f km para trás. Chega aqui em umas %d horas. Se você ficar, a gente aguenta.\"" % [defesa.km_horda(e.pos.z), int(h)])
			linhas.append(["Ficando, as ondas não param: vencida uma, vem outra maior. Dá para partir entre elas.", cinza])
			botoes.append(["Ficar e defender", func(): return defesa.ficar(id), true])
			botoes.append(["Seguir viagem", func(): return defesa.partir(id), true])
		"preparando", "entre_ondas":
			if e.fase == "preparando":
				linhas.append(["A horda chega em ~%d h. Use o tempo para preparar o muro." % int(ceil(h)), vermelho])
			else:
				linhas.append(["Próxima onda: %d zumbis em ~%d h." % [defesa.tamanho_onda(e.ondas + 1), int(ceil(e.prox_onda_h))], vermelho])
			if (e.ondas + 1) % 3 == 0:
				linhas.append(["\"Os batedores viram uma coisa enorme no meio deles. A próxima onda vem com %s.\"" % Defesa.CHEFES[((e.ondas + 1) / 3 - 1) % Defesa.CHEFES.size()], vermelho])
			# melhorias
			var opcoes: Array = []
			var cc := defesa.custo_conserto(id)
			if not cc.is_empty():
				opcoes.append(["Consertar o muro (%s)" % _txt_custo(cc), func(): return defesa.consertar(id), defesa.pode_pagar(e, cc)])
			if not e.chapas:
				opcoes.append(_opcao_obra(id, e, "chapas"))
			if not e.portao:
				opcoes.append(_opcao_obra(id, e, "portao"))
			# o resto se escolhe por setor do muro
			var sh := defesa.setor_da_horda(id)
			for k in 4:
				botoes.append(["Planejar o setor %s%s: %s" % [Defesa.NOMES_SETOR[k], " (a horda vem por aqui)" if k == sh else "", _resumo_setor(e, k)],
					func(): _abrir_painel(_painel_setor.bind(id, k)); return "", true])
			botoes.append_array(opcoes)
			# postos dos recrutas
			for rc in base.presentes():
				botoes.append(["%s: %s" % [rc.nome, Defesa.NOMES_POSTO[defesa.posto_de(e, rc)]], func(): defesa.trocar_posto(id, rc.nome); return "", true])
			botoes.append(["Esperar a %s" % ("horda" if e.fase == "preparando" else "próxima onda"), func(): return defesa.esperar(id), true])
			botoes.append(["Partir agora", func(): return defesa.partir(id), true])
			if base.lista.is_empty():
				linhas.append(["Sem recrutas, só os moradores e você vão estar no muro.", cinza])
			else:
				linhas.append(["Seus recrutas vão para os postos marcados nos botões (clique para trocar).", cinza])
			if _comboio_no_portao(a):
				linhas.append(["O comboio está estacionado no portão: vira parte da muralha (portão mais forte).", Color(0.55, 0.85, 0.5)])
			else:
				linhas.append(["Estacione o comboio colado no portão para reforçar a entrada com os reboques.", cinza])
		"aliado":
			linhas.append("\"Você salvou a gente. Aqui sempre vai ter um prato e um lugar no muro para você.\"")
		"onda":
			linhas.append(["Estão no muro! Vai!", vermelho])
	return {"titulo": "%s — %s" % [e.nome, nome_lider], "subtitulo": "Líder do assentamento", "linhas": linhas, "botoes": botoes}

func _resumo_setor(e: Dictionary, k: int) -> String:
	var p: Array[String] = []
	if e.torres[k]:
		p.append("torre" + (" c/ holofote" if e.holofotes[k] else ""))
	if e.armadilhas[k] > 0:
		p.append("estacas %d" % e.armadilhas[k])
	if e.get("fossos", [false, false, false, false])[k]:
		p.append("fosso")
	if e.get("arames", [0, 0, 0, 0])[k] > 0:
		p.append("arame %d" % e.arames[k])
	return ", ".join(p) if not p.is_empty() else "nada"

## Um setor do muro: escolha o que construir ali.
func _painel_setor(id: String, k: int) -> Dictionary:
	var e: Dictionary = defesa.obter(id)
	defesa._garantir(e)
	var sh := defesa.setor_da_horda(id)
	var linhas: Array = []
	linhas.append(["Setor %s: %s" % [Defesa.NOMES_SETOR[k], _resumo_setor(e, k)], Hud.DOURADO])
	if k == sh:
		linhas.append(["É por aqui que a horda costuma chegar (vem pela estrada, de trás).", Color(0.95, 0.45, 0.3)])
	linhas.append(["Do muro para fora: arame colado no muro, estacas a 3 m, fosso a 7 m.", Color(0.7, 0.7, 0.68)])
	linhas.append("Depósito do assentamento: %d sucata, %d peças · Seu estoque: %d sucata, %d peças, %d cordas, %d comida" % [e.estoque.sucata, e.estoque.pecas, estoque.get("sucata", 0), estoque.get("pecas", 0), estoque.get("cordame", 0), estoque.get("comida", 0)])
	var botoes: Array = []
	if not e.torres[k]:
		botoes.append(_opcao_obra(id, e, "torre", k))
	elif not e.holofotes[k]:
		botoes.append(_opcao_obra(id, e, "holofote", k))
	if e.armadilhas[k] < 36:
		botoes.append(_opcao_obra(id, e, "armadilha", k))
	if not e.fossos[k]:
		botoes.append(_opcao_obra(id, e, "fosso", k))
	if e.arames[k] < 80:
		botoes.append(_opcao_obra(id, e, "arame", k))
	botoes.append(["Voltar", func(): _abrir_painel(_painel_lider_atual); return "", true])
	return {"titulo": "SETOR %s" % Defesa.NOMES_SETOR[k].to_upper(), "subtitulo": e.nome, "linhas": linhas, "botoes": botoes}

func _opcao_obra(id: String, e: Dictionary, chave: String, alvo := -1) -> Array:
	var c: Dictionary = Defesa.CUSTOS[chave]
	var nome: String = c.nome
	if chave == "armadilha":
		nome = "Estacas (+12 cargas)"
	elif chave == "arame":
		nome = "Arame farpado (+40 cargas)"
	elif chave == "torre":
		nome = "Torre de vigia"
	elif chave == "holofote":
		nome = "Holofote na torre"
	return ["%s (%s, %s)" % [nome, _txt_custo(c.itens), _txt_horas(c.horas)], func(): return defesa.construir(id, chave, alvo), defesa.pode_pagar(e, c.itens)]

func _txt_custo(itens: Dictionary) -> String:
	var p: Array[String] = []
	var curtos := {"sucata": "sucata", "pecas": "peças", "galoes_diesel": "galão", "comida": "comida", "agua": "água", "cordame": "corda", "tecido": "tecido", "couro": "couro", "pele": "pele", "chapa": "chapa"}
	for k in itens:
		var nm: String = curtos.get(k, "")
		if nm == "":
			nm = ITENS[k].get("um", ITENS[k].nome.to_lower()) if itens[k] == 1 else ITENS[k].nome.to_lower()
		p.append("%d %s" % [itens[k], nm])
	return ", ".join(p)

func _comboio_no_portao(a: Assentamento) -> bool:
	if a == null:
		return false
	var portao_g := a.global_de(Assentamento.ponto(0, Assentamento.R))
	for el in comboio.cadeia:
		if el.global_position.distance_to(portao_g) < 18.0:
			return true
	return false

## Segurança do lugar onde o comboio está parado: [modificador de risco, descrição].
func seguranca_local() -> Array:
	var tp := trailer.global_position
	var l := mundo.lugar_em(tp)
	if not l.is_empty() and l.tipo == "vila":
		return [-1.0, "dentro dos muros da %s" % l.nome]
	if not l.is_empty() and l.tipo == "assentamento" and defesa.obter(l.id).fase != "caido":
		return [-1.0, "dentro do %s" % l.nome]
	var mod := 0.0
	var partes: Array[String] = []
	if acampamento:
		mod -= 0.25
		partes.append("acampamento montado")
	if base.n("vigia") > 0:
		mod += base.bonus_seguranca()
		partes.append("%d vigia%s de guarda" % [base.n("vigia"), "s" if base.n("vigia") > 1 else ""])
	if not l.is_empty() and l.tipo == "fazenda":
		mod -= 0.15
		partes.append("cerca da fazenda")
	var lat := absf(tp.x - mundo.centro_x(tp.z))
	if lat < 12.0:
		mod += 0.1
		partes.append("à beira da estrada")
	elif tp.y - mundo.elevacao(tp.z) > 4.0:
		mod -= 0.08
		partes.append("no alto do morro")
	return [mod, ", ".join(partes) if not partes.is_empty() else "no meio do mato"]

func _alternar_acampamento() -> void:
	if acampamento:
		acampamento.queue_free()
		mundo.obstaculos_extra.erase(acampamento)
		acampamento = null
		hud.aviso("Acampamento desmontado.")
		return
	var ac := Acampamento.new()
	ac.main = self
	add_child(ac)
	ac.montar()
	acampamento = ac
	trailer.cozinha_aberta = 1.0
	trailer.reconstruir()
	var seg := seguranca_local()
	hud.aviso("Acampamento montado (%s)." % seg[1])

# ------------------------------------------------------------ HUD
func _atualizar_hud() -> void:
	hud.hora = hora
	hud.dia = dia
	hud.recrutas_txt = base.texto_hud()
	hud.aliados = base.posicoes()
	hud.trailer_pos = trailer.global_position
	hud.dirigindo = comboio.dirigindo
	hud.km_h = comboio.km_h()
	hud.re = comboio.velocidade < -0.3
	hud.diesel = comboio.diesel
	hud.tanque = comboio.tanque()
	hud.fora_estrada = comboio.fora_da_estrada
	hud.marcadores = marcadores
	hud.interior = dentro != null
	hud.mira = dentro != null
	hud.carga_usada = volume_usado()
	hud.carga_max = capacidade_carga()
	hud.temperatura = comboio.temperatura
	hud.superaquecido = comboio.superaquecido
	hud.peso_rebocado = comboio.peso_rebocado()
	hud.capacidade_reboque = picape.capacidade_reboque()
	hud.projetos = estoque.projetos.size()
	hud.lugares = conhecidos.values()
	var zp: Array[Vector3] = []
	var f := _foco()
	for z in mundo.zumbis_vivos:
		if is_instance_valid(z) and z.vivo() and z.global_position.distance_to(f) < 60.0:
			zp.append(z.global_position)
	zp.append_array(exploracao.posicoes_marcadas())
	hud.zumbis = zp
	hud.infeccao = jogador.infeccao
	hud.itens = equip.itens_hud()
	hud.slot_ativo = maxi(0, equip.slots().find(equip.sel))
	hud.arma_txt = equip.texto_arma() if jogador.visible and not comboio.dirigindo and dentro == null else ""
	hud.recarga = equip.progresso_recarga()
	hud.mirando = jogador.mirando
	hud.defesa_armadura = equip.defesa()
	hud.defesa = defesa.info_hud()
	hud.horda_txt = defesa.texto_horda()
	var tr_radio := comboio_extra.texto_radio()
	if tr_radio != "" and hud.horda_txt != "":
		hud.horda_txt += " · " + tr_radio
	hud.clima_txt = "%s · %s" % [clima.nome(), clima.estacao()]
	hud.dirigindo = comboio.dirigindo
	hud.mira = dentro != null or (jogador.visible and not comboio.dirigindo)
	if comboio.dirigindo:
		var ob := progresso.objetivo()
		hud.objetivo = ob[0]
		hud.subobjetivo = ob[1]
	else:
		var la := mundo.lugar_em(jogador.position)
		if not la.is_empty() and la.tipo == "assentamento":
			var ea: Dictionary = defesa.obter(la.id)
			hud.objetivo = ea.nome
			match ea.fase:
				"livre":
					hud.subobjetivo = "Fale com o líder: ficar ou seguir?"
				"preparando":
					hud.subobjetivo = "Prepare o muro (horda em ~%d h)" % int(ceil(defesa.horas_ate(ea.pos.z)))
				"onda":
					hud.subobjetivo = "Segure o muro!"
				"entre_ondas":
					hud.subobjetivo = "Conserte o muro ou parta (~%d h)" % int(ceil(ea.prox_onda_h))
				"aliado":
					hud.subobjetivo = "Assentamento aliado"
				"caido":
					hud.subobjetivo = "Caiu para a horda. Cuidado."

# ------------------------------------------------------------ interações
func _janela_aberta() -> bool:
	return oficina.visible or painel.visible or Engine.get_process_frames() - _frame_fechou < 2

func _fechar_janela() -> void:
	for id in trailer.compartimentos_abertos:
		if trailer.compartimentos_abertos[id] and not _compartimento_preso:
			trailer.abrir_compartimento(id, false)
	oficina.visible = false
	painel.visible = false
	_frame_fechou = Engine.get_process_frames()
	if dentro == null and not comboio.dirigindo:
		jogador.set_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _abrir_painel(gerador: Callable) -> void:
	jogador.set_process(false)
	painel.mostrar(gerador)

func _interacao() -> void:
	hud.dica = ""
	if _janela_aberta() or ocupado():
		return
	if not comboio.dirigindo and Input.is_action_just_pressed("criar"):
		_abrir_painel(criacao.painel)
		return
	if dentro != null:
		_interacao_interior()
	elif comboio.dirigindo:
		_interacao_dirigindo()
	else:
		_interacao_a_pe()

func _interacao_a_pe() -> void:
	if Input.is_action_just_pressed("curar"):
		hud.aviso(_usar_remedio())
	var p := jogador.position
	var cands: Array = []
	var add := func(alvo: Vector3, raio: float, tecla: String, texto: String, f: Callable):
		var d := Vector2(p.x - alvo.x, p.z - alvo.z).length()
		if d < raio:
			cands.append({"d": d, "tecla": tecla, "texto": texto, "f": f})
	add.call(comboio.porta_motorista(), 1.8, "dirigir", "[F] Dirigir", _entrar_no_carro)
	add.call(trailer.global_transform * trailer.ponto_entrada(), 1.4, "interact", "[E] Entrar no trailer", _entrar_em.bind(trailer))
	for cid in Trailer.COMPARTIMENTOS:
		add.call(trailer.global_transform * trailer.ponto_compartimento(cid), 1.1, "interact", "[E] Abrir: %s" % Trailer.COMPARTIMENTOS[cid].nome, _abrir_compartimento.bind(cid))
	add.call(trailer.global_transform * Vector3(-1.4, 0, -0.6), 1.5, "interact",
		"[E] " + ("Fechar cozinha" if trailer.cozinha_aberta > 0.5 else "Abrir cozinha"), _alternar_cozinha)
	add.call(trailer.global_transform * Vector3(1.6, 0, 0.9), 1.2, "interact", "[E] Pintar o comboio", _abrir_painel.bind(comboio_extra.painel_visual))
	if comboio_extra.pneu_furado:
		add.call(picape.global_transform * Vector3(1.3, 0, 1.6), 2.2, "interact", "[E] Trocar o pneu furado (1 pneu, %s)" % _txt_horas(0.33), func(): hud.aviso(comboio_extra.trocar_pneu()))
	if estoque.galoes_diesel > 0 and comboio.diesel < comboio.tanque() - 1.0:
		add.call(picape.global_transform * Vector3(1.2, 0, -1.9), 1.6, "abastecer", "[R] Abastecer com galão (20 L)", _abastecer_galao)
	for i in range(1, comboio.cadeia.size()):
		var r: Reboque = comboio.cadeia[i]
		var txt := ("[E] Entrar: " if r.tem_interior() else "[E] Painel: ") + r.nome_exibicao()
		add.call(r.global_transform * r.ponto_entrada(), 1.5, "interact", txt, _entrar_em.bind(r))
	for r in mundo.reboques_soltos:
		if is_instance_valid(r):
			add.call(r.global_position, 4.2, "interact", "[E] Examinar %s %s" % [r.nome_exibicao().to_lower(), r.abandonado_txt()], _abrir_painel.bind(_painel_resgate.bind(r)))
	for c in mundo.carros_soltos:
		if is_instance_valid(c):
			add.call(c.global_position, 3.0, "interact", "[E] Desmontar carro (%s)" % _txt_horas(2.0), _desmontar.bind(c))
	for v in mundo.vasculhaveis:
		if is_instance_valid(v) and not mundo.vasculhados.has(v.get_meta("chave")) and absf(v.global_position.y - p.y - 1.0) < 1.6:
			if exploracao.trancado(v):
				add.call(v.global_position, 3.5, "interact", "[E] %s (trancado)" % v.get_meta("nome"), _abrir_painel.bind(exploracao.painel_tranca.bind(v)))
			else:
				add.call(v.global_position, 3.5, "interact", "[E] Vasculhar: %s (%s)" % [v.get_meta("nome"), _txt_horas(v.get_meta("horas"))], _vasculhar.bind(v))
	if cachorro and is_instance_valid(cachorro) and cachorro.vivo():
		add.call(cachorro.global_position, 1.8, "interact", "[E] %s" % cachorro.nome, _abrir_painel.bind(cachorro.painel))
	for ss in mundo.subsolos:
		if is_instance_valid(ss):
			add.call(ss.global_position, 2.0, "interact", "[E] Descer no %s%s" % [ss.nome_exibicao().to_lower(), "" if estoque.get("lanterna", 0) > 0 else " (escuro: sem lanterna)"], _entrar_em.bind(ss))
	for ni in mundo.ninhos:
		if is_instance_valid(ni) and not ni.queimado:
			add.call(ni.global_position, 4.5, "interact", "[E] Queimar o ninho (%s)" % ("molotov" if estoque.get("molotov", 0) > 0 else "1 galão de diesel"), _queimar_ninho.bind(ni))
	for an in mundo.animais:
		if is_instance_valid(an) and not an.vivo() and not an.esfolado:
			add.call(an.global_position, 2.2, "interact", "[E] Esfolar %s (%s)" % [an.info().nome, _txt_horas(0.5)], _esfolar.bind(an))
	for h in mundo.npcs:
		if is_instance_valid(h):
			add.call(h.global_position, 2.2, "interact", "[E] Falar com %s" % h.get_meta("nome"), _abrir_painel.bind(_painel_npc.bind(h)))
	for rn in base.nos:
		if is_instance_valid(rn) and rn.vivo():
			add.call(rn.global_position, 2.0, "interact", "[E] Falar com %s (%s)" % [rn.dados.nome, Recrutas.titulo(rn.dados).to_lower()], _abrir_painel.bind(_painel_recruta.bind(rn.dados)))
	var perto_comboio := p.distance_to(picape.global_position) < 6.0
	for el in comboio.cadeia:
		if p.distance_to(el.global_position) < 5.0:
			perto_comboio = true
	if cands.is_empty():
		if perto_comboio:
			hud.dica = "[Tab] Oficina"
	else:
		cands.sort_custom(func(a, b): return a.d < b.d)
		var c: Dictionary = cands[0]
		hud.dica = c.texto + ("   [Tab] Oficina" if perto_comboio else "")
		if Input.is_action_just_pressed(c.tecla):
			c.f.call()
			return
	if perto_comboio and Input.is_action_just_pressed("oficina"):
		_abrir_oficina()
	if perto_comboio and absf(comboio.velocidade) < 0.5:
		if cands.is_empty():
			hud.dica = "[Tab] Oficina   [C] " + ("Desmontar acampamento" if acampamento else "Montar acampamento")
		if Input.is_action_just_pressed("acampar"):
			_alternar_acampamento()

func _esfolar(an: Animal) -> void:
	if an.esfolado:
		return
	iniciar_acao("Esfolando o %s" % an.info().nome.to_lower(), segundos_acao(0.5), _esfolar_fim.bind(an), true, "Crouch_Idle")

func _esfolar_fim(an: Animal) -> void:
	if not is_instance_valid(an) or an.esfolado:
		return
	an.esfolado = true
	var ev := ""
	var i: Dictionary = an.info()
	var faca := 1 if equip.sel in ["facao", "machado"] else 0
	var c := adicionar("carne_crua", i.carne + faca)
	var p := adicionar("pele", i.pele)
	hud.aviso("Esfolou o %s: %d carne crua, %d pele%s." % [i.nome, c, p, "" if c + p > 0 else " (sem espaço na carga)"])
	main_som_sangue(an)
	if ev != "":
		hud.relatorio = ev
		hud.relatorio_titulo = ""
		hud.relatorio_t = 5.0

func main_som_sangue(an: Node3D) -> void:
	var mk := B.box(an.get_parent(), Vector3(1.4, 0.01, 1.2), an.position + Vector3(0, 0.03, 0), B.mat(Color(0.3, 0.05, 0.04), 0.6, 0.0, "sangue_chao"))
	an.queue_free()

## Duração de uma tarefa para mostrar ao jogador (agora em segundos de verdade).
func _txt_horas(h: float) -> String:
	return "%d s" % int(round(segundos_acao(h)))

func _alternar_cozinha() -> void:
	trailer.cozinha_aberta = 0.0 if trailer.cozinha_aberta > 0.5 else 1.0
	trailer.reconstruir()

func _abastecer_galao() -> void:
	comboio.abastecer(20.0)
	estoque.galoes_diesel -= 1

func _interacao_dirigindo() -> void:
	if Input.is_action_just_pressed("camera"):
		comboio.alternar_camera()
	if Input.is_action_just_pressed("dirigir"):
		if absf(comboio.velocidade) < 2.5:
			_sair_do_carro()
			return
		hud.aviso("Pare o carro para sair")
	if comboio.superaquecido:
		hud.dica = "MOTOR SUPERAQUECIDO — alivie o peso ou pare para esfriar"
	elif comboio.agua_no_motor:
		hud.dica = "ÁGUA NO MOTOR — sem snorkel o motor se desgasta"
	elif comboio.bloqueado:
		hud.dica = "Caminho bloqueado — procure o desvio"
	var livre := comboio.engate_livre()
	var r := _reboque_proximo(livre, 3.2, true)
	if r and absf(comboio.velocidade) < 1.0:
		if not r.pode_engatar():
			hud.dica = "%s com defeito: desça e conserte antes de engatar" % r.nome_exibicao()
		elif not comboio.pode_engatar(r):
			hud.dica = "O chassi não aguenta: %.1f t de %.1f t" % [(comboio.peso_rebocado() + r.peso_total()) / 1000.0, picape.limite_engate() / 1000.0]
		else:
			hud.dica = "[G] Engatar %s" % r.nome_exibicao()
			if Input.is_action_just_pressed("engatar"):
				_engatar(r)

## Reboque solto mais perto de um ponto (pela lança, se pela_lanca).
func _reboque_proximo(p: Vector3, raio: float, pela_lanca := false) -> Reboque:
	var melhor: Reboque = null
	var md := raio
	for r in mundo.reboques_soltos:
		if not is_instance_valid(r):
			continue
		var alvo := r.global_transform * Vector3(0, 0.6, r.engate_frente_z()) if pela_lanca else r.global_position
		var d := Vector2(p.x - alvo.x, p.z - alvo.z).length()
		if d < md:
			md = d
			melhor = r
	return melhor

func _engatar(r: Reboque) -> void:
	var gt := r.global_transform
	if r.get_parent():
		r.get_parent().remove_child(r)
	add_child(r)
	r.global_transform = gt
	mundo.reboques_soltos.erase(r)
	if r.has_meta("chunk"):
		mundo.reboques_levados[r.get_meta("chunk")] = true
		mundo.estado_reboques.erase(r.get_meta("chunk"))
	r.abandonado = false
	r.reconstruir()
	comboio.engatar(r, true)
	base.distribuir_camas()
	marcadores = marcadores.filter(func(m): return m.distance_to(r.global_position) > 60.0)
	hud.aviso("%s engatado!%s" % [r.nome_exibicao(), "" if r.funcional() else " Repare na oficina para usar."])

func _desengatar(indice: int) -> void:
	var r: Reboque = comboio.desengatar(indice)
	if r:
		r.remove_meta("chunk") if r.has_meta("chunk") else null
		mundo.reboques_soltos.append(r)
		hud.aviso("%s desengatado." % r.nome_exibicao())
		base.distribuir_camas()
	oficina.atualizar()

# ------------------------------------------------------------ primeira pessoa (trailer e reboques)
func _entrar_em(v: Node3D) -> void:
	Som.em("porta", v.global_position + Vector3(0, 1.2, 0), -6.0)
	if v is Reboque and not v.tem_interior():
		if v.tipo == "tanque":
			_abrir_painel(_painel_tanque.bind(v))
		else:
			_abrir_painel(comboio_extra.painel.bind(v))
		return
	if v is Reboque and v.tipo == "armazem" and not v.aberto:
		v.aberto = true
		v.reconstruir()
	if v == trailer:
		trailer.modo_interior = true
		trailer.reconstruir()
	dentro = v
	fp.entrar(v, v.interior())
	if v is Subsolo:
		exploracao.entrar_subsolo()
	hud.objetivo = "Dentro: " + v.nome_exibicao()
	hud.subobjetivo = "Mire um objeto e aperte [E]   ·   [F] Sair"
	jogador.visible = false
	jogador.set_process(false)
	jogador.set_process_unhandled_input(false)

func _sair_de_dentro() -> void:
	var v := dentro
	dentro = null
	fp.sair()
	if v is Subsolo:
		exploracao.sair_subsolo()
	if v == trailer:
		trailer.modo_interior = false
		trailer.reconstruir()
	jogador.position = v.global_transform * v.ponto_entrada()
	jogador.position.y = jogador.chao(jogador.position)
	jogador.yaw = v.global_rotation.y + PI * 0.5
	jogador.visible = true
	jogador.set_process(true)
	jogador.set_process_unhandled_input(true)
	jogador.camera.current = true
	hud.objetivo = "Explore os arredores"
	hud.subobjetivo = "Desmonte carros, procure reboques"

func _interacao_interior() -> void:
	if not fp.foco.is_empty():
		hud.dica = "[E] " + fp.foco.nome
	if Input.is_action_just_pressed("dirigir"):
		_sair_de_dentro()

func _acao_interior(id: String) -> void:
	if _janela_aberta():
		return
	if id.begins_with("sub:") and dentro is Subsolo:
		exploracao.acao_subsolo(dentro, id)
		return
	match id:
		"dormir":
			dormir()
		"radio":
			hud.mensagem_radio = ouvir_radio()
		"luz":
			trailer.luz_vermelha = not trailer.luz_vermelha
			trailer.reconstruir()
		"despensa":
			_abrir_painel(_painel_despensa)
		"mapa":
			_abrir_painel(_painel_mapa)
		"sair":
			_sair_de_dentro()
		"estoque":
			_abrir_painel(_painel_estoque)
		"colher":
			_colher(dentro)
		"agua":
			_coletar_agua(dentro)
		"bancada":
			_abrir_painel(_painel_bancada.bind(dentro))
		"gerador":
			hud.aviso("Gerador ligado: alimenta a bancada e a luz da oficina.")
		"moto":
			hud.aviso("A moto ainda não funciona. Em breve: explorar longe do comboio.")
		"recrutas":
			_abrir_painel(_painel_recrutas)
		"cama":
			_abrir_painel(_painel_recrutas)

# ------------------------------------------------------------ painéis
func _painel_recrutas() -> Dictionary:
	var linhas: Array = []
	var botoes: Array = []
	var c := base.camas()
	linhas.append(["Camas: %d ocupadas de %d   ·   Comida %d   ·   Água %d" % [base.lista.size(), c, estoque.get("comida", 0), estoque.get("agua", 0)], Hud.DOURADO])
	if base.lista.is_empty():
		linhas.append(["Ninguém ainda. Converse com os moradores das vilas: alguns aceitam vir em troca de algo, se houver cama.", Color(0.75, 0.75, 0.72)])
	for rc in base.lista:
		var st := "em expedição (volta em %.0f h)" % rc.expedicao.restante if not rc.expedicao.is_empty() else "%s, %s" % [Recrutas.txt_vida(rc.vida), Recrutas.txt_moral(rc.moral)]
		var cor := Color(0.9, 0.88, 0.82)
		if rc.vida < 0.4 or rc.moral < 0.3:
			cor = Color(0.95, 0.45, 0.3)
		VidaRecrutas.garantir(rc)
		linhas.append(["%s — %s %s · %s · %s · %d abate%s" % [rc.nome, Recrutas.titulo(rc), VidaRecrutas.txt_nivel(rc), VidaRecrutas.txt_traco(rc).to_lower(), st, rc.abates, "" if rc.abates == 1 else "s"], cor])
		linhas.append(["      " + Recrutas.FUNCOES[rc.funcao].auto, Color(0.62, 0.62, 0.6)])
		botoes.append(["%s: conversar" % rc.nome, func(): _abrir_painel(_painel_recruta.bind(rc)); return "", true])
	if base.lista.size() > c:
		linhas.append(["Tem gente dormindo no chão: falta cama (a moral cai).", Color(0.95, 0.45, 0.3)])
	linhas.append(["Cada recruta come 1 comida e bebe 1 água por dia. Sem isso, a moral despenca e eles vão embora.", Color(0.62, 0.62, 0.6)])
	return {"titulo": "QUADRO DOS RECRUTAS", "subtitulo": "Quem mora no comboio, o que cada um faz e como está.", "linhas": linhas, "botoes": botoes}

func _painel_recruta(rc: Dictionary) -> Dictionary:
	var info: Dictionary = Recrutas.FUNCOES[rc.funcao]
	var linhas: Array = []
	var botoes: Array = []
	if not base.lista.has(rc):
		return {"titulo": rc.nome, "linhas": ["Não faz mais parte do comboio."], "botoes": []}
	VidaRecrutas.garantir(rc)
	var cab: Array[String] = [Recrutas.titulo(rc), VidaRecrutas.txt_nivel(rc), Recrutas.txt_vida(rc.vida), "moral: " + Recrutas.txt_moral(rc.moral)]
	linhas.append([" · ".join(cab.filter(func(x): return x != "")), Hud.DOURADO])
	linhas.append(["Jeito: %s — %s" % [VidaRecrutas.txt_traco(rc), VidaRecrutas.TRACOS[rc.traco].desc], Color(0.85, 0.8, 0.65)])
	if rc.nivel < 5 and not rc.funcao in ["crianca", "idoso"]:
		linhas.append(["Experiência: %d / %d para o próximo nível" % [int(rc.xp), int(VidaRecrutas.XP_NIVEL[rc.nivel])], Color(0.62, 0.62, 0.6)])
	var par := VidaRecrutas.par_de(base.lista, rc)
	if not par.is_empty():
		linhas.append(["Está junto com %s." % par.nome, Color(0.95, 0.6, 0.65)])
	var rels: Array[String] = []
	for o in base.lista:
		if o != rc and absf(VidaRecrutas.relacao(rc, o)) > 0.25:
			rels.append("%s (%s)" % [o.nome, VidaRecrutas.txt_relacao(VidaRecrutas.relacao(rc, o))])
	if not rels.is_empty():
		linhas.append(["Com os outros: " + ", ".join(rels), Color(0.75, 0.75, 0.72)])
	linhas.append("Na base: %s." % info.auto)
	linhas.append("Na defesa: %s." % info.defesa.to_lower())
	linhas.append("Zumbis abatidos: %d" % rc.abates)
	var falas := {
		"mecanico": "\"Me deixa sucata que eu transformo em peça. E não maltrata esse motor.\"",
		"agricultor": "\"A estufa tá dando. Se tiver semente, rende mais.\"",
		"vigia": "\"Durmo de dia. De noite, ninguém chega perto sem eu ver.\"",
		"medico": "\"Mordida? Me mostra agora. Não espera piorar.\"",
		"batedor": "\"Me dá umas horas e eu volto com alguma coisa. Quase sempre.\"",
		"idoso": "\"Já vi seca, enchente e governo ruim. Isso aqui também passa. Senta que eu te ensino.\"",
		"crianca": "\"Achei uma moeda e um parafuso! Pode ficar com o parafuso.\"",
	}
	if rc.fome > 0.0:
		linhas.append(["\"A gente tá passando fome aqui...\"", Color(0.95, 0.45, 0.3)])
	elif rc.moral < 0.3:
		linhas.append(["\"Não sei quanto tempo mais eu aguento isso.\"", Color(0.95, 0.45, 0.3)])
	else:
		linhas.append([falas[rc.funcao], Color(0.8, 0.8, 0.76)])
	if rc.funcao == "batedor":
		if rc.expedicao.is_empty():
			linhas.append(["Expedições: quanto mais longa, mais saque e mais risco (ferimento ou morte).", Color(0.7, 0.7, 0.68)])
			for hh in [6.0, 12.0, 24.0]:
				botoes.append(["Expedição de %d h" % int(hh), base.enviar_expedicao.bind(rc, hh), rc.vida >= 0.5])
		else:
			linhas.append(["Em expedição: volta em %.0f h." % rc.expedicao.restante, Hud.DOURADO])
	if rc.expedicao.is_empty():
		botoes.append(["Dispensar do comboio", base.dispensar.bind(rc), true])
	return {"titulo": rc.nome.to_upper(), "subtitulo": "Recruta do comboio", "linhas": linhas, "botoes": botoes}

func _painel_estoque() -> Dictionary:
	var linhas: Array = []
	linhas.append(["Carga: %d / %d" % [int(volume_usado()), capacidade_carga()], Hud.DOURADO])
	for k in ITENS:
		linhas.append("%s: %d" % [ITENS[k].nome, estoque.get(k, 0)])
	if not estoque.projetos.is_empty():
		var nomes: Array[String] = []
		for t in estoque.projetos:
			nomes.append(NOMES_TIPO[t])
		linhas.append(["Projetos: " + ", ".join(nomes), Color(0.6, 0.85, 1.0)])
	var origem: Array[String] = ["caçamba %d" % [0, 30, 50, 80][picape.nivel("cacamba")], "despensa do trailer %d" % trailer.capacidade_carga()]
	for el in comboio.cadeia:
		if el is Reboque and el.capacidade_carga() > 0:
			origem.append("%s %d" % [el.nome_exibicao().to_lower(), el.capacidade_carga()])
	return {"titulo": "ESTOQUE DO COMBOIO", "subtitulo": "Espaço: " + ", ".join(origem), "linhas": linhas,
		"botoes": [["Jogar fora 10 sucata", func():
			estoque.sucata = maxi(0, estoque.sucata - 10)
			return "Sucata descartada.", estoque.sucata > 0]]}

# ------------------------------------------------------------ compartimentos do trailer
func _abrir_compartimento(id: String) -> void:
	Som.em("compartimento", trailer.global_transform * trailer.ponto_compartimento(id) + Vector3(0, 1.0, 0), -4.0)
	trailer.abrir_compartimento(id, true)
	_abrir_painel(_painel_compartimento.bind(id))

func _volume_compartimento(id: String) -> float:
	var v := 0.0
	for k in ITENS:
		if estoque.get(k, 0) > 0 and Trailer.compartimento_de(k) == id:
			v += estoque[k] * ITENS[k].vol
	return v

func _painel_compartimento(id: String) -> Dictionary:
	var c: Dictionary = Trailer.COMPARTIMENTOS[id]
	var linhas: Array = []
	var botoes: Array = []
	var cap := trailer.capacidade_compartimento(id)
	var usado := _volume_compartimento(id)
	var lista: Array = []
	for k in ITENS:
		var q: int = estoque.get(k, 0)
		if q > 0 and Trailer.compartimento_de(k) == id:
			lista.append([k, q])
	lista.sort_custom(func(a, b): return a[1] * ITENS[a[0]].vol > b[1] * ITENS[b[0]].vol)
	var cor := Color(0.95, 0.45, 0.3) if usado > cap else Hud.DOURADO
	linhas.append(["Ocupado: %.0f de %d (o que passar daqui vai para o resto do comboio).  Carga total: %.0f / %d" % [usado, cap, volume_usado(), capacidade_carga()], cor])
	if lista.is_empty():
		linhas.append(["Vazio.", Color(0.7, 0.7, 0.68)])
	for par in lista:
		var k: String = par[0]
		var extra := ""
		if Armas.LISTA.has(k) and Armas.LISTA[k].tipo == "fogo":
			extra = "  (pente: %d)" % equip.pentes.get(k, 0)
		elif equip.cond_armas.has(k):
			extra = "  (%d%%)" % int(equip.cond_armas[k] * 100.0)
		linhas.append("%d × %s%s" % [par[1], ITENS[k].get("um", ITENS[k].nome) if par[1] == 1 else ITENS[k].nome.to_lower(), extra])
	match id:
		"despensa":
			linhas.append(["Fome: %d%%     Sede: %d%%     Vida: %d%%" % [int(jogador.fome * 100.0), int(jogador.sede * 100.0), int(jogador.vida * 100.0)], Color(0.75, 0.75, 0.72)])
			linhas.append([saude.texto(), Color(0.95, 0.6, 0.35) if not saude.doencas.is_empty() else Color(0.75, 0.75, 0.72)])
			botoes.append(["Comer uma lata", func():
				estoque.comida -= 1
				jogador.fome = minf(1.0, jogador.fome + 0.25)
				saude.comeu("comida")
				return "Você comeu.", estoque.get("comida", 0) > 0 and jogador.fome < 0.99])
			for quente in [["ensopado", "Comer ensopado de caça", 0.7], ["sopa", "Tomar sopa", 0.35]]:
				var qid: String = quente[0]
				var qf: float = quente[2]
				botoes.append([quente[1], func():
					estoque[qid] -= 1
					jogador.fome = minf(1.0, jogador.fome + qf)
					jogador.vida = minf(1.0, jogador.vida + 0.08)
					return "Comida quente." + saude.tratar(qid), estoque.get(qid, 0) > 0])
			botoes.append(["Tomar café", func():
				estoque.cafe -= 1
				return "Café passado na hora." + saude.tratar("cafe"), estoque.get("cafe", 0) > 0])
			botoes.append(["Tomar antibiótico", func():
				estoque.antibiotico -= 1
				return "Antibiótico tomado." + saude.tratar("antibiotico"), estoque.get("antibiotico", 0) > 0])
			botoes.append(["Comer carne assada", func():
				estoque.carne_assada -= 1
				jogador.fome = minf(1.0, jogador.fome + 0.45)
				return "Carne assada. Quentinha.", estoque.get("carne_assada", 0) > 0 and jogador.fome < 0.99])
			botoes.append(["Beber água", func():
				estoque.agua -= 1
				jogador.sede = minf(1.0, jogador.sede + 0.3)
				return "Você bebeu.", estoque.get("agua", 0) > 0 and jogador.sede < 0.99])
			botoes.append(["Fazer curativo", func():
				estoque.bandagem -= 1
				jogador.vida = minf(1.0, jogador.vida + 0.22)
				return "Curativo feito." + saude.tratar("bandagem"), estoque.get("bandagem", 0) > 0 and (jogador.vida < 0.99 or saude.tem("ferida"))])
			botoes.append(["Tomar remédio", func(): return _usar_remedio(), estoque.get("remedio", 0) > 0])
		"ferramentas":
			botoes.append(["Abastecer a picape com um galão (20 L)", func():
				_abastecer_galao()
				return "Tanque: %d L." % int(comboio.diesel), estoque.get("galoes_diesel", 0) > 0 and comboio.diesel < comboio.tanque() - 1.0])
			botoes.append(["Abrir criação (oficina e metal)", func():
				_fechar_janela()
				criacao.aba = "metal"
				_abrir_painel(criacao.painel)
				return "", true])
		"bagageiro":
			for aid in Armas.ARMADURA:
				if estoque.get(aid, 0) > 0:
					botoes.append(["Vestir %s" % Armas.ARMADURA[aid].nome.to_lower(), equip.vestir.bind(aid), true])
			for wid in Armas.ORDEM:
				if wid != "facao" and estoque.get(wid, 0) > 0:
					botoes.append(["Pegar na mão: %s" % Armas.LISTA[wid].nome.to_lower(), func():
						equip.selecionar(wid)
						return "%s na mão." % Armas.LISTA[wid].nome, equip.sel != wid])
	var guarda := "comida, água e remédios" if id == "despensa" else ("peças, sucata, chapas, cordas, pneus, eixos e galões" if id == "ferramentas" else "armas, munição, couro, roupas e o resto")
	return {"titulo": c.nome.to_upper(), "subtitulo": "Compartimento do trailer · guarda: %s" % guarda, "linhas": linhas, "botoes": botoes}

func _painel_despensa() -> Dictionary:
	return {"titulo": "DESPENSA", "subtitulo": "Comer e beber recupera a fome e a sede.",
		"linhas": ["Comida: %d     Água: %d     Remédios: %d" % [estoque.comida, estoque.agua, estoque.get("remedio", 0)],
			"Fome: %d%%     Sede: %d%%" % [int(jogador.fome * 100.0), int(jogador.sede * 100.0)]],
		"botoes": [
			["Comer (1 comida)", func():
				estoque.comida -= 1
				jogador.fome = minf(1.0, jogador.fome + 0.25)
				return "Você comeu.", estoque.comida > 0 and jogador.fome < 0.99],
			["Beber (1 água)", func():
				estoque.agua -= 1
				jogador.sede = minf(1.0, jogador.sede + 0.3)
				return "Você bebeu.", estoque.agua > 0 and jogador.sede < 0.99],
			["Tomar remédio (%d)" % estoque.get("remedio", 0), func():
				return _usar_remedio(), estoque.get("remedio", 0) > 0]]}

func _painel_mapa() -> Dictionary:
	var linhas: Array = []
	var p := _foco()
	var ri := mundo.regiao_em(p.z)
	var b: Dictionary = mundo.reg.info_bioma(ri)
	var m := mundo.reg.marco(ri)
	linhas.append(["%s — %s (região %d)" % [mundo.reg.nome(ri), b.nome, ri + 1], Hud.DOURADO])
	linhas.append("Fim da região em %.1f km: %s." % [maxf(0.0, (m.z - p.z) / 1000.0), "ponte caída (vau ao lado)" if m.tipo == "ponte" else "bloqueio militar (desvio de terra)"])
	var lista := conhecidos.values()
	lista.sort_custom(func(a, c): return a.pos.z < c.pos.z)
	if lista.is_empty():
		linhas.append(["Nenhum lugar descoberto ainda. Fique de olho nas placas da estrada.", Color(0.7, 0.7, 0.68)])
	var tipos := {"vila": "Vila", "fazenda": "Fazenda", "ferro_velho": "Ferro-velho", "assentamento": "Assentamento"}
	var kmh := defesa.km_horda(p.z)
	linhas.append(["☠ A horda: %.1f km atrás, andando %.1f km por dia." % [kmh, defesa.velocidade_horda() * 24.0 / 1000.0], Color(0.95, 0.45, 0.3)])
	linhas.append("Assentamentos defendidos: %d   ·   Nível de ameaça: %d" % [defesa.defendidos, int(mundo.nivel_ameaca)])
	for l in lista:
		var dist: float = (l.pos.z - p.z) / 1000.0
		var extra := ""
		if l.tipo == "assentamento":
			var fa: String = defesa.obter(l.id).fase if l.has("id") else ""
			extra = {"livre": " · assentamento", "preparando": " · você vai defender", "entre_ondas": " · defendendo", "onda": " · sob ataque", "aliado": " · aliado ✔", "caido": " · caído ✖"}.get(fa, " · assentamento")
		linhas.append("⌂ %s — %.1f km %s%s" % [l.nome, absf(dist), "à frente" if dist > 0.05 else ("para trás" if dist < -0.05 else "aqui"), extra])
	for mk in marcadores:
		var dist2 := (mk.z - p.z) / 1000.0
		linhas.append("◆ Reboque abandonado (pista do rádio) — %.1f km %s" % [absf(dist2), "à frente" if dist2 > 0 else "para trás"])
	return {"titulo": "MAPA E ANOTAÇÕES", "linhas": linhas, "botoes": []}

func _painel_tanque(r: Reboque) -> Dictionary:
	var cap := float(r.capacidade())
	var linhas: Array = ["Diesel no tanque: %d / %d L" % [int(r.litros), int(cap)],
		"Picape: %d / %d L     Galões no estoque: %d" % [int(comboio.diesel), int(comboio.tanque()), estoque.galoes_diesel]]
	if not r.funcional():
		linhas.append(["O tanque está danificado e vazando. Repare na oficina.", Color(0.95, 0.4, 0.3)])
	var ok := r.funcional()
	return {"titulo": "TANQUE DE DIESEL", "subtitulo": "Reserva de combustível do comboio.", "linhas": linhas,
		"botoes": [
			["Abastecer a picape", func():
				var n := comboio.abastecer(r.litros)
				r.litros -= n
				return "Picape abastecida com %d L." % int(n), ok and r.litros > 1.0 and comboio.diesel < comboio.tanque() - 1.0],
			["Despejar 1 galão no tanque (+20 L)", func():
				estoque.galoes_diesel -= 1
				r.litros = minf(cap, r.litros + 20.0)
				return "", ok and estoque.galoes_diesel > 0 and r.litros < cap - 20.0],
			["Encher 1 galão (−20 L)", func():
				if adicionar("galoes_diesel", 1) == 0:
					return "Sem espaço na carga."
				r.litros -= 20.0
				return "", r.litros >= 20.0]]}

func _painel_bancada(r: Reboque) -> Dictionary:
	var linhas: Array = []
	var livre := r.trabalho.is_empty()
	if not r.funcional():
		linhas.append(["A oficina está danificada. Repare-a na aba Engates da oficina.", Color(0.95, 0.4, 0.3)])
	if not livre:
		var nome: String = "%d peças" % r.trabalho.qtd if r.trabalho.tipo == "pecas" else NOMES_TIPO[r.trabalho.reboque]
		linhas.append(["Em andamento: %s — faltam %.1f h" % [nome, maxf(0.0, r.trabalho.restante)], Hud.DOURADO])
	var hora_peca := 1.0 / r.nivel
	linhas.append("Fabricar peças: 4 sucata cada, %.1f h por peça (nível %d)." % [hora_peca, r.nivel])
	var ok := r.funcional() and livre
	var botoes: Array = [
		["Fabricar 1 peça", _iniciar_pecas.bind(r, 1), ok and estoque.sucata >= 4],
		["Fabricar 5 peças", _iniciar_pecas.bind(r, 5), ok and estoque.sucata >= 20]]
	if estoque.projetos.is_empty():
		linhas.append(["Nenhum projeto de reboque. Projetos são achados dentro de reboques abandonados.", Color(0.7, 0.7, 0.68)])
	else:
		var horas := 14.0 - r.nivel * 3.0
		linhas.append("Construir reboque (%d h): %s" % [int(horas), _txt_itens(CUSTO_CONSTRUCAO)])
		for t in estoque.projetos:
			botoes.append(["Construir %s" % NOMES_TIPO[t], _iniciar_construcao.bind(r, t, horas), ok and tem_itens(CUSTO_CONSTRUCAO)])
	return {"titulo": "BANCADA DA OFICINA", "subtitulo": "Os trabalhos continuam enquanto o tempo passa (dirigindo ou dormindo).",
		"linhas": linhas, "botoes": botoes}

func _iniciar_pecas(r: Reboque, n: int) -> String:
	estoque.sucata -= n * 4
	r.trabalho = {"tipo": "pecas", "qtd": n, "restante": n / float(r.nivel)}
	return "Fabricando %d peças." % n

func _iniciar_construcao(r: Reboque, tipo: String, horas: float) -> String:
	gastar(CUSTO_CONSTRUCAO)
	r.trabalho = {"tipo": "reboque", "reboque": tipo, "restante": horas}
	return "Construção iniciada: %s (%d h)." % [NOMES_TIPO[tipo], int(horas)]

func _concluir_trabalho(r: Reboque) -> void:
	var t := r.trabalho
	r.trabalho = {}
	if t.tipo == "pecas":
		estoque.pecas += t.qtd
		if t.get("auto", false):
			base.pecas_feitas(t.qtd)
		else:
			hud.aviso("Oficina: %d peças prontas." % t.qtd)
		return
	var novo := Reboque.new()
	novo.tipo = t.reboque
	novo.nivel = 1
	novo.condicao = 1.0
	var ult := comboio.cadeia[comboio.cadeia.size() - 1]
	var tras := -ult.global_transform.basis.z
	add_child(novo)
	novo.global_position = comboio.engate_livre() + tras * novo.engate_frente_z()
	novo.global_rotation.y = ult.global_rotation.y
	if comboio.pode_engatar(novo):
		comboio.engatar(novo, true)
		base.distribuir_camas()
		hud.aviso("%s construído e engatado!" % novo.nome_exibicao())
	else:
		novo.global_position += ult.global_transform.basis.x * 4.0
		mundo.reboques_soltos.append(novo)
		hud.aviso("%s construído! O chassi não aguenta mais peso: ficou estacionado." % novo.nome_exibicao())

func _colher(r: Reboque) -> void:
	if not r.funcional():
		hud.aviso("A estufa está danificada. Repare-a na oficina.")
		return
	var n := int(r.comida)
	if n <= 0:
		hud.aviso("Nada para colher ainda. Volte amanhã.")
		return
	var ent := adicionar("comida", n)
	r.comida -= ent
	hud.aviso("Você colheu %d comida." % ent if ent > 0 else "Sem espaço na carga.")

func _coletar_agua(r: Reboque) -> void:
	var n := int(r.agua)
	if n <= 0 or not r.funcional():
		hud.aviso("A cisterna está vazia.")
		return
	var ent := adicionar("agua", n)
	r.agua -= ent
	hud.aviso("Você coletou %d água." % ent if ent > 0 else "Sem espaço na carga.")

## Reboque abandonado: defeitos para consertar e saque.
func _painel_resgate(r: Reboque) -> Dictionary:
	var linhas: Array = []
	var botoes: Array = []
	if r.defeitos.is_empty():
		linhas.append(["Pronto para engatar! Encoste a traseira do comboio na lança e aperte [G].", Color(0.5, 0.9, 0.5)])
	else:
		linhas.append(["Defeitos — só dá para engatar depois de consertar tudo:", Hud.DOURADO])
	for d in r.defeitos:
		var info: Dictionary = Reboque.DEFEITOS[d]
		linhas.append("• %s — %s, %.1f h" % [info.nome, _txt_itens(info.itens), info.horas])
		botoes.append(["Consertar: %s" % info.nome.to_lower(), _consertar_defeito.bind(r, d), tem_itens(info.itens)])
	linhas.append("Estado da carroceria: %d%%" % int(r.condicao * 100.0))
	if not r.saque.is_empty():
		var partes: Array[String] = []
		for k in r.saque:
			if k == "projeto":
				partes.append("um papel dobrado...")
			else:
				partes.append("%d %s" % [r.saque[k], ITENS[k].nome.to_lower()])
		linhas.append(["Dentro: " + ", ".join(partes), Color(0.75, 0.75, 0.72)])
		botoes.append(["Saquear", _saquear.bind(r), true])
	if eh_noite():
		linhas.append(["É noite: o barulho do conserto pode atrair zumbis da escuridão.", Color(0.95, 0.45, 0.3)])
	return {"titulo": "%s %s" % [r.nome_exibicao().to_upper(), r.abandonado_txt().to_upper()],
		"subtitulo": "%s · nível %d · %d kg" % [r.info().desc, r.nivel, int(r.peso_total())], "linhas": linhas, "botoes": botoes}

func _consertar_defeito(r: Reboque, d: String) -> String:
	var info: Dictionary = Reboque.DEFEITOS[d]
	gastar(info.itens)
	r.defeitos.erase(d)
	r.reconstruir()
	var msg := "%s consertado (%.1f h)." % [info.nome, info.horas]
	var ev := trabalhar(info.horas, "Consertando: %s" % info.nome.to_lower())
	if r.defeitos.is_empty():
		msg += " Pronto para engatar!"
	return msg + (" " + ev if ev != "" else "")

func _saquear(r: Reboque) -> String:
	var pegou: Array[String] = []
	for k in r.saque.keys():
		if k == "projeto":
			var t: String = r.saque[k]
			if not estoque.projetos.has(t):
				estoque.projetos.append(t)
				pegou.append("PROJETO: %s!" % NOMES_TIPO[t])
			else:
				pegou.append("um projeto repetido (%s)" % NOMES_TIPO[t])
			r.saque.erase(k)
			continue
		var n := adicionar(k, r.saque[k])
		if n > 0:
			pegou.append("%d %s" % [n, ITENS[k].nome.to_lower()])
		r.saque[k] -= n
		if r.saque[k] <= 0:
			r.saque.erase(k)
	if pegou.is_empty():
		return "Sem espaço na carga."
	return "Você pegou: " + ", ".join(pegou) + ("" if r.saque.is_empty() else " (não coube tudo)")

func _desmontar(c: Node3D) -> void:
	iniciar_acao("Desmontando o carro", segundos_acao(2.0), _desmontar_fim.bind(c), true, "Fixing_Kneeling")

func _desmontar_fim(c: Node3D) -> void:
	if not is_instance_valid(c):
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash(c.get_meta("chave", ""))
	var ganhos: Array[String] = []
	var tabela := {"sucata": r.randi_range(6, 14), "pecas": r.randi_range(0, 2)}
	if r.randf() < 0.55:
		tabela["pneu"] = r.randi_range(1, 2)
	if r.randf() < 0.18:
		tabela["eixo"] = 1
	if r.randf() < 0.25:
		tabela["galoes_diesel"] = 1
	var ev := ""
	for k in tabela:
		var n := adicionar(k, tabela[k])
		if n > 0:
			ganhos.append("%d %s" % [n, ITENS[k].nome.to_lower()])
	mundo.marcar_desmontado(c)
	hud.aviso("Carro desmontado: " + (", ".join(ganhos) if not ganhos.is_empty() else "sem espaço na carga"))
	if ev != "":
		hud.relatorio = ev
		hud.relatorio_titulo = ""
		hud.relatorio_t = 5.0

# ------------------------------------------------------------ dormir e rádio
## Dorme até de manhã (ou um cochilo de 3h de dia). Retorna o relatório da noite.
func dormir() -> String:
	var noite := hora >= 18.0 or hora < 6.0
	var horas := 3.0
	if noite:
		horas = (24.0 - hora + 6.5) if hora >= 18.0 else (6.5 - hora)
	var risco := 0.0
	if noite:
		var grades: Dictionary = trailer.config.janelas
		risco = 0.75 - grades.nivel * 0.2 - grades.condicao * 0.2
		if trailer.luz_interna and not trailer.luz_vermelha:
			risco += 0.2
		risco = clampf(risco, 0.05, 0.95)
	var seg := seguranca_local()
	if noite:
		risco = 0.0 if seg[0] <= -1.0 else clampf(risco + seg[0], 0.03, 0.95)
	var linhas: Array[String] = []
	linhas.append("Você dormiu %d horas (%s)." % [int(round(horas)), seg[1]])
	var r := RandomNumberGenerator.new()
	r.seed = dia * 31 + int(hora)
	var vig := base.presentes("vigia")
	if r.randf() < risco and not vig.is_empty() and r.randf() < 0.55:
		var v: Dictionary = vig[r.randi() % vig.size()]
		var mortos := r.randi_range(1, 3)
		v.abates += mortos
		abates += mortos
		linhas.append("Zumbis rondaram o acampamento, mas %s deu conta (%d abatido%s)." % [v.nome, mortos, "s" if mortos > 1 else ""])
	elif r.randf() < risco:
		var alvos := ["janelas", "traseira", "lateral_esquerda", "frente"]
		var alvo: String = alvos[r.randi() % alvos.size()]
		var dano := r.randf_range(0.12, 0.3)
		trailer.danificar(alvo, dano)
		trailer.condicao_carroceria = maxf(0.1, trailer.condicao_carroceria - dano * 0.3)
		linhas.append("Durante a noite zumbis cercaram o trailer.")
		linhas.append("%s: -%d%%" % [Trailer.MODULOS[trailer.config[alvo].id].nome, int(dano * 100.0)])
	else:
		linhas.append("Nenhum zumbi chegou ao trailer.")
	var tinha_trabalho := false
	for el in comboio.cadeia:
		if el is Reboque and not el.trabalho.is_empty():
			tinha_trabalho = true
	_dormindo = true
	_passar_tempo(horas)
	_dormindo = false
	var abrigado: bool = trailer.condicao_carroceria > 0.3 and float(trailer.config.janelas.condicao) > 0.25
	var gr := saude.dormiu(horas, abrigado)
	if gr != "":
		linhas.append(gr)
	if tinha_trabalho:
		linhas.append("A oficina trabalhou durante a noite.")
	linhas.append_array(base.relatorio())
	jogador.estamina = 1.0
	jogador.vida = minf(1.0, jogador.vida + 0.1 * horas / 8.0)
	trailer.reconstruir()
	_atualizar_ceu()
	linhas.append("(Jogo salvo.)")
	var txt := "\n".join(linhas)
	hud.relatorio = txt
	hud.relatorio_titulo = ""
	hud.relatorio_t = 6.0
	call_deferred("salvar_jogo", true)
	return txt

const RUMORES := {
	"armazem": "...tem um baú de carga largado no acostamento, km %d. Parecia inteiro...",
	"tanque": "...vimos um reboque-tanque tombado perto do km %d. Ainda cheira a diesel...",
	"oficina": "...uma oficina sobre rodas abandonada no km %d. Ferramenta pra todo lado...",
	"estufa": "...alguém montou uma estufa num reboque. Ficou pra trás no km %d...",
	"plataforma": "...uma carreta plataforma com uma moto em cima, km %d. Ninguém por perto...",
	"apartamentos": "...um reboque-dormitório de uma turma de obra largado no km %d. Camas pra meia dúzia...",
}

## Sintoniza o rádio: às vezes dá a localização de um reboque abandonado à frente (é raro).
func ouvir_radio() -> String:
	_t_radio = 3.5
	# o rádio do trailer: marco anunciado ou uma meta nova
	if progresso and _rng_radio.randf() < 0.45:
		if progresso._ativas() < 2 and _rng_radio.randf() < 0.6:
			var id := progresso.nova_missao()
			var ms: Dictionary = progresso.missoes[id]
			return Progresso.TIPOS_MISSAO[ms.tipo].radio % int(ms.z / 1000.0)
		return String(Progresso.marco(progresso.marco_idx).radio)
	var k := int(floor(comboio.pos.z / WorldGen.TAM)) + WorldGen.FRENTE + 3 + _rng_radio.randi_range(0, 10)
	if mundo.pois_fixos.has(k) or _rng_radio.randf() < 0.65:
		var gerais := [
			"...aqui é a Zona Segura. Repito: sigam a estrada principal. Não parem à noite...",
			"...a horda está descendo pela serra. Quem estiver na estrada, mantenha distância...",
			"...se alguém ouvir isso, precisamos de remédios. Câmbio...",
			"...(chiado)...",
			"...os carros parados na rodovia ainda têm pneu bom. Levem macaco...",
		]
		return gerais[_rng_radio.randi() % gerais.size()]
	var tipos := WorldGen.TIPOS_REBOQUE
	var tipo: String = tipos[_rng_radio.randi() % tipos.size()]
	mundo.pois_fixos[k] = "reboque:" + tipo
	var alvo := mundo.posicao_poi_reboque(k)
	marcadores.append(alvo)
	var km := int((alvo.z) / 1000.0) + 1
	return RUMORES[tipo] % km

# ------------------------------------------------------------ picape
func _entrar_no_carro() -> void:
	if acampamento:
		_alternar_acampamento()
	comboio.dirigindo = true
	comboio.cam_yaw = 0.0
	picape.modo_cabine = comboio.primeira_pessoa
	picape.reconstruir()
	comboio.camera_ativa().current = true
	jogador.visible = false
	jogador.set_process(false)
	jogador.set_process_unhandled_input(false)
	if trailer.cozinha_aberta > 0.0:
		trailer.cozinha_aberta = 0.0
		trailer.reconstruir()

func _sair_do_carro() -> void:
	comboio.dirigindo = false
	comboio.velocidade = 0.0
	picape.modo_cabine = false
	picape.reconstruir()
	jogador.position = comboio.porta_motorista()
	jogador.yaw = comboio.yaw
	jogador.visible = true
	jogador.set_process(true)
	jogador.set_process_unhandled_input(true)
	jogador.camera.current = true
	hud.objetivo = "Explore os arredores"
	hud.subobjetivo = "Desmonte carros, procure reboques"

func _abrir_oficina() -> void:
	oficina.visible = true
	oficina.atualizar()
	jogador.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ------------------------------------------------------------ picape + trailer
func _rig() -> void:
	var z_picape := 15.5
	var lat := -5.4
	picape = Pickup.new()
	var p := mundo.ponto_estrada(z_picape, lat)
	p.y = mundo.elevacao(z_picape) - 0.02
	picape.position = p
	var d := mundo.direcao(z_picape)
	picape.rotation.y = atan2(d.x, d.z)
	add_child(picape)
	trailer = Trailer.new()
	var engate := picape.global_transform * picape.engate()
	var dir := -picape.global_transform.basis.z
	var engate_trailer := Trailer.COMPRIMENTO * 0.5 + 1.8
	trailer.position = engate + dir * engate_trailer
	trailer.position.y = p.y
	trailer.rotation.y = picape.rotation.y + 0.06
	add_child(trailer)
	comboio = Comboio.new()
	add_child(comboio)
	comboio.iniciar(mundo, picape, trailer)
	comboio.posicionar(z_picape, lat, 0.06)
	# carros abandonados posicionados à mão na cena inicial
	var r := RandomNumberGenerator.new()
	r.seed = 4
	for c in [[30.0, 3.8, 0.4], [-20.0, -6.5, 2.6], [52.0, -1.0, -0.9]]:
		var cp := mundo.ponto_estrada(c[0], c[1])
		cp.y = mundo.elevacao(c[0]) + 0.02
		var rc := RandomNumberGenerator.new()
		rc.seed = r.randi()
		mundo.carro_abandonado(mundo, cp, c[2], rc, "fixo:%d" % int(c[0]))

func _horda() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	# alguns zumbis próximos na estrada, à frente
	for i in 6:
		var z := 30.0 + r.randf() * 28.0
		var p := mundo.ponto_estrada(z, r.randf_range(-3.5, 3.5))
		var zz := mundo.criar_zumbi(mundo, p, PI + r.randf_range(-0.5, 0.5), r.randi())
		hud_zumbi(zz.position)
	# horda ao longe
	for i in 90:
		var z := 85.0 + r.randf() * 120.0
		var p := mundo.ponto_estrada(z, r.randf_range(-4.0, 4.0))
		mundo.silhueta(mundo, p, r)

var _zumbis_pos: Array[Vector3] = []
func hud_zumbi(p: Vector3) -> void:
	_zumbis_pos.append(p)
	if hud:
		hud.zumbis = _zumbis_pos

# ------------------------------------------------------------ prints
func _salvar(nome: String) -> void:
	for i in 5:
		await RenderingServer.frame_post_draw
	var pasta := ProjectSettings.globalize_path("res://prints")
	DirAccess.make_dir_recursive_absolute(pasta)
	get_viewport().get_texture().get_image().save_png(pasta + "/" + nome + ".png")
	print("salvo ", nome)

func _novo_reboque(tipo: String, nivel: int, cond: float) -> Reboque:
	var r := Reboque.new()
	r.tipo = tipo
	r.nivel = nivel
	r.condicao = cond
	add_child(r)
	return r

## Procura um lugar de um tipo nas primeiras regiões.
func _achar_lugar(tipo: String) -> Dictionary:
	for ri in 12:
		for l in mundo.lugares_da_regiao(ri):
			if l.tipo == tipo:
				return l
	return {}

func _achar_regiao(bioma: String) -> int:
	for ri in range(1, 40):
		if mundo.reg.bioma(ri) == bioma:
			return ri
	return 0

func _caminho_do_lugar(l: Dictionary) -> PackedVector3Array:
	for f in mundo._features(mundo.regiao_em(l.pos.z)):
		if f.tipo == "estrada" and f.id == l.id:
			return f.pts
	return PackedVector3Array()

func _dirigir_em(z: float, lateral: float, cam_yaw: float, cam_pitch: float, dist := 11.0) -> void:
	comboio.posicionar(z, lateral, 0.02)
	mundo.atualizar(comboio.pos)
	comboio.dirigindo = true
	comboio.primeira_pessoa = false
	comboio.velocidade = 14.0
	comboio.cam_yaw = cam_yaw
	comboio.cam_pitch = cam_pitch
	comboio.cam_dist = dist
	comboio._aplicar(0.0)
	comboio.camera.current = true
	jogador.visible = false

func _procurar_vasculhavel(prefixo: String, z_ini: float, z_max: float) -> Node3D:
	var z := z_ini
	while z < z_max:
		mundo.atualizar(mundo.ponto_estrada(z, 0.0))
		for v in mundo.vasculhaveis:
			if is_instance_valid(v) and not mundo._na_fila(v) and String(v.get_meta("chave")).begins_with(prefixo) and v.global_position.z > z - 100.0:
				return v
		z += 192.0
	return null

func _posar_jogador(pos: Vector3, olhar: Vector3, pitch := -0.1, desvio := 0.0) -> void:
	jogador.visible = true
	jogador.position = pos
	jogador.position.y = jogador.chao(pos)
	jogador.yaw = atan2(olhar.x - pos.x, olhar.z - pos.z) + desvio
	jogador.pitch = pitch
	jogador.pivo.rotation = Vector3(pitch, jogador.yaw, 0)
	jogador.corpo.rotation.y = atan2(olhar.x - pos.x, olhar.z - pos.z)
	jogador.corpo.pose_caminhada(0.0, 0.0)
	jogador.camera.current = true
	mundo.atualizar(jogador.position)

func _limpar_zumbis_perto(p: Vector3, raio: float) -> void:
	for z in mundo.zumbis_vivos.duplicate():
		if is_instance_valid(z) and z.global_position.distance_to(p) < raio:
			mundo.zumbis_vivos.erase(z)
			z.queue_free()
	for c in mundo.get_children():
		if not (c is Zumbi) and not c.name.begins_with("Chunk") and c is Node3D and c.get_child_count() > 0 and c.get_class() == "Node3D" and c.global_position.distance_to(p) < raio:
			c.visible = false

func _zumbi_posado(p: Vector3, olhar: Vector3, tipo: String, sem: int, fase: float, correndo := false, atacando := 0.0) -> Zumbi:
	p.y = jogador.chao(p)
	var z := mundo.criar_zumbi(mundo, p, atan2(olhar.x - p.x, olhar.z - p.z), sem, tipo)
	z._fase = fase
	z._anim_ataque = atacando
	z._animar(3.0 if correndo else 0.5)
	return z

## Só para os prints: some com as árvores que ficam entre a câmera e o alvo.
func _abrir_vista(de: Vector3, para: Vector3) -> void:
	var pilha: Array = [mundo]
	while not pilha.is_empty():
		var nd: Node = pilha.pop_back()
		pilha.append_array(nd.get_children())
		if nd is MultiMeshInstance3D:
			var mm: MultiMesh = nd.multimesh
			for i in mm.instance_count:
				var t: Transform3D = (nd as Node3D).global_transform * mm.get_instance_transform(i)
				var p := Vector2(t.origin.x, t.origin.z)
				var a := Vector2(de.x, de.z)
				var b := Vector2(para.x, para.z)
				var ab := b - a
				var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
				if k < 0.85 and p.distance_to(a + ab * k) < 7.0:
					mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), mm.get_instance_transform(i).origin))

## Vista de "casa de bonecas": andares de cima e telhado escondidos, câmera alta.
func _corte_aereo(cam: Camera3D, pr: Predio, andar: int, nome: String) -> void:
	pr.corte(andar)
	var b := pr.global_transform.basis
	var c := pr.global_position + Vector3(0, andar * Predio.H, 0)
	var tam := maxf(pr.largura, pr.profundidade)
	# câmera do lado da estrada (atrás costuma haver outros prédios colados)
	var pz := pr.global_position.z
	var para_estrada := Vector3(mundo.centro_x(pz) - pr.global_position.x, 0, 0).normalized()
	if para_estrada == Vector3.ZERO:
		para_estrada = b.z
	var de := c + para_estrada * tam * 0.8 + Vector3(0, 0, tam * 0.35) + Vector3(0, tam * 1.15 + 4.0, 0)
	_abrir_vista(de, c)
	var escondidos: Array = []
	for e in mundo.estruturas:
		if is_instance_valid(e) and e != pr and e.visible and e.global_position.distance_to(pr.global_position) < 30.0:
			e.visible = false
			escondidos.append(e)
	jogador.visible = false
	var hud_antes := hud.visible
	hud.visible = false
	cam.fov = 50.0
	cam.look_at_from_position(de, c + Vector3(0, 0.5, 0), Vector3.UP)
	cam.current = true
	await _salvar(nome)
	pr.corte(-1)
	hud.visible = hud_antes
	for e in escondidos:
		e.visible = true

func _achar_predio(tipo: String, z_ini: float, z_max: float, min_andares := 1) -> Predio:
	var z := z_ini
	while z < z_max:
		mundo.atualizar(mundo.ponto_estrada(z, 0.0))
		for e in mundo.estruturas:
			if is_instance_valid(e) and not mundo._na_fila(e) and e.tipo == tipo and e.andares >= min_andares and e.global_position.z > z - 150.0:
				return e
		z += 192.0
	return null

## Põe o jogador dentro de uma construção, num andar, olhando para um ponto local.
## Escolhe o cômodo do andar com mais móveis vasculháveis e põe o jogador no canto
## oposto, olhando para eles.
func _dentro_predio(pr: Predio, andar: int, preferir := "") -> void:
	var conts: Array = []
	var pilha: Array = [pr.andar_nos[andar]]
	while not pilha.is_empty():
		var nd: Node = pilha.pop_back()
		pilha.append_array(nd.get_children())
		if nd.has_meta("tabela"):
			conts.append(pr.local((nd as Node3D).global_position))
	var melhor: Rect2 = Rect2(-pr.largura * 0.4, -pr.profundidade * 0.4, pr.largura * 0.8, pr.profundidade * 0.8)
	var mais := -1
	for cm in pr.comodos[andar]:
		var r: Rect2 = cm.rect
		if r.size.x < 2.4 or r.size.y < 2.4:
			continue
		var q := 0
		for c in conts:
			if r.grow(0.3).has_point(Vector2(c.x, c.z)):
				q += 1
		if cm.uso == preferir:
			q += 100
		if q > mais:
			mais = q
			melhor = r
	var centro := Vector2.ZERO
	var nq := 0
	for c in conts:
		if melhor.grow(0.3).has_point(Vector2(c.x, c.z)):
			centro += Vector2(c.x, c.z)
			nq += 1
	centro = centro / nq if nq > 0 else melhor.get_center()
	# fica do lado oposto do cômodo, a uns 2,5 m dos móveis
	var meio := melhor.get_center()
	var dirv := (meio - centro)
	if dirv.length() < 0.3:
		dirv = Vector2(0, 1)
	var rr := melhor.grow(-0.5)
	var canto := centro + dirv.normalized() * 3.0
	canto = Vector2(clampf(canto.x, rr.position.x, rr.end.x), clampf(canto.y, rr.position.y, rr.end.y))
	var local_pos := Vector3(canto.x, 0, canto.y)
	var local_olhar := Vector3(centro.x, 0, centro.y)
	if preferir == "porta":
		local_pos = Vector3(pr.largura * 0.18, 0, pr.profundidade * 0.5 - 0.8)
		local_olhar = Vector3(-pr.largura * 0.1, 0, -pr.profundidade * 0.5)
	var g := pr.global_transform * (local_pos + Vector3(0, andar * Predio.H, 0))
	var alvo := pr.global_transform * (local_olhar + Vector3(0, andar * Predio.H + 0.6, 0))
	jogador.visible = true
	jogador.position = g
	jogador.position.y = jogador.chao(g)
	jogador.yaw = atan2(alvo.x - g.x, alvo.z - g.z)
	jogador.pitch = 0.2
	jogador.pivo.rotation = Vector3(jogador.pitch, jogador.yaw, 0)
	jogador.corpo.rotation.y = jogador.yaw
	jogador.corpo.pose_caminhada(0.0, 0.0)
	jogador.camera.current = true
	jogador._atualizar_predio(0.0)

## Prints da etapa 3: recrutas, apartamentos e automação.
func _capturar_recrutas() -> void:
	comboio.set_physics_process(false)
	mundo.mat_capim.set_shader_parameter("tempo", 1.3)
	var cam := Camera3D.new()
	cam.far = 2500.0
	cam.near = 0.05
	add_child(cam)
	hud.visible = false
	# comboio: picape, trailer, apartamentos, oficina, estufa
	var tipos := [["apartamentos", 3, 0.85], ["oficina", 2, 0.8], ["estufa", 2, 0.85]]
	for t in tipos:
		var r := _novo_reboque(t[0], t[1], t[2])
		comboio.engatar(r, true)
	estoque.comida = 9
	estoque.agua = 7
	estoque.sucata = 22
	estoque.galoes_diesel = 1
	var nomes := [["Tião", "vigia"], ["Marta", "medico"], ["Pedrão", "mecanico"], ["Neide", "agricultor"], ["Dinho", "batedor"]]
	for i in nomes.size():
		var rc := Recrutas.novo(nomes[i][0], nomes[i][1], 7000 + i * 13)
		rc.abates = [7, 1, 3, 2, 9][i]
		rc.moral = [0.8, 0.7, 0.62, 0.78, 0.55][i]
		rc.vida = [1.0, 1.0, 0.85, 1.0, 0.7][i]
		base.lista.append(rc)
	base.distribuir_camas()
	var zc := 620.0
	var lat := -11.0
	var dz := mundo.direcao(zc)
	var pc := mundo.ponto_estrada(zc, lat)
	pc.y = mundo.altura(pc.x, pc.z)
	comboio.posicionar_livre(pc, atan2(dz.x, dz.z), 0.03)
	mundo.atualizar(pc)
	_limpar_zumbis_perto(pc, 60.0)
	var apto := base.reboque("apartamentos")

	# 78 — vila: convidando um morador
	var vila := _achar_lugar("vila")
	if not vila.is_empty():
		hora = 15.8
		_atualizar_ceu()
		mundo.atualizar(vila.pos)
		await get_tree().process_frame
		var npc: Node3D = null
		for h in mundo.npcs:
			if is_instance_valid(h) and Recrutas.pode_recrutar(h) and h.get_meta("funcao") == "mecanico":
				npc = h
		if npc == null:
			for h in mundo.npcs:
				if is_instance_valid(h) and Recrutas.pode_recrutar(h):
					npc = h
		if npc:
			var fr := npc.global_transform.basis.z
			_limpar_zumbis_perto(npc.global_position, 20.0)
			_posar_jogador(npc.global_position + fr * 2.4 + npc.global_transform.basis.x * 0.6, npc.global_position + Vector3(0, 1.2, 0), -0.08, 0.25)
			# deixa uma cama livre para o convite
			var guarda: Dictionary = base.lista.pop_back()
			base.distribuir_camas()
			estoque.remedio = 2
			estoque.pecas = 9
			hud.visible = true
			_atualizar_hud()
			_abrir_painel(_painel_npc.bind(npc))
			await _salvar("78_vila_convite")
			_fechar_janela()
			base.lista.append(guarda)
			base.distribuir_camas()
			hud.visible = false

	# 79 — o comboio com o reboque de apartamentos, fim de tarde
	hora = 17.3
	_atualizar_ceu()
	mundo.atualizar(pc)
	jogador.visible = false
	var b := apto.global_transform.basis
	var de := apto.global_position - b.x * 9.0 - b.z * 4.5 + Vector3(0, 2.6, 0)
	_abrir_vista(de, apto.global_position)
	cam.fov = 52.0
	cam.look_at_from_position(de, apto.global_position + b.z * 1.5 + Vector3(0, 1.3, 0), Vector3.UP)
	cam.current = true
	await _salvar("79_comboio_apartamentos")

	# 80 — acampamento com os recrutas trabalhando (anoitecendo)
	hora = 18.4
	_atualizar_ceu()
	jogador.position = trailer.global_position + trailer.global_transform.basis.x * 6.0
	_alternar_acampamento()
	base._t_cena = 0.0
	base.atualizar_cena(1.0)
	for r in base.nos:
		r.set_meta("animar_captura", true)
	for f in 40:
		await get_tree().process_frame
	for r in base.nos:
		r.set_meta("animar_captura", false)
	var ct := trailer.global_position
	var bt := trailer.global_transform.basis
	var de2 := ct - bt.x * 17.0 + bt.z * 3.0 + Vector3(0, 11.0, 0)
	_abrir_vista(de2, ct)
	cam.fov = 58.0
	cam.current = true
	cam.look_at_from_position(de2, ct - bt.z * 1.5 + Vector3(0, 0.5, 0), Vector3.UP)
	await _salvar("80_acampamento_recrutas")

	# 81 — de perto: o mecânico na oficina e a médica na fogueira, em 3ª pessoa
	var mec: Recruta = null
	var med: Recruta = null
	for r in base.nos:
		if r.dados.funcao == "mecanico":
			mec = r
		if r.dados.funcao == "medico":
			med = r
	if med:
		hud.visible = true
		var fora := -trailer.global_transform.basis.x
		var pj := med.global_position + fora * 1.9 + trailer.global_transform.basis.z * 0.6
		_posar_jogador(pj, med.global_position + Vector3(0, 1.0, 0), -0.12, 0.3)
		med.rotation.y = atan2(pj.x - med.global_position.x, pj.z - med.global_position.z)
		med.pose_caminhada(0.0, 0.0)
		jogador.camera.position = Vector3(-0.85, 0.25, -3.3)
		_atualizar_hud()
		hud.limpar_aviso()
		hud.dica = "[E] Falar com Marta (médica)"
		await _salvar("81_falando_com_recruta")
		_abrir_painel(_painel_recruta.bind(med.dados))
		await _salvar("82_painel_recruta")
		_fechar_janela()
		hud.visible = false
		jogador.visible = false

	# 83 — ataque noturno: recrutas acordam e defendem o comboio
	hora = 20.1
	_atualizar_ceu()
	jogador.visible = false
	var zs: Array = []
	var tipos_z := ["comum", "corredor", "comum", "brutamonte", "comum", "comum", "rastejante", "comum"]
	for i in 8:
		var q: Vector3 = ct + bt.x * (6.5 + (i % 3) * 3.2) + bt.z * (-7.0 + i * 2.0)
		zs.append(_zumbi_posado(q, ct + bt.z * (-7.0 + i * 2.0), tipos_z[i], 400 + i, i * 0.9, i % 2 == 0, 0.6 if i % 3 == 0 else 0.0))
	base._acordados_t = 0.0
	base._t_cena = 0.0
	base.atualizar_cena(1.0)
	var usados: Array = []
	for r in base.nos:
		var alvo: Zumbi = null
		var md := 1e9
		for z in zs:
			var d: float = r.global_position.distance_to(z.global_position)
			if d < md and not usados.has(z):
				md = d
				alvo = z
		if alvo == null:
			continue
		r.pose_caminhada(0.0, 0.0)
		if r.dados.funcao == "vigia":
			r.global_position = jogador.global_position.lerp(ct + bt.x * 3.0 + bt.z * 1.0, 1.0)
			r.global_position.y = jogador.chao(r.global_position)
			var dv: Vector3 = alvo.global_position - r.global_position
			r.rotation.y = atan2(dv.x, dv.z)
			r.pose_mirar(1.0)
			r._flash.visible = true
		elif r.dados.funcao in ["batedor", "agricultor", "mecanico"]:
			usados.append(alvo)
			var dirz: Vector3 = alvo.global_position - ct
			dirz.y = 0.0
			r.global_position = alvo.global_position - dirz.normalized() * 1.25
			r.global_position.y = jogador.chao(r.global_position)
			var dv2: Vector3 = alvo.global_position - r.global_position
			r.rotation.y = atan2(dv2.x, dv2.z)
			alvo.rotation.y = atan2(-dv2.x, -dv2.z)
			alvo._anim_ataque = 0.7
			alvo._animar(0.5)
			r.pose_caminhada(1.2, 0.8)
			r.ombro_d.rotation.x = -2.5
			r.ombro_d.rotation.z = 0.55
			r.tronco.rotation.y = 0.4
		elif r.dados.funcao == "medico":
			r.global_position = ct + bt.x * 2.0 - bt.z * 2.5
			r.global_position.y = jogador.chao(r.global_position)
			r.rotation.y = trailer.global_rotation.y + PI * 0.5
	# holofote no teto do trailer (vigia acendeu)
	var holo := SpotLight3D.new()
	add_child(holo)
	holo.light_color = Color(1.0, 0.92, 0.8)
	holo.light_energy = 6.0
	holo.spot_range = 30.0
	holo.spot_angle = 30.0
	holo.shadow_enabled = true
	holo.global_position = ct + Vector3(0, 3.2, 0) + bt.x * 0.8
	holo.look_at(ct + bt.x * 10.0 + Vector3(0, 0.5, 0), Vector3.UP)
	hud.dica = ""
	cam.current = true
	cam.fov = 55.0
	var de3 := ct + bt.x * 15.0 - bt.z * 6.0 + Vector3(0, 6.0, 0)
	_abrir_vista(de3, ct + bt.x * 6.0)
	cam.look_at_from_position(de3, ct + bt.x * 4.0 + Vector3(0, 0.2, 0), Vector3.UP)
	hud.visible = true
	_atualizar_hud()
	hud.aviso("Tião: \"Zumbis vindo do leste! 8 deles!\"")
	await _salvar("83_ataque_noturno")
	hud.visible = false
	for z in zs:
		mundo.zumbis_vivos.erase(z)
		z.queue_free()
	holo.queue_free()
	base.limpar_cena()

	# 84 / 85 — dentro dos apartamentos: recrutas dormindo e o quadro
	hora = 2.5
	_atualizar_ceu()
	apto.dormindo = true
	apto.reconstruir()
	hud.limpar_aviso()
	_entrar_em(apto)
	fp.pos_local = Vector3(0, fp.piso, -apto.comprimento() * 0.5 + 0.7)
	fp.yaw = 0.0
	fp.pitch = -0.18
	fp._atualizar_camera()
	hud.visible = true
	_atualizar_hud()
	hud.dica = "[E] Cama de Neide"
	await _salvar("84_apartamentos_noite")
	hud.dica = ""
	_abrir_painel(_painel_recrutas)
	await _salvar("85_quadro_recrutas")
	_fechar_janela()
	_sair_de_dentro()
	apto.dormindo = false
	apto.reconstruir()

	# 86 — de manhã: o relatório do que os recrutas fizeram
	base._abates_noite = {"Tião": 3, "Dinho": 1}
	base._colhido = 4
	base._pecas_feitas = 2
	base.registro.append("Dinho voltou da expedição com 7 sucata, 2 comida, 1 remédio.")
	base.registro.append("A médica conteve a sua infecção.")
	hora = 21.0
	_entrar_em(trailer)
	dormir()
	_atualizar_ceu()
	hud.limpar_aviso()
	hud.dica = ""
	_atualizar_hud()
	await _salvar("86_relatorio_manha")
	get_tree().quit()

## Prints da rodada 5: casas da vila, mata nos assentamentos, apocalipse, caça, armas, criação.
func _etapa() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--etapa="):
			return a.substr(8)
	return ""

## Trailer principal visto dos quatro lados, compartimentos fechados ou abertos (--depois).
func _capturar_trailer() -> void:
	comboio.set_physics_process(false)
	var cam := Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	hud.visible = false
	jogador.visible = false
	hora = 15.0
	_atualizar_ceu()
	var pa0 := mundo.ponto_estrada(620.0, -11.0)
	pa0.y = mundo.altura(pa0.x, pa0.z)
	var dza := mundo.direcao(620.0)
	comboio.posicionar_livre(pa0, atan2(dza.x, dza.z), 0.0)
	mundo.atualizar(pa0)
	await get_tree().process_frame
	_limpar_zumbis_perto(pa0, 60.0)
	var t: Node3D = trailer
	var b := t.global_transform.basis
	var c := t.global_position + Vector3(0, 1.2, 0)
	var vistas := [["direita", b.x * 4.2 + b.z * 0.6 + Vector3(0, 0.6, 0)], ["esquerda", -b.x * 4.2 + b.z * 0.3 + Vector3(0, 0.6, 0)], ["frente", b.z * 4.6 + b.x * 1.6 + Vector3(0, 1.0, 0)], ["tras", -b.z * 4.4 - b.x * 1.4 + Vector3(0, 0.8, 0)]]
	var depois := OS.get_cmdline_user_args().has("--depois")
	if depois:
		for id in trailer.compartimentos_abertos:
			trailer.compartimentos_abertos[id] = true
		trailer.reconstruir()
		await get_tree().process_frame
	for v in vistas:
		var de: Vector3 = c + v[1]
		_abrir_vista(de, c)
		cam.fov = 50.0
		cam.look_at_from_position(de, c, Vector3.UP)
		cam.current = true
		await _salvar("trailer_%s%s" % [v[0], "_aberto" if depois else ""])
	if depois:
		for k in ITENS:
			estoque[k] = 0
		estoque.merge({"comida": 6, "agua": 5, "carne_assada": 2, "remedio": 1, "bandagem": 3, "pecas": 7, "sucata": 18, "galoes_diesel": 2, "pistola": 1, "municao_pistola": 14, "espingarda": 1, "cartucho": 6}, true)
		for id in ["despensa", "bagageiro"]:
			var pj := t.global_transform * trailer.ponto_compartimento(id)
			_posar_jogador(pj + (pj - t.global_position).normalized() * 0.8, t.global_transform * (trailer.ponto_compartimento(id) * Vector3(0.6, 1, 1)) + Vector3(0, 1.0, 0), -0.12, 0.35)
			hud.visible = true
			_atualizar_hud()
			_compartimento_preso = true
			_abrir_painel(_painel_compartimento.bind(id))
			await _salvar("trailer_painel_%s" % id)
			_fechar_janela()
	get_tree().quit()

## Prints da etapa 9: os lugares grandes de cima, a tranca, o porão no escuro e com lanterna, o binóculo e uma pichação.
func _capturar_exploracao() -> void:
	comboio.set_physics_process(false)
	var cam := Camera3D.new()
	cam.far = 2500.0
	cam.near = 0.05
	add_child(cam)
	hud.visible = false
	jogador.visible = false
	hora = 16.0
	_atualizar_ceu()
	for t in ["base_militar", "presidio", "shopping"]:
		var l := _achar_lugar(t)
		if l.is_empty():
			continue
		jogador.position = l.pos
		comboio.posicionar_livre(l.pos + Vector3(120, 0, 0), 0.0, 0.0)
		mundo.atualizar(l.pos)
		await get_tree().process_frame
		await get_tree().process_frame
		var no: Node3D = mundo.lugares_ativos.get(l.id)
		var fr := Vector3(0, 0, 1)
		if no:
			fr = no.global_transform.basis.z
		var de: Vector3 = l.pos + fr * 62.0 + fr.cross(Vector3.UP) * 30.0 + Vector3(0, 38.0, 0)
		_abrir_vista(de, l.pos)
		cam.fov = 55.0
		cam.look_at_from_position(de, l.pos + Vector3(0, 2.0, 0), Vector3.UP)
		cam.current = true
		await _salvar("explorar_%s" % t)
		if t == "base_militar":
			# a porta do paiol, com o painel da tranca
			var tr: Array = mundo.vasculhaveis.filter(func(v): return is_instance_valid(v) and v.has_meta("tranca") and v.global_position.distance_to(l.pos) < 80.0)
			if not tr.is_empty():
				var v: Node3D = tr[0]
				var fv: Vector3 = v.get_parent().global_transform.basis.z
				_posar_jogador(v.global_position + fv * 2.6 - Vector3(0, 1.0, 0), v.global_position, -0.05, 0.3)
				_limpar_zumbis_perto(v.global_position, 25.0)
				hud.visible = true
				estoque.pe_de_cabra = 1
				_atualizar_hud()
				_abrir_painel(exploracao.painel_tranca.bind(v))
				await _salvar("explorar_tranca")
				_fechar_janela()
				hud.visible = false
				jogador.visible = false
			# o bunker: no escuro e com lanterna
			var ss: Array = mundo.subsolos.filter(func(x): return is_instance_valid(x) and x.global_position.distance_to(l.pos) < 80.0)
			if not ss.is_empty():
				var sb: Subsolo = ss[0]
				var fs := sb.global_position + Vector3(3.0, 1.8, 3.0)
				cam.look_at_from_position(fs, sb.global_position + Vector3(0, 0.4, 0), Vector3.UP)
				cam.current = true
				await _salvar("explorar_bunker_fora")
				for luz in [false, true]:
					estoque.lanterna = 1 if luz else 0
					_entrar_em(sb)
					fp.pos_local = Vector3(0, sb.FUNDO, 4.0)
					fp.yaw = PI
					fp.pitch = -0.12
					fp._atualizar_camera()
					hud.visible = true
					_atualizar_hud()
					await _salvar("explorar_bunker_%s" % ("lanterna" if luz else "escuro"))
					_sair_de_dentro()
					hud.visible = false
					jogador.visible = false
	# binóculo: estrada aberta, zumbis lá na frente
	var zb0 := 2400.0
	var pv := mundo.ponto_estrada(zb0, 0.5)
	mundo.atualizar(pv)
	await get_tree().process_frame
	_limpar_zumbis_perto(pv, 300.0)
	var alvo_b := mundo.ponto_estrada(zb0 + 140.0, 0.0)
	for i in 7:
		var zp := mundo.ponto_estrada(zb0 + 130.0 + i * 4.0, -3.0 + (i % 3) * 3.0)
		var zb := mundo.criar_zumbi(mundo, zp, PI, 900 + i, "brutamonte" if i == 3 else "comum")
		zb.set_process(false)
	_posar_jogador(pv, alvo_b + Vector3(0, 1.4, 0), -0.01, 0.0)
	jogador.camera.current = true
	estoque.binoculo = 1
	hud.visible = true
	exploracao._alternar_zoom()
	for i in 20:
		await get_tree().process_frame
	exploracao._observar()
	_atualizar_hud()
	await _salvar("explorar_binoculo")
	exploracao._alternar_zoom()
	get_tree().quit()

## Prints da etapa 8: os 4 reboques raros, o comboio com nome e troféus, pneu furado e o rádio no mapa.
func _capturar_raros() -> void:
	comboio.set_physics_process(false)
	var cam := Camera3D.new()
	cam.far = 2500.0
	cam.near = 0.05
	add_child(cam)
	hud.visible = false
	hora = 15.5
	_atualizar_ceu()
	var zc := 1460.0
	var dz := mundo.direcao(zc)
	var pc := mundo.ponto_estrada(zc, -0.6)
	comboio.posicionar_livre(pc, atan2(dz.x, dz.z), 0.0)
	for t in ["hospital", "radio", "destilaria", "torreta"]:
		comboio.engatar(_novo_reboque(t, 3 if t != "radio" else 2, 0.9), true)
	comboio.posicionar_livre(pc, atan2(dz.x, dz.z), 0.0)
	comboio_extra.nome_comboio = "ÚLTIMA PARADA"
	comboio_extra.trofeus = 3
	var nomes := [["Tião", "vigia"], ["Marta", "medico"], ["Beto", "mecanico"], ["Rita", "agricultor"], ["Zeca", "batedor"]]
	for i in nomes.size():
		var rc := Recrutas.novo(nomes[i][0], nomes[i][1], 300 + i)
		rc.dias = 10
		base.lista.append(rc)
	comboio_extra.aplicar_visual()
	jogador.position = pc + Vector3(30, 0, 0)
	mundo.atualizar(pc)
	await get_tree().process_frame
	await get_tree().process_frame
	_limpar_zumbis_perto(pc, 120.0)
	jogador.visible = false
	var lado := Vector3(dz.z, 0, -dz.x)
	# cada reboque raro de lado
	for i in range(1, comboio.cadeia.size()):
		var r: Node3D = comboio.cadeia[i]
		var alvo := r.global_position + Vector3(0, 1.4, 0)
		var de := alvo + lado * 5.5 - dz * 2.5 + Vector3(0, 1.3, 0)
		if r.tipo == "radio":
			de = alvo + lado * 8.0 - dz * 3.0 + Vector3(0, 2.0, 0)
			alvo += Vector3(0, 2.2, 0)
		_abrir_vista(de, alvo)
		cam.fov = 55.0
		cam.look_at_from_position(de, alvo, Vector3.UP)
		cam.current = true
		await _salvar("raro_%s" % r.tipo)
	# frente: troféus e nome no trailer
	var pf := picape.global_position + dz * 5.0 + lado * 2.6 + Vector3(0, 1.6, 0)
	cam.look_at_from_position(pf, picape.global_position + dz * 1.5 + Vector3(0, 1.0, 0), Vector3.UP)
	await _salvar("comboio_trofeus")
	var tl := trailer.global_position + lado * 4.2 + dz * 0.8 + Vector3(0, 1.5, 0)
	cam.look_at_from_position(tl, trailer.global_position + Vector3(0, 1.4, 0), Vector3.UP)
	await _salvar("comboio_nome")
	# visão geral do comboio
	var meio: Vector3 = comboio.cadeia[2].global_position
	var dg := meio + lado * 16.0 + dz * 6.0 + Vector3(0, 7.0, 0)
	_abrir_vista(dg, meio)
	cam.look_at_from_position(dg, meio + Vector3(0, 0.8, 0), Vector3.UP)
	await _salvar("comboio_raros")
	# pneu furado e rádio no mapa (dirigindo)
	comboio_extra.furar()
	_entrar_no_carro()
	comboio_extra._atualizar_radar()
	hud.visible = true
	for i in 3:
		await get_tree().process_frame
	_atualizar_hud()
	await _salvar("comboio_pneu_furado")
	_sair_do_carro()
	comboio_extra.pneu_furado = false
	_abrir_painel(comboio_extra.painel.bind(comboio_extra.reboque("radio")))
	await _salvar("raro_radio_painel")
	get_tree().quit()

## Prints da vida dos recrutas: acampamento com criança e idoso, painel e túmulo.
func _capturar_vida() -> void:
	comboio.set_physics_process(false)
	var cam := Camera3D.new()
	cam.far = 2500.0
	cam.near = 0.05
	add_child(cam)
	hud.visible = false
	for t in [["apartamentos", 3, 0.85], ["estufa", 2, 0.85]]:
		comboio.engatar(_novo_reboque(t[0], t[1], t[2]), true)
	estoque.merge({"comida": 400, "agua": 400, "sucata": 30}, true)
	var nomes := [["Tião", "vigia", "rabugento"], ["Marta", "medico", "trabalhador"], ["Pedrão", "mecanico", "leal"], ["Neide", "agricultor", "otimista"], ["Seu Lauro", "idoso", "corajoso"], ["Bia", "crianca", "medroso"]]
	for i in nomes.size():
		var rc := Recrutas.novo(nomes[i][0], nomes[i][1], 7100 + i * 17)
		VidaRecrutas.garantir(rc)
		rc.traco = nomes[i][2]
		base.lista.append(rc)
	base.distribuir_camas()
	var por_nome := {}
	for rc in base.lista:
		por_nome[rc.nome] = rc
	for d in 25:
		_passar_tempo(24.0)
		base.relatorio()
	for rc in por_nome.values():
		rc.moral = maxf(rc.moral, 0.6)
		if not base.lista.has(rc):
			base.lista.append(rc)
	base.distribuir_camas()
	estoque.merge({"comida": 30, "agua": 25}, true)
	var marta: Dictionary = por_nome["Marta"]
	marta.xp = 31.0
	marta.nivel = 3
	var pedrao: Dictionary = por_nome["Pedrão"]
	if pedrao.par == "" and marta.par == "":
		marta.par = pedrao.id
		pedrao.par = marta.id
		VidaRecrutas._mudar_relacao(marta, pedrao, 0.8)
	var zc := 620.0
	var dz := mundo.direcao(zc)
	var pc := mundo.ponto_estrada(zc, -11.0)
	pc.y = mundo.altura(pc.x, pc.z)
	comboio.posicionar_livre(pc, atan2(dz.x, dz.z), 0.03)
	mundo.atualizar(pc)
	await get_tree().process_frame
	_limpar_zumbis_perto(pc, 60.0)
	# acampamento ao entardecer
	hora = 17.6
	_atualizar_ceu()
	jogador.position = trailer.global_position + trailer.global_transform.basis.x * 6.0
	_alternar_acampamento()
	base._t_cena = 0.0
	base.atualizar_cena(1.0)
	for r in base.nos:
		r.set_meta("animar_captura", true)
	for f in 40:
		await get_tree().process_frame
	for r in base.nos:
		r.set_meta("animar_captura", false)
	var ct := trailer.global_position
	var bt := trailer.global_transform.basis
	var crianca: Recruta = null
	var idoso: Recruta = null
	for r in base.nos:
		if r.dados.funcao == "crianca":
			crianca = r
		if r.dados.funcao == "idoso":
			idoso = r
	var foco := ct
	if crianca and idoso:
		foco = (crianca.global_position + idoso.global_position) * 0.5
	var de := foco - bt.x * 6.5 + bt.z * 3.5 + Vector3(0, 2.8, 0)
	_abrir_vista(de, foco)
	cam.fov = 55.0
	cam.current = true
	cam.look_at_from_position(de, foco + Vector3(0, 0.7, 0), Vector3.UP)
	jogador.visible = false
	await _salvar("vida_acampamento")
	# painel da Marta
	hud.visible = true
	_atualizar_hud()
	_abrir_painel(_painel_recruta.bind(marta))
	await _salvar("vida_painel")
	_fechar_janela()
	_abrir_painel(_painel_recrutas)
	await _salvar("vida_quadro")
	_fechar_janela()
	hud.visible = false
	# túmulo do Tião na beira da estrada, de manhã cedo
	var tiao: Dictionary = por_nome["Tião"]
	base.lista.erase(tiao)
	VidaRecrutas.luto(base, tiao, mundo.ponto_estrada(zc + 25.0, 0.0))
	hora = 7.2
	_atualizar_ceu()
	await get_tree().process_frame
	var tm: Dictionary = mundo.tumulos.values()[0][0]
	var tp: Vector3 = tm.pos
	tp.y = mundo.altura(tp.x, tp.z)
	var de3 := mundo.ponto_estrada(zc + 21.5, 0.0) + Vector3(0, 1.6, 0)
	_abrir_vista(de3, tp)
	cam.look_at_from_position(de3, tp + Vector3(0, 0.6, 0), Vector3.UP)
	await _salvar("vida_tumulo")
	get_tree().quit()

## Prints da rodada de refino: casas com relevo, fogo e portão, cabine da picape,
## interior do trailer, pulo e a horda de longe.
func _capturar_refino() -> void:
	var cam := Camera3D.new()
	cam.far = 2500.0
	add_child(cam)
	comboio.set_physics_process(false)
	hud.visible = false
	jogador.visible = false
	var so: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--so="):
			so = a.substr(5)
	# 1) casas de uma vila, de dia
	if so == "" or so == "casa":
		hora = 10.2
		_atualizar_ceu()
		var achou := false
		for reg_i in 6:
			for l in mundo.lugares_da_regiao(reg_i):
				if achou or not (l.tipo in ["vila", "assentamento", "cidade"]):
					continue
				jogador.position = l.pos
				mundo.atualizar(l.pos)
				await get_tree().process_frame
				var casas: Array = mundo.estruturas.filter(func(x): return is_instance_valid(x) and x is Predio and x.global_position.distance_to(l.pos) < 90.0)
				if casas.is_empty():
					continue
				achou = true
				_limpar_zumbis_perto(l.pos, 90.0)
				var n := 0
				for pr in casas.slice(0, 2):
					var fr: Vector3 = pr.global_transform.basis.z
					var lado: Vector3 = pr.global_transform.basis.x
					var c: Vector3 = pr.global_position + Vector3(0, 1.6, 0)
					var de: Vector3 = c + fr * (pr.profundidade * 0.5 + 5.5) + lado * (pr.largura * 0.5 + 1.5) + Vector3(0, 0.3, 0)
					_abrir_vista(de, c)
					cam.fov = 60.0
					cam.current = true
					cam.look_at_from_position(de, c, Vector3.UP)
					await _salvar("refino_casa_%d" % n)
					var de2: Vector3 = pr.global_position + fr * (pr.profundidade * 0.5 + 1.6) + lado * 0.6 + Vector3(0, 1.4, 0)
					var al2: Vector3 = pr.global_position + fr * (pr.profundidade * 0.5) - lado * 1.0 + Vector3(0, 1.0, 0)
					_abrir_vista(de2, al2)
					cam.look_at_from_position(de2, al2, Vector3.UP)
					await _salvar("refino_parede_%d" % n)
					n += 1
		if not achou:
			print("refino: nenhuma casa achada")
	# comboio parado na estrada para o resto
	var z := 14 * WorldGen.TAM + 20.0
	comboio.posicionar(z, -0.5, 0.0)
	var ct := trailer.global_position
	jogador.position = ct + trailer.global_transform.basis.x * 3.0
	mundo.atualizar(ct)
	await get_tree().process_frame
	_limpar_zumbis_perto(ct, 90.0)
	var bt := trailer.global_transform.basis
	# 2) fogo e portão ao entardecer
	if so == "" or so == "fogo":
		hora = 18.9
		_atualizar_ceu()
		_alternar_acampamento()
		var ac: Acampamento = acampamento
		for f in 40:
			await get_tree().process_frame
		var f0 := ac.fogueira
		var de := f0 + bt.z * 1.6 - bt.x * 1.2 + Vector3(0, 1.0, 0)
		_abrir_vista(de, f0)
		cam.fov = 55.0
		cam.current = true
		cam.look_at_from_position(de, f0 + Vector3(0, 0.45, 0), Vector3.UP)
		await _salvar("refino_fogo")
		var pc := (ac.portao_a + ac.portao_b) * 0.5
		var pc3 := Vector3(pc.x, ac.fogueira.y, pc.y)
		var fora := pc3 + (pc3 - ct).normalized() * 6.0 + Vector3(0, 1.7, 0)
		fora.y = jogador.chao(fora) + 1.7
		_abrir_vista(fora, pc3)
		cam.look_at_from_position(fora, pc3 + Vector3(0, 1.2, 0), Vector3.UP)
		await _salvar("refino_portao_fechado")
		# o jogador chega e o portão abre
		_posar_jogador(pc3 + (ct - pc3).normalized() * 1.2, pc3 + (pc3 - ct), -0.05, 0.0)
		cam.current = true
		for f in 90:
			await get_tree().process_frame
		await _salvar("refino_portao_aberto")
		jogador.visible = false
		_alternar_acampamento()
	# 3) cabine da picape
	if so == "" or so == "cabine":
		hora = 15.5
		_atualizar_ceu()
		comboio.diesel = 52.0
		picape.modo_cabine = true
		picape.reconstruir()
		await get_tree().process_frame
		var cb: Node3D = picape._corpo
		var olho: Vector3 = cb.global_transform * (Pickup.ASSENTO + Vector3(-0.05, 0.02, -0.1))
		var alvo: Vector3 = cb.global_transform * Vector3(0.05, 1.2, 1.0)
		_abrir_vista(olho, alvo)
		cam.fov = 70.0
		cam.near = 0.02
		cam.current = true
		cam.look_at_from_position(olho, alvo, Vector3.UP)
		await _salvar("refino_cabine")
		var alvo2: Vector3 = cb.global_transform * Vector3(-0.6, 1.1, 0.3)
		cam.look_at_from_position(olho, alvo2, Vector3.UP)
		await _salvar("refino_cabine_lado")
		picape.modo_cabine = false
		picape.reconstruir()
		cam.near = 0.05
	# 4) dentro do trailer
	if so == "" or so == "trailer":
		hora = 20.5
		_atualizar_ceu()
		trailer.modo_interior = true
		trailer.reconstruir()
		await get_tree().process_frame
		var rt: Node3D = trailer._root
		var olho: Vector3 = rt.global_transform * Vector3(0.35, Trailer.BASE_Y + 1.0, 0.95)
		var alvo: Vector3 = rt.global_transform * Vector3(-0.1, Trailer.BASE_Y + 0.5, -1.0)
		_abrir_vista(olho, alvo)
		cam.fov = 78.0
		cam.near = 0.02
		cam.current = true
		cam.look_at_from_position(olho, alvo, Vector3.UP)
		await _salvar("refino_trailer")
		var alvo2: Vector3 = rt.global_transform * Vector3(-0.3, Trailer.BASE_Y + 0.7, 1.6)
		var olho2: Vector3 = rt.global_transform * Vector3(0.2, Trailer.BASE_Y + 1.0, -0.2)
		cam.look_at_from_position(olho2, alvo2, Vector3.UP)
		await _salvar("refino_trailer_frente")
		trailer.modo_interior = false
		trailer.reconstruir()
		cam.near = 0.05
	# 5) pulo
	if so == "" or so == "pulo":
		hora = 11.0
		_atualizar_ceu()
		var pp := ct - bt.z * 9.0 + bt.x * 1.0
		_posar_jogador(pp, pp - bt.z * 10.0, -0.1, 0.0)
		jogador.set_process(true)
		jogador.no_ar = 0.55
		jogador._vy = 0.4
		jogador.corpo.loop("Jump_Loop")
		for f in 8:
			jogador.no_ar = 0.55
			await get_tree().process_frame
		var de5 := jogador.global_position + bt.x * 3.2 - bt.z * 2.5 + Vector3(0, 0.9, 0)
		cam.look_at_from_position(de5, jogador.global_position + Vector3(0, 1.0, 0), Vector3.UP)
		cam.current = true
		jogador.set_process(false)
		await _salvar("refino_pulo")
		jogador.visible = false
	# 5b) sacos de corpos no acostamento (antes eram vultos pretos)
	if so == "" or so == "sacos":
		hora = 9.5
		_atualizar_ceu()
		var zs := comboio.pos.z + 25.0
		var hw := WorldGen.LARG_ESTRADA * 0.5
		var ps := mundo.ponto_estrada(zs, hw + 1.6)
		ps.y = jogador.chao(ps)
		var rr := RandomNumberGenerator.new()
		rr.seed = 77
		var d := mundo.direcao(zs)
		Apocalipse._sacos_corpos(mundo, ps, atan2(d.x, d.z), rr)
		var de7 := mundo.ponto_estrada(zs - 5.0, -0.5) + Vector3(0, 1.7, 0)
		_abrir_vista(de7, ps)
		cam.fov = 55.0
		cam.current = true
		cam.look_at_from_position(de7, ps + Vector3(0, 0.2, 0), Vector3.UP)
		await _salvar("refino_sacos")
	# 6) a horda de longe e chegando
	if so == "" or so == "horda":
		hora = 16.8
		_atualizar_ceu()
		for dist in [[320.0, "refino_horda_longe"], [150.0, "refino_horda_perto"]]:
			defesa.z_horda = comboio.pos.z - dist[0]
			await get_tree().process_frame
			var de6 := mundo.ponto_estrada(comboio.pos.z - 14.0, 3.0) + Vector3(0, 2.2, 0)
			var al6 := mundo.ponto_estrada(defesa.z_horda - 30.0, 0.0) + Vector3(0, 1.0, 0)
			_abrir_vista(de6, al6)
			cam.fov = 55.0
			cam.current = true
			cam.look_at_from_position(de6, al6, Vector3.UP)
			await _salvar(dist[1])
	get_tree().quit()

## Prints do acampamento novo: cerca grande com portão, fogueira e a roda de cadeiras.
func _capturar_acampamento() -> void:
	var cam := Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	hora = 18.6
	_atualizar_ceu()
	comboio.set_physics_process(false)
	comboio.engatar(_novo_reboque("apartamentos", 3, 1.0), true)
	var nomes := [["Tião", "vigia"], ["Marta", "medico"], ["Beto", "mecanico"], ["Rita", "agricultor"], ["Zeca", "batedor"], ["Seu Zé", "idoso"], ["Bia", "crianca"]]
	for i in nomes.size():
		var rc := Recrutas.novo(nomes[i][0], nomes[i][1], 100 + i)
		VidaRecrutas.garantir(rc)
		base.lista.append(rc)
	base.distribuir_camas()
	var z := 14 * WorldGen.TAM + 20.0
	comboio.posicionar(z, -0.5, 0.0)
	var ct := trailer.global_position
	jogador.position = ct + trailer.global_transform.basis.x * 3.0
	mundo.atualizar(ct)
	await get_tree().process_frame
	_limpar_zumbis_perto(ct, 90.0)
	jogador.visible = false
	hud.visible = false
	_alternar_acampamento()
	var ac: Acampamento = acampamento
	base._t_cena = 0.0
	base.atualizar_cena(1.0)
	for r in base.nos:
		r.set_meta("animar_captura", true)
		if r._quer_sentar():
			var i: int = ac.pedir_cadeira(r)
			if i >= 0:
				r.global_position = ac.cadeiras[i].pos
				r.rotation.y = ac.cadeiras[i].yaw
	for f in 50:
		await get_tree().process_frame
	var bt := trailer.global_transform.basis
	# 1) visão de cima: a cerca inteira, o portão e a roda da fogueira
	var de := ct - bt.x * 24.0 - bt.z * 6.0 + Vector3(0, 20.0, 0)
	_abrir_vista(de, ct)
	cam.fov = 60.0
	cam.current = true
	cam.look_at_from_position(de, ct + Vector3(0, 0.0, 0), Vector3.UP)
	await _salvar("acamp_cerca")
	# 2) de perto: a roda na fogueira
	var f0 := ac.fogueira
	var de2 := f0 - bt.x * 4.6 + bt.z * 2.2 + Vector3(0, 2.1, 0)
	_abrir_vista(de2, f0)
	cam.fov = 58.0
	cam.look_at_from_position(de2, f0 + Vector3(0, 0.6, 0), Vector3.UP)
	await _salvar("acamp_fogueira")
	# 3) noite: zumbis presos do lado de fora da cerca, você lá dentro
	hora = 21.4
	_atualizar_ceu()
	for r in base.nos:
		r.set_meta("animar_captura", false)
	var pc := (ac.portao_a + ac.portao_b) * 0.5
	var pc3 := Vector3(pc.x, f0.y, pc.y)
	jogador.visible = true
	_posar_jogador(pc3 + (f0 - pc3).normalized() * 2.2, pc3 + (pc3 - f0), -0.05, 0.0)
	cam.current = true
	var fora := Vector2(pc.x, pc.y) + (Vector2(pc.x, pc.y) - Vector2(ct.x, ct.z)).normalized() * 0.9
	var dirc := (ac.portao_b - ac.portao_a).normalized()
	for k in 6:
		var q := fora + dirc * (k - 2.5) * 1.7 + (Vector2(pc.x, pc.y) - Vector2(ct.x, ct.z)).normalized() * (0.4 + (k % 2) * 0.9)
		if absf((q - pc).dot(dirc)) < 2.0:
			q += (Vector2(pc.x, pc.y) - Vector2(ct.x, ct.z)).normalized() * 0.2
		var p3 := Vector3(q.x, 0, q.y)
		p3.y = mundo.altura(p3.x, p3.z)
		var zz := mundo.criar_zumbi(mundo, p3, atan2(ct.x - p3.x, ct.z - p3.z), 60 + k, "comum")
		zz.set_process(false)
		zz.loop("Zombie_Idle")
	await get_tree().process_frame
	var de3 := pc3 + (f0 - pc3).normalized() * 7.0 + Vector3(0, 4.2, 0)
	var alvo3 := pc3 + (pc3 - f0).normalized() * 1.5 + Vector3(0, 0.4, 0)
	_abrir_vista(de3, alvo3)
	cam.look_at_from_position(de3, alvo3, Vector3.UP)
	await _salvar("acamp_noite")
	# 4) barra de progresso: vasculhar leva segundos, o relógio segue
	hud.visible = true
	_atualizar_hud()
	hud.acao_txt = "Vasculhando: guarda-roupa"
	hud.acao_prog = 0.62
	jogador.anim_trabalho = "Farm_Harvest"
	hora = 17.2
	_atualizar_ceu()
	_atualizar_hud()
	var pp := picape.global_transform * Vector3(2.4, 0, -0.5)
	_posar_jogador(pp, picape.global_transform * Vector3(0.9, 0, -1.6), -0.2, 0.6)
	for k in 10:
		await get_tree().process_frame
	await _salvar("acamp_barra_acao")
	get_tree().quit()

## Prints do cachorro: o evento de adoção, seguindo você, latindo, e na caçamba.
func _capturar_cachorro() -> void:
	var cam := Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	hora = 16.4
	_atualizar_ceu()
	comboio.set_physics_process(false)
	var z := 12 * WorldGen.TAM + 32.0
	var d0 := mundo.direcao(z)
	var pc := mundo.ponto_estrada(z, WorldGen.LARG_ESTRADA * 0.5 + 3.5)
	pc.y = mundo.altura(pc.x, pc.z)
	# comboio parado um pouco antes, para a cena da caçamba
	comboio.posicionar(z - 30.0, -0.5, 0.0)
	jogador.position = mundo.ponto_estrada(z - 12.0, 0.0)
	mundo.atualizar(pc)
	await get_tree().process_frame
	_limpar_zumbis_perto(pc, 60.0)
	jogador.visible = false
	hud.visible = false
	# 1) o evento: cachorro amarrado ao lado de um carro, com a placa
	var de := mundo.ponto_estrada(z - 4.5, WorldGen.LARG_ESTRADA * 0.5 - 0.5) + Vector3(0, 1.7, 0)
	_abrir_vista(de, pc)
	cam.fov = 50.0
	cam.look_at_from_position(de, pc + Vector3(0, 0.45, 0), Vector3.UP)
	cam.current = true
	await _salvar("cachorro_evento")
	# 2) adotado, seguindo o jogador
	var e: Dictionary = mundo.eventos_ativos.get(12, {})
	eventos._atual = e
	eventos._adotar()
	await get_tree().process_frame
	_fechar_janela()
	hud.relatorio_t = 0.0
	var lado_e := Vector3(-d0.z, 0, d0.x)
	var pj := mundo.ponto_estrada(z - 6.0, 1.5)
	_posar_jogador(pj, pj + d0 * 10.0, -0.12, 0.0)
	cachorro.global_position = pj + d0 * 0.4 - lado_e * 1.1
	cachorro.global_position.y = jogador.chao(cachorro.global_position)
	cachorro.rotation.y = atan2(d0.x, d0.z)
	cachorro.set_process(false)
	cachorro._tocar("Walk")
	hud.visible = true
	_atualizar_hud()
	var de2 := pj - d0 * 3.8 + lado_e * 1.6 + Vector3(0, 1.9, 0)
	cam.look_at_from_position(de2, pj + d0 * 1.5 + Vector3(0, 0.7, 0), Vector3.UP)
	cam.current = true
	await _salvar("cachorro_seguindo")
	# 3) latindo para um zumbi que vem pela estrada
	var zp := pj + d0 * 9.0 - lado_e * 2.0
	zp.y = mundo.altura(zp.x, zp.z)
	var zb := mundo.criar_zumbi(mundo, zp, atan2(-d0.x, -d0.z), 3, "comum")
	zb.set_process(false)
	cachorro.rotation.y = atan2(zp.x - cachorro.global_position.x, zp.z - cachorro.global_position.z)
	cachorro._oneshot = false
	cachorro._tocar("Attack", 0.0, true)
	cachorro._ap.seek(0.35, true)
	hud.aviso("%s está latindo para o norte. Tem coisa vindo (12 m)." % cachorro.nome)
	_atualizar_hud()
	var de3 := cachorro.global_position - lado_e * 4.5 - d0 * 2.0 + Vector3(0, 1.5, 0)
	cam.look_at_from_position(de3, (cachorro.global_position + zp) * 0.5 + Vector3(0, 0.7, 0), Vector3.UP)
	cam.current = true
	await _salvar("cachorro_latindo")
	zb.queue_free()
	# 4) na caçamba
	cachorro.set_process(true)
	_entrar_no_carro()
	for i in 4:
		await get_tree().process_frame
	cachorro.set_process(false)
	cachorro.posicionar_cacamba()
	cachorro._tocar("Idle")
	var pp: Vector3 = picape.global_position
	var de4 := pp - lado_e * 4.2 - d0 * 4.0 + Vector3(0, 2.4, 0)
	hud.visible = false
	cam.look_at_from_position(de4, pp - d0 * 1.8 + Vector3(0, 1.2, 0), Vector3.UP)
	cam.current = true
	await _salvar("cachorro_cacamba")
	get_tree().quit()

## Prints do comércio: banca na vila, painel de troca, pedido e bloqueio de facção.
func _capturar_comercio() -> void:
	var cam := Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	hora = 16.2
	_atualizar_ceu()
	comboio.set_physics_process(false)
	var vila := _achar_lugar("vila")
	mundo.atualizar(vila.pos)
	await get_tree().process_frame
	var raiz: Node3D = mundo.lugares_ativos.get(vila.id)
	var vend: Node3D = null
	for h in mundo.npcs:
		if is_instance_valid(h) and String(h.get_meta("chave", "")).ends_with(":vendedor"):
			vend = h
	jogador.visible = false
	hud.visible = false
	var alvo := vend.global_position + Vector3(0, 1.1, 0)
	var para_centro := (raiz.global_position - vend.global_position)
	para_centro.y = 0.0
	var de := vend.global_position + para_centro.normalized() * 5.5 + para_centro.normalized().cross(Vector3.UP) * 2.0 + Vector3(0, 2.0, 0)
	_abrir_vista(de, alvo)
	cam.fov = 60.0
	cam.look_at_from_position(de, alvo, Vector3.UP)
	cam.current = true
	await _salvar("comercio_banca")
	# painel de troca, com coisa para vender e crédito
	estoque.merge({"remedio": 4, "pele": 3, "couro": 2, "molotov": 2, "sucata": 40}, true)
	comercio.reputacao(vila.id, 30.0)
	comercio._lugar(vila.id).credito["lugar"] = 45
	hud.visible = true
	_atualizar_hud()
	comercio.abrir(vend)
	await _salvar("comercio_painel")
	_fechar_janela()
	# bloqueio de facção inimiga
	comercio.registrar_faccao("Irmandade do Asfalto", "furou")
	comercio.registrar_faccao("Irmandade do Asfalto", "furou")
	var k := 380
	mundo.pois_fixos[k] = "evento"
	mundo.eventos_tipo[k] = "saqueadores"
	var z := k * WorldGen.TAM + 32.0
	comboio.posicionar(z - 20.0, -0.5, 0.0)
	jogador.position = comboio.pos + Vector3(3, 0, 0)
	mundo.atualizar(comboio.pos)
	await get_tree().process_frame
	_limpar_zumbis_perto(comboio.pos, 60.0)
	var e: Dictionary = mundo.eventos_ativos.get(k, {})
	var d0 := mundo.direcao(z)
	var de2 := mundo.ponto_estrada(z - 14.0, -1.0) + Vector3(0, 2.3, 0)
	cam.look_at_from_position(de2, mundo.ponto_estrada(z, 0.0) + Vector3(0, 1.4, 0), Vector3.UP)
	estoque.comida = 25
	eventos._atual = e
	_abrir_painel(eventos._painel)
	await _salvar("comercio_faccao")
	get_tree().quit()

## Prints do combate com o comboio: agarrados, atirador na caçamba, espinhos e couraça.
func _capturar_combate_comboio() -> void:
	var cam := Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	hora = 16.0
	_atualizar_ceu()
	var z0 := 2200.0
	var p0 := mundo.ponto_estrada(z0, -0.5)
	var d0 := mundo.direcao(z0)
	comboio.posicionar_livre(p0, atan2(d0.x, d0.z), 0.0)
	comboio.set_physics_process(false)
	jogador.position = p0 + Vector3(3, 0, 0)
	mundo.atualizar(p0)
	await get_tree().process_frame
	_limpar_zumbis_perto(p0, 80.0)
	hud.visible = false
	jogador.visible = false
	# 1) zumbis agarrados na picape sem proteção
	var cc := combate_comboio
	comboio.dirigindo = true
	for i in 4:
		var lado := -1.0 if i % 2 == 0 else 1.0
		var veic: Node3D = picape if i < 3 else trailer
		var zb := mundo.criar_zumbi(mundo, veic.global_position, 0.0, 300 + i, "comum")
		await get_tree().process_frame
		cc._agarrar(zb, veic, Vector3(lado * (Pickup.LARGURA * 0.5 + 0.28), 0, -0.8 + i * 0.9 if veic == picape else 0.3))
	cc._segurar(comboio, 0.016, 6.0, 0.0)
	for g in cc.agarrados:
		g.z.fixar("Zombie_Scratch", 0.4)
	var lado_c := Vector3(d0.z, 0, -d0.x)
	var alvo := picape.global_position + Vector3(0, 1.0, 0) - d0 * 1.5
	var de := alvo + lado_c * 6.5 - d0 * 5.0 + Vector3(0, 2.2, 0)
	cam.fov = 55.0
	cam.look_at_from_position(de, alvo, Vector3.UP)
	cam.current = true
	await _salvar("comboio_agarrados")
	for g in cc.agarrados.duplicate():
		g.z.queue_free()
	cc.agarrados.clear()
	await get_tree().process_frame
	# 2) espinhos + posto de tiro + couraça, com o vigia na caçamba
	picape.config.espinhos.nivel = 2
	picape.config.posto_tiro.nivel = 2
	picape.config.protecao.nivel = 2
	picape.reconstruir()
	trailer.config.couraca.nivel = 2
	trailer.reconstruir()
	base.lista.append(Recrutas.novo("Tião", "vigia", 11))
	estoque.municao_rifle = 20
	cc._atualizar_atirador(comboio)
	await get_tree().process_frame
	await get_tree().process_frame
	var de2 := picape.global_position - lado_c * 6.0 - d0 * 6.5 + Vector3(0, 2.6, 0)
	cam.look_at_from_position(de2, picape.global_position + Vector3(0, 1.2, 0) - d0 * 2.0, Vector3.UP)
	await _salvar("comboio_blindado")
	# 3) atirador mirando um zumbi
	var zt := mundo.criar_zumbi(mundo, picape.global_position - d0 * 12.0 + lado_c * 4.0, 0.0, 77, "corredor")
	zt.estado = Zumbi.Estado.PERSEGUINDO
	zt.set_process(false)
	await get_tree().process_frame
	cc._t_tiro = 0.0
	cc._atirar(comboio, 0.016)
	await get_tree().process_frame
	var de3 := picape.global_position + lado_c * 3.5 + d0 * 1.0 + Vector3(0, 2.8, 0)
	cam.look_at_from_position(de3, picape.global_position - d0 * 5.0 + Vector3(0, 1.4, 0), Vector3.UP)
	hud.visible = true
	hud.aviso("2 zumbis agarrados no comboio! Balance o volante, acelere ou freie de repente.")
	_atualizar_hud()
	await _salvar("comboio_atirador")
	get_tree().quit()

## Prints do progresso: Zona Segura, prêmio, missões do rádio e diário.
func _capturar_progresso() -> void:
	var cam := Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	hora = 16.8
	_atualizar_ceu()
	comboio.set_physics_process(false)
	var zm := progresso.z_marco(0)
	var p0 := mundo.ponto_estrada(zm - 45.0, -0.5)
	var d0 := mundo.direcao(zm - 45.0)
	comboio.posicionar_livre(p0, atan2(d0.x, d0.z), 0.0)
	jogador.position = p0 + Vector3(3, 0, 0)
	jogador.visible = false
	mundo.atualizar(p0)
	await get_tree().process_frame
	_limpar_zumbis_perto(p0, 120.0)
	for c in mundo.get_children():
		if c.name.begins_with("Chunk"):
			var mk := c.find_child("Marco_0", false, false)
			if mk:
				mk.visible = true
	var alvo := mundo.ponto_estrada(zm + 6.0, 0.0) + Vector3(0, 3.0, 0)
	var de := mundo.ponto_estrada(zm - 34.0, -2.5) + Vector3(0, 3.2, 0)
	_abrir_vista(de, alvo)
	cam.fov = 60.0
	cam.look_at_from_position(de, alvo, Vector3.UP)
	cam.current = true
	hud.visible = false
	await _salvar("progresso_zona_segura")
	# dentro, olhando o acampamento
	var zg: float = floor(zm / WorldGen.TAM) * WorldGen.TAM + 32.0
	var de_in := mundo.ponto_estrada(zg + 3.0, 1.5) + Vector3(0, 3.0, 0)
	cam.look_at_from_position(de_in, mundo.ponto_estrada(zg + 14.0, -9.0) + Vector3(0, 0.5, 0), Vector3.UP)
	await _salvar("progresso_acampamento")
	# painel do prêmio
	hud.visible = true
	cam.look_at_from_position(de, alvo, Vector3.UP)
	progresso._chegou(0)
	_atualizar_hud()
	await _salvar("progresso_premio")
	progresso._painel_premio().botoes[2][1].call()
	await get_tree().process_frame
	_fechar_janela()
	# missão de socorro (cerco)
	var id := progresso.nova_missao("socorro")
	var ms: Dictionary = progresso.missoes[id]
	var c2 := mundo.ponto_estrada(ms.z, ms.lat)
	comboio.posicionar(ms.z - 30.0, -0.5, 0.0)
	jogador.position = comboio.pos + Vector3(3, 0, 0)
	mundo.atualizar(c2)
	await get_tree().process_frame
	for z in mundo.zumbis_vivos:
		if is_instance_valid(z):
			z.set_process(false)
	var de3 := mundo.ponto_estrada(ms.z - 16.0, ms.lat * 0.25) + Vector3(0, 4.0, 0)
	cam.look_at_from_position(de3, c2 + Vector3(0, 1.2, 0), Vector3.UP)
	hud.visible = false
	await _salvar("progresso_socorro")
	# hospital de campanha
	var id2 := progresso.nova_missao("remedios")
	var ms2: Dictionary = progresso.missoes[id2]
	var c3 := mundo.ponto_estrada(ms2.z, ms2.lat)
	comboio.posicionar(ms2.z - 30.0, -0.5, 0.0)
	jogador.position = comboio.pos + Vector3(3, 0, 0)
	mundo.atualizar(c3)
	await get_tree().process_frame
	for z in mundo.zumbis_vivos:
		if is_instance_valid(z):
			z.set_process(false)
	var de4 := mundo.ponto_estrada(ms2.z - 14.0, ms2.lat * 0.3) + Vector3(0, 3.5, 0)
	cam.look_at_from_position(de4, c3 + Vector3(0, 1.0, 0), Vector3.UP)
	await _salvar("progresso_hospital")
	# diário e HUD dirigindo
	hud.visible = true
	progresso.cartas = [0, 1, 2, 3]
	_abrir_painel(progresso.painel_diario)
	await _salvar("progresso_diario")
	_fechar_janela()
	comboio.posicionar(ms.z - 200.0, -0.5, 0.0)
	mundo.atualizar(comboio.pos)
	_entrar_no_carro()
	for i in 4:
		await get_tree().process_frame
	_atualizar_hud()
	await _salvar("progresso_hud")
	get_tree().quit()

## Prints do clima: chuva, tempestade (com relâmpago), neblina, neve e farol à noite.
func _capturar_clima() -> void:
	var cam := Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	var z0 := 2600.0
	var p0 := mundo.ponto_estrada(z0, -0.5)
	var d0 := mundo.direcao(z0)
	comboio.posicionar_livre(p0, atan2(d0.x, d0.z), 0.0)
	comboio.set_physics_process(false)
	jogador.position = p0 + Vector3(3, 0, 0)
	jogador.visible = false
	mundo.atualizar(p0)
	await get_tree().process_frame
	_limpar_zumbis_perto(p0, 60.0)
	var tr: Node3D = trailer
	var de := tr.global_position - d0 * 9.0 + Vector3(d0.z, 0, -d0.x) * 4.5 + Vector3(0, 2.6, 0)
	var alvo := picape.global_position + d0 * 6.0 + Vector3(0, 1.0, 0)
	cam.fov = 60.0
	cam.look_at_from_position(de, alvo, Vector3.UP)
	cam.current = true
	hud.visible = true
	for v in [["limpo", 15.0], ["chuva", 15.0], ["tempestade", 15.5], ["neblina", 9.0], ["neve", 13.0]]:
		dia = 21 if v[0] == "neve" else 3
		hora = v[1]
		clima.forcar(v[0])
		await get_tree().process_frame
		if v[0] == "tempestade":
			clima.flash = 0.0
		_atualizar_ceu()
		_atualizar_hud()
		await _salvar("clima_%s" % v[0])
		if v[0] == "tempestade":
			clima.flash = 0.8
			_atualizar_ceu()
			await _salvar("clima_relampago")
			clima.flash = 0.0
	# noite com farol, dirigindo debaixo de chuva
	dia = 3
	hora = 22.0
	clima.forcar("chuva")
	picape.ligar_farol(true)
	var fr := d0
	var de2 := picape.global_position - fr * 7.0 + Vector3(fr.z, 0, -fr.x) * 2.5 + Vector3(0, 3.2, 0)
	cam.look_at_from_position(de2, picape.global_position + fr * 25.0, Vector3.UP)
	_atualizar_ceu()
	_atualizar_hud()
	await _salvar("clima_noite_farol")
	get_tree().quit()

## Prints da etapa de perigo: zumbis novos, ninho (inteiro e queimando) e aviso de faixa.
func _capturar_perigo() -> void:
	var cam := Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	hora = 16.0
	_atualizar_ceu()
	comboio.set_physics_process(false)
	var z0 := 33000.0
	var p0 := mundo.ponto_estrada(z0, -0.5)
	comboio.posicionar(z0, -0.5, 0.0)
	jogador.position = p0
	mundo.atualizar(p0)
	await get_tree().process_frame
	_limpar_zumbis_perto(p0, 120.0)
	hud.visible = false
	jogador.visible = false
	# fila de zumbis: comum, corredor, gritador, brutamonte, blindado
	var tipos := ["comum", "corredor", "gritador", "brutamonte", "blindado"]
	var base_p := mundo.ponto_estrada(z0 + 20.0, 0.0)
	var d := mundo.direcao(z0)
	var lado := Vector3(d.z, 0, -d.x)
	for i in tipos.size():
		var q := base_p + lado * (-4.0 + i * 2.0)
		q.y = mundo.elevacao(z0 + 20.0) + 0.06
		var zb := mundo.criar_zumbi(mundo, q, atan2(-d.x, -d.z), 40 + i, tipos[i])
		zb.set_process(false)
	await get_tree().process_frame
	var de := base_p - d * 5.5 + Vector3(0, 1.6, 0)
	cam.fov = 55.0
	cam.look_at_from_position(de, base_p + Vector3(0, 1.0, 0), Vector3.UP)
	cam.current = true
	await _salvar("perigo_zumbis")
	# ninho
	var ni := Ninho.new()
	ni.mundo = mundo
	ni.chave = "ninho:print"
	var pn := mundo.ponto_estrada(z0 + 60.0, 14.0)
	pn.y = mundo.altura(pn.x, pn.z)
	ni.position = pn
	mundo.add_child(ni)
	await get_tree().process_frame
	_limpar_zumbis_perto(pn, 30.0)
	ni.visible = true
	var de2 := pn + (p0 - pn).normalized() * 9.0 + Vector3(0, 3.0, 0)
	de2.y = mundo.altura(de2.x, de2.z) + 3.0
	_abrir_vista(de2, pn)
	cam.look_at_from_position(de2, pn + Vector3(0, 0.8, 0), Vector3.UP)
	await _salvar("perigo_ninho")
	ni.queimar(self)
	hora = 19.6
	_atualizar_ceu()
	for zz in mundo.zumbis_vivos:
		if is_instance_valid(zz):
			zz.set_process(false)
	await _salvar("perigo_ninho_fogo")
	# aviso de faixa
	hora = 16.0
	_atualizar_ceu()
	hud.visible = true
	var dv := mundo.ponto_estrada(z0 + 8.0, 3.0) + Vector3(0, 1.8, 0)
	cam.look_at_from_position(dv, mundo.ponto_estrada(z0 + 40.0, 0.0) + Vector3(0, 1.5, 0), Vector3.UP)
	_avisou_marco.erase("faixa3")
	_avisar_faixa()
	_atualizar_hud()
	await _salvar("perigo_aviso")
	get_tree().quit()

## Prints da horda visível (--horda): de longe, de perto e pelo retrovisor.
func _capturar_horda() -> void:
	var cam := Camera3D.new()
	cam.far = 2500.0
	add_child(cam)
	hora = 17.2
	_atualizar_ceu()
	var z0 := 1500.0
	var p0 := mundo.ponto_estrada(z0, -0.5)
	var d0 := mundo.direcao(z0)
	comboio.posicionar_livre(p0, atan2(d0.x, d0.z), 0.0)
	comboio.set_physics_process(false)
	mundo.atualizar(p0)
	await get_tree().process_frame
	_limpar_zumbis_perto(p0, 400.0)
	hud.visible = false
	jogador.visible = false
	jogador.position = p0 + Vector3(2.5, 0, -6.0)
	if "--alto" in OS.get_cmdline_user_args():
		defesa.z_horda = z0 - 200.0
		await get_tree().process_frame
		var de2 := mundo.ponto_estrada(z0 - 20.0, 30.0) + Vector3(0, 45.0, 0)
		var al2 := mundo.ponto_estrada(z0 - 300.0, 0.0)
		cam.fov = 60.0
		cam.look_at_from_position(de2, al2, Vector3.UP)
		cam.current = true
		await _salvar("horda_alto")
		get_tree().quit()
		return
	for v in [[420.0, "horda_longe", 7.0, 4.5], [110.0, "horda_perto", 3.0, 2.0]]:
		defesa.z_horda = z0 - v[0]
		await get_tree().process_frame
		var zc: float = z0 - 12.0
		var de: Vector3 = mundo.ponto_estrada(zc, v[2]) + Vector3(0, v[3], 0)
		var alvo: Vector3 = mundo.ponto_estrada(defesa.z_horda - 40.0, 0.0) + Vector3(0, 1.0, 0)
		_abrir_vista(de, alvo)
		cam.fov = 55.0
		cam.look_at_from_position(de, alvo, Vector3.UP)
		cam.current = true
		await _salvar(v[1])
	# dirigindo: a horda no retrovisor
	defesa.z_horda = z0 - 170.0
	hud.visible = true
	_entrar_no_carro()
	comboio.set_physics_process(true)
	for i in 10:
		await get_tree().process_frame
	_atualizar_hud()
	await _salvar("horda_retrovisor")
	get_tree().quit()

## Prints dos eventos na estrada (--eventos): cena de cada tipo e o painel de escolha.
func _capturar_eventos() -> void:
	comboio.set_physics_process(false)
	var cam := Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	hora = 16.6
	_atualizar_ceu()
	var tipos := ["saqueadores", "carona", "acidente", "militar"]
	var k := 30
	for t in tipos:
		mundo.pois_fixos[k] = "evento"
		mundo.eventos_tipo[k] = t
		k += 4
	k = 30
	for t in tipos:
		var z := k * WorldGen.TAM + 32.0
		var zc: float = z - {"saqueadores": 15.0, "carona": 9.0, "acidente": 14.0, "militar": 24.0}[t]
		comboio.posicionar(zc - 14.0, -0.5, 0.0)
		jogador.visible = false
		jogador.position = comboio.pos
		mundo.atualizar(comboio.pos)
		await get_tree().process_frame
		await get_tree().process_frame
		var e: Dictionary = mundo.eventos_ativos.get(k, {})
		var alvo: Vector3 = e.get("pos", mundo.ponto_estrada(z, 0.0))
		alvo.y = mundo.elevacao(z) + 1.2
		var lat: float = {"saqueadores": -1.0, "carona": 1.0, "acidente": -3.0, "militar": -1.5}[t]
		var de := mundo.ponto_estrada(zc, lat) + Vector3(0, (2.3 if t != "militar" else 4.2), 0)
		if t == "carona":
			alvo.y -= 0.3
		if t == "militar":
			alvo = mundo.ponto_estrada(z + 6.0, 0.0) + Vector3(0, 1.0, 0)
		_abrir_vista(de, alvo)
		cam.fov = 58.0
		cam.look_at_from_position(de, alvo, Vector3.UP)
		cam.current = true
		hud.visible = false
		await _salvar("evento_%s" % t)
		if t in ["saqueadores", "carona", "acidente"] and not e.is_empty():
			hud.visible = true
			_atualizar_hud()
			eventos._atual = e
			_abrir_painel(eventos._painel)
			await _salvar("evento_%s_painel" % t)
			if t == "saqueadores":
				# depois de pagar: os carros vão para o acostamento
				estoque.comida = 20
				eventos._painel().botoes[0][1].call()
				await get_tree().process_frame
				_fechar_janela()
				hud.visible = true
				await _salvar("evento_saqueadores_pago")
			eventos._atual = {}
			_fechar_janela()
		k += 4
	get_tree().quit()

## Prints dos modelos novos (personagens com rosto, zumbis, armas, ações).
func _capturar_modelos() -> void:
	comboio.set_physics_process(false)
	var cam := Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	hud.visible = false
	hora = 16.4
	_atualizar_ceu()
	var etapa := _etapa()
	if etapa == "" or etapa == "1":
		# zumbis vindo pela estrada, jogador mirando a pistola
		var z0 := 2000.0
		var p0 := mundo.ponto_estrada(z0, 0.5)
		mundo.atualizar(p0)
		await get_tree().process_frame
		_limpar_zumbis_perto(p0, 90.0)
		var dz := mundo.direcao(z0)
		var lado := Vector3(dz.z, 0, -dz.x)
		var r := RandomNumberGenerator.new()
		r.seed = 77
		var zs: Array = []
		var tipos := ["comum", "comum", "corredor", "comum", "brutamonte", "comum", "rastejante", "comum", "gritador", "comum", "comum"]
		for i in tipos.size():
			var q := p0 + dz * (5.0 + i * 1.25 + r.randf() * 1.5) + lado * r.randf_range(-3.5, 3.5)
			q.y = jogador.chao(q)
			var z := mundo.criar_zumbi(mundo, q, atan2(-dz.x, -dz.z) + r.randf_range(-0.3, 0.3), 500 + i, tipos[i])
			zs.append(z)
		await get_tree().process_frame
		for i in zs.size():
			var z: Zumbi = zs[i]
			if z.tipo == "rastejante":
				z.fixar("Crawl_Fwd", r.randf())
			else:
				z.fixar(["Zombie_Walk_Fwd", "Zombie_Walk_Fwd", "Zombie_Run_Fwd", "Zombie_Idle"][i % 4], r.randf())
		estoque.pistola = 1
		equip.selecionar("pistola")
		_posar_jogador(p0 - dz * 2.0, zs[0].global_position + Vector3(0, 1.2, 0), 0.02, 0.0)
		jogador.set_process(false)
		jogador.corpo.rotation.y = jogador.yaw
		jogador.corpo.fixar("Pistol_Aim_Neutral", 0.3)
		var de := p0 - dz * 4.4 + lado * 1.5 + Vector3(0, 1.85, 0)
		cam.fov = 55.0
		cam.look_at_from_position(de, p0 + dz * 6.0 + Vector3(0, 1.0, 0), Vector3.UP)
		cam.current = true
		await _salvar("119_zumbis_modelo")
		# de perto: golpe de facão, zumbi apanhando, outro caído
		for z in zs:
			z.visible = false
		var pz := p0 + dz * 1.3
		pz.y = jogador.chao(pz)
		var z1: Zumbi = zs[0]
		z1.visible = true
		z1.global_position = pz
		z1.rotation.y = atan2(-dz.x, -dz.z) + 0.2
		z1.fixar("Hit_Chest", 0.25)
		Sangue.jorro(mundo, pz + Vector3(0, 1.2, 0), dz + lado * 0.4, 1.4)
		var z2: Zumbi = zs[1]
		z2.visible = true
		z2.global_position = pz + lado * 1.5 + dz * 0.9
		z2.global_position.y = jogador.chao(z2.global_position)
		z2.rotation.y = atan2(-dz.x, -dz.z) - 0.5
		z2.fixar("Zombie_Scratch", 0.45)
		var z3: Zumbi = zs[3]
		z3.visible = true
		z3.global_position = pz - lado * 1.7 + dz * 1.4
		z3.global_position.y = jogador.chao(z3.global_position)
		z3.fixar("Death02", 1.0)
		Sangue.poca(mundo, z3.global_position + lado * 0.3, 1.1)
		var z4: Zumbi = zs[4]
		z4.visible = true
		z4.global_position = pz + dz * 3.5 - lado * 0.4
		z4.global_position.y = jogador.chao(z4.global_position)
		z4.fixar("Zombie_Walk_Fwd", 0.2)
		equip.selecionar("facao")
		jogador.corpo.trocar_arma("facao")
		jogador.corpo.destravar()
		jogador.corpo.fixar("Sword_Regular_A", 0.42)
		for f in 30:
			await get_tree().process_frame
		var de2 := pz + lado * 4.6 - dz * 1.2 + Vector3(0, 1.7, 0)
		cam.fov = 50.0
		cam.look_at_from_position(de2, pz - dz * 0.5 + Vector3(0, 1.0, 0), Vector3.UP)
		await _salvar("120_combate_de_perto")
		for z in zs:
			if is_instance_valid(z):
				z.queue_free()
		jogador.set_process(true)
	if etapa == "" or etapa == "2":
		var vila := _achar_lugar("vila")
		mundo.atualizar(vila.pos)
		await get_tree().process_frame
		_limpar_zumbis_perto(vila.pos, 70.0)
		var raiz: Node3D = mundo.lugares_ativos.get(vila.id)
		jogador.visible = false
		var pessoas: Array = []
		for h in raiz.find_children("*", "Humanoid", true, false):
			pessoas.append(h)
		print("pessoas na vila: ", pessoas.size())
		var alvo: Vector3 = pessoas[0].global_position if pessoas.size() > 0 else raiz.global_position
		for f in 20:
			await get_tree().process_frame
		var de3 := alvo + Vector3(-3.2, 1.9, 3.6)
		cam.fov = 55.0
		cam.look_at_from_position(de3, alvo + Vector3(0, 1.0, 0), Vector3.UP)
		cam.current = true
		await _salvar("121_vila_moradores")
		if pessoas.size() > 2:
			var a2: Vector3 = pessoas[2].global_position
			cam.look_at_from_position(a2 + Vector3(2.6, 1.7, 2.8), a2 + Vector3(0, 1.0, 0), Vector3.UP)
			await _salvar("121b_vila_moradores")
	if etapa == "" or etapa == "3":
		# ações do jogador: comer, beber, enfaixar, recarregar, arremessar, ajoelhar
		var p1 := mundo.ponto_estrada(900.0, -9.0)
		mundo.atualizar(p1)
		await get_tree().process_frame
		_limpar_zumbis_perto(p1, 40.0)
		var acoes := [["Consume", "", 0.45], ["Drink", "", 0.5], ["Bandage", "", 0.5], ["Pistol_Reload", "pistola", 0.45], ["OverhandThrow", "", 0.35], ["Fixing_Kneeling", "", 0.3]]
		var dz2 := mundo.direcao(900.0)
		var lado2 := Vector3(dz2.z, 0, -dz2.x)
		jogador.visible = false
		var bonecos: Array = []
		for i in acoes.size():
			var h := Humanoid.new()
			h.cores = jogador.corpo.cores
			h.com_mochila = true
			h.com_bone = true
			h.arma = acoes[i][1]
			mundo.add_child(h)
			var q := p1 + lado2 * (i - 2.5) * 1.6
			q.y = jogador.chao(q)
			h.global_position = q
			h.rotation.y = atan2(-dz2.x, -dz2.z) + 0.5
			bonecos.append(h)
		for f in 3:
			await get_tree().process_frame
		for i in acoes.size():
			bonecos[i].fixar(acoes[i][0], acoes[i][2])
		var de4 := p1 - dz2 * 6.5 + Vector3(0, 1.6, 0)
		cam.fov = 60.0
		cam.look_at_from_position(de4, p1 + Vector3(0, 0.9, 0), Vector3.UP)
		cam.current = true
		await _salvar("124_acoes_jogador")
		for h in bonecos:
			h.queue_free()
	if etapa == "6":
		# tutorial na tela
		var p6 := mundo.ponto_estrada(-4.0, -0.6)
		_posar_jogador(trailer.global_transform * Vector3(4.0, 0, -2.0), trailer.global_position + Vector3(0, 1.0, 0), -0.12, 0.35)
		hud.visible = true
		_atualizar_hud()
		tutorial.iniciar()
		for f in 20:
			tutorial._process(0.05)
		await _salvar("128_tutorial_1")
		tutorial.passo = 5
		tutorial._comecar_passo()
		for f in 20:
			tutorial._process(0.05)
		await _salvar("128_tutorial_2")
	if etapa == "" or etapa == "5":
		# vila e assentamento: do alto e da rua
		hora = 15.8
		_atualizar_ceu()
		var n_print := 126
		for tipo in ["vila", "assentamento"]:
			var lg := _achar_lugar(tipo)
			if lg.is_empty():
				continue
			mundo.atualizar(lg.pos)
			await get_tree().process_frame
			_limpar_zumbis_perto(lg.pos, 80.0)
			var raiz: Node3D = mundo.lugares_ativos.get(lg.id)
			jogador.visible = false
			for f in 10:
				await get_tree().process_frame
			var b := raiz.global_transform.basis
			var c := raiz.global_position
			var de_alto := c + b.z * 48.0 + b.x * 22.0 + Vector3(0, 40.0, 0)
			cam.fov = 60.0
			cam.look_at_from_position(de_alto, c + b.z * 2.0, Vector3.UP)
			cam.current = true
			await _salvar("%d_%s_do_alto" % [n_print, tipo])
			var de_rua := c + b.z * 14.0 + b.x * 2.2 + Vector3(0, 1.75, 0)
			_abrir_vista(de_rua, c - b.z * 20.0)
			cam.fov = 62.0
			cam.look_at_from_position(de_rua, c - b.z * 20.0 + Vector3(0, 3.0, 0), Vector3.UP)
			await _salvar("%d_%s_rua" % [n_print, tipo])
			if tipo == "vila":
				var de_ig := c - b.z * 6.0 + b.x * 9.0 + Vector3(0, 3.5, 0)
				cam.look_at_from_position(de_ig, c - b.z * 26.0 + Vector3(0, 4.0, 0), Vector3.UP)
				await _salvar("%d_vila_igreja" % n_print)
			n_print += 1
	if etapa == "" or etapa == "4":
		var pc := mundo.ponto_estrada(3300.0, -40.0)
		mundo.atualizar(pc)
		await get_tree().process_frame
		pc.y = mundo.altura(pc.x, pc.z)
		_limpar_zumbis_perto(pc, 60.0)
		var bichos := [["veado", Vector3(-2, 0, 4), 0.4, "Eating"], ["veado", Vector3(1.5, 0, 6), -0.8, "Idle"], ["veado", Vector3(3.5, 0, 3), 2.2, "Walk"], ["lobo", Vector3(-4, 0, 11), 1.2, "Gallop"], ["lobo", Vector3(-1, 0, 12), 0.9, "Idle_2"]]
		var r2 := RandomNumberGenerator.new()
		r2.seed = 4
		var lista: Array = []
		for b in bichos:
			var an := Animal.new()
			an.tipo = b[0]
			an.mundo = mundo
			an.semente = r2.randi()
			var pa: Vector3 = pc + b[1]
			pa.y = mundo.altura(pa.x, pa.z)
			an.position = pa
			mundo.add_child(an)
			an.rotation.y = b[2]
			lista.append([an, b[3]])
		await get_tree().process_frame
		for e in lista:
			e[0]._tocar(e[1])
			e[0]._ap.seek(r2.randf(), true)
			e[0]._ap.pause()
		jogador.visible = false
		var de4 := pc + Vector3(-6.0, 1.8, -5.0)
		_abrir_vista(de4, pc + Vector3(0, 0, 7))
		cam.fov = 55.0
		cam.look_at_from_position(de4, pc + Vector3(0, 0.6, 6.0), Vector3.UP)
		cam.current = true
		await _salvar("122_animais_modelo")
	get_tree().quit()

func _capturar_r5() -> void:
	comboio.set_physics_process(false)
	mundo.mat_capim.set_shader_parameter("tempo", 1.3)
	var cam := Camera3D.new()
	cam.far = 2500.0
	cam.near = 0.05
	add_child(cam)
	hud.visible = false
	jogador.visible = false
	# 98 / 99 — vila
	var vila := _achar_lugar("vila")
	if not vila.is_empty():
		hora = 16.2
		_atualizar_ceu()
		mundo.atualizar(vila.pos)
		await get_tree().process_frame
		var raiz: Node3D = mundo.lugares_ativos.get(vila.id)
		var de := raiz.global_transform * Vector3(-26.0, 18.0, 30.0)
		_abrir_vista(de, raiz.global_position)
		cam.fov = 55.0
		cam.look_at_from_position(de, raiz.global_transform * Vector3(0, 1.0, 8.0), Vector3.UP)
		cam.current = true
		await _salvar("98_vila_do_alto")
		var de2 := raiz.global_transform * Vector3(3.0, 1.7, 30.0)
		_abrir_vista(de2, raiz.global_transform * Vector3(-8.0, 1.5, 22.0))
		cam.fov = 60.0
		cam.look_at_from_position(de2, raiz.global_transform * Vector3(-9.0, 2.0, 22.0), Vector3.UP)
		await _salvar("99_casa_da_vila")
	# 100 — assentamento cercado de mata
	var l := {}
	for ll in mundo.lugares_da_regiao(0):
		if ll.tipo == "assentamento":
			l = ll
	if not l.is_empty():
		hora = 15.5
		_atualizar_ceu()
		mundo.atualizar(l.pos)
		await get_tree().process_frame
		var a := defesa.no_de(l.id)
		var de3 := a.global_de(Vector3(40.0, 55.0, 75.0))
		cam.fov = 55.0
		cam.look_at_from_position(de3, a.global_de(Vector3(0, 0, -6.0)), Vector3.UP)
		await _salvar("100_assentamento_na_mata")
	# 101 — estrada do fim do mundo (barricada de quarentena, sacos, carro queimado, mensagem)
	var zb := 3400.0
	hora = 17.3
	_atualizar_ceu()
	mundo.atualizar(mundo.ponto_estrada(zb, 0))
	await get_tree().process_frame
	var n0: Node3D = mundo.get_node("Chunk_%d" % int(floor(zb / WorldGen.TAM)))
	var r := RandomNumberGenerator.new()
	r.seed = 9
	Apocalipse._barricada_quarentena(n0, mundo, zb, r)
	var pa := Apocalipse._pt(mundo, zb - 14.0, 0.5)
	Apocalipse._sacos_corpos(n0, pa[0], pa[1], r)
	var pb := Apocalipse._pt(mundo, zb - 24.0, 7.0)
	Apocalipse._carro_queimado(n0, pb[0], pb[1] + 0.5, r)
	var pm := Apocalipse._pt(mundo, zb - 32.0, -0.5)
	Apocalipse._mensagem_asfalto(n0, pm[0], pm[1], "NÃO PARE", r)
	var pv := Apocalipse._pt(mundo, zb - 20.0, -6.5)
	Apocalipse._veiculo_oficial(n0, pv[0], pv[1] + 0.2, r)
	for i in 3:
		var pz := mundo.ponto_estrada(zb - 10.0 - i * 6.0, r.randf_range(-3, 3))
		_zumbi_posado(pz, pz + Vector3(0, 0, -5), "comum", 300 + i, r.randf() * 5.0)
	var de4 := mundo.ponto_estrada(zb - 44.0, -1.0) + Vector3(0, 4.5, 0)
	cam.fov = 58.0
	cam.look_at_from_position(de4, mundo.ponto_estrada(zb - 8.0, 0.0) + Vector3(0, 0.5, 0), Vector3.UP)
	await _salvar("101_estrada_do_apocalipse")
	# 102 — caça na mata da serra: mirando o rifle num veado
	var ri := _achar_regiao("serra")
	var zs := mundo.reg.inicio(ri) + 2600.0
	var pf := Vector3.ZERO
	for t in 60:
		var q := mundo.ponto_estrada(zs + t * 40.0, -60.0)
		if mundo.floresta(q.x, q.z) > 0.6 and mundo.agua_em(q.x, q.z) < mundo.altura(q.x, q.z):
			pf = q
			zs = zs + t * 40.0
			break
	hora = 15.6
	_atualizar_ceu()
	mundo.atualizar(pf)
	await get_tree().process_frame
	_limpar_zumbis_perto(pf, 40.0)
	estoque.rifle = 1
	estoque.municao_rifle = 9
	equip.pentes["rifle"] = 5
	jogador.corpo.arma = "rifle"
	jogador.corpo.construir()
	equip.sel = "rifle"
	var dirv := Vector3(1, 0, 0.3).normalized()
	var alvo_v := pf + dirv * 9.0
	_abrir_vista(pf, alvo_v)
	_abrir_vista(pf + Vector3(0, 0, 0.1), alvo_v + Vector3(4, 0, 2))
	var vv: Array = []
	for i in 3:
		var an := Animal.new()
		an.tipo = "veado"
		an.mundo = mundo
		an.semente = 40 + i
		add_child(an)
		var qa := alvo_v + Vector3(i * 2.5, 0, i * 1.8 - 1.5)
		qa.y = mundo.altura(qa.x, qa.z)
		an.global_position = qa
		an.rotation.y = 2.4 + i * 0.4
		an._animar(0.0, 0.5)
		vv.append(an)
	_posar_jogador(pf, alvo_v + Vector3(0, 0.9, 0), -0.04, 0.0)
	jogador.mirando = true
	jogador.zoom = 26.0
	jogador.agachado = true
	jogador._process(0.016)
	jogador.camera.fov = 30.0
	jogador.camera.position = Vector3(-0.6, 0.12, -1.7)
	hud.visible = true
	_atualizar_hud()
	hud.dica = ""
	await _salvar("102_cacando_veado")
	# 103 — javali atacando
	var jv := Animal.new()
	jv.tipo = "javali"
	jv.mundo = mundo
	jv.semente = 9
	add_child(jv)
	var qj := pf + Vector3(-3.5, 0, 2.0)
	qj.y = mundo.altura(qj.x, qj.z)
	jv.global_position = qj
	jv.rotation.y = atan2(pf.x - qj.x, pf.z - qj.z)
	jv.estado = Animal.Estado.ATACANDO
	jv._animar(5.0, 0.3)
	jogador.mirando = false
	jogador.agachado = false
	equip.selecionar("espingarda")
	estoque.espingarda = 1
	equip.selecionar("espingarda")
	jogador.corpo.arma = "espingarda"
	jogador.corpo.construir()
	equip.pentes["espingarda"] = 2
	estoque.cartucho = 6
	_posar_jogador(pf, qj + Vector3(0, 0.5, 0), -0.15, 0.35)
	jogador.camera.fov = 55.0
	jogador.camera.position = Vector3(-0.85, 0.25, -3.3)
	jogador.mirando = true
	jogador.zoom = 44.0
	jogador._process(0.016)
	_atualizar_hud()
	hud.aviso("O javali te acertou com as presas!")
	await _salvar("103_javali")
	# 104 — caça abatida: esfolar
	jv.ferir(999.0)
	jv.rotation.z = PI * 0.5
	jv.global_position.y = mundo.altura(qj.x, qj.z) + 0.15
	jogador.mirando = false
	jogador._process(0.016)
	hud.limpar_aviso()
	_posar_jogador(qj + Vector3(1.6, 0, -1.4), qj, -0.35, 0.3)
	_atualizar_hud()
	hud.dica = "[E] Esfolar javali (%s)" % _txt_horas(0.5)
	await _salvar("104_esfolar")
	hud.dica = ""
	# 105 — acampamento: criação de armadura
	var zc := 640.0
	var pc := mundo.ponto_estrada(zc, -11.0)
	pc.y = mundo.altura(pc.x, pc.z)
	var dz := mundo.direcao(zc)
	var of := _novo_reboque("oficina", 2, 0.85)
	comboio.engatar(of, true)
	comboio.posicionar_livre(pc, atan2(dz.x, dz.z), 0.03)
	hora = 18.2
	_atualizar_ceu()
	mundo.atualizar(pc)
	_limpar_zumbis_perto(pc, 60.0)
	jogador.position = trailer.global_position - trailer.global_transform.basis.x * 3.0
	_alternar_acampamento()
	estoque.pele = 3
	estoque.couro = 5
	estoque.cordame = 2
	estoque.chapa = 2
	estoque.sucata = 26
	estoque.calca_couro = 1
	equip.armadura = {"torso": {"id": "colete_couro", "reforco": 2, "condicao": 0.85}, "cabeca": {"id": "capuz_couro", "reforco": 1, "condicao": 1.0}, "bracos": {"id": "bracadeiras", "reforco": 0, "condicao": 0.7}}
	jogador.atualizar_armadura(equip.armadura)
	_posar_jogador(trailer.global_position - trailer.global_transform.basis.x * 3.2 + trailer.global_transform.basis.z * 1.0, trailer.global_position + Vector3(0, 1.0, 0), -0.1, 0.3)
	criacao.aba = "couro"
	_atualizar_hud()
	_abrir_painel(criacao.painel)
	await _salvar("105_criacao_couro")
	criacao.aba = "metal"
	painel.atualizar()
	await _salvar("106_forja_metal")
	_fechar_janela()
	# 107 — o sobrevivente de armadura reforçada e espingarda, de frente
	equip.selecionar("espingarda")
	jogador.corpo.arma = "espingarda"
	jogador.corpo.construir()
	jogador.atualizar_armadura(equip.armadura)
	jogador.visible = true
	jogador.corpo.rotation.y = jogador.yaw + PI
	jogador.corpo.pose_caminhada(0.0, 0.0)
	hud.visible = false
	var fj := jogador.global_position
	var fr := Vector3(sin(jogador.corpo.rotation.y), 0, cos(jogador.corpo.rotation.y))
	cam.fov = 40.0
	cam.look_at_from_position(fj + fr * 3.4 + Vector3(0.6, 1.5, 0), fj + Vector3(0, 1.1, 0), Vector3.UP)
	cam.current = true
	await _salvar("107_armadura_reforcada")
	# 108 — molotov queimando zumbis na estrada
	hora = 19.6
	_atualizar_ceu()
	var pm2 := mundo.ponto_estrada(zc + 30.0, 0.5)
	for i in 4:
		var qz := pm2 + Vector3(r.randf_range(-2, 2), 0, r.randf_range(-2, 2))
		_zumbi_posado(qz, comboio.pos, ["comum", "corredor", "comum", "brutamonte"][i], 600 + i, r.randf() * 5.0, true)
	var mv := Arremesso.new()
	mv.main = self
	mv.tipo = "molotov"
	add_child(mv)
	mv.global_position = pm2 + Vector3(0, 0.1, 0)
	mv._cair()
	_posar_jogador(pm2 - mundo.direcao(zc) * 11.0 + Vector3(1.5, 0, 0), pm2 + Vector3(0, 1.0, 0), -0.08, 0.2)
	equip.selecionar("molotov")
	estoque.molotov = 2
	hud.visible = true
	_atualizar_hud()
	await _salvar("108_molotov")
	get_tree().quit()

## Prints da etapa 4: assentamento, líder, preparação, ondas, brecha e vitória.
## Prints da etapa 11: HUD com sono e doenças, despensa com comida quente, criação (cozinha) e cochilo ao volante.
func _capturar_saude() -> void:
	comboio.set_physics_process(false)
	hora = 17.0
	_atualizar_ceu()
	var pc := mundo.ponto_estrada(620.0, -11.0)
	pc.y = mundo.altura(pc.x, pc.z)
	var dz := mundo.direcao(620.0)
	comboio.posicionar_livre(pc, atan2(dz.x, dz.z), 0.0)
	mundo.atualizar(pc)
	await get_tree().process_frame
	_limpar_zumbis_perto(pc, 60.0)
	estoque.merge({"po_cafe": 2, "agua": 8, "comida": 9, "carne_crua": 4, "sopa": 2, "ensopado": 1, "cafe": 1, "antibiotico": 1, "bandagem": 2}, true)
	saude.cansaco = 0.72
	saude.pegar("gripe", 30.0, false)
	saude.pegar("ferida", 4.0, false)
	jogador.vida = 0.62
	_alternar_acampamento()
	var pj := trailer.global_transform * Vector3(-3.2, 0, 0.8)
	_posar_jogador(pj, trailer.global_transform * Vector3(-1.0, 1.0, 0.0), -0.15, 0.2)
	jogador.camera.current = true
	hud.visible = true
	saude.atualizar(0.01)
	_atualizar_hud()
	await _salvar("saude_hud")
	_compartimento_preso = true
	_abrir_painel(_painel_compartimento.bind("despensa"))
	await _salvar("saude_despensa")
	_fechar_janela()
	_compartimento_preso = false
	criacao.aba = "sobrevivencia"
	_abrir_painel(criacao.painel)
	await _salvar("saude_cozinha")
	_fechar_janela()
	# cochilo ao volante
	_entrar_no_carro()
	saude.cansaco = 0.95
	saude.atualizar(0.0)
	_atualizar_hud()
	hud.cochilo = 0.5
	hud.aviso("Você cochilou ao volante!")
	await _salvar("saude_cochilo")
	get_tree().quit()

## Prints da etapa 10: setor com fosso, arame e estacas; painel do setor; o chefe chegando à noite.
func _capturar_defesa2() -> void:
	comboio.set_physics_process(false)
	var cam := Camera3D.new()
	cam.far = 2500.0
	cam.near = 0.05
	add_child(cam)
	hud.visible = false
	jogador.visible = false
	estoque.merge({"sucata": 300, "pecas": 80, "cordame": 12, "comida": 60, "agua": 60, "galoes_diesel": 3}, true)
	var l := {}
	for ll in mundo.lugares_da_regiao(0):
		if ll.tipo == "assentamento":
			l = ll
	var id: String = l.id
	defesa.z_horda = float(l.pos.z) - 3600.0
	jogador.position = l.pos
	mundo.atualizar(l.pos)
	await get_tree().process_frame
	var a := defesa.no_de(id)
	var e: Dictionary = defesa.obter(id)
	_limpar_zumbis_perto(a.global_position, 90.0)
	defesa.ficar(id)
	var sh := defesa.setor_da_horda(id)
	for obra in ["fosso", "arame", "armadilha", "armadilha", "torre", "holofote"]:
		defesa.construir(id, obra, sh)
	defesa.construir(id, "chapas")
	hora = 16.0
	_atualizar_ceu()
	a.redesenhar()
	await get_tree().process_frame
	var R := Assentamento.R
	var ang: float = sh * PI * 0.5
	var fora := a.global_de(Vector3(sin(ang + 0.35), 0, cos(ang + 0.35)) * (R + 16.0)) + Vector3(0, 9.0, 0)
	var alvo := a.global_de(Vector3(sin(ang), 0, cos(ang)) * (R + 3.0))
	_abrir_vista(fora, alvo)
	cam.fov = 55.0
	cam.look_at_from_position(fora, alvo, Vector3.UP)
	cam.current = true
	await _salvar("defesa_setor")
	# painel do setor
	hud.visible = true
	_posar_jogador(a.global_de(Vector3(1.5, 0, -2.0)), a.global_position, -0.1, 0.4)
	_atualizar_hud()
	_lider_aberto = [id, e.lider]
	_abrir_painel(_painel_setor.bind(id, sh))
	await _salvar("defesa_painel_setor")
	_fechar_janela()
	_abrir_painel(_painel_lider_atual)
	await _salvar("defesa_painel_lider")
	_fechar_janela()
	hud.visible = false
	jogador.visible = false
	# o chefe, ao anoitecer, chegando pelo fosso
	hora = 18.9
	_atualizar_ceu()
	e.ondas = 2
	e.fase = "entre_ondas"
	defesa.iniciar_onda(id)
	var cp0: Vector3 = a.global_de(Vector3(sin(ang), 0, cos(ang)) * (R + 7.0))
	cp0.y = mundo.altura(cp0.x, cp0.z)
	var chz := mundo.criar_zumbi(mundo, cp0, 0.0, 4242, "colosso")
	chz.cerco = a
	defesa.onda.chefe_no = chz
	defesa.onda.vivos.append(chz)
	for i in 12:
		var q0: Vector3 = a.global_de(Vector3(sin(ang + randf_range(-0.5, 0.5)), 0, cos(ang + randf_range(-0.5, 0.5))) * (R + randf_range(4.0, 14.0)))
		q0.y = mundo.altura(q0.x, q0.z)
		var zz := mundo.criar_zumbi(mundo, q0, 0.0, 5000 + i)
		defesa.onda.vivos.append(zz)
	await get_tree().process_frame
	var ch: Variant = defesa.onda.chefe_no
	if ch and is_instance_valid(ch):
		var cp: Vector3 = a.global_de(Vector3(sin(ang), 0, cos(ang)) * (R + 7.0))
		cp.y = mundo.altura(cp.x, cp.z)
		ch.global_position = cp
		ch.rotation.y = a.global_rotation.y + ang + PI
		for z in defesa.onda.vivos:
			if is_instance_valid(z) and z != ch:
				var q: Vector3 = a.global_de(Vector3(sin(ang + randf_range(-0.4, 0.4)), 0, cos(ang + randf_range(-0.4, 0.4))) * (R + randf_range(4.0, 12.0)))
				q.y = mundo.altura(q.x, q.z)
				z.global_position = q
		for z in defesa.onda.vivos:
			if is_instance_valid(z):
				z.set_process(false)
		var de := a.global_de(Vector3(sin(ang - 0.12), 0, cos(ang - 0.12)) * (R + 1.5)) + Vector3(0, 3.2, 0)
		cam.look_at_from_position(de, cp + Vector3(0, 2.0, 0), Vector3.UP)
		cam.current = true
		hud.visible = true
		_atualizar_hud()
		await _salvar("defesa_chefe")
	defesa.abortar()
	get_tree().quit()

func _capturar_defesa() -> void:
	comboio.set_physics_process(false)
	mundo.mat_capim.set_shader_parameter("tempo", 1.3)
	var cam := Camera3D.new()
	cam.far = 2500.0
	cam.near = 0.05
	add_child(cam)
	hud.visible = false
	for t in [["apartamentos", 2, 0.85], ["oficina", 2, 0.8]]:
		comboio.engatar(_novo_reboque(t[0], t[1], t[2]), true)
	var nomes := [["Tião", "vigia"], ["Marta", "medico"], ["Pedrão", "mecanico"], ["Dinho", "batedor"]]
	for i in nomes.size():
		var rc := Recrutas.novo(nomes[i][0], nomes[i][1], 7000 + i * 13)
		base.lista.append(rc)
	base.distribuir_camas()
	estoque.sucata = 30
	estoque.pecas = 10
	estoque.comida = 4
	estoque.agua = 3
	estoque.galoes_diesel = 2
	var l := {}
	for ll in mundo.lugares_da_regiao(0):
		if ll.tipo == "assentamento":
			l = ll
	var id: String = l.id
	defesa.z_horda = float(l.pos.z) - 3600.0
	jogador.position = l.pos
	mundo.atualizar(l.pos)
	await get_tree().process_frame
	var a := defesa.no_de(id)
	var e: Dictionary = defesa.obter(id)
	var R := Assentamento.R
	var yaw_a := a.global_rotation.y
	_limpar_zumbis_perto(a.global_position, 90.0)
	# comboio chegando pela estrada de terra, de frente para o portão
	var pc := a.global_de(Vector3(-1.0, 0, R + 17.0))
	pc.y = mundo.altura(pc.x, pc.z)
	comboio.posicionar_livre(pc, yaw_a + PI, 0.0)

	# 88 — chegando ao assentamento
	hora = 16.4
	_atualizar_ceu()
	jogador.visible = false
	var de := a.global_de(Vector3(9.0, 4.2, R + 34.0))
	_abrir_vista(de, a.global_position)
	cam.fov = 55.0
	cam.look_at_from_position(de, a.global_de(Vector3(0, 2.6, R - 2.0)), Vector3.UP)
	cam.current = true
	await _salvar("88_chegando_assentamento")

	# 89 — do alto
	var de2 := a.global_de(Vector3(34.0, 48.0, 62.0))
	_abrir_vista(de2, a.global_position)
	cam.fov = 50.0
	cam.look_at_from_position(de2, a.global_de(Vector3(0, 0, -2.0)), Vector3.UP)
	await _salvar("89_assentamento_do_alto")

	# 90 — conversa com o líder: ficar ou seguir
	var lider: Node3D = null
	for h in mundo.npcs:
		if is_instance_valid(h) and h.get_meta("funcao", "") == "lider":
			lider = h
	hud.visible = true
	if lider:
		var fr := lider.global_transform.basis.z
		_posar_jogador(lider.global_position + fr * 2.4 + lider.global_transform.basis.x * 0.7, lider.global_position + Vector3(0, 1.2, 0), -0.08, 0.25)
		_atualizar_hud()
		_abrir_painel(_painel_npc.bind(lider))
		await _salvar("90_lider_ficar_ou_seguir")
		_fechar_janela()

	# 91 — ficou: preparando, com parte das obras feitas
	defesa.ficar(id)
	e.chapas = true
	e.torres[1] = true
	e.torres[2] = true
	e.holofotes[0] = true
	e.holofotes[2] = true
	var atras_l := a.local_de(a.global_position + Vector3(0, 0, -50.0))
	var setor_horda := Assentamento.setor(atras_l)
	e.armadilhas[setor_horda] = 12
	for i in Assentamento.N:
		e.muro[i] = a.hp_max(i)
	e.estoque.sucata = 18
	e.estoque.pecas = 4
	a.redesenhar()
	defesa.z_horda = float(e.pos.z) - 250.0 - defesa.velocidade_horda() * 5.4
	hora = 17.6
	_atualizar_ceu()
	if lider:
		_atualizar_hud()
		_abrir_painel(_painel_npc.bind(lider))
		await _salvar("91_preparando_defesa")
		_fechar_janela()

	# 92 — muralha pronta, comboio estacionado no portão, entardecer
	hora = 18.5
	_atualizar_ceu()
	var pg := a.global_de(Vector3(9.5, 0, R + 4.0))
	pg.y = mundo.altura(pg.x, pg.z)
	comboio.posicionar_livre(pg, yaw_a - PI * 0.5, 0.0)
	jogador.visible = false
	hud.visible = false
	var de3 := a.global_de(Vector3(-46.0, 34.0, 44.0))
	_abrir_vista(de3, a.global_position)
	cam.fov = 52.0
	cam.look_at_from_position(de3, a.global_de(Vector3(4.0, 0, 6.0)), Vector3.UP)
	cam.current = true
	await _salvar("92_muralha_pronta")

	# 93 — onda 1 chegando: vista de cima da torre do lado da horda
	hora = 19.0
	_atualizar_ceu()
	jogador.position = a.global_de(Vector3(0, 0, 4.0))
	defesa.iniciar_onda(id)
	var ang_h: float = defesa.onda.ang
	var zs: Array = []
	var r := RandomNumberGenerator.new()
	r.seed = 404
	for i in 26:
		var an := ang_h + r.randf_range(-0.55, 0.55)
		var rr := R + r.randf_range(6.0, 30.0)
		var q := a.global_de(Vector3(sin(an) * rr, 0, cos(an) * rr))
		var alvo := a.global_de(Vector3(sin(an) * R, 0, cos(an) * R))
		var tipo: String = ["comum", "comum", "comum", "corredor", "comum", "brutamonte", "comum", "rastejante"][i % 8]
		var z := _zumbi_posado(q, alvo, tipo, 900 + i, r.randf() * 6.0, tipo == "corredor" or r.randf() < 0.3)
		z.cerco = a
		zs.append(z)
	var torre_h := 0
	var melhor := 9.0
	for k in 4:
		if e.torres[k]:
			var dd := absf(wrapf(Assentamento.ANG_TORRES[k] - ang_h, -PI, PI))
			if dd < melhor:
				melhor = dd
				torre_h = k
	for n in defesa.nos:
		n.pose_caminhada(0.0, 0.0)
		if n.fixo:
			n.rotation.y = yaw_a + ang_h
			n.pose_mirar(1.0)
	var tp := a.torre_pos(torre_h)
	var para_fora := (a.global_de(Vector3(sin(ang_h), 0, cos(ang_h)) * (R + 18.0)) - tp)
	para_fora.y = 0.0
	var lado_v := para_fora.normalized().cross(Vector3.UP)
	var de4 := tp - para_fora.normalized() * 7.0 + lado_v * 4.5 + Vector3(0, 2.2, 0)
	cam.fov = 60.0
	cam.look_at_from_position(de4, tp + para_fora * 0.75 - Vector3(0, 3.6, 0), Vector3.UP)
	cam.current = true
	hud.visible = true
	_atualizar_hud()
	await _salvar("93_onda_chegando")

	# 94 — noite: holofotes, tiros, zumbis batendo no muro
	hud.limpar_banner()
	hora = 19.75
	_atualizar_ceu()
	e.torres[3] = true
	e.holofotes[3] = true
	a.ligar_holofotes(true)
	var i_h := Assentamento.indice_em(Vector3(sin(ang_h), 0, cos(ang_h)))
	for s2 in [-1, 0, 1, 2]:
		var j2 := posmod(i_h + s2, Assentamento.N)
		e.muro[j2] = a.hp_max(j2) * [0.55, 0.3, 0.6, 0.8][s2 + 1]
	a.redesenhar()
	for k2 in zs.size():
		var z: Zumbi = zs[k2]
		var an2 := ang_h + (k2 - zs.size() * 0.5) * 0.045
		var rr2 := R + 0.85 + (k2 % 3) * 0.7 + r.randf_range(0.0, 1.5) * float(k2 % 5 == 0) * 4.0
		var q2 := a.global_de(Vector3(sin(an2) * rr2, 0, cos(an2) * rr2))
		q2.y = jogador.chao(q2)
		z.global_position = q2
		z.rotation.y = yaw_a + an2 + PI
		z._anim_ataque = r.randf_range(0.2, 0.9)
		z._fase = r.randf() * 6.0
		z._animar(0.3)
	for n in defesa.nos:
		if n.fixo:
			n.pose_mirar(1.0)
			n._flash.visible = r.randf() < 0.6
	defesa.onda.fila = 0
	defesa.onda.vivos = zs
	var de5 := a.global_de(Vector3(sin(ang_h - 0.75) * (R + 15.0), 9.0, cos(ang_h - 0.75) * (R + 15.0)))
	_abrir_vista(de5, a.global_position)
	cam.fov = 58.0
	cam.look_at_from_position(de5, a.global_de(Vector3(sin(ang_h) * R, 1.5, cos(ang_h) * R)), Vector3.UP)
	cam.current = true
	jogador.visible = false
	_atualizar_hud()
	hud.limpar_aviso()
	await _salvar("94_ataque_noturno")

	# 95 — brecha: o muro cede e o jogador segura lá dentro
	hora = 19.85
	_atualizar_ceu()
	a.ligar_holofotes(true)
	e.muro[i_h] = 0.0
	a.redesenhar()
	hud.aviso("O muro %s caiu! Tapem a brecha!" % Defesa.NOMES_SETOR[Assentamento.setor(Assentamento.ponto(i_h, 1.0))])
	var dentro_zs: Array = []
	for k3 in 6:
		var z: Zumbi = zs[k3]
		var off := (k3 - 2.5) * 0.9
		var l3 := Assentamento.ponto(i_h + off * 0.04, R - 1.5 - k3 * 1.1)
		var q3 := a.global_de(l3)
		q3.y = jogador.chao(q3)
		z.global_position = q3
		z.rotation.y = yaw_a + Assentamento.ang(i_h) + PI
		z._fase = r.randf() * 6.0
		z._animar(3.0)
		dentro_zs.append(z)
	defesa.onda.dentro = 6
	defesa.onda.resistencia = 0.72
	var pj := a.global_de(Assentamento.ponto(i_h - 0.25, R - 10.5))
	_posar_jogador(pj, dentro_zs[3].global_position + Vector3(0, 1.0, 0), -0.12, 0.2)
	jogador.corpo.rotation.y = jogador.yaw
	jogador._t_golpe = 0.45
	jogador._process(0.0)
	for n in defesa.nos:
		if n.dados.funcao == "batedor" or n.dados.funcao == "agricultor":
			var q4 = pj + (dentro_zs[1].global_position - pj) * 0.6 + Vector3(1.5, 0, 0)
			q4.y = jogador.chao(q4)
			n.global_position = q4
			n.rotation.y = atan2(dentro_zs[1].global_position.x - q4.x, dentro_zs[1].global_position.z - q4.z)
			n.pose_caminhada(1.0, 0.8)
			n.ombro_d.rotation.x = -2.5
			break
	_atualizar_hud()
	await _salvar("95_brecha_no_muro")

	# 96 — vitória
	hud.limpar_banner()
	hora = 6.3
	_atualizar_ceu()
	for z in zs:
		if is_instance_valid(z):
			z.morrer()
			z.visible = false
	defesa.onda.vivos = []
	defesa.onda.fila = 0
	defesa._vitoria(e, a)
	e.muro[i_h] = 0.0
	a.redesenhar()
	var pj2 := a.global_de(Assentamento.ponto(i_h + 0.35, R - 6.0))
	_posar_jogador(pj2, a.global_de(Assentamento.ponto(i_h, R + 2.0)) + Vector3(0, 0.8, 0), -0.2, 0.3)
	hud.limpar_aviso()
	hud.limpar_banner()
	_atualizar_hud()
	await _salvar("96_onda_vencida")

	# 97 — de volta à estrada: a horda no mapa
	hora = 9.5
	_atualizar_ceu()
	hud.relatorio_t = 0.0
	hud.limpar_banner()
	conhecidos[id] = {"id": id, "nome": e.nome, "tipo": "assentamento", "pos": e.pos, "regiao": 0}
	for lv in mundo.lugares_da_regiao(0):
		if lv.tipo in ["vila", "fazenda"] and float(lv.pos.z) < float(e.pos.z) + 3500.0:
			conhecidos[lv.id] = {"id": lv.id, "nome": lv.nome, "tipo": lv.tipo, "pos": lv.pos, "regiao": 0}
	var zr := float(e.pos.z) + 1500.0
	defesa.z_horda = zr - 6200.0
	var pr := mundo.ponto_estrada(zr, -4.0)
	pr.y = mundo.altura(pr.x, pr.z)
	var dzr := mundo.direcao(zr)
	comboio.posicionar_livre(pr, atan2(dzr.x, dzr.z), 0.0)
	mundo.atualizar(pr)
	_limpar_zumbis_perto(pr, 60.0)
	_posar_jogador(trailer.global_position - trailer.global_transform.basis.x * 2.6 - trailer.global_transform.basis.z * 2.0, trailer.global_position + trailer.global_transform.basis.z * 6.0 + Vector3(0, 1.0, 0), -0.05, 0.3)
	_atualizar_hud()
	_abrir_painel(_painel_mapa)
	await _salvar("97_mapa_horda")
	_fechar_janela()
	get_tree().quit()

func _capturar() -> void:
	comboio.set_physics_process(false)
	mundo.mat_capim.set_shader_parameter("tempo", 1.3)
	var cam := Camera3D.new()
	cam.far = 2500.0
	cam.near = 0.05
	add_child(cam)
	trailer.cozinha_aberta = 0.0
	trailer.reconstruir()
	hud.visible = false

	# 62 / 63 — floresta densa na serra: do alto e por dentro
	var ri := _achar_regiao("serra")
	var zs := mundo.reg.inicio(ri) + 2500.0
	hora = 15.6
	var achou := false
	for tent in 40:
		var zz := zs + tent * 120.0
		for lat in [40.0, -40.0, 70.0, -70.0]:
			var q := mundo.ponto_estrada(zz, lat)
			if mundo.floresta(q.x, q.z) > 0.8:
				zs = zz
				achou = true
				break
		if achou:
			break
	mundo.atualizar(mundo.ponto_estrada(zs, 0.0))
	_regiao_atual = ri
	_atualizar_ceu()
	var pr0 := mundo.ponto_estrada(zs, 0.0)
	cam.fov = 55.0
	cam.look_at_from_position(pr0 + Vector3(-60.0, 45.0, -70.0), pr0 + Vector3(25.0, 0, 20.0), Vector3.UP)
	cam.current = true
	await _salvar("62_floresta_do_alto")
	var dentro_mata := Vector3.ZERO
	for lat in [40.0, -40.0, 60.0, -60.0, 80.0, -80.0, 100.0, -100.0]:
		var q := mundo.ponto_estrada(zs, lat)
		if mundo.floresta(q.x, q.z) > 0.85:
			dentro_mata = q
			break
	if dentro_mata != Vector3.ZERO:
		hud.visible = true
		_posar_jogador(dentro_mata, dentro_mata + Vector3(8.0, 0, 6.0), -0.05, 0.2)
		_limpar_zumbis_perto(dentro_mata, 10.0)
		hud._banner_t = 0.0
		hud.objetivo = "Explore a mata"
		hud.subobjetivo = "Cabanas, acampamentos e torres"
		_atualizar_hud()
		await _salvar("63_dentro_da_floresta")
		hud.visible = false

	# 64..68 — lugares escondidos na mata
	var n := 64
	for tipo in ["cabana", "acampamento", "torre", "serraria", "carro_mata"]:
		var l := {}
		for rr in 30:
			for lg in mundo.lugares_da_regiao(rr):
				if lg.tipo == tipo and mundo.agua_em(lg.pos.x, lg.pos.z) < mundo.altura(lg.pos.x, lg.pos.z) - 0.3 and mundo.floresta(lg.pos.x, lg.pos.z) > 0.2:
					l = lg
					break
			if not l.is_empty():
				break
		if l.is_empty():
			continue
		hora = [16.2, 17.4, 15.8, 16.6, 17.0][n - 64]
		_atualizar_ceu()
		mundo.atualizar(l.pos)
		var c: Vector3 = l.pos
		var dist: float = l.raio + (6.0 if tipo != "torre" else 10.0)
		if tipo == "carro_mata":
			dist = 9.0
		cam.fov = 55.0
		var de := c + Vector3(-dist * 0.8, dist * 0.55 + (6.0 if tipo == "torre" else 0.0), -dist * 0.9)
		var para := c + Vector3(0, 1.5 + (5.0 if tipo == "torre" else 0.0), 0)
		_abrir_vista(de, para)
		cam.look_at_from_position(de, para, Vector3.UP)
		cam.current = true
		await _salvar("%d_%s" % [n, tipo])
		n += 1

	# 69..72 — sobrado na beira da estrada: por fora, em corte, térreo e andar de cima
	var sob := _achar_predio("sobrado", 300.0, 20000.0, 2)
	if sob:
		hora = 16.4
		_atualizar_ceu()
		mundo.atualizar(sob.global_position)
		_regiao_atual = mundo.regiao_em(sob.global_position.z)
		var fr := sob.global_transform.basis.z
		var de0 := sob.global_position + fr * 14.0 + sob.global_transform.basis.x * 7.0 + Vector3(0, 3.0, 0)
		_abrir_vista(de0, sob.global_position)
		cam.fov = 50.0
		cam.look_at_from_position(de0, sob.global_position + Vector3(0, 2.5, 0), Vector3.UP)
		cam.current = true
		await _salvar("69_sobrado")
		await _corte_aereo(cam, sob, 0, "70_sobrado_em_corte")
		hud.visible = true
		hud._banner_t = 0.0
		hud.objetivo = "Vasculhe a casa"
		hud.subobjetivo = "Cada móvel guarda algo diferente"
		_limpar_zumbis_perto(sob.global_position, 12.0)
		_dentro_predio(sob, 0)
		_atualizar_hud()
		_interacao()
		await _salvar("71_sobrado_terreo")
		_dentro_predio(sob, 1, "quarto")
		_atualizar_hud()
		_interacao()
		await _salvar("72_sobrado_andar_de_cima")
		jogador.position.y += 50.0
		jogador._atualizar_predio(0.0)
		sob.corte(-1)
		hud.visible = false

	# 73..75 — prédio de apartamentos na cidade
	var rc := _achar_regiao("cidade")
	var ap := _achar_predio("apto", mundo.reg.inicio(rc) + 400.0, mundo.reg.fim(rc), 3)
	if ap:
		hora = 15.2
		_atualizar_ceu()
		mundo.atualizar(ap.global_position)
		_regiao_atual = rc
		var fr2 := ap.global_transform.basis.z
		jogador.visible = false
		cam.fov = 52.0
		cam.look_at_from_position(ap.global_position + fr2 * 18.0 - ap.global_transform.basis.x * 8.0 + Vector3(0, 4.0, 0), ap.global_position + Vector3(0, ap.andares * 1.5, 0), Vector3.UP)
		cam.current = true
		await _salvar("73_predio")
		await _corte_aereo(cam, ap, ap.andares - 1, "74_predio_ultimo_andar_em_corte")
		hud.visible = true
		hud._banner_t = 0.0
		hud.objetivo = "Suba o prédio"
		hud.subobjetivo = "Andares altos têm mais saque e mais risco"
		_limpar_zumbis_perto(ap.global_position, 14.0)
		_dentro_predio(ap, ap.andares - 1)
		_atualizar_hud()
		_interacao()
		await _salvar("75_predio_ultimo_andar")
		jogador.position.y += 80.0
		jogador._atualizar_predio(0.0)
		ap.corte(-1)
		hud.visible = false

	# 76 — loja por dentro
	var lj := _achar_predio("loja", mundo.reg.inicio(rc) + 300.0, mundo.reg.fim(rc))
	if lj:
		mundo.atualizar(lj.global_position)
		hud.visible = true
		_limpar_zumbis_perto(lj.global_position, 10.0)
		await _corte_aereo(cam, lj, 0, "76_loja_em_corte")
		_dentro_predio(lj, 0, "porta")
		hud.objetivo = "Saqueie a loja"
		hud.subobjetivo = "Prateleiras, caixa e estoque"
		_atualizar_hud()
		_interacao()
		await _salvar("77_loja_por_dentro")
	get_tree().quit()
