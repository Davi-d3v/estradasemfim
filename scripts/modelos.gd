class_name Modelos
## Modelos 3D prontos (CC0): personagens com rosto e zumbis da Quaternius
## (Ultimate Animated Character Pack), animados com a Universal Animation Library
## redirecionada para o esqueleto deles (assets/personagens/anims_q.res, gerado por
## tools/gerar_anims.gd); animais e armas.

const ESCALA := 0.55                       # personagem ~1,75 m
const DIR := "res://assets/personagens/"
const LIB := DIR + "anims_q.res"

## Visuais por papel. Cada um lista arquivos (sem .gltf) masculinos e femininos.
const VISUAIS := {
	"civil": [["Casual_Male", "Casual2_Male", "Casual3_Male", "Casual_Bald"], ["Casual_Female", "Casual2_Female", "Casual3_Female"]],
	"trabalhador": [["Worker_Male"], ["Worker_Female"]],
	"medico": [["Doctor_Male_Young", "Doctor_Male_Old"], ["Doctor_Female_Young", "Doctor_Female_Old"]],
	"soldado": [["Soldier_Male"], ["Soldier_Female"]],
	"idoso": [["OldClassy_Male"], ["OldClassy_Female"]],
	"cowboy": [["Cowboy_Male"], ["Cowboy_Male"]],
	"cozinheiro": [["Chef_Male"], ["Chef_Male"]],
	"zumbi": [["Zombie_Male"], ["Zombie_Female"]],
}

## Tons de pele (sRGB) e cores de roupa gasta.
const PELES := [Color(0.93, 0.76, 0.62), Color(0.86, 0.66, 0.5), Color(0.74, 0.53, 0.38), Color(0.6, 0.41, 0.28),
	Color(0.45, 0.3, 0.2), Color(0.33, 0.22, 0.15), Color(0.82, 0.63, 0.48), Color(0.67, 0.47, 0.33)]
const CABELOS := [Color(0.1, 0.07, 0.05), Color(0.2, 0.12, 0.07), Color(0.32, 0.2, 0.1), Color(0.55, 0.42, 0.25), Color(0.6, 0.6, 0.58), Color(0.05, 0.05, 0.05)]
const ROUPAS := [Color(0.23, 0.28, 0.34), Color(0.35, 0.33, 0.27), Color(0.42, 0.18, 0.15), Color(0.25, 0.32, 0.22), Color(0.5, 0.48, 0.42),
	Color(0.18, 0.2, 0.24), Color(0.55, 0.4, 0.22), Color(0.3, 0.24, 0.36), Color(0.62, 0.6, 0.55), Color(0.2, 0.36, 0.42)]
const CALCAS := [Color(0.16, 0.2, 0.3), Color(0.24, 0.22, 0.18), Color(0.3, 0.28, 0.22), Color(0.12, 0.12, 0.13), Color(0.36, 0.32, 0.24)]
const PELES_ZUMBI := [Color(0.5, 0.56, 0.45), Color(0.44, 0.48, 0.42), Color(0.55, 0.52, 0.45), Color(0.38, 0.44, 0.36), Color(0.48, 0.42, 0.4)]

## Armas de fogo: arquivo, escala, ponto da empunhadura (no modelo), ponta do cano (no modelo).
const ARMAS_FOGO := {
	"pistola": ["revolver", 0.105, Vector3(0.12, -0.18, 0.0), Vector3(1.74, 0.38, 0.0)],
	"espingarda": ["shotgun", 0.2, Vector3(0.45, -0.2, 0.0), Vector3(4.05, 0.3, 0.0)],
	"rifle": ["sniper", 0.155, Vector3(0.2, -0.3, 0.0), Vector3(5.25, 0.25, 0.0)],
	"metralhadora": ["smg", 0.14, Vector3(0.3, -0.35, 0.0), Vector3(2.27, 0.45, 0.0)],
}
## Na mão direita (eixos do osso Fist.R): o cano aponta para +Y do osso, o "em cima"
## da arma para -X do osso. Vale para todas as poses porque a arma é rígida na mão.
const BASE_MAO := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
const CENTRO_MAO := Vector3(0.0, 0.055, 0.012)

static var _cenas := {}
static var _lib: AnimationLibrary
static var _mats := {}
static var _ok := -1

static func disponivel() -> bool:
	if _ok < 0:
		_ok = 1 if ResourceLoader.exists(LIB) and ResourceLoader.exists(DIR + "Casual_Male.gltf") else 0
	return _ok == 1

static func biblioteca() -> AnimationLibrary:
	if _lib == null:
		_lib = load(LIB)
	return _lib

static func _cena(caminho: String) -> PackedScene:
	if not _cenas.has(caminho):
		_cenas[caminho] = load(caminho)
	return _cenas[caminho]

static func mat(cor: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var k := "%s_%.2f_%.2f" % [cor.to_html(), rough, metal]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.roughness = rough
		m.metallic = metal
		_mats[k] = m
	return _mats[k]

## Escolhe um arquivo de visual para o papel.
static func escolher(papel: String, feminino: bool, rng: RandomNumberGenerator) -> String:
	var v: Array = VISUAIS.get(papel, VISUAIS.civil)
	var lista: Array = v[1 if feminino else 0]
	return lista[rng.randi() % lista.size()]

## Cores aleatórias coerentes para um personagem.
static func cores_aleatorias(arquivo: String, rng: RandomNumberGenerator) -> Dictionary:
	var c := {}
	if arquivo.begins_with("Zombie"):
		var pz: Color = PELES_ZUMBI[rng.randi() % PELES_ZUMBI.size()]
		c["Skin"] = pz
		c["Clothes"] = ROUPAS[rng.randi() % ROUPAS.size()].darkened(0.35)
		c["DarkClothes"] = CALCAS[rng.randi() % CALCAS.size()].darkened(0.3)
		c["Pants"] = CALCAS[rng.randi() % CALCAS.size()].darkened(0.2)
		c["Guts"] = Color(0.42, 0.07, 0.05)
		c["Face"] = Color(0.08, 0.04, 0.03)
		c["Hair"] = CABELOS[rng.randi() % CABELOS.size()].darkened(0.3)
		return c
	var pele: Color = PELES[rng.randi() % PELES.size()]
	c["Skin"] = pele
	c["Face"] = Color(0.07, 0.05, 0.04) if pele.get_luminance() > 0.33 else Color(0.95, 0.93, 0.88)
	c["Hair"] = CABELOS[rng.randi() % CABELOS.size()]
	if arquivo.begins_with("Casual"):
		c["Shirt"] = ROUPAS[rng.randi() % ROUPAS.size()]
		c["Pants"] = CALCAS[rng.randi() % CALCAS.size()]
	elif arquivo.begins_with("Worker"):
		c["Shirt"] = ROUPAS[rng.randi() % ROUPAS.size()]
	return c

## Instancia um personagem. Devolve {raiz, esqueleto, player, malha}.
static func personagem(arquivo: String, cores: Dictionary, sujeira := 0.0) -> Dictionary:
	var raiz: Node3D = _cena(DIR + arquivo + ".gltf").instantiate()
	raiz.scale = Vector3.ONE * ESCALA
	var ap: AnimationPlayer = raiz.get_node("AnimationPlayer")
	ap.add_animation_library("q", biblioteca())
	var sk: Skeleton3D = raiz.find_child("Skeleton3D", true, false)
	var malha: MeshInstance3D = null
	for mi in sk.get_children():
		if mi is MeshInstance3D:
			malha = mi
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(s)
				var nome := m.resource_name if m else ""
				if cores.has(nome):
					var cor: Color = cores[nome]
					if sujeira > 0.0 and nome != "Face" and nome != "Skin":
						cor = cor.lerp(Color(0.3, 0.25, 0.18), sujeira)
					mi.set_surface_override_material(s, mat(cor, 0.9))
				elif m is StandardMaterial3D:
					# cores originais em linear: deixa um pouco mais claras para o nosso céu
					mi.set_surface_override_material(s, mat((m as StandardMaterial3D).albedo_color.linear_to_srgb().darkened(0.05), 0.9))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return {"raiz": raiz, "esqueleto": sk, "player": ap, "malha": malha}

## Ponto de fixação num osso, em metros (desfaz a escala do modelo).
static func anexo(sk: Skeleton3D, osso: String, nome: String) -> Node3D:
	var ba := BoneAttachment3D.new()
	ba.name = "BA_" + nome
	ba.bone_name = osso
	sk.add_child(ba)
	var n := Node3D.new()
	n.name = nome
	n.scale = Vector3.ONE / ESCALA
	ba.add_child(n)
	return n

# ------------------------------------------------------------ armas
## Monta a arma na âncora da mão direita. Cria o nó "Arma" e, nas de fogo, "Boca".
static func arma_na_mao(mao: Node3D, id: String) -> Node3D:
	var velho := mao.get_node_or_null("Arma")
	if velho:
		velho.free()
	if id == "":
		return null
	var arma := Node3D.new()
	arma.name = "Arma"
	mao.add_child(arma)
	var preto := mat(Color(0.08, 0.08, 0.08), 0.45, 0.6)
	var aco := mat(Color(0.55, 0.55, 0.57), 0.3, 0.85)
	var madeira := mat(Color(0.4, 0.24, 0.12), 0.7)
	if ARMAS_FOGO.has(id):
		var d: Array = ARMAS_FOGO[id]
		var m: Node3D = _cena("res://assets/armas/%s.glb" % d[0]).instantiate()
		var esc: float = d[1]
		m.transform = Transform3D(BASE_MAO.scaled(Vector3.ONE * esc), CENTRO_MAO - BASE_MAO * (d[2] * esc))
		arma.add_child(m)
		var boca := Node3D.new()
		boca.name = "Boca"
		boca.position = CENTRO_MAO + BASE_MAO * ((d[3] - d[2]) * esc)
		arma.add_child(boca)
		return arma
	# armas brancas: lâmina/cabo ao longo de -X do osso (sai pelo polegar), gume para +Y
	var lam := Node3D.new()
	lam.transform = Transform3D(Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)), CENTRO_MAO)
	arma.add_child(lam)
	# no espaço "lam": +Y = ao longo do cabo para a ponta, +Z = gume
	match id:
		"facao":
			B.box(lam, Vector3(0.03, 0.13, 0.035), Vector3(0, 0.0, 0), mat(Color(0.1, 0.07, 0.05), 0.8))
			B.box(lam, Vector3(0.006, 0.44, 0.06), Vector3(0, 0.29, 0.01), mat(Color(0.6, 0.6, 0.6), 0.3, 0.9))
		"pe_de_cabra":
			var ver := mat(Color(0.55, 0.12, 0.08), 0.5, 0.6)
			B.cyl(lam, 0.014, 0.62, Vector3(0, 0.2, 0), ver, Vector3.ZERO, 6)
			B.box(lam, Vector3(0.02, 0.03, 0.09), Vector3(0, 0.5, 0.04), ver, Vector3(-30, 0, 0))
		"taco":
			B.cyl(lam, 0.022, 0.72, Vector3(0, 0.26, 0), madeira, Vector3.ZERO, 8, 0.04)
			for q in 6:
				B.box(lam, Vector3(0.09, 0.006, 0.006), Vector3(0, 0.42 + q * 0.04, 0), aco, Vector3(0, q * 60, 0))
		"machado":
			var m: Node3D = _cena("res://assets/armas/tool-axe.glb").instantiate()
			m.scale = Vector3.ONE * 2.6
			m.position = Vector3(0, -0.08, 0)
			m.rotation_degrees = Vector3(0, 90, 0)
			lam.add_child(m)
		"chave":
			B.box(lam, Vector3(0.02, 0.3, 0.03), Vector3(0, 0.12, 0), aco)
			B.box(lam, Vector3(0.025, 0.05, 0.07), Vector3(0, 0.28, 0), aco)
		"martelo":
			var m2: Node3D = _cena("res://assets/armas/tool-hammer.glb").instantiate()
			m2.scale = Vector3.ONE * 2.4
			m2.position = Vector3(0, -0.06, 0)
			lam.add_child(m2)
		"besta":
			var bt := Node3D.new()
			bt.transform = Transform3D(BASE_MAO, CENTRO_MAO)
			arma.add_child(bt)
			# no espaço da arma: +X cano, +Y cima
			B.box(bt, Vector3(0.6, 0.06, 0.05), Vector3(0.2, 0.02, 0), madeira)
			B.box(bt, Vector3(0.04, 0.03, 0.62), Vector3(0.42, 0.05, 0), preto)
			B.box(bt, Vector3(0.004, 0.004, 0.6), Vector3(0.36, 0.06, 0), mat(Color(0.8, 0.78, 0.7), 0.8))
			B.cyl(bt, 0.007, 0.36, Vector3(0.3, 0.075, 0), aco, Vector3(0, 0, 90), 4)
			var boca2 := Node3D.new()
			boca2.name = "Boca"
			boca2.position = CENTRO_MAO + BASE_MAO * Vector3(0.5, 0.06, 0)
			arma.add_child(boca2)
	return arma

# ------------------------------------------------------------ animais
const ANIMAIS := {
	"veado": ["Deer", 0.34], "cervo": ["Stag", 0.36], "lobo": ["Wolf", 0.33], "raposa": ["Fox", 0.3],
}

static func animal(tipo: String) -> Dictionary:
	if not ANIMAIS.has(tipo):
		return {}
	var d: Array = ANIMAIS[tipo]
	var caminho := "res://assets/animais/%s.gltf" % d[0]
	if not ResourceLoader.exists(caminho):
		return {}
	var raiz: Node3D = _cena(caminho).instantiate()
	raiz.scale = Vector3.ONE * float(d[1])
	var ap: AnimationPlayer = raiz.find_child("AnimationPlayer", true, false)
	for nome in ap.get_animation_list():
		if nome.begins_with("Idle") or nome in ["Walk", "Gallop", "Eating", "Trot", "Run"]:
			ap.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	return {"raiz": raiz, "player": ap, "esqueleto": raiz.find_child("Skeleton3D", true, false)}
