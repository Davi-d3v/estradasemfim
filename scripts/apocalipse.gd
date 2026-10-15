class_name Apocalipse
## Detalhes que contam o fim do mundo na beira da estrada (referências: Days Gone,
## The Last of Us, State of Decay, Project Zomboid): manchas e lixo no asfalto,
## sacos de corpos, carros queimados, barricadas de quarentena, campos de
## refugiados abandonados, mensagens pintadas, postes caídos, helicóptero caído,
## mato rompendo o asfalto e fumaça de incêndios no horizonte.

const MENSAGENS := ["SOCORRO", "NÃO PARE", "INFECTADOS →", "EVACUAÇÃO KM 40", "ELES OUVEM", "FUJAM", "SEM SAÍDA", "DEUS NOS ABANDONOU", "MÃE ESTOU INDO P/ SERRA"]
const PLACAS := ["ZONA DE QUARENTENA\nACESSO PROIBIDO", "TOQUE DE RECOLHER\n18H ÀS 6H", "EVACUAÇÃO →\nCENTRO DE TRIAGEM", "ÁREA CONTAMINADA\nNÃO ULTRAPASSE", "DEFESA CIVIL\nPONTO DE RESGATE"]

static func _m(nome: String, cor: Color, rough := 0.9, metal := 0.0) -> Material:
	return Texturas.material(nome, cor, rough, metal)

## Ponto na estrada/acostamento com a altura certa e o ângulo da estrada.
static func _pt(m: WorldGen, z: float, lat: float) -> Array:
	var p := m.ponto_estrada(z, lat)
	var d := m.direcao(z)
	if absf(lat) > WorldGen.LARG_ESTRADA * 0.5 + 0.3:
		p.y = m.altura(p.x, p.z)
	else:
		p.y = m.elevacao(z) + 0.06
	return [p, atan2(d.x, d.z)]

static func chunk(n: Node3D, z0: float, k: int, m: WorldGen, bio: String) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([m.semente, k, "apoc"])
	var hw := WorldGen.LARG_ESTRADA * 0.5
	# manchas (sangue seco, óleo, queimado) e lixo em todo trecho
	for i in r.randi_range(3, 7):
		var a := _pt(m, z0 + r.randf() * WorldGen.TAM, r.randf_range(-hw + 0.5, hw - 0.5))
		var cor: Color = [Color(0.22, 0.05, 0.04), Color(0.05, 0.05, 0.05), Color(0.12, 0.1, 0.08), Color(0.3, 0.06, 0.05)][r.randi() % 4]
		var mk := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(r.randf_range(0.8, 2.6), r.randf_range(0.7, 2.2))
		mk.mesh = pm
		mk.material_override = _mat_mancha(cor)
		mk.position = a[0] + Vector3(0, 0.015, 0)
		mk.rotation.y = r.randf() * TAU
		mk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mk)
	for i in r.randi_range(4, 10):
		var a2 := _pt(m, z0 + r.randf() * WorldGen.TAM, r.randf_range(-hw - 2.5, hw + 2.5))
		_lixo(n, a2[0], r)
	if r.randf() < 0.18:
		var a3 := _pt(m, z0 + r.randf() * WorldGen.TAM, r.randf_range(-1.5, 1.5))
		_mensagem_asfalto(n, a3[0], a3[1], MENSAGENS[r.randi() % MENSAGENS.size()], r)
	if r.randf() < 0.14:
		var lado := 1.0 if r.randf() < 0.5 else -1.0
		var a4 := _pt(m, z0 + r.randf() * WorldGen.TAM, lado * (hw + 2.6))
		_placa_oficial(n, a4[0], a4[1] + (PI * 0.5 if lado > 0 else -PI * 0.5) + PI, PLACAS[r.randi() % PLACAS.size()], r)
	if r.randf() < 0.12:
		var lado5 := 1.0 if r.randf() < 0.5 else -1.0
		var a5 := _pt(m, z0 + r.randf_range(8.0, WorldGen.TAM - 8.0), lado5 * (hw + 1.6))
		_sacos_corpos(n, a5[0], a5[1], r)
	if r.randf() < 0.12:
		var lado2 := 1.0 if r.randf() < 0.5 else -1.0
		var a6 := _pt(m, z0 + r.randf_range(8.0, WorldGen.TAM - 8.0), lado2 * r.randf_range(hw + 1.5, hw + 5.0))
		_carro_queimado(n, a6[0], a6[1] + r.randf_range(-0.6, 0.6), r)
	if r.randf() < 0.07:
		_barricada_quarentena(n, m, z0 + WorldGen.TAM * 0.5, r)
	if bio != "cidade" and r.randf() < 0.05:
		var lado3 := 1.0 if r.randf() < 0.5 else -1.0
		var zc := z0 + WorldGen.TAM * 0.5
		var pc := m.ponto_estrada(zc, lado3 * r.randf_range(18.0, 26.0))
		if m._lugar_livre(pc.x, pc.z, 14.0):
			pc.y = m.altura(pc.x, pc.z)
			_campo_refugiados(n, m, pc, m.direcao(zc), r)
	if r.randf() < 0.07:
		var lado4 := 1.0 if r.randf() < 0.5 else -1.0
		var a8 := _pt(m, z0 + r.randf() * WorldGen.TAM, lado4 * (hw + 3.2))
		_poste_caido(n, a8[0], a8[1], lado4, r)
	if bio in ["rural", "serra", "alagado"] and r.randf() < 0.025:
		var lado5 := 1.0 if r.randf() < 0.5 else -1.0
		var ph := m.ponto_estrada(z0 + WorldGen.TAM * 0.5, lado5 * r.randf_range(25.0, 40.0))
		if m._lugar_livre(ph.x, ph.z, 12.0):
			ph.y = m.altura(ph.x, ph.z)
			_helicoptero(n, ph, r)
	if r.randf() < 0.06:
		var lado6 := 1.0 if r.randf() < 0.5 else -1.0
		var a9 := _pt(m, z0 + r.randf_range(10.0, WorldGen.TAM - 10.0), lado6 * (hw + 1.0))
		_veiculo_oficial(n, a9[0], a9[1] + r.randf_range(-0.3, 0.3), r)
	if k > 2 and r.randf() < 0.07:
		Exploracao.pichacao(n, m, z0, k, r)
	_mato_no_asfalto(n, m, z0, r)

# ------------------------------------------------------------ peças
static func _lixo(n: Node3D, p: Vector3, r: RandomNumberGenerator) -> void:
	match r.randi() % 6:
		0, 1:   # papel / sacola
			var c := Color(0.85, 0.83, 0.78) if r.randf() < 0.5 else Color.from_hsv(r.randf(), 0.4, 0.6)
			var f := B.box(n, Vector3(r.randf_range(0.2, 0.5), 0.01, r.randf_range(0.2, 0.4)), p + Vector3(0, 0.02, 0), B.mat(c, 0.9))
			f.rotation = Vector3(r.randf_range(-0.1, 0.1), r.randf() * TAU, 0)
		2:   # mala abandonada
			var mala := B.box(n, Vector3(0.55, 0.22, 0.4), p + Vector3(0, 0.11, 0), B.mat(Color.from_hsv(r.randf(), 0.5, 0.35), 0.6))
			mala.rotation = Vector3(0, r.randf() * TAU, PI * 0.5 * float(r.randf() < 0.4))
		3:   # roupa
			var rp := B.box(n, Vector3(0.5, 0.04, 0.6), p + Vector3(0, 0.03, 0), B.mat(Color.from_hsv(r.randf(), 0.5, 0.4), 0.95))
			rp.rotation.y = r.randf() * TAU
		4:   # pneu solto
			var pn := B.cyl(n, 0.35, 0.22, p + Vector3(0, 0.11, 0), B.mat(Color(0.06, 0.06, 0.06), 0.9, 0.0, "pneu_solto"), Vector3.ZERO, 12)
		5:   # garrafas e latas
			for q in 3:
				B.cyl(n, 0.04, 0.22, p + Vector3(r.randf_range(-0.4, 0.4), 0.04, r.randf_range(-0.4, 0.4)), B.mat(Color(0.2, 0.4, 0.2, 1.0), 0.2, 0.0, "garrafa_verde"), Vector3(90, r.randf() * 360.0, 0), 6)

static func _mensagem_asfalto(n: Node3D, p: Vector3, rot: float, txt: String, r: RandomNumberGenerator) -> void:
	var l := Label3D.new()
	l.text = txt
	l.font_size = 220
	l.pixel_size = 0.012
	l.modulate = [Color(0.85, 0.85, 0.82), Color(0.75, 0.12, 0.08), Color(0.9, 0.75, 0.15)][r.randi() % 3]
	l.position = p + Vector3(0, 0.03, 0)
	l.rotation = Vector3(-PI * 0.5, rot + PI + r.randf_range(-0.2, 0.2), 0)
	l.shaded = true
	l.double_sided = false
	l.set_meta("nao_mesclar", true)
	n.add_child(l)

static func _placa_oficial(n: Node3D, p: Vector3, rot: float, txt: String, r: RandomNumberGenerator) -> void:
	var pl := Node3D.new()
	pl.position = p
	pl.rotation = Vector3(0, rot, r.randf_range(-0.12, 0.12))
	pl.set_meta("nao_mesclar", true)
	n.add_child(pl)
	var metal := _m("metal", Color(0.55, 0.55, 0.53), 0.5, 0.6)
	for sx in [-0.9, 0.9]:
		B.box(pl, Vector3(0.07, 2.4, 0.07), Vector3(sx, 1.2, 0), metal)
	var vermelho := txt.begins_with("ZONA") or txt.begins_with("ÁREA")
	B.box(pl, Vector3(2.3, 1.15, 0.04), Vector3(0, 1.95, 0), B.mat(Color(0.85, 0.15, 0.1) if vermelho else Color(0.92, 0.75, 0.12), 0.7))
	var l := Label3D.new()
	l.text = txt
	l.font_size = 64
	l.pixel_size = 0.005
	l.modulate = Color(0.98, 0.96, 0.9) if vermelho else Color(0.08, 0.07, 0.06)
	l.position = Vector3(0, 1.95, 0.03)
	l.double_sided = false
	l.shaded = true
	pl.add_child(l)
	# furos de bala e ferrugem
	for q in r.randi_range(0, 5):
		B.box(pl, Vector3(0.04, 0.04, 0.05), Vector3(r.randf_range(-1, 1), 1.95 + r.randf_range(-0.45, 0.45), 0.0), B.mat(Color(0.05, 0.05, 0.05), 0.9))

## Mancha no asfalto com borda irregular e transparência (sangue seco, óleo, queimado).
static var _manchas := {}
static func _mat_mancha(cor: Color) -> StandardMaterial3D:
	var k := cor.to_html()
	if _manchas.has(k):
		return _manchas[k]
	Fogo._texturas()
	var m := StandardMaterial3D.new()
	m.albedo_texture = Fogo._tex_fumaca
	m.albedo_color = Color(cor.r, cor.g, cor.b, 0.92)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.roughness = 0.35 if cor.r > 0.2 else 0.7
	m.metallic_specular = 0.6
	_manchas[k] = m
	return m

static func _sacos_corpos(n: Node3D, p: Vector3, rot: float, r: RandomNumberGenerator) -> void:
	# sacos de vinil cinza-azulado (não preto chapado), com zíper, cabeça e pés marcando o volume
	var saco := B.mat(Color(0.2, 0.22, 0.26), 0.3, 0.05, "saco_corpo")
	var ziper := B.mat(Color(0.55, 0.55, 0.52), 0.4, 0.6, "ziper_saco")
	var amarelo := B.mat(Color(0.85, 0.7, 0.1), 0.6, 0.0, "fita_amarela")
	var dir := Vector3(sin(rot), 0, cos(rot))
	var lado := Vector3(dir.z, 0, -dir.x)
	for i in r.randi_range(3, 6):
		var q := p + dir * (i * 0.8 - 2.0) + lado * r.randf_range(-0.15, 0.15)
		var no := Node3D.new()
		no.position = q
		no.rotation.y = rot + PI * 0.5 + r.randf_range(-0.12, 0.12)   # deitados lado a lado, de través
		n.add_child(no)
		var corpo := B.capsule(no, 0.27, 1.85, Vector3(0, 0.13, 0), saco, Vector3(90, 0, 0))
		corpo.scale = Vector3(1.0, 1.0, 0.48)
		B.sphere(no, 0.14, Vector3(0, 0.2, 0.72), saco, Vector3(1, 0.7, 1), 8)          # cabeça
		for sx in [-0.09, 0.09]:
			B.sphere(no, 0.07, Vector3(sx, 0.2, -0.82), saco, Vector3(1, 0.8, 1.2), 6)  # pés
		B.box(no, Vector3(0.015, 0.012, 1.55), Vector3(0, 0.265, 0.02), ziper)
		B.box(no, Vector3(0.1, 0.012, 0.07), Vector3(0.12, 0.26, 0.62), amarelo)
	# cone e fita de isolamento
	for sx in [-1.0, 1.0]:
		var c = p + dir * sx * 3.0 + lado * 0.6
		B.cyl(n, 0.18, 0.7, c + Vector3(0, 0.35, 0), B.mat(Color(0.95, 0.4, 0.1), 0.6, 0.0, "cone"), Vector3.ZERO, 8, 0.015)
		B.box(n, Vector3(0.42, 0.04, 0.42), c + Vector3(0, 0.02, 0), B.mat(Color(0.95, 0.4, 0.1), 0.6, 0.0, "cone"))

static func _carro_queimado(n: Node3D, p: Vector3, rot: float, r: RandomNumberGenerator) -> void:
	var c := Node3D.new()
	c.position = p
	c.rotation = Vector3(0, rot, r.randf_range(-0.04, 0.04))
	n.add_child(c)
	var queimado := _m("metal", Color(0.12, 0.1, 0.09), 0.9, 0.3)
	var ferrugem := _m("metal", Color(0.35, 0.18, 0.1), 0.95, 0.2)
	B.box(c, Vector3(1.75, 0.55, 4.2), Vector3(0, 0.55, 0), queimado)
	B.box(c, Vector3(1.55, 0.5, 2.0), Vector3(0, 1.05, -0.2), ferrugem)
	B.box(c, Vector3(1.5, 0.04, 1.9), Vector3(0, 1.32, -0.2), queimado)
	for sx in [-0.85, 0.85]:
		for sz in [-1.3, 1.35]:
			B.cyl(c, 0.3, 0.2, Vector3(sx, 0.3, sz), B.mat(Color(0.15, 0.13, 0.12), 0.9, 0.5, "aro_queimado"), Vector3(0, 0, 90), 10)
	# vão vazio das janelas (sem vidro)
	B.box(c, Vector3(1.56, 0.36, 1.7), Vector3(0, 1.05, -0.2), B.mat(Color(0.02, 0.02, 0.02), 1.0, 0.0, "vao_carro"))
	# mancha de fuligem no chão
	var fu := B.box(n, Vector3(3.0, 0.01, 5.0), p + Vector3(0, 0.02, 0), B.mat(Color(0.04, 0.04, 0.04), 1.0, 0.0, "fuligem"))
	fu.rotation.y = rot

static func _barricada_quarentena(n: Node3D, m: WorldGen, z: float, r: RandomNumberGenerator) -> void:
	var hw := WorldGen.LARG_ESTRADA * 0.5
	var areia := _m("tecido", Color(0.6, 0.55, 0.4), 0.95)
	var concreto := _m("concreto", Color(0.62, 0.6, 0.56))
	# barreiras new jersey em zigue-zague (deixam passar devagar)
	for i in 3:
		var a := _pt(m, z + (i - 1) * 6.0, (-1.0 if i % 2 == 0 else 1.0) * 1.6)
		var b := B.box(n, Vector3(3.6, 0.85, 0.55), a[0] + Vector3(0, 0.42, 0), concreto)
		b.rotation.y = a[1] + PI * 0.5 + r.randf_range(-0.2, 0.2)
		var faixa := B.box(n, Vector3(3.62, 0.12, 0.57), a[0] + Vector3(0, 0.7, 0), B.mat(Color(0.85, 0.15, 0.1), 0.7, 0.0, "faixa_barreira"))
		if r.randf() < 0.7:
			var nb: Vector3 = b.global_transform.basis.z if b.is_inside_tree() else Basis(Vector3.UP, b.rotation.y).z
			Grafite.colar(n, a[0] + Vector3(0, 0.38, 0) + nb * 0.27, nb, r.randf_range(1.2, 1.9), r)
		faixa.rotation.y = b.rotation.y
	# sacos de areia e arame farpado no acostamento
	for lado in [-1.0, 1.0]:
		for i in 6:
			var a2 := _pt(m, z - 2.5 + i * 1.0, lado * (hw + 1.0))
			for h in 2:
				var s := B.box(n, Vector3(0.95, 0.3, 0.5), a2[0] + Vector3(0, 0.15 + h * 0.3, 0), areia)
				s.rotation.y = a2[1] + PI * 0.5 + r.randf_range(-0.1, 0.1)
		var arame := B.mat(Color(0.4, 0.4, 0.38), 0.5, 0.8, "arame")
		for i in 10:
			var a3 := _pt(m, z - 9.0 + i * 1.8, lado * (hw + 3.0))
			var anel := B.cyl(n, 0.45, 0.02, a3[0] + Vector3(0, 0.45, 0), arame, Vector3(0, 0, 90), 10)
			anel.rotation.y = a3[1]
	var ap := _pt(m, z - 10.0, hw + 2.6)
	_placa_oficial(n, ap[0], ap[1] + PI, PLACAS[r.randi() % 2], r)
	# guarita derrubada e tambor queimado
	var g := _pt(m, z + 4.0, -(hw + 4.5))
	var gu := B.box(n, Vector3(1.8, 2.4, 1.8), g[0] + Vector3(0, 1.0, 0), _m("metal", Color(0.3, 0.33, 0.25), 0.7, 0.4))
	gu.rotation = Vector3(0.0, g[1], 0.25)
	_tambor_fogo(n, _pt(m, z + 1.0, hw + 3.4)[0], r, true)

static func _tambor_fogo(n: Node3D, p: Vector3, r: RandomNumberGenerator, aceso: bool) -> void:
	B.cyl(n, 0.3, 0.9, p + Vector3(0, 0.45, 0), _m("metal", Color(0.3, 0.17, 0.1), 0.9, 0.4), Vector3.ZERO, 10)
	if not aceso:
		return
	var fogo := Node3D.new()
	fogo.position = p + Vector3(0, 1.0, 0)
	fogo.set_meta("nao_mesclar", true)
	n.add_child(fogo)
	B.sphere(fogo, 0.28, Vector3.ZERO, B.emissive(Color(1.0, 0.45, 0.12), 3.5), Vector3(1, 1.4, 1), 6)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.25)
	l.light_energy = 1.4
	l.omni_range = 7.0
	l.position = Vector3(0, 0.4, 0)
	fogo.add_child(l)
	fogo.add_child(fumaca(1.0, 6.0))

## Coluna de fumaça (partículas). escala 1 = tambor; 10+ = incêndio ao longe.
static func fumaca(escala: float, altura: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18 if escala < 3.0 else 40
	p.lifetime = 4.0 + escala * 0.6
	p.preprocess = p.lifetime
	var mesh := SphereMesh.new()
	mesh.radius = 0.35 * escala
	mesh.height = 0.7 * escala
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.15, 0.14, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	p.material_override = mat
	p.direction = Vector3(0, 1, 0)
	p.spread = 12.0
	p.gravity = Vector3(0.4 * escala, altura / (p.lifetime * p.lifetime) * 0.6, 0)
	p.initial_velocity_min = 0.4 * escala
	p.initial_velocity_max = 0.9 * escala
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.4))
	curva.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = curva
	var g := Gradient.new()
	g.set_color(0, Color(0.25, 0.22, 0.2, 0.55))
	g.set_color(1, Color(0.35, 0.34, 0.33, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

static func _campo_refugiados(n: Node3D, m: WorldGen, c: Vector3, dir: Vector3, r: RandomNumberGenerator) -> void:
	var raiz := Node3D.new()
	raiz.position = c
	raiz.rotation.y = atan2(dir.x, dir.z)
	n.add_child(raiz)
	var lona_az := _m("tecido", Color(0.2, 0.32, 0.55), 0.9)
	var lona_br := _m("tecido", Color(0.78, 0.78, 0.74), 0.9)
	for i in r.randi_range(4, 7):
		var q := Vector3(r.randf_range(-10, 10), 0, r.randf_range(-8, 8))
		var gq := raiz.transform * q
		var h := m.altura(gq.x, gq.z) - c.y
		var t := Node3D.new()
		t.position = q + Vector3(0, h, 0)
		t.rotation.y = r.randf() * TAU
		raiz.add_child(t)
		var lona: Material = lona_br if r.randf() < 0.5 else lona_az
		var tri := PackedVector2Array([Vector2(-1.4, 0), Vector2(1.4, 0), Vector2(0, 1.7)])
		var ex := B.extruded(t, tri, 3.0, Vector3.ZERO, lona)
		if r.randf() < 0.35:
			ex.rotation.z = 0.5   # meio desabada
		if lona == lona_br:
			B.box(t, Vector3(0.05, 0.4, 0.12), Vector3(0, 0.9, 1.51), B.mat(Color(0.8, 0.1, 0.08), 0.7, 0.0, "cruz_v"))
			B.box(t, Vector3(0.05, 0.12, 0.4), Vector3(0, 0.9, 1.51), B.mat(Color(0.8, 0.1, 0.08), 0.7, 0.0, "cruz_v")).rotation.y = PI * 0.5
	# colchões, caixas de doação, varal, tambores
	for i in 4:
		var q2 := Vector3(r.randf_range(-9, 9), 0, r.randf_range(-7, 7))
		var cm := B.box(raiz, Vector3(0.9, 0.15, 1.9), q2 + Vector3(0, m.altura((raiz.transform * q2).x, (raiz.transform * q2).z) - c.y + 0.08, 0), _m("colchao", Color(0.7, 0.65, 0.55)))
		cm.rotation.y = r.randf() * TAU
	_tambor_fogo(raiz, Vector3(0, m.altura(c.x, c.z) - c.y, 0), r, r.randf() < 0.6)
	var pl := Label3D.new()
	pl.text = "CAMPO DE TRIAGEM 7\nDEFESA CIVIL"
	pl.font_size = 80
	pl.pixel_size = 0.006
	pl.modulate = Color(0.1, 0.1, 0.12)
	pl.position = Vector3(0, 2.0, 11.0)
	pl.double_sided = false
	raiz.add_child(pl)
	B.box(raiz, Vector3(2.6, 1.0, 0.05), Vector3(0, 2.0, 10.97), B.mat(Color(0.95, 0.92, 0.85), 0.8))
	for sx in [-1.2, 1.2]:
		B.box(raiz, Vector3(0.08, 2.5, 0.08), Vector3(sx, 1.25, 10.95), _m("metal", Color(0.5, 0.5, 0.5), 0.5, 0.6))
	# alguns que não saíram mais de lá
	for i in r.randi_range(1, 3):
		var zq := Vector3(r.randf_range(-8, 8), 0, r.randf_range(-6, 6))
		m.criar_zumbi(n, raiz.transform * zq, r.randf() * TAU, r.randi())

static func _poste_caido(n: Node3D, p: Vector3, rot: float, lado: float, r: RandomNumberGenerator) -> void:
	var madeira := B.mat(Color(0.32, 0.25, 0.18), 0.9, 0.0, "poste_madeira")
	var pc := Node3D.new()
	pc.position = p
	pc.rotation = Vector3(0, rot, -lado * r.randf_range(1.15, 1.45))
	n.add_child(pc)
	B.cyl(pc, 0.13, 8.5, Vector3(0, 4.25, 0), madeira, Vector3.ZERO, 8)
	B.box(pc, Vector3(1.8, 0.12, 0.12), Vector3(0, 7.8, 0), madeira)
	B.cyl(n, 0.16, 0.6, p + Vector3(0, 0.3, 0), madeira, Vector3.ZERO, 8)   # toco

static func _helicoptero(n: Node3D, p: Vector3, r: RandomNumberGenerator) -> void:
	var h := Node3D.new()
	h.position = p
	h.rotation = Vector3(0.12, r.randf() * TAU, 0.45)
	h.set_meta("nao_mesclar", true)
	n.add_child(h)
	var verde := _m("metal", Color(0.24, 0.27, 0.2), 0.7, 0.4)
	var preto := _m("metal", Color(0.08, 0.08, 0.08), 0.6, 0.5)
	B.capsule(h, 1.1, 5.0, Vector3(0, 1.3, 0), verde, Vector3(90, 0, 0))
	B.box(h, Vector3(0.4, 0.5, 5.0), Vector3(0, 1.6, -4.5), verde)
	B.box(h, Vector3(0.12, 1.4, 0.8), Vector3(0, 2.2, -6.9), verde)
	B.box(h, Vector3(1.6, 0.6, 1.3), Vector3(0, 1.6, 1.8), B.mat(Color(0.05, 0.06, 0.07), 0.2, 0.3))
	for q in 4:
		var pa := B.box(h, Vector3(0.3, 0.05, 5.0), Vector3(0, 2.55, 0), preto)
		pa.rotation = Vector3(r.randf_range(-0.2, 0.3), q * PI * 0.5 + 0.3, 0)
	for sx in [-0.9, 0.9]:
		B.box(h, Vector3(0.08, 0.08, 3.2), Vector3(sx, 0.15, 0.2), preto)
	B.box(h, Vector3(0.6, 0.6, 0.05), Vector3(1.12, 1.6, -0.5), B.mat(Color(0.9, 0.9, 0.85), 0.7))
	var fumo := fumaca(2.5, 22.0)
	fumo.position = Vector3(0, 2.0, 0.5)
	h.add_child(fumo)

static func _veiculo_oficial(n: Node3D, p: Vector3, rot: float, r: RandomNumberGenerator) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation = Vector3(0, rot, 0)
	n.add_child(v)
	var tipo := r.randi() % 3
	var cor: Color = [Color(0.88, 0.88, 0.85), Color(0.15, 0.17, 0.2), Color(0.85, 0.65, 0.1)][tipo]
	var lat := B.pintura(cor, r.randf_range(0.25, 0.55), 0.6, 0.2)
	var comp := 5.0 if tipo < 2 else 9.0
	B.box(v, Vector3(2.0, 2.2 if tipo != 1 else 1.4, comp), Vector3(0, 1.4 if tipo != 1 else 1.0, 0), lat)
	B.box(v, Vector3(2.02, 0.6, comp * 0.8), Vector3(0, 1.9 if tipo != 1 else 1.3, -0.2), B.mat(Color(0.05, 0.06, 0.07), 0.2, 0.3, "vidro_veic"))
	for sx in [-0.95, 0.95]:
		for sz in [-comp * 0.35, comp * 0.35]:
			B.cyl(v, 0.42, 0.28, Vector3(sx, 0.42, sz), B.mat(Color(0.06, 0.06, 0.06), 0.9, 0.0, "pneu_v"), Vector3(0, 0, 90), 12)
	match tipo:
		0:   # ambulância
			B.box(v, Vector3(2.04, 0.3, comp * 0.6), Vector3(0, 1.2, -0.6), B.mat(Color(0.85, 0.12, 0.1), 0.6, 0.0, "faixa_amb"))
			B.box(v, Vector3(0.9, 0.12, 0.3), Vector3(0, 2.6, comp * 0.3), B.emissive(Color(0.9, 0.15, 0.1), 0.6))
		1:   # viatura
			B.box(v, Vector3(1.0, 0.14, 0.3), Vector3(0, 1.8, 0), B.mat(Color(0.2, 0.3, 0.8), 0.4))
			B.box(v, Vector3(2.04, 0.25, comp * 0.5), Vector3(0, 0.9, 0), B.mat(Color(0.9, 0.9, 0.88), 0.6, 0.0, "faixa_pol"))
		2:   # ônibus escolar
			var l := Label3D.new()
			l.text = "ESCOLAR"
			l.font_size = 90
			l.pixel_size = 0.008
			l.modulate = Color(0.08, 0.07, 0.06)
			l.position = Vector3(1.03, 2.2, 0)
			l.rotation.y = PI * 0.5
			l.double_sided = false
			v.add_child(l)
	# porta aberta, sangue na lataria
	B.box(v, Vector3(0.05, 1.4, 1.0), Vector3(1.4, 1.2, comp * 0.25), lat, Vector3(0, 60, 0))
	B.box(v, Vector3(0.02, 0.6, 0.8), Vector3(1.01, 1.0, -comp * 0.1), B.mat(Color(0.3, 0.05, 0.04), 0.7, 0.0, "sangue_lat"))

## Mato rompendo o asfalto nas rachaduras e no meio da pista (MultiMesh barato).
static func _mato_no_asfalto(n: Node3D, m: WorldGen, z0: float, r: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Floresta.malha("capim_alto")
	var lista: Array = []
	var hw := WorldGen.LARG_ESTRADA * 0.5
	for i in r.randi_range(14, 30):
		var z := z0 + r.randf() * WorldGen.TAM
		var lat := r.randf_range(-hw, hw) if r.randf() < 0.4 else (hw - 0.2) * (1.0 if r.randf() < 0.5 else -1.0) + r.randf_range(-0.3, 0.3)
		var p := m.ponto_estrada(z, lat)
		p.y = m.elevacao(z) + 0.04
		var e := r.randf_range(0.25, 0.6)
		lista.append([Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * e), p), Color(1, 1, 1) * r.randf_range(0.7, 1.1)])
	mm.instance_count = lista.size()
	for i in lista.size():
		mm.set_instance_transform(i, lista[i][0])
		mm.set_instance_color(i, lista[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("nao_mesclar", true)
	mi.visibility_range_end = 90.0
	n.add_child(mi)
