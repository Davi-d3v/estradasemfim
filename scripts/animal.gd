class_name Animal
extends Node3D
## Bicho do mato: pasta e anda devagar; foge de barulho e de quem chega perto
## (o javali às vezes ataca). Morto, dá para esfolar: carne crua e pele.

enum Estado { PASTANDO, FUGINDO, ATACANDO, MORTO }

const TIPOS := {
	"veado": {"nome": "veado", "vida": 70.0, "andar": 1.1, "correr": 7.5, "carne": 4, "pele": 2, "escala": 1.0, "agressivo": 0.0, "dano": 0.0, "medo": 22.0},
	"javali": {"nome": "javali", "vida": 120.0, "andar": 0.9, "correr": 5.8, "carne": 5, "pele": 2, "escala": 1.0, "agressivo": 0.6, "dano": 14.0, "medo": 14.0},
	"lobo": {"nome": "lobo", "vida": 90.0, "andar": 1.0, "correr": 7.2, "carne": 3, "pele": 2, "escala": 1.0, "agressivo": 0.85, "dano": 12.0, "medo": 20.0},
	"capivara": {"nome": "capivara", "vida": 60.0, "andar": 0.6, "correr": 4.2, "carne": 4, "pele": 1, "escala": 1.0, "agressivo": 0.0, "dano": 0.0, "medo": 12.0},
}

var tipo := "veado"
var mundo: WorldGen
var semente := 0
var estado := Estado.PASTANDO
var vida := 70.0
var esfolado := false
var chave := ""
var _rng := RandomNumberGenerator.new()
var _rumo := 0.0
var _t := 0.0
var _t_decisao := 0.0
var _fase := 0.0
var _ameaca := Vector3.ZERO
var _t_fuga := 0.0
var _t_ataque := 0.0
var _empurrao := Vector3.ZERO
var _corpo: Node3D
var _cabeca: Node3D
var _pernas: Array = []
var _t_morto := 0.0
var _poca := false
var _t_reacao := 0.0
var _mod := {}             # modelo animado (veado, cervo, lobo)
var _ap: AnimationPlayer
var _anim := ""
var _oneshot := false

func info() -> Dictionary:
	return TIPOS[tipo]

func vivo() -> bool:
	return estado != Estado.MORTO

func altura_alvo() -> float:
	return {"veado": 1.0, "javali": 0.55, "capivara": 0.4, "lobo": 0.6}[tipo]

func raio_alvo() -> float:
	return {"veado": 0.55, "javali": 0.5, "capivara": 0.45, "lobo": 0.45}[tipo]

func _ready() -> void:
	_rng.seed = semente
	vida = info().vida
	_rumo = _rng.randf() * TAU
	rotation.y = _rumo
	_t_decisao = _rng.randf_range(1.0, 5.0)
	_montar()
	if mundo:
		mundo.animais.append(self)

func ferir(dano: float, empurrao := Vector3.ZERO, origem := Vector3.ZERO) -> void:
	if not vivo():
		return
	vida -= dano
	_empurrao = empurrao * 0.4
	_t_reacao = 0.35
	if is_inside_tree():
		Sangue.jorro(get_parent(), global_position + Vector3(0, altura_alvo() * scale.x, 0), empurrao, 0.8)
	if origem != Vector3.ZERO:
		_assustar(origem, true)
	if vida <= 0.0:
		estado = Estado.MORTO
		_t_morto = 0.0

func _assustar(de: Vector3, ferido := false) -> void:
	if not vivo():
		return
	_ameaca = de
	if info().agressivo > 0.0 and (ferido or _rng.randf() < info().agressivo) and estado != Estado.FUGINDO:
		estado = Estado.ATACANDO
		_t_fuga = 8.0
	else:
		estado = Estado.FUGINDO
		_t_fuga = _rng.randf_range(6.0, 10.0)

func _process(dt: float) -> void:
	if not mundo:
		return
	var main: Node = mundo.get_parent()
	if not main.get("jogando") or main.get("capturando"):
		return
	if estado == Estado.MORTO:
		_morte(dt)
		return
	var foco: Vector3 = main.call("_foco")
	if global_position.distance_to(foco) > 120.0:
		return
	_t += dt
	_t_decisao -= dt
	_t_fuga -= dt
	_t_ataque = maxf(0.0, _t_ataque - dt)
	_perceber(main)
	var vel := 0.0
	var dir := Vector3(sin(_rumo), 0, cos(_rumo))
	match estado:
		Estado.PASTANDO:
			if _t_decisao <= 0.0:
				_t_decisao = _rng.randf_range(3.0, 9.0)
				_rumo += _rng.randf_range(-1.2, 1.2)
			vel = info().andar if fmod(_t, 9.0) < 4.0 else 0.0
		Estado.FUGINDO:
			var fora := global_position - _ameaca
			fora.y = 0.0
			if fora.length() > 0.1:
				_rumo = atan2(fora.x, fora.z) + sin(_t * 1.3) * 0.3
			dir = Vector3(sin(_rumo), 0, cos(_rumo))
			vel = info().correr
			if _t_fuga <= 0.0:
				estado = Estado.PASTANDO
		Estado.ATACANDO:
			var j: Node3D = main.jogador
			var alvo: Vector3 = j.global_position if j.visible else _ameaca
			var para := alvo - global_position
			para.y = 0.0
			_rumo = atan2(para.x, para.z)
			dir = Vector3(sin(_rumo), 0, cos(_rumo))
			vel = info().correr
			if para.length() < 1.4 and _t_ataque <= 0.0 and j.visible:
				_t_ataque = 1.4
				j.levar_dano(main.equip.absorver(info().dano / 100.0))
				main.hud.dano()
				main.hud.aviso("O %s te acertou com as presas!" % info().nome)
				_empurrao = -dir * 5.0
			if _t_fuga <= 0.0 or para.length() > 30.0:
				estado = Estado.FUGINDO
				_t_fuga = 5.0
	rotation.y = lerp_angle(rotation.y, _rumo, minf(1.0, dt * 5.0))
	var nova := global_position + Vector3(sin(rotation.y), 0, cos(rotation.y)) * vel * dt + _empurrao * dt
	_empurrao = _empurrao.move_toward(Vector3.ZERO, dt * 10.0)
	var ag := mundo.agua_em(nova.x, nova.z)
	var funda := ag > -1e8 and ag - mundo.altura(nova.x, nova.z) > (1.2 if tipo == "capivara" else 0.5)
	if not mundo.bloqueado(nova) and not mundo.colide(global_position, nova, 0.4) and not funda:
		nova.y = mundo.altura(nova.x, nova.z)
		global_position = nova
	else:
		_rumo += PI * 0.6
	_animar(vel, dt)

func _perceber(main: Node) -> void:
	if estado != Estado.PASTANDO:
		return
	var j: Node3D = main.jogador
	var alvo_p: Vector3 = j.global_position if j.visible else main.comboio.pos
	var medo: float = info().medo
	if j.visible and j.get("agachado"):
		medo *= 0.4
	if not j.visible and main.comboio.dirigindo:
		medo *= 2.0
	if global_position.distance_to(alvo_p) < medo:
		_assustar(alvo_p)
		return
	for z in mundo.zumbis_vivos:
		if is_instance_valid(z) and z.vivo() and global_position.distance_to(z.global_position) < 9.0:
			_assustar(z.global_position)
			return
	for r in mundo.ruidos:
		if global_position.distance_to(r.pos) < r.raio * 1.4:
			_assustar(r.pos)
			return

# ------------------------------------------------------------ corpo
func _montar() -> void:
	if Modelos.disponivel():
		var qual := tipo
		if tipo == "veado":
			qual = "cervo" if _rng.randf() < 0.35 else "veado"
		_mod = Modelos.animal(qual)
	if not _mod.is_empty():
		_corpo = Node3D.new()
		add_child(_corpo)
		_cabeca = Node3D.new()
		_corpo.add_child(_cabeca)
		add_child(_mod.raiz)
		_ap = _mod.player
		_ap.animation_finished.connect(func(_n): _oneshot = false)
		scale = Vector3.ONE * _rng.randf_range(0.9, 1.1)
		_tocar("Idle")
		return
	var r := _rng
	var pelo: Color
	var esc := 1.0
	match tipo:
		"veado":
			pelo = Color(0.52, 0.36, 0.22).lerp(Color(0.6, 0.45, 0.3), r.randf())
		"javali":
			pelo = Color(0.2, 0.16, 0.12).lerp(Color(0.32, 0.25, 0.18), r.randf())
		_:
			pelo = Color(0.45, 0.33, 0.22).lerp(Color(0.5, 0.38, 0.25), r.randf())
	var m := B.mat(pelo, 0.95)
	var claro := B.mat(pelo.lightened(0.35), 0.95)
	var preto := B.mat(Color(0.06, 0.05, 0.05), 0.6)
	_corpo = Node3D.new()
	add_child(_corpo)
	var h_perna: float
	var comp: float
	var larg: float
	match tipo:
		"veado":
			h_perna = 0.75
			comp = 1.3
			larg = 0.36
		"javali":
			h_perna = 0.38
			comp = 1.2
			larg = 0.5
		_:
			h_perna = 0.28
			comp = 1.0
			larg = 0.5
	var y_corpo := h_perna + larg * 0.45
	var tronco := B.capsule(_corpo, larg * 0.5, comp, Vector3(0, y_corpo, 0), m, Vector3(90, 0, 0))
	if tipo == "javali":
		tronco.scale = Vector3(1.0, 1.0, 1.25)
		B.box(_corpo, Vector3(0.08, 0.14, comp * 0.7), Vector3(0, y_corpo + larg * 0.55, 0.05), preto)   # crina
	if tipo == "veado":
		B.sphere(_corpo, 0.12, Vector3(0, y_corpo + 0.05, -comp * 0.5), claro, Vector3(1, 1.2, 0.6), 6)   # rabo branco
	# cabeça
	_cabeca = Node3D.new()
	_corpo.add_child(_cabeca)
	match tipo:
		"veado":
			_cabeca.position = Vector3(0, y_corpo + 0.15, comp * 0.42)
			B.cyl(_cabeca, 0.09, 0.55, Vector3(0, 0.25, 0.08), m, Vector3(25, 0, 0), 7)
			B.capsule(_cabeca, 0.1, 0.36, Vector3(0, 0.52, 0.2), m, Vector3(70, 0, 0))
			B.sphere(_cabeca, 0.035, Vector3(0, 0.47, 0.38), preto)
			for sx in [-1.0, 1.0]:
				B.box(_cabeca, Vector3(0.05, 0.14, 0.03), Vector3(sx * 0.1, 0.65, 0.14), m, Vector3(0, 0, sx * -35))
			if r.randf() < 0.5:
				var chifre := B.mat(Color(0.75, 0.68, 0.55), 0.7)
				for sx in [-1.0, 1.0]:
					B.cyl(_cabeca, 0.015, 0.35, Vector3(sx * 0.07, 0.8, 0.12), chifre, Vector3(-15, 0, sx * -25), 4)
					B.cyl(_cabeca, 0.012, 0.18, Vector3(sx * 0.13, 0.9, 0.2), chifre, Vector3(30, 0, sx * -50), 4)
		"javali":
			_cabeca.position = Vector3(0, y_corpo, comp * 0.55)
			B.capsule(_cabeca, 0.2, 0.55, Vector3(0, -0.02, 0.12), m, Vector3(80, 0, 0))
			B.cyl(_cabeca, 0.07, 0.06, Vector3(0, -0.08, 0.4), B.mat(Color(0.3, 0.22, 0.2), 0.7), Vector3(90, 0, 0), 8)
			var presa := B.mat(Color(0.9, 0.88, 0.8), 0.5)
			for sx in [-1.0, 1.0]:
				B.cyl(_cabeca, 0.015, 0.12, Vector3(sx * 0.08, -0.06, 0.34), presa, Vector3(-40, 0, sx * 30), 4)
				B.box(_cabeca, Vector3(0.05, 0.1, 0.03), Vector3(sx * 0.12, 0.17, 0.0), m, Vector3(0, 0, sx * -25))
		_:
			_cabeca.position = Vector3(0, y_corpo + 0.05, comp * 0.5)
			B.box(_cabeca, Vector3(0.24, 0.26, 0.38), Vector3(0, 0, 0.1), m)
			B.box(_cabeca, Vector3(0.2, 0.18, 0.1), Vector3(0, -0.03, 0.3), B.mat(pelo.darkened(0.3), 0.9))
			for sx in [-1.0, 1.0]:
				B.sphere(_cabeca, 0.04, Vector3(sx * 0.08, 0.15, -0.02), m)
	# pernas
	for sz in [comp * 0.38, -comp * 0.38]:
		for sx in [-larg * 0.3, larg * 0.3]:
			var pv := Node3D.new()
			pv.position = Vector3(sx, h_perna + 0.05, sz)
			_corpo.add_child(pv)
			B.cyl(pv, 0.045 if tipo == "veado" else 0.06, h_perna + 0.05, Vector3(0, -(h_perna + 0.05) * 0.5, 0), m, Vector3.ZERO, 6)
			B.box(pv, Vector3(0.07, 0.06, 0.09), Vector3(0, -h_perna - 0.02, 0.01), preto)
			_pernas.append(pv)
	scale = Vector3.ONE * esc * r.randf_range(0.9, 1.1)

func _tocar(nome: String, vel := 1.0, unica := false) -> void:
	if _ap == null or not _ap.has_animation(nome):
		return
	if unica:
		_oneshot = true
		_anim = nome
		_ap.play(nome, 0.1)
		_ap.seek(0.0, true)
		_ap.speed_scale = vel
		return
	if _oneshot:
		return
	if _anim != nome:
		_anim = nome
		_ap.play(nome, 0.25)
	_ap.speed_scale = vel

func _animar(vel: float, dt: float) -> void:
	if _ap:
		if _t_reacao > 0.0:
			_t_reacao = maxf(0.0, _t_reacao - dt)
		if _t_reacao > 0.25:
			_tocar("Idle_HitReact1", 1.3, true)
		elif estado == Estado.ATACANDO and _t_ataque > 1.2:
			_tocar("Attack" if _ap.has_animation("Attack") else "Attack_Headbutt", 1.2, true)
		elif vel > 3.0:
			_tocar("Gallop", clampf(vel / 6.5, 0.7, 1.5))
		elif vel > 0.1:
			_tocar("Walk", clampf(vel / 1.1, 0.6, 1.5))
		elif estado == Estado.PASTANDO and fmod(_t + semente % 10, 14.0) < 6.0:
			_tocar("Eating")
		else:
			_tocar("Idle" if estado == Estado.PASTANDO else "Idle_2")
		return
	_fase += dt * (2.0 + vel * 2.2)
	var k := clampf(vel / 2.0, 0.0, 1.0)
	for i in _pernas.size():
		var par := (i % 2 == 0) != (i >= 2)
		_pernas[i].rotation.x = sin(_fase + (0.0 if par else PI)) * 0.55 * k
	_corpo.position.y = absf(sin(_fase)) * 0.06 * k
	# cabeça baixa pastando, alta em alerta
	var alvo := 0.5 if (estado == Estado.PASTANDO and vel < 0.1) else (-0.1 if estado == Estado.FUGINDO else 0.0)
	if tipo == "javali" and estado == Estado.ATACANDO:
		alvo = 0.25
	_cabeca.rotation.x = lerpf(_cabeca.rotation.x, alvo, minf(1.0, dt * 3.0))

func _morte(dt: float) -> void:
	if _ap:
		if _t_morto == 0.0:
			_oneshot = false
			_anim = "Death"
			_ap.speed_scale = 1.0
			_ap.get_animation("Death").loop_mode = Animation.LOOP_NONE
			_ap.play("Death", 0.1)
		_t_morto += dt
		var yy := mundo.altura(global_position.x, global_position.z)
		global_position.y = lerpf(global_position.y, yy, minf(1.0, dt * 6.0))
		if _t_morto > 1.2 and not _poca:
			_poca = true
			Sangue.poca(get_parent(), global_position, 0.8)
		if _t_morto > 600.0:
			queue_free()
		return
	_t_morto += dt
	if _t_morto > 0.6 and not _poca:
		_poca = true
		Sangue.poca(get_parent(), global_position, 0.8)
	rotation.z = lerpf(rotation.z, PI * 0.5, minf(1.0, dt * 6.0))
	var y := mundo.altura(global_position.x, global_position.z) + 0.15
	global_position.y = lerpf(global_position.y, y, minf(1.0, dt * 6.0))
	if _t_morto > 600.0:
		queue_free()
