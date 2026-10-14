class_name Comboio
extends Node3D
## Controle da picape puxando o trailer (modelo arcade, sem física rígida).
## A picape segue um modelo de bicicleta; o trailer é arrastado pelo engate.

signal motor_ligado(ligado: bool)

const ENTRE_EIXOS := 3.4

var mundo: WorldGen
var picape: Pickup
var trailer: Trailer
## Tudo o que está engatado, em ordem: trailer primeiro, depois os reboques.
var cadeia: Array[Node3D] = []
var eixos: Array[Vector3] = []
var dirigindo := false

var velocidade := 0.0          # m/s, positivo = para frente
var esterco := 0.0             # ângulo do volante (-1..1)
var yaw := 0.0                 # direção da picape
var pos := Vector3.ZERO        # origem da picape
var diesel := 54.0
var odometro := 0.0
var fora_da_estrada := false
var na_terra := false        # numa estrada de terra
var na_agua := false
var agua_no_motor := false
var bloqueado := false       # bateu numa barreira
var aderencia_clima := 1.0   # chuva/neve deixam a pista lisa (Clima)
var temperatura := 0.3     # 0 frio .. 1 limite .. acima = superaquecido
var superaquecido := false
var primeira_pessoa := true
var cam_cabine: Camera3D
var _olhar_yaw := 0.0
var _olhar_pitch := -0.05

# câmera de perseguição
var cam_pivo: Node3D
var camera: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.18
var cam_dist := 11.0

func iniciar(m: WorldGen, p: Pickup, t: Trailer) -> void:
	mundo = m
	picape = p
	trailer = t
	pos = picape.position
	yaw = picape.rotation.y
	cadeia = [trailer]
	eixos = [trailer.global_transform * Vector3(0, 0, trailer.eixo_z())]
	cam_pivo = Node3D.new()
	add_child(cam_pivo)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.far = 2500.0
	cam_pivo.add_child(camera)
	cam_cabine = Camera3D.new()
	cam_cabine.fov = 72.0
	cam_cabine.near = 0.03
	cam_cabine.far = 2500.0
	add_child(cam_cabine)

func camera_ativa() -> Camera3D:
	return cam_cabine if primeira_pessoa else camera

func alternar_camera() -> void:
	primeira_pessoa = not primeira_pessoa
	picape.modo_cabine = primeira_pessoa and dirigindo
	picape.reconstruir()
	camera_ativa().current = true

## Peso só do que está sendo rebocado (sem a picape).
func peso_rebocado() -> float:
	var p := 0.0
	for el in cadeia:
		p += el.peso_total()
	return p

## Rebocado / capacidade (1.0 = no limite).
func razao_carga() -> float:
	return peso_rebocado() / maxf(picape.capacidade_reboque(), 1.0)

func pode_engatar(r: Node3D) -> bool:
	return peso_rebocado() + r.peso_total() <= picape.limite_engate()
## Posiciona o conjunto num ponto da estrada (usado no começo e nos prints).
## angulo: quanto cada engate dobra em relação ao anterior.
func posicionar(z: float, lateral: float, angulo := 0.0) -> void:
	var d := mundo.direcao(z)
	posicionar_livre(mundo.ponto_estrada(z, lateral), atan2(d.x, d.z), angulo)

## Posiciona em qualquer ponto (estradas de terra, lugares), com o comboio reto atrás.
func posicionar_livre(p: Vector3, yaw_novo: float, angulo := 0.0) -> void:
	pos = p
	yaw = yaw_novo
	var engate := pos + Vector3(sin(yaw), 0, cos(yaw)) * picape.engate().z
	var ty := yaw
	eixos.clear()
	for el in cadeia:
		ty += angulo
		var dir := Vector3(sin(ty), 0, cos(ty))
		var eixo: Vector3 = engate - dir * (el.engate_frente_z() - el.eixo_z())
		eixos.append(eixo)
		var centro: Vector3 = eixo - dir * el.eixo_z()
		var tras: Vector3 = el.engate_tras()
		engate = centro + dir * tras.z
	_aplicar(0.0)

func tanque() -> float:
	return picape.tanque_litros()

func engatar(r: Node3D, forcar := false) -> bool:
	if not forcar and not pode_engatar(r):
		return false
	var ult := cadeia[cadeia.size() - 1]
	var engate: Vector3 = ult.global_transform * ult.engate_tras()
	var dir := (Vector3(engate.x, 0, engate.z) - Vector3(r.global_position.x, 0, r.global_position.z)).normalized()
	cadeia.append(r)
	eixos.append(Vector3(engate.x, 0, engate.z) - dir * (r.engate_frente_z() - r.eixo_z()))
	_aplicar(0.0)
	return true

func desengatar(indice: int) -> Node3D:
	if indice <= 0 or indice >= cadeia.size():
		return null
	var r := cadeia[indice]
	cadeia.remove_at(indice)
	eixos.remove_at(indice)
	_aplicar(0.0)
	return r

## Ponto do último engate livre (onde um novo reboque pode ser preso).
func engate_livre() -> Vector3:
	var ult := cadeia[cadeia.size() - 1]
	return ult.global_transform * ult.engate_tras()

func peso_total() -> float:
	var p := picape.peso_total() + diesel * 0.85
	for el in cadeia:
		p += el.peso_total()
	return p

func velocidade_maxima() -> float:
	var vmax := 30.0 + picape.nivel("motor") * 1.5 - (peso_total() - 3400.0) * 0.002
	var rz := razao_carga()
	if rz > 1.0:
		vmax *= clampf(1.0 - (rz - 1.0) * 1.8, 0.12, 1.0)
	if superaquecido:
		vmax = minf(vmax, 6.0)
	if fora_da_estrada:
		vmax = minf(vmax, 7.0 + picape.aderencia_fora() * 6.0)
	elif na_terra:
		vmax = minf(vmax, 11.0 + picape.aderencia_fora() * 3.0)
	if na_agua:
		vmax = minf(vmax, 3.5)
	var cc = mundo.get_parent().get("combate_comboio") if mundo else null
	if cc:
		vmax *= cc.fator_velocidade()
	var ex = mundo.get_parent().get("comboio_extra") if mundo else null
	if ex:
		vmax = minf(vmax, ex.limite_velocidade())
	return clampf(vmax, 3.0, 32.0)

func _unhandled_input(e: InputEvent) -> void:
	if not dirigindo:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and primeira_pessoa:
		_olhar_yaw = clampf(_olhar_yaw - e.relative.x * 0.003, -2.2, 2.2)
		_olhar_pitch = clampf(_olhar_pitch - e.relative.y * 0.003, -0.7, 0.5)
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= e.relative.x * 0.003
		cam_pitch = clampf(cam_pitch - e.relative.y * 0.003, -0.8, 0.1)
	if e is InputEventMouseButton and e.pressed:
		if primeira_pessoa:
			return
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(6.0, cam_dist - 0.8)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(20.0, cam_dist + 0.8)

func _physics_process(dt: float) -> void:
	if not mundo:
		return
	var acel := 0.0
	var volante := 0.0
	var freio := false
	if dirigindo:
		acel = Input.get_axis("move_back", "move_forward")
		volante = Input.get_axis("move_right", "move_left")
		freio = Input.is_action_pressed("freio")
	if diesel <= 0.0:
		acel = minf(acel, 0.0) if velocidade > 0.5 else 0.0

	esterco = move_toward(esterco, volante, dt * 2.2)
	var massa := peso_total() / 3400.0
	var forca := 5.5 * picape.forca() / massa
	if superaquecido:
		forca *= 0.4
	_temperatura(dt, absf(acel))
	if acel > 0.0:
		if velocidade < -0.2:
			velocidade = move_toward(velocidade, 0.0, 12.0 * dt * aderencia_clima)
		else:
			velocidade += acel * forca * dt * lerpf(0.65, 1.0, aderencia_clima)
	elif acel < 0.0:
		if velocidade > 0.2:
			velocidade = move_toward(velocidade, 0.0, 12.0 * dt)
		else:
			velocidade = maxf(velocidade + acel * forca * 0.5 * dt, -5.0)
	else:
		var arrasto := 0.6 + (2.0 / picape.aderencia_fora() if fora_da_estrada else 0.0)
		velocidade = move_toward(velocidade, 0.0, arrasto * dt)
	if freio:
		velocidade = move_toward(velocidade, 0.0, (3.0 + 13.0 * pow(aderencia_clima, 1.8)) * dt)
	velocidade = clampf(velocidade, -6.0, velocidade_maxima())
	# em alta velocidade o volante responde menos
	var giro := esterco * lerpf(0.55, 0.16, clampf(absf(velocidade) / 30.0, 0.0, 1.0))
	var ex2 = mundo.get_parent().get("comboio_extra") if mundo else null
	if ex2 and ex2.pneu_furado and absf(velocidade) > 1.0:
		giro += ex2.puxao() * 0.25    # pneu furado puxa para a direita
	giro *= lerpf(0.6, 1.0, aderencia_clima)
	yaw += velocidade * tan(giro) / ENTRE_EIXOS * dt
	# pista lisa: em curva rápida a traseira escorrega (o comboio "abre")
	if aderencia_clima < 0.95 and absf(velocidade) > 11.0 and absf(esterco) > 0.25:
		yaw += esterco * (1.0 - aderencia_clima) * clampf((absf(velocidade) - 11.0) / 14.0, 0.0, 1.0) * 0.5 * dt
		velocidade *= 1.0 - (1.0 - aderencia_clima) * 0.25 * dt
	var frente := Vector3(sin(yaw), 0, cos(yaw))
	var antes := pos
	pos += frente * velocidade * dt
	var ponta := pos + frente * (3.0 if velocidade >= 0.0 else -3.0)
	bloqueado = mundo.bloqueado(ponta)
	if bloqueado:
		pos = antes
		velocidade = 0.0
	odometro += absf(velocidade) * dt
	# água: sem snorkel, entra água no motor
	agua_no_motor = na_agua and picape.nivel("snorkel") < 1 and absf(velocidade) > 0.5
	if agua_no_motor:
		picape.config.motor.condicao = maxf(0.05, picape.config.motor.condicao - 0.03 * dt)

	# consumo: base parado + por metro, crescendo com o peso e fora da estrada
	var por_metro := 0.00011 * (peso_total() / 3400.0) * (1.6 if fora_da_estrada else 1.0) * (1.0 + picape.nivel("turbo") * 0.12)
	diesel = maxf(0.0, diesel - absf(velocidade) * dt * por_metro - (0.0004 * dt if dirigindo else 0.0))

	_aplicar(dt)

## Motor esquenta com carga acima da capacidade, subida e turbo; esfria com o radiador.
func _temperatura(dt: float, pedal: float) -> void:
	var rz := razao_carga()
	var subida := clampf(-picape.rotation.x * 6.0, 0.0, 1.0)
	var alvo := 0.25
	if dirigindo:
		alvo = 0.4 + pedal * (0.35 * rz + 0.25 * subida * rz + 0.08 * picape.nivel("turbo")) - picape.dissipacao() * pedal * 0.6
		if rz > 1.0:
			alvo += (rz - 1.0) * 1.1 * pedal
	var taxa := 0.025 if alvo > temperatura else 0.04
	temperatura = move_toward(temperatura, alvo, taxa * dt)
	if temperatura >= 1.0 and not superaquecido:
		superaquecido = true
	elif superaquecido and temperatura < 0.75:
		superaquecido = false
	if temperatura > 1.0:
		picape.config.motor.condicao = maxf(0.05, picape.config.motor.condicao - 0.004 * dt)

func _aplicar(dt: float) -> void:
	var frente := Vector3(sin(yaw), 0, cos(yaw))
	var fora_principal := absf(pos.x - mundo.centro_x(pos.z)) > WorldGen.LARG_ESTRADA * 0.5 + 1.2
	na_terra = fora_principal and mundo.em_estrada_de_terra(pos)
	fora_da_estrada = fora_principal and not na_terra
	na_agua = mundo.agua_em(pos.x, pos.z) > _chao(pos) + 0.15
	# altura e inclinação pelo chão
	var h_frente := _chao(pos + frente * 1.6)
	var h_tras := _chao(pos - frente * 1.8)
	pos.y = (h_frente + h_tras) * 0.5
	var pitch := atan2(h_tras - h_frente, 3.4)
	var trepida := 0.0
	if (fora_da_estrada or na_terra) and absf(velocidade) > 1.0:
		trepida = sin(odometro * 3.1) * (0.012 if fora_da_estrada else 0.005) * clampf(absf(velocidade) / 8.0, 0.0, 1.0)
	picape.position = pos
	picape.rotation = Vector3(pitch + trepida, yaw, trepida * 0.6)

	# cada engatado é arrastado pelo engate de quem está na frente
	var engate := picape.global_transform * picape.engate()
	var yaw_ant := yaw
	for idx in cadeia.size():
		var el := cadeia[idx]
		var dist: float = el.engate_frente_z() - el.eixo_z()
		var eng_plano := Vector3(engate.x, 0, engate.z)
		var eixo_plano := Vector3(eixos[idx].x, 0, eixos[idx].z)
		var dir_t := eng_plano - eixo_plano
		if dir_t.length() < 0.01:
			dir_t = Vector3(sin(yaw_ant), 0, cos(yaw_ant))
		dir_t = dir_t.normalized()
		var ty := atan2(dir_t.x, dir_t.z)
		var dif := clampf(wrapf(ty - yaw_ant, -PI, PI), -1.3, 1.3)
		ty = yaw_ant + dif
		dir_t = Vector3(sin(ty), 0, cos(ty))
		eixos[idx] = eng_plano - dir_t * dist
		var centro: Vector3 = eixos[idx] - dir_t * el.eixo_z()
		var meio: float = el.comprimento() * 0.45 if el.has_method("comprimento") else 1.5
		var ht_f := _chao(centro + dir_t * meio)
		var ht_t := _chao(centro - dir_t * meio)
		el.position = Vector3(centro.x, (ht_f + ht_t) * 0.5, centro.z)
		el.rotation = Vector3(atan2(ht_t - ht_f, meio * 2.0) + trepida * 0.8, ty, -trepida)
		engate = el.global_transform * el.engate_tras()
		yaw_ant = ty

	# câmera da cabine e volante
	if cam_cabine:
		cam_cabine.global_transform = picape.global_transform * Transform3D(Basis(Vector3.UP, PI + _olhar_yaw) * Basis(Vector3.RIGHT, _olhar_pitch), picape.posicao_assento())
		if dt > 0.0 and absf(velocidade) > 3.0 and absf(_olhar_yaw) < 0.6:
			_olhar_yaw = lerpf(_olhar_yaw, 0.0, dt * 0.5)
	if picape.volante and is_instance_valid(picape.volante):
		picape.volante.rotation = Vector3(deg_to_rad(-62), 0, 0)
		picape.volante.rotate_object_local(Vector3.UP, -esterco * 1.6)
	# câmera
	if cam_pivo:
		cam_pivo.position = pos + Vector3(0, 1.8, 0) - frente * (2.5 + (cadeia.size() - 1) * 2.5)
		var alvo_yaw := yaw + PI + cam_yaw
		cam_pivo.rotation = Vector3(cam_pitch, alvo_yaw, 0)
		camera.position = Vector3(0, 0.8, cam_dist + (cadeia.size() - 1) * 3.0)
		if dt > 0.0 and velocidade > 2.0:
			cam_yaw = lerpf(cam_yaw, 0.0, dt * 0.8)

func _chao(p: Vector3) -> float:
	var d := absf(p.x - mundo.centro_x(p.z))
	if d < WorldGen.LARG_ESTRADA * 0.5 + 0.3:
		return mundo.elevacao(p.z) + 0.06
	if d < 12.0:
		return maxf(mundo.altura(p.x, p.z), mundo.elevacao(p.z) - 0.1)
	return mundo.altura(p.x, p.z)

## Ponto ao lado da porta do motorista (lado esquerdo = +X local).
func porta_motorista() -> Vector3:
	return picape.global_transform * Vector3(1.6, 0, 0.5)

func km_h() -> float:
	return absf(velocidade) * 3.6

func abastecer(litros: float) -> float:
	var cabe := tanque() - diesel
	var usado := minf(cabe, litros)
	diesel += usado
	return usado
