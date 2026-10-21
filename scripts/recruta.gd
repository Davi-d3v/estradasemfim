class_name Recruta
extends Humanoid
## Recruta no acampamento: fica no posto fazendo o seu trabalho e larga tudo
## para lutar quando zumbis chegam perto. Ferido demais, recua para o comboio.

enum Estado { POSTO, INDO, LUTANDO, RECUANDO, DORMINDO }

var dados: Dictionary            # o Dictionary em main.recrutas (alterado direto)
var main: Node
var posto := Vector3.ZERO        # onde trabalha
var olhar_posto := 0.0
var estado := Estado.POSTO
var alvo: Zumbi = null
var _t := 0.0
var _t_ataque := 0.0
var _t_busca := 0.0
var _fase := 0.0
var _flash: Node3D
var _t_flash := 0.0
var _patrulha := 0.0
var _anim_golpe := 0.0
var _t_dano := 0.0
var _t_panico := 0.0
# defesa de assentamento
var fixo := false                # em cima de uma torre: não sai do lugar
var papel := ""                  # torre, portao, muro, reparos, socorro, centro
var refugio := Vector3.ZERO      # para onde recua ferido (sem isso, o trailer)
var assent: Node = null          # Assentamento sendo defendido
var _alvo_reparo := -1

const ALCANCE_VISTA := 16.0
const ALCANCE_TIRO := 30.0

static func criar(d: Dictionary) -> Recruta:
	var r := Recruta.new()
	r.dados = d
	r.semente = d.semente
	r.pele = d.pele
	r.camisa = d.camisa
	r.calca = d.calca
	r.com_bone = d.bone
	r.feminino = VidaRecrutas.eh_nome_feminino(String(d.get("nome", "")))
	r.cores = {"Skin": d.pele, "Shirt": d.camisa, "Pants": d.calca}
	match d.funcao:
		"vigia":
			r.visual = "soldado"
			r.anim_parado = "Idle_LookAround"
		"mecanico":
			r.visual = "mecanico"
			r.anim_parado = "Idle_Tired"
		"agricultor":
			r.visual = "agricultor"
		"medico":
			r.visual = "medico"
			r.anim_parado = "Idle_FoldArms"
		"batedor":
			r.visual = "batedor"
		"idoso":
			r.visual = "idoso"
			r.anim_parado = "Idle_Tired"
		"crianca":
			r.visual = "crianca"
			r.anim_parado = "Idle_LookAround"
			if not Modelos.npcs_ok():
				r.scale = Vector3.ONE * 0.64
	match d.funcao:
		"vigia":
			r.arma = "rifle"
			r.com_bone = true
		"mecanico":
			r.arma = "chave"
			r.camisa = Color(0.16, 0.24, 0.38)
			r.calca = Color(0.16, 0.24, 0.38)
		"agricultor":
			r.arma = "facao"
			r.chapeu = true
			r.com_bone = false
		"medico":
			r.jaleco = true
		"batedor":
			r.arma = "facao"
			r.com_mochila = true
	return r

func _ready() -> void:
	super._ready()
	_flash = Node3D.new()
	var boca: Node = find_child("Boca", true, false)
	if boca:
		boca.add_child(_flash)
		B.sphere(_flash, 0.09, Vector3.ZERO, B.emissive(Color(1.0, 0.8, 0.35), 6.0), Vector3(1, 1, 2.2), 6)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.4)
		l.light_energy = 3.0
		l.omni_range = 6.0
		_flash.add_child(l)
	_flash.visible = false
	_patrulha = randf() * TAU

func funcao() -> String:
	return dados.funcao

func ferir(d: float) -> void:
	var vivo_antes := vivo()
	dados.vida = maxf(0.0, dados.vida - d)
	_t_dano = 0.4
	if modelo and is_inside_tree():
		Sangue.jorro(get_parent(), global_position + Vector3(0, 1.15, 0), -global_transform.basis.z, 0.6)
		if vivo_antes and not vivo():
			cair("Death01" if randf() < 0.5 else "Death02")
		elif vivo():
			tocar("Hit_Chest", 1.2, 0.05)

func vivo() -> bool:
	return dados.vida > 0.0

func _process(dt: float) -> void:
	if not main or main.get("capturando") and not get_meta("animar_captura", false):
		return
	_t += dt
	_t_ataque = maxf(0.0, _t_ataque - dt)
	_t_busca -= dt
	_t_panico = maxf(0.0, _t_panico - dt)
	_t_flash = maxf(0.0, _t_flash - dt)
	_anim_golpe = maxf(0.0, _anim_golpe - dt * 3.0)
	_t_dano = maxf(0.0, _t_dano - dt)
	_flash.visible = _t_flash > 0.0
	if not vivo():
		return
	if estado == Estado.DORMINDO:
		pose_dormir()
		return
	# procura zumbis perto de tempos em tempos
	if _t_busca <= 0.0:
		_t_busca = 0.35
		alvo = _zumbi_mais_perto()
		var traco: String = dados.get("traco", "")
		var limite := 0.15 if traco == "corajoso" else 0.3
		var ferido: bool = dados.vida < limite
		if dados.funcao in ["crianca", "idoso"] and _ameaca(14.0):
			estado = Estado.RECUANDO      # se esconde no trailer
		elif _t_panico > 0.0:
			estado = Estado.RECUANDO
		elif ferido and not fixo:
			estado = Estado.RECUANDO
		elif alvo and traco == "medroso" and not fixo and estado != Estado.LUTANDO and randf() < 0.3:
			_t_panico = randf_range(4.0, 8.0)
			estado = Estado.RECUANDO
			main.hud.aviso("%s entrou em pânico e correu para o trailer!" % dados.nome)
		elif alvo:
			estado = Estado.LUTANDO
		elif estado == Estado.LUTANDO or estado == Estado.RECUANDO:
			estado = Estado.INDO
	if assent and _tarefa_defesa(dt):
		return
	match estado:
		Estado.POSTO:
			_no_posto(dt)
		Estado.INDO:
			if _andar_ate(posto, 2.0, dt):
				estado = Estado.POSTO
		Estado.LUTANDO:
			_lutar(dt)
		Estado.RECUANDO:
			if refugio != Vector3.ZERO:
				_andar_ate(refugio, 2.0, dt)
			else:
				_andar_ate(main.trailer.global_position + main.trailer.global_transform.basis.x * 2.2, 3.0, dt)
	if _t_dano > 0.0 and not modelo:
		tronco.rotation.x = -0.25 * _t_dano / 0.4

func _zumbi_mais_perto() -> Zumbi:
	if dados.funcao in ["crianca", "idoso"]:
		return null
	var alcance := ALCANCE_TIRO if dados.funcao == "vigia" else ALCANCE_VISTA
	if fixo:
		alcance = 36.0
	if dados.funcao == "medico":
		alcance = 5.0    # médico só se defende
	var melhor: Zumbi = null
	var md := alcance
	for z in main.mundo.zumbis_vivos:
		if not is_instance_valid(z) or not z.vivo():
			continue
		var d := global_position.distance_to(z.global_position)
		# batedor prefere os especiais
		if dados.funcao == "batedor" and z.tipo != "comum":
			d *= 0.6
		if d < md:
			md = d
			melhor = z
	return melhor

func _ameaca(raio: float) -> bool:
	for z in main.mundo.zumbis_vivos:
		if is_instance_valid(z) and z.vivo() and z.global_position.distance_to(global_position) < raio:
			return true
	return false

## Com o acampamento montado, quem não está de vigia senta na roda da fogueira
## (idosos, médicos e batedores o dia todo; os outros depois do expediente).
func _quer_sentar() -> bool:
	if not (main.acampamento is Acampamento) or assent != null or fixo:
		return false
	match dados.funcao:
		"vigia":
			return false
		"idoso", "medico", "batedor":
			return true
	var h: float = main.hora
	return h >= 17.0 or h < 5.0

var _cadeira := -1
var _conversa := ""
var _t_conversa := 0.0

func _sentar_fogueira(dt: float) -> bool:
	var ac: Acampamento = main.acampamento
	_cadeira = ac.pedir_cadeira(self)
	if _cadeira < 0:
		return false
	var c: Dictionary = ac.cadeiras[_cadeira]
	var frente: Vector3 = c.pos + Vector3(sin(c.yaw), 0, cos(c.yaw)) * 0.7
	if global_position.distance_to(c.pos) > 0.9:
		if _andar_ate(frente, 0.25, dt, 1.6):
			global_position = c.pos
		return true
	global_position = c.pos
	rotation.y = lerp_angle(rotation.y, c.yaw, dt * 6.0)
	# a conversa vai mudando: um fala, o outro concorda, alguém fica quieto olhando o fogo
	_t_conversa -= dt
	if _t_conversa <= 0.0 or _conversa == "":
		var ops := ["Sitting_Talking", "Sitting_Nodding", "Sitting_Talking", "Sitting_Idle", "Sitting_Nodding", "Sitting_Idle03"]
		_conversa = ops[(int(_t * 0.13) + semente + _cadeira) % ops.size()]
		_t_conversa = randf_range(5.0, 11.0)
	if modelo:
		loop(_conversa)
	else:
		pose_sentar()
	return true

func _no_posto(dt: float) -> void:
	if _quer_sentar():
		if _sentar_fogueira(dt):
			return
	elif _cadeira >= 0:
		if main.acampamento is Acampamento:
			main.acampamento.largar_cadeira(self)
		_cadeira = -1
	match dados.funcao:
		"vigia":
			if fixo:
				rotation.y = lerp_angle(rotation.y, olhar_posto + sin(_t * 0.4) * 0.8, dt * 2.0)
				pose_caminhada(0.0, 0.0)
				return
			# ronda devagar em volta do posto, olhando para fora
			_patrulha += dt * 0.12
			var p := posto + Vector3(cos(_patrulha), 0, sin(_patrulha)) * 3.0
			if not _andar_ate(p, 0.4, dt, 0.9):
				return
			rotation.y = lerp_angle(rotation.y, olhar_posto + sin(_t * 0.4) * 0.8, dt * 2.0)
			pose_caminhada(0.0, 0.0)
		"mecanico", "agricultor":
			rotation.y = lerp_angle(rotation.y, olhar_posto, dt * 4.0)
			_fase += dt
			pose_trabalhar(_fase)
		"idoso":
			rotation.y = lerp_angle(rotation.y, olhar_posto, dt * 4.0)
			pose_sentar()
		"crianca":
			# corre em volta, brincando
			_patrulha += dt * 0.5
			var pc := posto + Vector3(cos(_patrulha), 0, sin(_patrulha * 1.3)) * 1.6
			if _andar_ate(pc, 0.3, dt, 1.8):
				rotation.y = lerp_angle(rotation.y, olhar_posto, dt * 3.0)
				pose_caminhada(0.0, 0.0)
		"medico", "batedor":
			rotation.y = lerp_angle(rotation.y, olhar_posto, dt * 4.0)
			pose_sentar() if dados.funcao == "batedor" else pose_caminhada(0.0, 0.0)
			if dados.funcao == "medico":
				cabeca.rotation.x = 0.25 + sin(_t * 0.7) * 0.05

## Anda até p. Devolve true quando chegou.
func _andar_ate(p: Vector3, perto: float, dt: float, vel := 2.6) -> bool:
	var dir := p - global_position
	dir.y = 0.0
	var d := dir.length()
	if d < perto:
		return true
	dir /= d
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 6.0))
	var nova := global_position + dir * minf(vel * dt, d)
	if main.mundo.colide(global_position, nova, 0.25, true):
		# desvia pela lateral (veículos, cerca)
		var lado := Vector3(-dir.z, 0, dir.x) * minf(vel * dt, d)
		for q in [global_position + lado, global_position - lado]:
			if not main.mundo.colide(global_position, q, 0.25, true):
				nova = q
				break
	if not main.mundo.colide(global_position, nova, 0.25, true):
		nova.y = main.mundo.altura(nova.x, nova.z)
		var cx: float = main.mundo.centro_x(nova.z)
		if absf(nova.x - cx) < WorldGen.LARG_ESTRADA * 0.5 + 0.3:
			nova.y = main.mundo.elevacao(nova.z) + 0.06
		global_position = nova
	_fase += dt * vel * 2.6
	vel_anim = vel
	pose_caminhada(_fase, clampf(vel / 2.6, 0.4, 1.0))
	return false

func _lutar(dt: float) -> void:
	if not is_instance_valid(alvo) or not alvo.vivo():
		alvo = null
		estado = Estado.INDO
		return
	var dz := alvo.global_position - global_position
	dz.y = 0.0
	var d := dz.length()
	if dados.funcao == "vigia":
		rotation.y = lerp_angle(rotation.y, atan2(dz.x, dz.z), minf(1.0, dt * 8.0))
		pose_caminhada(0.0, 0.0)
		pose_mirar(1.0)
		if d < 3.0 and not fixo:
			# muito perto: recua atirando
			var atras := global_position - dz.normalized() * 1.5
			_andar_ate(atras, 0.2, dt, 2.2)
			pose_mirar(1.0)
		if _t_ataque <= 0.0:
			_t_ataque = 1.6
			_t_flash = 0.07
			if modelo:
				tocar("Pistol_Shoot", 1.4, 0.04)
			main.ruido(global_position, 38.0, "tiro")
			Som.em("tiro_rifle", global_position + Vector3(0, 1.4, 0), -2.0, 0.05, 3.0)
			var acerto := 0.8 - clampf((d - 10.0) / 40.0, 0.0, 0.4) + 0.04 * (int(dados.get("nivel", 1)) - 1)
			if assent and main.eh_noite() and not _iluminado(alvo.global_position):
				acerto *= 0.45
			if randf() < acerto:
				alvo.ferir(randf_range(40.0, 70.0), dz.normalized() * 2.0, global_position)
				if not alvo.vivo():
					dados.abates += 1
					main.abate_recruta(self)
		return
	var alcance_golpe := 2.2 if assent else 1.5   # no muro, golpeia por cima/por entre as estacas
	if d > alcance_golpe:
		_andar_ate(alvo.global_position, 1.4, dt, 3.4)
	else:
		rotation.y = lerp_angle(rotation.y, atan2(dz.x, dz.z), minf(1.0, dt * 8.0))
		pose_caminhada(0.0, 0.0)
		if _t_ataque <= 0.0:
			_t_ataque = 1.1
			_anim_golpe = 1.0
			if modelo:
				tocar(["Sword_Regular_A", "Sword_Regular_B", "Sword_Light_A"][randi() % 3] if arma != "" else "Punch_Cross", 1.15)
			var dano := (28.0 if dados.funcao != "batedor" else 40.0) * VidaRecrutas.mult(dados)
			if dados.funcao == "medico":
				dano = 15.0
			if assent and alvo.cerco:
				var lz: Vector3 = assent.local_de(alvo.global_position)
				if Vector2(lz.x, lz.z).length() > Assentamento.R:
					dano *= 0.5   # por cima do muro o golpe sai fraco
			alvo.ferir(dano, dz.normalized() * 2.5, global_position)
			main.ruido(global_position, 8.0)
			if not alvo.vivo():
				dados.abates += 1
				main.abate_recruta(self)
	if _anim_golpe > 0.0 and not modelo:
		var k := 1.0 - _anim_golpe
		ombro_d.rotation.x = lerpf(-2.6, 0.2, smoothstep(0.15, 0.7, k))
		ombro_d.rotation.z = lerpf(0.6, -0.5, smoothstep(0.15, 0.7, k))
		tronco.rotation.y = lerpf(0.4, -0.35, smoothstep(0.15, 0.7, k))

## Holofote do assentamento iluminando o ponto?
func _iluminado(p: Vector3) -> bool:
	if not is_instance_valid(assent):
		return false
	for k in 4:
		if assent.est.holofotes[k]:
			var tp: Vector3 = assent.torre_pos(k)
			var fora = (tp - assent.global_position)
			fora.y = 0.0
			var para := p - tp
			para.y = 0.0
			if para.length() < 36.0 and fora.normalized().dot(para.normalized()) > 0.55:
				return true
	return false

## Trabalho especial na defesa: mecânico tapa o muro, médico cuida dos feridos.
## Devolve true se cuidou do frame.
func _tarefa_defesa(dt: float) -> bool:
	if not is_instance_valid(assent):
		assent = null
		return false
	if papel == "reparos" and estado != Estado.RECUANDO:
		var z := _zumbi_mais_perto()
		if z and z.global_position.distance_to(global_position) < 3.5:
			return false
		if _alvo_reparo < 0 or assent.fracao(_alvo_reparo) > 0.95:
			_alvo_reparo = assent.mais_danificado()
		if _alvo_reparo < 0:
			return false
		var l: Vector3 = Assentamento.ponto(_alvo_reparo, Assentamento.R - 1.3)
		var g: Vector3 = assent.global_de(l)
		if _andar_ate(g, 1.1, dt, 3.0):
			rotation.y = lerp_angle(rotation.y, assent.global_rotation.y + Assentamento.ang(_alvo_reparo), dt * 6.0)
			_fase += dt * 2.0
			pose_trabalhar(_fase)
			assent.reparar(_alvo_reparo, dt * 3.0)
			if randf() < dt * 0.6:
				main.ruido(global_position, 10.0)
		return true
	if papel == "socorro":
		for r in main.recrutas_nos:
			if is_instance_valid(r) and r != self and r.vivo() and r.global_position.distance_to(global_position) < 5.0:
				r.dados.vida = minf(1.0, r.dados.vida + dt * 0.025)
		var j: Node3D = main.jogador
		if j.visible and j.global_position.distance_to(global_position) < 4.0:
			j.vida = minf(1.0, j.vida + dt * 0.015)
	return false
