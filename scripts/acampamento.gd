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
			var inc := Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
			B.cyl(self, 0.075, 1.7, Vector3(p0.x, y0 + 0.85, p0.y), madeira, inc, 7)
			B.cyl(self, 0.075, 0.2, Vector3(p0.x, y0 + 1.8, p0.y), madeira, inc, 7, 0.01)
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
	_portao(madeira, tabua)

## Portão de verdade: mourões, trave com placa pendurada e uma folha de tábuas com
## travessa em Z, dobradiças e tranca. Abre sozinho quando um amigo chega perto.
var _folha: Node3D
var _abertura := 0.0
var _dentro_dir := Vector2.ZERO

func _portao(madeira: Material, tabua: Material) -> void:
	var ferro := B.mat(Color(0.18, 0.17, 0.16), 0.55, 0.75, "ferro_camp")
	var dir_p := (portao_b - portao_a).normalized()
	var pc := (portao_a + portao_b) * 0.5
	_dentro_dir = (Vector2(main.trailer.global_position.x, main.trailer.global_position.z) - pc).normalized()
	var ang_p := rad_to_deg(atan2(dir_p.x, dir_p.y))
	var ya := _chao(Vector3(portao_a.x, 0, portao_a.y))
	var yb := _chao(Vector3(portao_b.x, 0, portao_b.y))
	for pp in [[portao_a, ya], [portao_b, yb]]:
		var v: Vector2 = pp[0]
		B.cyl(self, 0.13, 2.5, Vector3(v.x, pp[1] + 1.25, v.y), madeira, Vector3.ZERO, 8)
		B.cyl(self, 0.13, 0.22, Vector3(v.x, pp[1] + 2.61, v.y), madeira, Vector3.ZERO, 8, 0.02)   # ponta
	var ym := maxf(ya, yb)
	# trave de cima e mãos-francesas
	B.box(self, Vector3(0.16, 0.16, PORTAO + 0.7), Vector3(pc.x, ym + 2.3, pc.y), madeira, Vector3(0, ang_p, 0))
	for lado in [-1.0, 1.0]:
		var pa: Vector2 = pc + dir_p * lado * (PORTAO * 0.5 - 0.25)
		B.box(self, Vector3(0.1, 0.1, 0.6), Vector3(pa.x, ym + 2.05, pa.y), madeira, Vector3(-45.0 * lado, ang_p, 0))
	# placa pendurada por duas correntes
	var bx := Node3D.new()
	bx.position = Vector3(pc.x, ym + 1.86, pc.y)
	bx.rotation.y = atan2(dir_p.x, dir_p.y) - PI * 0.5
	add_child(bx)
	B.box(bx, Vector3(1.9, 0.42, 0.05), Vector3.ZERO, tabua, Vector3(0, 0, -2.5))
	for sx in [-0.75, 0.75]:
		B.box(bx, Vector3(0.02, 0.24, 0.02), Vector3(sx, 0.32, 0), ferro)
	for lado in [1.0, -1.0]:
		var placa := Label3D.new()
		placa.text = "ACAMPAMENTO"
		placa.font_size = 72
		placa.pixel_size = 0.0035
		placa.modulate = Color(0.93, 0.9, 0.82)
		placa.outline_size = 0
		placa.shaded = true
		placa.double_sided = false
		placa.position = Vector3(0, 0, 0.03 * lado)
		placa.rotation.y = 0.0 if lado > 0 else PI
		placa.rotation.z = deg_to_rad(-2.5) * lado
		bx.add_child(placa)
	# folha do portão (gira na dobradiça em portao_a)
	_folha = Node3D.new()
	_folha.position = Vector3(portao_a.x, ya, portao_a.y)
	add_child(_folha)
	var L := PORTAO - 0.25
	for hh in [0.3, 0.75, 1.2, 1.6]:
		B.box(_folha, Vector3(0.05, 0.16, L), Vector3(0, hh, 0.12 + L * 0.5), tabua)
	for zz in [0.2, L * 0.5 + 0.12, L + 0.05]:
		B.box(_folha, Vector3(0.06, 1.55, 0.12), Vector3(0.03, 0.95, zz), tabua)
	var diag := Vector2(L - 0.2, 1.25)
	B.box(_folha, Vector3(0.05, 0.12, diag.length()), Vector3(-0.03, 0.95, 0.12 + L * 0.5), tabua, Vector3(rad_to_deg(atan2(diag.y, diag.x)), 0, 0))
	for hh in [0.4, 1.45]:
		B.box(_folha, Vector3(0.07, 0.06, 0.34), Vector3(0.0, hh, 0.2), ferro)          # dobradiças
	B.box(_folha, Vector3(0.09, 0.05, 0.22), Vector3(0.0, 1.0, L + 0.08), ferro)          # tranca
	_folha.rotation.y = atan2(dir_p.x, dir_p.y)
	_folha.set_meta("fechado", _folha.rotation.y)
	# para que lado abre (para dentro do acampamento)
	var aberto_dir := atan2(_dentro_dir.x, _dentro_dir.y)
	_folha.set_meta("aberto", _folha.rotation.y + wrapf(aberto_dir - _folha.rotation.y, -PI, PI) * 0.95)

func _animar_portao(dt: float) -> void:
	if _folha == null:
		return
	var pc := (portao_a + portao_b) * 0.5
	var p3 := Vector3(pc.x, 0, pc.y)
	var amigos: Array = []
	if main.jogador.visible:
		amigos.append(main.jogador.global_position)
	for r in main.recrutas_nos:
		if is_instance_valid(r):
			amigos.append(r.global_position)
	if main.get("cachorro") and is_instance_valid(main.cachorro):
		amigos.append(main.cachorro.global_position)
	var abrir := false
	for a in amigos:
		if Vector2(a.x - p3.x, a.z - p3.z).length() < 3.2:
			abrir = true
	var antes := _abertura
	_abertura = move_toward(_abertura, 1.0 if abrir else 0.0, dt * 1.6)
	if (antes == 0.0 and _abertura > 0.0) or (antes == 1.0 and _abertura < 1.0):
		Som.em("porta", Vector3(portao_a.x, _folha.position.y + 1.0, portao_a.y), -6.0, 0.2)
	var e := _abertura * _abertura * (3.0 - 2.0 * _abertura)
	_folha.rotation.y = lerp_angle(_folha.get_meta("fechado"), _folha.get_meta("aberto"), e)

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
	var pedra := Texturas.material("pedra", Color(0.36, 0.34, 0.32), 0.95, 0.0, 0.5)
	var fuligem := B.mat(Color(0.1, 0.09, 0.08), 1.0, 0.0, "pedra_fuligem")
	var rp := RandomNumberGenerator.new()
	rp.seed = int(f.x * 3.0) ^ int(f.z * 7.0)
	for k in 13:
		var a := TAU * k / 13.0 + rp.randf_range(-0.08, 0.08)
		var tam := rp.randf_range(0.11, 0.16)
		var pd := B.sphere(self, tam, f + Vector3(cos(a) * 0.62, 0.06, sin(a) * 0.62), pedra, Vector3(rp.randf_range(1.0, 1.5), rp.randf_range(0.55, 0.8), rp.randf_range(0.9, 1.2)), 5)
		pd.rotation.y = rp.randf() * TAU
		B.sphere(self, tam * 0.8, f + Vector3(cos(a) * 0.56, 0.08, sin(a) * 0.56), fuligem, Vector3(0.6, 0.5, 0.6), 5)
	var lenha := B.mat(Color(0.3, 0.2, 0.12), 0.95, 0.0, "lenha")
	var queimada := B.mat(Color(0.07, 0.05, 0.04), 1.0, 0.0, "carvao")
	B.cyl(self, 0.5, 0.05, f + Vector3(0, 0.025, 0), B.mat(Color(0.13, 0.12, 0.11), 1.0, 0.0, "cinza_fogo"), Vector3.ZERO, 14)
	# lenha em pirâmide (as pontas de cima queimadas)
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var base := f + Vector3(cos(a) * 0.38, 0.0, sin(a) * 0.38)
		var tora := Node3D.new()
		tora.position = base
		tora.rotation = Vector3(0, -a + PI * 0.5, 0)
		add_child(tora)
		var inc := Node3D.new()
		inc.rotation.x = deg_to_rad(-38.0)
		tora.add_child(inc)
		B.cyl(inc, 0.06, 0.5, Vector3(0, 0.25, 0), lenha, Vector3.ZERO, 6)
		B.cyl(inc, 0.058, 0.18, Vector3(0, 0.58, 0), queimada, Vector3.ZERO, 6, 0.03)
	var fogo := Fogo.new()
	fogo.name = "Fogo"
	fogo.position = f + Vector3(0, 0.05, 0)
	add_child(fogo)
	# panela no tripé
	var ferro := B.mat(Color(0.15, 0.15, 0.15), 0.5, 0.7, "ferro_camp")
	for k in 3:
		var a2 := TAU * k / 3.0
		B.cyl(self, 0.02, 1.25, f + Vector3(cos(a2) * 0.45, 0.58, sin(a2) * 0.45), ferro, Vector3(-18.0 * cos(a2), 0, 18.0 * sin(a2)), 4)
	B.cyl(self, 0.004, 0.25, f + Vector3(0, 1.2, 0), ferro, Vector3.ZERO, 4)
	B.cyl(self, 0.12, 0.13, f + Vector3(0, 1.0, 0), ferro, Vector3.ZERO, 12, 0.13)
	B.cyl(self, 0.13, 0.015, f + Vector3(0, 1.07, 0), ferro, Vector3.ZERO, 12)
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

func _process(dt: float) -> void:
	_animar_portao(dt)
