class_name Texturas
## Materiais com textura procedural (shaders/superficie.gdshader), cacheados.

const PADROES := {
	"reboco": 0, "reboco_int": 0, "tijolo": 1, "tabuas": 2, "porta": 2, "telha": 3,
	"piso_madeira": 4, "piso_ceramica": 5, "granito": 5, "concreto": 6, "metal": 7,
	"telha_velha": 3, "vidro_sujo": 8, "tecido": 9, "colchao": 9, "papelao": 10, "madeira_movel": 11, "esmalte": 0, "casca": 12, "pedra": 13,
}
## Fotos ambientCG (CC0) em assets/texturas/<pasta>: escala em metros por repetição,
## cor média da foto, quanto a cor do material tinge, massa caída (só reboco).
const FOTOS := {
	"reboco": {"pasta": "reboco", "escala": Vector2(2.4, 2.4), "media": Color(0.568, 0.556, 0.522), "tingir": 1.0, "massa": 0.6},
	"reboco_int": {"pasta": "reboco", "escala": Vector2(2.4, 2.4), "media": Color(0.568, 0.556, 0.522), "tingir": 1.0, "massa": 0.0},
	"tijolo": {"pasta": "tijolo", "escala": Vector2(1.2, 0.825), "media": Color(0.448, 0.383, 0.356), "tingir": 0.25},
	"telha": {"pasta": "telha", "escala": Vector2(3.0, 3.0), "media": Color(0.559, 0.336, 0.242), "tingir": 0.2},
	"telha_velha": {"pasta": "telha_velha", "escala": Vector2(2.8, 2.8), "media": Color(0.366, 0.306, 0.242), "tingir": 0.0},
	"concreto": {"pasta": "concreto", "escala": Vector2(2.5, 2.5), "media": Color(0.513, 0.512, 0.515), "tingir": 0.8},
	"metal": {"pasta": "metal", "escala": Vector2(1.6, 1.6), "media": Color(0.246, 0.246, 0.247), "tingir": 1.0},
}
static var usar_fotos := true
static var _shader: Shader
static var _cache := {}
static var _texs := {}

static func _tex(caminho: String) -> Texture2D:
	if not _texs.has(caminho):
		_texs[caminho] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _texs[caminho]

static func material(nome: String, cor: Color, rough := 0.9, metal := 0.0, sujeira := 0.4) -> ShaderMaterial:
	var k := "%s_%s_%.2f_%.2f" % [nome, cor.to_html(false), rough, metal]
	if _cache.has(k):
		return _cache[k]
	if _shader == null:
		_shader = load("res://shaders/superficie.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("padrao", PADROES.get(nome, 0))
	m.set_shader_parameter("rugosidade", rough)
	m.set_shader_parameter("metalico", metal)
	m.set_shader_parameter("sujeira", sujeira)
	m.set_shader_parameter("descascado", 0.7 if nome == "reboco" else 0.0)
	if usar_fotos and FOTOS.has(nome):
		var f: Dictionary = FOTOS[nome]
		var d := "res://assets/texturas/%s/" % f.pasta
		var tc := _tex(d + "cor.jpg")
		if tc:
			m.set_shader_parameter("tem_tex", true)
			m.set_shader_parameter("tex_cor", tc)
			m.set_shader_parameter("tex_normal", _tex(d + "normal.jpg"))
			m.set_shader_parameter("tex_rough", _tex(d + "rugosidade.jpg"))
			m.set_shader_parameter("escala", f.escala)
			m.set_shader_parameter("media", f.media)
			m.set_shader_parameter("tingir", f.tingir)
			m.set_shader_parameter("massa_caida", f.get("massa", -1.0))
			m.set_shader_parameter("descascado", 0.0)
	_cache[k] = m
	return m
