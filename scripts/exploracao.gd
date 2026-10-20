class_name Exploracao
extends Node
## Exploração: lugares grandes e raros (base militar, presídio, shopping) com o melhor
## saque trancado (chave achada em outro lugar, ou arrombar com pé de cabra fazendo barulho),
## porões e bunkers escuros (Subsolo), binóculo [Z] e pichações de sobreviventes que
## apontam esconderijos de verdade.

const GRANDES := {
	"base_militar": {"regiao": 1, "raio": 50.0},
	"presidio": {"regiao": 2, "raio": 48.0},
	"shopping": {"regiao": 1, "raio": 50.0},
}
const TRANCAS := {
	"cartao_militar": "cartão de acesso militar",
	"chaves_presidio": "molho de chaves do presídio",
	"chave_cofre": "chave do cofre do shopping",
}
const PICHACOES := [
	["COMIDA ENTERRADA\n← 30 PASSOS", true], ["ÁGUA NO POÇO →", true], ["SE PRECISAR, PEGA\n← ATRÁS DA PEDRA", true],
	["FAMÍLIA SOUZA\nFOI P/ ZONA SEGURA", false], ["NÃO ENTRE NO TÚNEL", false], ["ELES OUVEM O MOTOR", false],
	["NINHO NA MATA\nNÃO VÁ", false], ["JOÃO TE AMO\nTE ESPERO NO KM 40", false], ["MORDIDO = TIRO\nSEM EXCEÇÃO", false],
	["O GOVERNO MENTIU", false], ["DEUS VÊ TUDO", false], ["REMÉDIO ESCONDIDO\n→ NA CAIXA AZUL", true],
]

var main: Node
var _zoom := false
var _fov_normal := 70.0
var marcados := {}            # Zumbi -> segundos restantes no mapa
var _ambiente_salvo := {}

# ------------------------------------------------------------ a cada quadro
func atualizar(dt: float) -> void:
	for z in marcados.keys():
		marcados[z] -= dt
		if marcados[z] <= 0.0 or not is_instance_valid(z) or not z.vivo():
			marcados.erase(z)
	var pode: bool = main.estoque.get("binoculo", 0) > 0 and not main.comboio.dirigindo and main.dentro == null
	if Input.is_action_just_pressed("binoculo"):
		if not pode:
			if main.estoque.get("binoculo", 0) <= 0:
				main.hud.aviso("Você não tem binóculo.")
		else:
			_alternar_zoom()
	if _zoom and (not pode or Input.is_action_just_pressed("atacar")):
		_alternar_zoom()
	if _zoom:
		_observar()

func _alternar_zoom() -> void:
	var cam: Camera3D = main.jogador.camera
	_zoom = not _zoom
	main.jogador.binoculo = _zoom
	if _zoom:
		cam.fov = 14.0
		Som.tela("troca_arma", -10.0)
	else:
		cam.fov = 55.0
	main.hud.binoculo = _zoom

## Com o binóculo: marca no mapa todo zumbi à vista (até 350 m) por um minuto.
func _observar() -> void:
	var cam: Camera3D = main.jogador.camera
	var n := 0
	var esp := 0
	for z in main.mundo.zumbis_vivos:
		if not is_instance_valid(z) or not z.vivo():
			continue
		var p: Vector3 = z.global_position + Vector3(0, 1.2, 0)
		if cam.is_position_behind(p) or p.distance_to(cam.global_position) > 350.0:
			continue
		var sp := cam.unproject_position(p)
		var vr: Rect2 = main.get_viewport().get_visible_rect()
		if vr.grow(-vr.size.x * 0.15).has_point(sp):
			marcados[z] = 60.0
			n += 1
			if z.tipo != "comum":
				esp += 1
	main.hud.binoculo_txt = "%d zumbi%s à vista%s" % [n, "" if n == 1 else "s", (" (%d especial%s)" % [esp, "" if esp == 1 else "is"]) if esp > 0 else ""] if n > 0 else "Nada se mexe."

func posicoes_marcadas() -> Array[Vector3]:
	var l: Array[Vector3] = []
	for z in marcados:
		if is_instance_valid(z):
			l.append(z.global_position)
	return l

# ------------------------------------------------------------ trancas
static func trancar(v: Node3D, item: String) -> void:
	v.set_meta("tranca", item)

func trancado(v: Node3D) -> bool:
	return v.has_meta("tranca") and not main.mundo.vasculhados.has(String(v.get_meta("chave")) + ":aberto")

func painel_tranca(v: Node3D) -> Dictionary:
	var item: String = v.get_meta("tranca")
	var tem: bool = main.estoque.get(item, 0) > 0
	var pe: bool = main.estoque.get("pe_de_cabra", 0) > 0
	return {"titulo": String(v.get_meta("nome")).to_upper(), "subtitulo": "Porta de aço, cadeado grosso. O melhor saque do lugar está aqui dentro.",
		"linhas": ["Abre com: %s%s." % [TRANCAS[item], " (você tem)" if tem else ""],
			["Sem a chave, dá para arrombar com um pé de cabra: leva 2 h e faz um barulho que se ouve de longe.", Color(0.95, 0.6, 0.35)]],
		"botoes": [
			["Usar %s" % TRANCAS[item], func(): return _abrir(v, false), tem],
			["Arrombar (pé de cabra, %s, barulho)" % main._txt_horas(2.0), func(): return _abrir(v, true), pe],
		]}

func _abrir(v: Node3D, arrombar: bool) -> String:
	main.mundo.vasculhados[String(v.get_meta("chave")) + ":aberto"] = true
	main.call_deferred("_fechar_janela")
	if arrombar:
		main.trabalhar(2.0, "Arrombando com o pé de cabra")
		main.ruido(v.global_position, 110.0, "tiro")
		Som.em("impacto_metal", v.global_position, 4.0, 0.1, 3.0)
		# o barulho chama quem estava por perto
		var r := RandomNumberGenerator.new()
		r.randomize()
		for i in r.randi_range(4, 8):
			var a := r.randf() * TAU
			var p: Vector3 = v.global_position + Vector3(cos(a), 0, sin(a)) * r.randf_range(25.0, 40.0)
			p.y = main.mundo.altura(p.x, p.z) + 0.05
			var z: Zumbi = main.mundo.criar_zumbi(main.mundo, p, a + PI, r.randi())
			z.estado = Zumbi.Estado.PERSEGUINDO
			z.alvo_pos = v.global_position
		main.hud.aviso("O cadeado cedeu, mas o barulho ecoou longe. Eles estão vindo.")
	else:
		main.hud.aviso("A porta abriu com um clique.")
	main.call_deferred("_vasculhar", v)
	return ""

# ------------------------------------------------------------ subsolo (escuro)
func entrar_subsolo() -> void:
	var amb: Environment = main.ambiente
	_ambiente_salvo = {"energia": amb.ambient_light_energy, "sol": main.sol.visible, "ceu": amb.ambient_light_sky_contribution, "nevoa": amb.fog_enabled}
	amb.ambient_light_energy = 0.02
	amb.ambient_light_sky_contribution = 0.0
	amb.fog_enabled = false
	main.sol.visible = false
	var fp: Node3D = main.fp
	var lan: Variant = fp.camera.get_node_or_null("Lanterna")
	if lan == null:
		var sp := SpotLight3D.new()
		sp.name = "Lanterna"
		sp.light_energy = 3.0
		sp.spot_range = 14.0
		sp.spot_angle = 26.0
		sp.light_color = Color(1.0, 0.95, 0.85)
		sp.shadow_enabled = true
		fp.camera.add_child(sp)
		lan = sp
	lan.visible = main.estoque.get("lanterna", 0) > 0
	if not lan.visible:
		main.hud.aviso("Está escuro demais. Sem lanterna, você vai tatear.")

func sair_subsolo() -> void:
	if _ambiente_salvo.is_empty():
		return
	var amb: Environment = main.ambiente
	amb.ambient_light_energy = _ambiente_salvo.energia
	amb.ambient_light_sky_contribution = _ambiente_salvo.ceu
	amb.fog_enabled = _ambiente_salvo.nevoa
	main.sol.visible = _ambiente_salvo.sol
	var lan: Node3D = main.fp.camera.get_node_or_null("Lanterna")
	if lan:
		lan.visible = false
	_ambiente_salvo = {}

## Ação lá embaixo: vasculhar um item ou enfrentar o vulto.
func acao_subsolo(s: Subsolo, id: String) -> void:
	var tem_luz: bool = main.estoque.get("lanterna", 0) > 0
	if id == "sub:vulto":
		if tem_luz:
			main.jogador.estamina = maxf(0.0, main.jogador.estamina - 0.3)
			s.matar_vulto()
			Som.tela("impacto_carne", -2.0)
			main.hud.aviso("A lanterna mostrou o que era. Você acabou com ele antes que levantasse.")
		else:
			_mordida("Você tateou no escuro e algo agarrou seu braço.")
			s.matar_vulto()
		main.fp.interativos = s.interior().interativos
		return
	var i := int(id.substr(4))
	if i < 0 or i >= s.itens.size():
		return
	if s.ocupado and randf() < (0.12 if tem_luz else 0.45):
		if tem_luz:
			main.hud.aviso("Um zumbi saiu de trás das caixas! Na luz da lanterna, você foi mais rápido.")
			s.matar_vulto()
		else:
			_mordida("No escuro, uma mão gelada fechou no seu tornozelo.")
			s.matar_vulto()
	main._vasculhar(s.itens[i])
	main.fp.interativos = s.interior().interativos

func _mordida(txt: String) -> void:
	var j: Player = main.jogador
	j.vida = maxf(0.05, j.vida - 0.18)
	j.infeccao = minf(1.0, j.infeccao + 0.12)
	Som.tela("zumbi_ataque", 0.0)
	Som.tela("dor", -2.0)
	main.hud.aviso(txt + " (−18% de vida, risco de infecção)")

# ------------------------------------------------------------ lugares grandes
static func _muralha(p: Node3D, raio: float, altura: float, mat: Material, abertura: float) -> void:
	var n := int(TAU * raio / 4.0)
	for i in n:
		var a := TAU * (i + 0.5) / n
		if absf(wrapf(a, -PI, PI)) < abertura:
			continue
		var pos := Vector3(sin(a), 0, cos(a)) * raio
		var seg := B.box(p, Vector3(4.15, altura, 0.4), pos + Vector3(0, altura * 0.5, 0), mat)
		seg.rotation.y = a

static func _zumbis_lugar(p: Node3D, m: WorldGen, r: RandomNumberGenerator, n: int, raio: float, cor_roupa: Color, tipos: Array) -> void:
	for i in n:
		var a := r.randf() * TAU
		var q := Vector3(cos(a), 0, sin(a)) * r.randf_range(6.0, raio - 6.0)
		q.y = Lugares._altura_local(p, m, q) + 0.05
		var z := m.criar_zumbi(p, q, r.randf() * TAU, r.randi(), tipos[r.randi() % tipos.size()])
		z.cores = {"roupa": cor_roupa}

static func base_militar(p: Node3D, f: Dictionary, r: RandomNumberGenerator, m: WorldGen) -> void:
	var raio: float = f.raio
	var j: Dictionary = f.juncao
	var verde := B.mat(Color(0.3, 0.33, 0.24), 0.8, 0.2)
	var conc := Texturas.material("concreto", Color(0.55, 0.55, 0.52))
	Lugares._muro(p, raio, 0.18, r, m, true)
	Lugares._placa(p, Vector3(0, 3.0, raio + 0.6), 0.0, j.nome.to_upper() + "\nÁREA MILITAR", Color(0.95, 0.85, 0.3))
	# guarita e cancela
	B.box(p, Vector3(2.2, 2.6, 2.2), Vector3(5.0, 1.3, raio - 2.5), conc)
	B.box(p, Vector3(5.0, 0.12, 0.12), Vector3(1.0, 1.1, raio - 0.5), B.mat(Color(0.85, 0.2, 0.1), 0.6), Vector3(0, 0, 32))
	# sede administrativa (dá para entrar) e hangar
	var sede := m.criar_predio(p.get_parent(), p.transform * Vector3(-16, 0, 6), p.rotation.y + PI * 0.5, "sede", 13.0, 10.0, 2, r.randi(), j.id + ":sede")
	sede.set_meta("tabela_loja", "militar")
	var hg := Node3D.new()
	hg.position = Vector3(14, 0, -10)
	p.add_child(hg)
	B.box(hg, Vector3(16, 0.3, 20), Vector3(0, 0.15, 0), conc)
	var arco := PackedVector2Array()
	for k in 13:
		var ang := PI * k / 12.0
		arco.append(Vector2(cos(ang) * 8.0, sin(ang) * 7.0))
	B.extruded(hg, arco, 20.0, Vector3.ZERO, verde)
	B.box(hg, Vector3(12, 6, 0.1), Vector3(0, 3.0, 10.05), B.mat(Color(0.05, 0.05, 0.05), 1.0))
	# caminhões e jipe abandonados dentro do hangar
	for i in 2:
		var cam := Node3D.new()
		cam.position = Vector3(-3.5 + i * 7.0, 0.3, 1.0)
		hg.add_child(cam)
		B.box(cam, Vector3(2.4, 1.6, 2.2), Vector3(0, 1.5, 3.0), verde)
		B.box(cam, Vector3(2.5, 2.0, 5.6), Vector3(0, 2.1, -1.0), B.mat(Color(0.32, 0.34, 0.24), 0.95))
		for zz in [2.8, -0.5, -2.8]:
			for s in [-1.0, 1.0]:
				var w := B.wheel(cam, Vector3(s * 1.15, 0.55, zz), 0.55, 0.35)
				w.rotation_degrees.y = 90
	Lugares._vasculhavel(hg, Vector3(0, 1.0, -7.0), "Caixas de suprimento", "militar", 1.0, m, j.id + ":hangar")
	# arsenal trancado (cartão)
	var ars := Node3D.new()
	ars.position = Vector3(-14, 0, -18)
	p.add_child(ars)
	B.box(ars, Vector3(6, 3.2, 5), Vector3(0, 1.6, 0), conc)
	B.box(ars, Vector3(1.6, 2.3, 0.08), Vector3(0, 1.15, 2.52), B.mat(Color(0.35, 0.38, 0.35), 0.45, 0.8))
	Lugares._placa(ars, Vector3(0, 2.75, 2.56), 0.0, "PAIOL", Color(0.95, 0.85, 0.3))
	Lugares._vasculhavel(ars, Vector3(0, 1.0, 3.2), "Paiol (arsenal)", "arsenal", 1.5, m, j.id + ":paiol")
	trancar(ars.get_child(ars.get_child_count() - 1), "cartao_militar")
	# torres de vigia nos cantos
	for a in [0.7, -0.7, PI - 0.6, PI + 0.6]:
		VilaExtra.torre(p, Vector3(sin(a), 0, cos(a)) * (raio - 4.0), a + PI, m)
	# sacos de areia e bunker
	var saco := B.mat(Color(0.6, 0.55, 0.4), 0.95, 0.0, "saco_areia")
	for i in 8:
		B.box(p, Vector3(0.9, 0.38, 0.5), Vector3(-4.0 + i * 1.0, 0.2, 10.0), saco)
	var bk := Subsolo.new()
	bk.tipo = "bunker"
	bk.chave = j.id + ":bunker"
	bk.mundo = m
	bk.position = Vector3(2.0, Lugares._altura_local(p, m, Vector3(2, 0, -24)), -24.0)
	bk.set_meta("nao_mesclar", true)
	p.add_child(bk)
	m.subsolos.append(bk)
	_zumbis_lugar(p, m, r, r.randi_range(9, 14), raio, Color(0.5, 0.57, 0.38), ["comum", "comum", "blindado", "brutamonte"])

static func presidio(p: Node3D, f: Dictionary, r: RandomNumberGenerator, m: WorldGen) -> void:
	var raio: float = f.raio
	var j: Dictionary = f.juncao
	var conc := Texturas.material("concreto", Color(0.58, 0.57, 0.53))
	var arame := B.mat(Color(0.35, 0.35, 0.35), 0.5, 0.8)
	_muralha(p, raio, 5.5, conc, 0.1)
	for i in int(TAU * raio / 2.0):
		var a := TAU * i / int(TAU * raio / 2.0)
		if absf(wrapf(a, -PI, PI)) < 0.1:
			continue
		B.cyl(p, 0.35, 1.9, Vector3(sin(a), 0, cos(a)) * raio + Vector3(0, 5.8, 0), arame, Vector3(0, rad_to_deg(a), 90), 8)
	Lugares._placa(p, Vector3(0, 6.2, raio + 0.6), 0.0, j.nome.to_upper(), Color(0.9, 0.88, 0.8))
	# portão de grade aberto
	for s in [-1.0, 1.0]:
		var pt := B.box(p, Vector3(4.0, 4.5, 0.15), Vector3(s * 4.5, 2.25, raio + 1.5), B.mat(Color(0.25, 0.25, 0.25), 0.5, 0.8))
		pt.rotation.y = s * 1.1
	# blocos de celas (dá para entrar) e pátio
	for i in 2:
		var bl := m.criar_predio(p.get_parent(), p.transform * Vector3(-13 + i * 26, 0, -10), p.rotation.y, "apto", 10.0, 16.0, 2, r.randi(), j.id + ":bloco%d" % i)
		bl.set_meta("tabela_loja", "presidio")
	B.box(p, Vector3(14, 0.06, 12), Vector3(0, 0.04, 8), B.mat(Color(0.5, 0.5, 0.48), 0.9, 0.0, "patio"))
	for s in [-1.0, 1.0]:
		B.cyl(p, 0.06, 3.0, Vector3(s * 5.5, 1.5, 8), arame, Vector3.ZERO, 6)
		B.box(p, Vector3(1.2, 0.9, 0.05), Vector3(s * 5.5, 3.0, 8), B.mat(Color(0.85, 0.85, 0.82), 0.6))
	# almoxarifado e armaria trancados (chaves)
	var alm := Node3D.new()
	alm.position = Vector3(0, 0, -26)
	p.add_child(alm)
	B.box(alm, Vector3(10, 3.4, 6), Vector3(0, 1.7, 0), conc)
	B.box(alm, Vector3(1.6, 2.3, 0.08), Vector3(-2.5, 1.15, 3.02), B.mat(Color(0.3, 0.32, 0.35), 0.45, 0.8))
	B.box(alm, Vector3(1.6, 2.3, 0.08), Vector3(2.5, 1.15, 3.02), B.mat(Color(0.3, 0.32, 0.35), 0.45, 0.8))
	Lugares._vasculhavel(alm, Vector3(-2.5, 1.0, 3.6), "Almoxarifado", "almoxarifado", 1.0, m, j.id + ":almox")
	trancar(alm.get_child(alm.get_child_count() - 1), "chaves_presidio")
	Lugares._vasculhavel(alm, Vector3(2.5, 1.0, 3.6), "Armaria dos agentes", "armaria", 1.0, m, j.id + ":armaria")
	trancar(alm.get_child(alm.get_child_count() - 1), "chaves_presidio")
	# guaritas na muralha
	for a in [PI * 0.25, -PI * 0.25, PI * 0.75, -PI * 0.75]:
		var g := Node3D.new()
		g.position = Vector3(sin(a), 0, cos(a)) * raio
		g.rotation.y = a
		p.add_child(g)
		B.box(g, Vector3(3.0, 8.5, 3.0), Vector3(0, 4.25, 0), conc)
		B.box(g, Vector3(3.6, 0.3, 3.6), Vector3(0, 8.6, 0), conc)
		B.box(g, Vector3(2.6, 0.9, 0.05), Vector3(0, 7.6, 1.52), B.mat(Color(0.1, 0.12, 0.14), 0.2, 0.3))
	_zumbis_lugar(p, m, r, r.randi_range(12, 18), raio, Color(0.85, 0.42, 0.12), ["comum", "comum", "corredor", "brutamonte"])

static func shopping(p: Node3D, f: Dictionary, r: RandomNumberGenerator, m: WorldGen) -> void:
	var raio: float = f.raio
	var j: Dictionary = f.juncao
	var asf := B.mat(Color(0.18, 0.18, 0.19), 0.9, 0.0, "estacionamento")
	var faixa := B.mat(Color(0.85, 0.85, 0.8), 0.7, 0.0, "faixa_vaga")
	B.box(p, Vector3(56.0, 0.05, 30.0), Vector3(0, 0.03, 16.0), asf)
	for fila in [9.0, 23.0]:
		for i in 13:
			B.box(p, Vector3(0.12, 0.06, 4.5), Vector3(-24 + i * 4.0, 0.05, fila), faixa)
	# postes de luz do estacionamento
	var poste := B.mat(Color(0.35, 0.36, 0.38), 0.5, 0.7)
	for x in [-20.0, 0.0, 20.0]:
		B.cyl(p, 0.12, 7.0, Vector3(x, 3.5, 16.0), poste, Vector3.ZERO, 8)
		B.box(p, Vector3(1.4, 0.15, 0.4), Vector3(x, 7.0, 16.0), poste)
	# carros largados
	for i in 10:
		var rc := RandomNumberGenerator.new()
		rc.seed = r.randi()
		var q := Vector3(-22 + r.randi_range(0, 11) * 4.0, 0.02, [9.0, 23.0][r.randi() % 2])
		m.carro_abandonado(p, q, PI * 0.5 * (1 if r.randf() < 0.5 else -1) + r.randf_range(-0.2, 0.2), rc, "%s:carro%d" % [j.id, i])
	# o prédio (dá para entrar): salão grande, 2 andares
	var sh := m.criar_predio(p.get_parent(), p.transform * Vector3(0, 0, -12), p.rotation.y, "loja", 26.0, 18.0, 2, r.randi(), j.id + ":shopping")
	sh.set_meta("tabela_loja", "loja")
	# fachada: faixa colorida, marquise de vidro, letreiro grande e dois anexos
	var faixa_cor := B.mat(Color(0.12, 0.3, 0.55), 0.5, 0.2)
	var laranja := B.mat(Color(0.9, 0.45, 0.12), 0.5, 0.1)
	var vidro := B.mat(Color(0.25, 0.35, 0.4), 0.1, 0.5)
	var zf := -12.0 + 9.15
	B.box(p, Vector3(26.4, 1.4, 0.3), Vector3(0, 6.7, zf), faixa_cor)
	B.box(p, Vector3(26.4, 0.25, 0.32), Vector3(0, 5.9, zf + 0.02), laranja)
	B.box(p, Vector3(10.0, 0.2, 3.0), Vector3(0, 3.4, zf + 1.5), vidro)
	for s in [-1.0, 1.0]:
		B.cyl(p, 0.1, 3.4, Vector3(s * 4.8, 1.7, zf + 2.9), poste, Vector3.ZERO, 8)
	var letreiro := Label3D.new()
	letreiro.text = String(j.nome).to_upper()
	letreiro.font_size = 160
	letreiro.pixel_size = 0.012
	letreiro.outline_size = 12
	letreiro.modulate = Color(0.98, 0.95, 0.85)
	letreiro.outline_modulate = Color(0.05, 0.1, 0.2)
	letreiro.shaded = true
	letreiro.position = Vector3(0, 6.7, zf + 0.18)
	p.add_child(letreiro)
	for s in [-1.0, 1.0]:
		var an := Node3D.new()
		an.position = Vector3(s * 19.0, 0, -9.0)
		p.add_child(an)
		B.box(an, Vector3(10.0, 5.0, 12.0), Vector3(0, 2.5, 0), Texturas.material("concreto", Color(0.7, 0.68, 0.62)))
		B.box(an, Vector3(10.2, 1.0, 0.2), Vector3(0, 4.3, 6.05), laranja if s < 0 else faixa_cor)
		B.box(an, Vector3(6.0, 2.6, 0.1), Vector3(0, 1.3, 6.05), B.mat(Color(0.06, 0.06, 0.07), 0.9))
		for k in 5:
			B.box(an, Vector3(0.08, 2.6, 0.12), Vector3(-2.8 + k * 1.4, 1.3, 6.1), poste)   # porta de enrolar meio aberta
	Lugares._placa(p, Vector3(-19.0, 4.3, -2.82), 0.0, "FARMÁCIA", Color(0.95, 0.95, 0.9))
	Lugares._placa(p, Vector3(19.0, 4.3, -2.82), 0.0, "CAÇA E PESCA", Color(0.95, 0.95, 0.9))
	var lojas := [["Farmácia do shopping", "farmacia", Vector3(-19, 0, -2.0)], ["Caça e Pesca", "cacador", Vector3(19, 0, -2.0)], ["Supermercado", "loja", Vector3(0, 0, -1.0)]]
	for l in lojas:
		Lugares._vasculhavel(p, l[2] + Vector3(0, 1.0, 0), l[0], l[1], 1.0, m, "%s:%s" % [j.id, l[1]])
	# cofre da administração (chave), nos fundos
	var aco := B.mat(Color(0.4, 0.42, 0.44), 0.4, 0.8)
	B.box(p, Vector3(1.4, 1.6, 1.0), Vector3(-6, 0.8, -22.6), aco)
	B.cyl(p, 0.18, 0.08, Vector3(-6, 0.9, -22.05), B.mat(Color(0.7, 0.6, 0.2), 0.3, 0.9), Vector3(90, 0, 0), 12)
	Lugares._vasculhavel(p, Vector3(-6, 1.0, -21.4), "Cofre da administração", "cofre", 1.0, m, j.id + ":cofre")
	trancar(p.get_child(p.get_child_count() - 1), "chave_cofre")
	# dinheiro: não vale nada no apocalipse, mas está lá
	Props.por(p, "saco_dinheiro", Vector3(-4.9, 0, -22.3), 30.0)
	Props.por(p, "dinheiro", Vector3(-5.4, 0.02, -21.6), 0.0, 1.2)
	# barricada de carrinhos na entrada
	var car := B.mat(Color(0.6, 0.6, 0.62), 0.4, 0.8)
	for i in 9:
		B.box(p, Vector3(0.6, 0.9, 0.9), Vector3(-4.5 + i * 1.1, 0.45, zf + 3.6 + r.randf_range(-0.4, 0.4)), car, Vector3(0, r.randf_range(-30, 30), 0))
	_zumbis_lugar(p, m, r, r.randi_range(14, 20), raio, Color(0.45, 0.4, 0.55), ["comum", "comum", "corredor", "gritador"])

# ------------------------------------------------------------ pichações e esconderijos
static func pichacao(n: Node3D, m: WorldGen, z0: float, k: int, r: RandomNumberGenerator) -> void:
	var lado := 1.0 if r.randf() < 0.5 else -1.0
	var z := z0 + r.randf_range(10.0, WorldGen.TAM - 10.0)
	var pc := m.ponto_estrada(z, lado * (WorldGen.LARG_ESTRADA * 0.5 + 2.4))
	pc.y = m.altura(pc.x, pc.z)
	var d := m.direcao(z)
	var msg: Array = PICHACOES[r.randi() % PICHACOES.size()]
	var t := Node3D.new()
	t.position = pc
	t.rotation.y = atan2(d.x, d.z) + (PI * 0.5 if lado < 0 else -PI * 0.5)
	n.add_child(t)
	var mad := B.mat(Color(0.42, 0.32, 0.2), 0.95, 0.0, "tabua_picho")
	for s in [-1.0, 1.0]:
		B.box(t, Vector3(0.08, 1.4, 0.08), Vector3(s * 0.8, 0.7, 0), B.mat(Color(0.3, 0.22, 0.14), 0.95))
	for i in 3:
		B.box(t, Vector3(1.9, 0.32, 0.04), Vector3(0, 0.95 + i * 0.33, 0.04), mad, Vector3(0, 0, r.randf_range(-3, 3)))
	var l := Label3D.new()
	l.text = msg[0]
	l.font_size = 72
	l.pixel_size = 0.0034
	l.modulate = [Color(0.85, 0.12, 0.08), Color(0.08, 0.08, 0.08), Color(0.95, 0.95, 0.9)][r.randi() % 3]
	l.outline_size = 0
	l.shaded = true
	l.position = Vector3(0, 1.28, 0.08)
	t.add_child(l)
	if not msg[1]:
		return
	# esconderijo de verdade, mato adentro
	var pe := m.ponto_estrada(z + r.randf_range(-8, 8), lado * (WorldGen.LARG_ESTRADA * 0.5 + r.randf_range(18.0, 28.0)))
	pe.y = m.altura(pe.x, pe.z)
	var e := Node3D.new()
	e.position = pe
	e.set_meta("area_livre", Vector2(1.5, 1.5))
	n.add_child(e)
	var pedra := B.mat(Color(0.48, 0.47, 0.44), 0.95, 0.0, "pedra_esconde")
	for i in 6:
		B.sphere(e, r.randf_range(0.2, 0.35), Vector3(r.randf_range(-0.5, 0.5), 0.15, r.randf_range(-0.5, 0.5)), pedra, Vector3(1.2, 0.7, 1.0), 6)
	B.box(e, Vector3(0.6, 0.4, 0.45), Vector3(0, 0.22, 0), B.mat(Color(0.15, 0.3, 0.6), 0.6))
	Lugares._vasculhavel(e, Vector3(0, 0.9, 0), "Esconderijo de sobrevivente", "esconderijo", 0.25, m, "esconderijo:%d" % k)
