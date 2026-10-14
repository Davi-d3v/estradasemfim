class_name CombateComboio
extends Node
## Combate com o comboio em movimento:
##  - zumbis que alcançam a picape ou o trailer se AGARRAM na lataria, batem,
##    seguram o comboio e, se a proteção das janelas for fraca, alcançam o motorista;
##  - para soltá-los: ziguezague (volante de um lado para o outro), acelerar forte,
##    frear de repente, espinhos na lataria ou o atirador da caçamba;
##  - atirador: um vigia em pé na caçamba (precisa do Posto de tiro) que atira sozinho
##    nos zumbis perto, primeiro nos agarrados; gasta munição do estoque.

const MAX_AGARRADOS := 5

var main: Node
var agarrados: Array = []      # [{z, veic, local, t_golpe}]
var atirador: Humanoid
var _t_tiro := 0.0
var _esterco_ant := 0.0
var _chacoalho := 0.0          # quanto o volante balançou recentemente
var _vel_ant := 0.0
var _t_aviso := 0.0

func _process(dt: float) -> void:
	if main == null or not main.jogando or main.get("_morto"):
		return
	var c: Comboio = main.comboio
	_atualizar_atirador(c)
	if not c.dirigindo:
		if not agarrados.is_empty():
			for g in agarrados.duplicate():
				_soltar(g, Vector3.ZERO, 0.0)
		return
	var vel := absf(c.velocidade)
	# balançar o volante
	_chacoalho = maxf(0.0, _chacoalho - dt * 1.2)
	if absf(c.esterco - _esterco_ant) > 0.0:
		_chacoalho += absf(c.esterco - _esterco_ant) * clampf(vel / 8.0, 0.0, 1.0)
	_esterco_ant = c.esterco
	var freada := (_vel_ant - vel) / maxf(dt, 0.001)
	_vel_ant = vel
	_procurar_novos(c, vel)
	_segurar(c, dt, vel, freada)
	_atirar(c, dt)
	# aviso na tela
	_t_aviso -= dt
	if not agarrados.is_empty() and _t_aviso <= 0.0:
		_t_aviso = 4.0
		main.hud.aviso("%d zumbi%s agarrado%s no comboio! Balance o volante, acelere ou freie de repente." % [agarrados.size(), "" if agarrados.size() == 1 else "s", "" if agarrados.size() == 1 else "s"])

## O comboio fica mais pesado com gente pendurada.
func fator_velocidade() -> float:
	return 1.0 - 0.07 * agarrados.size()

func _procurar_novos(c: Comboio, vel: float) -> void:
	if agarrados.size() >= MAX_AGARRADOS or vel < 1.5 or vel > 15.0:
		return
	var veics: Array = [main.picape, main.trailer]
	for z in main.mundo.zumbis_vivos:
		if not is_instance_valid(z) or not z.vivo() or z.get_meta("agarrado", false):
			continue
		if z.estado != Zumbi.Estado.PERSEGUINDO and z.estado != Zumbi.Estado.ATACANDO:
			continue
		if z.tipo == "rastejante" or z.tipo == "brutamonte":
			continue
		if z.global_position.distance_to(c.pos) > 14.0:
			continue
		for v in veics:
			var local: Vector3 = (v as Node3D).global_transform.affine_inverse() * z.global_position
			var meia := (Pickup.LARGURA if v == main.picape else Trailer.LARGURA) * 0.5
			var comp_min := -2.7 if v == main.picape else -Trailer.COMPRIMENTO * 0.5
			var comp_max := 1.2 if v == main.picape else Trailer.COMPRIMENTO * 0.5
			if absf(local.x) > meia + 0.2 and absf(local.x) < meia + 1.1 and local.z > comp_min and local.z < comp_max:
				# espinhos fazem muitos desistirem de agarrar
				var esp: int = _nivel_espinhos(v)
				if randf() < esp * 0.3:
					z.ferir(18.0 * esp, Vector3(signf(local.x), 0, 0) * 3.0, v.global_position)
					continue
				_agarrar(z, v, Vector3(signf(local.x) * (meia + 0.28), 0.0, clampf(local.z, comp_min + 0.3, comp_max - 0.3)))
				return

func _agarrar(z: Zumbi, v: Node3D, local: Vector3) -> void:
	z.set_meta("agarrado", true)
	z.set_process(false)
	agarrados.append({"z": z, "veic": v, "local": local, "t_golpe": randf_range(0.6, 1.4)})
	Som.em("zumbi_ataque", z.global_position + Vector3(0, 1.5, 0), 3.0, 0.1, 2.0)
	Som.em("impacto_metal", z.global_position + Vector3(0, 1.0, 0), 0.0, 0.2)
	if z.modelo:
		z.loop("Zombie_Scratch", 1.2)

func _segurar(c: Comboio, dt: float, vel: float, freada: float) -> void:
	for g in agarrados.duplicate():
		var z: Zumbi = g.z
		var v: Node3D = g.veic
		if not is_instance_valid(z) or not z.vivo() or not is_instance_valid(v):
			agarrados.erase(g)
			if is_instance_valid(z):
				z.set_meta("agarrado", false)
				z.set_process(true)
			continue
		# pendurado do lado de fora, virado para a lataria, os pés arrastando no chão
		var lado := signf(g.local.x)
		var p: Vector3 = v.global_transform * g.local
		p.y = main.mundo.altura(p.x, p.z) if absf(p.x - main.mundo.centro_x(p.z)) > WorldGen.LARG_ESTRADA * 0.5 else main.mundo.elevacao(p.z) + 0.06
		p.y += 0.25
		z.global_position = p
		z.rotation.y = v.global_rotation.y + (-PI * 0.5 if lado > 0 else PI * 0.5)
		z.rotation.z = lerpf(z.rotation.z, -lado * clampf(vel / 30.0, 0.0, 0.35), 0.1)
		# espinhos machucam quem se segura
		var esp := _nivel_espinhos(v)
		if esp > 0:
			z.ferir(esp * 14.0 * dt)
		# bate na lataria ou alcança a janela
		g.t_golpe -= dt
		if g.t_golpe <= 0.0:
			g.t_golpe = randf_range(1.1, 1.8)
			_golpe(z, v)
		# soltar
		var chance := 0.0
		if vel > 15.0:
			chance += (vel - 15.0) * 0.05 * dt
		if _chacoalho > 0.9:
			chance += 0.9 * dt * _chacoalho
		if freada > 9.0:
			chance += 0.5
		if randf() < chance:
			_soltar(g, Vector3(lado, 0, 0), vel)

func _golpe(z: Zumbi, v: Node3D) -> void:
	Som.em("impacto_metal", z.global_position + Vector3(0, 1.2, 0), -2.0, 0.2)
	if z.modelo:
		z.tocar("Zombie_Scratch", 1.2)
	if v == main.picape:
		var prot: int = main.picape.nivel("protecao")
		var slot: String = ["protecao", "santo_antonio", "pneus", "cacamba"][randi() % 4]
		main.picape.config[slot].condicao = maxf(0.0, main.picape.config[slot].condicao - 0.012 * (1.0 - prot * 0.3))
		# pelo vidro: sem tela, alcança o motorista (se for do lado do motorista ou o vidro já estiver quebrado)
		var vidro: float = 1.0 - prot * 0.45 - main.picape.config.protecao.condicao * prot * 0.1
		if randf() < 0.35 * vidro:
			main.jogador.levar_dano(main.equip.absorver(z.info().dano / 100.0 * 0.8))
			main.hud.dano()
			if randf() < 0.06 * vidro * (1.0 - main.equip.protecao_mordida()):
				main.jogador.infeccao = maxf(main.jogador.infeccao, 0.05)
				main.hud.aviso("Ele te mordeu pela janela! Tome um remédio [H].")
	else:
		var blind: int = main.trailer.config.get("couraca", {}).get("nivel", 0)
		main.trailer.condicao_carroceria = maxf(0.05, main.trailer.condicao_carroceria - 0.008 * (1.0 - blind * 0.35))
		var slots: Array = main.trailer.config.keys()
		var s: String = slots[randi() % slots.size()]
		main.trailer.config[s].condicao = maxf(0.0, main.trailer.config[s].condicao - 0.01 * (1.0 - blind * 0.35))

func _soltar(g: Dictionary, dir: Vector3, vel: float) -> void:
	agarrados.erase(g)
	var z: Zumbi = g.z
	if not is_instance_valid(z):
		return
	z.set_meta("agarrado", false)
	z.set_process(true)
	z.rotation.z = 0.0
	if vel > 0.0 and is_instance_valid(g.veic):
		var mundo_dir: Vector3 = (g.veic as Node3D).global_transform.basis * dir
		z.global_position += mundo_dir.normalized() * 0.8
		z.ferir(vel * 3.5, mundo_dir.normalized() * (4.0 + vel * 0.3), (g.veic as Node3D).global_position)
		Som.em("impacto_carne", z.global_position + Vector3(0, 0.8, 0), 2.0, 0.15)

func _nivel_espinhos(v: Node3D) -> int:
	if v == main.picape:
		return main.picape.config.get("espinhos", {}).get("nivel", 0)
	return 1 if main.trailer.config.get("couraca", {}).get("nivel", 0) >= 2 else 0

# ------------------------------------------------------------ atirador da caçamba
func _vigia_atirador() -> Dictionary:
	for rc in main.base.presentes("vigia"):
		return rc
	return {}

func _atualizar_atirador(c: Comboio) -> void:
	var posto: int = main.picape.config.get("posto_tiro", {}).get("nivel", 0)
	var rc := _vigia_atirador()
	var deve := c.dirigindo and posto >= 1 and not rc.is_empty()
	if deve and not is_instance_valid(atirador):
		atirador = Humanoid.new()
		atirador.semente = int(rc.get("semente", 7))
		atirador.feminino = String(rc.nome).ends_with("a")
		atirador.visual = "soldado"
		atirador.arma = "rifle"
		atirador.anim_parado = "Pistol_Idle"
		atirador.name = "Atirador"
		main.picape.add_child(atirador)
		atirador.position = Vector3(0.0, main.picape.elevacao() + 0.98, -1.65)
		atirador.set_meta("nome", rc.nome)
	elif not deve and is_instance_valid(atirador):
		atirador.queue_free()
		atirador = null

func _atirar(c: Comboio, dt: float) -> void:
	if not is_instance_valid(atirador):
		return
	var posto: int = main.picape.config.posto_tiro.nivel
	_t_tiro -= dt
	if _t_tiro > 0.0:
		return
	var est: Dictionary = main.estoque
	var mun := "municao_rifle" if est.get("municao_rifle", 0) > 0 else ("municao_pistola" if est.get("municao_pistola", 0) > 0 else "")
	if mun == "":
		return
	# alvo: agarrados primeiro, depois o mais perto até 28 m
	var alvo: Zumbi = null
	if not agarrados.is_empty():
		alvo = agarrados[0].z
	else:
		var dmin := 28.0
		for z in main.mundo.zumbis_vivos:
			if is_instance_valid(z) and z.vivo() and z.estado != Zumbi.Estado.VAGANDO:
				var d: float = z.global_position.distance_to(atirador.global_position)
				if d < dmin:
					dmin = d
					alvo = z
	if alvo == null:
		return
	_t_tiro = (1.3 if mun == "municao_rifle" else 0.8) / (1.0 + 0.4 * (posto - 1))
	est[mun] -= 1
	var o := atirador.global_position + Vector3(0, 1.5, 0)
	var para := alvo.global_position + Vector3(0, 1.3, 0)
	atirador.rotation.y = atan2(para.x - o.x, para.z - o.z) - main.picape.global_rotation.y
	atirador.tocar("Pistol_Shoot", 1.4)
	Som.em("tiro_rifle" if mun == "municao_rifle" else "tiro_pistola", o, 0.0, 0.08, 4.0)
	main.ruido(o, 45.0, "tiro")
	# chance de acerto: pior com o comboio pulando, melhor com posto nível 2
	var chance := 0.55 + 0.15 * (posto - 1) - clampf(absf(c.velocidade) / 60.0, 0.0, 0.25)
	if randf() < chance:
		alvo.ferir(75.0 if mun == "municao_rifle" else 40.0, (para - o).normalized() * 3.0, o)
		if not alvo.vivo():
			main.abates += 1
			var rc := _vigia_atirador()
			if not rc.is_empty():
				rc.abates = rc.get("abates", 0) + 1
