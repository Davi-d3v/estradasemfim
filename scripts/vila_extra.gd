class_name VilaExtra
## Detalhes que dão vida às vilas e assentamentos: rua de paralelepípedo com meio-fio
## e calçada, igreja detalhada com cemitério, parquinho, torres de vigia internas,
## árvores, galinheiro, horta com espantalho, lenha, bancos, lixo e barricadas.
## preencher() ocupa os espaços vazios (sem casa, rua ou construção).

# ------------------------------------------------------------ materiais
static func _m(nome: String, cor: Color, rough := 0.9, metal := 0.0) -> Material:
	return Texturas.material(nome, cor, rough, metal)

# ------------------------------------------------------------ rua
## Rua de paralelepípedo (ou terra batida) de a até b, com meio-fio, calçada,
## marcas de pneu, buracos com poça e bueiros.
static func rua(p: Node3D, a: Vector3, b: Vector3, larg: float, r: RandomNumberGenerator, terra := false) -> void:
	var d := b - a
	d.y = 0.0
	var comp := d.length()
	if comp < 0.5:
		return
	var n := Node3D.new()
	n.position = (a + b) * 0.5
	n.rotation.y = atan2(d.x, d.z)
	p.add_child(n)
	var leito: Material = B.mat(Color(0.42, 0.36, 0.28), 1.0, 0.0, "rua_vila") if terra else _m("pedra", Color(0.34, 0.32, 0.29), 0.95)
	B.box(n, Vector3(larg, 0.06, comp), Vector3(0, 0.04, 0), leito)
	var meio_fio := _m("concreto", Color(0.62, 0.6, 0.56), 0.9)
	var calcada := _m("concreto", Color(0.48, 0.46, 0.43), 0.95)
	for s in [-1.0, 1.0]:
		B.box(n, Vector3(0.16, 0.16, comp), Vector3(s * (larg * 0.5 + 0.08), 0.08, 0), meio_fio)
		B.box(n, Vector3(1.2, 0.12, comp), Vector3(s * (larg * 0.5 + 0.76), 0.06, 0), calcada)
		# trilha de pneu escurecida
		B.box(n, Vector3(0.45, 0.005, comp * 0.96), Vector3(s * larg * 0.22, 0.072, 0), B.mat(Color(0.25, 0.22, 0.19), 1.0, 0.0, "trilha_pneu"))
	# buracos com poça
	var poca := B.mat(Color(0.18, 0.2, 0.22), 0.05, 0.3, "poca_rua")
	for i in int(comp / 9.0):
		if r.randf() < 0.55:
			var pz := r.randf_range(-comp * 0.45, comp * 0.45)
			var px := r.randf_range(-larg * 0.35, larg * 0.35)
			var c := B.cyl(n, r.randf_range(0.35, 0.8), 0.01, Vector3(px, 0.074, pz), poca, Vector3.ZERO, 10)
			c.scale = Vector3(1.0, 1.0, r.randf_range(0.5, 1.0))
	# bueiros na sarjeta
	for i in int(comp / 14.0):
		var bz := -comp * 0.5 + 7.0 + i * 14.0
		B.box(n, Vector3(0.5, 0.02, 0.8), Vector3(larg * 0.5 - 0.3, 0.075, bz), B.mat(Color(0.12, 0.12, 0.12), 0.5, 0.6, "bueiro"))

# ------------------------------------------------------------ igreja
## Igreja com nave, contrafortes, janelas em arco, rosácea, escadaria, torre com sino
## aberto, cruz, e um pequeno cemitério cercado ao lado. Frente para +Z.
static func igreja(ig: Node3D, r: RandomNumberGenerator, m: WorldGen) -> void:
	var reboco := _m("reboco", Color(0.86, 0.84, 0.78), 0.9)
	var barra := _m("reboco", Color(0.55, 0.62, 0.7), 0.9)
	var telha := _m("telha", Color(0.55, 0.26, 0.16), 0.85)
	var pedra := _m("pedra", Color(0.6, 0.58, 0.54), 0.95)
	var madeira := _m("tabuas", Color(0.36, 0.22, 0.12), 0.8)
	var vidro := B.mat(Color(0.25, 0.32, 0.42), 0.15, 0.4, "vitral")
	var vitral_cores := [Color(0.7, 0.2, 0.18), Color(0.2, 0.35, 0.65), Color(0.85, 0.7, 0.2), Color(0.25, 0.55, 0.3)]
	var L := 9.0
	var C := 14.0
	var H := 6.0
	# embasamento de pedra e nave
	B.box(ig, Vector3(L + 0.4, 0.5, C + 0.4), Vector3(0, 0.25, 0), pedra)
	B.box(ig, Vector3(L, H, C), Vector3(0, 0.5 + H * 0.5, 0), reboco)
	B.box(ig, Vector3(L + 0.04, 0.9, C + 0.04), Vector3(0, 0.95, 0), barra)          # barrado pintado
	B.box(ig, Vector3(L + 0.1, 0.18, C + 0.1), Vector3(0, 0.5 + H, 0), pedra)          # cornija
	# telhado de duas águas
	var tri := PackedVector2Array([Vector2(-L * 0.5 - 0.6, 0.5 + H), Vector2(L * 0.5 + 0.6, 0.5 + H), Vector2(0, 0.5 + H + 3.4)])
	var tel := B.extruded(ig, tri, C + 0.8, Vector3.ZERO, telha)
	tel.rotation.y = PI * 0.5
	# frontão (empena) com rosácea
	var emp := PackedVector2Array([Vector2(-L * 0.5, 0.5 + H), Vector2(L * 0.5, 0.5 + H), Vector2(0, 0.5 + H + 3.2)])
	var e := B.extruded(ig, emp, 0.3, Vector3(0, 0, C * 0.5 - 0.1), reboco)
	e.rotation.y = PI * 0.5
	B.cyl(ig, 0.75, 0.12, Vector3(0, H + 1.6, C * 0.5 + 0.06), pedra, Vector3(90, 0, 0), 16)
	B.cyl(ig, 0.6, 0.14, Vector3(0, H + 1.6, C * 0.5 + 0.07), vidro, Vector3(90, 0, 0), 16)
	for k in 8:
		var a := TAU * k / 8.0
		B.box(ig, Vector3(0.05, 0.6, 0.02), Vector3(sin(a) * 0.3, H + 1.6 + cos(a) * 0.3, C * 0.5 + 0.15), pedra, Vector3(0, 0, -rad_to_deg(a)))
	# contrafortes e janelas em arco nas laterais
	for s in [-1.0, 1.0]:
		for k in 4:
			var z := -C * 0.5 + 1.5 + k * ((C - 3.0) / 3.0)
			B.box(ig, Vector3(0.5, H * 0.8, 0.6), Vector3(s * (L * 0.5 + 0.25), 0.5 + H * 0.4, z), pedra)
			if k < 3:
				var zj := z + (C - 3.0) / 6.0
				B.box(ig, Vector3(0.1, 2.6, 1.0), Vector3(s * (L * 0.5 + 0.01), 3.3, zj), pedra)
				B.box(ig, Vector3(0.12, 2.3, 0.75), Vector3(s * (L * 0.5 + 0.02), 3.25, zj), B.mat(vitral_cores[(k + int(s > 0)) % 4].darkened(0.35), 0.2, 0.2))
				B.cyl(ig, 0.5, 0.1, Vector3(s * (L * 0.5 + 0.01), 4.6, zj), pedra, Vector3(0, 0, 90), 12)
				B.cyl(ig, 0.37, 0.12, Vector3(s * (L * 0.5 + 0.02), 4.6, zj), B.mat(vitral_cores[(k + 1) % 4].darkened(0.3), 0.2, 0.2), Vector3(0, 0, 90), 12)
				# uma janela quebrada e tapada com tábuas
				if k == 1 and s > 0:
					for t in 3:
						B.box(ig, Vector3(0.05, 0.16, 1.1), Vector3(L * 0.5 + 0.1, 2.6 + t * 0.6, zj), madeira, Vector3(r.randf_range(-12, 12), 0, 0))
	# escadaria e porta dupla com arco
	for k in 3:
		B.box(ig, Vector3(4.2 - k * 0.4, 0.18, 1.0 - k * 0.25), Vector3(0, 0.09 + k * 0.18, C * 0.5 + 0.9 - k * 0.2), pedra)
	B.box(ig, Vector3(2.6, 3.6, 0.2), Vector3(0, 2.3, C * 0.5 + 0.02), pedra)
	B.cyl(ig, 1.3, 0.22, Vector3(0, 4.1, C * 0.5 + 0.02), pedra, Vector3(90, 0, 0), 14)
	for s in [-1.0, 1.0]:
		var porta := B.box(ig, Vector3(1.05, 3.0, 0.1), Vector3(s * 0.55, 2.0, C * 0.5 + 0.15), madeira)
		B.box(ig, Vector3(0.06, 0.06, 0.12), Vector3(s * 0.12, 2.0, C * 0.5 + 0.22), B.mat(Color(0.5, 0.42, 0.2), 0.4, 0.8))
		if s > 0:
			porta.rotation.y = -0.5   # entreaberta
			porta.position += Vector3(0.18, 0, 0.25)
	# torre do sino na frente, de lado
	var tx := L * 0.5 - 1.4
	var tz := C * 0.5 - 1.4
	var TH := 13.0
	B.box(ig, Vector3(3.0, TH, 3.0), Vector3(tx, TH * 0.5, tz), reboco)
	B.box(ig, Vector3(3.1, 0.9, 3.1), Vector3(tx, 0.95, tz), barra)
	for y in [H + 0.6, TH - 3.6]:
		B.box(ig, Vector3(3.15, 0.15, 3.15), Vector3(tx, y, tz), pedra)
	# câmara do sino com arcos abertos
	var cy := TH + 1.3
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.box(ig, Vector3(0.5, 2.6, 0.5), Vector3(tx + sx * 1.25, cy, tz + sz * 1.25), reboco)
	B.box(ig, Vector3(3.1, 0.3, 3.1), Vector3(tx, cy + 1.45, tz), pedra)
	B.cyl(ig, 0.45, 0.65, Vector3(tx, cy + 0.3, tz), B.mat(Color(0.55, 0.42, 0.18), 0.35, 0.85), Vector3.ZERO, 12, 0.22)
	B.box(ig, Vector3(1.2, 0.12, 0.12), Vector3(tx, cy + 0.75, tz), madeira)
	B.cyl(ig, 2.2, 3.0, Vector3(tx, cy + 3.1, tz), telha, Vector3(0, 45, 0), 4, 0.0)
	# cruz
	B.box(ig, Vector3(0.12, 1.4, 0.12), Vector3(tx, cy + 5.2, tz), B.mat(Color(0.3, 0.3, 0.3), 0.5, 0.7))
	B.box(ig, Vector3(0.8, 0.12, 0.12), Vector3(tx, cy + 5.45, tz), B.mat(Color(0.3, 0.3, 0.3), 0.5, 0.7))
	# relógio parado e janelinhas da torre
	B.cyl(ig, 0.55, 0.08, Vector3(tx, TH - 2.4, tz + 1.52), B.mat(Color(0.92, 0.9, 0.82), 0.6), Vector3(90, 0, 0), 16)
	B.box(ig, Vector3(0.05, 0.4, 0.02), Vector3(tx, TH - 2.25, tz + 1.58), B.mat(Color(0.1, 0.1, 0.1), 0.5))
	B.box(ig, Vector3(0.3, 0.05, 0.02), Vector3(tx + 0.13, TH - 2.4, tz + 1.58), B.mat(Color(0.1, 0.1, 0.1), 0.5))
	for y in [4.5, 8.0]:
		B.box(ig, Vector3(0.5, 1.0, 0.08), Vector3(tx, y, tz + 1.52), vidro)
	# letreiro e aviso pichado
	var l := Label3D.new()
	l.text = "PARÓQUIA SÃO JOSÉ"
	l.font_size = 64
	l.pixel_size = 0.006
	l.modulate = Color(0.3, 0.25, 0.2)
	l.position = Vector3(0, 4.9, C * 0.5 + 0.13)
	ig.add_child(l)
	var pich := Label3D.new()
	pich.text = "ABRIGO\nNÃO ENTRE À NOITE"
	pich.font_size = 72
	pich.pixel_size = 0.006
	pich.modulate = Color(0.75, 0.12, 0.1)
	pich.position = Vector3(-L * 0.5 - 0.03, 2.2, 2.0)
	pich.rotation.y = -PI * 0.5
	ig.add_child(pich)
	# cemitério cercado ao lado esquerdo
	var cem := Node3D.new()
	cem.position = Vector3(-L * 0.5 - 5.5, 0, -1.0)
	ig.add_child(cem)
	var ferro := B.mat(Color(0.12, 0.12, 0.12), 0.5, 0.7, "grade_ferro")
	var W := 7.0
	var D := 11.0
	for s in [-1.0, 1.0]:
		B.box(cem, Vector3(0.05, 0.05, D), Vector3(s * W * 0.5, 1.0, 0), ferro)
		B.box(cem, Vector3(W, 0.05, 0.05), Vector3(0, 1.0, s * D * 0.5), ferro)
	for k in int((W + D) * 2.0 / 0.35):
		var t := k * 0.35
		var q: Vector3
		if t < W:
			q = Vector3(-W * 0.5 + t, 0, D * 0.5)
		elif t < W + D:
			q = Vector3(W * 0.5, 0, D * 0.5 - (t - W))
		elif t < W * 2.0 + D:
			q = Vector3(W * 0.5 - (t - W - D), 0, -D * 0.5)
		else:
			q = Vector3(-W * 0.5, 0, -D * 0.5 + (t - W * 2.0 - D))
		if absf(q.x) < 0.8 and q.z > 0:
			continue   # portãozinho
		B.box(cem, Vector3(0.03, 1.15, 0.03), q + Vector3(0, 0.58, 0), ferro)
	var lapide := _m("pedra", Color(0.62, 0.62, 0.6), 0.9)
	for i in 4:
		for k in 3:
			var q := Vector3(-W * 0.5 + 1.3 + k * 2.2 + r.randf_range(-0.2, 0.2), 0, -D * 0.5 + 1.5 + i * 2.5)
			match r.randi() % 3:
				0:
					var lp := B.box(cem, Vector3(0.6, 0.8, 0.12), q + Vector3(0, 0.4, 0), lapide)
					lp.rotation.z = r.randf_range(-0.12, 0.12)
				1:
					B.box(cem, Vector3(0.1, 1.0, 0.1), q + Vector3(0, 0.5, 0), madeira)
					B.box(cem, Vector3(0.55, 0.1, 0.1), q + Vector3(0, 0.75, 0), madeira)
				2:
					B.box(cem, Vector3(0.8, 0.3, 1.7), q + Vector3(0, 0.15, -0.6), lapide)
					B.box(cem, Vector3(0.6, 0.6, 0.12), q + Vector3(0, 0.6, 0.2), lapide)
			# cova recente (terra mexida)
			if r.randf() < 0.35:
				B.box(cem, Vector3(0.9, 0.12, 1.8), q + Vector3(0, 0.06, -0.9), B.mat(Color(0.3, 0.22, 0.15), 1.0, 0.0, "cova"))
	var arv := MeshInstance3D.new()
	arv.mesh = Floresta.malha("folhosa")
	arv.position = Vector3(W * 0.5 - 1.0, 0, D * 0.5 - 1.0)
	arv.scale = Vector3.ONE * 0.9
	cem.add_child(arv)

# ------------------------------------------------------------ parquinho
static func parquinho(p: Node3D, pos: Vector3, rot: float, r: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot
	p.add_child(n)
	var ferro := B.mat(Color(0.75, 0.2, 0.15), 0.5, 0.6, "brinquedo_ver")
	var ferro2 := B.mat(Color(0.2, 0.45, 0.7), 0.5, 0.6, "brinquedo_az")
	var amarelo := B.mat(Color(0.9, 0.72, 0.15), 0.5, 0.3, "brinquedo_am")
	var madeira := _m("tabuas", Color(0.5, 0.36, 0.22), 0.85)
	var corrente := B.mat(Color(0.5, 0.5, 0.5), 0.4, 0.8, "corrente")
	# areia e cerquinha
	B.box(n, Vector3(10.0, 0.05, 8.0), Vector3(0, 0.03, 0), B.mat(Color(0.72, 0.64, 0.48), 1.0, 0.0, "areia_parquinho"))
	for k in 20:
		var a := k / 20.0
		for s in [-1.0, 1.0]:
			B.box(n, Vector3(0.08, 0.7, 0.08), Vector3(-5.0 + a * 10.0, 0.35, s * 4.0), madeira)
	for s in [-1.0, 1.0]:
		B.box(n, Vector3(10.0, 0.06, 0.06), Vector3(0, 0.6, s * 4.0), madeira)
	# balanço (um assento caído)
	for s in [-1.0, 1.0]:
		var pe := B.cyl(n, 0.05, 2.6, Vector3(-3.0 + s * 1.5, 1.2, -1.5 + 0.5), ferro, Vector3(-20, 0, 0), 8)
		var pe2 := B.cyl(n, 0.05, 2.6, Vector3(-3.0 + s * 1.5, 1.2, -1.5 - 0.5), ferro, Vector3(20, 0, 0), 8)
	B.cyl(n, 0.05, 3.2, Vector3(-3.0, 2.42, -1.5), ferro, Vector3(0, 0, 90), 8)
	for k in 2:
		var x := -3.6 + k * 1.2
		if k == 1:
			B.cyl(n, 0.01, 1.9, Vector3(x - 0.2, 1.45, -1.5), corrente, Vector3.ZERO, 4)
			B.box(n, Vector3(0.5, 0.04, 0.2), Vector3(x - 0.05, 0.12, -1.3), madeira, Vector3(0, 30, 60))
			continue
		for dx in [-0.2, 0.2]:
			B.cyl(n, 0.01, 1.9, Vector3(x + dx, 1.45, -1.5), corrente, Vector3.ZERO, 4)
		B.box(n, Vector3(0.5, 0.04, 0.2), Vector3(x, 0.5, -1.5), madeira)
	# escorregador
	B.box(n, Vector3(1.0, 0.08, 1.0), Vector3(2.5, 1.6, -1.5), madeira)
	for sx in [-0.45, 0.45]:
		for sz in [-0.45, 0.45]:
			B.cyl(n, 0.04, 1.6, Vector3(2.5 + sx, 0.8, -1.5 + sz), ferro2, Vector3.ZERO, 6)
	for k in 5:
		B.box(n, Vector3(0.6, 0.04, 0.08), Vector3(2.5, 0.3 + k * 0.3, -2.1 - k * 0.05), ferro2)
	var esc := B.box(n, Vector3(0.6, 0.04, 2.4), Vector3(2.5, 0.85, 0.0), amarelo)
	esc.rotation.x = deg_to_rad(-38)
	for s in [-1.0, 1.0]:
		var b2 := B.box(n, Vector3(0.04, 0.15, 2.4), Vector3(2.5 + s * 0.3, 0.92, 0.0), amarelo)
		b2.rotation.x = deg_to_rad(-38)
	# gangorra
	B.box(n, Vector3(0.2, 0.4, 0.2), Vector3(-1.0, 0.2, 2.0), ferro2)
	var g := B.box(n, Vector3(0.25, 0.05, 3.0), Vector3(-1.0, 0.42, 2.0), madeira)
	g.rotation.x = 0.22
	# gira-gira
	B.cyl(n, 0.9, 0.08, Vector3(2.8, 0.35, 2.2), amarelo, Vector3.ZERO, 16)
	B.cyl(n, 0.06, 0.6, Vector3(2.8, 0.6, 2.2), ferro, Vector3.ZERO, 6)
	for k in 4:
		var a := TAU * k / 4.0
		B.box(n, Vector3(0.04, 0.04, 0.85), Vector3(2.8 + sin(a) * 0.42, 0.85, 2.2 + cos(a) * 0.42), ferro, Vector3(0, rad_to_deg(a), 0))
	# brinquedos largados
	B.sphere(n, 0.12, Vector3(0.5, 0.12, 0.8), B.mat(Color(0.85, 0.15, 0.15), 0.5, 0.0, "bola"))
	B.box(n, Vector3(0.25, 0.15, 0.35), Vector3(-2.0, 0.08, 0.6), B.mat(Color(0.2, 0.6, 0.3), 0.6, 0.0, "baldinho"))

# ------------------------------------------------------------ torre de vigia interna
static func torre(p: Node3D, pos: Vector3, rot: float, m: WorldGen) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot
	p.add_child(n)
	var madeira := _m("tabuas", Color(0.35, 0.25, 0.16), 0.9)
	var h := 5.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.box(n, Vector3(0.22, h + 1.6, 0.22), Vector3(sx * 1.2, (h + 1.6) * 0.5, sz * 1.2), madeira)
			var x := B.box(n, Vector3(0.1, 3.4, 0.1), Vector3(sx * 1.2, h * 0.45, 0), madeira)
			x.rotation.x = sz * 0.6
	B.box(n, Vector3(3.0, 0.15, 3.0), Vector3(0, h, 0), madeira)
	for s in [-1.0, 1.0]:
		B.box(n, Vector3(3.0, 0.9, 0.08), Vector3(0, h + 0.5, s * 1.46), madeira)
		B.box(n, Vector3(0.08, 0.9, 3.0), Vector3(s * 1.46, h + 0.5, 0), madeira)
	# sacos de areia na mureta e telhado de zinco
	for k in 6:
		B.box(n, Vector3(0.45, 0.18, 0.28), Vector3(-1.1 + k * 0.45, h + 1.04, 1.4), B.mat(Color(0.6, 0.55, 0.4), 0.95, 0.0, "saco_areia"))
	var tel := B.box(n, Vector3(3.4, 0.06, 3.4), Vector3(0, h + 2.2, 0), _m("metal", Color(0.5, 0.5, 0.48), 0.6, 0.5))
	tel.rotation.x = 0.1
	# escada
	for k in int(h / 0.35):
		B.box(n, Vector3(0.6, 0.05, 0.06), Vector3(0, 0.3 + k * 0.35, -1.6), madeira)
	for s in [-0.3, 0.3]:
		B.box(n, Vector3(0.06, h, 0.08), Vector3(s, h * 0.5, -1.6), madeira)
	# holofote e sino de alarme
	B.box(n, Vector3(0.35, 0.3, 0.35), Vector3(1.1, h + 1.15, 1.1), B.mat(Color(0.15, 0.15, 0.15), 0.5, 0.6))
	B.cyl(n, 0.12, 0.05, Vector3(1.1, h + 1.15, 1.3), B.emissive(Color(1.0, 0.9, 0.6), 2.0), Vector3(90, 0, 0), 10)
	B.cyl(n, 0.15, 0.25, Vector3(-1.1, h + 1.7, 1.1), B.mat(Color(0.55, 0.42, 0.18), 0.35, 0.85), Vector3.ZERO, 10, 0.08)
	return n

# ------------------------------------------------------------ pequenos
static func arvore(p: Node3D, pos: Vector3, r: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Floresta.malha(["folhosa", "folhosa", "jeriva", "pinheiro"][r.randi() % 4])
	mi.position = pos
	mi.rotation.y = r.randf() * TAU
	mi.scale = Vector3.ONE * r.randf_range(0.7, 1.05)
	p.add_child(mi)
	# canteiro de pedras em volta
	if r.randf() < 0.5:
		for k in 8:
			var a := TAU * k / 8.0
			B.box(p, Vector3(0.25, 0.15, 0.2), pos + Vector3(sin(a) * 0.9, 0.07, cos(a) * 0.9), B.mat(Color(0.55, 0.53, 0.5), 0.95, 0.0, "pedra_canteiro"), Vector3(0, rad_to_deg(a), 0))

static func banco(p: Node3D, pos: Vector3, rot: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot
	p.add_child(n)
	var madeira := _m("tabuas", Color(0.45, 0.3, 0.18), 0.85)
	var ferro := B.mat(Color(0.15, 0.15, 0.15), 0.5, 0.7, "ferro_banco")
	B.box(n, Vector3(1.6, 0.06, 0.45), Vector3(0, 0.45, 0), madeira)
	B.box(n, Vector3(1.6, 0.35, 0.05), Vector3(0, 0.72, -0.22), madeira)
	for s in [-0.7, 0.7]:
		B.box(n, Vector3(0.06, 0.45, 0.45), Vector3(s, 0.22, 0), ferro)

static func galinheiro(p: Node3D, pos: Vector3, rot: float, r: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot
	p.add_child(n)
	var madeira := _m("tabuas", Color(0.42, 0.3, 0.2), 0.9)
	var tela := B.mat(Color(0.6, 0.6, 0.6, 1.0), 0.6, 0.6, "tela_galinheiro")
	B.box(n, Vector3(2.0, 1.6, 1.6), Vector3(-1.5, 0.8, 0), madeira)
	var tel := B.box(n, Vector3(2.3, 0.06, 2.0), Vector3(-1.5, 1.7, 0), _m("metal", Color(0.45, 0.4, 0.36), 0.7, 0.4))
	tel.rotation.z = 0.15
	for s in [-1.0, 1.0]:
		B.box(n, Vector3(3.0, 1.2, 0.03), Vector3(1.0, 0.6, s * 1.5), tela)
	B.box(n, Vector3(0.03, 1.2, 3.0), Vector3(2.5, 0.6, 0), tela)
	for k in 6:
		var q := Vector3(r.randf_range(0, 2.2), 0, r.randf_range(-1.2, 1.2))
		var g := Node3D.new()
		g.position = q
		g.rotation.y = r.randf() * TAU
		n.add_child(g)
		var cor = [Color(0.92, 0.9, 0.85), Color(0.55, 0.3, 0.15), Color(0.2, 0.18, 0.16)][r.randi() % 3]
		B.sphere(g, 0.13, Vector3(0, 0.2, 0), B.mat(cor, 0.9, 0.0, "galinha_%d" % (r.randi() % 3)), Vector3(0.9, 0.85, 1.25))
		B.sphere(g, 0.07, Vector3(0, 0.36, 0.12), B.mat(cor, 0.9, 0.0, "galinha_c"))
		B.box(g, Vector3(0.03, 0.05, 0.03), Vector3(0, 0.44, 0.13), B.mat(Color(0.8, 0.1, 0.08), 0.6, 0.0, "crista"))
		B.box(g, Vector3(0.03, 0.02, 0.05), Vector3(0, 0.36, 0.2), B.mat(Color(0.9, 0.6, 0.1), 0.6, 0.0, "bico"))

static func horta(p: Node3D, pos: Vector3, rot: float, r: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot
	p.add_child(n)
	var terra := B.mat(Color(0.28, 0.2, 0.13), 1.0, 0.0, "terra_horta")
	var folha := B.mat(Color(0.25, 0.45, 0.15), 0.8, 0.0, "folha_horta")
	var folha2 := B.mat(Color(0.35, 0.55, 0.2), 0.8, 0.0, "folha_horta2")
	for k in 5:
		B.box(n, Vector3(5.0, 0.18, 0.7), Vector3(0, 0.09, -2.0 + k * 1.0), terra)
		for q in 9:
			B.sphere(n, r.randf_range(0.12, 0.2), Vector3(-2.2 + q * 0.55, 0.25, -2.0 + k * 1.0), folha if (q + k) % 2 == 0 else folha2, Vector3(1, 0.7, 1))
	# espantalho
	var madeira := _m("tabuas", Color(0.4, 0.3, 0.2), 0.9)
	B.box(n, Vector3(0.08, 2.0, 0.08), Vector3(2.9, 1.0, 0), madeira)
	B.box(n, Vector3(1.3, 0.07, 0.07), Vector3(2.9, 1.5, 0), madeira)
	B.box(n, Vector3(0.5, 0.6, 0.25), Vector3(2.9, 1.35, 0), B.mat(Color(0.5, 0.25, 0.2), 0.95, 0.0, "camisa_esp"))
	B.sphere(n, 0.17, Vector3(2.9, 1.85, 0), B.mat(Color(0.8, 0.7, 0.45), 0.95, 0.0, "saco_esp"))
	B.cyl(n, 0.3, 0.02, Vector3(2.9, 1.98, 0), B.mat(Color(0.78, 0.66, 0.4), 0.95, 0.0, "palha"), Vector3.ZERO, 12)
	B.cyl(n, 0.14, 0.12, Vector3(2.9, 2.05, 0), B.mat(Color(0.78, 0.66, 0.4), 0.95, 0.0, "palha"), Vector3.ZERO, 10, 0.12)
	# regador e cerca baixa
	B.cyl(n, 0.12, 0.25, Vector3(-2.9, 0.13, 1.5), B.mat(Color(0.3, 0.5, 0.35), 0.5, 0.5, "regador"), Vector3.ZERO, 10)
	for k in 12:
		B.box(n, Vector3(0.06, 0.6, 0.06), Vector3(-3.3 + k * 0.6, 0.3, 2.7), madeira)
	B.box(n, Vector3(7.0, 0.05, 0.05), Vector3(0, 0.5, 2.7), madeira)

static func lenha(p: Node3D, pos: Vector3, rot: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot
	p.add_child(n)
	var casca := _m("casca", Color(0.4, 0.3, 0.2), 0.95)
	for c in 3:
		for k in 6 - c:
			B.cyl(n, 0.14, 1.2, Vector3(-0.75 + k * 0.3 + c * 0.15, 0.14 + c * 0.25, 0), casca, Vector3(90, 0, 0), 8)
	B.cyl(n, 0.3, 0.45, Vector3(1.4, 0.22, 0.2), casca, Vector3.ZERO, 10)   # cepo
	B.box(n, Vector3(0.03, 0.55, 0.03), Vector3(1.4, 0.65, 0.2), B.mat(Color(0.45, 0.3, 0.15), 0.8), Vector3(0, 0, 30))

static func barricada(p: Node3D, pos: Vector3, rot: float, r: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot
	p.add_child(n)
	for k in 7:
		var x := -1.6 + (k % 4) * 0.95 + (0.45 if k >= 4 else 0.0)
		var y := 0.2 + (0.4 if k >= 4 else 0.0)
		B.box(n, Vector3(0.9, 0.38, 0.5), Vector3(x, y, 0), B.mat(Color(0.6, 0.55, 0.4), 0.95, 0.0, "saco_areia"), Vector3(0, r.randf_range(-6, 6), 0))
	var poste := B.mat(Color(0.3, 0.22, 0.15), 0.9)
	for s in [-1.0, 1.0]:
		var x2 := B.box(n, Vector3(0.1, 0.1, 1.8), Vector3(s * 2.4, 0.6, 0), poste, Vector3(45, 0, 0))
		var x3 := B.box(n, Vector3(0.1, 0.1, 1.8), Vector3(s * 2.4, 0.6, 0), poste, Vector3(-45, 0, 0))

static func lixo(p: Node3D, pos: Vector3, r: RandomNumberGenerator) -> void:
	var cores := [Color(0.15, 0.15, 0.17), Color(0.2, 0.25, 0.2), Color(0.3, 0.3, 0.32)]
	for k in r.randi_range(2, 4):
		B.sphere(p, r.randf_range(0.2, 0.32), pos + Vector3(r.randf_range(-0.6, 0.6), 0.18, r.randf_range(-0.4, 0.4)), B.mat(cores[k % 3], 0.4, 0.0, "saco_lixo_%d" % (k % 3)), Vector3(1, 0.8, 1))
	B.cyl(p, 0.3, 0.8, pos + Vector3(0.9, 0.4, 0), _m("metal", Color(0.35, 0.38, 0.35), 0.6, 0.6), Vector3.ZERO, 12)

static func _flores(p: Node3D, q: Vector3, r: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Floresta.malha(["flores", "arbusto", "capim_alto"][r.randi() % 3])
	mi.position = q
	mi.rotation.y = r.randf() * TAU
	p.add_child(mi)

static func cisterna(p: Node3D, pos: Vector3) -> void:
	B.cyl(p, 1.1, 1.6, pos + Vector3(0, 0.8, 0), B.mat(Color(0.25, 0.32, 0.42), 0.5, 0.0, "cisterna"), Vector3.ZERO, 18)
	B.cyl(p, 1.12, 0.1, pos + Vector3(0, 1.62, 0), B.mat(Color(0.2, 0.26, 0.34), 0.5, 0.0, "cisterna_t"), Vector3.ZERO, 18)
	B.cyl(p, 0.04, 2.2, pos + Vector3(1.0, 1.1, 0), B.mat(Color(0.3, 0.3, 0.3), 0.5, 0.6), Vector3(0, 0, 0), 6)
	B.box(p, Vector3(0.3, 0.2, 0.2), pos + Vector3(1.0, 0.25, 0.4), B.mat(Color(0.6, 0.6, 0.6), 0.4, 0.7))

# ------------------------------------------------------------ preenchimento
## Ocupa os vazios dentro do raio. ocupados: Array de [Vector3 centro, raio].
## Itens fixos (parquinho, torres) vão primeiro nos maiores vazios; o resto vira
## árvores, hortas, galinheiros, lenha, bancos e lixo.
static func preencher(p: Node3D, raio: float, ocupados: Array, r: RandomNumberGenerator, m: WorldGen, extras := {}) -> Array:
	var livres: Array = []
	var passo: float = 3.0 if extras.get("denso", false) else 4.0
	var nx := int(raio * 2.0 / passo)
	for i in nx + 1:
		for k in nx + 1:
			var q := Vector3(-raio + i * passo + r.randf_range(-0.8, 0.8), 0, -raio + k * passo + r.randf_range(-0.8, 0.8))
			if q.length() > raio - 3.5:
				continue
			var folga := 99.0
			for o in ocupados:
				var c: Vector3 = o[0]
				folga = minf(folga, Vector2(q.x - c.x, q.z - c.z).length() - float(o[1]))
			if folga > 0.8:
				livres.append([q, folga])
	livres.sort_custom(func(a, b): return a[1] > b[1])
	var usados: Array = []
	var colocados: Array = []
	var cabe := func(q: Vector3, rr: float) -> bool:
		for u in usados:
			if Vector2(q.x - u[0].x, q.z - u[0].z).length() < rr + u[1]:
				return false
		return true
	var pedidos: Array = extras.get("grandes", [["parquinho", 6.0], ["horta", 4.0], ["galinheiro", 3.0], ["torre", 2.2], ["torre", 2.2]])
	for ped in pedidos:
		var tipo: String = ped[0]
		var rr: float = ped[1]
		for l in livres:
			var q: Vector3 = l[0]
			if l[1] < rr - 0.5 or not cabe.call(q, rr):
				continue
			if tipo == "torre" and q.length() < raio * 0.6:
				continue   # torres perto do muro
			q.y = _alt(p, m, q)
			var rot := atan2(-q.x, -q.z)
			match tipo:
				"parquinho":
					parquinho(p, q, rot, r)
				"horta":
					horta(p, q, rot, r)
				"galinheiro":
					galinheiro(p, q, rot + PI * 0.5, r)
				"torre":
					var t := torre(p, q, rot + PI, m)
					colocados.append(["torre", q, t])
				"cisterna":
					cisterna(p, q)
				"barricada":
					barricada(p, q, rot, r)
			usados.append([q, rr])
			if tipo != "torre":
				colocados.append([tipo, q, null])
			break
	# o resto: árvores e pequenos detalhes
	var arvores := 0
	for l in livres:
		var q: Vector3 = l[0]
		if not cabe.call(q, 1.8):
			continue
		q.y = _alt(p, m, q)
		var dado := r.randf()
		if dado < 0.6:
			arvore(p, q, r)
			arvores += 1
		elif dado < 0.65:
			banco(p, q, r.randf() * TAU)
		elif dado < 0.75:
			lenha(p, q, r.randf() * TAU)
		elif dado < 0.83:
			lixo(p, q, r)
		elif dado < 0.9:
			arvore(p, q, r)
			banco(p, q + Vector3(1.4, 0, 0), PI * 0.5)
		else:
			_flores(p, q, r)
		usados.append([q, 1.6])
	return colocados

static func _alt(p: Node3D, m: WorldGen, local: Vector3) -> float:
	if m == null:
		return 0.0
	var g := p.transform * local
	return m.altura(g.x, g.z) - p.position.y
