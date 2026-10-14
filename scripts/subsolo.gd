class_name Subsolo
extends Node3D
## Porão ou bunker: entra-se por um alçapão/escotilha e anda-se em primeira pessoa
## no escuro. Sem lanterna, vasculhar é arriscado (algo pode morder); com lanterna,
## dá para ver. Funciona como os reboques: interior(), ponto_entrada(), nome_exibicao().

const FUNDO := -40.0      # o cômodo fica bem abaixo do chão (longe da luz do sol)

var tipo := "porao"       # porao, bunker
var chave := ""
var mundo: WorldGen
var itens: Array[Node3D] = []   # marcadores de vasculhar (não ficam em mundo.vasculhaveis)
var ocupado := false            # tem zumbi lá dentro
var _r := RandomNumberGenerator.new()

func nome_exibicao() -> String:
	return "Porão" if tipo == "porao" else "Bunker"

func tamanho() -> Vector2:
	return Vector2(4.2, 5.0) if tipo == "porao" else Vector2(6.0, 11.0)

func ponto_entrada() -> Vector3:
	return Vector3(0, 0, 1.6)

func _ready() -> void:
	_r.seed = hash(chave)
	ocupado = _r.randf() < (0.35 if tipo == "porao" else 0.6) and not (mundo and mundo.vasculhados.has(chave + ":vulto"))
	_superficie()
	_interior()

## O que se vê de fora: alçapão de madeira ou escotilha de concreto.
func _superficie() -> void:
	set_meta("area_livre", Vector2(2.0, 2.0))
	if tipo == "porao":
		var mad := B.mat(Color(0.3, 0.21, 0.13), 0.95, 0.0, "alcapao")
		B.box(self, Vector3(1.3, 0.12, 1.1), Vector3(0, 0.06, 0), mad)
		for i in 4:
			B.box(self, Vector3(1.32, 0.02, 0.05), Vector3(0, 0.13, -0.42 + i * 0.28), B.mat(Color(0.18, 0.13, 0.08), 0.95))
		B.cyl(self, 0.05, 0.04, Vector3(0, 0.15, 0.35), B.mat(Color(0.3, 0.3, 0.3), 0.4, 0.8), Vector3(90, 0, 0), 8)
	else:
		var conc := Texturas.material("concreto", Color(0.5, 0.5, 0.47))
		var aco := B.mat(Color(0.25, 0.28, 0.22), 0.5, 0.7)
		B.box(self, Vector3(2.4, 0.5, 2.4), Vector3(0, 0.25, 0), conc)
		B.cyl(self, 0.62, 0.12, Vector3(0, 0.56, 0), aco, Vector3.ZERO, 16)
		B.cyl(self, 0.06, 0.5, Vector3(0, 0.66, 0), aco, Vector3(0, 0, 90), 8)    # volante
		for s in [-1.0, 1.0]:
			B.cyl(self, 0.09, 1.2, Vector3(s * 1.0, 0.85, -0.9), aco, Vector3.ZERO, 8)  # respiros
			B.cyl(self, 0.14, 0.12, Vector3(s * 1.0, 1.5, -0.9), aco, Vector3.ZERO, 8)
		var pl := Label3D.new()
		pl.text = "ABRIGO\nDEFESA CIVIL"
		pl.font_size = 64
		pl.pixel_size = 0.004
		pl.modulate = Color(0.9, 0.8, 0.2)
		pl.outline_size = 6
		pl.shaded = true
		pl.position = Vector3(0, 0.3, 1.22)
		add_child(pl)

## O cômodo lá embaixo.
func _interior() -> void:
	var t := tamanho()
	var hx := t.x * 0.5
	var hz := t.y * 0.5
	var h := 2.4
	var raiz := Node3D.new()
	raiz.position = Vector3(0, FUNDO, 0)
	add_child(raiz)
	var parede: Material
	var piso: Material
	if tipo == "porao":
		parede = B.mat(Color(0.3, 0.27, 0.22), 1.0, 0.0, "porao_parede")
		piso = B.mat(Color(0.2, 0.17, 0.13), 1.0, 0.0, "porao_piso")
	else:
		parede = Texturas.material("concreto", Color(0.45, 0.46, 0.43))
		piso = B.mat(Color(0.28, 0.3, 0.27), 0.9, 0.0, "bunker_piso")
	B.box(raiz, Vector3(t.x + 0.4, 0.2, t.y + 0.4), Vector3(0, -0.1, 0), piso)
	B.box(raiz, Vector3(t.x + 0.4, 0.2, t.y + 0.4), Vector3(0, h + 0.1, 0), parede)
	for s in [-1.0, 1.0]:
		B.box(raiz, Vector3(0.2, h, t.y + 0.4), Vector3(s * (hx + 0.1), h * 0.5, 0), parede)
		B.box(raiz, Vector3(t.x + 0.4, h, 0.2), Vector3(0, h * 0.5, s * (hz + 0.1)), parede)
	# escada de subida (em +Z)
	var mad := B.mat(Color(0.35, 0.25, 0.15), 0.9)
	for i in 7:
		B.box(raiz, Vector3(0.8, 0.06, 0.12), Vector3(0, 0.3 + i * 0.33, hz - 0.15), mad)
	for s in [-1.0, 1.0]:
		B.box(raiz, Vector3(0.06, h, 0.06), Vector3(s * 0.42, h * 0.5, hz - 0.1), mad)
	# lâmpada apagada / luz de emergência fraca (só para não ficar 100% preto)
	var l := OmniLight3D.new()
	l.light_color = Color(0.9, 0.35, 0.2) if tipo == "bunker" else Color(0.6, 0.55, 0.45)
	l.light_energy = 0.09
	l.omni_range = 7.0
	l.position = Vector3(0, h - 0.3, 0)
	raiz.add_child(l)
	# móveis e o que dá para vasculhar
	var lista: Array = []
	if tipo == "porao":
		lista = [["Prateleira de conservas", "armario", Vector3(-hx + 0.3, 1.0, -0.8)], ["Caixas velhas", "caixa", Vector3(hx - 0.4, 0.5, -1.2)],
			["Baú de ferramentas", "galpao", Vector3(hx - 0.4, 0.5, 1.0)], ["Armário de caça", "cacador", Vector3(-hx + 0.3, 1.0, 1.2)]]
		B.box(raiz, Vector3(0.4, 1.8, 1.6), Vector3(-hx + 0.25, 0.9, -0.8), mad)
		for k in 4:
			for q in 5:
				B.cyl(raiz, 0.06, 0.15, Vector3(-hx + 0.3, 0.35 + k * 0.42, -1.4 + q * 0.3), B.mat([Color(0.7, 0.3, 0.1), Color(0.8, 0.7, 0.3), Color(0.4, 0.6, 0.2)][(k + q) % 3], 0.4), Vector3.ZERO, 8)
		B.box(raiz, Vector3(0.7, 0.5, 0.6), Vector3(hx - 0.4, 0.25, -1.2), B.mat(Color(0.45, 0.35, 0.22), 0.95))
		B.box(raiz, Vector3(0.6, 0.4, 0.5), Vector3(hx - 0.4, 0.7, -1.3), B.mat(Color(0.5, 0.4, 0.25), 0.95), Vector3(0, 15, 0))
		B.box(raiz, Vector3(0.8, 0.45, 0.45), Vector3(hx - 0.45, 0.23, 1.0), B.mat(Color(0.6, 0.1, 0.06), 0.5, 0.3))
		B.box(raiz, Vector3(0.35, 1.7, 0.8), Vector3(-hx + 0.2, 0.85, 1.2), mad)
	else:
		lista = [["Armário de armas", "militar", Vector3(-hx + 0.35, 1.0, -3.5)], ["Estoque de conservas", "prateleira", Vector3(hx - 0.35, 1.0, -3.0)],
			["Enfermaria", "farmacia", Vector3(hx - 0.4, 0.8, 1.0)], ["Beliches", "guarda_roupa", Vector3(-hx + 0.6, 0.6, 1.0)],
			["Mesa do rádio", "torre", Vector3(0, 0.9, -hz + 0.5)]]
		var aco := B.mat(Color(0.3, 0.33, 0.28), 0.5, 0.6)
		B.box(raiz, Vector3(0.5, 1.9, 1.4), Vector3(-hx + 0.3, 0.95, -3.5), aco)
		for i in 3:
			B.box(raiz, Vector3(0.45, 1.8, 0.9), Vector3(hx - 0.3, 0.9, -4.0 + i * 1.0), aco)
		for i in 2:
			B.box(raiz, Vector3(0.9, 0.12, 2.0), Vector3(-hx + 0.6, 0.45 + i * 0.9, 1.0), aco)
			B.box(raiz, Vector3(0.85, 0.12, 1.9), Vector3(-hx + 0.6, 0.55 + i * 0.9, 1.0), B.mat(Color(0.3, 0.35, 0.25), 0.95))
		B.box(raiz, Vector3(1.0, 0.8, 0.5), Vector3(hx - 0.4, 0.4, 1.0), B.mat(Color(0.85, 0.85, 0.82), 0.5))
		B.box(raiz, Vector3(0.3, 0.05, 0.3), Vector3(hx - 0.4, 0.82, 1.0), B.mat(Color(0.75, 0.1, 0.06), 0.5))
		B.box(raiz, Vector3(1.6, 0.08, 0.7), Vector3(0, 0.8, -hz + 0.5), aco)
		B.box(raiz, Vector3(0.6, 0.35, 0.35), Vector3(0, 1.02, -hz + 0.45), B.mat(Color(0.15, 0.17, 0.14), 0.4, 0.5))
		# luz de emergência vermelha
		B.box(raiz, Vector3(0.2, 0.1, 0.1), Vector3(0, h - 0.1, -hz + 0.2), B.emissive(Color(1.0, 0.15, 0.08), 1.2))
		# cartaz
		var cz := Label3D.new()
		cz.text = "MANTENHA A CALMA\nAGUARDE O RESGATE"
		cz.font_size = 48
		cz.pixel_size = 0.004
		cz.modulate = Color(0.85, 0.82, 0.7)
		cz.shaded = true
		cz.position = Vector3(hx - 0.02, 1.6, 2.6)
		cz.rotation.y = -PI * 0.5
		raiz.add_child(cz)
	for i in lista.size():
		var v := Node3D.new()
		v.position = Vector3(0, FUNDO, 0) + lista[i][2]
		v.set_meta("nome", lista[i][0])
		v.set_meta("tabela", lista[i][1])
		v.set_meta("horas", 0.25)
		v.set_meta("chave", "%s:%d" % [chave, i])
		add_child(v)
		itens.append(v)
	if ocupado:
		# o que está lá embaixo: um vulto parado no canto
		var vul := Node3D.new()
		vul.name = "Vulto"
		vul.position = Vector3(hx * 0.5, 0, -hz + 1.0)
		raiz.add_child(vul)
		var m := B.mat(Color(0.12, 0.11, 0.1), 1.0)
		B.capsule(vul, 0.2, 1.1, Vector3(0, 1.0, 0), m, Vector3(15, 0, 0))
		B.sphere(vul, 0.13, Vector3(0, 1.62, 0.15), m)

func interior() -> Dictionary:
	var t := tamanho()
	var hx := t.x * 0.5 - 0.35
	var hz := t.y * 0.5 - 0.35
	var its: Array = []
	for i in itens.size():
		var v := itens[i]
		if mundo and mundo.vasculhados.has(v.get_meta("chave")):
			continue
		its.append({"id": "sub:%d" % i, "nome": "Vasculhar: %s" % v.get_meta("nome"), "pos": v.position})
	if ocupado:
		its.append({"id": "sub:vulto", "nome": "Tem alguma coisa no canto...", "pos": Vector3(t.x * 0.25, FUNDO + 1.2, -t.y * 0.5 + 1.0)})
	its.append({"id": "sair", "nome": "Subir a escada", "pos": Vector3(0, FUNDO + 1.4, t.y * 0.5 - 0.15)})
	return {"limites": AABB(Vector3(-hx, 0, -hz), Vector3(hx * 2.0, 0, hz * 2.0)), "piso": FUNDO, "olho": 1.6,
		"inicio": Vector3(0, 0, t.y * 0.5 - 0.7), "yaw": PI, "interativos": its}

func matar_vulto() -> void:
	ocupado = false
	if mundo:
		mundo.vasculhados[chave + ":vulto"] = true
	var v := find_child("Vulto", true, false)
	if v:
		v.rotation.x = -1.4
		v.position.y = 0.2
