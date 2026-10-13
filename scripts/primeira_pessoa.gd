class_name PrimeiraPessoa
extends Node3D
## Andar em primeira pessoa dentro de um veículo (trailer ou reboque).
## A posição é guardada no espaço local do veículo, então tudo acompanha
## o veículo mesmo quando ele é reconstruído ou se move.

signal interagiu(id: String)

var veiculo: Node3D
var camera: Camera3D
var pos_local := Vector3.ZERO
var yaw := 0.0       # relativo ao veículo
var pitch := 0.0
var limites := AABB()
var piso := 0.8
var altura_olho := 1.55
var interativos: Array = []   # [{id, nome, pos (local), tecla}]
var foco: Dictionary = {}
var ativo := false
var _fase := 0.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 78.0
	camera.near = 0.03
	camera.far = 2500.0
	add_child(camera)

## Entra num veículo. info vem de veiculo.interior().
func entrar(v: Node3D, info: Dictionary) -> void:
	veiculo = v
	limites = info.limites
	piso = info.piso
	altura_olho = info.get("olho", 1.55)
	interativos = info.interativos
	pos_local = info.inicio
	pos_local.y = piso
	yaw = info.get("yaw", 0.0)
	pitch = -0.1
	ativo = true
	camera.current = true
	_atualizar_camera()

func sair() -> void:
	ativo = false
	foco = {}

func _unhandled_input(e: InputEvent) -> void:
	if not ativo:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.003
		pitch = clampf(pitch - e.relative.y * 0.003, -1.3, 1.2)
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(dt: float) -> void:
	if not ativo or not is_instance_valid(veiculo):
		return
	var entrada := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var frente := Vector3(sin(yaw), 0, cos(yaw))
	var direita := Vector3(-cos(yaw), 0, sin(yaw))
	var mov := frente * entrada.y + direita * entrada.x
	if mov.length() > 0.01:
		pos_local += mov.normalized() * 1.6 * dt
		_fase += dt * 9.0
	pos_local.x = clampf(pos_local.x, limites.position.x, limites.end.x)
	pos_local.z = clampf(pos_local.z, limites.position.z, limites.end.z)
	pos_local.y = piso
	_atualizar_camera()
	_achar_foco()
	if not foco.is_empty() and Input.is_action_just_pressed(foco.get("tecla", "interact")):
		interagiu.emit(foco.id)

func _atualizar_camera() -> void:
	if not is_instance_valid(veiculo):
		return
	var balanço := sin(_fase) * 0.012
	var olho := pos_local + Vector3(0, altura_olho + balanço, 0)
	var base := Basis(Vector3.UP, yaw + PI) * Basis(Vector3.RIGHT, pitch)
	camera.global_transform = veiculo.global_transform * Transform3D(base, olho)

## Escolhe o interativo mais alinhado com a mira, dentro de 2 m.
func _achar_foco() -> void:
	foco = {}
	var olho := pos_local + Vector3(0, altura_olho, 0)
	var dir := (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)) * Vector3(0, 0, 1)
	var melhor := 0.9
	for it in interativos:
		var v: Vector3 = it.pos - olho
		var d := v.length()
		if d > 2.2:
			continue
		var al := v.normalized().dot(dir)
		var nota := al - d * 0.03
		if al > 0.86 and nota > melhor - 0.1:
			if nota > melhor or foco.is_empty():
				melhor = nota
				foco = it

## Aponta a câmera para um interativo (usado nos prints).
func olhar_para(id: String) -> void:
	for it in interativos:
		if it.id == id:
			var v: Vector3 = it.pos - (pos_local + Vector3(0, altura_olho, 0))
			yaw = atan2(v.x, v.z)
			pitch = atan2(v.y, Vector2(v.x, v.z).length())
			_atualizar_camera()
			_achar_foco()
			return
