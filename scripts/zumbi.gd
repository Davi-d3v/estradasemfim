class_name Zumbi
extends Humanoid
## Zumbi com comportamento: vaga, ouve barulho, vê o jogador, persegue e ataca
## (o jogador a pé ou os veículos do comboio). Variantes mudam força e velocidade.

enum Estado { VAGANDO, INVESTIGANDO, PERSEGUINDO, ATACANDO, MORTO }

const TIPOS := {
	"comum": {"vida": 60.0, "vel_vagar": 0.6, "vel_correr": 2.1, "dano": 9.0, "dano_veic": 0.012, "escala": 1.0},
	"corredor": {"vida": 40.0, "vel_vagar": 0.9, "vel_correr": 4.6, "dano": 7.0, "dano_veic": 0.008, "escala": 0.95},
	"brutamonte": {"vida": 220.0, "vel_vagar": 0.5, "vel_correr": 1.6, "dano": 22.0, "dano_veic": 0.045, "escala": 1.35},
	"gritador": {"vida": 45.0, "vel_vagar": 0.7, "vel_correr": 2.4, "dano": 6.0, "dano_veic": 0.006, "escala": 0.95},
	"blindado": {"vida": 150.0, "vel_vagar": 0.55, "vel_correr": 1.9, "dano": 13.0, "dano_veic": 0.02, "escala": 1.05},
	"rastejante": {"vida": 35.0, "vel_vagar": 0.4, "vel_correr": 1.4, "dano": 12.0, "dano_veic": 0.004, "escala": 1.0},
}

var tipo := "comum"
var estado := Estado.VAGANDO
var vida := 60.0
var mundo: WorldGen
var alvo_pos := Vector3.ZERO
var _rumo := 0.0
var _t_decisao := 0.0
var _t_ataque := 0.0
var _fase := 0.0
var _t_morto := 0.0
var _gritou := false
var _t_gemido := randf_range(1.0, 10.0)
var _empurrao := Vector3.ZERO
var _anim_ataque := 0.0
var _rng := RandomNumberGenerator.new()
var cerco: Node = null          # Assentamento que esta onda está atacando

func configurar(t: String) -> void:
	tipo = t
	vida = TIPOS[t].vida
	var esc: float = TIPOS[t].escala
	scale = Vector3.ONE * esc * randf_range(0.94, 1.04)
	feminino = randf() < 0.4 and t != "brutamonte"
	sujeira = randf_range(0.2, 0.6)
	match t:
		"brutamonte":
			cores = {"Skin": Color(0.42, 0.44, 0.38), "Clothes": Color(0.16, 0.15, 0.14)}
		"gritador":
			cores = {"Skin": Color(0.62, 0.6, 0.55), "Clothes": Color(0.55, 0.52, 0.48)}
		"corredor":
			cores = {"Clothes": Color(0.4, 0.12, 0.1)}
		"blindado":
			cores = {"roupa": Color(0.36, 0.4, 0.3)}
	match t:
		"brutamonte":
			camisa = Color(0.18, 0.16, 0.15)
			pele = Color(0.42, 0.42, 0.36)
		"gritador":
			pele = Color(0.6, 0.56, 0.5)
			camisa = Color(0.55, 0.52, 0.48)
		"corredor":
			camisa = Color(0.35, 0.12, 0.1)
		"rastejante":
			calca = Color(0.12, 0.1, 0.08)

func _ready() -> void:
	zumbi = true
	_rng.seed = semente
	_rumo = rotation.y
	super._ready()
	if tipo == "blindado" and modelo:
		_equipar_blindado()
	_t_decisao = _rng.randf_range(0.0, 3.0)

func vivo() -> bool:
	return estado != Estado.MORTO

func info() -> Dictionary:
	return TIPOS[tipo]

## Capacete e colete de soldado (zumbi blindado: segura tiro e golpe fraco).
func _equipar_blindado() -> void:
	var verde := Modelos.mat(Color(0.26, 0.3, 0.2), 0.75)
	if cabeca_a:
		B.sphere(cabeca_a, 0.118, Vector3(0, 0.15, -0.005), verde, Vector3(1.04, 0.66, 1.12))
		B.cyl(cabeca_a, 0.128, 0.018, Vector3(0, 0.135, -0.005), verde, Vector3.ZERO, 14)
	if costas:
		var colete := Modelos.mat(Color(0.2, 0.22, 0.17), 0.85)
		# placas na frente e nas costas do peito (osso spine_03: +Y sobe, +Z frente)
		B.box(costas, Vector3(0.3, 0.3, 0.04), Vector3(0, 0.0, 0.13), colete)
		B.box(costas, Vector3(0.3, 0.3, 0.04), Vector3(0, 0.0, -0.12), colete)
		for s in [-1.0, 1.0]:
			B.box(costas, Vector3(0.04, 0.24, 0.24), Vector3(s * 0.155, 0.0, 0.005), colete)

## Recebe dano. empurrao = direção do golpe (para recuar).
func ferir(dano: float, empurrao := Vector3.ZERO, origem := Vector3.ZERO) -> void:
	if not vivo():
		return
	if tipo == "blindado":
		# colete e capacete: só tiro forte (rifle, espingarda de perto) ou golpe pesado passa bem
		dano *= 0.4 if dano < 60.0 else 0.85
		if dano < 25.0:
			Som.em("impacto_metal", global_position + Vector3(0, 1.3, 0), -6.0, 0.2)
	vida -= dano
	_empurrao = empurrao
	Som.em("impacto_carne", global_position + Vector3(0, 1.1, 0), -2.0, 0.15)
	if modelo and is_inside_tree():
		var peito := global_position + Vector3(0, 1.15 * scale.x, 0)
		Sangue.jorro(get_parent(), peito, empurrao if empurrao.length() > 0.1 else (peito - origem), clampf(dano / 40.0, 0.4, 1.8))
		if vida > 0.0 and tipo != "rastejante":
			var lado := 0.0
			if origem != Vector3.ZERO:
				var v := (origem - global_position)
				lado = v.normalized().dot(global_transform.basis.x.normalized())
			var reac := "Hit_Chest"
			if empurrao.length() > 7.5:
				reac = "Hit_Knockback"
			elif dano > 60.0:
				reac = "Hit_Head"
			elif absf(lado) > 0.35:
				reac = "Hit_Shoulder_L" if lado > 0.0 else "Hit_Shoulder_R"
			tocar(reac, 1.25, 0.05)
	if origem != Vector3.ZERO:
		alvo_pos = origem
		estado = Estado.PERSEGUINDO
	if vida <= 0.0:
		morrer()

func morrer() -> void:
	estado = Estado.MORTO
	Som.em("zumbi_morte", global_position + Vector3(0, 1.4, 0), -3.0, 0.12)
	_t_morto = 0.0
	if modelo:
		if tipo == "rastejante":
			fixar("Crawl_Idle", 0.0)
		else:
			cair("Death01" if _rng.randf() < 0.55 else "Death02", _rng.randf_range(0.9, 1.25))
	if mundo:
		mundo.zumbis_vivos.erase(self)

func _process(dt: float) -> void:
	if not mundo:
		return
	var main: Node = mundo.get_parent()
	if not main.has_method("_foco") or not main.get("jogando"):
		return
	if main.get("capturando"):
		return
	if estado == Estado.MORTO:
		_animar_morte(dt)
		return
	var foco: Vector3 = main.call("_foco")
	var dist_foco := global_position.distance_to(foco)
	if dist_foco > (140.0 if cerco else 90.0):
		return   # longe demais: congelado (economiza processamento)
	_t_decisao -= dt
	_t_gemido -= dt
	if _t_gemido <= 0.0:
		_t_gemido = _rng.randf_range(5.0, 14.0) if estado == Estado.VAGANDO else _rng.randf_range(2.5, 6.0)
		if dist_foco < 40.0:
			Som.em("zumbi_gemido", global_position + Vector3(0, 1.6, 0), -6.0 if estado == Estado.VAGANDO else -2.0, 0.15)
	_t_ataque = maxf(0.0, _t_ataque - dt)
	_anim_ataque = maxf(0.0, _anim_ataque - dt * 3.0)
	if cerco and not is_instance_valid(cerco):
		cerco = null
	if cerco:
		if estado != Estado.ATACANDO:
			estado = Estado.PERSEGUINDO
	else:
		_perceber(main)
	var vel := 0.0
	var alvo_dir := Vector3.ZERO
	match estado:
		Estado.VAGANDO:
			if _t_decisao <= 0.0:
				_t_decisao = _rng.randf_range(3.0, 8.0)
				_rumo = _rng.randf() * TAU if _rng.randf() < 0.7 else _rumo
			alvo_dir = Vector3(sin(_rumo), 0, cos(_rumo))
			vel = info().vel_vagar if _rng.randf() < 0.995 else 0.0
		Estado.INVESTIGANDO:
			alvo_dir = alvo_pos - global_position
			vel = info().vel_vagar * 1.6
			if Vector2(alvo_dir.x, alvo_dir.z).length() < 2.0:
				estado = Estado.VAGANDO
		Estado.PERSEGUINDO, Estado.ATACANDO:
			var alvo := _alvo_cerco(main) if cerco else _alvo_atual(main)
			alvo_pos = alvo.pos
			alvo_dir = alvo.pos - global_position
			var d := Vector2(alvo_dir.x, alvo_dir.z).length()
			if alvo.tipo == "mover":
				estado = Estado.PERSEGUINDO
				vel = info().vel_correr * 0.8
			elif d < alvo.alcance:
				estado = Estado.ATACANDO
				vel = 0.0
				if _t_ataque <= 0.0:
					_t_ataque = 1.3 if tipo != "brutamonte" else 1.9
					_anim_ataque = 1.0
					Som.em("zumbi_ataque", global_position + Vector3(0, 1.5, 0), 0.0, 0.12)
					if modelo:
						tocar("Zombie_Bite" if _rng.randf() < 0.4 else "Zombie_Scratch", 1.1 if tipo != "brutamonte" else 0.85)
					main.call("zumbi_atacou", self, alvo)
			else:
				estado = Estado.PERSEGUINDO
				vel = info().vel_correr
			if d > 45.0 and not cerco:
				estado = Estado.INVESTIGANDO
	alvo_dir.y = 0.0
	if alvo_dir.length() > 0.01:
		var ang := atan2(alvo_dir.x, alvo_dir.z)
		rotation.y = lerp_angle(rotation.y, ang, minf(1.0, dt * 4.0))
	var frente := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var nova := global_position + frente * vel * dt + _empurrao * dt
	_empurrao = _empurrao.move_toward(Vector3.ZERO, dt * 12.0)
	if not mundo.bloqueado(nova) and not mundo.colide(global_position, nova, 0.25) and mundo.agua_em(nova.x, nova.z) < mundo.altura(nova.x, nova.z) + 0.6:
		nova.y = _chao(nova)
		global_position = nova
	elif estado == Estado.VAGANDO:
		_rumo += PI
	_fase += dt * (2.0 + vel * 2.2)
	_animar(vel)

func _chao(p: Vector3) -> float:
	var pr := mundo.estrutura_em(p, 0.25)
	if pr:
		return pr.piso(Vector3(p.x, global_position.y, p.z))
	var d := absf(p.x - mundo.centro_x(p.z))
	if d < WorldGen.LARG_ESTRADA * 0.5 + 0.3:
		return mundo.elevacao(p.z) + 0.06
	return mundo.altura(p.x, p.z)

## Alvo durante o ataque a um assentamento: o muro na frente, uma brecha perto,
## e lá dentro os defensores ou os moradores no centro.
func _alvo_cerco(main: Node) -> Dictionary:
	var a: Assentamento = cerco
	var l := a.local_de(global_position)
	var r := Vector2(l.x, l.z).length()
	var perto := _defensor_perto(main, 2.4)
	if not perto.is_empty():
		return perto
	if r > Assentamento.R - 0.6:
		var fi := Assentamento.indice_f(l)
		var i := posmod(int(round(fi)), Assentamento.N)
		var j := a.brecha_perto(i, 4)
		if j == i:
			return {"tipo": "mover", "pos": a.global_de(Assentamento.ponto(j, Assentamento.R - 7.0)), "alcance": 0.0}
		if j >= 0:
			var delta := wrapi(j - i + Assentamento.N / 2, 0, Assentamento.N) - Assentamento.N / 2
			return {"tipo": "mover", "pos": a.global_de(Assentamento.ponto(fi + signf(delta) * 0.7, Assentamento.R + 2.2)), "alcance": 0.0}
		# sem brecha: bate no muro bem na frente
		var pm := a.global_de(Assentamento.ponto(fi, Assentamento.R + 0.75))
		return {"tipo": "muro", "pos": pm, "alcance": 0.95 * scale.x, "idx": i, "no": a}
	var dentro := _defensor_perto(main, 35.0)
	if not dentro.is_empty():
		return dentro
	var off := Vector3(sin(semente * 1.7), 0, cos(semente * 2.3)) * 3.0
	return {"tipo": "povo", "pos": a.global_de(Vector3(0, 0, 2.0)) + off, "alcance": 2.2, "no": a}

func _defensor_perto(main: Node, raio: float) -> Dictionary:
	var md := raio
	var res := {}
	var j: Node3D = main.jogador
	if j.visible:
		var dj := global_position.distance_to(j.global_position)
		if dj < md:
			md = dj
			res = {"tipo": "jogador", "pos": j.global_position, "alcance": 1.3 * scale.x, "no": j}
	for rc in main.recrutas_nos:
		if is_instance_valid(rc) and rc.vivo() and not rc.fixo:
			var d := global_position.distance_to(rc.global_position)
			if d < md:
				md = d
				res = {"tipo": "recruta", "pos": rc.global_position, "alcance": 1.3 * scale.x, "no": rc}
	return res

## Alvo: o jogador a pé, ou o veículo mais perto se ele estiver dentro de um.
## Um recruta mais perto que esse alvo vira o alvo.
func _alvo_atual(main: Node) -> Dictionary:
	var base := _alvo_base(main)
	var rc := _recruta_perto(main, 1e9)
	if rc and (base.is_empty() or global_position.distance_to(rc.global_position) < global_position.distance_to(base.pos)):
		return {"tipo": "recruta", "pos": rc.global_position, "alcance": 1.3 * scale.x, "no": rc}
	return base

func _recruta_perto(main: Node, raio: float) -> Node3D:
	var melhor: Node3D = null
	var md := raio
	for rc in main.recrutas_nos:
		if is_instance_valid(rc) and rc.vivo():
			var d := global_position.distance_to(rc.global_position)
			if d < md:
				md = d
				melhor = rc
	return melhor

func _alvo_base(main: Node) -> Dictionary:
	var j: Node3D = main.jogador
	if j.visible:
		return {"tipo": "jogador", "pos": j.global_position, "alcance": 1.3 * scale.x, "no": j}
	var melhor := {}
	var md := 1e9
	var veic: Array = [main.picape]
	veic.append_array(main.comboio.cadeia)
	for v in veic:
		var meia: float = 2.8 if v == main.picape else v.comprimento() * 0.5
		var local: Vector3 = v.global_transform.affine_inverse() * global_position
		var pz := clampf(local.z, -meia, meia)
		var ponto: Vector3 = v.global_transform * Vector3(clampf(local.x, -1.1, 1.1), 0, pz)
		var d := Vector2(ponto.x - global_position.x, ponto.z - global_position.z).length()
		if d < md:
			md = d
			melhor = {"tipo": "veiculo", "pos": ponto, "alcance": 1.0 * scale.x, "no": v}
	return melhor

## Visão e audição.
func _perceber(main: Node) -> void:
	var j: Node3D = main.jogador
	var noite: bool = main.eh_noite()
	var alvo_p: Vector3 = j.global_position if j.visible else main.comboio.pos
	var d := global_position.distance_to(alvo_p)
	var visao := 9.0 if noite else 20.0
	var cl = main.get("clima")
	if cl:
		visao *= cl.fator_visao()
	# farol aceso no escuro: quem está na frente do comboio vê de longe e vem
	if noite and main.comboio.dirigindo and main.picape.farol:
		var fr := Vector3(sin(main.comboio.yaw), 0, cos(main.comboio.yaw))
		var rel: Vector3 = global_position - main.comboio.pos
		if rel.length() < 48.0 and fr.dot(rel.normalized()) > 0.75:
			visao = maxf(visao, 48.0)
	if tipo == "rastejante":
		visao *= 0.6
	if j.visible and j.get("agachado"):
		visao *= 0.5
	# luz do acampamento ou do trailer chama a atenção à noite
	if noite and main.trailer.luz_interna and not main.trailer.luz_vermelha:
		if global_position.distance_to(main.trailer.global_position) < 28.0:
			visao = maxf(visao, 28.0)
	var frente := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var para := (alvo_p - global_position).normalized()
	var ve := d < visao and (frente.dot(para) > -0.2 or d < 4.0)
	if not ve:
		# recrutas no acampamento também são vistos
		var rc := _recruta_perto(main, visao)
		if rc:
			ve = true
	if ve:
		if estado != Estado.PERSEGUINDO and estado != Estado.ATACANDO:
			estado = Estado.PERSEGUINDO
			if tipo == "gritador" and not _gritou:
				_gritou = true
				Som.em("zumbi_grito", global_position + Vector3(0, 1.6, 0), 4.0, 0.06, 4.0)
				main.call("ruido", global_position, 55.0, "grito")
		return
	if estado == Estado.PERSEGUINDO and d > visao * 1.8:
		estado = Estado.INVESTIGANDO
		alvo_pos = alvo_p
	var ouvido: float = 1.0 if cl == null else cl.fator_audicao()
	for r in mundo.ruidos:
		if global_position.distance_to(r.pos) < r.raio * ouvido and estado == Estado.VAGANDO:
			estado = Estado.INVESTIGANDO
			alvo_pos = r.pos + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))

func _animar(vel: float) -> void:
	if modelo:
		vel_anim = vel
		if tipo == "rastejante":
			loop("Crawl_Fwd" if vel > 0.1 else "Crawl_Idle", clampf(vel / 0.6, 0.6, 1.6))
		else:
			pose_zumbi(_fase)
		return
	if tipo == "rastejante":
		pose_rastejar(_fase)
		return
	pose_zumbi(_fase * (1.0 if vel < 1.5 else 1.8))
	if vel > 1.5:
		var a := sin(_fase) * 0.7
		quadril_e.rotation.x = a
		quadril_d.rotation.x = -a
		joelho_e.rotation.x = maxf(0.0, -sin(_fase - 0.6)) * 1.0
		joelho_d.rotation.x = maxf(0.0, sin(_fase - 0.6)) * 1.0
		tronco.rotation.x = 0.45
	if _anim_ataque > 0.0:
		var k := sin(_anim_ataque * PI)
		ombro_e.rotation.x = -1.5 - k * 0.4
		ombro_d.rotation.x = -1.5 - k * 0.4
		tronco.rotation.x = 0.3 + k * 0.35

func pose_rastejar(f: float) -> void:
	tronco.rotation.x = 1.35
	tronco.position.y = 0.35
	quadril_e.rotation.x = 1.5 + sin(f) * 0.15
	quadril_d.rotation.x = 1.5 - sin(f) * 0.15
	quadril_e.position.y = 0.3
	quadril_d.position.y = 0.3
	ombro_e.rotation.x = -2.4 + sin(f) * 0.5
	ombro_d.rotation.x = -2.4 - sin(f) * 0.5
	cabeca.rotation.x = -0.9

func _animar_morte(dt: float) -> void:
	if modelo:
		var t0 := _t_morto
		_t_morto += dt
		if t0 < 1.0 and _t_morto >= 1.0:
			Sangue.poca(get_parent(), global_position + global_transform.basis.z * -0.5 * scale.x, 1.0 * scale.x)
		if _t_morto > 40.0:
			queue_free()
		return
	_t_morto += dt
	var t := clampf(_t_morto * 2.2, 0.0, 1.0)
	rotation.x = lerpf(0.0, -1.5, t * t)
	ombro_e.rotation.x = -2.6
	ombro_d.rotation.x = -2.2
	quadril_e.rotation.x = 0.1
	quadril_d.rotation.x = -0.15
	if _t_morto > 40.0:
		queue_free()
