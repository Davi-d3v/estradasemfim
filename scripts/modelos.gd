class_name Modelos
## Modelos 3D prontos (CC0, Quaternius): personagens de proporção realista e com rosto
## (Universal Base Characters + roupa modular, montados em PersonagemU), animados
## direto pela Universal Animation Library (mesmo esqueleto). Animais e armas.

const ESCALA := 1.0
const UAL := ["res://assets/personagens/UAL1.glb", "res://assets/personagens/UAL2.glb"]
const LOOPS := ["Idle", "Idle_LookAround", "Idle_Talking", "Idle_Tired", "Idle_FoldArms", "Idle_Torch", "Walk", "Walk_Formal",
	"Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Crawl_Fwd", "Crawl_Idle", "Pistol_Idle", "Pistol_Aim_Neutral",
	"Pistol_Aim_Down", "Pistol_Aim_Up", "Fixing_Kneeling", "GroundSit_Idle", "Sitting_Idle", "Sitting_Talking",
	"Zombie_Idle", "Zombie_Walk_Fwd", "Zombie_Run_Fwd", "Farm_Harvest", "Farm_Watering", "Mining", "TreeChopping",
	"Walk_Carry", "Sword_Idle", "Driving", "Crying", "Idle_Lantern", "Idle_TalkingPhone", "Idle_Rail", "Consume"]

const PELES := [Color(1.0, 1.0, 1.0), Color(0.92, 0.85, 0.8), Color(0.78, 0.66, 0.58), Color(0.62, 0.5, 0.42), Color(0.48, 0.38, 0.32), Color(1.0, 0.94, 0.9)]
const CABELOS := [Color(0.16, 0.11, 0.07), Color(0.08, 0.06, 0.05), Color(0.3, 0.2, 0.12), Color(0.5, 0.38, 0.24), Color(0.62, 0.6, 0.58), Color(0.42, 0.22, 0.12)]
const ROUPAS := [Color(1, 1, 1), Color(0.75, 0.82, 0.95), Color(0.95, 0.8, 0.7), Color(0.7, 0.8, 0.65), Color(0.6, 0.6, 0.62), Color(0.9, 0.75, 0.55),
	Color(0.8, 0.6, 0.6), Color(0.55, 0.6, 0.7)]
const CABELOS_M := ["Hair_SimpleParted", "Hair_Buzzed", "Hair_SimpleParted", ""]
const CABELOS_F := ["Hair_Long", "Hair_Buns", "Hair_BuzzedFemale", "Hair_Long"]

static var _cenas := {}
static var _lib: AnimationLibrary
static var _mats := {}
static var _ok := -1

static func disponivel() -> bool:
	if _ok < 0:
		_ok = 1 if PersonagemU.disponivel() and ResourceLoader.exists(UAL[0]) else 0
	return _ok == 1

## Uma biblioteca só com as animações das duas UAL (as do pacote 2 não repetem nomes).
static func biblioteca() -> AnimationLibrary:
	if _lib == null:
		_lib = AnimationLibrary.new()
		for c in UAL:
			var n: Node = load(c).instantiate()
			var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
			var l: AnimationLibrary = ap.get_animation_library("")
			for nome in l.get_animation_list():
				if not _lib.has_animation(nome):
					var an: Animation = l.get_animation(nome)
					an.loop_mode = Animation.LOOP_LINEAR if String(nome) in LOOPS else Animation.LOOP_NONE
					_lib.add_animation(nome, an)
			n.free()
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

## Visual aleatório para um papel: {cabelo, barba, roupa, pele, cor_cabelo}.
static func escolher(papel: String, feminino: bool, rng: RandomNumberGenerator) -> Dictionary:
	var v := {
		"cabelo": (CABELOS_F if feminino else CABELOS_M)[rng.randi() % 4],
		"barba": not feminino and rng.randf() < 0.45,
		"roupa": ROUPAS[rng.randi() % ROUPAS.size()],
		"pele": PELES[rng.randi() % PELES.size()],
		"cor_cabelo": CABELOS[rng.randi() % CABELOS.size()],
	}
	match papel:
		"zumbi":
			v.pele = [Color(0.8, 1.0, 0.78), Color(0.85, 0.92, 0.88), Color(0.9, 0.95, 0.75), Color(0.78, 0.9, 0.82)][rng.randi() % 4]
			v.roupa = [Color(0.85, 0.75, 0.68), Color(0.72, 0.72, 0.78), Color(0.9, 0.72, 0.6), Color(0.75, 0.8, 0.7)][rng.randi() % 4]
			v.cor_cabelo = v.cor_cabelo.darkened(0.3)
		"medico":
			v.roupa = Color(1.1, 1.1, 1.12)
		"soldado":
			v.roupa = Color(0.62, 0.7, 0.5)
			v.barba = false
		"trabalhador":
			v.roupa = Color(0.95, 0.72, 0.45)
		"idoso":
			v.cor_cabelo = Color(0.7, 0.7, 0.68)
	return v

## Instancia um personagem. Devolve {raiz, esqueleto, player}.
static func personagem(feminino: bool, vis: Dictionary) -> Dictionary:
	var d := PersonagemU.montar(feminino, vis.get("cabelo", ""), vis.get("barba", false), vis.get("roupa", Color.WHITE), vis.get("pele", Color.WHITE), vis.get("cor_cabelo", Color(0.2, 0.14, 0.08)))
	var ap: AnimationPlayer = d.player
	ap.root_node = ap.get_path_to(d.raiz)
	ap.add_animation_library("q", biblioteca())
	for mi in d.esqueleto.get_children():
		if mi is MeshInstance3D:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return d

## Ponto de fixação num osso, em metros e no espaço do osso.
static func anexo(sk: Skeleton3D, osso: String, nome: String) -> Node3D:
	var ba := BoneAttachment3D.new()
	ba.name = "BA_" + nome
	ba.bone_name = osso
	sk.add_child(ba)
	var n := Node3D.new()
	n.name = nome
	var esc := 1.0
	var no: Node = sk
	while no != null and no is Node3D:
		esc *= (no as Node3D).scale.x
		no = no.get_parent()
	n.scale = Vector3.ONE / maxf(esc, 0.0001)
	ba.add_child(n)
	return n

# ------------------------------------------------------------ armas
## Armas de fogo: arquivo, escala, ponto da empunhadura (no modelo), ponta do cano (no modelo).
const ARMAS_FOGO := {
	"pistola": ["revolver", 0.105, Vector3(0.12, -0.18, 0.0), Vector3(1.74, 0.38, 0.0)],
	"espingarda": ["shotgun", 0.2, Vector3(0.45, -0.2, 0.0), Vector3(4.05, 0.3, 0.0)],
	"rifle": ["sniper", 0.155, Vector3(0.2, -0.3, 0.0), Vector3(5.25, 0.25, 0.0)],
	"metralhadora": ["smg", 0.14, Vector3(0.3, -0.35, 0.0), Vector3(2.27, 0.45, 0.0)],
}
## Na mão direita (osso hand_r da UAL): o cano aponta para +Y do osso e o "em cima" da
## arma para +Z. Vale para todas as poses, porque a arma é rígida na mão.
const BASE_MAO := Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
const CENTRO_MAO := Vector3(0.0, 0.08, 0.0)
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
	# armas brancas: lâmina/cabo ao longo de +Z do osso (sai pelo polegar), gume para +Y
	var lam := Node3D.new()
	lam.transform = Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)), CENTRO_MAO)
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
