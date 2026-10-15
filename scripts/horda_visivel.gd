class_name HordaVisivel
extends Node3D
## A horda migratória vista de longe: uma massa de centenas de vultos andando pela
## estrada atrás do comboio, com poeira por cima e um coro de gemidos que cresce
## conforme ela chega perto. É só visual (barato, MultiMesh + shader); quando a frente
## alcança o comboio, a Defesa troca a massa por zumbis de verdade.

const N := 1200                # vultos
const PROFUNDIDADE := 320.0    # metros de horda atrás da frente
const VISIVEL_ATE := 1600.0    # distância (m) a partir da qual aparece
const N_POEIRA := 34

var main: Node
var _mm: MultiMeshInstance3D
var _poeira: MultiMeshInstance3D
var _base: Array = []          # [lateral, atrás, escala, giro] por vulto
var _z_feito := INF            # frente usada na última montagem
var _t := 0.0
var _mat: ShaderMaterial

const SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_lambert;
uniform float tempo;
uniform float some_perto = 70.0;   // abaixo disso o vulto some (perto, quem aparece são zumbis de verdade)
varying float v_alt;
varying float v_dist;
void vertex() {
	float fase = INSTANCE_CUSTOM.r * 6.2831;
	float ritmo = 2.6 + INSTANCE_CUSTOM.g * 1.6;
	float s = sin(tempo * ritmo + fase);
	// pernas balançam (abaixo do quadril), o corpo cambaleia e sobe/desce
	float perna = clamp((0.9 - VERTEX.y) / 0.9, 0.0, 1.0);
	VERTEX.z += s * perna * 0.32 * sign(VERTEX.x);
	float tronco = clamp(VERTEX.y - 0.9, 0.0, 1.0);
	VERTEX.x += sin(tempo * ritmo * 0.5 + fase) * tronco * 0.12;
	VERTEX.y += abs(s) * 0.05;
	v_alt = VERTEX.y;
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}
void fragment() {
	// some aos poucos (pontilhado) quando chega perto da câmera
	float f = clamp((v_dist - some_perto) / 45.0, 0.0, 1.0);
	float pont = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	if (pont > f) { discard; }
	vec3 c = COLOR.rgb;
	c *= mix(0.7, 1.0, clamp(v_alt / 1.7, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
"""

const SHADER_POEIRA := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 cor_longe : source_color = vec4(0.5, 0.48, 0.47, 1.0);
varying float v_dist;
uniform vec4 cor : source_color = vec4(0.3, 0.27, 0.23, 1.0);
uniform float alfa = 0.42;
uniform float tempo;
varying vec2 v_dado;
void vertex() {
	v_dado = INSTANCE_CUSTOM.rg;
	v_dist = length((VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz);
	// sempre de frente para a câmera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float ondas = 0.75 + 0.25 * sin(p.x * 5.0 + tempo * 0.7 + v_dado.x * 9.0) * sin(p.y * 4.0 - tempo * 0.5);
	d += 0.18 * sin(atan(p.y, p.x) * 5.0 + v_dado.x * 20.0 + tempo * 0.3);   // borda irregular
	float base = mix(1.0, 0.55, UV.y < 0.5 ? 1.0 - UV.y * 2.0 : 0.0);   // mais densa embaixo
	float a = smoothstep(1.0, 0.15, d) * alfa * ondas * v_dado.y * base;
	// de longe a poeira clareia um pouco (ar), mas continua escura contra o céu
	float longe = clamp((v_dist - 150.0) / 1400.0, 0.0, 0.6);
	ALBEDO = mix(cor.rgb, cor_longe.rgb, longe);
	ALPHA = a * (1.0 - longe * 0.4);
}
"""

func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 6006
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _malha_vulto()
	mm.instance_count = N
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	_mm.material_override = _mat
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mm)
	for i in N:
		# mais densa no meio da estrada e na frente; espalha para os lados lá atrás
		var atras := pow(r.randf(), 1.6) * PROFUNDIDADE
		var largura := 7.0 + atras * 0.22
		var lat := r.randfn(0.0, largura * 0.55)
		_base.append([lat, atras + r.randf_range(-3, 3), r.randf_range(0.95, 1.15), r.randf_range(-0.5, 0.5)])
		# roupas sujas e desbotadas (não preto puro: de longe, com a névoa, viram gente)
		var tons := [Color(0.13, 0.12, 0.11), Color(0.17, 0.15, 0.12), Color(0.11, 0.13, 0.15), Color(0.18, 0.11, 0.09), Color(0.12, 0.15, 0.11), Color(0.2, 0.18, 0.15)]
		mm.set_instance_color(i, tons[r.randi() % tons.size()])
		mm.set_instance_custom_data(i, Color(r.randf(), r.randf(), 0, 0))
	# poeira levantada pela multidão
	var pm := MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	pm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	pm.mesh = q
	pm.instance_count = N_POEIRA
	for i in N_POEIRA:
		pm.set_instance_custom_data(i, Color(r.randf(), r.randf_range(0.5, 1.0), 0, 0))
	var pmat := ShaderMaterial.new()
	var psh := Shader.new()
	psh.code = SHADER_POEIRA
	pmat.shader = psh
	_poeira = MultiMeshInstance3D.new()
	_poeira.multimesh = pm
	_poeira.material_override = pmat
	_poeira.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_poeira)
	visible = false

## Vulto de zumbi em baixa resolução (~150 triângulos): tronco curvado, braços para a frente.
func _malha_vulto() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var partes := [
		[_caixa(Vector3(0.36, 0.62, 0.22)), Transform3D(Basis(Vector3.RIGHT, 0.22), Vector3(0, 1.22, 0.05))],   # tronco
		[_esfera(0.12), Transform3D(Basis(), Vector3(0, 1.66, 0.16))],                                          # cabeça caída
		[_caixa(Vector3(0.14, 0.86, 0.15)), Transform3D(Basis(), Vector3(-0.11, 0.45, 0))],                    # pernas
		[_caixa(Vector3(0.14, 0.86, 0.15)), Transform3D(Basis(), Vector3(0.11, 0.45, 0))],
		[_caixa(Vector3(0.1, 0.1, 0.6)), Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(-0.24, 1.36, 0.3))],   # braços estendidos
		[_caixa(Vector3(0.1, 0.1, 0.55)), Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0.24, 1.28, 0.24))],
	]
	for pt in partes:
		st.append_from(pt[0], 0, pt[1])
	return st.commit()

func _caixa(s: Vector3) -> Mesh:
	var b := BoxMesh.new()
	b.size = s
	return b

func _esfera(r: float) -> Mesh:
	var e := SphereMesh.new()
	e.radius = r
	e.height = r * 2.1
	e.radial_segments = 8
	e.rings = 4
	return e

func _process(dt: float) -> void:
	if main == null or not main.jogando or main.get("_morto"):
		visible = false
		Som.loop("horda", -80.0, 1.0, "Ambiente")
		return
	_t += dt
	var foco: Vector3 = main._foco()
	var z_frente: float = main.defesa.z_horda
	var dist := foco.z - z_frente
	var ver := dist < VISIVEL_ATE and dist > -50.0
	visible = ver
	# mantém o chão carregado debaixo da frente da horda quando ela está perto
	var extra := 0
	if dist < 700.0 and dist > -50.0:
		extra = clampi(int(ceil((dist + 60.0) / WorldGen.TAM)) - WorldGen.ATRAS, 0, 6)
	if extra != main.mundo.atras_extra:
		main.mundo.atras_extra = extra
		main.mundo.atualizar(foco)
	_som(dist)
	if not ver:
		return
	_mat.set_shader_parameter("tempo", _t)
	(_poeira.material_override as ShaderMaterial).set_shader_parameter("tempo", _t)
	# a frente anda sozinha entre as atualizações da Defesa (que avança em saltos de tempo)
	if absf(z_frente - _z_feito) > 2.0:
		_montar(z_frente)

func _montar(z_frente: float) -> void:
	_z_feito = z_frente
	var w: WorldGen = main.mundo
	var mm := _mm.multimesh
	for i in N:
		var b: Array = _base[i]
		var z: float = z_frente - b[1]
		var p := w.ponto_estrada(z, b[0])
		var y := w.altura(p.x, p.z)
		if absf(b[0]) < WorldGen.LARG_ESTRADA * 0.5 + 0.5:
			y = maxf(y, w.elevacao(z))
		var d := w.direcao(z)
		var ang: float = atan2(d.x, d.z) + b[3]
		var t := Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * b[2]), Vector3(p.x, y, p.z))
		mm.set_instance_transform(i, t)
	var pm := _poeira.multimesh
	for i in N_POEIRA:
		var h1 := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(i * 78.233) * 12345.678, 1.0)
		var atras := 30.0 + h1 * PROFUNDIDADE
		var lat := (h2 * 2.0 - 1.0) * (18.0 + atras * 0.22)
		var p := w.ponto_estrada(z_frente - atras, lat)
		var tam := 18.0 + atras * 0.1 + h2 * 22.0
		p.y = w.altura(p.x, p.z) + tam * (0.25 + h1 * 0.35)
		pm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(tam * 1.4, tam * 0.75, 1)), p))

## Coro de gemidos: some de longe, enche a cabeça quando ela está a poucas centenas de metros.
func _som(dist: float) -> void:
	var vol := -80.0
	if dist < 2200.0 and dist > -50.0:
		var perto := clampf(1.0 - (dist - 120.0) / 2080.0, 0.0, 1.0)
		vol = lerpf(-38.0, -2.0, pow(perto, 1.6))
	Som.loop("horda", vol, 1.0, "Ambiente")
