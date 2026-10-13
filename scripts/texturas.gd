class_name Texturas
## Materiais com textura procedural (shaders/superficie.gdshader), cacheados.

const PADROES := {
	"reboco": 0, "reboco_int": 0, "tijolo": 1, "tabuas": 2, "porta": 2, "telha": 3,
	"piso_madeira": 4, "piso_ceramica": 5, "granito": 5, "concreto": 6, "metal": 7,
	"vidro_sujo": 8, "tecido": 9, "colchao": 9, "papelao": 10, "madeira_movel": 11, "esmalte": 0, "casca": 12, "pedra": 13,
}
static var _shader: Shader
static var _cache := {}

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
	_cache[k] = m
	return m
