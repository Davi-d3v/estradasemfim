class_name Clima
extends Node
## Tempo e estações. Muda sozinho de algumas em algumas horas de jogo.
## Estados: limpo, nublado, chuva, tempestade, neblina, neve (só no inverno).
## Efeitos: partículas que seguem a câmera, céu fechado, névoa, relâmpagos,
## asfalto molhado, pista lisa, zumbis que escutam/enxergam menos, horda mais
## rápida na tempestade.

const ESTACOES := ["Verão", "Outono", "Inverno", "Primavera"]
const DIAS_ESTACAO := 10
const NOMES := {"limpo": "Céu limpo", "nublado": "Nublado", "chuva": "Chuva", "tempestade": "Tempestade", "neblina": "Neblina", "neve": "Neve"}
## pesos por estação
const PESOS := {
	"Verão": {"limpo": 5.0, "nublado": 2.0, "chuva": 1.5, "tempestade": 1.2, "neblina": 0.4},
	"Outono": {"limpo": 3.0, "nublado": 3.0, "chuva": 2.5, "tempestade": 0.6, "neblina": 1.6},
	"Inverno": {"limpo": 2.5, "nublado": 3.0, "chuva": 1.0, "tempestade": 0.3, "neblina": 2.0, "neve": 2.5},
	"Primavera": {"limpo": 4.0, "nublado": 2.5, "chuva": 2.2, "tempestade": 0.8, "neblina": 1.0},
}

var main: Node
var estado := "limpo"
var _t_troca := 5.0          # horas de jogo até a próxima mudança
## intensidades atuais (0..1), vão atrás dos alvos devagar
var nuvens := 0.0
var chuva := 0.0
var neblina := 0.0
var neve := 0.0
var _alvo := {"nuvens": 0.0, "chuva": 0.0, "neblina": 0.0, "neve": 0.0}
var flash := 0.0             # relâmpago (0..1)
var _t_raio := 8.0
var _trovoes: Array = []     # segundos até tocar cada trovão

var _chuva_leve: CPUParticles3D
var _chuva_forte: CPUParticles3D
var _flocos: CPUParticles3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_chuva_leve = _gotas(900)
	_chuva_forte = _gotas(2600)
	_flocos = _neve_part()
	_definir(estado)

func estacao() -> String:
	var d: int = main.dia if main else 1
	return ESTACOES[int((d - 1) / DIAS_ESTACAO) % 4]

func nome() -> String:
	return NOMES.get(estado, estado)

## Quanto a pista segura o carro (1 = seco).
func aderencia() -> float:
	return clampf(1.0 - chuva * 0.32 - neve * 0.5, 0.4, 1.0)

## Raio de audição dos zumbis (chuva forte abafa o barulho).
func fator_audicao() -> float:
	return 1.0 - chuva * 0.4

## Alcance de visão dos zumbis e do jogador.
func fator_visao() -> float:
	return clampf(1.0 - neblina * 0.55 - chuva * 0.2 - neve * 0.25, 0.3, 1.0)

## A horda anda mais rápido debaixo de tempestade (o barulho do trovão a empurra).
func fator_horda() -> float:
	return 1.0 + (0.35 if estado == "tempestade" else 0.0) + chuva * 0.1

func _definir(e: String) -> void:
	estado = e
	_alvo = {"nuvens": 0.0, "chuva": 0.0, "neblina": 0.0, "neve": 0.0}
	match e:
		"nublado":
			_alvo.nuvens = 0.6
		"chuva":
			_alvo.nuvens = 0.8
			_alvo.chuva = 0.55
			_alvo.neblina = 0.15
		"tempestade":
			_alvo.nuvens = 1.0
			_alvo.chuva = 1.0
			_alvo.neblina = 0.3
		"neblina":
			_alvo.nuvens = 0.45
			_alvo.neblina = 1.0
		"neve":
			_alvo.nuvens = 0.75
			_alvo.neve = 1.0
			_alvo.neblina = 0.35

## Força um estado agora (prints, testes, carregar jogo).
func forcar(e: String, imediato := true) -> void:
	_definir(e)
	if imediato:
		for pt in [_chuva_leve, _chuva_forte, _flocos]:
			if pt:
				pt.restart()
		_chuva_leve.visible = _alvo.chuva > 0.08
		_chuva_forte.visible = _alvo.chuva > 0.6
		_flocos.visible = _alvo.neve > 0.1
		nuvens = _alvo.nuvens
		chuva = _alvo.chuva
		neblina = _alvo.neblina
		neve = _alvo.neve

## Avança o relógio do tempo (horas de jogo).
func passar(h: float) -> void:
	_t_troca -= h
	if _t_troca > 0.0:
		return
	_t_troca = _rng.randf_range(3.0, 9.0)
	var pesos: Dictionary = PESOS[estacao()]
	var tot := 0.0
	for k in pesos:
		tot += pesos[k]
	var x := _rng.randf() * tot
	for k in pesos:
		x -= pesos[k]
		if x <= 0.0:
			if k != estado and main and main.jogando:
				_avisar(k)
			_definir(k)
			return

func _avisar(k: String) -> void:
	var txt: String = {"chuva": "Começou a chover. A pista vai ficar lisa.", "tempestade": "Tempestade chegando. Melhor parar o comboio.",
		"neblina": "Neblina fechando a estrada.", "neve": "Começou a nevar.", "limpo": "O céu abriu.", "nublado": ""}.get(k, "")
	if txt != "":
		main.hud.aviso(txt)

func _process(dt: float) -> void:
	if main == null:
		return
	# intensidades vão atrás do alvo (~1 minuto real)
	var v := dt * 0.06
	nuvens = move_toward(nuvens, _alvo.nuvens, v)
	chuva = move_toward(chuva, _alvo.chuva, v)
	neblina = move_toward(neblina, _alvo.neblina, v * 0.7)
	neve = move_toward(neve, _alvo.neve, v)
	# partículas seguem a câmera; dentro do trailer não chove
	var cam := get_viewport().get_camera_3d()
	var abrigado: bool = main.get("dentro") != null
	if cam:
		var p := cam.global_position
		for pt in [_chuva_leve, _chuva_forte]:
			pt.global_position = p + Vector3(0, 9.0, 0)
		_flocos.global_position = p + Vector3(0, 7.0, 0)
	_chuva_leve.emitting = chuva > 0.08 and not abrigado
	_chuva_forte.emitting = chuva > 0.6 and not abrigado
	_flocos.emitting = neve > 0.1 and not abrigado
	_chuva_leve.visible = chuva > 0.03 and not abrigado
	_chuva_forte.visible = chuva > 0.4 and not abrigado
	_flocos.visible = neve > 0.03 and not abrigado
	# relâmpagos
	flash = maxf(0.0, flash - dt * 5.0)
	if estado == "tempestade" and chuva > 0.7 and not main.get("capturando"):
		_t_raio -= dt
		if _t_raio <= 0.0:
			_t_raio = _rng.randf_range(6.0, 22.0)
			flash = 1.0
			_trovoes.append(_rng.randf_range(0.4, 2.8))
	for i in range(_trovoes.size() - 1, -1, -1):
		_trovoes[i] -= dt
		if _trovoes[i] <= 0.0:
			_trovoes.remove_at(i)
			Som.tela("trovao", -2.0 if not abrigado else -9.0, 0.1)
	# som
	var vol_chuva := -80.0 if chuva < 0.05 else lerpf(-28.0, -6.0, chuva) - (8.0 if abrigado else 0.0)
	Som.loop("chuva", vol_chuva, 1.0, "Ambiente")
	# asfalto molhado
	var ms: ShaderMaterial = main.mundo.get("_mat_estrada") if main.mundo else null
	if ms:
		ms.set_shader_parameter("molhado", clampf(chuva * 1.3, 0.0, 1.0))
		ms.set_shader_parameter("neve", neve)
	# vento forte na tempestade balança capim e árvores
	var vento := 1.0 + chuva * 1.2 + (1.2 if estado == "tempestade" else 0.0)
	var mc: ShaderMaterial = main.mundo.get("mat_capim") if main.mundo else null
	if mc:
		mc.set_shader_parameter("neve", neve)
		mc.set_shader_parameter("vento", vento)
	for mf in Floresta.mat_folhas.values():
		mf.set_shader_parameter("vento", vento)
	var mt: ShaderMaterial = main.mundo.get("_mat_terreno") if main.mundo else null
	if mt:
		mt.set_shader_parameter("neve", neve)

func _gotas(n: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = 0.9
	p.preprocess = 0.9
	p.local_coords = false
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(22, 1.5, 22)
	p.direction = Vector3(0.08, -1, 0.03)
	p.spread = 3.0
	p.gravity = Vector3(0, -9.8, 0)
	p.initial_velocity_min = 16.0
	p.initial_velocity_max = 21.0
	var m := BoxMesh.new()
	m.size = Vector3(0.01, 0.6, 0.01)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.79, 0.85, 0.5)
	m.material = mat
	p.mesh = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _neve_part() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 1800
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(26, 2.0, 26)
	p.direction = Vector3(0.2, -1, 0.1)
	p.spread = 25.0
	p.gravity = Vector3(0, -0.6, 0)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var m := SphereMesh.new()
	m.radius = 0.03
	m.height = 0.06
	m.radial_segments = 4
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.96, 1.0)
	m.material = mat
	p.mesh = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func salvar() -> Dictionary:
	return {"estado": estado, "t_troca": _t_troca}

func carregar(d: Dictionary) -> void:
	forcar(d.get("estado", "limpo"))
	_t_troca = d.get("t_troca", 4.0)
