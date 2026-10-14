class_name Equipamento
extends Node
## O que o jogador carrega na mão: barra rápida (armas e consumíveis), golpes,
## tiros, recarga, arremessos (molotov e sinalizador) e a armadura vestida.

var main: Node
var sel := "facao"
var pentes := {}            # arma de fogo -> balas no pente
var cond_armas := {}        # arma branca -> 0..1
var armadura := {}          # slot -> {id, reforco (0..3), condicao (0..1)}
var analgesico_t := 0.0     # segundos de efeito
var enjoo_t := 0.0
var _cd := 0.0
var _recarga_t := 0.0
var _uso_t := 0.0
var _uso_id := ""
var _tracos: Array = []
var _golpe_pendente := -1.0   # segundos até o impacto do golpe em curso
var _arremesso_pendente := -1.0
var _arremesso_id := ""

# ------------------------------------------------------------ barra rápida
func slots() -> Array:
	var r: Array = []
	for a in Armas.ORDEM:
		if a == "facao" or main.estoque.get(a, 0) > 0:
			r.append(a)
	for c in Armas.ORDEM_CONSUMIVEIS:
		if main.estoque.get(c, 0) > 0 and r.size() < 9:
			r.append(c)
	return r

func eh_arma(id: String) -> bool:
	return Armas.LISTA.has(id)

func eh_fogo(id: String) -> bool:
	return eh_arma(id) and Armas.LISTA[id].tipo == "fogo"

func info() -> Dictionary:
	return Armas.LISTA.get(sel, {})

func selecionar(id: String) -> void:
	if id == sel:
		return
	sel = id
	_recarga_t = 0.0
	Som.tela("troca_arma", -10.0)
	var visual := id if eh_arma(id) else ("facao" if not main.jogador.corpo.modelo else "")
	if main.jogador.corpo.arma != visual:
		main.jogador.corpo.trocar_arma(visual)

## Itens da barra para o HUD: [id, texto da contagem].
func itens_hud() -> Array:
	var r: Array = []
	for id in slots():
		var txt := ""
		if eh_fogo(id):
			txt = "%d/%d" % [pentes.get(id, 0), main.estoque.get(Armas.LISTA[id].municao, 0)]
		elif eh_arma(id):
			txt = "" if id == "facao" else "%d%%" % int(cond_armas.get(id, 1.0) * 100.0)
		else:
			txt = str(main.estoque.get(id, 0))
		r.append([id, txt])
	return r

func texto_arma() -> String:
	if eh_fogo(sel):
		var a: Dictionary = info()
		return "%s   %d / %d%s" % [a.nome.to_upper(), pentes.get(sel, 0), main.estoque.get(a.municao, 0), "   RECARREGANDO" if _recarga_t > 0.0 else ""]
	if eh_arma(sel):
		return info().nome.to_upper()
	if _uso_t > 0.0:
		return "USANDO..."
	return main.ITENS.get(sel, {}).get("nome", "").to_upper()

func progresso_recarga() -> float:
	if _recarga_t <= 0.0 or not eh_fogo(sel):
		return -1.0
	return 1.0 - _recarga_t / float(info().recarga)

# ------------------------------------------------------------ armadura
func defesa() -> float:
	var d := 0.0
	for slot in armadura:
		var a: Dictionary = armadura[slot]
		d += (Armas.ARMADURA[a.id].defesa + Armas.REFORCO_DEFESA * a.reforco) * (0.4 + 0.6 * a.condicao)
	return clampf(d, 0.0, 0.7)

func protecao_mordida() -> float:
	var p := 0.0
	for slot in armadura:
		var a: Dictionary = armadura[slot]
		p += Armas.ARMADURA[a.id].mordida * (0.5 + 0.5 * a.condicao) + 0.05 * a.reforco
	return clampf(p, 0.0, 0.85)

func peso_armadura() -> float:
	var r := 0.0
	for slot in armadura:
		r += 0.04 + 0.05 * armadura[slot].reforco
	return r

## Dano recebido passa pela armadura; ela se gasta.
func absorver(d: float) -> float:
	var df := defesa()
	if analgesico_t > 0.0:
		df += 0.15
	for slot in armadura:
		var a: Dictionary = armadura[slot]
		a.condicao = maxf(0.0, a.condicao - d * (0.12 - 0.025 * a.reforco))
	return d * (1.0 - clampf(df, 0.0, 0.8))

func vestir(id: String) -> String:
	var slot: String = Armas.ARMADURA[id].slot
	if main.estoque.get(id, 0) <= 0:
		return ""
	main.estoque[id] -= 1
	if armadura.has(slot):
		main.adicionar(armadura[slot].id, 1)
	armadura[slot] = {"id": id, "reforco": 0, "condicao": 1.0}
	main.jogador.atualizar_armadura(armadura)
	return "Vestiu: %s." % Armas.ARMADURA[id].nome

# ------------------------------------------------------------ por frame
func atualizar(dt: float, ativo: bool) -> void:
	_cd = maxf(0.0, _cd - dt)
	analgesico_t = maxf(0.0, analgesico_t - dt)
	enjoo_t = maxf(0.0, enjoo_t - dt)
	if enjoo_t > 0.0:
		main.jogador.vida = maxf(0.05, main.jogador.vida - dt * 0.004)
	_atualizar_tracos(dt)
	if _golpe_pendente >= 0.0:
		_golpe_pendente -= dt
		if _golpe_pendente < 0.0:
			_resolver_golpe()
	if _arremesso_pendente >= 0.0:
		_arremesso_pendente -= dt
		if _arremesso_pendente < 0.0:
			_lancar(_arremesso_id)
	if _recarga_t > 0.0:
		_recarga_t -= dt
		if _recarga_t <= 0.0:
			_terminar_recarga()
	if _uso_t > 0.0:
		_uso_t -= dt
		if _uso_t <= 0.0:
			_terminar_uso()
	if not ativo:
		main.jogador.mirando = false
		return
	var lista := slots()
	if not lista.has(sel):
		selecionar("facao")
	for i in 9:
		if Input.is_action_just_pressed("slot_%d" % (i + 1)) and i < lista.size():
			selecionar(lista[i])
	if Input.is_action_just_pressed("slot_prox") or Input.is_action_just_pressed("slot_ant"):
		var k := lista.find(sel)
		k = posmod(k + (1 if Input.is_action_just_pressed("slot_prox") else -1), lista.size())
		selecionar(lista[k])
	main.jogador.mirando = eh_fogo(sel) and Input.is_action_pressed("mirar")
	main.jogador.zoom = info().get("zoom", 55.0)
	if Input.is_action_just_pressed("recarregar") and eh_fogo(sel) and not String(main.hud.dica).begins_with("[R]"):
		recarregar()
	if Input.is_action_just_pressed("atacar"):
		usar()

func usar() -> void:
	if _uso_t > 0.0:
		return
	if eh_fogo(sel):
		atirar()
	elif eh_arma(sel):
		golpear()
	else:
		consumir(sel)

# ------------------------------------------------------------ corpo a corpo
func golpear() -> void:
	var a: Dictionary = info()
	if _cd > 0.0 or main.jogador.estamina < 0.08:
		return
	_cd = a.cad + peso_armadura() * 0.5
	_golpe_pendente = main.jogador.golpear(a.estamina + peso_armadura() * 0.05)
	Som.em("golpe_ar_pesado" if sel in ["machado", "taco"] else "golpe_ar", main.jogador.global_position + Vector3(0, 1.3, 0), -4.0, 0.12)
	main.ruido(main.jogador.global_position, a.ruido * 0.5)

## O dano do golpe sai no meio da animação (quando a lâmina passa na frente).
func _resolver_golpe() -> void:
	var a: Dictionary = info()
	if a.is_empty() or eh_fogo(sel):
		return
	var j: Node3D = main.jogador
	var origem: Vector3 = j.global_position
	var frente := Vector3(sin(j.yaw), 0, cos(j.yaw))
	main.ruido(origem, a.ruido)
	var acertou := false
	for alvo in _alvos_vivos():
		var v: Vector3 = alvo.global_position - origem
		v.y = 0.0
		var d := v.length()
		if d < a.alcance and (d < 0.6 or v.normalized().dot(frente) > 0.45):
			var dano := randf_range(a.dano[0], a.dano[1])
			if alvo is Zumbi and j.agachado and alvo.estado == Zumbi.Estado.VAGANDO:
				dano *= 3.0   # golpe furtivo
			_ferir(alvo, dano, frente * a.empurrao, origem)
			acertou = true
	if acertou:
		main.hud.acerto()
		main.jogador.tremer(0.35 if sel != "machado" else 0.55)
		if main.has_method("impacto"):
			main.impacto(0.05 if sel != "machado" else 0.08)
		if a.durab > 0:
			cond_armas[sel] = cond_armas.get(sel, 1.0) - 1.0 / float(a.durab)
			if cond_armas[sel] <= 0.0:
				main.estoque[sel] = maxi(0, main.estoque.get(sel, 0) - 1)
				cond_armas.erase(sel)
				main.hud.aviso("%s quebrou!" % a.nome)

func _alvos_vivos() -> Array:
	var r: Array = []
	for z in main.mundo.zumbis_vivos:
		if is_instance_valid(z) and z.vivo():
			r.append(z)
	for an in main.mundo.animais:
		if is_instance_valid(an) and an.vivo():
			r.append(an)
	return r

func _ferir(alvo: Node3D, dano: float, empurrao: Vector3, origem: Vector3) -> void:
	alvo.ferir(dano, empurrao, origem)
	if not alvo.vivo():
		if alvo is Zumbi:
			main.abates += 1
			main.defesa.abateu(alvo)

# ------------------------------------------------------------ armas de fogo
func atirar() -> void:
	var a: Dictionary = info()
	if _cd > 0.0 or _recarga_t > 0.0:
		return
	if pentes.get(sel, 0) <= 0:
		Som.tela("vazio", -4.0)
		if main.estoque.get(a.municao, 0) > 0:
			recarregar()
		else:
			main.hud.aviso("Sem munição (%s)." % main.ITENS[a.municao].nome.to_lower())
			_cd = 0.4
		return
	_cd = a.cad
	pentes[sel] -= 1
	var j: Player = main.jogador
	var cam: Camera3D = j.camera
	var o := cam.global_position
	var fr := -cam.global_transform.basis.z
	var disp: float = a.disp * (0.5 if j.mirando else 1.6) * (0.7 if j.agachado else 1.0) * (1.0 + j.intensidade * 0.8)
	var boca := _boca()
	var hits := 0
	for p in a.projeteis:
		var d := (fr + cam.global_transform.basis.x * randf_range(-disp, disp) + cam.global_transform.basis.y * randf_range(-disp, disp)).normalized()
		var res := _raio(o, d, a.alcance)
		var fim: Vector3 = o + d * a.alcance
		if not res.is_empty():
			fim = res.ponto
			var dano := randf_range(a.dano[0], a.dano[1])
			if res.distancia > a.alcance * 0.6:
				dano *= 0.6
			if res.cabeca:
				dano *= 2.2
			_ferir(res.alvo, dano, d * 3.0, j.global_position)
			hits += 1
		_traco(boca, fim, sel == "besta")
	if hits > 0:
		main.hud.acerto()
	main.ruido(j.global_position, a.ruido, "tiro")
	j.pitch = clampf(j.pitch + a.coice, -1.0, 0.6)
	j.flash_tiro()
	Som.em({"pistola": "tiro_pistola", "espingarda": "tiro_espingarda", "rifle": "tiro_rifle", "besta": "golpe_ar"}.get(sel, "tiro_pistola"), j.global_position + Vector3(0, 1.4, 0), 0.0 if sel != "besta" else -6.0, 0.05, 4.0)
	j.tremer(0.25 + a.coice * 4.0)
	if j.corpo.modelo:
		j.corpo.tocar("Pistol_Shoot", 1.6 if sel == "pistola" else 1.1, 0.03)

## O alvo (zumbi ou animal) mais perto ao longo do raio. {alvo, ponto, distancia, cabeca}
func _raio(o: Vector3, d: Vector3, alcance: float) -> Dictionary:
	var melhor := {}
	var md := alcance
	for alvo in _alvos_vivos():
		var esc: float = alvo.scale.x
		var alt: float = alvo.altura_alvo() if alvo.has_method("altura_alvo") else 1.1
		var c: Vector3 = alvo.global_position + Vector3(0, alt * esc, 0)
		var t := (c - o).dot(d)
		if t < 0.3 or t > md:
			continue
		var perto := o + d * t
		var raio: float = (alvo.raio_alvo() if alvo.has_method("raio_alvo") else 0.42) * esc
		if perto.distance_to(c) < raio:
			var cabeca := false
			if alvo is Zumbi and alvo.tipo != "rastejante":
				var hc: Vector3 = alvo.global_position + Vector3(0, 1.62 * esc, 0)
				var th := (hc - o).dot(d)
				cabeca = (o + d * th).distance_to(hc) < 0.17 * esc
			md = t
			melhor = {"alvo": alvo, "ponto": perto, "distancia": t, "cabeca": cabeca}
	return melhor

func _boca() -> Vector3:
	var c: Node = main.jogador.corpo
	var b: Node3D = c.find_child("Boca", true, false)
	return b.global_position if b else main.jogador.global_position + Vector3(0, 1.4, 0)

func _traco(de: Vector3, ate: Vector3, flecha: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var comp := de.distance_to(ate)
	bm.size = Vector3(0.012 if not flecha else 0.03, 0.012 if not flecha else 0.03, comp)
	mi.mesh = bm
	mi.material_override = B.emissive(Color(1.0, 0.85, 0.5), 4.0) if not flecha else B.mat(Color(0.4, 0.3, 0.2))
	main.add_child(mi)
	mi.look_at_from_position((de + ate) * 0.5, ate, Vector3.UP if absf((ate - de).normalized().y) < 0.99 else Vector3.RIGHT)
	_tracos.append([mi, 0.06 if not flecha else 0.25])

func _atualizar_tracos(dt: float) -> void:
	for t in _tracos.duplicate():
		t[1] -= dt
		if t[1] <= 0.0:
			if is_instance_valid(t[0]):
				t[0].queue_free()
			_tracos.erase(t)

func recarregar() -> void:
	var a: Dictionary = info()
	if _recarga_t > 0.0 or pentes.get(sel, 0) >= a.pente or main.estoque.get(a.municao, 0) <= 0:
		return
	_recarga_t = a.recarga
	main.ruido(main.jogador.global_position, 5.0)
	Som.tela("recarga", -3.0)
	var corpo: Humanoid = main.jogador.corpo
	if corpo.modelo:
		var dur := corpo.tem_anim("Pistol_Reload")
		if dur:
			var l: float = corpo._ap.get_animation("q/Pistol_Reload").length
			corpo.tocar("Pistol_Reload", l / maxf(0.5, float(a.recarga)), 0.1)

func _terminar_recarga() -> void:
	var a: Dictionary = info()
	if a.is_empty() or not eh_fogo(sel):
		return
	var falta: int = a.pente - pentes.get(sel, 0)
	var tem: int = main.estoque.get(a.municao, 0)
	var n := mini(falta, tem)
	pentes[sel] = pentes.get(sel, 0) + n
	main.estoque[a.municao] = tem - n

# ------------------------------------------------------------ consumíveis
func consumir(id: String) -> void:
	if main.estoque.get(id, 0) <= 0 or not Armas.CONSUMIVEIS.has(id):
		return
	var c: Dictionary = Armas.CONSUMIVEIS[id]
	if c.get("arremesso", false):
		arremessar(id)
		return
	_uso_t = c.tempo
	_uso_id = id
	main.jogador.golpear(0.0, true)
	var dur: float = main.jogador.tocar_acao(id)
	Som.tela({"agua": "beber", "remedio": "beber", "bandagem": "enfaixar"}.get(id, "comer"), -4.0)
	if dur > 0.0:
		_uso_t = maxf(c.tempo, dur * 0.85)

func _terminar_uso() -> void:
	var id := _uso_id
	if main.estoque.get(id, 0) <= 0:
		return
	var c: Dictionary = Armas.CONSUMIVEIS[id]
	var j: Player = main.jogador
	main.estoque[id] -= 1
	j.vida = clampf(j.vida + c.get("vida", 0.0), 0.0, 1.0)
	j.fome = clampf(j.fome + c.get("fome", 0.0), 0.0, 1.0)
	j.sede = clampf(j.sede + c.get("sede", 0.0), 0.0, 1.0)
	if c.has("estamina"):
		j.estamina = c.estamina
	if c.has("infeccao"):
		j.infeccao = maxf(0.0, j.infeccao + c.infeccao)
	if c.get("efeito", "") == "analgesico":
		analgesico_t = 90.0
	var txt: String = c.texto
	if main.get("saude"):
		main.saude.comeu(id)
		txt += main.saude.tratar(id)
	if c.has("enjoo") and randf() < c.enjoo:
		enjoo_t = 60.0
		txt += " Seu estômago revirou."
	main.hud.aviso(txt)

# ------------------------------------------------------------ arremessos
func arremessar(id: String) -> void:
	if _cd > 0.0:
		return
	_cd = 0.9
	main.estoque[id] -= 1
	var j: Player = main.jogador
	_arremesso_pendente = j.golpear(0.03, false, "arremesso") if j.corpo.modelo else 0.0
	_arremesso_id = id

func _lancar(id: String) -> void:
	var j: Player = main.jogador
	var cam: Camera3D = j.camera
	var d := -cam.global_transform.basis.z
	d.y = maxf(d.y, -0.2) + 0.35
	var v = Arremesso.new()
	v.main = main
	v.tipo = id
	v.velocidade = d.normalized() * 13.0
	main.add_child(v)
	v.global_position = j.global_position + Vector3(0, 1.6, 0) + Vector3(sin(j.yaw), 0, cos(j.yaw)) * 0.5
