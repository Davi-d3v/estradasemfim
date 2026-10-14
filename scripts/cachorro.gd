class_name Cachorro
extends Node3D
## O cachorro do comboio. Segue você a pé, viaja na caçamba, late quando zumbis
## chegam perto (antes de você ver), fareja saque escondido e ajuda a caçar:
## corre atrás do bicho ferido e morde. Também defende você de zumbi colado.
## Se apanhar muito, foge ganindo; com vida zero, morre de verdade.

enum Estado { SEGUINDO, FAREJANDO, CACANDO, DEFENDENDO, FERIDO, PARADO, NA_CACAMBA, MORTO }

const NOMES := ["Rex", "Bidu", "Pipoca", "Thor", "Mel", "Caramelo", "Faísca", "Pandora", "Tobias", "Luna"]

var main: Node
var nome := "Caramelo"
var raca := "husky"
var vida := 1.0
var ficar := false            # ordem de ficar parado
var estado := Estado.SEGUINDO
var _mod := {}
var _ap: AnimationPlayer
var _anim := ""
var _oneshot := false
var _alvo: Node3D = null
var _t_latido := 0.0
var _t_mordida := 0.0
var _t_faro := 4.0
var _t_ferido := 0.0
var _faro: Node3D = null      # vasculhável que ele achou
var _avisou_faro := {}
var _rumo_ofs := 0.0

func _ready() -> void:
	_mod = Modelos.animal(raca)
	if not _mod.is_empty():
		add_child(_mod.raiz)
		_ap = _mod.player
		_ap.animation_finished.connect(func(_n): _oneshot = false)
	_rumo_ofs = randf_range(-0.6, 0.6)

func vivo() -> bool:
	return estado != Estado.MORTO

func _tocar(n: String, vel := 1.0, unica := false) -> void:
	if _ap == null or not _ap.has_animation(n):
		return
	if unica:
		_oneshot = true
		_anim = n
		_ap.play(n, 0.1)
		_ap.seek(0.0, true)
		_ap.speed_scale = vel
		return
	if _oneshot:
		return
	if _anim != n:
		_anim = n
		_ap.play(n, 0.25)
	_ap.speed_scale = vel

## Em pé na caçamba da picape.
func posicionar_cacamba() -> void:
	var pc: Node3D = main.picape
	global_position = pc.global_transform * Vector3(0.3, pc.elevacao() + 0.95, -2.6)
	rotation = Vector3(0, pc.global_rotation.y, 0)

func _chao(p: Vector3) -> float:
	return main.jogador.chao(p)

# ------------------------------------------------------------ a cada quadro
func _process(dt: float) -> void:
	if main == null or not main.jogando or main.get("capturando"):
		return
	if estado == Estado.MORTO:
		return
	_t_latido -= dt
	_t_mordida -= dt
	var c: Comboio = main.comboio
	# viajando: em pé na caçamba
	if c.dirigindo:
		if estado != Estado.NA_CACAMBA:
			estado = Estado.NA_CACAMBA
		posicionar_cacamba()
		_tocar("Idle" if absf(c.velocidade) < 1.0 else "Idle_2")
		_vigiar(dt)
		return
	elif estado == Estado.NA_CACAMBA:
		estado = Estado.SEGUINDO
		var pc2: Node3D = main.picape
		global_position = pc2.global_transform * Vector3(1.6, 0, -2.2)
		global_position.y = _chao(global_position)
	var j: Player = main.jogador
	var jp: Vector3 = j.global_position if j.visible else main.trailer.global_position
	_vigiar(dt)
	var vel := 0.0
	var destino := global_position
	match estado:
		Estado.FERIDO:
			_t_ferido -= dt
			destino = global_position + (global_position - _ameaca_perto()).normalized() * 4.0
			vel = 5.0
			if _t_ferido <= 0.0:
				estado = Estado.SEGUINDO
		Estado.DEFENDENDO, Estado.CACANDO:
			var coleira := 90.0 if estado == Estado.CACANDO else 40.0
			if not is_instance_valid(_alvo) or not _alvo.vivo() or _alvo.global_position.distance_to(jp) > coleira:
				_alvo = null
				estado = Estado.SEGUINDO
			else:
				destino = _alvo.global_position
				var d := Vector2(destino.x - global_position.x, destino.z - global_position.z).length()
				vel = (10.5 if estado == Estado.CACANDO else 7.0) if d > 1.4 else 0.0
				if d < 1.6 and _t_mordida <= 0.0:
					_morder()
		Estado.FAREJANDO:
			if not is_instance_valid(_faro) or main.mundo.vasculhados.has(_faro.get_meta("chave")):
				_faro = null
				estado = Estado.SEGUINDO
			else:
				destino = _faro.global_position
				var d2 := Vector2(destino.x - global_position.x, destino.z - global_position.z).length()
				vel = 3.2 if d2 > 1.5 else 0.0
				if d2 <= 1.5 and _t_latido <= 0.0:
					_latir(0.0, false)
					_t_latido = 5.0
				if jp.distance_to(global_position) > 30.0:
					estado = Estado.SEGUINDO
		Estado.PARADO:
			vel = 0.0
			if not ficar:
				estado = Estado.SEGUINDO
		_:
			if ficar:
				estado = Estado.PARADO
			else:
				# segue o dono a uns 2,5 m, um pouco de lado
				var atras := Vector3(sin(j.yaw + PI + _rumo_ofs), 0, cos(j.yaw + PI + _rumo_ofs)) * 2.4
				destino = jp + atras
				var d3 := Vector2(destino.x - global_position.x, destino.z - global_position.z).length()
				vel = 0.0 if d3 < 0.8 else (2.0 if d3 < 4.0 else (5.5 if d3 < 15.0 else 8.0))
				if d3 > 60.0:
					global_position = jp + atras
					global_position.y = _chao(global_position)
				_procurar_tarefa(jp, dt)
	# anda
	var dir := destino - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 6.0))
	if vel > 0.0:
		var passo := Vector3(sin(rotation.y), 0, cos(rotation.y)) * vel * dt
		var nova := global_position + passo
		if not main.mundo.colide(global_position, nova, 0.25):
			nova.y = _chao(nova)
			global_position = nova
	if vel > 4.0:
		_tocar("Gallop", clampf(vel / 7.0, 0.8, 1.4))
	elif vel > 0.1:
		_tocar("Walk", clampf(vel / 2.0, 0.7, 1.5))
	elif estado == Estado.FAREJANDO:
		_tocar("Idle_2_HeadLow")
	else:
		_tocar("Idle")

func _ameaca_perto() -> Vector3:
	var melhor := global_position + Vector3(1, 0, 0)
	var dmin := INF
	for z in main.mundo.zumbis_vivos:
		if is_instance_valid(z) and z.vivo():
			var d: float = z.global_position.distance_to(global_position)
			if d < dmin:
				dmin = d
				melhor = z.global_position
	return melhor

## Late quando um zumbi chega perto — mesmo que você não esteja vendo.
func _vigiar(_dt: float) -> void:
	if _t_latido > 0.0:
		return
	var noite: bool = main.eh_noite()
	var raio := 32.0 if not noite else 40.0
	var perto: Zumbi = null
	var dmin := raio
	for z in main.mundo.zumbis_vivos:
		if is_instance_valid(z) and z.vivo() and not z.get_meta("agarrado", false):
			var d: float = z.global_position.distance_to(global_position)
			if d < dmin:
				dmin = d
				perto = z
	if perto:
		_t_latido = randf_range(5.0, 8.0)
		_latir(dmin, true, perto.global_position)
		# zumbi colado no dono: ataca
		var j: Player = main.jogador
		if j.visible and estado in [Estado.SEGUINDO, Estado.PARADO, Estado.FAREJANDO] and perto.global_position.distance_to(j.global_position) < 6.0 and vida > 0.35:
			_alvo = perto
			estado = Estado.DEFENDENDO

func _latir(dist: float, aviso: bool, de := Vector3.ZERO) -> void:
	Som.em("latido", global_position + Vector3(0, 0.6, 0), 2.0, 0.08, 3.0)
	if not main.comboio.dirigindo and _ap:
		_tocar("Idle_HitReact2", 1.4, true)
	if aviso and dist > 8.0:
		var dirs := ["norte", "noroeste", "oeste", "sudoeste", "sul", "sudeste", "leste", "nordeste"]
		var ang := fposmod(atan2(-(de.x - global_position.x), de.z - global_position.z), TAU)
		main.hud.aviso("%s está latindo para o %s. Tem coisa vindo (%d m)." % [nome, dirs[int(round(ang / (TAU / 8.0))) % 8], int(dist)])

## Fareja saque perto e ajuda na caça.
func _procurar_tarefa(jp: Vector3, dt: float) -> void:
	# caça: bicho ferido ou fugindo perto do dono
	for an in main.mundo.animais:
		if is_instance_valid(an) and an.vivo() and an.global_position.distance_to(jp) < 30.0 and (an.vida < an.info().vida or an.estado == Animal.Estado.FUGINDO):
			if an.tipo != "lobo" or vida > 0.6:
				_alvo = an
				estado = Estado.CACANDO
				return
	_t_faro -= dt
	if _t_faro > 0.0:
		return
	_t_faro = 3.0
	var melhor: Node3D = null
	var dmin := 22.0
	for v in main.mundo.vasculhaveis:
		if not is_instance_valid(v) or main.mundo.vasculhados.has(v.get_meta("chave")) or _avisou_faro.has(v.get_meta("chave")):
			continue
		if absf(v.global_position.y - global_position.y) > 2.5:
			continue
		var d: float = v.global_position.distance_to(global_position)
		if d < dmin:
			dmin = d
			melhor = v
	if melhor:
		_avisou_faro[melhor.get_meta("chave")] = true
		_faro = melhor
		estado = Estado.FAREJANDO
		main.hud.aviso("%s farejou alguma coisa: %s." % [nome, String(melhor.get_meta("nome")).to_lower()])

func _morder() -> void:
	_t_mordida = 1.1
	_tocar("Attack", 1.3, true)
	Som.em("latido", global_position + Vector3(0, 0.5, 0), 0.0, 0.15)
	if _alvo is Zumbi:
		var z: Zumbi = _alvo
		z.ferir(14.0, (z.global_position - global_position).normalized() * 2.0, global_position)
		if not z.vivo():
			main.abates += 1
		# zumbi revida
		if z.vivo() and randf() < 0.35:
			ferir(0.12)
	elif _alvo is Animal:
		var a: Animal = _alvo
		a.ferir(22.0, (a.global_position - global_position).normalized() * 1.5, global_position)
		if a.tipo in ["lobo", "javali"] and a.vivo() and randf() < 0.3:
			ferir(0.1)
		if not a.vivo():
			main.hud.aviso("%s derrubou o %s!" % [nome, a.info().nome])
			_alvo = null
			estado = Estado.SEGUINDO

func ferir(d: float) -> void:
	if estado == Estado.MORTO:
		return
	vida = maxf(0.0, vida - d)
	Som.em("ganido", global_position + Vector3(0, 0.5, 0), 0.0, 0.1)
	if vida <= 0.0:
		estado = Estado.MORTO
		_oneshot = false
		_tocar("Death", 1.0, true)
		main.hud.banner("%s morreu" % nome, "Ele ficou do seu lado até o fim.")
		main.registrar("%s morreu defendendo o comboio." % nome)
		return
	if vida < 0.35:
		estado = Estado.FERIDO
		_t_ferido = 6.0
		_alvo = null

## Recebe um golpe de zumbi (chamado quando ele é o alvo).
func painel() -> Dictionary:
	var linhas: Array = ["Raça: %s · Saúde: %d%%" % ["husky" if raca == "husky" else "shiba", int(vida * 100.0)],
		["Late quando zumbis chegam perto, fareja saque e ajuda a caçar (corre atrás do bicho ferido).", Color(0.7, 0.7, 0.68)]]
	return {"titulo": nome.to_upper(), "subtitulo": "Bom garoto." if vida > 0.5 else "Está machucado.", "linhas": linhas,
		"botoes": [
			["Fazer carinho", func(): _tocar("Idle_2_HeadLow", 1.0, true); return "%s abana o rabo." % nome, true],
			["Dar comida (+30% saúde)", func(): return _comer(), main.estoque.get("comida", 0) > 0 or main.estoque.get("carne_crua", 0) > 0],
			["Tratar com bandagem (+50%)", func(): return _tratar(), main.estoque.get("bandagem", 0) > 0 and vida < 1.0],
			["Fica!" if not ficar else "Vem!", func(): ficar = not ficar; return ("%s senta e espera." if ficar else "%s vem correndo.") % nome, true],
		]}

func _comer() -> String:
	if main.estoque.get("carne_crua", 0) > 0:
		main.estoque.carne_crua -= 1
	else:
		main.estoque.comida -= 1
	vida = minf(1.0, vida + 0.3)
	_tocar("Eating", 1.0, true)
	return "%s comeu tudo em dois segundos." % nome

func _tratar() -> String:
	main.estoque.bandagem -= 1
	vida = minf(1.0, vida + 0.5)
	return "Você enfaixou a pata do %s." % nome

func salvar() -> Dictionary:
	return {"nome": nome, "raca": raca, "vida": vida, "ficar": ficar, "pos": global_position}
