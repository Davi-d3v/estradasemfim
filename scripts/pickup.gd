class_name Pickup
extends Node3D
## Picape modular que puxa o comboio. Frente em +Z.

const LARGURA := 1.95

const MODULOS := {
	"motor": {"nome": "Motor", "nivel_max": 3, "peso": 40.0, "desc": "Força: +450 kg de reboque por nível"},
	"cambio": {"nome": "Câmbio reforçado", "nivel_max": 3, "peso": 35.0, "desc": "+400 kg de reboque por nível, aquece menos"},
	"chassi": {"nome": "Chassi e engate", "nivel_max": 3, "peso": 90.0, "desc": "Limite estrutural: 2,4 t / 3,8 t / 5,6 t"},
	"arrefecimento": {"nome": "Arrefecimento", "nivel_max": 3, "peso": 20.0, "desc": "Radiador maior: segura a temperatura"},
	"turbo": {"nome": "Turbo", "nivel_max": 2, "peso": 15.0, "desc": "+350 kg por nível, mas esquenta e gasta mais"},
	"pneus": {"nome": "Pneus e suspensão", "nivel_max": 3, "peso": 30.0, "desc": "Rende melhor fora da estrada"},
	"tanque": {"nome": "Tanque de diesel", "nivel_max": 2, "peso": 25.0, "desc": "80 L / 130 L"},
	"parachoque": {"nome": "Para-choque", "nivel_max": 3, "peso": 45.0, "desc": "Empurra carros e zumbis"},
	"santo_antonio": {"nome": "Santo-antônio", "nivel_max": 3, "peso": 30.0, "desc": "Faróis e bagageiro"},
	"protecao": {"nome": "Proteção das janelas", "nivel_max": 2, "peso": 35.0, "desc": "Telas e chapas"},
	"snorkel": {"nome": "Snorkel", "nivel_max": 1, "peso": 5.0, "desc": "Atravessa água funda"},
	"cacamba": {"nome": "Carga da caçamba", "nivel_max": 3, "peso": 30.0, "desc": "Mais espaço de carga"},
	"espinhos": {"nome": "Espinhos laterais", "nivel_max": 2, "peso": 40.0, "desc": "Zumbis não conseguem se agarrar (e se ferem tentando)"},
	"posto_tiro": {"nome": "Posto de tiro na caçamba", "nivel_max": 2, "peso": 50.0, "desc": "Um vigia atira da caçamba enquanto você dirige"},
}

@export var cor := Color(0.42, 0.43, 0.42)
@export var condicao := 0.6
var trofeus := 0          # crânios de brutamonte no quebra-mato

var config := {
	"motor": {"id": "motor", "nivel": 1, "condicao": 0.7},
	"cambio": {"id": "cambio", "nivel": 1, "condicao": 0.75},
	"chassi": {"id": "chassi", "nivel": 1, "condicao": 0.8},
	"arrefecimento": {"id": "arrefecimento", "nivel": 1, "condicao": 0.7},
	"turbo": {"id": "turbo", "nivel": 0, "condicao": 1.0},
	"pneus": {"id": "pneus", "nivel": 2, "condicao": 0.65},
	"tanque": {"id": "tanque", "nivel": 1, "condicao": 0.8},
	"parachoque": {"id": "parachoque", "nivel": 2, "condicao": 0.6},
	"santo_antonio": {"id": "santo_antonio", "nivel": 2, "condicao": 0.7},
	"protecao": {"id": "protecao", "nivel": 0, "condicao": 1.0},
	"snorkel": {"id": "snorkel", "nivel": 0, "condicao": 1.0},
	"cacamba": {"id": "cacamba", "nivel": 1, "condicao": 0.8},
	"espinhos": {"id": "espinhos", "nivel": 0, "condicao": 1.0},
	"posto_tiro": {"id": "posto_tiro", "nivel": 0, "condicao": 1.0},
}

## Visão de dentro da cabine: vidros transparentes e interior montado.
var modo_cabine := false
var volante: Node3D
const ASSENTO := Vector3(0.43, 1.62, 0.12)

var _rng := RandomNumberGenerator.new()
var _pinturas: Array[ShaderMaterial] = []
var _corpo: Node3D

func _process(_dt: float) -> void:
	for m in _pinturas:
		B.atualizar_pintura(m, self)

func _ready() -> void:
	reconstruir()

func nivel(slot: String) -> int:
	return int(config[slot].nivel)

# ---------------------------------------------------------------- atributos usados pelo comboio
func elevacao() -> float:
	return (nivel("pneus") - 1) * 0.05

func raio_roda() -> float:
	return 0.46 + (nivel("pneus") - 1) * 0.035

func engate() -> Vector3:
	return Vector3(0, 0.62 + elevacao() + raio_roda() - 0.46, -2.88)

func forca() -> float:
	var c: float = config.motor.condicao
	return (1.0 + (nivel("motor") - 1) * 0.28 + nivel("turbo") * 0.15) * lerpf(0.6, 1.0, c)

## Quanto a picape puxa sem sofrer (kg rebocados).
func capacidade_reboque() -> float:
	var cap := 900.0 + nivel("motor") * 450.0 + nivel("cambio") * 400.0 + nivel("turbo") * 350.0
	var cond: float = (config.motor.condicao + config.cambio.condicao) * 0.5
	return cap * lerpf(0.7, 1.0, cond)

## Peso máximo que o chassi/engate aguenta. Acima disso não engata.
func limite_engate() -> float:
	return [0.0, 2400.0, 3800.0, 5600.0][nivel("chassi")]

## Capacidade de resfriar o motor (0..1).
func dissipacao() -> float:
	return 0.15 + nivel("arrefecimento") * 0.1 + nivel("cambio") * 0.03 - nivel("turbo") * 0.05

func posicao_assento() -> Vector3:
	return ASSENTO + Vector3(0, elevacao() + raio_roda() - 0.46, 0)

func aderencia_fora() -> float:
	return 0.55 + nivel("pneus") * 0.15

func tanque_litros() -> float:
	return 80.0 if nivel("tanque") <= 1 else 130.0

func peso_total() -> float:
	var p := 2300.0
	for slot in config:
		p += MODULOS[slot].peso * config[slot].nivel
	return p

func melhorar(slot: String) -> bool:
	var c: Dictionary = config[slot]
	if c.nivel >= MODULOS[slot].nivel_max:
		return false
	c.nivel += 1
	if c.nivel == 1:
		c.condicao = 1.0
	reconstruir()
	return true

func reparar(slot: String, quantidade := 1.0) -> void:
	config[slot].condicao = minf(1.0, config[slot].condicao + quantidade)
	reconstruir()

func danificar(slot: String, quantidade: float) -> void:
	config[slot].condicao = maxf(0.0, config[slot].condicao - quantidade)
	reconstruir()

func nome_exibicao() -> String:
	return "Picape"

# ---------------------------------------------------------------- visual
var farol := false
var _farois: Node3D

func ligar_farol(v: bool) -> void:
	if v == farol:
		return
	farol = v
	if is_instance_valid(_farois):
		_farois.visible = v

func reconstruir() -> void:
	for c in get_children():
		c.queue_free()
	_rng.seed = 991
	_pinturas.clear()
	var hw := LARGURA * 0.5
	var lift := elevacao()
	var rr := raio_roda()
	_corpo = Node3D.new()
	_corpo.position.y = lift + (rr - 0.46)
	add_child(_corpo)
	var b := _corpo
	var pintura := B.pintura(cor, condicao, 0.55, 0.35, 1.05)
	_pinturas.append(pintura)
	var preto := B.mat(Color(0.05, 0.05, 0.055), 0.6, 0.3)
	var plastico := B.mat(Color(0.08, 0.08, 0.08), 0.85)
	var aco := B.mat(Color(0.12, 0.12, 0.13), 0.45, 0.7)
	var vidro := B.mat(Color(0.04, 0.05, 0.06), 0.05, 0.6, "vidro_carro")
	if modo_cabine:
		vidro = _vidro_cabine()

	# cabine + capô
	var perfil := PackedVector2Array([
		Vector2(-0.78, 0.62), Vector2(1.06, 0.62), Vector2(1.14, 0.9), Vector2(1.34, 1.07),
		Vector2(1.9, 1.07), Vector2(2.1, 0.9), Vector2(2.18, 0.62), Vector2(2.55, 0.62), Vector2(2.7, 0.82), Vector2(2.66, 1.18),
		Vector2(1.18, 1.27), Vector2(0.42, 1.86), Vector2(-0.72, 1.88), Vector2(-0.78, 1.3)])
	B.extruded(b, perfil, LARGURA, Vector3.ZERO, pintura)
	var jan := PackedVector2Array([Vector2(-0.62, 1.32), Vector2(1.0, 1.32), Vector2(0.45, 1.79), Vector2(-0.62, 1.8)])
	B.extruded(b, jan, LARGURA + 0.01, Vector3.ZERO, vidro)
	for s in [-1.0, 1.0]:
		B.box(b, Vector3(0.09, 0.5, 0.07), Vector3(s * (hw - 0.035), 1.55, 0.2), pintura)
	var pb := B.box(b, Vector3(LARGURA - 0.16, 0.015, 0.93), Vector3(0, 1.57, 0.8), vidro)
	pb.rotation_degrees.x = 37.0
	B.box(b, Vector3(LARGURA - 0.3, 0.42, 0.02), Vector3(0, 1.56, -0.785), vidro)
	for z in [-0.72, 0.2, 1.12]:
		B.box(b, Vector3(LARGURA + 0.01, 0.34, 0.012), Vector3(0, 1.12, z), preto)
	for s in [-1.0, 1.0]:
		for z in [-0.2, 0.75]:
			B.box(b, Vector3(0.03, 0.03, 0.14), Vector3(s * (hw + 0.01), 1.18, z), preto)
		B.box(b, Vector3(0.22, 0.16, 0.08), Vector3(s * (hw + 0.14), 1.42, 1.08), plastico)
	if nivel("motor") >= 3:
		B.box(b, Vector3(0.6, 0.08, 0.5), Vector3(0, 1.28, 1.9), preto)  # tomada de ar no capô

	# caçamba
	var zc0 := -2.72
	var zc1 := -0.82
	var compc := zc1 - zc0
	var zm := (zc0 + zc1) * 0.5
	B.box(b, Vector3(LARGURA - 0.56, 0.14, compc), Vector3(0, 0.69, zm), pintura)
	B.box(b, Vector3(LARGURA - 0.1, 0.06, compc), Vector3(0, 1.1, zm), pintura)
	var lado := PackedVector2Array([Vector2(zc0, 0.62), Vector2(-2.34, 0.62), Vector2(-2.26, 0.9), Vector2(-2.06, 1.07),
		Vector2(-1.5, 1.07), Vector2(-1.3, 0.9), Vector2(-1.22, 0.62), Vector2(zc1, 0.62), Vector2(zc1, 1.29), Vector2(zc0, 1.29)])
	for s in [-1.0, 1.0]:
		B.extruded(b, lado, 0.08, Vector3(s * (hw - 0.04), 0, 0), pintura)
		B.box(b, Vector3(0.12, 0.03, compc), Vector3(s * (hw - 0.04), 1.29, zm), preto)
	B.box(b, Vector3(LARGURA, 0.56, 0.08), Vector3(0, 1.0, zc0 + 0.04), pintura)
	B.box(b, Vector3(0.3, 0.05, 0.02), Vector3(0, 1.12, zc0 - 0.005), preto)
	B.box(b, Vector3(LARGURA - 0.16, 0.02, compc - 0.1), Vector3(0, 0.77, zm), plastico)

	# frente
	B.box(b, Vector3(1.5, 0.36, 0.05), Vector3(0, 0.98, 2.68), preto)
	for k in range(-5, 6):
		B.box(b, Vector3(0.02, 0.32, 0.06), Vector3(k * 0.13, 0.98, 2.69), aco)
	for s in [-1.0, 1.0]:
		B.box(b, Vector3(0.24, 0.12, 0.05), Vector3(s * 0.8, 1.05, 2.66), B.mat(Color(0.75, 0.75, 0.7), 0.15, 0.5))
	# faróis (acendem sozinhos à noite, na neblina e na chuva forte)
	_farois = Node3D.new()
	_farois.name = "Farois"
	b.add_child(_farois)
	for s in [-1.0, 1.0]:
		B.box(_farois, Vector3(0.22, 0.1, 0.02), Vector3(s * 0.8, 1.05, 2.69), B.emissive(Color(1.0, 0.95, 0.8), 3.0))
		var sp := SpotLight3D.new()
		sp.position = Vector3(s * 0.8, 1.05, 2.75)
		sp.rotation_degrees = Vector3(-6, 180, 0)
		sp.light_color = Color(1.0, 0.94, 0.8)
		sp.light_energy = 16.0
		sp.spot_range = 55.0
		sp.spot_angle = 26.0
		sp.spot_attenuation = 0.5
		sp.shadow_enabled = false
		_farois.add_child(sp)
	_farois.visible = farol
	_parachoque(b, aco, plastico)
	_trofeus(b)
	B.box(b, Vector3(LARGURA, 0.16, 0.15), Vector3(0, 0.6, -2.78), aco)
	B.box(b, Vector3(0.08, 0.08, 0.2), Vector3(0, 0.55, -2.85), aco)
	B.sphere(b, 0.05, Vector3(0, 0.62, -2.88), B.mat(Color(0.6, 0.6, 0.6), 0.3, 0.9))
	for s in [-1.0, 1.0]:
		B.box(b, Vector3(0.1, 0.3, 0.04), Vector3(s * (hw - 0.08), 1.08, zc0 - 0.02), B.emissive(Color(0.6, 0.04, 0.02), 0.4))

	# rodas (ficam no chão; o corpo sobe com a suspensão)
	var largura_pneu := 0.32 + (nivel("pneus") - 1) * 0.03
	for z in [-1.78, 1.62]:
		for s in [-1.0, 1.0]:
			B.wheel(self, Vector3(s * (hw - 0.08 + (nivel("pneus") - 1) * 0.04), rr, z), rr, largura_pneu)
			var fl := PackedVector2Array([Vector2(-0.6, 0.6), Vector2(-0.42, 1.0), Vector2(0.42, 1.0), Vector2(0.6, 0.6), Vector2(0.52, 0.6), Vector2(0.37, 0.92), Vector2(-0.37, 0.92), Vector2(-0.52, 0.6)])
			B.extruded(b, fl, 0.14 + (nivel("pneus") - 1) * 0.04, Vector3(s * (hw + 0.03), 0, z), plastico)
		if lift > 0.0:
			B.cyl(self, 0.05, LARGURA - 0.3, Vector3(0, rr, z), aco, Vector3(0, 0, 90), 8)
			for s in [-1.0, 1.0]:
				B.cyl(self, 0.04, 0.35 + lift, Vector3(s * 0.6, rr + 0.25, z + 0.15), B.mat(Color(0.75, 0.6, 0.1), 0.4, 0.6), Vector3.ZERO, 8)
	for s in [-1.0, 1.0]:
		B.box(b, Vector3(0.18, 0.05, 1.8), Vector3(s * (hw + 0.05), 0.42, 0.2), aco)

	_santo_antonio(b, preto)
	_mecanica(b, aco, preto)
	if modo_cabine:
		_cabine(b)
	_protecao(b, nivel("protecao"))
	if nivel("snorkel") >= 1:
		B.cyl(b, 0.05, 1.0, Vector3(-hw - 0.06, 1.4, 1.2), preto, Vector3.ZERO, 10)
		B.box(b, Vector3(0.12, 0.12, 0.2), Vector3(-hw - 0.06, 1.95, 1.25), preto)
		B.cyl(b, 0.05, 0.25, Vector3(-hw + 0.05, 0.92, 1.2), preto, Vector3(0, 0, 90), 10)
	_cacamba(b, nivel("cacamba"))
	_espinhos(b, nivel("espinhos"))
	_posto_tiro(b, nivel("posto_tiro"))

## Espinhos de vergalhão soldados na lataria (portas, caixa de roda, caçamba).
func _espinhos(b: Node3D, n: int) -> void:
	if n <= 0:
		return
	var hw := LARGURA * 0.5
	var aco := B.mat(B.worn(Color(0.2, 0.19, 0.18), config.espinhos.condicao), 0.55, 0.7)
	var ferrugem := B.mat(Color(0.35, 0.18, 0.08), 0.9, 0.3)
	for s in [-1.0, 1.0]:
		# barra de apoio ao longo da lateral
		B.box(b, Vector3(0.05, 0.06, 4.4), Vector3(s * (hw + 0.05), 0.95, -0.5), aco)
		var qtd := 11 if n == 1 else 16
		for i in qtd:
			var z := -2.6 + i * (4.2 / (qtd - 1))
			var y := 0.95 + (0.18 if i % 2 == 0 else -0.12)
			var e := B.cyl(b, 0.025, 0.42 if n == 1 else 0.55, Vector3(s * (hw + 0.24), y, z), aco if i % 3 else ferrugem, Vector3(0, 0, 90), 5, 0.002)
			e.rotation_degrees = Vector3(0, 0, -90.0 * s)
		if n >= 2:
			# lâminas nas caixas de roda e na janela
			for z in [-1.78, 1.62]:
				B.box(b, Vector3(0.03, 0.08, 0.9), Vector3(s * (hw + 0.12), 1.12, z), aco, Vector3(0, 0, 25 * s))
			for k in 5:
				B.cyl(b, 0.02, 0.3, Vector3(s * (hw + 0.14), 1.52, 0.1 + k * 0.18), aco, Vector3(0, 0, -90.0 * s), 5, 0.002)

## Posto de tiro: plataforma na caçamba com apoio para o rifle (nível 2: escudo de chapa).
func _posto_tiro(b: Node3D, n: int) -> void:
	if n <= 0:
		return
	var aco := B.mat(Color(0.14, 0.14, 0.15), 0.5, 0.6)
	var chapa := B.mat(B.worn(Color(0.3, 0.31, 0.28), config.posto_tiro.condicao), 0.6, 0.6)
	B.box(b, Vector3(1.1, 0.06, 0.9), Vector3(0, 0.98, -1.65), aco)
	for s in [-1.0, 1.0]:
		B.box(b, Vector3(0.04, 0.9, 0.04), Vector3(s * 0.55, 1.45, -1.2), aco)
	B.box(b, Vector3(1.14, 0.04, 0.04), Vector3(0, 1.9, -1.2), aco)
	if n >= 2:
		B.box(b, Vector3(1.4, 0.5, 0.03), Vector3(0, 2.15, -1.12), chapa, Vector3(-12, 0, 0))
		B.box(b, Vector3(0.2, 0.12, 0.035), Vector3(0, 2.2, -1.1), B.mat(Color(0.02, 0.02, 0.02), 0.9))

func _parachoque(b: Node3D, aco: Material, plastico: Material) -> void:
	var n := nivel("parachoque")
	if n <= 1:
		B.box(b, Vector3(LARGURA, 0.18, 0.15), Vector3(0, 0.62, 2.72), plastico)
		return
	B.box(b, Vector3(LARGURA + 0.1, 0.24, 0.22), Vector3(0, 0.62, 2.75), aco)
	for s in [-1.0, 1.0]:
		B.cyl(b, 0.035, 0.6, Vector3(s * 0.55, 0.92, 2.85), aco, Vector3(-20, 0, 0), 8)
	B.box(b, Vector3(1.2, 0.04, 0.04), Vector3(0, 1.18, 2.93), aco)
	B.cyl(b, 0.08, 0.5, Vector3(0, 0.6, 2.88), B.mat(Color(0.15, 0.15, 0.15), 0.5, 0.6), Vector3(0, 0, 90), 10)
	if n >= 3:
		# quebra-mato completo com lâmina para empurrar
		var lam := B.box(b, Vector3(LARGURA + 0.2, 0.5, 0.05), Vector3(0, 0.5, 3.05), B.mat(Color(0.18, 0.18, 0.18), 0.5, 0.7))
		lam.rotation_degrees.x = -15
		for k in range(-3, 4):
			B.box(b, Vector3(0.06, 0.55, 0.06), Vector3(k * 0.3, 0.52, 3.08), aco, Vector3(-15, 0, 0))
		B.box(b, Vector3(1.0, 0.1, 0.1), Vector3(0, 1.22, 2.95), B.emissive(Color(1.0, 0.95, 0.8), 1.0))

func _trofeus(b: Node3D) -> void:
	if trofeus <= 0:
		return
	var osso := B.mat(Color(0.82, 0.78, 0.66), 0.75, 0.0, "cranio")
	var buraco := B.mat(Color(0.05, 0.04, 0.03), 1.0, 0.0, "cranio_olho")
	var arame := B.mat(Color(0.3, 0.3, 0.3), 0.5, 0.8)
	var xs := [-0.5, 0.5, -0.16, 0.16]
	for i in trofeus:
		var p := Vector3(xs[i], 1.0 if nivel("parachoque") >= 2 else 0.86, 2.98 if nivel("parachoque") >= 2 else 2.84)
		B.sphere(b, 0.13, p + Vector3(0, 0.05, 0), osso, Vector3(0.95, 1.0, 1.05), 10)
		B.box(b, Vector3(0.15, 0.08, 0.12), p + Vector3(0, -0.08, 0.03), osso)
		for s in [-1.0, 1.0]:
			B.sphere(b, 0.035, p + Vector3(s * 0.05, 0.05, 0.11), buraco, Vector3(1, 1.1, 0.6), 6)
		B.box(b, Vector3(0.03, 0.04, 0.02), p + Vector3(0, -0.01, 0.12), buraco)
		B.cyl(b, 0.006, 0.25, p + Vector3(0, 0.18, -0.02), arame, Vector3.ZERO, 3)

func _santo_antonio(b: Node3D, preto: Material) -> void:
	var n := nivel("santo_antonio")
	if n <= 0:
		return
	var hw := LARGURA * 0.5
	var zr := -1.05
	for s in [-1.0, 1.0]:
		B.cyl(b, 0.04, 0.75, Vector3(s * (hw - 0.12), 1.62, zr), preto, Vector3.ZERO, 8)
		B.cyl(b, 0.035, 1.0, Vector3(s * (hw - 0.12), 1.55, zr - 0.45), preto, Vector3(-55, 0, 0), 8)
	B.cyl(b, 0.04, LARGURA - 0.2, Vector3(0, 2.0, zr), preto, Vector3(0, 0, 90), 8)
	if n >= 2:
		for k in 4:
			var x := -0.6 + k * 0.4
			B.box(b, Vector3(0.16, 0.14, 0.1), Vector3(x, 2.1, zr + 0.02), preto)
			B.cyl(b, 0.055, 0.02, Vector3(x, 2.1, zr + 0.08), B.mat(Color(0.75, 0.75, 0.65), 0.1, 0.4), Vector3(90, 0, 0), 12)
	if n >= 3:
		# bagageiro sobre a cabine com caixa e pneu
		for s in [-1.0, 1.0]:
			B.box(b, Vector3(0.04, 0.04, 1.3), Vector3(s * 0.8, 1.98, 0.0), preto)
		for z in range(-3, 4):
			B.box(b, Vector3(1.6, 0.03, 0.03), Vector3(0, 1.96, z * 0.18), preto)
		B.box(b, Vector3(0.9, 0.3, 0.55), Vector3(0.25, 2.12, -0.2), B.mat(Color(0.15, 0.17, 0.12), 0.7))
		var pn := B.wheel(b, Vector3(-0.5, 2.08, 0.3), 0.4, 0.24)
		pn.rotation_degrees.z = 90

func _protecao(b: Node3D, n: int) -> void:
	if n <= 0:
		return
	var hw := LARGURA * 0.5
	var grade := B.mat(Color(0.05, 0.05, 0.05), 0.6, 0.5)
	for s in [-1.0, 1.0]:
		for k in range(0, 9):
			var z := -0.6 + k * 0.18
			var topo := 1.79 if z < 0.45 else 1.79 - (z - 0.45) * 0.85
			var h := topo - 1.32
			if h > 0.05:
				B.box(b, Vector3(0.015, h, 0.015), Vector3(s * (hw + 0.025), 1.32 + h * 0.5, z), grade)
		B.box(b, Vector3(0.015, 0.015, 1.6), Vector3(s * (hw + 0.025), 1.55, 0.18), grade)
	# tela no para-brisa
	for k in range(-5, 6):
		var t := B.box(b, Vector3(0.015, 0.015, 0.95), Vector3(k * 0.15, 1.585, 0.81), grade)
		t.rotation_degrees.x = 37
	if n >= 2:
		var chapa := B.mat(Color(0.3, 0.31, 0.3), 0.5, 0.7)
		for s in [-1.0, 1.0]:
			B.box(b, Vector3(0.02, 0.24, 1.55), Vector3(s * (hw + 0.035), 1.45, 0.15), chapa)
		B.box(b, Vector3(LARGURA - 0.3, 0.22, 0.02), Vector3(0, 1.5, -0.8), chapa)

func _cacamba(b: Node3D, n: int) -> void:
	B.box(b, Vector3(0.7, 0.4, 0.5), Vector3(-0.45, 0.98, -2.2), B.mat(Color(0.18, 0.22, 0.15), 0.8))
	B.jerrycan(b, Vector3(0.6, 0.78, -2.3), Color(0.25, 0.32, 0.18), Vector3(0, 90, 0))
	B.jerrycan(b, Vector3(0.6, 0.78, -1.9), Color(0.7, 0.1, 0.05), Vector3(0, 90, 0))
	if nivel("tanque") >= 2:
		B.cyl(b, 0.28, 1.2, Vector3(0, 1.06, -1.15), B.mat(Color(0.55, 0.55, 0.52), 0.4, 0.7), Vector3(0, 0, 90), 14)
		B.cyl(b, 0.04, 0.12, Vector3(0.3, 1.38, -1.15), B.mat(Color(0.7, 0.1, 0.05), 0.5), Vector3.ZERO, 8)
	else:
		var lona := B.box(b, Vector3(0.9, 0.18, 0.6), Vector3(0.1, 0.9, -1.4), B.mat(Color(0.3, 0.28, 0.22), 1.0))
		lona.rotation_degrees.y = 12
	if n >= 2:
		# rack de caçamba alto
		var preto := B.mat(Color(0.06, 0.06, 0.06), 0.6, 0.4)
		for s in [-1.0, 1.0]:
			for z in [-2.6, -1.0]:
				B.box(b, Vector3(0.04, 0.6, 0.04), Vector3(s * 0.88, 1.58, z), preto)
			B.box(b, Vector3(0.04, 0.04, 1.65), Vector3(s * 0.88, 1.88, -1.8), preto)
		for z in [-2.6, -1.8, -1.0]:
			B.box(b, Vector3(1.8, 0.04, 0.04), Vector3(0, 1.88, z), preto)
		B.box(b, Vector3(1.4, 0.28, 0.9), Vector3(0, 2.05, -1.9), B.mat(Color(0.22, 0.24, 0.18), 0.95))  # carga amarrada
	if n >= 3:
		for i in 3:
			B.box(b, Vector3(0.45, 0.35, 0.4), Vector3(-0.5 + i * 0.5, 2.36, -2.1 + i * 0.1), B.mat(Color(0.35, 0.27, 0.18), 0.9))

func _vidro_cabine() -> StandardMaterial3D:
	var k := "vidro_cabine"
	if not B._mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 0.35, 0.38, 0.12)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		B._mats[k] = m
	return B._mats[k]

## Peças mecânicas visíveis: radiador, intercooler do turbo, engate reforçado.
func _mecanica(b: Node3D, aco: Material, preto: Material) -> void:
	if nivel("arrefecimento") >= 2:
		B.box(b, Vector3(1.2, 0.3, 0.05), Vector3(0, 0.98, 2.62), B.mat(Color(0.35, 0.35, 0.36), 0.4, 0.8))
		for k in range(-7, 8):
			B.box(b, Vector3(0.01, 0.28, 0.06), Vector3(k * 0.08, 0.98, 2.63), aco)
	if nivel("arrefecimento") >= 3:
		for s in [-1.0, 1.0]:
			B.box(b, Vector3(0.3, 0.03, 0.4), Vector3(s * 0.45, 1.24, 2.0), preto)  # saídas de ar do capô
	if nivel("turbo") >= 1:
		B.box(b, Vector3(0.9, 0.18, 0.06), Vector3(0, 0.72, 2.7), B.mat(Color(0.5, 0.5, 0.52), 0.3, 0.9))
		B.cyl(b, 0.04, 0.6, Vector3(LARGURA * 0.5 - 0.1, 0.5, -2.3), B.mat(Color(0.3, 0.3, 0.3), 0.3, 0.9), Vector3(90, 0, 0), 8)
	if nivel("chassi") >= 2:
		# engate classe pesada: barra e correntes
		B.box(b, Vector3(0.7, 0.12, 0.25), Vector3(0, 0.5, -2.85), aco)
		for s in [-1.0, 1.0]:
			B.box(b, Vector3(0.04, 0.04, 0.3), Vector3(s * 0.28, 0.45, -2.95), B.mat(Color(0.5, 0.5, 0.5), 0.4, 0.8))
	if nivel("chassi") >= 3:
		for s in [-1.0, 1.0]:
			B.box(b, Vector3(0.1, 0.16, 4.6), Vector3(s * 0.55, 0.5, -0.1), aco)

## Interior da cabine (só montado quando a câmera está dentro).
func _cabine(b: Node3D) -> void:
	var hw := LARGURA * 0.5 - 0.04
	var painel := B.mat(Color(0.17, 0.16, 0.15), 0.8, 0.0, "cab_painel")
	var forro := B.mat(Color(0.32, 0.31, 0.29), 0.95, 0.0, "cab_forro")
	var banco := B.mat(Color(0.18, 0.16, 0.14), 0.9, 0.0, "cab_banco")
	var metal := B.mat(Color(0.4, 0.4, 0.4), 0.4, 0.8)
	# portas, teto e parede traseira
	for s in [-1.0, 1.0]:
		B.box(b, Vector3(0.04, 0.62, 1.9), Vector3(s * hw, 1.0, 0.2), forro)
		B.box(b, Vector3(0.12, 0.04, 1.6), Vector3(s * (hw - 0.05), 1.3, 0.25), painel)  # apoio de braço / soleira da janela
		# colunas A
		var ca := B.box(b, Vector3(0.08, 0.06, 0.95), Vector3(s * (hw - 0.03), 1.57, 0.8), painel)
		ca.rotation_degrees.x = 37
	B.box(b, Vector3(LARGURA - 0.1, 0.03, 1.1), Vector3(0, 1.84, -0.2), forro)
	B.box(b, Vector3(LARGURA - 0.1, 0.03, 0.25), Vector3(0, 1.83, 0.45), forro)
	B.box(b, Vector3(LARGURA - 0.1, 0.6, 0.04), Vector3(0, 1.0, -0.75), forro)
	B.box(b, Vector3(LARGURA - 0.1, 0.03, 1.9), Vector3(0, 0.66, 0.2), painel)  # assoalho
	# painel de instrumentos
	var pf := PackedVector2Array([Vector2(0.9, 0.66), Vector2(1.2, 0.66), Vector2(1.2, 1.28), Vector2(0.98, 1.32), Vector2(0.78, 1.28), Vector2(0.78, 1.0)])
	B.extruded(b, pf, LARGURA - 0.1, Vector3.ZERO, painel)
	B.box(b, Vector3(0.5, 0.16, 0.06), Vector3(0.43, 1.33, 0.86), painel)  # capelinha dos relógios
	for dx in [-0.11, 0.11]:
		B.cyl(b, 0.065, 0.01, Vector3(0.43 + dx, 1.33, 0.825), B.emissive(Color(0.95, 0.65, 0.25), 0.6), Vector3(90, 0, 0), 18)
	B.box(b, Vector3(0.3, 0.12, 0.02), Vector3(0.0, 1.2, 0.79), B.emissive(Color(0.2, 0.5, 0.35), 0.4))  # rádio do painel
	B.box(b, Vector3(0.22, 0.25, 0.5), Vector3(0.0, 0.85, 0.3), painel)  # console central
	B.cyl(b, 0.02, 0.22, Vector3(0.0, 1.03, 0.25), metal, Vector3(-15, 0, 0), 6)  # alavanca
	B.sphere(b, 0.035, Vector3(0.0, 1.14, 0.22), painel)
	# volante
	volante = Node3D.new()
	volante.position = Vector3(0.43, 1.2, 0.66)
	volante.rotation_degrees.x = -58
	b.add_child(volante)
	var aro := B.cyl(volante, 0.17, 0.03, Vector3.ZERO, painel, Vector3.ZERO, 24)
	B.cyl(volante, 0.145, 0.035, Vector3.ZERO, B.mat(Color(0.02, 0.02, 0.02), 1.0), Vector3.ZERO, 24)
	aro.visible = true
	for a in [0.0, 120.0, 240.0]:
		var raio := B.box(volante, Vector3(0.025, 0.02, 0.17), Vector3.ZERO, painel)
		raio.rotation_degrees.y = a
		raio.position = Vector3(sin(deg_to_rad(a)) * 0.08, 0, cos(deg_to_rad(a)) * 0.08)
	B.cyl(volante, 0.05, 0.05, Vector3.ZERO, painel, Vector3.ZERO, 12)
	B.cyl(b, 0.03, 0.4, Vector3(0.43, 1.18, 0.86), painel, Vector3(28, 0, 0), 8)  # coluna de direção
	# bancos
	for x in [0.43, -0.43]:
		B.box(b, Vector3(0.5, 0.14, 0.5), Vector3(x, 0.95, 0.3), banco)
		var enc := B.box(b, Vector3(0.5, 0.6, 0.12), Vector3(x, 1.3, 0.02), banco)
		enc.rotation_degrees.x = -10
		B.box(b, Vector3(0.26, 0.18, 0.1), Vector3(x, 1.72, -0.04), banco)
	# retrovisor interno, quebra-sol e um rosário pendurado (toque pessoal)
	B.box(b, Vector3(0.24, 0.07, 0.03), Vector3(0, 1.74, 0.62), painel)
	B.box(b, Vector3(0.22, 0.06, 0.02), Vector3(0, 1.74, 0.605), B.mat(Color(0.5, 0.55, 0.6), 0.1, 0.8))
	for s in [-1.0, 1.0]:
		var qs := B.box(b, Vector3(0.5, 0.02, 0.2), Vector3(s * 0.43, 1.8, 0.6), forro)
		qs.rotation_degrees.x = 12
	B.cyl(b, 0.003, 0.18, Vector3(0, 1.62, 0.62), painel, Vector3.ZERO, 4)
	B.sphere(b, 0.015, Vector3(0, 1.52, 0.62), B.mat(Color(0.6, 0.45, 0.2), 0.4, 0.5))
