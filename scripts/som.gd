class_name Som
extends Node
## Som do jogo: efeitos posicionais (3D) e de tela, loops de ambiente e motor.
## Barramentos: Efeitos, Ambiente, Motor (volumes ajustáveis nas opções).
## Os efeitos ficam em assets/sons (sintetizados por tools/gerar_sons.py) e
## assets/sons/kenney (CC0).

const DIR := "res://assets/sons/"
static var inst: Som

var _cache := {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _loops := {}
var _variantes := {}
var main: Node

func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Efeitos", "Ambiente", "Motor"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for i in 24:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Efeitos"
		p.unit_size = 6.0
		p.max_distance = 90.0
		p.attenuation_filter_cutoff_hz = 6000.0
		p.attenuation_filter_db = -12.0
		add_child(p)
		_pool3d.append(p)
	for i in 8:
		var q := AudioStreamPlayer.new()
		q.bus = "Efeitos"
		add_child(q)
		_pool2d.append(q)

func _stream(nome: String) -> AudioStream:
	if not _cache.has(nome):
		var c := DIR + nome + ".ogg"
		_cache[nome] = load(c) if ResourceLoader.exists(c) else null
	return _cache[nome]

## Nome com variantes: "zumbi_gemido" sorteia zumbi_gemido_0.._N.
func _escolher(nome: String) -> String:
	if not _variantes.has(nome):
		var n := 0
		while ResourceLoader.exists(DIR + "%s_%d.ogg" % [nome, n]):
			n += 1
		_variantes[nome] = n
	var k: int = _variantes[nome]
	return nome if k == 0 else "%s_%d" % [nome, randi() % k]

## Efeito num ponto do mundo.
static func em(nome: String, pos: Vector3, vol_db := 0.0, var_tom := 0.08, alcance := 1.0) -> void:
	if inst == null or (inst.main and inst.main.get("capturando")):
		return
	var s := inst._stream(inst._escolher(nome))
	if s == null:
		return
	var p: AudioStreamPlayer3D = null
	for q in inst._pool3d:
		if not q.playing:
			p = q
			break
	if p == null:
		p = inst._pool3d[randi() % inst._pool3d.size()]
	p.stream = s
	p.global_position = pos
	p.volume_db = vol_db
	p.unit_size = 6.0 * alcance
	p.pitch_scale = 1.0 + randf_range(-var_tom, var_tom)
	p.play()

## Efeito sem posição (interface, o próprio jogador).
static func tela(nome: String, vol_db := 0.0, var_tom := 0.05) -> void:
	if inst == null or (inst.main and inst.main.get("capturando")):
		return
	var s := inst._stream(inst._escolher(nome))
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for q in inst._pool2d:
		if not q.playing:
			p = q
			break
	if p == null:
		p = inst._pool2d[0]
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-var_tom, var_tom)
	p.play()

## Loop contínuo (ambiente, motor). vol em dB; -80 = desligado.
static func loop(nome: String, vol_db: float, tom := 1.0, bus := "Ambiente") -> void:
	if inst == null:
		return
	var p: AudioStreamPlayer = inst._loops.get(nome)
	if p == null:
		var s := inst._stream(nome)
		if s == null:
			return
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		p = AudioStreamPlayer.new()
		p.stream = s
		p.bus = bus
		p.volume_db = -80.0
		inst.add_child(p)
		inst._loops[nome] = p
	var ligado = vol_db > -60.0 and not (inst.main and inst.main.get("capturando"))
	if ligado and not p.playing:
		p.play(randf() * maxf(0.0, p.stream.get_length() - 0.5))
	elif not ligado and p.playing and p.volume_db < -55.0:
		p.stop()
	p.volume_db = lerpf(p.volume_db, vol_db, 0.1) if p.playing else vol_db
	p.pitch_scale = tom

static func volume_bus(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(i, linear <= 0.001)
