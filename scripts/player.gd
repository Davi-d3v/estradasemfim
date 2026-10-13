class_name Player
extends Node3D
## Sobrevivente em 3ª pessoa: WASD anda, Shift corre, mouse gira a câmera.

@export var velocidade := 2.2
@export var velocidade_corrida := 5.0
@export var sensibilidade := 0.003

var mundo: WorldGen
var corpo: Humanoid
var pivo: Node3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.12
var fase := 0.0
var intensidade := 0.0

# atributos de sobrevivência (0..1)
var vida := 0.85
var sede := 0.45
var fome := 0.62
var estamina := 0.75
var infeccao := 0.0       # 0 saudável .. 1 virou zumbi
var agachado := false
var _t_golpe := 0.0       # animação do golpe (1 -> 0)
var _cd_golpe := 0.0
var _t_dano := 0.0
var predio_atual: Predio = null
var mirando := false
var zoom := 40.0
var _t_flash := 0.0
var _flash_luz: OmniLight3D
var _armadura_nos: Array = []
var _armadura := {}
signal golpeou(origem: Vector3, frente: Vector3)

func _ready() -> void:
	corpo = Humanoid.new()
	corpo.com_mochila = true
	corpo.com_bone = true
	corpo.arma = "facao"
	corpo.camisa = Color(0.24, 0.27, 0.26)
	corpo.calca = Color(0.26, 0.24, 0.2)
	add_child(corpo)
	pivo = Node3D.new()
	pivo.position = Vector3(0, 1.55, 0)
	add_child(pivo)
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.far = 2500.0
	camera.position = Vector3(-0.85, 0.25, -3.3)
	camera.rotation.y = PI
	pivo.add_child(camera)
	camera.current = true

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * sensibilidade
		pitch = clampf(pitch - e.relative.y * sensibilidade, -1.0, 0.6)
	if e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if e.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Animação do golpe (o dano é resolvido no Equipamento).
func golpear(custo := 0.06, uso := false) -> void:
	_t_golpe = 1.0 if not uso else 0.5
	estamina = maxf(0.0, estamina - custo)
	corpo.rotation.y = yaw

func flash_tiro() -> void:
	_t_flash = 0.06
	if _flash_luz == null:
		_flash_luz = OmniLight3D.new()
		_flash_luz.light_color = Color(1.0, 0.8, 0.45)
		_flash_luz.light_energy = 4.0
		_flash_luz.omni_range = 7.0
		add_child(_flash_luz)
	_flash_luz.position = corpo.transform * Vector3(0.25, 1.4, 0.8)
	_flash_luz.visible = true

## Peças de armadura vestidas aparecem no corpo (couro marrom; chapas de metal por cima).
func atualizar_armadura(arm: Dictionary) -> void:
	_armadura = arm
	for n in _armadura_nos:
		if is_instance_valid(n):
			n.queue_free()
	_armadura_nos.clear()
	var couro := Texturas.material("tecido", Color(0.36, 0.24, 0.14), 0.85)
	var metal := Texturas.material("metal", Color(0.42, 0.42, 0.4), 0.5, 0.7)
	for slot in arm:
		var a: Dictionary = arm[slot]
		var ref: int = a.reforco
		match slot:
			"torso":
				var v := B.box(corpo.tronco, Vector3(0.44, 0.5, 0.3), Vector3(0, 0.32, 0.0), couro)
				_armadura_nos.append(v)
				for q in ref:
					_armadura_nos.append(B.box(corpo.tronco, Vector3(0.3, 0.12, 0.02), Vector3(0, 0.45 - q * 0.14, 0.16), metal))
			"cabeca":
				var c := B.sphere(corpo.cabeca, 0.15, Vector3(0, 0.1, -0.01), couro, Vector3(1.05, 1.0, 1.1), 8)
				_armadura_nos.append(c)
				if ref > 0:
					_armadura_nos.append(B.box(corpo.cabeca, Vector3(0.22, 0.04 * ref, 0.2), Vector3(0, 0.22, 0), metal))
			"pernas":
				for q in [corpo.quadril_e, corpo.quadril_d]:
					_armadura_nos.append(B.box(q, Vector3(0.17, 0.42, 0.17), Vector3(0, -0.22, 0), couro))
					if ref > 0:
						_armadura_nos.append(B.box(q.get_child(0) if q.get_child_count() > 0 else q, Vector3(0.12, 0.12 * ref, 0.03), Vector3(0, -0.6, 0.09), metal))
			"bracos":
				for q in [corpo.cotovelo_e, corpo.cotovelo_d]:
					_armadura_nos.append(B.box(q, Vector3(0.11, 0.24, 0.11), Vector3(0, -0.12, 0), couro))
					if ref > 0:
						_armadura_nos.append(B.box(q, Vector3(0.12, 0.08 * ref, 0.03), Vector3(0, -0.12, 0.06), metal))

func levar_dano(d: float) -> void:
	vida = maxf(0.0, vida - d)
	_t_dano = 1.0

func _process(dt: float) -> void:
	pivo.rotation = Vector3(pitch, yaw, 0)
	_cd_golpe = maxf(0.0, _cd_golpe - dt)
	_t_golpe = maxf(0.0, _t_golpe - dt * 3.2)
	_t_dano = maxf(0.0, _t_dano - dt * 1.5)
	agachado = Input.is_action_pressed("agachar")
	_t_flash = maxf(0.0, _t_flash - dt)
	if _flash_luz:
		_flash_luz.visible = _t_flash > 0.0
	var entrada := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var frente := Vector3(sin(yaw), 0, cos(yaw))
	var direita := Vector3(-cos(yaw), 0, sin(yaw))
	var mov := (frente * entrada.y + direita * entrada.x)
	var correndo := Input.is_action_pressed("sprint") and estamina > 0.05 and not agachado
	correndo = correndo and not mirando
	var vel := velocidade_corrida if correndo else (velocidade * 0.5 if agachado else velocidade)
	if mirando:
		vel *= 0.6
	if mov.length() > 0.01:
		mov = mov.normalized()
		var nova := position + mov * vel * dt
		if mundo and mundo.colide(position, nova, 0.28, true):
			var so_x := position + Vector3(mov.x, 0, 0) * vel * dt
			var so_z := position + Vector3(0, 0, mov.z) * vel * dt
			if not mundo.colide(position, so_x, 0.28, true):
				nova = so_x
			elif not mundo.colide(position, so_z, 0.28, true):
				nova = so_z
			else:
				nova = position
		position = nova
		var alvo := atan2(mov.x, mov.z)
		corpo.rotation.y = lerp_angle(corpo.rotation.y, alvo, 10.0 * dt)
		intensidade = move_toward(intensidade, 1.0, dt * 4.0)
		fase += dt * vel * 2.6
		if correndo:
			estamina = maxf(0.0, estamina - dt * 0.08)
	else:
		intensidade = move_toward(intensidade, 0.0, dt * 4.0)
		estamina = minf(1.0, estamina + dt * 0.05)
	corpo.pose_caminhada(fase, intensidade)
	if agachado:
		corpo.tronco.rotation.x = 0.35
		corpo.tronco.position.y = 0.72
		corpo.joelho_e.rotation.x = 1.0
		corpo.joelho_d.rotation.x = 1.0
		corpo.quadril_e.rotation.x -= 0.6
		corpo.quadril_d.rotation.x -= 0.6
		corpo.quadril_e.position.y = 0.72
		corpo.quadril_d.position.y = 0.72
	else:
		corpo.quadril_e.position.y = 0.95
		corpo.quadril_d.position.y = 0.95
	if mirando:
		corpo.rotation.y = lerp_angle(corpo.rotation.y, yaw, minf(1.0, dt * 14.0))
		corpo.pose_mirar(1.0)
		corpo.tronco.rotation.x = -pitch * 0.5
	elif _t_golpe > 0.0:
		# arco do facão: levanta e desce na diagonal
		var k := 1.0 - _t_golpe
		corpo.ombro_d.rotation.x = lerpf(-2.6, 0.2, smoothstep(0.15, 0.7, k))
		corpo.ombro_d.rotation.z = lerpf(0.6, -0.5, smoothstep(0.15, 0.7, k))
		corpo.cotovelo_d.rotation.x = -0.3
		corpo.tronco.rotation.y = lerpf(0.4, -0.35, smoothstep(0.15, 0.7, k))
	else:
		corpo.tronco.rotation.y = 0.0
	# infecção avança sozinha
	if infeccao > 0.0:
		infeccao = minf(1.0, infeccao + dt * 0.0016)
		if infeccao > 0.6:
			vida = maxf(0.0, vida - dt * 0.002)
	if mundo:
		position.y = chao(position)
		_atualizar_predio(dt)

## Dentro de uma construção: câmera mais perto e vista em corte dos andares de cima.
func _atualizar_predio(dt: float) -> void:
	var pr := mundo.estrutura_em(position, -0.2)
	if pr != predio_atual:
		if is_instance_valid(predio_atual):
			predio_atual.corte(-1)
		predio_atual = pr
	# dentro de construções a câmera vai para os olhos (1ª pessoa), como no trailer
	var alvo_cam := Vector3(-0.85, 0.25, -3.3) if not mirando else Vector3(-0.6, 0.12, -1.7)
	camera.fov = lerpf(camera.fov, zoom if mirando else 55.0, minf(1.0, dt * 10.0)) if dt > 0.0 else camera.fov
	pivo.position.y = 1.55
	if pr:
		pr.corte(pr.andar_em(pr.local(position).y))
		alvo_cam = Vector3(0, 0.08, 0.12)
		pivo.position.y = 1.0 if agachado else 1.55
	camera.position = camera.position.lerp(alvo_cam, minf(1.0, dt * 10.0)) if dt > 0.0 else alvo_cam
	corpo.visible = camera.position.length() > 1.0
	camera.near = 0.04 if pr else 0.05

func chao(p: Vector3) -> float:
	var pr := mundo.estrutura_em(p, 0.25) if mundo else null
	if pr:
		return pr.piso(p)
	var d := absf(p.x - mundo.centro_x(p.z))
	if d < WorldGen.LARG_ESTRADA * 0.5 + 0.3:
		return mundo.elevacao(p.z) + 0.06
	if d < 12.0:
		return maxf(mundo.altura(p.x, p.z), mundo.elevacao(p.z) - 0.1)
	return mundo.altura(p.x, p.z)
