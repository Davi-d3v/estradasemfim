class_name Arremesso
extends Node3D
## Garrafa (molotov) ou sinalizador voando. Ao cair: o molotov vira fogo que queima
## quem passar por 9 s; o sinalizador fica aceso fazendo barulho e atrai os zumbis.

var main: Node
var tipo := "molotov"
var velocidade := Vector3.ZERO
var _no_chao := false
var _t := 0.0
var _t_ruido := 0.0
var _luz: OmniLight3D
var _fogo: Node3D

const DURACAO := {"molotov": 9.0, "sinalizador": 40.0}
const RAIO_FOGO := 3.2

func _ready() -> void:
	if tipo == "molotov":
		B.cyl(self, 0.05, 0.24, Vector3.ZERO, B.mat(Color(0.25, 0.45, 0.2), 0.2, 0.0, "garrafa_verde"), Vector3.ZERO, 8)
		B.box(self, Vector3(0.04, 0.12, 0.04), Vector3(0, 0.17, 0), B.emissive(Color(1.0, 0.55, 0.15), 3.0))
	else:
		B.cyl(self, 0.03, 0.25, Vector3.ZERO, B.mat(Color(0.8, 0.12, 0.08), 0.5), Vector3.ZERO, 8)
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.5, 0.2) if tipo == "molotov" else Color(1.0, 0.12, 0.08)
	_luz.light_energy = 0.8
	_luz.omni_range = 3.0
	add_child(_luz)

func _process(dt: float) -> void:
	if not _no_chao:
		velocidade.y -= 9.8 * dt
		global_position += velocidade * dt
		rotation.x += dt * 8.0
		var chao: float = main.jogador.chao(global_position) if main else 0.0
		if global_position.y <= chao + 0.05:
			global_position.y = chao + 0.05
			_cair()
		return
	_t += dt
	_t_ruido -= dt
	var dur: float = DURACAO[tipo]
	if tipo == "molotov":
		_luz.light_energy = 3.5 * (1.0 - _t / dur) + randf_range(-0.4, 0.4)
		if _t_ruido <= 0.0:
			_t_ruido = 0.25
			_queimar(0.25)
	else:
		_luz.light_energy = 5.0 + randf_range(-1.0, 1.0)
		if _t_ruido <= 0.0:
			_t_ruido = 2.0
			main.ruido(global_position, 70.0, "sinalizador")
	if _t >= dur:
		queue_free()

func _cair() -> void:
	_no_chao = true
	rotation = Vector3(0, 0, PI * 0.5 if tipo == "sinalizador" else 0.0)
	if tipo == "molotov":
		for c in get_children():
			if c is MeshInstance3D:
				c.queue_free()
		_fogo = Node3D.new()
		add_child(_fogo)
		var r := RandomNumberGenerator.new()
		r.randomize()
		for i in 14:
			var a := r.randf() * TAU
			var d := sqrt(r.randf()) * RAIO_FOGO
			B.sphere(_fogo, r.randf_range(0.25, 0.5), Vector3(cos(a) * d, 0.3, sin(a) * d), B.emissive(Color(1.0, r.randf_range(0.35, 0.6), 0.1), 4.0), Vector3(1, r.randf_range(1.5, 2.6), 1), 6)
		B.cyl(_fogo, RAIO_FOGO, 0.02, Vector3(0, 0.02, 0), B.mat(Color(0.05, 0.04, 0.03), 1.0, 0.0, "fuligem"), Vector3.ZERO, 16)
		var fu := Apocalipse.fumaca(1.6, 8.0)
		_fogo.add_child(fu)
		_luz.omni_range = 9.0
		_luz.position = Vector3(0, 1.0, 0)
		main.ruido(global_position, 30.0)
	else:
		_luz.omni_range = 14.0
		_luz.position = Vector3(0, 0.4, 0)
		var chama := B.sphere(self, 0.08, Vector3(0, 0.15, 0), B.emissive(Color(1.0, 0.2, 0.1), 6.0), Vector3.ONE, 6)
		main.ruido(global_position, 70.0, "sinalizador")
		# zumbis por perto vão até a luz
		for z in main.mundo.zumbis_vivos:
			if is_instance_valid(z) and z.vivo() and z.global_position.distance_to(global_position) < 60.0 and z.estado != Zumbi.Estado.ATACANDO:
				z.estado = Zumbi.Estado.INVESTIGANDO
				z.alvo_pos = global_position

func _queimar(dt: float) -> void:
	var alvos: Array = []
	alvos.append_array(main.mundo.zumbis_vivos)
	alvos.append_array(main.mundo.animais)
	for a in alvos:
		if is_instance_valid(a) and a.vivo() and Vector2(a.global_position.x - global_position.x, a.global_position.z - global_position.z).length() < RAIO_FOGO:
			a.ferir(26.0 * dt * 4.0, Vector3.ZERO)
			if not a.vivo() and a is Zumbi:
				main.abates += 1
	var j: Node3D = main.jogador
	if j.visible and Vector2(j.global_position.x - global_position.x, j.global_position.z - global_position.z).length() < RAIO_FOGO:
		j.levar_dano(0.05 * dt * 4.0)
		main.hud.dano()
