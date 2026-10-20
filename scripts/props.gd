class_name Props
## Objetos com modelo (Sketchfab, enviados pelo Davi): móveis, cozinha, comida, jornais,
## cinzeiros, dinheiro, carros, plantas da estufa e mobiliário urbano.
##
## Cada entrada aponta para um .glb e, nos pacotes com vários objetos, para o nome do nó
## (os nós irmãos que começam com o mesmo nome e ficam dentro dele — gavetas, tampas —
## vêm junto). O objeto é recentralizado (base no chão, centro em x/z), girado para que a
## frente fique em +Z e redimensionado para o tamanho real.
##
##   arquivo, no ("" = arquivo inteiro), tam (metros), eixo ("h" altura, "c" comprimento,
##   "m" maior lado), giro (graus em Y para a frente ficar em +Z), deitar/tombar (graus em X/Z, para
##   modelos que vieram em pé, como jornal e frigideira pendurada), sem (nós a ignorar)

const C := {
	# ---- cozinha (Kitchen - Assets, SeverDoes3D)
	"pia": {"arquivo": "res://assets/objetos/cozinha.glb", "no": "Sink_001_47", "tam": 0.9, "eixo": "h", "giro": 90.0},
	"fogareiro": {"arquivo": "res://assets/objetos/cozinha.glb", "no": "PortableStove_Base_001_42", "tam": 0.56, "eixo": "m", "giro": 90.0},
	"botijao": {"arquivo": "res://assets/objetos/cozinha.glb", "no": "GasCylinder_001_34", "tam": 0.6, "eixo": "h"},
	"panela": {"arquivo": "res://assets/objetos/cozinha.glb", "no": "Kitchenware_Stewpot_001_11", "tam": 0.3, "eixo": "m"},
	"panela2": {"arquivo": "res://assets/objetos/cozinha.glb", "no": "Kitchenware_Pot_001_8", "tam": 0.37, "eixo": "m", "tombar": -90.0},
	"frigideira": {"arquivo": "res://assets/objetos/cozinha.glb", "no": "Kitchenware_Pan_IronCast_001_9", "tam": 0.46, "eixo": "m", "tombar": -90.0},
	"prato": {"arquivo": "res://assets/objetos/cozinha.glb", "no": "Plate_Regular_001_12", "tam": 0.22, "eixo": "m"},
	"lata": {"arquivo": "res://assets/objetos/cozinha.glb", "no": "CannedFood_Tall_001_14", "tam": 0.11, "eixo": "h"},
	"lata_baixa": {"arquivo": "res://assets/objetos/cozinha.glb", "no": "CannedFood_Flat_001_13", "tam": 0.1, "eixo": "m"},
	"pote": {"arquivo": "res://assets/objetos/cozinha.glb", "no": "GlassJar_001_21", "tam": 0.14, "eixo": "h"},
	"mesa_cozinha": {"arquivo": "res://assets/objetos/cozinha.glb", "no": "CookingTable_001_3", "tam": 0.9, "eixo": "h", "giro": 90.0},
	# ---- estante de ferro (Shelf, Dmitriy Mitroshin)
	"estante_ferro": {"arquivo": "res://assets/objetos/estante.glb", "no": "Shelf_02_A", "tam": 1.9, "eixo": "h"},
	"estante_ferro_larga": {"arquivo": "res://assets/objetos/estante.glb", "no": "Shelf_02_B", "tam": 1.9, "eixo": "h"},
	# ---- casa (Objects Interior Village, Elbolillo)
	"sofa": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Armchair_04", "tam": 0.8, "eixo": "h"},
	"poltrona": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Armchair_05", "tam": 0.95, "eixo": "h"},
	"poltrona2": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Armchair_02", "tam": 1.0, "eixo": "h"},
	"cadeira": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Chair_03", "tam": 0.95, "eixo": "h"},
	"cadeira2": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Chair_05", "tam": 0.95, "eixo": "h"},
	"comoda": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Chest_drawers_02", "tam": 0.95, "eixo": "h"},
	"comoda2": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Chest_drawers_05", "tam": 1.0, "eixo": "h"},
	"estante_livros": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Bookcase_01", "tam": 1.85, "eixo": "h"},
	"abajur": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Desk_lamp", "tam": 0.5, "eixo": "h"},
	"livros": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Books_001", "tam": 0.3, "eixo": "m"},
	"lixo": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Garbage_bags", "tam": 0.85, "eixo": "h"},
	"pizza": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Box_Pizza_001", "tam": 0.4, "eixo": "m"},
	"garrafa": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Bottle", "tam": 0.3, "eixo": "h"},
	"ventilador": {"arquivo": "res://assets/objetos/objetos_vila.glb", "no": "Ceiling_Fan_02", "tam": 1.1, "eixo": "m"},
	# ---- miudezas
	"jornais": {"arquivo": "res://assets/objetos/jornais.glb", "no": "newspaper_1", "tam": 0.42, "eixo": "m"},
	"jornal": {"arquivo": "res://assets/objetos/jornal_ps1.glb", "no": "Newspaper01", "tam": 0.4, "eixo": "m", "deitar": -90.0},
	"jornal_sangue": {"arquivo": "res://assets/objetos/jornal_ps1.glb", "no": "Newspaper02", "tam": 0.4, "eixo": "m", "deitar": -90.0},
	"cinzeiro": {"arquivo": "res://assets/objetos/cinzeiro.glb", "no": "", "tam": 0.14, "eixo": "m"},
	"cinzeiro_cheio": {"arquivo": "res://assets/objetos/cinzeiro_cigarros.glb", "no": "", "tam": 0.16, "eixo": "m"},
	"dinheiro": {"arquivo": "res://assets/objetos/dinheiro.glb", "no": "", "tam": 0.3, "eixo": "m"},
	"saco_dinheiro": {"arquivo": "res://assets/objetos/saco_dinheiro.glb", "no": "", "tam": 0.35, "eixo": "m"},
	# ---- carros (frente em +Z, como os carros do jogo)
	"carro_punto": {"arquivo": "res://assets/carros/punto.glb", "no": "", "tam": 3.8, "eixo": "c", "sem": ["Punto_GT_8"]},
	"carro_viatura": {"arquivo": "res://assets/carros/viatura.glb", "no": "", "tam": 4.9, "eixo": "c", "giro": -90.0},
	"carro_velho": {"arquivo": "res://assets/carros/carro_enferrujado.glb", "no": "", "tam": 4.6, "eixo": "c", "sem": ["Plane001"]},
	"casa_trailer": {"arquivo": "res://assets/carros/trailer_park.glb", "no": "Home", "dentro": true, "tam": 15.1, "eixo": "m"},
	"casa_trailer2": {"arquivo": "res://assets/carros/trailer_park.glb", "no": "Home_02", "dentro": true, "tam": 15.1, "eixo": "m"},
	"muro_carros": {"arquivo": "res://assets/carros/muro_carros.glb", "no": "", "tam": 16.0, "eixo": "m"},
	# ---- estufa (Greenhouse Foliage, Mats de Wind)
	"planta_palmeira": {"arquivo": "res://assets/objetos/estufa_plantas.glb", "no": "Plant_Palm2", "tam": 1.1, "eixo": "h"},
	"planta_arbusto": {"arquivo": "res://assets/objetos/estufa_plantas.glb", "no": "Plant_Bush4", "tam": 1.0, "eixo": "h"},
	"planta_costela": {"arquivo": "res://assets/objetos/estufa_plantas.glb", "no": "Plant_Monstera1", "tam": 0.8, "eixo": "h"},
	"planta_muda": {"arquivo": "res://assets/objetos/estufa_plantas.glb", "no": "Plant_Sapling2", "tam": 0.5, "eixo": "h"},
	"planta_capim": {"arquivo": "res://assets/objetos/estufa_plantas.glb", "no": "Plant_Grass1", "tam": 0.7, "eixo": "h"},
	"planta_samambaia": {"arquivo": "res://assets/objetos/estufa_plantas.glb", "no": "Plant_Fern", "tam": 0.9, "eixo": "h"},
	# ---- rua (City Props Collection, TampaJoey — licença Sketchfab Padrão, fica fora do repositório)
	"ponto_onibus": {"arquivo": "res://assets/sketchfab_padrao/city_props.glb", "no": "BusStop", "tam": 2.6, "eixo": "h"},
	"banco_praca": {"arquivo": "res://assets/sketchfab_padrao/city_props.glb", "no": "Bench", "tam": 1.8, "eixo": "m"},
	"banco_concreto": {"arquivo": "res://assets/sketchfab_padrao/city_props.glb", "no": "ConcreteBench", "tam": 2.0, "eixo": "m", "giro": 90.0},
	"cacamba_lixo": {"arquivo": "res://assets/sketchfab_padrao/city_props.glb", "no": "Dumpster", "tam": 1.45, "eixo": "h"},
	"hidrante": {"arquivo": "res://assets/sketchfab_padrao/city_props.glb", "no": "FireHydrant", "tam": 0.8, "eixo": "h"},
	"caixa_eletronico": {"arquivo": "res://assets/sketchfab_padrao/city_props.glb", "no": "ATM", "tam": 1.7, "eixo": "h"},
}

static var _modelos := {}   # id -> Node3D pronto (molde), ou null se faltar o arquivo
static var _cenas := {}

static func existe(id: String) -> bool:
	return C.has(id) and ResourceLoader.exists(C[id].arquivo)

static func _cena(arq: String) -> Node3D:
	if not _cenas.has(arq):
		_cenas[arq] = (load(arq) as PackedScene).instantiate()
	return _cenas[arq]

static func _malhas(n: Node, t: Transform3D, saida: Array) -> void:
	var tt := t
	if n is Node3D:
		tt = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (n as Node3D).visible:
		saida.append([n, tt])
	for c in n.get_children():
		_malhas(c, tt, saida)

static func _caixa(lista: Array) -> AABB:
	var ab := AABB()
	var primeiro := true
	for par in lista:
		var a: AABB = (par[1] as Transform3D) * (par[0] as MeshInstance3D).get_aabb()
		ab = a if primeiro else ab.merge(a)
		primeiro = false
	return ab

## Molde do objeto (só malhas, transformações já aplicadas, base na origem, frente +Z).
static func _molde(id: String) -> Node3D:
	if _modelos.has(id):
		return _modelos[id]
	var d: Dictionary = C[id]
	if not ResourceLoader.exists(d.arquivo):
		_modelos[id] = null
		return null
	var cena := _cena(d.arquivo)
	var todas: Array = []
	_malhas(cena, Transform3D(), todas)
	var sem: Array = d.get("sem", [])
	var escolhidas: Array = []
	if d.no == "":
		for par in todas:
			var ok := true
			for s in sem:
				if _caminho(cena, par[0]).contains(s):
					ok = false
			if ok:
				escolhidas.append(par)
	else:
		# o nó principal e os irmãos "filhos de nome" que ficam dentro dele
		var principais: Array = todas.filter(func(p): return _tem_ancestral(cena, p[0], d.no, true))
		if principais.is_empty():
			push_warning("Props: nó %s não achado em %s" % [d.no, d.arquivo])
			_modelos[id] = null
			return null
		var cx := _caixa(principais).grow(0.05)
		escolhidas = principais.duplicate()
		for par in todas:
			if par in principais:
				continue
			var a: AABB = (par[1] as Transform3D) * (par[0] as MeshInstance3D).get_aabb()
			if d.get("dentro", false):
				# tudo que está dentro da caixa do nó principal (móveis soltos de uma casa)
				if cx.has_point(a.get_center()) and a.size.length() < cx.size.length() * 0.6:
					escolhidas.append(par)
			elif _tem_ancestral(cena, par[0], d.no + "_", false) and cx.encloses(a):
				escolhidas.append(par)
	var raiz := Node3D.new()
	raiz.name = id
	var giro := Basis(Vector3.UP, deg_to_rad(float(d.get("giro", 0.0)))) * Basis(Vector3.RIGHT, deg_to_rad(float(d.get("deitar", 0.0)))) * Basis(Vector3.BACK, deg_to_rad(float(d.get("tombar", 0.0))))
	var lim := _caixa(escolhidas)
	# caixa girada (basta girar os cantos)
	var mn := Vector3.INF
	var mx := -Vector3.INF
	for i in 8:
		var p := giro * lim.get_endpoint(i)
		mn = mn.min(p)
		mx = mx.max(p)
	var tam := mx - mn
	var medida: float = {"h": tam.y, "c": tam.z, "m": maxf(tam.x, maxf(tam.y, tam.z))}[d.get("eixo", "m")]
	var esc: float = float(d.tam) / maxf(medida, 0.0001)
	var centro := Vector3((mn.x + mx.x) * 0.5, mn.y, (mn.z + mx.z) * 0.5)
	var base := Transform3D(giro.scaled(Vector3.ONE * esc), -centro * esc)
	if escolhidas.size() > 12:
		# muitos pedaços: junta tudo por material (menos chamadas de desenho)
		for mi in _juntar(escolhidas, base):
			raiz.add_child(mi)
		escolhidas = []
	for par in escolhidas:
		var mi := MeshInstance3D.new()
		var orig: MeshInstance3D = par[0]
		mi.mesh = orig.mesh
		for s in orig.get_surface_override_material_count():
			if orig.get_surface_override_material(s):
				mi.set_surface_override_material(s, orig.get_surface_override_material(s))
		if orig.material_override:
			mi.material_override = orig.material_override
		mi.transform = base * (par[1] as Transform3D)
		raiz.add_child(mi)
	raiz.set_meta("tamanho", tam * esc)
	_modelos[id] = raiz
	return raiz

static func _juntar(lista: Array, base: Transform3D) -> Array:
	var por_mat := {}   # material -> SurfaceTool
	var ordem: Array = []
	for par in lista:
		var orig: MeshInstance3D = par[0]
		var t: Transform3D = base * (par[1] as Transform3D)
		for s in orig.mesh.get_surface_count():
			if orig.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var mat: Material = orig.get_active_material(s)
			if not por_mat.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				por_mat[mat] = st
				ordem.append(mat)
			(por_mat[mat] as SurfaceTool).append_from(orig.mesh, s, t)
	var saida: Array = []
	for mat in ordem:
		var st: SurfaceTool = por_mat[mat]
		st.set_material(mat)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		saida.append(mi)
	return saida

static func _caminho(raiz: Node, n: Node) -> String:
	var s := ""
	var a := n
	while a != null and a != raiz:
		s = a.name + "/" + s
		a = a.get_parent()
	return s

## n tem um ancestral (ou é) com nome == nome (exato) ou começando com nome (prefixo)?
static func _tem_ancestral(raiz: Node, n: Node, nome: String, exato: bool) -> bool:
	var a := n
	while a != null and a != raiz:
		if (exato and a.name == nome) or (not exato and String(a.name).begins_with(nome)):
			return true
		a = a.get_parent()
	return false

## Põe o objeto. giro em graus (Y), escala relativa ao tamanho real, alcance = some de longe.
static func por(pai: Node3D, id: String, pos: Vector3, giro := 0.0, escala := 1.0, alcance := 45.0, sombra := true) -> Node3D:
	var m := _molde(id)
	if m == null:
		return null
	var n: Node3D = m.duplicate()
	n.position = pos
	n.rotation.y = deg_to_rad(giro)
	n.scale = Vector3.ONE * escala
	n.set_meta("nao_mesclar", true)
	for c in n.get_children():
		var mi := c as MeshInstance3D
		if mi:
			mi.visibility_range_end = alcance
			if not sombra:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(n)
	return n

static func tamanho(id: String) -> Vector3:
	var m := _molde(id)
	return m.get_meta("tamanho") if m else Vector3.ZERO
