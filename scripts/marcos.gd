class_name Marcos
## Construção dos marcos (lugares fortificados de progresso) e dos pontos das
## missões do rádio. Chamado pelo WorldGen ao gerar o trecho (POI "marco"/"missao").

# ------------------------------------------------------------ marco
static func construir_marco(m: WorldGen, n: Node3D, z0: float, k: int, idx: int) -> void:
	var mc := Progresso.marco(idx)
	var r := m._rng_chunk(k, 404)
	var z := z0 + 32.0
	var d := m.direcao(z)
	var rot := atan2(d.x, d.z)
	var c := m.ponto_estrada(z, 0.0)
	var raiz := Node3D.new()
	raiz.name = "Marco_%d" % idx
	raiz.set_meta("area_livre", Vector2(30.0, 34.0))
	raiz.position = c
	raiz.rotation.y = rot
	n.add_child(raiz)
	var hw := WorldGen.LARG_ESTRADA * 0.5
	var cores := [Color(0.55, 0.22, 0.15), Color(0.2, 0.3, 0.42), Color(0.28, 0.36, 0.22), Color(0.6, 0.45, 0.15), Color(0.45, 0.45, 0.45)]
	# muralha de contêineres atravessando o vale (portão aberto na estrada)
	for s in [-1.0, 1.0]:
		for i in 9:
			var x: float = s * (hw + 2.0 + 1.25 + i * 2.5)
			var y0 := m.altura(c.x + x * cos(rot), c.z - x * sin(rot)) - c.y
			for andar in (2 if i % 3 != 1 else 1):
				var cor: Color = cores[(i + andar + (1 if s > 0 else 0)) % cores.size()]
				_conteiner(raiz, Vector3(x, y0 + 1.3 + andar * 2.6, 0), cor, r)
	# portão (folhas abertas) e guarita
	var aco := B.mat(Color(0.25, 0.25, 0.26), 0.5, 0.7)
	for s in [-1.0, 1.0]:
		B.box(raiz, Vector3(0.3, 4.2, 0.3), Vector3(s * (hw + 0.6), 2.1, 0), aco)
		var folha := B.box(raiz, Vector3(3.8, 3.2, 0.12), Vector3(s * (hw + 0.6 + 0.2), 1.7, 1.9), B.mat(Color(0.32, 0.3, 0.27), 0.6, 0.6))
		folha.rotation_degrees.y = s * 80.0
	B.box(raiz, Vector3(WorldGen.LARG_ESTRADA + 1.6, 0.5, 0.4), Vector3(0, 4.4, 0), aco)
	B.box(raiz, Vector3(WorldGen.LARG_ESTRADA + 1.0, 1.1, 0.06), Vector3(0, 5.2, -0.1), B.mat(Color(0.12, 0.3, 0.18), 0.8))
	Lugares._placa(raiz, Vector3(0, 5.2, -0.16), PI, String(mc.nome).to_upper(), Color(0.95, 0.92, 0.8))
	# torres de vigia com holofote nos cantos do portão
	for s in [-1.0, 1.0]:
		_torre(raiz, Vector3(s * (hw + 4.5), 0, -3.5), r)
	# acampamento lá dentro: barracas, fogueira, bandeiras
	var lona := [Color(0.35, 0.4, 0.3), Color(0.45, 0.4, 0.3), Color(0.3, 0.33, 0.4)]
	for i in 6:
		var lado := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(lado * (hw + 4.0 + r.randf() * 8.0), 0, 6.0 + (i / 2) * 6.0)
		p.y = m.altura(c.x + p.x * cos(rot) + p.z * sin(rot), c.z - p.x * sin(rot) + p.z * cos(rot)) - c.y
		_barraca(raiz, p, lona[i % 3], r)
	var fog := Node3D.new()
	fog.position = Vector3(hw + 3.0, 0, 10.0)
	raiz.add_child(fog)
	B.cyl(fog, 0.6, 0.25, Vector3(0, 0.12, 0), B.mat(Color(0.3, 0.3, 0.3), 0.9), Vector3.ZERO, 10)
	B.sphere(fog, 0.35, Vector3(0, 0.45, 0), B.emissive(Color(1.0, 0.5, 0.15), 3.0), Vector3(1, 1.6, 1), 8)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 1.4
	l.omni_range = 10.0
	l.position = Vector3(0, 1.2, 0)
	fog.add_child(l)
	fog.set_meta("nao_mesclar", true)
	# peça central conforme o tema
	match String(mc.tema):
		"refinaria":
			for i in 3:
				var tq := Vector3(-hw - 14.0 - i * 7.0, 0, 18.0)
				B.cyl(raiz, 3.0, 6.0, tq + Vector3(0, 3.0, 0), B.mat(Color(0.75, 0.72, 0.66), 0.5, 0.3), Vector3.ZERO, 18)
				B.cyl(raiz, 3.1, 0.3, tq + Vector3(0, 6.1, 0), B.mat(Color(0.5, 0.48, 0.44), 0.6, 0.4), Vector3.ZERO, 18)
			B.cyl(raiz, 0.5, 18.0, Vector3(hw + 16.0, 9.0, 22.0), B.mat(Color(0.4, 0.38, 0.35), 0.6, 0.5), Vector3.ZERO, 10)
		"base":
			var hang := B.mat(Color(0.42, 0.44, 0.4), 0.7, 0.4)
			B.box(raiz, Vector3(16.0, 7.0, 14.0), Vector3(-hw - 16.0, 3.5, 20.0), hang)
			B.box(raiz, Vector3(10.0, 1.2, 1.4), Vector3(hw + 14.0, 1.0, 20.0), B.mat(Color(0.3, 0.33, 0.28), 0.6, 0.4), Vector3(0, 30, -8))
			B.box(raiz, Vector3(1.6, 1.0, 9.0), Vector3(hw + 14.0, 1.4, 20.0), B.mat(Color(0.3, 0.33, 0.28), 0.6, 0.4), Vector3(0, 30, 0))
		"usina":
			for i in 2:
				B.cyl(raiz, 4.0, 16.0, Vector3(-hw - 18.0, 8.0, 14.0 + i * 11.0), B.mat(Color(0.7, 0.7, 0.68), 0.8), Vector3.ZERO, 20, 3.0)
		"porto":
			B.box(raiz, Vector3(0.6, 18.0, 0.6), Vector3(hw + 16.0, 9.0, 18.0), B.mat(Color(0.85, 0.55, 0.1), 0.6, 0.5))
			B.box(raiz, Vector3(0.6, 0.6, 16.0), Vector3(hw + 16.0, 17.6, 12.0), B.mat(Color(0.85, 0.55, 0.1), 0.6, 0.5))
	# gente: vigias, médico, vendedor e moradores
	var funcoes := ["vigia", "vigia", "medico", "vendedor", "morador", "morador", "mecanico"]
	for i in funcoes.size():
		var lado := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(lado * (hw + 2.5 + r.randf() * 5.0), 0, 4.0 + r.randf() * 14.0)
		if funcoes[i] == "vigia":
			p = Vector3(lado * (hw + 1.6), 0, 1.8)
		var gp := c + Vector3(p.x * cos(rot) + p.z * sin(rot), 0, -p.x * sin(rot) + p.z * cos(rot))
		gp.y = m.altura(gp.x, gp.z)
		var h := Lugares._pessoa(n, gp, rot + (PI if funcoes[i] == "vigia" else r.randf() * TAU), funcoes[i], r, m, "marco:%d:%d" % [idx, i])
		if funcoes[i] == "vigia":
			h.arma = "rifle"
		h.set_meta("nao_mesclar", true)

static func _conteiner(p: Node3D, pos: Vector3, cor: Color, r: RandomNumberGenerator) -> void:
	var mat := B.pintura(cor, r.randf_range(0.3, 0.6), 0.6, 0.3)
	B.box(p, Vector3(2.45, 2.55, 6.0), pos, mat, Vector3(0, 90, 0))
	var friso := B.mat(cor.darkened(0.35), 0.7, 0.3)
	for i in 5:
		B.box(p, Vector3(2.47, 2.4, 0.05), pos + Vector3(-2.4 + i * 1.2, 0, 0), friso, Vector3(0, 90, 0))

static func _torre(p: Node3D, pos: Vector3, _r: RandomNumberGenerator) -> void:
	var mad := B.mat(Color(0.35, 0.26, 0.17), 0.9)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.box(p, Vector3(0.18, 7.0, 0.18), pos + Vector3(sx * 1.1, 3.5, sz * 1.1), mad)
	B.box(p, Vector3(2.8, 0.15, 2.8), pos + Vector3(0, 6.0, 0), mad)
	for i in 4:
		var a := i * PI * 0.5
		B.box(p, Vector3(2.8, 1.0, 0.08), pos + Vector3(sin(a) * 1.4, 6.6, cos(a) * 1.4), mad, Vector3(0, rad_to_deg(a), 0))
	B.box(p, Vector3(3.2, 0.12, 3.2), pos + Vector3(0, 8.0, 0), B.mat(Color(0.3, 0.32, 0.3), 0.7, 0.4))
	B.box(p, Vector3(0.1, 1.2, 0.1), pos + Vector3(0, 7.4, 0), mad)
	var holo := SpotLight3D.new()
	holo.position = pos + Vector3(0, 7.6, -1.4)
	holo.rotation_degrees = Vector3(-25, 180, 0)
	holo.light_energy = 6.0
	holo.spot_range = 40.0
	holo.spot_angle = 22.0
	holo.light_color = Color(1.0, 0.95, 0.85)
	holo.set_meta("nao_mesclar", true)
	p.add_child(holo)
	B.cyl(p, 0.25, 0.4, pos + Vector3(0, 7.6, -1.25), B.emissive(Color(1.0, 0.95, 0.85), 2.5), Vector3(90, 0, 0), 10)

static func _barraca(p: Node3D, pos: Vector3, cor: Color, r: RandomNumberGenerator) -> void:
	var b := Node3D.new()
	b.position = pos
	b.rotation.y = r.randf() * TAU
	p.add_child(b)
	var lona := B.mat(cor, 0.95)
	B.box(b, Vector3(2.6, 0.05, 3.2), Vector3(-0.62, 0.85, 0), lona, Vector3(0, 0, 50))
	B.box(b, Vector3(2.6, 0.05, 3.2), Vector3(0.62, 0.85, 0), lona, Vector3(0, 0, -50))
	B.box(b, Vector3(0.08, 1.75, 0.08), Vector3(0, 0.87, 1.55), B.mat(Color(0.3, 0.25, 0.18), 0.9))

# ------------------------------------------------------------ missões
static func construir_missao(m: WorldGen, n: Node3D, z0: float, k: int, id: int, ms: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(ms.get("sem", k))
	var z: float = ms.z
	var lat: float = ms.lat
	var c := m.ponto_estrada(z, lat)
	c.y = m.altura(c.x, c.z)
	var d := m.direcao(z)
	var rot := atan2(d.x, d.z)
	var raiz := Node3D.new()
	raiz.name = "Missao_%d" % id
	raiz.set_meta("area_livre", Vector2(9.0, 9.0))
	raiz.position = c
	raiz.rotation.y = rot + (PI * 0.5 if lat > 0.0 else -PI * 0.5)
	raiz.set_meta("nao_mesclar", true)
	n.add_child(raiz)
	var feita: bool = ms.estado != "ativa"
	var chave := "missao:%d" % id
	# placa na beira da estrada apontando
	var pl := m.ponto_estrada(z - 14.0, signf(lat) * (WorldGen.LARG_ESTRADA * 0.5 + 1.5))
	pl.y = m.elevacao(z) + 2.0
	match String(ms.tipo):
		"diesel":
			_galpao(raiz, Vector3(0, 0, 0), Color(0.5, 0.48, 0.42), r)
			for i in 6:
				B.cyl(raiz, 0.3, 0.9, Vector3(-3.0 + i * 0.7, 0.45, 3.2), B.mat([Color(0.55, 0.12, 0.08), Color(0.15, 0.3, 0.5)][i % 2], 0.6, 0.3), Vector3.ZERO, 12)
			Lugares._vasculhavel(raiz, Vector3(0, 1.2, 0), "Depósito de combustível", "deposito_diesel", 1.0, m, chave)
			_zumbis(m, n, c, r, 4 + m.faixa(z) * 2, id, "")
			Lugares._placa(n, pl, rot + PI, "COMBUSTÍVEL\n%s" % ("→" if lat > 0 else "←"), Color(0.9, 0.6, 0.2))
		"remedios":
			var branca := B.mat(Color(0.82, 0.82, 0.78), 0.9)
			for i in 2:
				B.box(raiz, Vector3(4.0, 0.06, 6.0), Vector3(-2.5 + i * 5.0, 2.4, 0), branca, Vector3(0, 0, -8.0 + i * 16.0))
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						B.box(raiz, Vector3(0.08, 2.2, 0.08), Vector3(-2.5 + i * 5.0 + sx * 1.9, 1.1, sz * 2.9), B.mat(Color(0.4, 0.4, 0.4), 0.6, 0.5))
			B.box(raiz, Vector3(1.0, 0.25, 1.0), Vector3(-2.5, 2.5, 0), B.mat(Color(0.8, 0.1, 0.1), 0.8), Vector3(0, 0, -8))
			B.box(raiz, Vector3(0.25, 0.26, 1.0), Vector3(-2.5, 2.5, 0), B.mat(Color(0.95, 0.95, 0.95), 0.8), Vector3(0, 0, -8))
			for i in 4:
				B.box(raiz, Vector3(0.7, 0.5, 1.9), Vector3(-3.5 + i * 2.2, 0.4, -1.0), B.mat(Color(0.5, 0.52, 0.5), 0.6, 0.4))
			Lugares._vasculhavel(raiz, Vector3(-2.5, 1.0, 1.5), "Hospital de campanha", "hospital_campanha", 1.0, m, chave)
			_zumbis(m, n, c, r, 5 + m.faixa(z) * 2, id, "")
			Lugares._placa(n, pl, rot + PI, "HOSPITAL\n%s" % ("→" if lat > 0 else "←"), Color(0.9, 0.3, 0.25))
		"militar":
			Eventos._militar(m, n, z, rot, r, k)
			Lugares._vasculhavel(raiz, Vector3(0, 1.0, 0), "Caixas do exército", "militar", 1.0, m, chave)
		"socorro":
			_galpao(raiz, Vector3(0, 0, 0), Color(0.62, 0.6, 0.55), r)
			var tab := B.mat(Color(0.4, 0.3, 0.2), 0.9)
			for i in 5:
				B.box(raiz, Vector3(1.2, 0.15, 0.05), Vector3(-1.2 + i * 0.6, 1.2 + (i % 2) * 0.4, 3.05), tab, Vector3(0, 0, r.randf_range(-20, 20)))
			Lugares._placa(raiz, Vector3(0, 3.4, 3.1), 0.0, "SOCORRO" if not feita else "", Color(0.85, 0.15, 0.1))
			if not feita:
				_zumbis(m, n, c, r, 6 + m.faixa(z) * 2, id, "cerco")
			Lugares._placa(n, pl, rot + PI, "SOS %s" % ("→" if lat > 0 else "←"), Color(0.95, 0.3, 0.2))
		"sinal":
			# van tombada com o rádio ligado
			var van := Node3D.new()
			van.rotation = Vector3(0, r.randf() * TAU, PI * 0.45)
			van.position = Vector3(0, 1.0, 0)
			raiz.add_child(van)
			B.box(van, Vector3(2.0, 2.1, 4.6), Vector3.ZERO, B.pintura(Color(0.82, 0.82, 0.8), 0.4))
			B.box(van, Vector3(2.02, 0.7, 1.2), Vector3(0, 0.4, 1.9), B.mat(Color(0.1, 0.12, 0.14), 0.2, 0.3))
			B.cyl(raiz, 0.04, 4.0, Vector3(0.6, 2.0, 0.4), B.mat(Color(0.4, 0.4, 0.4), 0.5, 0.7), Vector3(0, 0, 30), 6)
			var luz := OmniLight3D.new()
			luz.light_color = Color(0.3, 1.0, 0.4)
			luz.light_energy = 1.2
			luz.omni_range = 5.0
			luz.position = Vector3(0, 1.5, 0)
			raiz.add_child(luz)
			Lugares._vasculhavel(raiz, Vector3(0.0, 1.0, 1.5), "Van com rádio ligado", "acampamento", 0.5, m, chave)
			_zumbis(m, n, c, r, 3 + m.faixa(z), id, "")

static func _galpao(p: Node3D, pos: Vector3, cor: Color, r: RandomNumberGenerator) -> void:
	var par := B.pintura(cor, r.randf_range(0.3, 0.5), 0.8, 0.1)
	B.box(p, Vector3(8.0, 3.2, 0.2), pos + Vector3(0, 1.6, -3.0), par)
	B.box(p, Vector3(0.2, 3.2, 6.0), pos + Vector3(-4.0, 1.6, 0), par)
	B.box(p, Vector3(0.2, 3.2, 6.0), pos + Vector3(4.0, 1.6, 0), par)
	B.box(p, Vector3(2.6, 3.2, 0.2), pos + Vector3(-2.7, 1.6, 3.0), par)
	B.box(p, Vector3(2.6, 3.2, 0.2), pos + Vector3(2.7, 1.6, 3.0), par)
	B.box(p, Vector3(8.6, 0.12, 6.8), pos + Vector3(0, 3.3, 0), B.mat(Color(0.35, 0.32, 0.3), 0.6, 0.6), Vector3(4, 0, 0))

static func _zumbis(m: WorldGen, n: Node3D, c: Vector3, r: RandomNumberGenerator, qtd: int, id: int, modo: String) -> void:
	for i in qtd:
		var a := r.randf() * TAU
		var dist := r.randf_range(4.0, 9.0) if modo == "cerco" else r.randf_range(5.0, 16.0)
		var p := c + Vector3(cos(a), 0, sin(a)) * dist
		p.y = m.altura(p.x, p.z) + 0.05
		var z := m.criar_zumbi(n, p, a + PI, r.randi())
		z.set_meta("missao", id)
		if modo == "cerco":
			z.estado = Zumbi.Estado.INVESTIGANDO
			z.alvo_pos = c
