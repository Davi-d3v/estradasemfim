class_name Reboque
extends Node3D
## Reboques extras que se engatam atrás do trailer (ou de outro reboque).
## Todos compartilham o chassi; o "tipo" define a carroceria e a função.

const TIPOS := {
	"armazem": {"nome": "Armazém", "comp": 4.2, "larg": 2.0, "nivel_max": 3, "peso": 520.0,
		"desc": "Guarda recursos", "capacidade": [0, 120, 200, 320], "unidade": "itens", "cor": Color(0.55, 0.57, 0.52)},
	"tanque": {"nome": "Tanque de diesel", "comp": 3.6, "larg": 1.8, "nivel_max": 3, "peso": 380.0,
		"desc": "Reserva de combustível", "capacidade": [0, 250, 450, 700], "unidade": "L", "cor": Color(0.75, 0.73, 0.68)},
	"oficina": {"nome": "Oficina móvel", "comp": 3.8, "larg": 2.0, "nivel_max": 3, "peso": 600.0,
		"desc": "Fabrica peças com sucata", "capacidade": [0, 1, 2, 3], "unidade": "peças/hora", "cor": Color(0.2, 0.32, 0.45)},
	"estufa": {"nome": "Estufa", "comp": 3.6, "larg": 1.9, "nivel_max": 3, "peso": 420.0,
		"desc": "Cultiva comida e coleta água", "capacidade": [0, 4, 8, 14], "unidade": "rações/dia", "cor": Color(0.3, 0.38, 0.22)},
	"apartamentos": {"nome": "Apartamentos", "comp": 4.8, "larg": 2.1, "nivel_max": 3, "peso": 640.0,
		"desc": "Camas para recrutas", "capacidade": [0, 2, 4, 6], "unidade": "camas", "cor": Color(0.62, 0.5, 0.36)},
	"plataforma": {"nome": "Plataforma de carga", "comp": 4.0, "larg": 2.0, "nivel_max": 3, "peso": 300.0,
		"desc": "Leva carga pesada e uma moto", "capacidade": [0, 80, 140, 220], "unidade": "itens", "cor": Color(0.35, 0.18, 0.12)},
}

@export var tipo := "armazem"
@export var nivel := 1
@export var condicao := 0.7
@export var abandonado := false
@export var aberto := false   # porta do armazém / tampas abertas

const DEFEITOS := {
	"pneus": {"nome": "Pneus estourados", "itens": {"pneu": 2}, "horas": 1.5},
	"eixo": {"nome": "Eixo partido", "itens": {"eixo": 1, "pecas": 2}, "horas": 3.0},
	"engate": {"nome": "Engate travado", "itens": {"pecas": 3, "sucata": 6}, "horas": 2.0},
	"freios": {"nome": "Freios colados", "itens": {"pecas": 2}, "horas": 1.0},
}

## Problemas que impedem de engatar (reboques achados abandonados).
var defeitos: Array[String] = []
## Itens que ainda estão dentro (saque). Vazio depois de saqueado.
var saque: Dictionary = {}
var litros := 0.0          # tanque de diesel
var comida := 0.0          # estufa: produção acumulada
var agua := 0.0
var trabalho: Dictionary = {}   # oficina: tarefa em andamento
var moradores: Array = []       # apartamentos: recrutas que dormem aqui (Dictionaries)
var dormindo := false           # apartamentos: mostra os recrutas deitados

func salvar() -> Dictionary:
	return {"tipo": tipo, "nivel": nivel, "condicao": condicao, "defeitos": defeitos.duplicate(),
		"saque": saque.duplicate(true), "litros": litros, "abandonado": abandonado}

func carregar(d: Dictionary) -> void:
	tipo = d.tipo
	nivel = d.nivel
	condicao = d.condicao
	defeitos.assign(d.defeitos)
	saque = d.saque.duplicate(true)
	litros = d.litros
	abandonado = d.abandonado

## Precisa estar consertado para cumprir sua função.
func funcional() -> bool:
	return condicao >= 0.5 and defeitos.is_empty()

func pode_engatar() -> bool:
	return defeitos.is_empty()

func capacidade_carga() -> int:
	if tipo in ["armazem", "plataforma"] and funcional():
		return capacidade()
	return 0

func ponto_entrada() -> Vector3:
	var hz := comprimento() * 0.5
	var hw: float = info().larg * 0.5
	match tipo:
		"armazem", "estufa", "apartamentos":
			return Vector3(0, 0, -hz - 0.8)
		"tanque":
			return Vector3(hw + 0.7, 0, hz - 0.2)
		_:
			return Vector3(hw + 0.7, 0, -0.6)

## Tanque não tem interior: abre o painel da bomba.
func tem_interior() -> bool:
	return tipo != "tanque"

func interior() -> Dictionary:
	var hz := comprimento() * 0.5
	var hw: float = info().larg * 0.5
	match tipo:
		"armazem":
			return {"limites": AABB(Vector3(-0.35, 0, -hz + 0.35), Vector3(0.7, 0, comprimento() - 0.75)),
				"piso": 0.785, "olho": 1.6, "inicio": Vector3(0, 0, -hz + 0.5), "yaw": 0.0,
				"interativos": [
					{"id": "estoque", "nome": "Prateleiras: ver estoque", "pos": Vector3(-0.72, 1.3, 0.0)},
					{"id": "estoque", "nome": "Prateleiras: ver estoque", "pos": Vector3(0.72, 1.3, 0.6)},
					{"id": "sair", "nome": "Sair", "pos": Vector3(0, 1.4, -hz)}]}
		"apartamentos":
			var its: Array = [
				{"id": "recrutas", "nome": "Quadro dos recrutas", "pos": Vector3(-hw + 0.4, 1.45, -hz + 0.08)},
				{"id": "sair", "nome": "Sair", "pos": Vector3(0, 1.4, -hz)}]
			for i in capacidade():
				var c := cama(i)
				var quem := ("Cama de %s" % moradores[i].nome) if i < moradores.size() else "Cama vazia"
				its.append({"id": "cama", "nome": quem, "pos": c.position + Vector3(0, 0.3, 0)})
			return {"limites": AABB(Vector3(-0.2, 0, -hz + 0.35), Vector3(0.4, 0, comprimento() - 1.3)),
				"piso": 0.76, "olho": 1.62, "inicio": Vector3(0, 0, -hz + 0.5), "yaw": 0.0, "interativos": its}
		"estufa":
			return {"limites": AABB(Vector3(-0.27, 0, -hz + 0.35), Vector3(0.54, 0, comprimento() - 0.7)),
				"piso": 0.76, "olho": 1.4, "inicio": Vector3(0, 0, -hz + 0.45), "yaw": 0.0,
				"interativos": [
					{"id": "colher", "nome": "Colher a horta", "pos": Vector3(-0.6, 1.1, -0.3)},
					{"id": "colher", "nome": "Colher a horta", "pos": Vector3(0.6, 1.1, 0.5)},
					{"id": "agua", "nome": "Coletar água da cisterna", "pos": Vector3(0, 1.0, hz - 0.05)},
					{"id": "sair", "nome": "Sair", "pos": Vector3(0, 1.3, -hz)}]}
		"oficina":
			return {"limites": AABB(Vector3(-0.8, 0, -1.65), Vector3(1.6, 0, 1.8)),
				"piso": 0.76, "olho": 1.6, "inicio": Vector3(0.6, 0, -0.6), "yaw": 0.0,
				"interativos": [
					{"id": "bancada", "nome": "Bancada de trabalho", "pos": Vector3(0, 1.7, 0.6)},
					{"id": "gerador", "nome": "Gerador", "pos": Vector3(-0.5, 1.1, -1.0)},
					{"id": "sair", "nome": "Descer", "pos": Vector3(hw, 1.0, -0.6)}]}
		"plataforma":
			var its: Array = [
				{"id": "estoque", "nome": "Carga amarrada: ver estoque", "pos": Vector3(0, 1.2, 0.9)},
				{"id": "sair", "nome": "Descer", "pos": Vector3(hw, 1.0, -0.5)}]
			if nivel >= 2:
				its.append({"id": "moto", "nome": "Moto", "pos": Vector3(0.1, 1.4, -1.3)})
			return {"limites": AABB(Vector3(-0.8, 0, -1.85), Vector3(1.6, 0, 1.95)),
				"piso": 0.8, "olho": 1.6, "inicio": Vector3(0.6, 0, -0.4), "yaw": 0.0, "interativos": its}
	return {}

## Gera defeitos e saque de um reboque achado abandonado.
func gerar_abandonado(r: RandomNumberGenerator) -> void:
	abandonado = true
	condicao = r.randf_range(0.15, 0.4)
	defeitos.clear()
	if r.randf() < 0.85:
		defeitos.append("pneus")
	for d in ["eixo", "engate", "freios"]:
		if r.randf() < 0.45:
			defeitos.append(d)
	if defeitos.size() < 2:
		defeitos.append("engate" if not defeitos.has("engate") else "freios")
	saque = {"sucata": r.randi_range(4, 18), "pecas": r.randi_range(0, 3), "comida": r.randi_range(0, 4), "agua": r.randi_range(0, 3)}
	if r.randf() < 0.35:
		saque["galoes_diesel"] = r.randi_range(1, 2)
	if r.randf() < 0.25:
		saque["pneu"] = 1
	if r.randf() < 0.3:
		var tipos := TIPOS.keys()
		saque["projeto"] = tipos[r.randi() % tipos.size()]
	if tipo == "tanque":
		litros = r.randf_range(50.0, 220.0)

var _root: Node3D
var _pinturas: Array[ShaderMaterial] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	reconstruir()

func _process(_dt: float) -> void:
	for m in _pinturas:
		B.atualizar_pintura(m, self)

func info() -> Dictionary:
	return TIPOS[tipo]

func comprimento() -> float:
	return info().comp

func engate_frente_z() -> float:
	return comprimento() * 0.5 + 1.3

func eixo_z() -> float:
	return -0.3

func engate_tras() -> Vector3:
	return Vector3(0, 0.6, -comprimento() * 0.5 - 0.4)

func feminino() -> bool:
	return tipo in ["oficina", "estufa", "plataforma"]

func abandonado_txt() -> String:
	if tipo == "apartamentos":
		return "abandonados"
	return "abandonada" if feminino() else "abandonado"

func nome_exibicao() -> String:
	return info().nome

func peso_total() -> float:
	return info().peso * (0.8 + 0.2 * nivel)

func capacidade() -> int:
	return int(info().capacidade[nivel])

func melhorar() -> bool:
	if nivel >= info().nivel_max:
		return false
	nivel += 1
	reconstruir()
	return true

func reparar(qtd := 1.0) -> void:
	condicao = minf(1.0, condicao + qtd)
	abandonado = false
	reconstruir()

func _pint(cor: Color, cond: float, rough := 0.7, metal := 0.15) -> ShaderMaterial:
	var m := B.pintura(cor, cond, rough, metal, 1.2)
	_pinturas.append(m)
	return m

func reconstruir() -> void:
	if _root:
		_root.queue_free()
	_pinturas.clear()
	_root = Node3D.new()
	add_child(_root)
	_rng.seed = hash(tipo) + nivel
	_chassi()
	call("_corpo_" + tipo)
	if is_inside_tree():
		call_deferred("_process", 0.0)

# ---------------------------------------------------------------- chassi comum
func _chassi() -> void:
	var r := _root
	var L := comprimento()
	var hz := L * 0.5
	var hw: float = info().larg * 0.5
	var aco := B.mat(Color(0.12, 0.12, 0.13), 0.5, 0.6)
	var preto := _pint(Color(0.07, 0.07, 0.07), condicao, 0.7, 0.2)
	# longarinas e assoalho
	for s in [-1.0, 1.0]:
		B.box(r, Vector3(0.12, 0.16, L + 0.1), Vector3(s * (hw - 0.25), 0.6, 0), aco)
	B.box(r, Vector3(hw * 2.0, 0.06, L), Vector3(0, 0.71, 0), preto)
	# lança em A
	for s in [-1.0, 1.0]:
		var v := B.box(r, Vector3(0.1, 0.1, 1.45), Vector3(s * 0.3, 0.6, hz + 0.55), aco)
		v.rotation.y = -s * 0.36
	B.box(r, Vector3(0.12, 0.12, 0.45), Vector3(0, 0.6, hz + 1.1), aco)
	B.box(r, Vector3(0.16, 0.1, 0.16), Vector3(0, 0.62, hz + 1.3), aco)
	B.cyl(r, 0.04, 0.5, Vector3(0.22, 0.36, hz + 0.9), aco, Vector3.ZERO, 8)
	# engate traseiro
	B.box(r, Vector3(0.12, 0.12, 0.45), Vector3(0, 0.6, -hz - 0.18), aco)
	B.sphere(r, 0.05, Vector3(0, 0.67, -hz - 0.4), B.mat(Color(0.6, 0.6, 0.6), 0.3, 0.9))
	# eixos: um no nível 1, dois a partir do nível 2 (armazém e plataforma)
	var duplo := nivel >= 2 and tipo in ["armazem", "plataforma", "tanque"]
	var eixos := [eixo_z() - 0.5, eixo_z() + 0.5] if duplo else [eixo_z()]
	var furado := defeitos.has("pneus")
	for ez in eixos:
		B.cyl(r, 0.05, hw * 2.0 + 0.2, Vector3(0, 0.42, ez), aco, Vector3(0, 0, 90), 8)
		for s in [-1.0, 1.0]:
			var y := 0.42
			if furado:
				y = 0.3 if s > 0.0 else 0.34
			B.wheel(r, Vector3(s * (hw + 0.08), y, ez), 0.42, 0.26)
			B.box(r, Vector3(0.32, 0.03, 0.95), Vector3(s * (hw + 0.08), 0.92, ez), preto)
	# lanternas
	for s in [-1.0, 1.0]:
		B.box(r, Vector3(0.16, 0.08, 0.04), Vector3(s * (hw - 0.15), 0.62, -hz - 0.05), B.emissive(Color(0.8, 0.05, 0.03), 0.5))
	if abandonado:
		# mato crescendo e sujeira
		for i in 10:
			var p := Vector3(_rng.randf_range(-hw, hw), 0.0, _rng.randf_range(-hz, hz))
			B.cyl(r, 0.0, 0.4 + _rng.randf() * 0.4, p + Vector3(0, 0.25, 0), B.mat(Color(0.25, 0.28, 0.1), 1.0), Vector3(_rng.randf_range(-15, 15), 0, 0), 4, 0.06)

# ---------------------------------------------------------------- tipos
func _corpo_armazem() -> void:
	var r := _root
	var L := comprimento()
	var hz := L * 0.5
	var hw: float = info().larg * 0.5
	var h := 1.9 + (nivel - 1) * 0.25
	var y0 := 0.74
	var cor: Color = info().cor
	var lataria := _pint(cor, condicao, 0.55, 0.45)
	var friso := _pint(cor.darkened(0.3), condicao, 0.5, 0.5)
	# caixa oca: laterais, teto, frente e piso (a traseira é a porta)
	for s in [-1.0, 1.0]:
		B.box(r, Vector3(0.04, h, L), Vector3(s * (hw - 0.02), y0 + h * 0.5, 0), lataria)
	B.box(r, Vector3(hw * 2.0, 0.04, L), Vector3(0, y0 + h - 0.02, 0), lataria)
	B.box(r, Vector3(hw * 2.0, h, 0.04), Vector3(0, y0 + h * 0.5, hz - 0.02), lataria)
	B.box(r, Vector3(hw * 2.0 - 0.08, 0.03, L - 0.05), Vector3(0, y0 + 0.02, 0), B.mat(Color(0.25, 0.22, 0.18), 0.9))
	# nervuras verticais (chapa corrugada)
	var n := int(L / 0.32)
	for i in n + 1:
		var z := -hz + i * (L / n)
		for s in [-1.0, 1.0]:
			B.box(r, Vector3(0.04, h - 0.1, 0.05), Vector3(s * (hw + 0.02), y0 + h * 0.5, z), friso)
	B.box(r, Vector3(hw * 2.0 + 0.08, 0.08, L + 0.06), Vector3(0, y0 + h, 0), friso)
	B.box(r, Vector3(hw * 2.0 + 0.08, 0.1, L + 0.06), Vector3(0, y0 + 0.05, 0), friso)
	# frente arredondada
	B.box(r, Vector3(hw * 2.0 - 0.1, h - 0.2, 0.08), Vector3(0, y0 + h * 0.5, hz + 0.03), friso)
	# porta de enrolar traseira
	var vao := Vector3(hw * 2.0 - 0.3, h - 0.25, 0.05)
	if aberto:
		B.box(r, Vector3(vao.x, 0.25, 0.05), Vector3(0, y0 + h - 0.2, -hz - 0.03), friso)
		# prateleiras com caixas visíveis
		for k in nivel + 1:
			var yy := y0 + 0.3 + k * 0.48
			for s in [-1.0, 1.0]:
				B.box(r, Vector3(0.5, 0.03, L * 0.8), Vector3(s * (hw - 0.3), yy, -0.2), B.mat(Color(0.4, 0.4, 0.4), 0.6, 0.5))
				for c in 4:
					var cx: float = s * (hw - 0.3)
					var cc := Color(0.45, 0.33, 0.2) if (c + k) % 3 != 0 else Color(0.25, 0.32, 0.2)
					B.box(r, Vector3(0.4, 0.3, 0.35), Vector3(cx, yy + 0.17, -hz + 0.4 + c * 0.6), B.mat(cc, 0.9))
		var luz := OmniLight3D.new()
		luz.light_color = Color(1, 0.75, 0.45)
		luz.light_energy = 0.8
		luz.omni_range = 3.0
		luz.position = Vector3(0, y0 + h - 0.3, -hz + 0.6)
		r.add_child(luz)
	else:
		B.box(r, Vector3(hw * 2.0, h, 0.04), Vector3(0, y0 + h * 0.5, -hz + 0.02), lataria)
		B.box(r, vao, Vector3(0, y0 + vao.y * 0.5 + 0.1, -hz - 0.03), friso)
		for k in int(vao.y / 0.12):
			B.box(r, Vector3(vao.x, 0.015, 0.06), Vector3(0, y0 + 0.16 + k * 0.12, -hz - 0.04), B.mat(Color(0.1, 0.1, 0.1), 0.8))
		B.box(r, Vector3(0.3, 0.05, 0.08), Vector3(0, y0 + 0.25, -hz - 0.07), B.mat(Color(0.6, 0.6, 0.6), 0.3, 0.9))
	# porta lateral e luz de teto
	B.box(r, Vector3(0.04, 1.5, 0.8), Vector3(hw + 0.03, y0 + 0.8, hz - 0.8), friso)
	if nivel >= 3:
		for i in 3:
			B.box(r, Vector3(0.5, 0.05, 0.9), Vector3(0, y0 + h + 0.08, -hz + 0.7 + i * 1.2), B.mat(Color(0.1, 0.13, 0.22), 0.2, 0.6))  # painéis solares

func _corpo_tanque() -> void:
	var r := _root
	var L := comprimento()
	var hz := L * 0.5
	var raio := 0.62 + (nivel - 1) * 0.08
	var cor: Color = info().cor
	var tanque := _pint(cor, condicao, 0.35, 0.7)
	var aco := B.mat(Color(0.2, 0.2, 0.2), 0.5, 0.6)
	B.cyl(r, raio, L - 0.3, Vector3(0, 0.8 + raio, 0), tanque, Vector3(90, 0, 0), 24)
	for s in [-1.0, 1.0]:
		B.sphere(r, raio, Vector3(0, 0.8 + raio, s * (L * 0.5 - 0.15)), tanque, Vector3(1, 1, 0.35), 16)
	for z in [-hz + 0.5, 0.0, hz - 0.5]:
		B.cyl(r, raio + 0.03, 0.08, Vector3(0, 0.8 + raio, z), aco, Vector3(90, 0, 0), 24)
	# faixa de perigo
	B.cyl(r, raio + 0.01, 0.35, Vector3(0, 0.8 + raio, -0.6), B.mat(Color(0.85, 0.6, 0.1), 0.6), Vector3(90, 0, 0), 24)
	# escotilha, escada, bomba e carretel de mangueira
	B.cyl(r, 0.2, 0.1, Vector3(0, 0.8 + raio * 2.0 + 0.03, 0.2), aco, Vector3.ZERO, 14)
	for k in 6:
		B.box(r, Vector3(0.35, 0.03, 0.03), Vector3(0, 0.85 + k * 0.22, -hz - 0.08), aco)
	for s in [-1.0, 1.0]:
		B.box(r, Vector3(0.03, 1.4, 0.03), Vector3(s * 0.17, 1.45, -hz - 0.08), aco)
	B.box(r, Vector3(0.4, 0.4, 0.3), Vector3(0.75, 0.95, hz - 0.2), B.mat(Color(0.7, 0.1, 0.06), 0.6))
	B.cyl(r, 0.22, 0.14, Vector3(-0.75, 1.0, hz - 0.25), B.mat(Color(0.1, 0.1, 0.1), 0.8), Vector3(0, 0, 90), 16)
	if nivel >= 3:
		B.cyl(r, 0.12, 0.6, Vector3(0.6, 0.8 + raio * 2.0, -0.6), aco, Vector3.ZERO, 10)  # filtro/decantador

func _corpo_oficina() -> void:
	var r := _root
	var L := comprimento()
	var hz := L * 0.5
	var hw: float = info().larg * 0.5
	var cor: Color = info().cor
	var lataria := _pint(cor, condicao, 0.55, 0.4)
	var aco := B.mat(Color(0.25, 0.25, 0.26), 0.45, 0.7)
	var madeira := B.mat(Color(0.42, 0.3, 0.18), 0.8)
	# laterais baixas
	for s in [-1.0, 1.0]:
		B.box(r, Vector3(0.05, 0.45, L), Vector3(s * hw, 0.97, 0), lataria)
	B.box(r, Vector3(hw * 2.0, 0.45, 0.05), Vector3(0, 0.97, hz), lataria)
	# bancada com morsa
	B.box(r, Vector3(1.6, 0.06, 0.7), Vector3(0, 1.62, 0.6), madeira)
	for s in [-1.0, 1.0]:
		for dz in [0.3, 0.9]:
			B.box(r, Vector3(0.05, 0.86, 0.05), Vector3(s * 0.75, 1.17, dz), aco)
	B.box(r, Vector3(0.16, 0.14, 0.22), Vector3(0.55, 1.73, 0.75), B.mat(Color(0.2, 0.35, 0.55), 0.5, 0.5))
	B.box(r, Vector3(1.4, 0.03, 0.4), Vector3(0, 1.1, 0.6), madeira)
	for i in 4:
		B.box(r, Vector3(0.12, 0.03, 0.03), Vector3(-0.5 + i * 0.25, 1.67, 0.45), aco, Vector3(0, i * 25.0, 0))
	# painel de ferramentas
	B.box(r, Vector3(1.6, 0.9, 0.03), Vector3(0, 2.1, 1.0), madeira)
	for i in 8:
		B.box(r, Vector3(0.04, 0.25, 0.02), Vector3(-0.65 + i * 0.18, 2.15, 0.98), aco, Vector3(0, 0, _rng.randf_range(-20, 20)))
	# gerador
	var ger := Node3D.new()
	ger.position = Vector3(-0.5, 0.74, -1.0)
	r.add_child(ger)
	B.box(ger, Vector3(0.7, 0.5, 0.5), Vector3(0, 0.3, 0), B.mat(Color(0.8, 0.55, 0.1), 0.6))
	for s in [-1.0, 1.0]:
		B.box(ger, Vector3(0.03, 0.65, 0.55), Vector3(s * 0.38, 0.35, 0), aco)
	B.box(ger, Vector3(0.78, 0.03, 0.03), Vector3(0, 0.68, 0), aco)
	# cilindros de solda e caixa de ferramentas
	for i in 2:
		B.cyl(r, 0.1, 0.85, Vector3(0.7, 1.18, -0.6 + i * 0.25), B.mat([Color(0.2, 0.4, 0.25), Color(0.7, 0.2, 0.1)][i], 0.4, 0.4), Vector3.ZERO, 12)
	B.box(r, Vector3(0.5, 0.3, 0.3), Vector3(0.45, 0.89, -1.4), B.mat(Color(0.7, 0.08, 0.06), 0.5, 0.3))
	if nivel >= 2:
		# lâmpada de trabalho no mastro
		B.cyl(r, 0.03, 1.8, Vector3(-hw + 0.1, 1.65, hz - 0.1), aco, Vector3.ZERO, 6)
		B.box(r, Vector3(0.2, 0.15, 0.1), Vector3(-hw + 0.1, 2.6, hz - 0.18), B.emissive(Color(1, 0.9, 0.7), 2.0))
	if nivel >= 3:
		# guindaste articulado
		B.cyl(r, 0.08, 1.3, Vector3(hw - 0.2, 1.4, -hz + 0.3), B.mat(Color(0.85, 0.6, 0.1), 0.5, 0.4), Vector3.ZERO, 10)
		var braco := B.box(r, Vector3(0.12, 0.12, 1.6), Vector3(hw - 0.2, 2.2, -hz + 0.9), B.mat(Color(0.85, 0.6, 0.1), 0.5, 0.4))
		braco.rotation_degrees.x = -18
		B.cyl(r, 0.01, 0.8, Vector3(hw - 0.2, 1.85, -hz + 1.6), aco, Vector3.ZERO, 4)

func _corpo_estufa() -> void:
	var r := _root
	var L := comprimento()
	var hz := L * 0.5
	var hw: float = info().larg * 0.5
	var aco := B.mat(Color(0.75, 0.75, 0.72), 0.4, 0.6)
	var terra := B.mat(Color(0.2, 0.14, 0.09), 1.0)
	var madeira := B.mat(Color(0.4, 0.28, 0.17), 0.9)
	# canteiros com plantas
	var fileiras := 2
	for f in fileiras:
		var x := -hw + 0.35 + f * ((hw * 2.0 - 0.7) / maxf(fileiras - 1, 1))
		B.box(r, Vector3(0.5, 0.25, L - 0.3), Vector3(x, 0.87, 0), madeira)
		B.box(r, Vector3(0.44, 0.03, L - 0.36), Vector3(x, 0.99, 0), terra)
		for k in int((L - 0.4) / 0.3):
			var z := -hz + 0.35 + k * 0.3
			var verde := Color(0.15, 0.4, 0.12).lerp(Color(0.3, 0.5, 0.15), _rng.randf())
			var pl := B.sphere(r, _rng.randf_range(0.1, 0.17) * (0.7 + nivel * 0.15), Vector3(x + _rng.randf_range(-0.08, 0.08), 1.1, z), B.mat(verde, 0.8), Vector3(1, 1.3, 1), 6)
			if _rng.randf() < 0.25:
				B.sphere(r, 0.04, pl.position + Vector3(0.05, 0.05, 0), B.mat(Color(0.85, 0.15, 0.08), 0.5), Vector3.ONE, 6)
	# estrutura em arco + painéis translúcidos
	var arcos := int(L / 0.6) + 1
	var raio := hw + 0.02
	for i in arcos:
		var z := -hz + i * (L / (arcos - 1))
		for k in 8:
			var a0 := PI * k / 8.0
			var a1 := PI * (k + 1) / 8.0
			var p0 := Vector3(cos(a0) * raio, 0.74 + sin(a0) * raio * 1.75, z)
			var p1 := Vector3(cos(a1) * raio, 0.74 + sin(a1) * raio * 1.75, z)
			var seg := B.box(r, Vector3(0.035, p0.distance_to(p1), 0.035), (p0 + p1) * 0.5, aco)
			seg.rotation.z = atan2(p1.y - p0.y, p1.x - p0.x) - PI * 0.5
	var plastico := StandardMaterial3D.new()
	plastico.albedo_color = Color(0.85, 0.9, 0.85, 0.28 + (1.0 - condicao) * 0.3)
	plastico.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plastico.roughness = 0.3
	plastico.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 8:
		var a0 := PI * k / 8.0
		var a1 := PI * (k + 1) / 8.0
		var p0 := Vector3(cos(a0) * raio, 0.74 + sin(a0) * raio * 1.75, 0)
		var p1 := Vector3(cos(a1) * raio, 0.74 + sin(a1) * raio * 1.75, 0)
		var pn := B.box(r, Vector3(0.01, p0.distance_to(p1), L), (p0 + p1) * 0.5, plastico)
		pn.rotation.z = atan2(p1.y - p0.y, p1.x - p0.x) - PI * 0.5
	# caixa d'água de chuva
	B.cyl(r, 0.3, 0.6, Vector3(0, 1.05, hz + 0.25), B.mat(Color(0.15, 0.25, 0.45), 0.5), Vector3.ZERO, 14)
	if nivel >= 2:
		var luz := OmniLight3D.new()
		luz.light_color = Color(0.9, 0.4, 1.0)
		luz.light_energy = 0.5
		luz.omni_range = 2.5
		luz.position = Vector3(0, 1.7, 0)
		r.add_child(luz)

## Posição (local) de cada cama: beliches nas laterais, o terceiro na parede da frente.
func cama(i: int) -> Dictionary:
	var hz := comprimento() * 0.5
	var hw: float = info().larg * 0.5
	var y0 := 0.78
	var andar := i % 2
	var y := y0 + 0.3 + andar * 0.95
	match i / 2:
		0:
			return {"position": Vector3(-hw + 0.42, y, hz - 1.95), "rot": 0.0}
		1:
			return {"position": Vector3(hw - 0.42, y, hz - 1.95), "rot": 0.0}
		_:
			return {"position": Vector3(0, y, hz - 0.5), "rot": PI * 0.5}

func _corpo_apartamentos() -> void:
	var r := _root
	var L := comprimento()
	var hz := L * 0.5
	var hw: float = info().larg * 0.5
	var h := 2.2
	var y0 := 0.74
	var cor: Color = info().cor
	var lataria := _pint(cor, condicao, 0.6, 0.25)
	var faixa := _pint(Color(0.86, 0.82, 0.72), condicao, 0.5, 0.2)
	var madeira := B.mat(Color(0.45, 0.31, 0.19), 0.8)
	var interno := B.mat(Color(0.78, 0.72, 0.6), 0.9)
	var aco := B.mat(Color(0.3, 0.3, 0.3), 0.5, 0.6)
	var vidro := B.mat(Color(0.12, 0.16, 0.18), 0.15, 0.3)
	# casca: laterais com janelas, teto, frente e traseira com porta
	for s in [-1.0, 1.0]:
		var x: float = s * (hw - 0.02)
		# painéis entre as janelas (3 janelas por lado)
		var zs := [-hz, -hz + 0.9, -hz + 1.5, -0.3, 0.5, 1.2, 1.9, hz]
		for k in range(0, zs.size() - 1):
			var za: float = zs[k]
			var zb: float = zs[k + 1]
			if k in [1, 3, 5]:
				# janela: peitoril e verga
				B.box(r, Vector3(0.05, 0.95, zb - za), Vector3(x, y0 + 0.475, (za + zb) * 0.5), lataria)
				B.box(r, Vector3(0.05, 0.55, zb - za), Vector3(x, y0 + h - 0.275, (za + zb) * 0.5), lataria)
				B.box(r, Vector3(0.02, 0.7, zb - za - 0.04), Vector3(x + s * 0.01, y0 + 1.3, (za + zb) * 0.5), vidro if k != 3 or condicao > 0.4 else B.mat(Color(0.4, 0.28, 0.16), 0.9))
				B.box(r, Vector3(0.07, 0.05, zb - za + 0.08), Vector3(x + s * 0.02, y0 + 0.95, (za + zb) * 0.5), faixa)
			else:
				B.box(r, Vector3(0.05, h, zb - za), Vector3(x, y0 + h * 0.5, (za + zb) * 0.5), lataria)
		B.box(r, Vector3(0.06, 0.18, L + 0.02), Vector3(s * hw, y0 + 0.55, 0), faixa)
		for zc in [-hz + 1.2, 0.1, 1.55]:
			B.box(r, Vector3(0.12, 0.04, 0.75), Vector3(s * (hw + 0.06), y0 + 1.72, zc), madeira)   # pingadeira das janelas
	B.box(r, Vector3(hw * 2.0, 0.05, L), Vector3(0, y0 + h, 0), lataria)
	B.box(r, Vector3(hw * 2.0 + 0.1, 0.08, L + 0.1), Vector3(0, y0 + h + 0.04, 0), faixa)
	B.box(r, Vector3(hw * 2.0, h, 0.05), Vector3(0, y0 + h * 0.5, hz - 0.02), lataria)
	# traseira com porta
	var pw := 0.75
	for s in [-1.0, 1.0]:
		var larg_lado: float = hw - pw * 0.5
		B.box(r, Vector3(larg_lado, h, 0.05), Vector3(s * (pw * 0.5 + larg_lado * 0.5), y0 + h * 0.5, -hz + 0.02), lataria)
	B.box(r, Vector3(pw, 0.25, 0.05), Vector3(0, y0 + h - 0.125, -hz + 0.02), lataria)
	var porta := B.box(r, Vector3(pw, h - 0.27, 0.04), Vector3(-pw * 0.5 + 0.02, y0 + (h - 0.27) * 0.5, -hz - 0.35), madeira)
	porta.rotation.y = deg_to_rad(-75)
	porta.position = Vector3(-pw * 0.5 - 0.08, y0 + (h - 0.27) * 0.5, -hz - 0.36)
	# degrau
	B.box(r, Vector3(0.7, 0.05, 0.35), Vector3(0, 0.42, -hz - 0.3), aco)
	# piso e paredes internas
	B.box(r, Vector3(hw * 2.0 - 0.1, 0.03, L - 0.1), Vector3(0, y0 + 0.02, 0), B.mat(Color(0.36, 0.26, 0.17), 0.85))
	for s in [-1.0, 1.0]:
		B.box(r, Vector3(0.01, h - 0.1, L - 0.1), Vector3(s * (hw - 0.06), y0 + h * 0.5, 0), interno)
	# beliches
	var lencois := [Color(0.25, 0.32, 0.45), Color(0.45, 0.22, 0.18), Color(0.3, 0.38, 0.25), Color(0.5, 0.42, 0.25), Color(0.35, 0.3, 0.4), Color(0.2, 0.36, 0.38)]
	for i in capacidade():
		var c := cama(i)
		var p: Vector3 = c.position
		var nd := Node3D.new()
		nd.position = p
		nd.rotation.y = c.rot
		r.add_child(nd)
		B.box(nd, Vector3(0.72, 0.08, 1.9), Vector3(0, -0.06, 0), madeira)
		B.box(nd, Vector3(0.66, 0.12, 1.84), Vector3(0, 0.04, 0), B.mat(Color(0.82, 0.8, 0.74), 0.95))
		var ocupada := i < moradores.size()
		if ocupada:
			B.box(nd, Vector3(0.68, 0.05, 1.2), Vector3(0, 0.12, -0.3), B.mat(lencois[i % lencois.size()], 0.95))
			B.box(nd, Vector3(0.45, 0.1, 0.28), Vector3(0, 0.15, 0.75), B.mat(Color(0.9, 0.88, 0.82), 0.95))
			if dormindo and not moradores[i].get("expedicao", {}).size() > 0:
				var m: Dictionary = moradores[i]
				var hm := Humanoid.new()
				hm.semente = m.semente
				hm.pele = m.pele
				hm.camisa = m.camisa
				hm.calca = m.calca
				nd.add_child(hm)
				hm.rotation = Vector3(-PI * 0.5, PI, 0) if not Modelos.disponivel() else Vector3(0, PI * 0.5, 0)
				hm.position = Vector3(0, 0.2, -0.88)
				hm.scale = Vector3.ONE * 0.92
				hm.call_deferred("pose_dormir")
		else:
			B.box(nd, Vector3(0.6, 0.06, 0.4), Vector3(0, 0.12, -0.75), B.mat(Color(0.5, 0.48, 0.42), 0.95))   # cobertor dobrado
	# colunas dos beliches
	for s in [-1.0, 1.0]:
		if (s < 0.0 and capacidade() >= 1) or (s > 0.0 and capacidade() >= 3):
			for dz in [-0.95, 0.95]:
				B.box(r, Vector3(0.05, h - 0.1, 0.05), Vector3(s * (hw - 0.78), y0 + h * 0.5, hz - 1.95 + dz), madeira)
			B.box(r, Vector3(0.04, 0.04, 0.9), Vector3(s * (hw - 0.78), y0 + 1.55, hz - 2.2), madeira)   # grade da cama de cima
	# escadinha, armário, mesinha e quadro
	B.box(r, Vector3(0.5, 1.7, 0.45), Vector3(hw - 0.3, y0 + 0.85, -hz + 0.6), B.mat(Color(0.38, 0.4, 0.36), 0.6, 0.4))
	B.box(r, Vector3(0.01, 1.5, 0.01), Vector3(hw - 0.55, y0 + 0.85, -hz + 0.6), aco)
	B.box(r, Vector3(0.45, 0.04, 0.55), Vector3(-hw + 0.3, y0 + 0.72, -hz + 0.75), madeira)
	B.box(r, Vector3(0.04, 0.7, 0.04), Vector3(-hw + 0.3, y0 + 0.36, -hz + 0.75), aco)
	B.cyl(r, 0.04, 0.12, Vector3(-hw + 0.25, y0 + 0.8, -hz + 0.7), B.mat(Color(0.7, 0.3, 0.1), 0.5), Vector3.ZERO, 8)  # caneca
	# quadro de cortiça na parede da frente, ao lado da porta, em cima da mesinha
	var qx := -hw + 0.4
	B.box(r, Vector3(0.5, 0.4, 0.02), Vector3(qx, y0 + 1.45, -hz + 0.06), B.mat(Color(0.5, 0.38, 0.24), 0.9))
	for k in mini(moradores.size(), 6):
		B.box(r, Vector3(0.1, 0.08, 0.005), Vector3(qx - 0.15 + (k % 3) * 0.15, y0 + 1.52 - (k / 3) * 0.14, -hz + 0.075), B.mat(Color(0.9, 0.88, 0.75), 0.9))
	# divisória entre entrada e quarto
	for s in [-1.0, 1.0]:
		B.box(r, Vector3(0.45, h - 0.1, 0.04), Vector3(s * (hw - 0.28), y0 + h * 0.5, -hz + 1.62), interno)
	# luz quente
	var luz := OmniLight3D.new()
	luz.light_color = Color(1, 0.72, 0.42)
	luz.light_energy = 0.7
	luz.omni_range = 4.0
	luz.position = Vector3(0, y0 + h - 0.25, 0.4)
	r.add_child(luz)
	var luz2 := OmniLight3D.new()
	luz2.light_color = Color(1, 0.75, 0.5)
	luz2.light_energy = 0.45
	luz2.omni_range = 3.0
	luz2.position = Vector3(0, y0 + h - 0.3, -hz + 0.8)
	r.add_child(luz2)
	var luz3 := OmniLight3D.new()
	luz3.light_color = Color(1, 0.72, 0.45)
	luz3.light_energy = 0.4
	luz3.omni_range = 2.6
	luz3.position = Vector3(0, y0 + 1.5, hz - 1.2)
	r.add_child(luz3)
	B.sphere(r, 0.07, Vector3(0, y0 + h - 0.08, 0.4), B.emissive(Color(1, 0.8, 0.5), 2.0), Vector3(1, 0.6, 1), 8)
	# por fora: varal, caixa d'água, antena, cadeira dobrada
	B.cyl(r, 0.28, 0.5, Vector3(0.45, y0 + h + 0.3, hz - 0.6), B.mat(Color(0.15, 0.25, 0.42), 0.5), Vector3.ZERO, 12)
	B.cyl(r, 0.012, 1.2, Vector3(-0.6, y0 + h + 0.6, -hz + 0.5), aco, Vector3.ZERO, 4)
	if nivel >= 2:
		for k in 2:
			B.box(r, Vector3(0.6, 0.05, 1.0), Vector3(-0.45 + k * 0.9, y0 + h + 0.1, -0.4), B.mat(Color(0.1, 0.13, 0.22), 0.2, 0.6))
	if nivel >= 3:
		# toldo lateral aberto
		var toldo := B.box(r, Vector3(1.4, 0.03, L - 1.0), Vector3(-hw - 0.68, y0 + h - 0.15, 0.2), B.mat(Color(0.55, 0.35, 0.2), 0.9))
		toldo.rotation.z = deg_to_rad(-8)
		for dz in [-hz + 0.8, hz - 0.5]:
			B.cyl(r, 0.025, h - 0.1, Vector3(-hw - 1.35, (y0 + h) * 0.5 - 0.05, dz), aco, Vector3.ZERO, 6)

func _corpo_plataforma() -> void:
	var r := _root
	var L := comprimento()
	var hz := L * 0.5
	var hw: float = info().larg * 0.5
	var cor: Color = info().cor
	var madeira := _pint(Color(0.4, 0.3, 0.2), condicao, 0.9, 0.0)
	var aco := B.mat(Color(0.15, 0.15, 0.15), 0.5, 0.6)
	B.box(r, Vector3(hw * 2.0, 0.06, L), Vector3(0, 0.77, 0), madeira)
	for i in int(L / 0.25):
		B.box(r, Vector3(hw * 2.0, 0.01, 0.02), Vector3(0, 0.805, -hz + i * 0.25), aco)
	# fueiros laterais
	for s in [-1.0, 1.0]:
		for i in 5:
			B.box(r, Vector3(0.06, 0.7, 0.06), Vector3(s * (hw - 0.03), 1.15, -hz + 0.2 + i * (L - 0.4) / 4.0), _pint(cor, condicao, 0.6, 0.4))
		B.box(r, Vector3(0.05, 0.05, L), Vector3(s * (hw - 0.03), 1.5, 0), _pint(cor, condicao, 0.6, 0.4))
	# carga amarrada com lona
	B.box(r, Vector3(1.6, 0.7, 1.4), Vector3(0, 1.15, 0.9), B.mat(Color(0.25, 0.28, 0.2), 0.95))
	for dz in [0.5, 1.3]:
		B.box(r, Vector3(1.65, 0.75, 0.04), Vector3(0, 1.16, dz), B.mat(Color(0.8, 0.5, 0.1), 0.6))
	for i in 4:
		B.box(r, Vector3(0.6, 0.12, 0.12), Vector3(-0.5 + (i % 2) * 0.4, 0.86 + (i / 2) * 0.12, -0.2), B.mat(Color(0.5, 0.4, 0.3), 0.9))  # madeira empilhada
	if nivel >= 2:
		_moto(r, Vector3(0.1, 0.8, -1.3))

func _moto(r: Node3D, p: Vector3) -> void:
	var m := Node3D.new()
	m.position = p
	r.add_child(m)
	var preto := B.mat(Color(0.06, 0.06, 0.06), 0.6, 0.3)
	var verm := B.mat(Color(0.65, 0.1, 0.06), 0.4, 0.4)
	for z in [-0.65, 0.6]:
		var w := B.wheel(m, Vector3(0, 0.33, z), 0.33, 0.12)
	B.box(m, Vector3(0.22, 0.25, 0.5), Vector3(0, 0.75, 0.15), verm)
	B.box(m, Vector3(0.2, 0.1, 0.55), Vector3(0, 0.82, -0.3), preto)
	B.box(m, Vector3(0.12, 0.35, 0.5), Vector3(0, 0.5, 0.0), preto)
	var garfo := B.cyl(m, 0.025, 0.7, Vector3(0, 0.62, 0.55), B.mat(Color(0.6, 0.6, 0.6), 0.3, 0.8), Vector3(-25, 0, 0), 6)
	B.cyl(m, 0.02, 0.6, Vector3(0, 0.98, 0.42), preto, Vector3(0, 0, 90), 6)
