class_name Humanoid
extends Node3D
## Corpo humano montado por partes, com articulações animáveis.
## O personagem olha para +Z.

@export var pele := Color(0.72, 0.52, 0.4)
@export var camisa := Color(0.16, 0.18, 0.17)
@export var calca := Color(0.2, 0.19, 0.16)
@export var bota := Color(0.12, 0.09, 0.07)
@export var zumbi := false
@export var com_mochila := false
@export var com_bone := false
@export var arma := ""  # "", "facao", "rifle", "chave"
@export var chapeu := false     # chapéu de palha
@export var jaleco := false     # avental branco com cruz
@export var semente := 0

var quadril_e: Node3D
var quadril_d: Node3D
var joelho_e: Node3D
var joelho_d: Node3D
var ombro_e: Node3D
var ombro_d: Node3D
var cotovelo_e: Node3D
var cotovelo_d: Node3D
var tronco: Node3D
var cabeca: Node3D

func _ready() -> void:
	construir()

func construir() -> void:
	for c in get_children():
		c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var m_pele := B.mat(pele, 0.7)
	var m_camisa := B.mat(camisa, 0.9)
	var m_calca := B.mat(calca, 0.9)
	var m_bota := B.mat(bota, 0.7)

	# pernas
	quadril_e = _junta(self, Vector3(-0.1, 0.95, 0))
	quadril_d = _junta(self, Vector3(0.1, 0.95, 0))
	for q in [quadril_e, quadril_d]:
		B.capsule(q, 0.085, 0.5, Vector3(0, -0.22, 0), m_calca)
		var j := _junta(q, Vector3(0, -0.45, 0))
		B.capsule(j, 0.07, 0.48, Vector3(0, -0.22, 0), m_calca)
		B.box(j, Vector3(0.13, 0.12, 0.26), Vector3(0, -0.44, 0.04), m_bota)
		if q == quadril_e:
			joelho_e = j
		else:
			joelho_d = j

	# tronco
	tronco = _junta(self, Vector3(0, 0.95, 0))
	B.box(tronco, Vector3(0.34, 0.12, 0.2), Vector3(0, 0.03, 0), m_calca)
	B.box(tronco, Vector3(0.35, 0.04, 0.21), Vector3(0, 0.1, 0), B.mat(Color(0.08, 0.06, 0.05), 0.6))  # cinto
	var peito := B.capsule(tronco, 0.19, 0.62, Vector3(0, 0.33, 0), m_camisa)
	peito.scale = Vector3(1.0, 1.0, 0.68)
	B.capsule(tronco, 0.06, 0.12, Vector3(0, 0.62, 0), m_pele)  # pescoço

	cabeca = _junta(tronco, Vector3(0, 0.66, 0))
	var cr := B.sphere(cabeca, 0.11, Vector3(0, 0.1, 0.0), m_pele, Vector3(0.9, 1.08, 1.0))
	B.sphere(cabeca, 0.035, Vector3(0, 0.08, 0.1), m_pele)  # nariz
	if zumbi:
		B.sphere(cabeca, 0.02, Vector3(-0.04, 0.12, 0.095), B.emissive(Color(0.8, 0.75, 0.5), 0.3))
		B.sphere(cabeca, 0.02, Vector3(0.04, 0.12, 0.095), B.emissive(Color(0.8, 0.75, 0.5), 0.3))
		B.box(cabeca, Vector3(0.08, 0.025, 0.02), Vector3(0, 0.03, 0.1), B.mat(Color(0.25, 0.05, 0.04), 0.9))
		B.sphere(cabeca, 0.1, Vector3(0, 0.16, -0.02), B.mat(Color(0.12, 0.1, 0.08), 1.0), Vector3(0.95, 0.6, 1.0))
	else:
		B.sphere(cabeca, 0.105, Vector3(0, 0.15, -0.015), B.mat(Color(0.1, 0.07, 0.05), 1.0), Vector3(0.95, 0.7, 1.0))
		B.box(cabeca, Vector3(0.17, 0.08, 0.06), Vector3(0, 0.03, 0.07), B.mat(Color(0.15, 0.1, 0.07), 1.0))  # barba
	if com_bone:
		var bone := B.mat(Color(0.12, 0.13, 0.11), 0.9)
		B.sphere(cabeca, 0.118, Vector3(0, 0.16, -0.01), bone, Vector3(1.0, 0.65, 1.05))
		B.box(cabeca, Vector3(0.18, 0.02, 0.12), Vector3(0, 0.15, 0.13), bone, Vector3(-10, 0, 0))

	# braços
	ombro_e = _junta(tronco, Vector3(-0.23, 0.53, 0))
	ombro_d = _junta(tronco, Vector3(0.23, 0.53, 0))
	for o in [ombro_e, ombro_d]:
		B.capsule(o, 0.065, 0.36, Vector3(0, -0.15, 0), m_camisa)
		var c := _junta(o, Vector3(0, -0.3, 0))
		B.capsule(c, 0.055, 0.32, Vector3(0, -0.13, 0), m_camisa if not zumbi else m_pele)
		B.sphere(c, 0.05, Vector3(0, -0.31, 0.01), m_pele, Vector3(0.8, 1.1, 1.0))
		if o == ombro_e:
			cotovelo_e = c
		else:
			cotovelo_d = c

	if zumbi:
		# rasgos e sangue
		var sangue := B.mat(Color(0.22, 0.04, 0.03), 0.6)
		for i in 4:
			var p := Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.15, 0.5), 0.13 * (1 if rng.randf() > 0.5 else -1))
			B.box(tronco, Vector3(rng.randf_range(0.05, 0.12), rng.randf_range(0.04, 0.15), 0.01), p, sangue)

	if chapeu:
		var palha := B.mat(Color(0.78, 0.66, 0.4), 0.95)
		B.cyl(cabeca, 0.24, 0.02, Vector3(0, 0.17, 0), palha, Vector3.ZERO, 16)
		B.cyl(cabeca, 0.11, 0.11, Vector3(0, 0.23, 0), palha, Vector3.ZERO, 12, 0.095)
		B.cyl(cabeca, 0.112, 0.025, Vector3(0, 0.19, 0), B.mat(Color(0.35, 0.18, 0.1), 0.8), Vector3.ZERO, 12)
	if jaleco:
		var branco := B.mat(Color(0.88, 0.88, 0.85), 0.85)
		var av := B.capsule(tronco, 0.2, 0.7, Vector3(0, 0.28, 0), branco)
		av.scale = Vector3(1.03, 1.0, 0.71)
		B.box(tronco, Vector3(0.09, 0.025, 0.01), Vector3(0.09, 0.45, 0.145), B.mat(Color(0.75, 0.08, 0.06), 0.6))
		B.box(tronco, Vector3(0.025, 0.09, 0.01), Vector3(0.09, 0.45, 0.145), B.mat(Color(0.75, 0.08, 0.06), 0.6))
	if com_mochila:
		_mochila()
	if arma == "facao":
		var mao := cotovelo_d
		B.cyl(mao, 0.018, 0.13, Vector3(0, -0.32, 0.03), B.mat(Color(0.08, 0.06, 0.05), 0.8), Vector3(90, 0, 0), 6)
		B.box(mao, Vector3(0.008, 0.06, 0.45), Vector3(0, -0.33, 0.32), B.mat(Color(0.55, 0.55, 0.55), 0.3, 0.9))
	elif arma == "chave":
		var mao := cotovelo_d
		B.box(mao, Vector3(0.03, 0.02, 0.3), Vector3(0, -0.32, 0.12), B.mat(Color(0.6, 0.6, 0.62), 0.3, 0.9))
		B.box(mao, Vector3(0.07, 0.025, 0.05), Vector3(0, -0.32, 0.28), B.mat(Color(0.6, 0.6, 0.62), 0.3, 0.9))
	elif arma == "rifle":
		# rifle preso à mão direita, apontando para frente
		var mao := cotovelo_d
		var rf := Node3D.new()
		rf.name = "Rifle"
		rf.position = Vector3(0, -0.3, 0.05)
		mao.add_child(rf)
		var preto := B.mat(Color(0.07, 0.07, 0.07), 0.5, 0.6)
		var madeira := B.mat(Color(0.35, 0.2, 0.1), 0.7)
		B.box(rf, Vector3(0.05, 0.07, 0.42), Vector3(0, 0, 0.05), madeira)
		B.box(rf, Vector3(0.045, 0.12, 0.2), Vector3(0, -0.04, -0.22), madeira)
		B.cyl(rf, 0.013, 0.55, Vector3(0, 0.03, 0.5), preto, Vector3(90, 0, 0), 6)
		B.box(rf, Vector3(0.035, 0.05, 0.16), Vector3(0, 0.065, 0.12), preto)
		var cano := Node3D.new()
		cano.name = "Boca"
		cano.position = Vector3(0, 0.03, 0.8)
		rf.add_child(cano)

	_arma_extra()
	if zumbi:
		pose_zumbi(rng.randf() * TAU)
	else:
		pose_caminhada(0.0, 0.0)

func _mochila() -> void:
	var t := tronco
	var verde := B.mat(Color(0.2, 0.23, 0.16), 0.95)
	var escuro := B.mat(Color(0.12, 0.13, 0.1), 0.9)
	B.box(t, Vector3(0.36, 0.52, 0.22), Vector3(0, 0.4, -0.23), verde)
	B.box(t, Vector3(0.3, 0.2, 0.08), Vector3(0, 0.3, -0.37), escuro)
	B.box(t, Vector3(0.38, 0.1, 0.24), Vector3(0, 0.68, -0.22), escuro)
	for s in [-1.0, 1.0]:
		B.box(t, Vector3(0.08, 0.22, 0.14), Vector3(s * 0.22, 0.3, -0.23), escuro)
		B.box(t, Vector3(0.05, 0.5, 0.02), Vector3(s * 0.12, 0.4, 0.12), escuro)  # alças
	# saco de dormir enrolado
	B.cyl(t, 0.1, 0.44, Vector3(0, 0.08, -0.25), B.mat(Color(0.28, 0.27, 0.2), 0.95), Vector3(0, 0, 90), 12)
	# kit médico e cantil
	B.box(t, Vector3(0.14, 0.12, 0.06), Vector3(-0.2, 0.06, -0.12), B.mat(Color(0.65, 0.08, 0.06), 0.7))
	B.cyl(t, 0.045, 0.2, Vector3(0.23, 0.1, -0.05), B.mat(Color(0.3, 0.32, 0.25), 0.6, 0.3), Vector3.ZERO, 10)

func _junta(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

## Pose de caminhada. fase em radianos, intensidade 0..1.
func pose_caminhada(fase: float, intensidade: float) -> void:
	var a := sin(fase) * 0.6 * intensidade
	quadril_e.rotation.x = a
	quadril_d.rotation.x = -a
	joelho_e.rotation.x = maxf(0.0, -sin(fase - 0.6)) * 0.9 * intensidade
	joelho_d.rotation.x = maxf(0.0, sin(fase - 0.6)) * 0.9 * intensidade
	ombro_e.rotation.x = -a * 0.7
	ombro_d.rotation.x = a * 0.5 - (0.25 if arma != "" else 0.0)
	tronco.rotation.y = 0.0
	tronco.rotation.z = 0.0
	quadril_e.position.y = 0.95
	quadril_d.position.y = 0.95
	cabeca.rotation = Vector3.ZERO
	cotovelo_e.rotation.x = -0.25 - absf(a) * 0.3
	cotovelo_d.rotation.x = -0.35 if arma != "" else -0.25
	ombro_e.rotation.z = -0.08
	ombro_d.rotation.z = 0.08
	tronco.rotation.x = 0.06 * intensidade
	tronco.position.y = 0.95 - absf(cos(fase)) * 0.03 * intensidade

func pose_zumbi(fase: float) -> void:
	var a := sin(fase) * 0.3
	quadril_e.rotation.x = a
	quadril_d.rotation.x = -a
	joelho_e.rotation.x = 0.2
	joelho_d.rotation.x = 0.35
	tronco.rotation.x = 0.28
	tronco.rotation.z = sin(fase * 1.7) * 0.12
	ombro_e.rotation.x = -1.55 + sin(fase) * 0.2
	ombro_d.rotation.x = -1.25 + cos(fase) * 0.3
	ombro_e.rotation.z = -0.12
	ombro_d.rotation.z = 0.15
	cotovelo_e.rotation.x = -0.3
	cotovelo_d.rotation.x = -0.2
	cabeca.rotation.z = 0.35 * sin(fase * 2.3)
	cabeca.rotation.x = 0.2

## Arma apontada (rifle): os dois braços para frente.
func pose_mirar(k := 1.0) -> void:
	ombro_d.rotation.x = lerpf(ombro_d.rotation.x, -1.45, k)
	ombro_d.rotation.z = lerpf(ombro_d.rotation.z, -0.15, k)
	cotovelo_d.rotation.x = lerpf(cotovelo_d.rotation.x, -0.15, k)
	ombro_e.rotation.x = lerpf(ombro_e.rotation.x, -1.3, k)
	ombro_e.rotation.z = lerpf(ombro_e.rotation.z, 0.55, k)
	cotovelo_e.rotation.x = lerpf(cotovelo_e.rotation.x, -0.5, k)
	var rf := cotovelo_d.get_node_or_null("Rifle")
	if rf == null:
		rf = cotovelo_d.get_node_or_null("Arma")
	if rf:
		rf.rotation.x = lerpf(0.0, 1.45 - 0.15, k)

## Ajoelhado mexendo em algo (consertando, plantando).
func pose_trabalhar(fase: float) -> void:
	pose_caminhada(0.0, 0.0)
	quadril_e.rotation.x = -1.4
	joelho_e.rotation.x = 1.5
	quadril_d.rotation.x = -0.2
	joelho_d.rotation.x = 1.9
	quadril_e.position.y = 0.55
	quadril_d.position.y = 0.55
	tronco.position.y = 0.55
	tronco.rotation.x = 0.45
	ombro_d.rotation.x = -1.0 + sin(fase * 3.0) * 0.35
	ombro_e.rotation.x = -0.8
	cotovelo_d.rotation.x = -0.6
	cotovelo_e.rotation.x = -0.5
	cabeca.rotation.x = 0.35

## Deitado de costas (dormindo numa cama).
func pose_dormir() -> void:
	pose_caminhada(0.0, 0.0)
	ombro_e.rotation.x = -0.1
	ombro_d.rotation.x = -0.1
	ombro_e.rotation.z = -0.25
	ombro_d.rotation.z = 0.25
	cabeca.rotation.y = 0.4

## Sentado (no chão ou numa cadeira baixa).
func pose_sentar() -> void:
	pose_caminhada(0.0, 0.0)
	quadril_e.rotation.x = -1.5
	quadril_d.rotation.x = -1.5
	joelho_e.rotation.x = 1.5
	joelho_d.rotation.x = 1.5
	quadril_e.position.y = 0.48
	quadril_d.position.y = 0.48
	tronco.position.y = 0.48
	tronco.rotation.x = 0.1
	ombro_e.rotation.x = -0.6
	ombro_d.rotation.x = -0.6
	cotovelo_e.rotation.x = -0.9
	cotovelo_d.rotation.x = -0.9

func _resetar_altura() -> void:
	quadril_e.position.y = 0.95
	quadril_d.position.y = 0.95
	tronco.position.y = 0.95

## Armas além de facão/chave/rifle (o jogador troca na barra rápida).
func _arma_extra() -> void:
	var mao := cotovelo_d
	var preto := B.mat(Color(0.07, 0.07, 0.07), 0.45, 0.6)
	var aco := B.mat(Color(0.5, 0.5, 0.52), 0.3, 0.9)
	var madeira := B.mat(Color(0.38, 0.22, 0.11), 0.7)
	match arma:
		"pe_de_cabra":
			var ver := B.mat(Color(0.55, 0.12, 0.08), 0.5, 0.6)
			B.cyl(mao, 0.016, 0.62, Vector3(0, -0.32, 0.22), ver, Vector3(90, 0, 0), 6)
			B.box(mao, Vector3(0.02, 0.09, 0.03), Vector3(0, -0.28, 0.53), ver, Vector3(-30, 0, 0))
		"taco":
			B.cyl(mao, 0.025, 0.75, Vector3(0, -0.32, 0.3), madeira, Vector3(90, 0, 0), 8, 0.045)
			for q in 6:
				B.box(mao, Vector3(0.006, 0.08, 0.006), Vector3(0, -0.32, 0.45 + q * 0.04), aco, Vector3(0, 0, q * 60))
		"machado":
			B.cyl(mao, 0.02, 0.7, Vector3(0, -0.32, 0.26), madeira, Vector3(90, 0, 0), 6)
			B.box(mao, Vector3(0.015, 0.2, 0.16), Vector3(0, -0.24, 0.58), aco)
		"pistola", "espingarda", "besta":
			var rf := Node3D.new()
			rf.name = "Arma"
			rf.position = Vector3(0, -0.3, 0.05)
			mao.add_child(rf)
			var boca := Node3D.new()
			boca.name = "Boca"
			rf.add_child(boca)
			if arma == "pistola":
				B.box(rf, Vector3(0.035, 0.1, 0.05), Vector3(0, -0.03, 0.02), preto, Vector3(-15, 0, 0))
				B.box(rf, Vector3(0.035, 0.045, 0.2), Vector3(0, 0.03, 0.08), preto)
				boca.position = Vector3(0, 0.03, 0.19)
			elif arma == "espingarda":
				B.box(rf, Vector3(0.05, 0.1, 0.3), Vector3(0, -0.02, -0.15), madeira)
				B.box(rf, Vector3(0.05, 0.06, 0.16), Vector3(0, 0.02, 0.08), preto)
				for sx in [-0.013, 0.013]:
					B.cyl(rf, 0.013, 0.6, Vector3(sx, 0.04, 0.45), preto, Vector3(90, 0, 0), 6)
				B.box(rf, Vector3(0.05, 0.035, 0.22), Vector3(0, 0.0, 0.32), madeira)
				boca.position = Vector3(0, 0.04, 0.76)
			else:
				B.box(rf, Vector3(0.05, 0.07, 0.55), Vector3(0, 0, 0.12), madeira)
				B.box(rf, Vector3(0.05, 0.1, 0.12), Vector3(0, -0.05, -0.12), madeira)
				var arco := B.box(rf, Vector3(0.62, 0.03, 0.04), Vector3(0, 0.02, 0.38), preto)
				B.box(rf, Vector3(0.6, 0.004, 0.004), Vector3(0, 0.04, 0.3), B.mat(Color(0.8, 0.78, 0.7), 0.8))
				B.cyl(rf, 0.008, 0.36, Vector3(0, 0.05, 0.25), aco, Vector3(90, 0, 0), 4)
				boca.position = Vector3(0, 0.05, 0.45)
