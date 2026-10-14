class_name Trailer
extends Node3D
## Trailer de expedição modular. Frente (engate) aponta para +Z.
## Cada slot recebe um módulo com nível (1..3) e condição (0..1).

const COMPRIMENTO := 3.6
const LARGURA := 1.76
const BASE_Y := 0.75
const TOPO_Y := 2.05

## Catálogo de módulos: id -> dados fixos.
const MODULOS := {
	"cozinha": {"nome": "Cozinha deslizante", "slot": "lateral_esquerda", "nivel_max": 3, "peso": 45.0},
	"despensa": {"nome": "Despensa externa", "slot": "lateral_direita", "nivel_max": 3, "peso": 25.0},
	"rack_teto": {"nome": "Rack de teto", "slot": "teto", "nivel_max": 3, "peso": 35.0},
	"barraca": {"nome": "Barraca de teto", "slot": "teto_carga", "nivel_max": 2, "peso": 55.0},
	"galoes": {"nome": "Suporte de galões", "slot": "frente", "nivel_max": 3, "peso": 20.0},
	"estepes": {"nome": "Suporte de estepes", "slot": "traseira", "nivel_max": 2, "peso": 30.0},
	"grades": {"nome": "Grades de proteção", "slot": "janelas", "nivel_max": 2, "peso": 18.0},
	"farois": {"nome": "Faróis auxiliares", "slot": "iluminacao", "nivel_max": 3, "peso": 6.0},
	"antena": {"nome": "Rádio e antena", "slot": "comunicacao", "nivel_max": 2, "peso": 4.0},
	"botijao": {"nome": "Botijão de gás", "slot": "lanca", "nivel_max": 2, "peso": 22.0},
	"couraca": {"nome": "Couraça (chapas e espinhos)", "slot": "couraca", "nivel_max": 2, "peso": 120.0},
}

@export var cor_pintura := Color(0.66, 0.33, 0.12)
@export var condicao_carroceria := 0.65
@export var cozinha_aberta := 1.0  # 0 fechada .. 1 aberta
@export var despensa_aberta := true
## Compartimentos externos que funcionam como inventário: id -> aberto?
var compartimentos_abertos := {"despensa": false, "ferramentas": false, "bagageiro": false}

## Compartimentos de carga do trailer: nome, o que guardam, capacidade por nível e onde ficam.
const COMPARTIMENTOS := {
	"despensa": {"nome": "Despensa externa", "slot": "lateral_direita", "cap": [6, 10, 16, 22],
		"itens": ["comida", "agua", "carne_crua", "carne_assada", "remedio", "bandagem", "analgesico"]},
	"ferramentas": {"nome": "Caixa de ferramentas", "slot": "", "cap": [12, 12, 12, 12],
		"itens": ["pecas", "sucata", "chapa", "cordame", "pneu", "eixo", "galoes_diesel"]},
	"bagageiro": {"nome": "Bagageiro lateral", "slot": "", "cap": [14, 14, 14, 14],
		"itens": []},   # vazio = o que não cabe nos outros (armas, munição, couro, roupas...)
}
@export var luz_interna := true
## Câmera do jogador dentro do trailer: vidros ficam transparentes.
var modo_interior := false
## Luz interna vermelha (enxerga sem chamar atenção de fora).
var luz_vermelha := false

# ---------------------------------------------------------------- engate (interface comum a todos os rebocados)
func engate_frente_z() -> float:
	return COMPRIMENTO * 0.5 + 1.8

func eixo_z() -> float:
	return -0.2

func comprimento() -> float:
	return COMPRIMENTO

func engate_tras() -> Vector3:
	return Vector3(0, 0.6, -COMPRIMENTO * 0.5 - 0.55)

func nome_exibicao() -> String:
	return "Trailer"

func funcional() -> bool:
	return true

## Espaço de carga extra na despensa externa.
func capacidade_carga() -> int:
	var t := 0
	for id in COMPARTIMENTOS:
		t += capacidade_compartimento(id)
	return t

func capacidade_compartimento(id: String) -> int:
	var c: Dictionary = COMPARTIMENTOS[id]
	var nivel := 1
	if c.slot != "":
		nivel = int(config.get(c.slot, {}).get("nivel", 0))
	return int(c.cap[clampi(nivel, 0, 3)])

## Em que compartimento um item fica guardado.
static func compartimento_de(item: String) -> String:
	for id in ["despensa", "ferramentas"]:
		if item in COMPARTIMENTOS[id].itens:
			return id
	return "bagageiro"

## Onde o jogador fica para abrir cada compartimento (espaço local do trailer).
func ponto_compartimento(id: String) -> Vector3:
	match id:
		"despensa":
			return Vector3(LARGURA * 0.5 + 0.7, 0, -1.05)
		"ferramentas":
			return Vector3(0.0, 0, COMPRIMENTO * 0.5 + 1.15)
	return Vector3(-LARGURA * 0.5 - 0.7, 0, 1.1)

func abrir_compartimento(id: String, aberto: bool) -> void:
	if compartimentos_abertos.get(id, false) == aberto:
		return
	compartimentos_abertos[id] = aberto
	reconstruir()

func ponto_entrada() -> Vector3:
	return Vector3(LARGURA * 0.5 + 0.7, 0, 0.35)

## Dados para andar em primeira pessoa aqui dentro (agachado: o trailer é baixo).
func interior() -> Dictionary:
	var hw := LARGURA * 0.5
	return {
		"limites": AABB(Vector3(-0.68, 0, 0.25), Vector3(1.36, 0, 0.7)),
		"piso": BASE_Y + 0.055,
		"olho": 0.92,
		"inicio": Vector3(0.45, 0, 0.5),
		"yaw": -PI * 0.5,
		"interativos": [
			{"id": "dormir", "nome": "Dormir", "pos": Vector3(0, 1.32, -0.55)},
			{"id": "radio", "nome": "Ouvir o rádio", "pos": Vector3(-0.42, 1.48, 1.12)},
			{"id": "luz", "nome": "Trocar a luz (normal / vermelha)", "pos": Vector3(0.35, 1.53, 1.1)},
			{"id": "despensa", "nome": "Despensa: comer e beber", "pos": Vector3(0.38, 1.1, 0.96)},
			{"id": "mapa", "nome": "Ver anotações no mapa", "pos": Vector3(hw - 0.03, 1.28, -0.35)},
			{"id": "sair", "nome": "Sair do trailer", "pos": Vector3(hw - 0.03, 1.35, 0.55)},
		],
	}

## slot -> {"id": String, "nivel": int, "condicao": float}
var config := {
	"lateral_esquerda": {"id": "cozinha", "nivel": 3, "condicao": 0.8},
	"lateral_direita": {"id": "despensa", "nivel": 2, "condicao": 0.7},
	"teto": {"id": "rack_teto", "nivel": 3, "condicao": 0.6},
	"teto_carga": {"id": "barraca", "nivel": 1, "condicao": 0.7},
	"frente": {"id": "galoes", "nivel": 3, "condicao": 0.75},
	"traseira": {"id": "estepes", "nivel": 2, "condicao": 0.7},
	"janelas": {"id": "grades", "nivel": 2, "condicao": 0.6},
	"iluminacao": {"id": "farois", "nivel": 2, "condicao": 0.9},
	"comunicacao": {"id": "antena", "nivel": 1, "condicao": 0.9},
	"lanca": {"id": "botijao", "nivel": 1, "condicao": 0.8},
	"couraca": {"id": "couraca", "nivel": 0, "condicao": 1.0},
}

var _rng := RandomNumberGenerator.new()
var _root: Node3D
var _pinturas: Array[ShaderMaterial] = []

func _process(_dt: float) -> void:
	for m in _pinturas:
		B.atualizar_pintura(m, self)

func _pint(cor: Color, cond: float, rough := 0.7, metal := 0.05) -> ShaderMaterial:
	var m := B.pintura(cor, cond, rough, metal, 1.35)
	_pinturas.append(m)
	return m

func _ready() -> void:
	reconstruir()

func peso_total() -> float:
	var p := 380.0
	for slot in config:
		var c: Dictionary = config[slot]
		p += MODULOS[c.id].peso * (0.7 + 0.3 * c.nivel)
	return p

func melhorar(slot: String) -> bool:
	if not config.has(slot):
		return false
	var c: Dictionary = config[slot]
	if c.nivel >= MODULOS[c.id].nivel_max:
		return false
	c.nivel += 1
	reconstruir()
	return true

func reparar(slot: String, quantidade := 0.25) -> void:
	if config.has(slot):
		config[slot].condicao = minf(1.0, config[slot].condicao + quantidade)
		reconstruir()

func danificar(slot: String, quantidade: float) -> void:
	if config.has(slot):
		config[slot].condicao = maxf(0.0, config[slot].condicao - quantidade)
		reconstruir()

func reconstruir() -> void:
	if _root:
		_root.queue_free()
	if is_inside_tree():
		call_deferred("_process", 0.0)
	_pinturas.clear()
	_root = Node3D.new()
	add_child(_root)
	_rng.seed = 7331
	_base()
	for slot in config:
		var c: Dictionary = config[slot]
		var fn: String = "_mod_" + c.id
		if has_method(fn):
			call(fn, int(c.nivel), float(c.condicao))

# ---------------------------------------------------------------- base
func _base() -> void:
	var r := _root
	var hz := COMPRIMENTO * 0.5
	var hw := LARGURA * 0.5
	var pintura := _pint(cor_pintura, condicao_carroceria)
	var preto := _pint(Color(0.06, 0.06, 0.065), condicao_carroceria + 0.2, 0.65, 0.2)
	var aco := B.mat(Color(0.12, 0.12, 0.13), 0.5, 0.6)
	var lama := B.mat(Color(0.24, 0.19, 0.14), 1.0)

	var perfil := PackedVector2Array([
		Vector2(-hz, BASE_Y), Vector2(hz - 0.35, BASE_Y), Vector2(hz, BASE_Y + 0.3),
		Vector2(hz, 1.55), Vector2(hz - 0.45, TOPO_Y), Vector2(-hz + 0.35, TOPO_Y),
		Vector2(-hz, TOPO_Y - 0.3)])
	B.extruded(r, perfil, LARGURA, Vector3.ZERO, pintura)

	# faixa inferior preta e lama
	B.box(r, Vector3(LARGURA + 0.02, 0.22, COMPRIMENTO - 0.4), Vector3(0, BASE_Y + 0.11, -0.15), preto)
	# quinas superiores pretas
	B.box(r, Vector3(LARGURA + 0.02, 0.05, COMPRIMENTO - 0.75), Vector3(0, TOPO_Y - 0.02, -0.05), preto)

	# chassi, eixo e para-lamas
	B.box(r, Vector3(0.12, 0.14, COMPRIMENTO + 0.2), Vector3(-0.6, BASE_Y - 0.08, 0), aco)
	B.box(r, Vector3(0.12, 0.14, COMPRIMENTO + 0.2), Vector3(0.6, BASE_Y - 0.08, 0), aco)
	B.cyl(r, 0.05, LARGURA + 0.2, Vector3(0, 0.44, -0.2), aco, Vector3(0, 0, 90), 8)
	for s in [-1.0, 1.0]:
		B.wheel(r, Vector3(s * (hw + 0.1), 0.44, -0.2), 0.44, 0.3)
		var fl := PackedVector2Array([Vector2(-0.62, 0.62), Vector2(-0.45, 1.0), Vector2(0.45, 1.0), Vector2(0.62, 0.62), Vector2(0.55, 0.62), Vector2(0.4, 0.93), Vector2(-0.4, 0.93), Vector2(-0.55, 0.62)])
		B.extruded(r, fl, 0.36, Vector3(s * (hw + 0.1), 0, -0.2), preto)
		# degrau lateral
	B.box(r, Vector3(0.3, 0.04, 0.9), Vector3(hw + 0.15, 0.55, 0.65), B.mat(Color(0.1, 0.1, 0.1), 0.6, 0.5))

	# lança em A e engate
	for s in [-1.0, 1.0]:
		var beam := B.box(r, Vector3(0.1, 0.1, 1.9), Vector3(s * 0.32, 0.6, hz + 0.75), aco)
		beam.rotation.y = -s * 0.28
	B.box(r, Vector3(0.12, 0.12, 0.5), Vector3(0, 0.6, hz + 1.55), aco)
	B.sphere(r, 0.06, Vector3(0, 0.62, hz + 1.8), aco)
	B.cyl(r, 0.04, 0.55, Vector3(0.2, 0.35, hz + 1.25), aco)  # macaco de apoio

	# caixa de ferramentas frontal (compartimento: a frente desce como tampa de caçamba)
	var aberta: bool = compartimentos_abertos.get("ferramentas", false)
	B.box(r, Vector3(1.5, 0.58, 0.6), Vector3(0, BASE_Y + 0.29, hz + 0.32), preto)
	for s in [-0.45, 0.45]:
		B.box(r, Vector3(0.06, 0.03, 0.08), Vector3(s, BASE_Y + 0.44, hz + 0.63), aco)
	if aberta:
		B.box(r, Vector3(1.4, 0.48, 0.02), Vector3(0, BASE_Y + 0.3, hz + 0.625), B.mat(Color(0.03, 0.03, 0.03), 1.0))
		var tampa := Node3D.new()
		tampa.position = Vector3(0, BASE_Y + 0.04, hz + 0.63)
		tampa.rotation.x = 1.45
		r.add_child(tampa)
		B.box(tampa, Vector3(1.46, 0.5, 0.03), Vector3(0, 0.25, 0), preto)
		for s2 in [-0.6, 0.6]:
			B.cyl(r, 0.006, 0.45, Vector3(s2, BASE_Y + 0.3, hz + 0.82), aco, Vector3(55, 0, 0), 4)
		B.box(r, Vector3(0.4, 0.05, 0.06), Vector3(-0.35, BASE_Y + 0.12, hz + 0.45), B.mat(Color(0.75, 0.1, 0.06), 0.5), Vector3(0, 20, 0))
		B.box(r, Vector3(0.22, 0.12, 0.18), Vector3(0.4, BASE_Y + 0.1, hz + 0.42), B.mat(Color(0.75, 0.6, 0.1), 0.6))
		B.box(r, Vector3(0.3, 0.22, 0.3), Vector3(0.0, BASE_Y + 0.15, hz + 0.3), B.mat(Color(0.55, 0.12, 0.08), 0.5, 0.3))
		B.cyl(r, 0.05, 0.1, Vector3(-0.1, BASE_Y + 0.33, hz + 0.45), B.mat(Color(0.1, 0.3, 0.6), 0.5), Vector3.ZERO, 10)
	B.box(r, Vector3(1.52, 0.03, 0.62), Vector3(0, BASE_Y + 0.6, hz + 0.32), preto)

	# porta lateral direita (+X)
	var porta := B.mat(B.worn(Color(0.08, 0.08, 0.085), 0.8), 0.6, 0.1)
	B.box(r, Vector3(0.04, 0.95, 0.78), Vector3(hw + 0.01, 1.32, 0.35), porta)
	for dz in [-0.17, 0.17]:
		B.box(r, Vector3(0.05, 0.38, 0.07), Vector3(hw + 0.02, 1.38, 0.35 + dz), _vidro())
	B.cyl(r, 0.08, 0.05, Vector3(hw + 0.04, 1.62, 0.35), aco, Vector3(0, 0, 90), 12)
	for dy in [1.0, 1.65]:
		B.box(r, Vector3(0.06, 0.05, 0.12), Vector3(hw + 0.03, dy, 0.77), aco)

	# janelas ovais superiores (as duas laterais)
	for s in [-1.0, 1.0]:
		for z in [-1.0, 0.0, 0.95]:
			var j := B.cyl(r, 0.13, 0.03, Vector3(s * (hw + 0.005), 1.82, z), _vidro(), Vector3(0, 0, 90), 16)
			j.scale = Vector3(1, 1, 2.0)
	# janela traseira
	B.box(r, Vector3(0.9, 0.35, 0.03), Vector3(0, 1.65, -hz - 0.005), _vidro())
	# lanternas
	for s in [-1.0, 1.0]:
		B.box(r, Vector3(0.18, 0.1, 0.04), Vector3(s * 0.7, 1.0, -hz - 0.02), B.emissive(Color(0.8, 0.05, 0.03), 0.6))
		B.box(r, Vector3(0.05, 0.08, 0.05), Vector3(s * (hw + 0.01), 1.0, hz - 0.1), B.emissive(Color(1.0, 0.5, 0.05), 0.5))

	# engate traseiro (receptor para reboques extras)
	B.box(r, Vector3(0.12, 0.12, 0.5), Vector3(0, 0.6, -hz - 0.3), aco)
	B.box(r, Vector3(0.2, 0.06, 0.08), Vector3(0, 0.6, -hz - 0.52), aco)
	B.sphere(r, 0.05, Vector3(0, 0.67, -hz - 0.55), B.mat(Color(0.6, 0.6, 0.6), 0.3, 0.9))

	_bagageiro()
	_interior()

	if luz_interna:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.12, 0.08) if luz_vermelha else Color(1.0, 0.68, 0.35)
		l.light_energy = (0.3 if luz_vermelha else 0.5) if modo_interior else 0.6
		l.omni_range = 2.4
		l.position = Vector3(0.1, 1.85, 0.6)
		r.add_child(l)

## Casca interna e mobília. Só fica visível de dentro (a casca externa esconde de fora).
func _interior() -> void:
	var r := _root
	var hz := COMPRIMENTO * 0.5
	var hw := LARGURA * 0.5 - 0.035
	var parede := B.mat(Color(0.62, 0.6, 0.56), 0.85, 0.0, "int_parede")
	var madeira := B.mat(Color(0.45, 0.3, 0.18), 0.7, 0.0, "int_madeira")
	var escuro := B.mat(Color(0.12, 0.12, 0.13), 0.7, 0.2, "int_escuro")
	var t := 0.03
	# piso e teto
	B.box(r, Vector3(LARGURA - 0.1, t, COMPRIMENTO - 0.1), Vector3(0, BASE_Y + 0.04, 0), B.mat(Color(0.2, 0.18, 0.16), 0.9, 0.0, "int_piso"))
	B.box(r, Vector3(LARGURA - 0.1, t, COMPRIMENTO - 0.85), Vector3(0, TOPO_Y - 0.04, -0.05), B.mat(Color(0.82, 0.8, 0.75), 0.9, 0.0, "int_teto"))
	# laterais com vão das janelas (y 1.69..1.95)
	for s in [-1.0, 1.0]:
		var x: float = s * hw
		B.box(r, Vector3(t, 0.92, COMPRIMENTO - 0.12), Vector3(x, BASE_Y + 0.5, -0.02), parede)
		B.box(r, Vector3(t, 0.07, COMPRIMENTO - 0.85), Vector3(x, 1.99, -0.05), parede)
		for zz in [[-1.7, -1.26], [-0.74, -0.26], [0.26, 0.69], [1.21, 1.32]]:
			B.box(r, Vector3(t, 0.3, zz[1] - zz[0]), Vector3(x, 1.82, (zz[0] + zz[1]) * 0.5), parede)
	# frente: parede reta + inclinação
	B.box(r, Vector3(LARGURA - 0.1, 0.8, t), Vector3(0, 1.15, hz - 0.05), parede)
	var inc_f := B.box(r, Vector3(LARGURA - 0.1, 0.66, t), Vector3(0, 1.8, hz - 0.28), parede)
	inc_f.rotation.x = -atan2(0.45, 0.5)
	# traseira: parede baixa, vão da janela, inclinação
	B.box(r, Vector3(LARGURA - 0.1, 0.72, t), Vector3(0, 1.11, -hz + 0.05), parede)
	for s in [-1.0, 1.0]:
		B.box(r, Vector3(0.36, 0.3, t), Vector3(s * 0.66, 1.62, -hz + 0.05), parede)
	var inc_t := B.box(r, Vector3(LARGURA - 0.1, 0.46, t), Vector3(0, 1.9, -hz + 0.2), parede)
	inc_t.rotation.x = -atan2(0.35, 0.3)

	# cama na traseira (base com gavetas + colchão + cobertor + travesseiros)
	B.box(r, Vector3(LARGURA - 0.12, 0.3, 1.95), Vector3(0, BASE_Y + 0.2, -0.75), madeira)
	for i in 3:
		B.box(r, Vector3(0.012, 0.18, 0.5), Vector3(hw - 0.02 - 0.0, BASE_Y + 0.2, -1.4 + i * 0.6), escuro)
	B.box(r, Vector3(LARGURA - 0.16, 0.16, 1.9), Vector3(0, BASE_Y + 0.43, -0.75), B.mat(Color(0.82, 0.8, 0.74), 0.95, 0.0, "int_colchao"))
	var cob := B.box(r, Vector3(LARGURA - 0.12, 0.05, 1.15), Vector3(0, BASE_Y + 0.53, -0.35), B.mat(Color(0.3, 0.33, 0.27), 0.95, 0.0, "int_cobertor"))
	cob.rotation_degrees.z = 1.5
	B.box(r, Vector3(LARGURA - 0.11, 0.03, 0.3), Vector3(0, BASE_Y + 0.555, 0.05), B.mat(Color(0.2, 0.22, 0.18), 0.95))  # dobra
	for s in [-0.38, 0.38]:
		var tr := B.box(r, Vector3(0.6, 0.12, 0.34), Vector3(s, BASE_Y + 0.57, -1.5), B.mat(Color(0.86, 0.85, 0.8), 0.95, 0.0, "int_travesseiro"))
		tr.rotation_degrees.x = -12

	# armário frontal com prateleiras
	var zf := hz - 0.3
	B.box(r, Vector3(LARGURA - 0.12, 0.62, 0.42), Vector3(0, BASE_Y + 0.35, zf - 0.02), madeira)
	for s in [-1.0, 1.0]:
		B.box(r, Vector3(0.7, 0.5, 0.012), Vector3(s * 0.38, BASE_Y + 0.35, zf - 0.235), B.mat(Color(0.38, 0.25, 0.15), 0.7))
		B.box(r, Vector3(0.1, 0.02, 0.02), Vector3(s * 0.12, BASE_Y + 0.45, zf - 0.25), escuro)
	B.box(r, Vector3(LARGURA - 0.12, 0.02, 0.24), Vector3(0, 1.58, zf + 0.05), madeira)  # prateleira alta
	# rádio
	var radio := Node3D.new()
	radio.position = Vector3(-0.42, BASE_Y + 0.66, zf - 0.05)
	r.add_child(radio)
	B.box(radio, Vector3(0.32, 0.15, 0.18), Vector3(0, 0.075, 0), escuro)
	B.box(radio, Vector3(0.14, 0.06, 0.005), Vector3(-0.05, 0.09, -0.091), B.emissive(Color(0.95, 0.6, 0.15), 1.2))
	for dx in [0.06, 0.11]:
		B.cyl(radio, 0.022, 0.02, Vector3(dx, 0.075, -0.095), B.mat(Color(0.5, 0.5, 0.5), 0.4, 0.8), Vector3(90, 0, 0), 10)
	B.cyl(radio, 0.006, 0.35, Vector3(0.13, 0.32, 0.05), escuro, Vector3(0, 0, -15), 4)
	B.box(radio, Vector3(0.06, 0.1, 0.04), Vector3(-0.22, 0.05, 0.02), escuro)  # microfone
	# lampião, livros, garrafas, kit médico
	B.cyl(r, 0.05, 0.16, Vector3(0.35, BASE_Y + 0.74, zf - 0.08), B.emissive(Color(1.0, 0.75, 0.4), 2.0), Vector3.ZERO, 10)
	B.cyl(r, 0.06, 0.02, Vector3(0.35, BASE_Y + 0.83, zf - 0.08), escuro, Vector3.ZERO, 10)
	for i in 5:
		var cor := Color.from_hsv(0.05 + i * 0.13, 0.5, 0.45)
		var lv := B.box(r, Vector3(0.04, 0.2 + (i % 2) * 0.03, 0.15), Vector3(0.05 + i * 0.045, 1.7, zf + 0.06), B.mat(cor, 0.8))
		lv.rotation_degrees.z = 4 if i == 4 else 0
	for i in 3:
		B.cyl(r, 0.035, 0.22, Vector3(-0.55 + i * 0.09, 1.7, zf + 0.06), B.mat(Color(0.55, 0.75, 0.9), 0.15, 0.1), Vector3.ZERO, 8)
	B.box(r, Vector3(0.22, 0.14, 0.12), Vector3(0.6, 1.66, zf + 0.06), B.mat(Color(0.8, 0.12, 0.1), 0.6))
	B.box(r, Vector3(0.06, 0.06, 0.005), Vector3(0.6, 1.66, zf - 0.005), B.mat(Color(0.95, 0.95, 0.95), 0.6))
	# mapa preso na parede da porta e extintor
	var mapa := B.box(r, Vector3(0.005, 0.32, 0.46), Vector3(hw - 0.02, 1.28, -0.35), B.mat(Color(0.82, 0.76, 0.6), 0.9, 0.0, "int_mapa"))
	for i in 4:
		B.box(r, Vector3(0.006, 0.008, 0.38), Vector3(hw - 0.023, 1.18 + i * 0.07, -0.35 + (i - 1.5) * 0.02), B.mat(Color(0.6, 0.2, 0.12), 0.9), Vector3(i * 6.0, 0, 0))
	B.cyl(r, 0.055, 0.32, Vector3(hw - 0.08, BASE_Y + 0.75, 0.82), B.mat(Color(0.75, 0.08, 0.06), 0.4, 0.3), Vector3.ZERO, 10)
	# lado de dentro da porta
	B.box(r, Vector3(0.02, 0.9, 0.72), Vector3(hw - 0.02, 1.32, 0.35), B.mat(Color(0.3, 0.3, 0.3), 0.6, 0.3))
	B.box(r, Vector3(0.05, 0.03, 0.14), Vector3(hw - 0.05, 1.3, 0.62), escuro)
	# faixa de LED no teto
	B.box(r, Vector3(0.02, 0.01, 1.8), Vector3(0, TOPO_Y - 0.06, -0.2), B.emissive(Color(1.0, 0.15, 0.08) if luz_vermelha else Color(1.0, 0.8, 0.55), 0.7 if luz_interna else 0.0))

func _vidro() -> StandardMaterial3D:
	if modo_interior:
		var k := "vidro_interior"
		if not B._mats.has(k):
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.25, 0.3, 0.32, 0.18)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			B._mats[k] = m
		return B._mats[k]
	if luz_interna:
		return B.emissive(Color(1.0, 0.62, 0.25), 1.6)
	return B.mat(Color(0.05, 0.06, 0.07), 0.1, 0.3)

# ---------------------------------------------------------------- módulos
func _mod_cozinha(nivel: int, cond: float) -> void:
	var r := _root
	var hw := LARGURA * 0.5
	var aberto := cozinha_aberta * 0.72
	var branco := _pint(Color(0.86, 0.86, 0.83), cond, 0.45, 0.1)
	var inox := B.mat(Color(0.6, 0.6, 0.62), 0.3, 0.9)
	var preto := B.mat(Color(0.05, 0.05, 0.05), 0.7)
	var z0 := -1.35
	var comp := 1.5
	# vão escuro na carroceria
	B.box(r, Vector3(0.02, 0.3, comp + 0.06), Vector3(-hw - 0.002, 1.02, z0 + comp * 0.5), B.mat(Color(0.02, 0.02, 0.02), 1.0))
	if aberto <= 0.01:
		B.box(r, Vector3(0.03, 0.28, comp), Vector3(-hw - 0.01, 1.02, z0 + comp * 0.5), _pint(cor_pintura, condicao_carroceria))
		return
	var g := Node3D.new()
	g.position = Vector3(-hw - aberto * 0.5, 0, z0 + comp * 0.5)
	g.rotation.y = PI
	r.add_child(g)
	B.box(g, Vector3(0.62 + aberto * 0.2, 0.05, comp), Vector3(0.05, 1.12, 0), branco)  # bancada
	B.box(g, Vector3(0.62, 0.24, comp), Vector3(0, 0.98, 0), branco)
	B.box(g, Vector3(0.62, 0.3, 0.03), Vector3(0.05, 1.27, -comp * 0.5), branco)  # espelho lateral
	# pia
	B.box(g, Vector3(0.34, 0.02, 0.34), Vector3(0.1, 1.15, 0.05), inox)
	B.box(g, Vector3(0.3, 0.03, 0.3), Vector3(0.1, 1.146, 0.05), B.mat(Color(0.25, 0.25, 0.26), 0.3, 0.9))
	B.cyl(g, 0.012, 0.22, Vector3(-0.12, 1.25, 0.05), inox, Vector3.ZERO, 6)
	B.cyl(g, 0.01, 0.14, Vector3(-0.06, 1.35, 0.05), inox, Vector3(0, 0, 70), 6)
	# fogão
	B.box(g, Vector3(0.36, 0.03, 0.4), Vector3(0.1, 1.16, 0.5), inox)
	for dz in [-0.09, 0.09]:
		B.cyl(g, 0.07, 0.015, Vector3(0.1, 1.18, 0.5 + dz), preto, Vector3.ZERO, 12)
	# frigideira e chaleira
	B.cyl(g, 0.13, 0.05, Vector3(0.1, 1.21, 0.42), B.mat(Color(0.08, 0.08, 0.08), 0.6, 0.5), Vector3.ZERO, 16)
	B.box(g, Vector3(0.03, 0.025, 0.2), Vector3(0.28, 1.22, 0.38), B.mat(Color(0.7, 0.08, 0.05), 0.5), Vector3(0, -50, 0))
	B.cyl(g, 0.07, 0.12, Vector3(0.05, 1.25, 0.62), inox, Vector3.ZERO, 10, 0.05)
	if nivel >= 2:
		# geladeira portátil
		B.box(g, Vector3(0.4, 0.38, 0.5), Vector3(0.0, 1.33, -0.48), B.mat(Color(0.55, 0.56, 0.58), 0.4, 0.3))
		B.box(g, Vector3(0.42, 0.05, 0.52), Vector3(0.0, 1.54, -0.48), B.mat(Color(0.18, 0.2, 0.22), 0.5))
	if nivel >= 3:
		# toldo
		var toldo := B.box(r, Vector3(1.6, 0.03, 2.6), Vector3(-hw - 0.78, 2.12, -0.2), B.mat(Color(0.32, 0.3, 0.24), 0.95))
		toldo.rotation_degrees.z = 9
		B.cyl(r, 0.06, 2.7, Vector3(-hw - 0.02, 2.2, -0.2), B.mat(Color(0.1, 0.1, 0.1), 0.7), Vector3(90, 0, 0), 8)
		for dz in [-1.45, 1.05]:
			B.cyl(r, 0.02, 2.1, Vector3(-hw - 1.55, 1.05, dz), B.mat(Color(0.2, 0.2, 0.2), 0.5, 0.6))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.4)
	l.light_energy = 0.45
	l.omni_range = 2.2
	l.position = Vector3(-hw - 0.75, 1.75, z0 + comp * 0.5)
	r.add_child(l)
	# pote de temperos na prateleira interna
	for i in 4:
		B.cyl(r, 0.03, 0.1, Vector3(-hw + 0.05, 1.0, z0 + 0.2 + i * 0.08), B.mat(Color.from_hsv(_rng.randf(), 0.6, 0.6)), Vector3.ZERO, 8)

## Fileira de portinholas no flanco direito, atrás da porta (como nos trailers
## off-road de referência). Abertas, mostram prateleiras com latas, garrafas e potes.
func _mod_despensa(nivel: int, cond: float) -> void:
	var r := _root
	var hw := LARGURA * 0.5
	var aberto: bool = compartimentos_abertos.get("despensa", false)
	var n := 3 if nivel <= 1 else 4
	var larg := 0.3
	var z0 := -1.68
	var y0 := 1.0
	var alt := 0.48
	var moldura := B.mat(B.worn(Color(0.08, 0.08, 0.085), cond), 0.55, 0.4)
	var interno := B.mat(Color(0.75, 0.74, 0.7), 0.6)
	var aco := B.mat(Color(0.55, 0.55, 0.56), 0.35, 0.85)
	var comp := n * larg + 0.06
	B.box(r, Vector3(0.025, alt + 0.06, comp), Vector3(hw + 0.006, y0 + alt * 0.5, z0 + comp * 0.5), moldura)
	for i in n:
		var zc := z0 + 0.03 + larg * (i + 0.5)
		if aberto:
			B.box(r, Vector3(0.02, alt - 0.04, larg - 0.04), Vector3(hw + 0.014, y0 + alt * 0.5, zc), interno)
			B.box(r, Vector3(0.16, 0.015, larg - 0.04), Vector3(hw + 0.08, y0 + 0.24, zc), interno)
			var porta := Node3D.new()
			porta.position = Vector3(hw + 0.03, y0, zc)
			porta.rotation.z = -1.35
			r.add_child(porta)
			B.box(porta, Vector3(0.02, alt - 0.03, larg - 0.04), Vector3(0, alt * 0.5, 0), preto_porta(cond))
			for k in 2:
				var dz := -0.06 + k * 0.12
				match i % 4:
					0:
						B.cyl(r, 0.035, 0.1, Vector3(hw + 0.06, y0 + 0.07, zc + dz), B.mat(Color.from_hsv(0.05 + k * 0.15, 0.7, 0.7), 0.45, 0.3), Vector3.ZERO, 10)
						B.cyl(r, 0.035, 0.1, Vector3(hw + 0.06, y0 + 0.31, zc + dz), B.mat(Color(0.85, 0.45, 0.12), 0.45, 0.3), Vector3.ZERO, 10)
					1:
						B.cyl(r, 0.03, 0.2, Vector3(hw + 0.06, y0 + 0.12, zc + dz), B.mat(Color(0.55, 0.75, 0.9, 1.0), 0.15), Vector3.ZERO, 8)
						B.box(r, Vector3(0.1, 0.1, 0.08), Vector3(hw + 0.07, y0 + 0.32, zc + dz), B.mat(Color(0.7, 0.6, 0.4), 0.9))
					2:
						B.cyl(r, 0.04, 0.12, Vector3(hw + 0.06, y0 + 0.08, zc + dz), B.mat(Color(0.75, 0.25, 0.15), 0.3), Vector3.ZERO, 10)
						B.box(r, Vector3(0.06, 0.09, 0.06), Vector3(hw + 0.06, y0 + 0.3, zc + dz), B.mat(Color(0.9, 0.9, 0.88), 0.5))
					3:
						B.box(r, Vector3(0.1, 0.08, 0.1), Vector3(hw + 0.07, y0 + 0.06, zc + dz), B.mat(Color(0.82, 0.1, 0.08), 0.5))
						B.cyl(r, 0.035, 0.14, Vector3(hw + 0.06, y0 + 0.32, zc + dz), B.mat(Color(0.25, 0.45, 0.2), 0.4), Vector3.ZERO, 8)
		else:
			B.box(r, Vector3(0.022, alt - 0.04, larg - 0.04), Vector3(hw + 0.02, y0 + alt * 0.5, zc), preto_porta(cond))
			B.box(r, Vector3(0.03, 0.03, 0.08), Vector3(hw + 0.035, y0 + alt - 0.06, zc), aco)
		B.box(r, Vector3(0.03, 0.02, larg - 0.1), Vector3(hw + 0.03, y0 + 0.01, zc), aco)
	if nivel >= 3:
		B.box(r, Vector3(0.03, 0.14, comp - 0.04), Vector3(hw + 0.02, y0 - 0.1, z0 + comp * 0.5), moldura)
		B.box(r, Vector3(0.03, 0.03, 0.16), Vector3(hw + 0.04, y0 - 0.1, z0 + comp * 0.5), aco)

## Portinholas pretas, como nas fotos de referência.
func preto_porta(cond: float) -> Material:
	return _pint(Color(0.07, 0.07, 0.075), cond + 0.2, 0.6, 0.2)

## Bagageiro no flanco esquerdo, na frente da cozinha: portinhola grande com
## mochilas, caixas de munição e ferramentas maiores.
func _bagageiro() -> void:
	var r := _root
	var hw := LARGURA * 0.5
	var aberto: bool = compartimentos_abertos.get("bagageiro", false)
	var z0 := 0.55
	var comp := 0.95
	var y0 := 0.98
	var alt := 0.52
	var moldura := B.mat(Color(0.08, 0.08, 0.085), 0.55, 0.4)
	var aco := B.mat(Color(0.55, 0.55, 0.56), 0.35, 0.85)
	B.box(r, Vector3(0.025, alt + 0.06, comp + 0.06), Vector3(-hw - 0.006, y0 + alt * 0.5, z0 + comp * 0.5), moldura)
	if aberto:
		B.box(r, Vector3(0.02, alt - 0.03, comp - 0.03), Vector3(-hw - 0.012, y0 + alt * 0.5, z0 + comp * 0.5), B.mat(Color(0.03, 0.03, 0.03), 1.0))
		var porta := Node3D.new()
		porta.position = Vector3(-hw - 0.03, y0 + alt, z0 + comp * 0.5)
		porta.rotation.z = -1.25
		r.add_child(porta)
		B.box(porta, Vector3(0.02, alt, comp - 0.03), Vector3(0, -alt * 0.5, 0), preto_porta(1.0))
		B.cyl(r, 0.01, 0.4, Vector3(-hw - 0.18, y0 + alt + 0.08, z0 + 0.1), aco, Vector3(0, 0, 50), 6)
		B.box(r, Vector3(0.22, 0.16, 0.3), Vector3(-hw + 0.02, y0 + 0.09, z0 + 0.22), B.mat(Color(0.25, 0.3, 0.2), 0.7, 0.3))
		B.box(r, Vector3(0.05, 0.02, 0.1), Vector3(-hw - 0.08, y0 + 0.18, z0 + 0.22), B.mat(Color(0.8, 0.7, 0.2), 0.5))
		B.box(r, Vector3(0.26, 0.34, 0.24), Vector3(-hw + 0.0, y0 + 0.19, z0 + 0.6), B.mat(Color(0.22, 0.25, 0.17), 0.95))
		B.cyl(r, 0.06, 0.4, Vector3(-hw + 0.05, y0 + 0.4, z0 + 0.48), B.mat(Color(0.3, 0.28, 0.2), 0.95), Vector3(90, 0, 0), 10)
		B.box(r, Vector3(0.05, 0.05, 0.6), Vector3(-hw - 0.05, y0 + 0.07, z0 + 0.5), B.mat(Color(0.38, 0.22, 0.11), 0.7))
	else:
		B.box(r, Vector3(0.022, alt - 0.03, comp - 0.03), Vector3(-hw - 0.02, y0 + alt * 0.5, z0 + comp * 0.5), preto_porta(1.0))
		B.box(r, Vector3(0.03, 0.06, 0.14), Vector3(-hw - 0.035, y0 + alt * 0.5, z0 + comp - 0.12), aco)
	for dz in [0.15, comp - 0.15]:
		B.box(r, Vector3(0.03, 0.03, 0.08), Vector3(-hw - 0.03, y0 + alt - 0.01, z0 + dz), aco)

func _mod_rack_teto(nivel: int, cond: float) -> void:
	var r := _root
	var hz := COMPRIMENTO * 0.5
	var y := TOPO_Y + 0.08
	var preto := B.mat(B.worn(Color(0.06, 0.06, 0.06), cond), 0.6, 0.4)
	for s in [-0.8, 0.8]:
		B.box(r, Vector3(0.04, 0.04, COMPRIMENTO - 0.5), Vector3(s, y + 0.06, -0.05), preto)
		for z in [-1.3, -0.4, 0.5, 1.2]:
			B.box(r, Vector3(0.04, 0.1, 0.04), Vector3(s, y, z), preto)
	for z in range(-6, 7):
		B.box(r, Vector3(1.6, 0.03, 0.03), Vector3(0, y + 0.02, z * 0.22 - 0.05), preto)
	if nivel >= 2:
		# pá e macaco hi-lift
		var cabo := B.mat(Color(0.75, 0.6, 0.1), 0.6)
		B.cyl(r, 0.02, 1.0, Vector3(0.7, y + 0.1, 0.4), cabo, Vector3(90, 0, 0), 8)
		B.box(r, Vector3(0.2, 0.02, 0.26), Vector3(0.7, y + 0.1, 1.0), B.mat(Color(0.75, 0.12, 0.06), 0.6, 0.3))
		B.box(r, Vector3(0.06, 0.06, 1.2), Vector3(0.55, y + 0.1, 0.3), B.mat(Color(0.7, 0.1, 0.05), 0.5, 0.4))
		B.box(r, Vector3(0.24, 0.12, 0.3), Vector3(0.55, y + 0.12, -0.5), B.mat(Color(0.75, 0.1, 0.05), 0.5))  # case vermelha
	if nivel >= 3:
		# caixa rígida grande
		var caixa := B.box(r, Vector3(0.75, 0.45, 0.55), Vector3(-0.35, y + 0.3, hz - 0.55), _pint(Color(0.08, 0.08, 0.08), cond, 0.6))
		caixa.rotation_degrees.x = -8
		for s in [-1.0, 1.0]:
			B.jerrycan(r, Vector3(s * 0.7 if s > 0 else 0.35, y + 0.04, hz - 0.35), Color(0.8, 0.1, 0.05), Vector3(0, 90, 0))

func _mod_barraca(nivel: int, cond: float) -> void:
	var r := _root
	var y := TOPO_Y + 0.08
	var lona := B.mat(B.worn(Color(0.2, 0.21, 0.2), cond + 0.3), 0.95)
	if nivel == 1:
		var b := B.box(r, Vector3(0.45, 0.22, 1.9), Vector3(-0.45, y + 0.16, -0.45), lona)
		B.box(r, Vector3(0.47, 0.03, 1.92), Vector3(-0.45, y + 0.28, -0.45), B.mat(Color(0.1, 0.1, 0.1), 0.7))
	else:
		B.box(r, Vector3(1.6, 0.35, 2.0), Vector3(0, y + 0.22, -0.4), B.mat(Color(0.85, 0.85, 0.82), 0.5))

func _mod_galoes(nivel: int, cond: float) -> void:
	var r := _root
	var hz := COMPRIMENTO * 0.5
	var y := BASE_Y + 0.64
	var cores := [Color(0.75, 0.1, 0.05), Color(0.75, 0.1, 0.05), Color(0.85, 0.85, 0.82), Color(0.2, 0.35, 0.15), Color(0.75, 0.1, 0.05)]
	var n := 1 + nivel
	B.box(r, Vector3(1.4, 0.03, 0.42), Vector3(0, y, hz + 0.32), B.mat(Color(0.08, 0.08, 0.08), 0.6, 0.5))
	for i in n:
		var x := -0.55 + i * (1.1 / maxf(n - 1, 1))
		B.jerrycan(r, Vector3(x, y + 0.01, hz + 0.32), B.worn(cores[i], cond + 0.2), Vector3(0, 90 + _rng.randf_range(-6, 6), 0))

func _mod_estepes(nivel: int, cond: float) -> void:
	var r := _root
	var hz := COMPRIMENTO * 0.5
	var xs := [0.0] if nivel == 1 else [-0.42, 0.42]
	for x in xs:
		var w := B.wheel(r, Vector3(x, 1.12, -hz - 0.2), 0.42, 0.28)
		w.rotation_degrees.y = 90
		B.box(r, Vector3(0.1, 0.1, 0.12), Vector3(x, 1.12, -hz - 0.06), B.mat(Color(0.1, 0.1, 0.1), 0.5, 0.6))

func _mod_grades(nivel: int, cond: float) -> void:
	var r := _root
	var hw := LARGURA * 0.5
	var preto := B.mat(B.worn(Color(0.05, 0.05, 0.05), cond), 0.6, 0.5)
	for s in [-1.0, 1.0]:
		for z in [-1.0, 0.0, 0.95]:
			for k in range(-3, 4):
				B.box(r, Vector3(0.015, 0.3, 0.012), Vector3(s * (hw + 0.03), 1.82, z + k * 0.07), preto)
			B.box(r, Vector3(0.015, 0.012, 0.56), Vector3(s * (hw + 0.03), 1.82, z), preto)
	# grade da janela traseira
	for k in range(-6, 7):
		B.box(r, Vector3(0.012, 0.4, 0.015), Vector3(k * 0.075, 1.65, -COMPRIMENTO * 0.5 - 0.03), preto)
	if nivel >= 2:
		# chapas de blindagem rebitadas na saia inferior (abaixo das portas e compartimentos)
		var chapa := _pint(Color(0.3, 0.31, 0.3), cond * 0.7, 0.5, 0.7)
		var rebite := B.mat(Color(0.5, 0.5, 0.5), 0.4, 0.9)
		for s in [-1.0, 1.0]:
			for seg in [[-1.55, -0.65], [0.25, 1.35]]:
				var zc: float = (seg[0] + seg[1]) * 0.5
				var lz: float = seg[1] - seg[0]
				B.box(r, Vector3(0.02, 0.2, lz), Vector3(s * (hw + 0.022), BASE_Y + 0.11, zc), chapa)
				for k in 4:
					B.sphere(r, 0.012, Vector3(s * (hw + 0.035), BASE_Y + 0.17, seg[0] + 0.08 + k * (lz - 0.16) / 3.0), rebite)

## Couraça: chapas de aço nas laterais (nível 1) e espinhos por cima (nível 2).
func _mod_couraca(nivel: int, cond: float) -> void:
	if nivel <= 0:
		return
	var r := _root
	var hw := LARGURA * 0.5
	var chapa := _pint(Color(0.32, 0.33, 0.31), cond * 0.6, 0.5, 0.7)
	var rebite := B.mat(Color(0.5, 0.5, 0.5), 0.4, 0.9)
	var aco := B.mat(Color(0.2, 0.19, 0.18), 0.55, 0.7)
	for s in [-1.0, 1.0]:
		for seg in [[-1.75, -0.7], [-0.6, 0.15], [0.3, 1.5]]:
			var zc: float = (seg[0] + seg[1]) * 0.5
			var lz: float = seg[1] - seg[0]
			B.box(r, Vector3(0.025, 0.42, lz), Vector3(s * (hw + 0.05), BASE_Y + 0.42, zc), chapa)
			for k in 3:
				B.sphere(r, 0.014, Vector3(s * (hw + 0.065), BASE_Y + 0.6, seg[0] + 0.1 + k * (lz - 0.2) / 2.0), rebite)
		if nivel >= 2:
			for i in 12:
				var z := -1.65 + i * 0.28
				var e := B.cyl(r, 0.022, 0.38, Vector3(s * (hw + 0.24), BASE_Y + 0.42 + (0.1 if i % 2 else -0.1), z), aco, Vector3.ZERO, 5, 0.002)
				e.rotation_degrees = Vector3(0, 0, -90.0 * s)

func _mod_farois(nivel: int, cond: float) -> void:
	var r := _root
	var hz := COMPRIMENTO * 0.5
	var y := TOPO_Y + 0.22
	var pos := [Vector3(-0.72, y, hz - 0.55), Vector3(0.72, y, hz - 0.55)]
	if nivel >= 2:
		pos.append(Vector3(-0.72, y, -hz + 0.45))
		pos.append(Vector3(0.72, y, -hz + 0.45))
	var aceso := cond > 0.3
	for p in pos:
		B.box(r, Vector3(0.14, 0.12, 0.1), p, B.mat(Color(0.06, 0.06, 0.06), 0.5, 0.4))
		var lente := B.cyl(r, 0.05, 0.02, p + Vector3(0, 0, 0.055 if p.z > 0 else -0.055), B.emissive(Color(1.0, 0.85, 0.3), 3.0) if aceso else B.mat(Color(0.6, 0.55, 0.3), 0.2), Vector3(90, 0, 0), 12)
		if aceso:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.82, 0.4)
			l.light_energy = 0.7
			l.omni_range = 4.0
			l.position = p + Vector3(sign(p.x) * 1.6, -1.4, 0.8 * sign(p.z))
			r.add_child(l)

func _mod_antena(nivel: int, _cond: float) -> void:
	var r := _root
	var hz := COMPRIMENTO * 0.5
	B.cyl(r, 0.008, 1.5 + nivel * 0.4, Vector3(-0.78, TOPO_Y + 0.75 + nivel * 0.2, hz - 0.8), B.mat(Color(0.1, 0.1, 0.1), 0.4, 0.6), Vector3.ZERO, 6)
	if nivel >= 2:
		B.cyl(r, 0.025, 1.4, Vector3(0.78, TOPO_Y + 0.7, -hz + 0.8), B.mat(Color(0.1, 0.1, 0.1), 0.4, 0.6))
		B.sphere(r, 0.08, Vector3(0.78, TOPO_Y + 1.45, -hz + 0.8), B.mat(Color(0.9, 0.9, 0.9), 0.3))

func _mod_botijao(nivel: int, cond: float) -> void:
	var r := _root
	var hz := COMPRIMENTO * 0.5
	var m := B.mat(B.worn(Color(0.8, 0.8, 0.78), cond + 0.2), 0.5, 0.4)
	var xs := [0.32] if nivel == 1 else [-0.3, 0.32]
	for x in xs:
		B.cyl(r, 0.15, 0.5, Vector3(x, 0.92, hz + 0.85), m, Vector3.ZERO, 14)
		B.sphere(r, 0.15, Vector3(x, 1.17, hz + 0.85), m, Vector3(1, 0.5, 1))
		B.cyl(r, 0.04, 0.08, Vector3(x, 1.25, hz + 0.85), B.mat(Color(0.5, 0.45, 0.2), 0.4, 0.8), Vector3.ZERO, 8)
