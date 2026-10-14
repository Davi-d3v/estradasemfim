class_name Acampamento
extends Node3D
## Acampamento montado com [C]: cerca grande em volta do comboio (zumbis não passam;
## você, os recrutas e o cachorro passam pelo portão), fogueira com pedras e lenha,
## e cadeiras em roda onde os recrutas sentam, conversam e bebem à noite.

const FOLGA_LADO := 10.0      # cerca a quantos metros da lateral dos veículos
const FOLGA_PONTA := 7.5     # e das pontas (frente da picape e traseira do último reboque)
const PORTAO := 3.2          # largura do portão

var main: Node
var anel: PackedVector2Array = PackedVector2Array()   # cerca (polígono fechado, xz)
var portao_a := Vector2.ZERO   # extremos do vão do portão
var portao_b := Vector2.ZERO
var fogueira := Vector3.ZERO
var cadeiras: Array = []       # [{pos, yaw}]
var ocupantes := {}            # índice da cadeira -> recruta sentado

## Recruta pede uma cadeira na roda (devolve o índice, ou -1 se não houver).
func pedir_cadeira(r: Node) -> int:
	for i in ocupantes.keys():
		if not is_instance_valid(ocupantes[i]):
			ocupantes.erase(i)
		elif ocupantes[i] == r:
			return i
	for i in cadeiras.size():
		if not ocupantes.has(i):
			ocupantes[i] = r
			return i
	return -1

func largar_cadeira(r: Node) -> void:
	for i in ocupantes.keys():
		if ocupantes[i] == r:
			ocupantes.erase(i)

func montar() -> void:
	_cerca()
	_fogueira()
	_cadeiras()
	main.mundo.obstaculos_extra.append(self)

func _exit_tree() -> void:
	if main and main.mundo:
		main.mundo.obstaculos_extra.erase(self)

func _chao(p: Vector3) -> float:
	return main.jogador.chao(p)

# ------------------------------------------------------------ cerca
func _cerca() -> void:
	var veic: Array = [main.picape]
	veic.append_array(main.comboio.cadeia)
	var esq: Array = []
	var dir: Array = []
	for v in veic:
		var meia: float = 3.0 if v == main.picape else (v.comprimento() * 0.5 + 0.5)
		for zz in [meia, 0.0, -meia]:
			esq.append(v.global_transform * Vector3(FOLGA_LADO, 0, zz))
			dir.append(v.global_transform * Vector3(-FOLGA_LADO, 0, zz))
	var pk: Node3D = main.picape
	var ult: Node3D = main.comboio.cadeia[main.comboio.cadeia.size() - 1]
	var frente_e: Vector3 = pk.global_transform * Vector3(FOLGA_LADO * 0.6, 0, 3.0 + FOLGA_PONTA)
	var frente_d: Vector3 = pk.global_transform * Vector3(-FOLGA_LADO * 0.6, 0, 3.0 + FOLGA_PONTA)
	var tras_e: Vector3 = ult.global_transform * Vector3(FOLGA_LADO * 0.6, 0, -ult.comprimento() * 0.5 - FOLGA_PONTA)
	var tras_d: Vector3 = ult.global_transform * Vector3(-FOLGA_LADO * 0.6, 0, -ult.comprimento() * 0.5 - FOLGA_PONTA)
	var pts: Array = [frente_e]
	pts.append_array(esq)
	pts.append(tras_e)
	pts.append(tras_d)
	var d2 := dir.duplicate()
	d2.reverse()
	pts.append_array(d2)
	pts.append(frente_d)
	# suaviza: tira pontos muito próximos
	var lim: Array = [pts[0]]
	for p in pts:
		if Vector2(p.x, p.z).distance_to(Vector2(lim[-1].x, lim[-1].z)) > 2.0:
			lim.append(p)
	anel = PackedVector2Array()
	for p in lim:
		anel.append(Vector2(p.x, p.z))
	# portão: na lateral da picape, do lado da cozinha do trailer (-x local), longe da roda da fogueira
	var tr: Node3D = main.trailer
	var pg: Vector3 = main.picape.global_transform * Vector3(-FOLGA_LADO, 0, 0.5)
	var pg2 := Vector2(pg.x, pg.z)
	var melhor := 0
	var dmin := INF
	for i in anel.size():
		var a := anel[i]
		var b := anel[(i + 1) % anel.size()]
		var dd := _dist_seg(pg2, a, b)
		if dd < dmin:
			dmin = dd
			melhor = i
	var sa := anel[melhor]
	var sb := anel[(melhor + 1) % anel.size()]
	var tdir := (sb - sa).normalized()
	var proj := sa + tdir * clampf((pg2 - sa).dot(tdir), PORTAO, sa.distance_to(sb) - PORTAO)
	portao_a = proj - tdir * PORTAO * 0.5
	portao_b = proj + tdir * PORTAO * 0.5
	# desenho
	var madeira := B.mat(Color(0.35, 0.26, 0.17), 0.95, 0.0, "estaca_camp")
	var tabua := B.mat(Color(0.42, 0.31, 0.2), 0.95, 0.0, "tabua_camp")
	var arame := B.mat(Color(0.42, 0.42, 0.42), 0.4, 0.8, "arame")
	var chapa := B.mat(Color(0.45, 0.42, 0.38), 0.6, 0.5, "chapa_camp")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(tr.global_position.x * 10.0) ^ int(tr.global_position.z * 10.0)
	for i in anel.size():
		var a := anel[i]
		var b := anel[(i + 1) % anel.size()]
		var comp := a.distance_to(b)
		var n := maxi(1, int(ceil(comp / 2.4)))
		for q in n:
			var p0 := a.lerp(b, float(q) / n)
			var p1 := a.lerp(b, float(q + 1) / n)
			var meio := (p0 + p1) * 0.5
			if _no_portao(meio):
				continue
			var y0 := _chao(Vector3(p0.x, 0, p0.y))
			B.box(self, Vector3(0.14, 1.7, 0.14), Vector3(p0.x, y0 + 0.85, p0.y), madeira, Vector3(0, 0, rng.randf_range(-4, 4)))
			var y1 := _chao(Vector3(p1.x, 0, p1.y))
			var ym := (y0 + y1) * 0.5
			var ang := rad_to_deg(atan2(p1.x - p0.x, p1.y - p0.y))
			var c3 := Vector3(meio.x, ym, meio.y)
			var sl := p0.distance_to(p1)
			# tábuas embaixo, chapa às vezes, arame em cima
			if rng.randf() < 0.3:
				B.box(self, Vector3(0.04, 0.9, sl), c3 + Vector3(0, 0.55, 0), chapa, Vector3(0, ang, rng.randf_range(-3, 3)))
			else:
				for hh in [0.3, 0.75]:
					B.box(self, Vector3(0.05, 0.22, sl), c3 + Vector3(0, hh, 0), tabua, Vector3(0, ang, rng.randf_range(-2, 2)))
			for hh in [1.2, 1.5]:
				B.box(self, Vector3(0.02, 0.02, sl), c3 + Vector3(0, hh, 0), arame, Vector3(0, ang, 0))
	# portão: dois mourões grossos e a folha aberta para dentro
	for pp in [portao_a, portao_b]:
		var yy := _chao(Vector3(pp.x, 0, pp.y))
		B.box(self, Vector3(0.22, 2.1, 0.22), Vector3(pp.x, yy + 1.05, pp.y), madeira)
	var ya := _chao(Vector3(portao_a.x, 0, portao_a.y))
	var dir_p := (portao_b - portao_a).normalized()
	var dentro := (Vector2(main.trailer.global_position.x, main.trailer.global_position.z) - (portao_a + portao_b) * 0.5).normalized()
	var folha_fim := portao_a + (dir_p * 0.2 + dentro).normalized() * (PORTAO - 0.3)
	var fm := (portao_a + folha_fim) * 0.5
	var ang_f := rad_to_deg(atan2(folha_fim.x - portao_a.x, folha_fim.y - portao_a.y))
	for hh in [0.35, 0.85, 1.35]:
		B.box(self, Vector3(0.05, 0.14, PORTAO - 0.3), Vector3(fm.x, ya + hh, fm.y), tabua, Vector3(0, ang_f, 0))
	B.box(self, Vector3(0.05, 1.3, 0.12), Vector3(fm.x, ya + 0.85, fm.y), tabua, Vector3(0, ang_f, 0))
	var pc := (portao_a + portao_b) * 0.5
	var placa := Label3D.new()
	placa.text = "ACAMPAMENTO"
	placa.font_size = 64
	placa.pixel_size = 0.004
	placa.modulate = Color(0.95, 0.9, 0.8)
	placa.outline_size = 6
	placa.shaded = true
	placa.position = Vector3(pc.x, ya + 2.25, pc.y)
	placa.rotation.y = atan2(dir_p.x, dir_p.y) + PI * 0.5
	add_child(placa)
	B.box(self, Vector3(PORTAO + 0.3, 0.12, 0.12), Vector3(pc.x, ya + 2.05, pc.y), madeira, Vector3(0, rad_to_deg(atan2(dir_p.x, dir_p.y)), 0))

func _no_portao(p: Vector2) -> bool:
	return _dist_seg(p, portao_a, portao_b) < 0.6

static func _dist_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func _cruza(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	var d1 := (q2 - q1).cross(p1 - q1)
	var d2 := (q2 - q1).cross(p2 - q1)
	var d3 := (p2 - p1).cross(q1 - p1)
	var d4 := (p2 - p1).cross(q2 - p1)
	return d1 * d2 < 0.0 and d3 * d4 < 0.0

## Colisão: zumbis e bichos não atravessam a cerca; amigos (amigo=true) passam pelo portão.
func colide_em(a: Vector3, b: Vector3, raio: float, amigo := false) -> bool:
	if anel.is_empty():
		return false
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	if a2.distance_squared_to(anel[0]) > 90000.0:
		return false
	for i in anel.size():
		var p := anel[i]
		var q := anel[(i + 1) % anel.size()]
		var db := _dist_seg(b2, p, q)
		if db > raio + 0.2 and not _cruza(a2, b2, p, q):
			continue
		# perto/atravessando este trecho da cerca
		var ponto := b2
		if amigo and _dist_seg(ponto, portao_a, portao_b) < PORTAO * 0.5 + 0.2 and _dist_seg(ponto, p, q) < 1.0:
			continue
		if _cruza(a2, b2, p, q):
			return true
		if db < raio + 0.2 and db < _dist_seg(a2, p, q):
			return true
	return false

# ------------------------------------------------------------ fogueira e cadeiras
func _fogueira() -> void:
	var tr: Node3D = main.trailer
	fogueira = tr.global_transform * Vector3(-4.4, 0, 0.0)
	fogueira.y = _chao(fogueira)
	var f := fogueira
	var pedra := B.mat(Color(0.42, 0.4, 0.38), 0.9, 0.0, "pedra")
	for k in 11:
		var a := TAU * k / 11.0
		B.sphere(self, 0.17, f + Vector3(cos(a) * 0.6, 0.08, sin(a) * 0.6), pedra, Vector3(1.1, 0.7, 1), 6)
	var lenha := B.mat(Color(0.3, 0.2, 0.12), 0.95, 0.0, "lenha")
	var brasa := B.mat(Color(0.08, 0.05, 0.04), 1.0, 0.0, "carvao")
	B.cyl(self, 0.45, 0.06, f + Vector3(0, 0.03, 0), brasa, Vector3.ZERO, 12)
	for k in 5:
		var tora := B.cyl(self, 0.065, 0.85, f + Vector3(0, 0.22, 0), lenha, Vector3(68, k * 72.0, 0), 6)
		tora.name = "Tora"
	var chama := Node3D.new()
	chama.name = "Chama"
	chama.position = f
	add_child(chama)
	B.sphere(chama, 0.28, Vector3(0, 0.35, 0), B.emissive(Color(1.0, 0.42, 0.08), 4.5), Vector3(1, 1.7, 1), 8)
	B.sphere(chama, 0.16, Vector3(0.05, 0.62, 0.02), B.emissive(Color(1.0, 0.75, 0.25), 6.0), Vector3(1, 1.8, 1), 8)
	var luz := OmniLight3D.new()
	luz.name = "Luz"
	luz.light_color = Color(1.0, 0.55, 0.22)
	luz.light_energy = 2.6
	luz.omni_range = 11.0
	luz.shadow_enabled = true
	luz.position = f + Vector3(0, 1.0, 0)
	add_child(luz)
	# panela no tripé
	var ferro := B.mat(Color(0.15, 0.15, 0.15), 0.5, 0.7, "ferro_camp")
	for k in 3:
		var a2 := TAU * k / 3.0
		B.cyl(self, 0.02, 1.25, f + Vector3(cos(a2) * 0.45, 0.58, sin(a2) * 0.45), ferro, Vector3(-18.0 * cos(a2), 0, 18.0 * sin(a2)), 4)
	B.cyl(self, 0.16, 0.18, f + Vector3(0, 1.0, 0), ferro, Vector3.ZERO, 10)
	# troncos de lenha empilhados
	for i in 6:
		B.cyl(self, 0.11, 0.9, f + tr.global_transform.basis * Vector3(-2.6, 0.11 + (i / 3) * 0.2, -2.4 + (i % 3) * 0.23), lenha, Vector3(0, 0, 90) + Vector3(0, rad_to_deg(tr.global_rotation.y), 0), 6)

func _cadeiras() -> void:
	var n: int = clampi(main.base.lista.size() + 1, 4, 8)
	var lona := B.mat(Color(0.14, 0.3, 0.22), 0.9, 0.0, "lona_cad")
	var lona2 := B.mat(Color(0.45, 0.2, 0.12), 0.9, 0.0, "lona_cad2")
	var aco := B.mat(Color(0.4, 0.4, 0.4), 0.4, 0.8, "arame")
	var tr: Node3D = main.trailer
	var a0: float = tr.global_rotation.y + PI * 0.5
	cadeiras.clear()
	for k in n:
		var a: float = a0 + TAU * (k + 0.5) / n
		var p := fogueira + Vector3(sin(a), 0, cos(a)) * 2.1
		p.y = _chao(p)
		var yaw := atan2(fogueira.x - p.x, fogueira.z - p.z)
		cadeiras.append({"pos": p, "yaw": yaw})
		var cad := Node3D.new()
		cad.position = p
		cad.rotation.y = yaw
		add_child(cad)
		var m := lona if k % 2 == 0 else lona2
		B.box(cad, Vector3(0.52, 0.04, 0.46), Vector3(0, 0.44, 0), m)
		B.box(cad, Vector3(0.52, 0.55, 0.04), Vector3(0, 0.72, -0.24), m, Vector3(-12, 0, 0))
		for sx in [-0.24, 0.24]:
			B.cyl(cad, 0.014, 0.62, Vector3(sx, 0.26, 0.05), aco, Vector3(28, 0, 0), 4)
			B.cyl(cad, 0.014, 0.62, Vector3(sx, 0.26, -0.08), aco, Vector3(-28, 0, 0), 4)
			B.box(cad, Vector3(0.04, 0.03, 0.4), Vector3(sx + signf(sx) * 0.02, 0.62, 0.0), aco)

func _process(_dt: float) -> void:
	var ch := get_node_or_null("Chama")
	if ch:
		var t := Time.get_ticks_msec() / 1000.0
		ch.scale = Vector3.ONE * (1.0 + 0.12 * sin(t * 9.0) + 0.06 * sin(t * 23.0))
		var l: OmniLight3D = get_node_or_null("Luz")
		if l:
			l.light_energy = 2.4 + 0.4 * sin(t * 11.0) + 0.2 * sin(t * 27.0)
