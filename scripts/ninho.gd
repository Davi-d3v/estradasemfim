class_name Ninho
extends Node3D
## Ninho de zumbis (zona vermelha em diante): monte de corpos, lona rasgada e
## carne pulsando. Enquanto você estiver por perto, de tempos em tempos sai mais
## um zumbi. Só para queimando (molotov ou um galão de diesel); queimado, sobra
## o que as vítimas carregavam.

var mundo: WorldGen
var chave := ""
var queimado := false
var _t := 6.0
var _t_fogo := 0.0
var _miolo: MeshInstance3D
var _fogo: Node3D
var _luz: OmniLight3D

func _ready() -> void:
	queimado = mundo.vasculhados.has(chave)
	_montar()
	mundo.ninhos.append(self)

func _montar() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(chave)
	var carne := Modelos.mat(Color(0.3, 0.08, 0.07), 0.55)
	var podre := Modelos.mat(Color(0.25, 0.24, 0.18), 0.9)
	var pano := Modelos.mat(Color(0.42, 0.38, 0.28), 0.95)
	var osso := Modelos.mat(Color(0.75, 0.7, 0.6), 0.7)
	var carvao := Modelos.mat(Color(0.05, 0.045, 0.04), 1.0)
	var mat_corpo: Material = carvao if queimado else podre
	# corpos amontoados (modelos de verdade, caídos uns sobre os outros)
	for i in 6:
		var h := Humanoid.new()
		h.zumbi = true
		h.semente = r.randi()
		h.feminino = r.randf() < 0.4
		h.sujeira = 0.9
		if queimado:
			h.cores = {"pele": Color(0.08, 0.07, 0.06), "roupa": Color(0.05, 0.05, 0.05)}
		var a := TAU * i / 6.0 + r.randf() * 0.5
		var d := 0.6 + r.randf() * 0.9 if i > 0 else 0.0
		h.position = Vector3(cos(a) * d, 0.05 + (0.35 if i % 3 == 0 else 0.0), sin(a) * d)
		h.rotation = Vector3(0, r.randf() * TAU, 0)
		add_child(h)
		h.fixar("Death01" if r.randf() < 0.5 else "Death02", 1.0)
	# trapos e terra revolvida no meio
	for i in 8:
		var a := r.randf() * TAU
		var d := r.randf_range(0.2, 1.6)
		B.sphere(self, r.randf_range(0.25, 0.45), Vector3(cos(a) * d, 0.08, sin(a) * d), carvao if queimado else (pano if r.randf() < 0.5 else podre), Vector3(1.4, 0.45, 1.1), 8)
	# ossos e lixo em volta
	for i in 10:
		var a := r.randf() * TAU
		var d := r.randf_range(2.0, 4.0)
		B.cyl(self, 0.03, r.randf_range(0.3, 0.5), Vector3(cos(a) * d, 0.04, sin(a) * d), osso, Vector3(90, r.randf() * 180, 0), 6)
	# lona rasgada em estacas
	var est := Modelos.mat(Color(0.25, 0.18, 0.12), 0.95)
	for i in 3:
		var a := TAU * i / 3.0 + r.randf() * 0.4
		var p := Vector3(cos(a) * 3.0, 0, sin(a) * 3.0)
		B.box(self, Vector3(0.08, 1.9, 0.08), p + Vector3(0, 0.95, 0), est, Vector3(r.randf_range(-12, 12), 0, r.randf_range(-12, 12)))
		# lona rasgada pendurada (dois pedaços tortos)
		B.box(self, Vector3(1.1, 0.6, 0.02), p * 0.85 + Vector3(0, 1.5, 0), carvao if queimado else pano, Vector3(r.randf_range(-25, 25), rad_to_deg(a) + 90.0, r.randf_range(-25, 25)))
		B.box(self, Vector3(0.5, 0.7, 0.02), p * 0.8 + Vector3(0.2, 0.95, 0), carvao if queimado else pano, Vector3(r.randf_range(-30, 30), rad_to_deg(a) + 80.0, r.randf_range(10, 35)))
	# poça escura no chão
	B.cyl(self, 3.2, 0.02, Vector3(0, 0.01, 0), Modelos.mat(Color(0.16, 0.06, 0.04), 1.0) if not queimado else carvao, Vector3.ZERO, 18)
	if not queimado:
		# massa de carne pulsando no centro, meio enterrada
		_miolo = B.sphere(self, 0.55, Vector3(0, 0.25, 0), carne, Vector3(1.3, 0.75, 1.1), 14)
		var veia := Modelos.mat(Color(0.18, 0.03, 0.03), 0.4)
		for i in 7:
			var a := TAU * i / 7.0
			B.cyl(self, 0.05, 1.6, Vector3(cos(a) * 0.9, 0.06, sin(a) * 0.9), veia, Vector3(90, -rad_to_deg(a) + 90.0, 0), 6)

func _process(dt: float) -> void:
	if mundo == null:
		return
	var main: Node = mundo.get_parent()
	if not main.get("jogando") or main.get("capturando"):
		return
	if _fogo:
		_t_fogo += dt
		_luz.light_energy = maxf(0.4, 3.0 - _t_fogo * 0.05) * (0.85 + 0.15 * sin(_t_fogo * 13.0))
		return
	if queimado:
		return
	if _miolo:
		var s := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.004)
		_miolo.scale = Vector3(1.3, 0.75, 1.1) * s
	var foco: Vector3 = main._foco()
	var d := global_position.distance_to(foco)
	if d > 75.0:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = randf_range(14.0, 24.0)
	var vivos := 0
	for z in mundo.zumbis_vivos:
		if is_instance_valid(z) and z.get_meta("ninho", "") == chave:
			vivos += 1
	if vivos >= 3 + mundo.faixa(global_position.z):
		return
	var a := randf() * TAU
	var p := global_position + Vector3(cos(a), 0, sin(a)) * 1.5
	p.y = mundo.altura(p.x, p.z)
	var z := mundo.criar_zumbi(mundo, p, a, randi())
	z.set_meta("ninho", chave)
	z.estado = Zumbi.Estado.INVESTIGANDO
	z.alvo_pos = foco
	Som.em("zumbi_gemido", p + Vector3(0, 1.0, 0), 2.0, 0.2, 2.0)

## Põe fogo. Devolve o texto do resultado.
func queimar(main: Node) -> String:
	queimado = true
	mundo.vasculhados[chave] = true
	_fogo = Node3D.new()
	add_child(_fogo)
	var fogo_m := B.emissive(Color(1.0, 0.45, 0.1), 3.5)
	for i in 7:
		var a := TAU * i / 7.0
		B.sphere(_fogo, randf_range(0.4, 0.7), Vector3(cos(a) * 1.1, 0.9 + randf() * 0.5, sin(a) * 1.1), fogo_m, Vector3(1, 1.8, 1), 8)
	B.sphere(_fogo, 0.9, Vector3(0, 1.4, 0), fogo_m, Vector3(1, 2.0, 1), 8)
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.55, 0.2)
	_luz.light_energy = 3.0
	_luz.omni_range = 16.0
	_luz.position = Vector3(0, 2.0, 0)
	_fogo.add_child(_luz)
	if _miolo:
		_miolo.queue_free()
		_miolo = null
	Som.em("fogo_whoosh", global_position + Vector3(0, 1, 0), 4.0, 0.05, 3.0)
	main.ruido(global_position, 60.0, "fogo")
	# o que as vítimas carregavam
	var r := RandomNumberGenerator.new()
	r.seed = hash(chave + "saque")
	var ganho := {"municao_pistola": r.randi_range(4, 14), "sucata": r.randi_range(3, 9), "remedio": r.randi_range(0, 2),
		"bandagem": r.randi_range(1, 3), "cartucho": r.randi_range(0, 6)}
	if r.randf() < 0.3:
		ganho["pistola"] = 1
	var lin: Array[String] = []
	for k in ganho:
		if ganho[k] > 0:
			var n: int = main.adicionar(k, ganho[k])
			if n > 0:
				lin.append("%d %s" % [n, main.ITENS[k].nome.to_lower()])
	# os que estavam dentro saem queimando
	for i in randi_range(2, 4):
		var a := randf() * TAU
		var p := global_position + Vector3(cos(a), 0, sin(a)) * 2.5
		p.y = mundo.altura(p.x, p.z)
		var z := mundo.criar_zumbi(mundo, p, a, randi())
		z.estado = Zumbi.Estado.PERSEGUINDO
		z.alvo_pos = main._foco()
		z.ferir(15.0)
	return "O ninho pegou fogo. Saíram mais alguns lá de dentro.\nNo meio dos restos: %s." % (", ".join(lin) if not lin.is_empty() else "nada que coubesse na carga")
