class_name Fogo
extends Node3D
## Fogo de verdade (partículas): línguas de chama que sobem e se apagam, núcleo
## claro, brasas que voam, fumaça que sobe e se espalha, carvão incandescente e
## luz tremulando. Barato (CPUParticles3D), funciona no renderizador de compatibilidade.

@export var tamanho := 1.0       # 1 = fogueira de acampamento
@export var com_fumaca := true
@export var com_luz := true

var _luz: OmniLight3D
var _brasa_mat: StandardMaterial3D
var _t := randf() * 10.0

static var _tex_chama: Texture2D
static var _tex_fumaca: Texture2D

func _ready() -> void:
	_texturas()
	var s := tamanho
	# carvão em brasa no meio (pulsa)
	_brasa_mat = StandardMaterial3D.new()
	_brasa_mat.albedo_color = Color(0.12, 0.05, 0.03)
	_brasa_mat.emission_enabled = true
	_brasa_mat.emission = Color(1.0, 0.32, 0.06)
	_brasa_mat.emission_energy_multiplier = 2.5
	_brasa_mat.roughness = 1.0
	var r := RandomNumberGenerator.new()
	r.seed = int(global_position.x * 7.0 + global_position.z * 13.0)
	for i in 9:
		var a := r.randf() * TAU
		var d := r.randf_range(0.0, 0.32) * s
		B.sphere(self, r.randf_range(0.05, 0.09) * s, Vector3(cos(a) * d, 0.04 * s, sin(a) * d), _brasa_mat, Vector3(1.3, 0.6, 1.1), 6)
	# chamas: duas camadas (externa laranja, núcleo amarelo-claro)
	add_child(_chamas(s, 28, 0.55, Color(1.0, 0.55, 0.12), Color(0.9, 0.18, 0.03), 0.36, 0.75))
	add_child(_chamas(s, 14, 0.38, Color(1.0, 0.92, 0.6), Color(1.0, 0.5, 0.1), 0.18, 0.5))
	add_child(_brasas(s))
	if com_fumaca:
		add_child(_fumaca(s))
	if com_luz:
		_luz = OmniLight3D.new()
		_luz.light_color = Color(1.0, 0.56, 0.24)
		_luz.light_energy = 2.6
		_luz.omni_range = 11.0 * s
		_luz.shadow_enabled = true
		_luz.position = Vector3(0, 0.9 * s, 0)
		add_child(_luz)

static func _texturas() -> void:
	if _tex_chama:
		return
	# chama: gota macia (mais estreita em cima)
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var u := (x - 31.5) / 32.0
			var v := (y - 31.5) / 32.0
			var larg := lerpf(0.45, 1.0, clampf((v + 1.0) * 0.5, 0.0, 1.0))   # afina para cima
			var d := sqrt(pow(u / larg, 2.0) + v * v)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex_chama = ImageTexture.create_from_image(img)
	# fumaça: nuvem com borda irregular
	var im2 := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.frequency = 0.09
	for y in 64:
		for x in 64:
			var u := (x - 31.5) / 32.0
			var v := (y - 31.5) / 32.0
			var d := sqrt(u * u + v * v) + n.get_noise_2d(x, y) * 0.35
			var a := clampf(1.0 - d, 0.0, 1.0)
			im2.set_pixel(x, y, Color(1, 1, 1, a * a))
	_tex_fumaca = ImageTexture.create_from_image(im2)

static func _mat_part(tex: Texture2D, aditivo: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if aditivo else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m

func _quad(t: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(t, t * 1.35)
	return q

func _chamas(s: float, n: int, vida: float, cor_a: Color, cor_b: Color, raio: float, tam: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = vida
	p.preprocess = 1.0
	p.randomness = 0.6
	p.local_coords = false
	p.mesh = _quad(tam * s)
	p.material_override = _mat_part(_tex_chama, true)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = raio * s
	p.position = Vector3(0, 0.15 * s, 0)
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.6 * s, 0)
	p.initial_velocity_min = 0.5 * s
	p.initial_velocity_max = 1.1 * s
	p.angle_min = -25.0
	p.angle_max = 25.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var cs := Curve.new()
	cs.add_point(Vector2(0, 0.55))
	cs.add_point(Vector2(0.3, 1.0))
	cs.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = cs
	var g := Gradient.new()
	g.set_color(0, Color(cor_a.r, cor_a.g, cor_a.b, 0.0))
	g.set_color(1, Color(cor_b.r * 0.4, cor_b.g * 0.2, 0.0, 0.0))
	g.add_point(0.12, Color(cor_a.r, cor_a.g, cor_a.b, 0.95))
	g.add_point(0.6, Color(cor_b.r, cor_b.g, cor_b.b, 0.6))
	p.color_ramp = g
	return p

func _brasas(s: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 2.2
	p.preprocess = 2.0
	p.randomness = 0.8
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035) * s
	p.mesh = q
	p.material_override = _mat_part(_tex_chama, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25 * s
	p.position = Vector3(0, 0.3 * s, 0)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.gravity = Vector3(0.25, 0.7, 0.1)
	p.initial_velocity_min = 0.8 * s
	p.initial_velocity_max = 2.0 * s
	p.tangential_accel_min = -1.5
	p.tangential_accel_max = 1.5
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	g.set_color(1, Color(0.9, 0.2, 0.0, 0.0))
	p.color_ramp = g
	return p

func _fumaca(s: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.randomness = 0.5
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9) * s
	p.mesh = q
	var m := _mat_part(_tex_fumaca, false)
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2 * s
	p.position = Vector3(0, 1.0 * s, 0)
	p.direction = Vector3.UP
	p.spread = 10.0
	p.gravity = Vector3(0.18, 0.25, 0.05)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -20.0
	p.angular_velocity_max = 20.0
	var cs := Curve.new()
	cs.add_point(Vector2(0, 0.4))
	cs.add_point(Vector2(1, 2.6))
	p.scale_amount_curve = cs
	var g := Gradient.new()
	g.set_color(0, Color(0.2, 0.18, 0.16, 0.0))
	g.set_color(1, Color(0.45, 0.44, 0.43, 0.0))
	g.add_point(0.15, Color(0.22, 0.2, 0.18, 0.35))
	g.add_point(0.6, Color(0.38, 0.37, 0.36, 0.18))
	p.color_ramp = g
	return p

func _process(dt: float) -> void:
	_t += dt
	var k := 0.5 * sin(_t * 11.0) + 0.3 * sin(_t * 27.3) + 0.2 * sin(_t * 5.1)
	if _luz:
		_luz.light_energy = 2.5 + 0.45 * k
		_luz.position = Vector3(0.04 * sin(_t * 7.0), 0.9 * tamanho + 0.05 * k, 0.04 * cos(_t * 6.1))
	if _brasa_mat:
		_brasa_mat.emission_energy_multiplier = 2.3 + 0.8 * (0.5 + 0.5 * sin(_t * 1.7))
