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
## Modelo pronto (personagem com rosto + animações). Falso = corpo montado por partes.
var modelo := false
var feminino := false
var visual := "civil"          # civil, trabalhador, medico, soldado, idoso, cowboy, cozinheiro, zumbi
var arquivo := ""              # força um visual específico (ex.: "Worker_Female")
var cores := {}                # cores por material (Skin, Shirt, Pants, Hair...)
var sujeira := 0.0
var _m := {}
var _ap: AnimationPlayer
var _loop := ""
var _loop_vel := 1.0
var _oneshot := false
var _oneshot_fim := 0.0
var _travado := false
var _pend := false
var vel_anim := 0.0            # m/s reais (escolhe andar/correr)
var agachado_anim := false
var anim_parado := "Idle"
var mao_d: Node3D
var mao_e: Node3D
var costas: Node3D
var cabeca_a: Node3D
var coxa_e: Node3D
var coxa_d: Node3D
var canela_e: Node3D
var canela_d: Node3D
var braco_e: Node3D
var braco_d: Node3D
var antebraco_e: Node3D
var antebraco_d: Node3D

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
	if Modelos.disponivel():
		_construir_modelo(rng)
		return
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
	if modelo:
		_locomover(intensidade)
		return
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
	if modelo:
		if vel_anim < 0.12:
			loop("Zombie_Idle")
		elif vel_anim < 1.6:
			loop("Zombie_Walk_Fwd", clampf(vel_anim / 0.9, 0.6, 1.8))
		else:
			loop("Zombie_Run_Fwd", clampf(vel_anim / 3.2, 0.7, 1.5))
		return
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
	if modelo:
		loop("Pistol_Aim_Neutral")
		return
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
	if modelo:
		loop("Fixing_Kneeling")
		return
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
	if modelo:
		fixar("IdleToLay", 1.0)
		return
	pose_caminhada(0.0, 0.0)
	ombro_e.rotation.x = -0.1
	ombro_d.rotation.x = -0.1
	ombro_e.rotation.z = -0.25
	ombro_d.rotation.z = 0.25
	cabeca.rotation.y = 0.4

## Sentado (no chão ou numa cadeira baixa).
func pose_sentar() -> void:
	if modelo:
		loop("GroundSit_Idle")
		return
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
	if modelo:
		return
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

# ================================================================ modelo pronto
func _construir_modelo(rng: RandomNumberGenerator) -> void:
	modelo = true
	if zumbi:
		visual = "zumbi"
	elif jaleco:
		visual = "medico"
	elif chapeu:
		visual = "trabalhador"
	var vis := Modelos.escolher(visual, feminino, rng)
	for k in cores:
		vis[k] = cores[k]
	_m = Modelos.personagem(feminino, vis)
	add_child(_m.raiz)
	_m.raiz.rotation.y = 0.0
	_ap = _m.player
	_ap.playback_default_blend_time = 0.18
	if not _ap.animation_finished.is_connected(_fim_anim):
		_ap.animation_finished.connect(_fim_anim)
	# articulações "fantasma": o código antigo de pose ainda pode mexer nelas sem efeito
	var sombra := Node3D.new()
	sombra.name = "Sombra"
	sombra.visible = false
	add_child(sombra)
	tronco = _junta(sombra, Vector3(0, 0.95, 0))
	cabeca = _junta(tronco, Vector3(0, 0.66, 0))
	quadril_e = _junta(sombra, Vector3(-0.1, 0.95, 0))
	quadril_d = _junta(sombra, Vector3(0.1, 0.95, 0))
	joelho_e = _junta(quadril_e, Vector3(0, -0.45, 0))
	joelho_d = _junta(quadril_d, Vector3(0, -0.45, 0))
	ombro_e = _junta(tronco, Vector3(-0.23, 0.53, 0))
	ombro_d = _junta(tronco, Vector3(0.23, 0.53, 0))
	cotovelo_e = _junta(ombro_e, Vector3(0, -0.3, 0))
	cotovelo_d = _junta(ombro_d, Vector3(0, -0.3, 0))
	# pontos de fixação reais (em metros)
	var sk: Skeleton3D = _m.esqueleto
	mao_d = Modelos.anexo(sk, "hand_r", "mao_d")
	mao_e = Modelos.anexo(sk, "hand_l", "mao_e")
	costas = Modelos.anexo(sk, "spine_03", "costas")
	cabeca_a = Modelos.anexo(sk, "Head", "cabeca")
	coxa_e = Modelos.anexo(sk, "thigh_l", "coxa_e")
	coxa_d = Modelos.anexo(sk, "thigh_r", "coxa_d")
	canela_e = Modelos.anexo(sk, "calf_l", "canela_e")
	canela_d = Modelos.anexo(sk, "calf_r", "canela_d")
	braco_e = Modelos.anexo(sk, "upperarm_l", "braco_e")
	braco_d = Modelos.anexo(sk, "upperarm_r", "braco_d")
	antebraco_e = Modelos.anexo(sk, "lowerarm_l", "antebraco_e")
	antebraco_d = Modelos.anexo(sk, "lowerarm_r", "antebraco_d")
	_acessorios_modelo()
	_arma_modelo()
	set_process(true)
	if zumbi:
		loop("Zombie_Idle")
		_ap.seek(rng.randf() * 2.0, true)
	else:
		loop(anim_parado)
		_ap.seek(rng.randf() * 2.0, true)

func _acessorios_modelo() -> void:
	if zumbi:
		_sangue_modelo()
	if com_mochila:
		_mochila_modelo()
	_chapeu_modelo()

## Manchas de sangue e rasgos (zumbi): placas finas presas ao peito, braços e rosto.
func _sangue_modelo() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = semente + 17
	var vermelho := Modelos.mat(Color(0.32, 0.03, 0.02), 0.35)
	var escuro := Modelos.mat(Color(0.12, 0.04, 0.03), 0.6)
	for i in r.randi_range(3, 6):
		var lado := 1.0 if r.randf() < 0.75 else -1.0
		var p := Vector3(r.randf_range(-0.12, 0.12), r.randf_range(-0.12, 0.14), 0.135 * lado)
		var b := B.box(costas, Vector3(r.randf_range(0.04, 0.11), r.randf_range(0.04, 0.16), 0.008), p, vermelho if r.randf() < 0.7 else escuro)
		b.rotation.z = r.randf_range(-0.6, 0.6)
	# boca e queixo sujos
	B.box(cabeca_a, Vector3(0.05, 0.035, 0.008), Vector3(0, 0.03, 0.105), vermelho)
	for q in [antebraco_e, antebraco_d]:
		if r.randf() < 0.7:
			B.box(q, Vector3(0.07, 0.1, 0.07), Vector3(0, r.randf_range(0.05, 0.2), 0), vermelho)

## Chapéus e capacetes por papel (osso Head: +Y para cima, +Z para a frente; cabeça ~0,45 m).
func _chapeu_modelo() -> void:
	var h := cabeca_a
	var tipo := ""
	if com_bone and not zumbi:
		tipo = "bone"
	match visual:
		"soldado":
			tipo = "capacete"
		"trabalhador":
			tipo = "palha" if chapeu else "obra"
		"idoso", "cowboy":
			tipo = "chapeu"
	if chapeu and tipo == "":
		tipo = "palha"
	match tipo:
		"bone":
			var bone := Modelos.mat(Color(0.2, 0.22, 0.17), 0.9)
			B.sphere(h, 0.105, Vector3(0, 0.155, -0.005), bone, Vector3(1.0, 0.55, 1.08))
			B.box(h, Vector3(0.15, 0.012, 0.09), Vector3(0, 0.155, 0.11), bone, Vector3(-6, 0, 0))
		"capacete":
			var verde := Modelos.mat(Color(0.28, 0.32, 0.2), 0.75)
			B.sphere(h, 0.118, Vector3(0, 0.15, -0.005), verde, Vector3(1.04, 0.66, 1.12))
			B.cyl(h, 0.128, 0.018, Vector3(0, 0.135, -0.005), verde, Vector3.ZERO, 14)
		"obra":
			var am := Modelos.mat(Color(0.9, 0.7, 0.1), 0.45)
			B.sphere(h, 0.112, Vector3(0, 0.16, -0.005), am, Vector3(1.0, 0.62, 1.1))
			B.box(h, Vector3(0.15, 0.012, 0.06), Vector3(0, 0.15, 0.11), am)
		"palha", "chapeu":
			var c := Modelos.mat(Color(0.78, 0.66, 0.4), 0.95) if tipo == "palha" else Modelos.mat(Color(0.25, 0.17, 0.1), 0.85)
			B.cyl(h, 0.19, 0.012, Vector3(0, 0.17, 0), c, Vector3.ZERO, 16)
			B.cyl(h, 0.1, 0.09, Vector3(0, 0.215, 0), c, Vector3.ZERO, 12, 0.09)

## Mochila de sobrevivente: proporcional ao corpo novo (menor que a antiga).
func _mochila_modelo() -> void:
	var t := costas
	var verde := Modelos.mat(Color(0.26, 0.29, 0.2), 0.95)
	var escuro := Modelos.mat(Color(0.15, 0.16, 0.13), 0.9)
	var n := Node3D.new()
	n.name = "Mochila"
	# no osso Torso: +Y sobe pela coluna, +Z é a frente do peito
	n.position = Vector3(0, 0.02, -0.2)
	t.add_child(n)
	n.rotation_degrees = Vector3(0, 0, 0)
	B.box(n, Vector3(0.27, 0.32, 0.13), Vector3(0, 0, 0), verde)
	B.box(n, Vector3(0.21, 0.12, 0.05), Vector3(0, -0.06, -0.085), escuro)
	B.box(n, Vector3(0.28, 0.06, 0.14), Vector3(0, 0.17, 0), escuro)
	for sx in [-1.0, 1.0]:
		B.box(n, Vector3(0.05, 0.14, 0.09), Vector3(sx * 0.16, -0.04, 0), escuro)
	B.cyl(n, 0.06, 0.3, Vector3(0, -0.2, -0.01), Modelos.mat(Color(0.32, 0.3, 0.22), 0.95), Vector3(0, 0, 90), 10)

## Arma visível na mão direita.
func _arma_modelo() -> void:
	if mao_d == null:
		return
	_nas_costas = false
	Modelos.arma_na_mao(mao_d, arma)

var _nas_costas := false
## Espingarda e rifle vão para as costas (bandoleira) quando não estão em uso.
func arma_costas(sim: bool) -> void:
	if not modelo or sim == _nas_costas:
		return
	var a: Node3D = (costas if _nas_costas else mao_d).get_node_or_null("Arma")
	if a == null:
		return
	_nas_costas = sim
	a.get_parent().remove_child(a)
	if sim:
		costas.add_child(a)
		# atravessada nas costas, cano para cima à direita (osso spine_03: +Y sobe, +Z frente)
		var by := Vector3(-0.57, 0.82, 0.0)
		var bz := Vector3(0, 0, -1)
		a.transform = Transform3D(Basis(by.cross(bz), by, bz), Vector3(0.2, -0.3, -0.21))
	else:
		mao_d.add_child(a)
		a.transform = Transform3D()

func trocar_arma(id: String) -> void:
	arma = id
	if modelo:
		_arma_modelo()
	else:
		construir()

func anexo(nome: String) -> Node3D:
	match nome:
		"mao_d": return mao_d
		"mao_e": return mao_e
		"costas": return costas
		"cabeca": return cabeca_a
	return get(nome)

# ------------------------------------------------------------ animação
func _nome(n: String) -> String:
	return "q/" + n

func tem_anim(n: String) -> bool:
	return _ap != null and _ap.has_animation(_nome(n))

## Animação contínua (andar, parado, mirar...). Não interrompe um golpe em curso.
func loop(nome: String, vel := 1.0) -> void:
	if _ap == null or _travado:
		return
	_loop = nome
	_loop_vel = vel
	# aplicado uma vez no fim do quadro (várias poses no mesmo quadro: vale a última)
	if not _pend:
		_pend = true
		call_deferred("_aplicar_loop")

func _aplicar_loop() -> void:
	_pend = false
	if _ap == null or _oneshot or _travado or _loop == "":
		return
	if _ap.current_animation != _nome(_loop) and tem_anim(_loop):
		_ap.play(_nome(_loop))
	_ap.speed_scale = _loop_vel

## Animação única (golpe, dano, comer). Devolve a duração em segundos.
func tocar(nome: String, vel := 1.0, blend := 0.1) -> float:
	if _ap == null or not tem_anim(nome) or _travado:
		return 0.0
	_oneshot = true
	_ap.play(_nome(nome), blend)
	_ap.seek(0.0, true)
	_ap.speed_scale = vel
	var dur := _ap.get_animation(_nome(nome)).length / maxf(vel, 0.01)
	_oneshot_fim = Time.get_ticks_msec() / 1000.0 + dur
	return dur

func ocupado_anim() -> bool:
	return _oneshot

func _fim_anim(_n: StringName) -> void:
	if _oneshot:
		_oneshot = false
		if _loop != "":
			_aplicar_loop()

## Trava numa pose (prints, morte). frac = 0..1 da animação.
func fixar(nome: String, frac := 1.0) -> void:
	if _ap == null or not tem_anim(nome):
		return
	_travado = true
	_oneshot = false
	_ap.play(_nome(nome), 0.0)
	_ap.seek(_ap.get_animation(_nome(nome)).length * clampf(frac, 0.0, 1.0), true)
	_ap.pause()

## Toca uma vez e fica parado no último quadro (morte).
func cair(nome: String, vel := 1.0) -> void:
	if _ap == null or not tem_anim(nome):
		return
	_travado = true
	_oneshot = false
	var a := _ap.get_animation(_nome(nome))
	a.loop_mode = Animation.LOOP_NONE
	_ap.play(_nome(nome), 0.12)
	_ap.speed_scale = vel

func destravar() -> void:
	_travado = false
	_oneshot = false
	if _ap:
		_ap.play()
		loop(_loop if _loop != "" else anim_parado)

func _process(_dt: float) -> void:
	if modelo and _oneshot and Time.get_ticks_msec() / 1000.0 > _oneshot_fim + 0.25:
		_fim_anim(&"")

## Escolhe parado/andar/correr/agachado pela velocidade real.
func _locomover(intensidade: float) -> void:
	var v := 0.0 if intensidade <= 0.001 else (vel_anim if vel_anim > 0.0 else intensidade * 2.2)
	if agachado_anim:
		if v < 0.15:
			loop("Crouch_Idle")
		else:
			loop("Crouch_Fwd", clampf(v / 1.1, 0.6, 1.6))
	elif v < 0.15:
		loop(anim_parado)
	elif v < 2.9:
		loop("Walk", clampf(v / 1.45, 0.6, 1.7))
	elif v < 4.6:
		loop("Jog_Fwd", clampf(v / 3.6, 0.8, 1.4))
	else:
		loop("Sprint", clampf(v / 5.6, 0.8, 1.35))
