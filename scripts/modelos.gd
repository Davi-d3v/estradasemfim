class_name Modelos
## Modelos 3D prontos (CC0, Quaternius): personagens de proporção realista e com rosto
## (Universal Base Characters + roupa modular, montados em PersonagemU), animados
## direto pela Universal Animation Library (mesmo esqueleto). Animais e armas.

const ESCALA := 1.0
const UAL := ["res://assets/personagens/UAL1.glb", "res://assets/personagens/UAL2.glb"]
const LOOPS := ["Idle", "Idle_LookAround", "Idle_Talking", "Idle_Tired", "Idle_FoldArms", "Idle_Torch", "Walk", "Walk_Formal",
	"Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Crawl_Fwd", "Crawl_Idle", "Pistol_Idle", "Pistol_Aim_Neutral",
	"Pistol_Aim_Down", "Pistol_Aim_Up", "Fixing_Kneeling", "GroundSit_Idle", "Sitting_Idle", "Sitting_Talking", "Sitting_Nodding", "Sitting_Idle02", "Sitting_Idle03",
	"Zombie_Idle", "Zombie_Walk_Fwd", "Zombie_Run_Fwd", "Farm_Harvest", "Farm_Watering", "Mining", "TreeChopping",
	"Walk_Carry", "Sword_Idle", "Driving", "Crying", "Idle_Lantern", "Idle_TalkingPhone", "Idle_Rail", "Consume", "Jump_Loop"]

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
	v.pecas = trajes(papel, rng)
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

## Roupa peça por peça para cada papel: camisa, braços, calça e calçado com cores próprias
## (camponês = pano; patrulheiro = couro, cinto, botas, capuz, ombreira).
static func trajes(papel: String, rng: RandomNumberGenerator) -> Array:
	var lista := _trajes(papel, rng)
	for pc in lista:
		if pc[0] == "Peasant_Legs":
			# a calça de camponês tem textura escura: clareia a tinta para a cor aparecer
			pc[1] = Color(pc[1].r * 2.3, pc[1].g * 2.3, pc[1].b * 2.3)
	return lista

static func _trajes(papel: String, rng: RandomNumberGenerator) -> Array:
	var pano := func(c: Color) -> Color:
		return c.lerp(Color(0.85, 0.82, 0.75), rng.randf_range(0.0, 0.2))
	var camisa: Color = pano.call(ROUPAS[rng.randi() % ROUPAS.size()])
	var calca: Color = [Color(0.55, 0.62, 0.85), Color(0.5, 0.48, 0.45), Color(0.7, 0.62, 0.5), Color(0.42, 0.45, 0.42)][rng.randi() % 4]
	var bota := Color(0.6, 0.5, 0.42) if rng.randf() < 0.5 else Color(0.4, 0.36, 0.33)
	match papel:
		"zumbi":
			return []
		"medico":   # jaleco branco, calça de hospital azul-clara
			return [["Peasant_Body", Color(1.15, 1.15, 1.18)], ["Peasant_Arms", Color(1.15, 1.15, 1.18)], ["Peasant_Legs", Color(0.7, 0.85, 1.05)], ["Peasant_Feet", Color(0.9, 0.9, 0.92)]]
		"soldado":   # farda verde-oliva e coturno
			var oliva := Color(0.55, 0.62, 0.42).lerp(Color(0.62, 0.58, 0.45), rng.randf())
			return [["Ranger_Body", oliva], ["Ranger_Arms", oliva], ["Ranger_Legs", oliva * 0.9], ["Ranger_Feet_Boots", Color(0.35, 0.33, 0.3)]]
		"trabalhador", "mecanico":   # macacão azul de oficina
			var az := Color(0.42, 0.55, 0.85)
			return [["Peasant_Body", az], ["Peasant_Arms", az], ["Peasant_Legs", az * 0.92], ["Ranger_Feet_Boots", Color(0.45, 0.38, 0.32)]]
		"agricultor":   # camisa xadrez avermelhada, jeans, botina
			return [["Peasant_Body", Color(0.95, 0.6, 0.5).lerp(Color(0.85, 0.75, 0.5), rng.randf())], ["Peasant_Arms", Color(0.95, 0.65, 0.55)], ["Peasant_Legs", Color(0.5, 0.6, 0.88)], ["Ranger_Feet_Boots", Color(0.6, 0.45, 0.32)]]
		"armeiro":   # couro escuro, calça grossa, bota
			return [["Ranger_Body", Color(0.55, 0.45, 0.38)], ["Ranger_Arms", Color(0.5, 0.42, 0.36)], ["Peasant_Legs", Color(0.42, 0.42, 0.4)], ["Ranger_Feet_Boots", Color(0.3, 0.28, 0.26)]]
		"batedor":   # patrulheiro de capuz, cores de mato
			var mato := Color(0.6, 0.68, 0.5).lerp(Color(0.7, 0.62, 0.5), rng.randf())
			return [["Ranger_Body", mato], ["Ranger_Arms", mato], ["Ranger_Legs", mato * 0.85], ["Ranger_Feet_Boots", Color(0.45, 0.4, 0.35)], ["Ranger_Head_Hood", mato * 0.95]]
		"lider":   # casaco de couro com ombreira
			return [["Ranger_Body", Color(0.48, 0.4, 0.36)], ["Ranger_Arms", Color(0.48, 0.4, 0.36)], ["Ranger_Legs", Color(0.4, 0.38, 0.36)], ["Ranger_Feet_Boots", Color(0.3, 0.27, 0.25)], ["Ranger_Acc_Pauldron", Color(0.6, 0.55, 0.5)]]
		"idoso":   # cardigã bege, calça social
			return [["Peasant_Body", Color(0.95, 0.85, 0.68)], ["Peasant_Arms", Color(0.95, 0.85, 0.68)], ["Peasant_Legs", Color(0.55, 0.5, 0.48)], ["Peasant_Feet", Color(0.55, 0.45, 0.4)]]
		"cozinheiro":
			return [["Peasant_Body", Color(1.15, 1.15, 1.12)], ["Peasant_Arms", Color(1.15, 1.15, 1.12)], ["Peasant_Legs", Color(0.45, 0.45, 0.48)], ["Peasant_Feet", Color(0.4, 0.4, 0.4)]]
		"cowboy":
			return [["Ranger_Body", Color(0.8, 0.62, 0.45)], ["Peasant_Arms", Color(0.9, 0.8, 0.65)], ["Peasant_Legs", Color(0.5, 0.6, 0.88)], ["Ranger_Feet_Boots", Color(0.6, 0.42, 0.28)]]
		"vendedor":
			return [["Peasant_Body", camisa], ["Peasant_Arms", camisa], ["Peasant_Legs", calca], ["Peasant_Feet", bota]]
	# civil: mistura, às vezes com peças de couro
	var corpo := "Ranger_Body" if rng.randf() < 0.3 else "Peasant_Body"
	var pes := "Ranger_Feet_Boots" if rng.randf() < 0.4 else "Peasant_Feet"
	return [[corpo, camisa], ["Peasant_Arms", camisa], ["Ranger_Legs" if rng.randf() < 0.25 else "Peasant_Legs", calca], [pes, bota]]

## Instancia um personagem. Devolve {raiz, esqueleto, player}.
static func personagem(feminino: bool, vis: Dictionary) -> Dictionary:
	var d := PersonagemU.montar(feminino, vis.get("cabelo", ""), vis.get("barba", false), vis.get("roupa", Color.WHITE), vis.get("pele", Color.WHITE), vis.get("cor_cabelo", Color(0.2, 0.14, 0.08)), vis.get("pecas", []))
	var ap: AnimationPlayer = d.player
	ap.root_node = ap.get_path_to(d.raiz)
	ap.add_animation_library("q", biblioteca())
	for mi in d.esqueleto.get_children():
		if mi is MeshInstance3D:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return d

## Protagonista: o sobrevivente de máscara de gás (Sketchfab, "post apo character", Am I dead?),
## malha única ligada ao esqueleto da UAL por tools/rigar_personagem.gd.
const SOBREVIVENTE := "res://assets/personagem_novo/corpo.res"

static func sobrevivente_ok() -> bool:
	return ResourceLoader.exists(SOBREVIVENTE)

static func sobrevivente() -> Dictionary:
	var raiz: Node3D = PersonagemU._cena(PersonagemU.DIR + "base/Superhero_Male_FullBody.gltf").instantiate()
	var sk: Skeleton3D = raiz.find_children("*", "Skeleton3D", true, false)[0]
	for mi in sk.get_children():
		if mi is MeshInstance3D:
			mi.queue_free()
	var m := MeshInstance3D.new()
	m.name = "Sobrevivente"
	m.mesh = load(SOBREVIVENTE)
	m.skin = load("res://assets/personagem_novo/corpo_skin.tres")
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sk.add_child(m)
	m.skeleton = NodePath("..")
	var aps := raiz.find_children("*", "AnimationPlayer", true, false)
	var ap: AnimationPlayer = aps[0] if aps.size() > 0 else null
	if ap == null:
		ap = AnimationPlayer.new()
		raiz.add_child(ap)
	ap.root_node = ap.get_path_to(raiz)
	ap.add_animation_library("q", biblioteca())
	return {"raiz": raiz, "esqueleto": sk, "player": ap}

## NPCs e zumbis: avatares realistas Rocketbox (Microsoft, MIT), com roupa de cada profissão e
## texturas sujas para combinar com o protagonista (tools/preparar_npcs.py + tools/rigar_npc.gd).
const NPCS_DIR := "res://assets/npcs/"
const ADULTOS_M := ["Male_Adult_01", "Male_Adult_02", "Male_Adult_03", "Male_Adult_04", "Male_Adult_05", "Male_Adult_06", "Male_Adult_07", "Male_Adult_08"]
const ADULTOS_F := ["Female_Adult_01", "Female_Adult_02", "Female_Adult_03", "Female_Adult_04", "Female_Adult_05", "Female_Adult_06"]
const NPCS := {   # papel -> [homens, mulheres]
	"medico": [["Medical_Male_01", "Medical_Male_02"], ["Medical_Female_01", "Medical_Female_02"]],
	"soldado": [["Military_Male_01", "Military_Male_02", "Military_Male_04"], ["Military_Female_01"]],
	"mecanico": [["Construction_Male_02"], ["Construction_Female_01"]],
	"trabalhador": [["Construction_Male_02"], ["Construction_Female_01"]],
	"agricultor": [["Gardener_Male_01", "Wood_Male_01"], ["Female_Adult_03", "Female_Adult_06"]],
	"armeiro": [["Security_Male_01"], ["Security_Female_01"]],
	"batedor": [["Military_Male_04", "Wood_Male_01"], ["Sports_Female_01"]],
	"lider": [["Business_Male_01"], ["Female_Adult_05"]],
	"cozinheiro": [["Male_Adult_07"], ["Chef_Female_01"]],
	"crianca": [["Male_Child_01"], ["Female_Child_01"]],
}
const ZUMBIS := ["Male_Adult_01", "Male_Adult_02", "Male_Adult_03", "Male_Adult_04", "Male_Adult_05", "Male_Adult_06", "Male_Adult_08",
	"Female_Adult_01", "Female_Adult_02", "Female_Adult_04", "Female_Adult_05", "Construction_Male_02", "Medical_Male_02", "Business_Male_01",
	"Military_Male_02", "Medical_Female_01", "Wood_Male_01", "Sports_Female_01", "Chef_Female_01", "Gardener_Male_01"]
static var _npc_ok := -1

static func npcs_ok() -> bool:
	if _npc_ok < 0:
		_npc_ok = 1 if ResourceLoader.exists(NPCS_DIR + "Male_Adult_01/corpo.res") else 0
	return _npc_ok == 1

static func escolher_npc(papel: String, feminino: bool, rng: RandomNumberGenerator) -> String:
	var lista: Array
	if papel == "zumbi":
		lista = ZUMBIS
	elif NPCS.has(papel):
		lista = NPCS[papel][1 if feminino else 0]
	else:
		lista = ADULTOS_F if feminino else ADULTOS_M
	var nome: String = lista[rng.randi() % lista.size()]
	return nome if ResourceLoader.exists(NPCS_DIR + nome + "/corpo.res") else (ADULTOS_F if feminino else ADULTOS_M)[0]

static var _mats_zumbi := {}
static var _sangue: ShaderMaterial
static var _sangue_rosto: ShaderMaterial

## Camada de sangue seco e sujeira por cima da roupa dos zumbis (manchas pelo mapa de UV,
## estáveis enquanto o corpo anda). Vai como next_pass do material.
static func sangue_zumbi() -> ShaderMaterial:
	if _sangue == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_lambert;
uniform float semente = 0.0;
uniform float limiar = 0.58;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * 7.0 + vec2(semente * 3.1, semente * 1.7);
	float m = n(p) * 0.6 + n(p * 2.7) * 0.3 + n(p * 9.0) * 0.1;
	float a = smoothstep(limiar, limiar + 0.1, m);
	ALBEDO = mix(vec3(0.16, 0.02, 0.015), vec3(0.08, 0.05, 0.03), n(p * 4.0));
	ROUGHNESS = 0.45;
	ALPHA = a * 0.9;
}
"""
		_sangue = ShaderMaterial.new()
		_sangue.shader = sh
		_sangue_rosto = ShaderMaterial.new()
		_sangue_rosto.shader = sh
		_sangue_rosto.set_shader_parameter("limiar", 0.7)
	return _sangue

## Monta um avatar no esqueleto da UAL. zumbi: pele cinza-esverdeada e roupa encardida.
static func npc(nome: String, zumbi := false) -> Dictionary:
	var raiz: Node3D = PersonagemU._cena(PersonagemU.DIR + "base/Superhero_Male_FullBody.gltf").instantiate()
	var sk: Skeleton3D = raiz.find_children("*", "Skeleton3D", true, false)[0]
	for mi in sk.get_children():
		if mi is MeshInstance3D:
			mi.queue_free()
	var malha: Mesh = load(NPCS_DIR + nome + "/corpo.res")
	var m := MeshInstance3D.new()
	m.name = "Corpo"
	m.mesh = malha
	m.skin = load(NPCS_DIR + nome + "/corpo_skin.tres")
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sk.add_child(m)
	m.skeleton = NodePath("..")
	if zumbi:
		for s in malha.get_surface_count():
			var k := "%s:%d" % [nome, s]
			if not _mats_zumbi.has(k):
				var d: StandardMaterial3D = (malha.surface_get_material(s) as StandardMaterial3D).duplicate()
				var cabeca := String(d.albedo_texture.resource_path if d.albedo_texture else "").ends_with("head.jpg")
				d.albedo_color = Color(0.68, 0.78, 0.64) if cabeca else Color(0.6, 0.56, 0.5)
				d.roughness = 0.9
				if d.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
					sangue_zumbi()
					d.next_pass = _sangue_rosto if cabeca else _sangue
				_mats_zumbi[k] = d
			m.set_surface_override_material(s, _mats_zumbi[k])
	# a malha foi feita na altura do esqueleto (1,82 m); escala para a altura real do avatar
	raiz.scale = Vector3.ONE * clampf(float(malha.get_meta("altura", 1.82)) / 1.82, 0.7, 1.1)
	var aps := raiz.find_children("*", "AnimationPlayer", true, false)
	var ap: AnimationPlayer = aps[0] if aps.size() > 0 else null
	if ap == null:
		ap = AnimationPlayer.new()
		raiz.add_child(ap)
	ap.root_node = ap.get_path_to(raiz)
	ap.add_animation_library("q", biblioteca())
	return {"raiz": raiz, "esqueleto": sk, "player": ap, "avatar": nome}

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
## Armas com modelo detalhado (ArmasHD). Se o arquivo não existir (ex.: modelo de licença
## que não vai para o repositório), cai no modelo simples de ARMAS_FOGO.
const ARMAS_HD := {"pistola": "m1911", "rifle": "kar98k", "carabina": "saiga9", "fuzil": "acr",
	"precisao": "svd", "prototipo": "prototipo", "bullpup": "bullpup"}
const RESERVA := {"carabina": "metralhadora", "fuzil": "metralhadora", "precisao": "rifle", "prototipo": "metralhadora", "bullpup": "metralhadora"}

## Monta a arma na âncora da mão direita. Cria o nó "Arma" e, nas de fogo, "Boca".
## Nas armas longas, guarda em meta "ombro" e "apoio" (espaço da arma, metros, a partir
## da empunhadura) para a pegada com as duas mãos (PegadaArma).
static func arma_na_mao(mao: Node3D, id: String) -> Node3D:
	var velho := mao.get_node_or_null("Arma")
	if velho:
		velho.free()
	if id == "":
		return null
	var arma := Node3D.new()
	arma.name = "Arma"
	mao.add_child(arma)
	if ARMAS_HD.has(id) and ArmasHD.existe(ARMAS_HD[id]):
		var hd := ArmasHD.montar(ARMAS_HD[id])
		hd.transform = Transform3D(BASE_MAO, CENTRO_MAO)
		arma.add_child(hd)
		var boca_hd := Node3D.new()
		boca_hd.name = "Boca"
		boca_hd.position = CENTRO_MAO + BASE_MAO * (hd.get_meta("boca") as Vector3)
		arma.add_child(boca_hd)
		arma.set_meta("ombro", hd.get_meta("ombro"))
		arma.set_meta("apoio", hd.get_meta("apoio"))
		return arma
	if RESERVA.has(id):
		id = RESERVA[id]
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
		# pegada de duas mãos aproximada para os modelos simples
		var comp: float = (d[3].x - d[2].x) * esc
		arma.set_meta("ombro", Vector3(-comp * 0.42, 0.04, 0.0))
		arma.set_meta("apoio", Vector3(comp * 0.45, 0.02, 0.0))
		return arma
	# armas brancas: lâmina/cabo ao longo de +Z do osso (sai pelo polegar), gume para +Y
	var lam := Node3D.new()
	lam.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), CENTRO_MAO)
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
	"veado": ["Deer", 0.34], "cervo": ["Stag", 0.36], "lobo": ["Wolf", 0.33], "raposa": ["Fox", 0.3], "husky": ["Husky", 0.3], "shiba": ["ShibaInu", 0.27],
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
