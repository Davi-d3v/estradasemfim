class_name Recrutas
## Dados dos recrutas: funções, o que automatizam, o que pedem para entrar no comboio.
## Cada recruta é um Dictionary guardado em main.recrutas (sobrevive a carregar chunks).

const FUNCOES := {
	"mecanico": {"nome": "Mecânico", "fem": "Mecânica", "posto": "oficina",
		"auto": "Fabrica peças sozinho na oficina e conserta o comboio aos poucos",
		"defesa": "Conserta reboques durante o ataque"},
	"agricultor": {"nome": "Agricultor", "fem": "Agricultora", "posto": "estufa",
		"auto": "Estufa rende 50% a mais e a colheita vai direto para o estoque",
		"defesa": "Luta de facão"},
	"vigia": {"nome": "Vigia", "fem": "Vigia", "posto": "perimetro",
		"auto": "Guarda o acampamento à noite: menos ataques e aviso antecipado",
		"defesa": "Atira de longe (barulhento)"},
	"medico": {"nome": "Médico", "fem": "Médica", "posto": "fogueira",
		"auto": "Cura ferimentos e segura a infecção sem gastar remédio",
		"defesa": "Socorre feridos"},
	"batedor": {"nome": "Batedor", "fem": "Batedora", "posto": "apartamentos",
		"auto": "Sai em expedições de saque e volta com recursos (ou não volta)",
		"defesa": "Caça zumbis especiais"},
	"idoso": {"nome": "Seu", "fem": "Dona", "posto": "fogueira",
		"auto": "Ensina os outros (aprendem 25% mais rápido), ajuda na horta e na oficina e conta histórias à noite",
		"defesa": "Fica no trailer recarregando armas"},
	"crianca": {"nome": "Criança", "fem": "Criança", "posto": "apartamentos",
		"auto": "Anima todo mundo e, com o comboio por perto, acha coisas pequenas onde ninguém olha",
		"defesa": "Se esconde no trailer"},
}

const NOMES_CRIANCA := ["Juninho", "Bia", "Tatá", "Pedrinho", "Lili", "Duda", "Caio", "Nina"]
const NOMES_IDOSO := ["Seu Zé", "Dona Benta", "Seu Lauro", "Dona Zica", "Seu Antônio", "Dona Filó"]

const FEMININOS := ["Dona Cida", "Marta", "Joana", "Neide", "Lurdes", "Ana", "Sônia", "Irene"]

## O que cada sobrevivente pede para largar a vila e vir junto.
const PEDIDOS := [
	{"comida": 3, "agua": 3},
	{"remedio": 1},
	{"pecas": 4},
	{"galoes_diesel": 1},
	{"sucata": 15},
	{"comida": 2, "remedio": 1},
]

static func titulo(rc: Dictionary) -> String:
	var f: Dictionary = FUNCOES[rc.funcao]
	if rc.funcao == "idoso":
		return "idosa" if String(rc.nome).begins_with("Dona") else "idoso"
	return f.fem if VidaRecrutas.fem(rc) else f.nome

## Funcão de recruta para um morador de vila (morador vira batedor).
static func funcao_de_npc(funcao_npc: String, h: Node3D = null) -> String:
	if funcao_npc == "morador" and h is Humanoid and (h as Humanoid).visual == "idoso":
		return "idoso"
	return "batedor" if funcao_npc == "morador" else funcao_npc

static func pode_recrutar(h: Node3D) -> bool:
	var ch: String = h.get_meta("chave", "")
	return ch.contains(":p") and FUNCOES.has(funcao_de_npc(h.get_meta("funcao")))

static func pedido_de(h: Node3D) -> Dictionary:
	return PEDIDOS[absi(hash(h.get_meta("chave", ""))) % PEDIDOS.size()]

static func de_npc(h: Humanoid) -> Dictionary:
	return {
		"id": h.get_meta("chave"),
		"nome": h.get_meta("nome"),
		"funcao": funcao_de_npc(h.get_meta("funcao"), h),
		"vida": 1.0,
		"moral": 0.7,
		"semente": h.semente,
		"pele": h.pele, "camisa": h.camisa, "calca": h.calca, "bone": h.com_bone,
		"abates": 0,
		"expedicao": {},
		"fome": 0.0,    # dias sem comer/beber
	}

static func novo(nome: String, funcao: String, sem: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = sem
	return {
		"id": "novo:%d" % sem, "nome": nome, "funcao": funcao, "vida": 1.0, "moral": 0.7, "semente": sem,
		"pele": [Color(0.72, 0.52, 0.4), Color(0.55, 0.38, 0.27), Color(0.38, 0.26, 0.18), Color(0.8, 0.62, 0.5)][r.randi() % 4],
		"camisa": Color.from_hsv(r.randf(), r.randf_range(0.2, 0.55), r.randf_range(0.25, 0.55)),
		"calca": Color.from_hsv(r.randf_range(0.55, 0.65), r.randf_range(0.2, 0.4), r.randf_range(0.15, 0.35)),
		"bone": r.randf() < 0.4, "abates": 0, "expedicao": {}, "fome": 0.0,
	}

static func txt_moral(m: float) -> String:
	if m > 0.75:
		return "animado"
	if m > 0.5:
		return "firme"
	if m > 0.3:
		return "abatido"
	return "pensando em ir embora"

static func txt_vida(v: float) -> String:
	if v > 0.8:
		return "saudável"
	if v > 0.5:
		return "machucado"
	if v > 0.25:
		return "ferido"
	return "muito ferido"
