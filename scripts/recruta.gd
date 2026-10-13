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
	var boca := cotovelo_d.get_node_or_null("Rifle/Boca")
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
	dados.vida = maxf(0.0, dados.vida - d)
	_t_dano = 0.4

func vivo() -> bool:
	return dados.vida > 0.0

func _process(dt: float) -> void:
	if not main or main.get("capturando") and not get_meta("animar_captura", false):
		return
	_t += dt
	_t_ataque = maxf(0.0, _t_ataque - dt)
	_t_busca -= dt
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
		var ferido: bool = dados.vida < 0.3
		if ferido and not fixo:
			estado = Estado.RECUANDO
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
	if _t_dano > 0.0:
		tronco.rotation.x = -0.25 * _t_dano / 0.4

func _zumbi_mais_perto() -> Zumbi:
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

func _no_posto(dt: float) -> void:
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
	if not main.mundo.colide(global_position, nova, 0.25):
		nova.y = main.mundo.altura(nova.x, nova.z)
		var cx: float = main.mundo.centro_x(nova.z)
		if absf(nova.x - cx) < WorldGen.LARG_ESTRADA * 0.5 + 0.3:
			nova.y = main.mundo.elevacao(nova.z) + 0.06
		global_position = nova
	_fase += dt * vel * 2.6
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
			main.ruido(global_position, 38.0, "tiro")
			var acerto := 0.8 - clampf((d - 10.0) / 40.0, 0.0, 0.4)
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
			var dano := 28.0 if dados.funcao != "batedor" else 40.0
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
	if _anim_golpe > 0.0:
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
