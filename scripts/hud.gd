class_name Hud
extends Control
## Interface desenhada à mão: objetivo, relógio, barras, barra rápida e bússola.

var jogador: Player
var trailer_pos := Vector3.ZERO
var zumbis: Array[Vector3] = []
var aliados: Array[Vector3] = []   # recrutas no acampamento
var recrutas_txt := ""
var dia := 1
var hora := 18.78
var objetivo := "Volte para o trailer"
var subobjetivo := "Leve os recursos que saqueou (0/1)"
var dica := ""
var slot_ativo := 0
var dirigindo := false
var km_h := 0.0
var diesel := 0.0
var tanque := 80.0
var fora_estrada := false
var re := false
var estoque := {}
var marcadores: Array[Vector3] = []
var binoculo := false
var sono := 1.0
var cochilo := 0.0
var doencas: Array = []
var binoculo_txt := ""
var radar: Array = []          # torre de rádio: [{pos, cor, letra}]
var mira := false
var carga_usada := 0.0
var carga_max := 0
var temperatura := 0.3
var superaquecido := false
var peso_rebocado := 0.0
var capacidade_reboque := 1.0
var projetos := 0
var interior := false
var relatorio := ""
var relatorio_t := 0.0
var relatorio_titulo := ""
var mensagem_radio := ""
var lugares: Array = []
var infeccao := 0.0
var defesa := {}          # painel da defesa do assentamento (ver Defesa.info_hud)
var horda_txt := ""
var clima_txt := ""
var arma_txt := ""
var recarga := -1.0
var mirando := false
var defesa_armadura := 0.0
var _t_dano := 0.0
var _t_acerto := 0.0       # [{pos, tipo}] conhecidos
var _banner_t := 0.0
var _banner_titulo := ""
var _banner_sub := ""
var _aviso_txt := ""
var _aviso_t := 0.0

func dano() -> void:
	_t_dano = 1.0

func acerto() -> void:
	_t_acerto = 0.25

func limpar_banner() -> void:
	_banner_t = 0.0

func banner(titulo: String, sub: String) -> void:
	_banner_titulo = titulo
	_banner_sub = sub
	_banner_t = 6.0

func limpar_aviso() -> void:
	_aviso_t = 0.0

func aviso(t: String) -> void:
	_aviso_txt = t
	_aviso_t = 3.5
var itens := [["facao", 1], ["mochila", 2], ["medkit", 2], ["lata", 3], ["agua", 4], ["madeira", 12]]

const FUNDO := Color(0.06, 0.06, 0.07, 0.72)
const BORDA := Color(1, 1, 1, 0.08)
const DOURADO := Color(0.95, 0.68, 0.22)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	_aviso_t = maxf(0.0, _aviso_t - dt)
	_banner_t = maxf(0.0, _banner_t - dt)
	_t_dano = maxf(0.0, _t_dano - dt * 1.6)
	_t_acerto = maxf(0.0, _t_acerto - dt)
	relatorio_t = maxf(0.0, relatorio_t - dt)
	queue_redraw()

func _fonte() -> Font:
	return ThemeDB.fallback_font

func _painel(r: Rect2, raio := 6) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = FUNDO
	sb.border_color = BORDA
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(raio)
	draw_style_box(sb, r)

func _texto(t: String, p: Vector2, tam: int, cor := Color(0.93, 0.92, 0.88), alinh := HORIZONTAL_ALIGNMENT_LEFT, largura := -1.0) -> void:
	draw_string(_fonte(), p + Vector2(1, 1), t, alinh, largura, tam, Color(0, 0, 0, 0.6))
	draw_string(_fonte(), p, t, alinh, largura, tam, cor)

## Vinheta do binóculo: dois círculos e o resto escuro.
func _binoculo(s: Vector2, e: float) -> void:
	var r := s.y * 0.36
	var c1 := Vector2(s.x * 0.5 - r * 0.62, s.y * 0.5)
	var c2 := Vector2(s.x * 0.5 + r * 0.62, s.y * 0.5)
	var preto := Color(0, 0, 0, 0.94)
	# preenche o que está fora dos dois círculos com faixas
	var passo := 2.0
	var y := 0.0
	while y < s.y:
		var xs: Array = []
		for c in [c1, c2]:
			var dy: float = y - c.y
			if absf(dy) < r:
				var dx := sqrt(r * r - dy * dy)
				xs.append([c.x - dx, c.x + dx])
		if xs.is_empty():
			draw_rect(Rect2(0, y, s.x, passo), preto)
		else:
			var a: float = xs[0][0]
			var b: float = xs[xs.size() - 1][1]
			draw_rect(Rect2(0, y, a, passo), preto)
			draw_rect(Rect2(b, y, s.x - b, passo), preto)
			if xs.size() == 2 and xs[0][1] < xs[1][0]:
				draw_rect(Rect2(xs[0][1], y, xs[1][0] - xs[0][1], passo), preto)
		y += passo
	draw_line(Vector2(s.x * 0.5 - 12 * e, s.y * 0.5), Vector2(s.x * 0.5 + 12 * e, s.y * 0.5), Color(1, 1, 1, 0.35), 1.5 * e)
	draw_line(Vector2(s.x * 0.5, s.y * 0.5 - 12 * e), Vector2(s.x * 0.5, s.y * 0.5 + 12 * e), Color(1, 1, 1, 0.35), 1.5 * e)
	_texto("BINÓCULO  ·  " + binoculo_txt + "  ·  [Z] baixar", Vector2(0, s.y * 0.9), int(16 * e), Color(0.95, 0.9, 0.75), HORIZONTAL_ALIGNMENT_CENTER, s.x)

func _draw() -> void:
	size = get_viewport_rect().size
	var s := size
	if s.y < 50:
		return
	var e := s.y / 900.0  # escala
	if binoculo:
		_binoculo(s, e)
	if cochilo > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, clampf(cochilo * 1.4, 0.0, 0.96)))
	_objetivo(e)
	_relogio(s, e)
	if not defesa.is_empty():
		_painel_defesa(s, e)
	_barras(s, e)
	if dirigindo:
		_painel_veiculo(s, e)
	elif not interior:
		_barra_rapida(s, e)
	if _t_dano > 0.0:
		var a := _t_dano * 0.45
		for k in 6:
			var m := 40.0 * e * (6 - k)
			draw_rect(Rect2(Vector2.ZERO, Vector2(s.x, m)), Color(0.6, 0.0, 0.0, a * 0.12))
			draw_rect(Rect2(Vector2(0, s.y - m), Vector2(s.x, m)), Color(0.6, 0.0, 0.0, a * 0.12))
			draw_rect(Rect2(Vector2.ZERO, Vector2(m, s.y)), Color(0.6, 0.0, 0.0, a * 0.12))
			draw_rect(Rect2(Vector2(s.x - m, 0), Vector2(m, s.y)), Color(0.6, 0.0, 0.0, a * 0.12))
	if infeccao > 0.0:
		var ri := Rect2(Vector2(20 * e, s.y - 196 * e), Vector2(200 * e, 22 * e))
		_painel(ri)
		draw_rect(Rect2(ri.position + Vector2(68, 7) * e, Vector2(124 * e * infeccao, 8 * e)), Color(0.45, 0.75, 0.2))
		_texto("INFECÇÃO", ri.position + Vector2(8, 16) * e, int(11 * e), Color(0.6, 0.9, 0.35))
	if _t_acerto > 0.0:
		var c := s * 0.5
		for k in 4:
			var a2 := PI * 0.25 + k * PI * 0.5
			draw_line(c + Vector2(cos(a2), sin(a2)) * 8 * e, c + Vector2(cos(a2), sin(a2)) * 16 * e, Color(1, 0.9, 0.8, _t_acerto * 4.0), 2.0 * e)
	if _banner_t > 0.0:
		var alfa := clampf(minf(_banner_t, 6.0 - _banner_t) * 1.5, 0.0, 1.0)
		var by := s.y * 0.2 + (60.0 * e if dirigindo else 0.0)
		_texto(_banner_titulo.to_upper(), Vector2(0, by), int(40 * e), Color(0.96, 0.93, 0.85, alfa), HORIZONTAL_ALIGNMENT_CENTER, s.x)
		draw_line(Vector2(s.x * 0.5 - 160 * e, by + 16 * e), Vector2(s.x * 0.5 + 160 * e, by + 16 * e), Color(DOURADO, alfa * 0.8), 2.0 * e)
		_texto(_banner_sub, Vector2(0, by + 44 * e), int(18 * e), Color(DOURADO, alfa), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if _aviso_t > 0.0:
		var w2 := maxf(520.0 * e, _fonte().get_string_size(_aviso_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * e)).x + 40.0 * e)
		var r2 := Rect2(Vector2(s.x * 0.5 - w2 * 0.5, (170 if dirigindo else 90) * e), Vector2(w2, 40 * e))
		_painel(r2)
		_texto(_aviso_txt, r2.position + Vector2(0, 26) * e, int(17 * e), DOURADO, HORIZONTAL_ALIGNMENT_CENTER, w2)
	if mensagem_radio != "" and interior:
		_caixa_texto("RÁDIO", mensagem_radio, s, e, 0.2)
	if relatorio_t > 0.0 and relatorio != "":
		_caixa_texto(relatorio_titulo if relatorio_titulo != "" else "BOM DIA", relatorio, s, e, 0.36)
	_recursos(e)
	_bussola(s, e)
	if mirando:
		var cc := s * 0.5
		for k in 4:
			var dd := Vector2(cos(k * PI * 0.5), sin(k * PI * 0.5))
			draw_line(cc + dd * 6.0 * e, cc + dd * 15.0 * e, Color(0, 0, 0, 0.5), 3.0 * e)
			draw_line(cc + dd * 6.0 * e, cc + dd * 15.0 * e, Color(1, 1, 1, 0.9), 1.5 * e)
		draw_circle(cc, 1.6 * e, Color(1, 0.3, 0.2, 0.95))
	elif mira:
		var cc := s * 0.5
		draw_circle(cc, 3.0 * e, Color(1, 1, 1, 0.85))
		draw_arc(cc, 6.0 * e, 0, TAU, 20, Color(0, 0, 0, 0.35), 1.2 * e)
	if arma_txt != "" and not dirigindo and not interior:
		var wa := maxf(220.0 * e, _fonte().get_string_size(arma_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * e)).x + 28.0 * e)
		var ra := Rect2(Vector2(s.x * 0.5 - wa * 0.5, s.y - 128 * e), Vector2(wa, 28 * e))
		_painel(ra)
		_texto(arma_txt, ra.position + Vector2(0, 19) * e, int(15 * e), DOURADO, HORIZONTAL_ALIGNMENT_CENTER, wa)
		if recarga >= 0.0:
			draw_rect(Rect2(ra.position + Vector2(8, 23) * e, Vector2((wa - 16 * e) * recarga, 3 * e)), DOURADO)
	if defesa_armadura > 0.0:
		var rd := Rect2(Vector2(20 * e, s.y - 222 * e), Vector2(200 * e, 22 * e))
		_painel(rd)
		_texto("ARMADURA  −%d%% de dano" % int(defesa_armadura * 100.0), rd.position + Vector2(10, 16) * e, int(12 * e), Color(0.8, 0.7, 0.55))
	if dica != "":
		var w := (_fonte().get_string_size(dica, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * e)).x + 36.0 * e)
		var r := Rect2(Vector2(s.x * 0.5 - w * 0.5, s.y * 0.62), Vector2(w, 34 * e))
		_painel(r)
		_texto(dica, r.position + Vector2(0, 23 * e), int(16 * e), Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, w)

func _objetivo(e: float) -> void:
	var r := Rect2(Vector2(20, 20) * e, Vector2(340, 66) * e)
	var sb := StyleBoxFlat.new()
	sb.bg_color = FUNDO
	sb.set_corner_radius_all(int(6 * e))
	sb.border_width_left = int(3 * e)
	sb.border_color = DOURADO
	draw_style_box(sb, r)
	var c := r.position + Vector2(22, 22) * e
	var losango := PackedVector2Array([c + Vector2(0, -8) * e, c + Vector2(8, 0) * e, c + Vector2(0, 8) * e, c + Vector2(-8, 0) * e])
	draw_colored_polygon(losango, DOURADO)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3.5) * e, c + Vector2(3.5, 0) * e, c + Vector2(0, 3.5) * e, c + Vector2(-3.5, 0) * e]), Color(0.1, 0.08, 0.05))
	_texto(objetivo, r.position + Vector2(40, 28) * e, int(19 * e), DOURADO)
	var cb := Rect2(r.position + Vector2(40, 40) * e, Vector2(13, 13) * e)
	draw_rect(cb, Color(1, 1, 1, 0.7), false, 1.5 * e)
	_texto(subobjetivo, r.position + Vector2(62, 52) * e, int(14 * e))

func _relogio(s: Vector2, e: float) -> void:
	var w := 168.0 * e
	var r := Rect2(Vector2(s.x - w - 20 * e, 20 * e), Vector2(w, 40 * e))
	_painel(r)
	var h := int(hora)
	var m := int((hora - h) * 60.0)
	_texto("Dia %d   %02d:%02d" % [dia, h, m], r.position + Vector2(14, 27) * e, int(19 * e))
	var c := r.position + Vector2(w - 24 * e, 22 * e)
	var noite := hora < 6.0 or hora > 19.3
	if noite:
		draw_circle(c, 8 * e, Color(0.85, 0.88, 1.0))
		draw_circle(c + Vector2(4, -3) * e, 7 * e, Color(0.12, 0.12, 0.16))
	else:
		draw_circle(c + Vector2(0, 2) * e, 7 * e, DOURADO)
		draw_rect(Rect2(c + Vector2(-14, 3) * e, Vector2(28, 8) * e), Color(0.14, 0.13, 0.15))
		for i in 7:
			var a := PI + PI * i / 6.0
			draw_line(c + Vector2(cos(a), sin(a)) * 10 * e + Vector2(0, 2) * e, c + Vector2(cos(a), sin(a)) * 14 * e + Vector2(0, 2) * e, DOURADO, 1.6 * e)
		draw_line(c + Vector2(-13, 3) * e, c + Vector2(13, 3) * e, DOURADO, 1.6 * e)
	var y := 66.0
	for item in [[horda_txt, "☠ ", Color(0.95, 0.5, 0.35)], [clima_txt, "", Color(0.78, 0.84, 0.92)]]:
		if item[0] == "":
			continue
		var txt: String = item[1] + item[0]
		var lw: float = maxf(w, _fonte().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * e)).x + 22 * e)
		var rh := Rect2(Vector2(s.x - lw - 20 * e, y * e), Vector2(lw, 26 * e))
		_painel(rh)
		_texto(txt, rh.position + Vector2(10, 18) * e, int(13 * e), item[2])
		y += 30.0

func _painel_defesa(s: Vector2, e: float) -> void:
	var w := 420.0 * e
	var onda: bool = defesa.get("onda", false)
	var h := (74.0 if onda else 56.0) * e
	var r := Rect2(Vector2(s.x * 0.5 - w * 0.5, 20 * e), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = FUNDO
	sb.set_corner_radius_all(int(6 * e))
	sb.border_width_top = int(3 * e)
	sb.border_color = Color(0.85, 0.25, 0.18) if onda else DOURADO
	draw_style_box(sb, r)
	_texto(defesa.titulo, r.position + Vector2(0, 22) * e, int(16 * e), Color(0.95, 0.4, 0.3) if onda else DOURADO, HORIZONTAL_ALIGNMENT_CENTER, w)
	_texto(defesa.linha, r.position + Vector2(0, 40) * e, int(13 * e), Color(0.9, 0.88, 0.84), HORIZONTAL_ALIGNMENT_CENTER, w)
	var barras: Array = [["MURO", defesa.muro, Color(0.75, 0.6, 0.35)]]
	if defesa.get("resistencia", -1.0) >= 0.0:
		barras.append(["MORADORES", defesa.resistencia, Color(0.35, 0.7, 0.4)])
	if onda:
		for k in barras.size():
			var bx := r.position + Vector2(18 + k * 200, 52) * e
			_texto(barras[k][0], bx + Vector2(0, 11) * e, int(10 * e), Color(0.75, 0.75, 0.72))
			var bar := Rect2(bx + Vector2(70, 2) * e, Vector2(110, 10) * e)
			draw_rect(bar, Color(1, 1, 1, 0.08))
			var v: float = clampf(barras[k][1], 0.0, 1.0)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * v, bar.size.y)), barras[k][2] if v > 0.3 else Color(0.9, 0.25, 0.2))

func _barras(s: Vector2, e: float) -> void:
	var vals := [jogador.vida if jogador else 1.0, jogador.sede if jogador else 1.0, jogador.fome if jogador else 1.0, jogador.estamina if jogador else 1.0, sono]
	var cores := [Color(0.82, 0.16, 0.14), Color(0.2, 0.5, 0.9), Color(0.92, 0.62, 0.15), Color(0.25, 0.72, 0.28), Color(0.55, 0.45, 0.85)]
	var r := Rect2(Vector2(20 * e, s.y - 201 * e), Vector2(200, 181) * e)
	_painel(r)
	# doenças acima das barras
	for i in doencas.size():
		_texto("✚ " + String(doencas[i]), Vector2(r.position.x + 6 * e, r.position.y - (10 + i * 20) * e), int(14 * e), Color(0.95, 0.55, 0.35))
	for i in 5:
		var y := r.position.y + (20 + i * 33) * e
		var ic := Vector2(r.position.x + 22 * e, y + 6 * e)
		_icone_status(i, ic, e)
		var bar := Rect2(Vector2(r.position.x + 44 * e, y), Vector2(140, 13) * e)
		draw_rect(bar, Color(1, 1, 1, 0.08))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * vals[i], bar.size.y)), cores[i])

func _icone_status(i: int, c: Vector2, e: float) -> void:
	var b := Color(0.95, 0.95, 0.95)
	match i:
		0:
			draw_circle(c + Vector2(-4, -2) * e, 5 * e, b)
			draw_circle(c + Vector2(4, -2) * e, 5 * e, b)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 0) * e, c + Vector2(9, 0) * e, c + Vector2(0, 9) * e]), b)
		1:
			draw_circle(c + Vector2(0, 3) * e, 6 * e, b)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5.5, 1) * e, c + Vector2(0, -9) * e, c + Vector2(5.5, 1) * e]), b)
		2:
			draw_line(c + Vector2(-4, -8) * e, c + Vector2(-4, 9) * e, b, 2.2 * e)
			for dx in [-7, -4, -1]:
				draw_line(c + Vector2(dx, -8) * e, c + Vector2(dx, -2) * e, b, 1.4 * e)
			draw_line(c + Vector2(5, -8) * e, c + Vector2(5, 9) * e, b, 2.4 * e)
			draw_circle(c + Vector2(5, -4) * e, 2.8 * e, b)
		4:
			_texto("z", c + Vector2(-6, 5) * e, int(15 * e), b)
			_texto("z", c + Vector2(1, -1) * e, int(11 * e), b)
		3:
			draw_circle(c + Vector2(3, -8) * e, 2.6 * e, b)
			draw_polyline(PackedVector2Array([c + Vector2(-7, -3) * e, c + Vector2(-1, -5) * e, c + Vector2(2, 1) * e, c + Vector2(7, 2) * e]), b, 2 * e)
			draw_polyline(PackedVector2Array([c + Vector2(-1, -5) * e, c + Vector2(0, 2) * e, c + Vector2(-5, 5) * e, c + Vector2(-8, 9) * e]), b, 2.2 * e)
			draw_polyline(PackedVector2Array([c + Vector2(0, 2) * e, c + Vector2(5, 5) * e, c + Vector2(4, 10) * e]), b, 2.2 * e)

func _barra_rapida(s: Vector2, e: float) -> void:
	var tam := 64.0 * e
	var gap := 8.0 * e
	var total := itens.size() * tam + (itens.size() - 1) * gap
	var x0 := s.x * 0.5 - total * 0.5
	var y := s.y - tam - 22 * e
	for i in itens.size():
		var r := Rect2(Vector2(x0 + i * (tam + gap), y), Vector2(tam, tam))
		_painel(r, 4)
		if i == slot_ativo:
			draw_rect(r.grow(-1), Color(0.95, 0.95, 0.9, 0.9), false, 2.0 * e)
		_texto(str(i + 1), r.position + Vector2(6, 14) * e, int(12 * e), Color(1, 1, 1, 0.6))
		_texto(str(itens[i][1]), r.position + Vector2(0, tam - 8 * e), int(15 * e), Color(1, 1, 1), HORIZONTAL_ALIGNMENT_RIGHT, tam - 6 * e)
		_icone_item(itens[i][0], r.get_center() + Vector2(0, -2) * e, e)

func _icone_item(id: String, c: Vector2, e: float) -> void:
	var cinza := Color(0.65, 0.65, 0.66)
	var esc := Color(0.15, 0.15, 0.16)
	var mad := Color(0.55, 0.35, 0.18)
	match id:
		"pe_de_cabra":
			draw_line(c + Vector2(-14, 14) * e, c + Vector2(10, -12) * e, Color(0.7, 0.15, 0.1), 4 * e)
			draw_line(c + Vector2(10, -12) * e, c + Vector2(16, -8) * e, Color(0.7, 0.15, 0.1), 4 * e)
			return
		"taco":
			draw_line(c + Vector2(-14, 14) * e, c + Vector2(12, -14) * e, mad, 6 * e)
			for k in 4:
				draw_line(c + Vector2(4 + k * 2, -8 - k * 2) * e, c + Vector2(9 + k * 2, -3 - k * 2) * e, cinza, 1.2 * e)
			return
		"machado":
			draw_line(c + Vector2(-12, 15) * e, c + Vector2(8, -12) * e, mad, 4 * e)
			draw_colored_polygon(PackedVector2Array([c + Vector2(4, -16) * e, c + Vector2(16, -10) * e, c + Vector2(12, 0) * e, c + Vector2(4, -6) * e]), cinza)
			return
		"pistola":
			draw_rect(Rect2(c + Vector2(-14, -8) * e, Vector2(26, 8) * e), esc)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 0) * e, c + Vector2(-4, 0) * e, c + Vector2(-6, 12) * e, c + Vector2(-14, 12) * e]), esc)
			return
		"espingarda", "rifle":
			draw_line(c + Vector2(-18, 6) * e, c + Vector2(-4, 2) * e, mad, 6 * e)
			draw_line(c + Vector2(-4, 1) * e, c + Vector2(18, -6) * e, esc, 3 * e if id == "espingarda" else 2 * e)
			if id == "rifle":
				draw_rect(Rect2(c + Vector2(-2, -6) * e, Vector2(10, 4) * e), esc)
			return
		"besta":
			draw_line(c + Vector2(-14, 10) * e, c + Vector2(12, -8) * e, mad, 4 * e)
			draw_arc(c + Vector2(6, -4) * e, 12 * e, -2.4, 0.6, 10, esc, 2.5 * e)
			return
		"bandagem":
			draw_rect(Rect2(c + Vector2(-12, -6) * e, Vector2(24, 12) * e), Color(0.92, 0.9, 0.85))
			draw_line(c + Vector2(-12, 0) * e, c + Vector2(12, 0) * e, Color(0.8, 0.2, 0.15), 2 * e)
			return
		"analgesico":
			draw_rect(Rect2(c + Vector2(-7, -12) * e, Vector2(14, 22) * e), Color(0.95, 0.95, 0.95))
			draw_rect(Rect2(c + Vector2(-7, -12) * e, Vector2(14, 6) * e), Color(0.2, 0.45, 0.8))
			return
		"remedio":
			draw_rect(Rect2(c + Vector2(-10, -6) * e, Vector2(20, 12) * e), Color(0.9, 0.9, 0.88))
			draw_rect(Rect2(c + Vector2(-10, -6) * e, Vector2(10, 12) * e), Color(0.8, 0.2, 0.15))
			return
		"molotov":
			draw_rect(Rect2(c + Vector2(-6, -6) * e, Vector2(12, 18) * e), Color(0.3, 0.5, 0.25))
			draw_rect(Rect2(c + Vector2(-2, -14) * e, Vector2(4, 8) * e), Color(0.9, 0.85, 0.75))
			draw_circle(c + Vector2(0, -16) * e, 4 * e, Color(1.0, 0.55, 0.15))
			return
		"sinalizador":
			draw_rect(Rect2(c + Vector2(-4, -12) * e, Vector2(8, 24) * e), Color(0.85, 0.15, 0.1))
			draw_circle(c + Vector2(0, -14) * e, 3.5 * e, Color(1, 0.6, 0.5))
			return
		"comida":
			id = "lata"
		"carne_crua", "carne_assada":
			var cor_c := Color(0.75, 0.25, 0.25) if id == "carne_crua" else Color(0.55, 0.3, 0.15)
			draw_circle(c + Vector2(-2, 0) * e, 10 * e, cor_c)
			draw_line(c + Vector2(6, 6) * e, c + Vector2(15, 14) * e, Color(0.92, 0.9, 0.85), 4 * e)
			return
	match id:
		"facao":
			draw_line(c + Vector2(-16, 14) * e, c + Vector2(-8, 6) * e, Color(0.3, 0.2, 0.12), 5 * e)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 5) * e, c + Vector2(14, -18) * e, c + Vector2(18, -14) * e, c + Vector2(-6, 8) * e]), Color(0.75, 0.75, 0.75))
		"mochila":
			draw_rect(Rect2(c + Vector2(-11, -12) * e, Vector2(22, 26) * e), Color(0.45, 0.42, 0.28))
			draw_rect(Rect2(c + Vector2(-8, 2) * e, Vector2(16, 9) * e), Color(0.33, 0.3, 0.2))
			draw_arc(c + Vector2(0, -12) * e, 5 * e, PI, TAU, 8, Color(0.33, 0.3, 0.2), 2.5 * e)
		"medkit":
			draw_rect(Rect2(c + Vector2(-14, -10) * e, Vector2(28, 22) * e), Color(0.82, 0.14, 0.12))
			draw_rect(Rect2(c + Vector2(-2.5, -6) * e, Vector2(5, 14) * e), Color.WHITE)
			draw_rect(Rect2(c + Vector2(-7, -1.5) * e, Vector2(14, 5) * e), Color.WHITE)
		"lata":
			draw_rect(Rect2(c + Vector2(-9, -12) * e, Vector2(18, 25) * e), Color(0.85, 0.45, 0.12))
			draw_rect(Rect2(c + Vector2(-9, -4) * e, Vector2(18, 9) * e), Color(0.95, 0.85, 0.5))
			draw_line(c + Vector2(-9, -12) * e, c + Vector2(9, -12) * e, Color(0.7, 0.7, 0.7), 2 * e)
		"agua":
			draw_rect(Rect2(c + Vector2(-6, -8) * e, Vector2(12, 22) * e), Color(0.6, 0.78, 0.95, 0.85))
			draw_rect(Rect2(c + Vector2(-3, -14) * e, Vector2(6, 6) * e), Color(0.2, 0.4, 0.85))
			draw_rect(Rect2(c + Vector2(-6, 0) * e, Vector2(12, 6) * e), Color(0.2, 0.45, 0.85))
		"madeira":
			for k in 3:
				var o := Vector2(0, (k - 1) * 7) * e
				var cor := Color(0.62, 0.44, 0.25).darkened(k * 0.08)
				draw_colored_polygon(PackedVector2Array([c + o + Vector2(-16, 2) * e, c + o + Vector2(10, -6) * e, c + o + Vector2(16, -2) * e, c + o + Vector2(-10, 6) * e]), cor)

func _bussola(s: Vector2, e: float) -> void:
	var raio := 92.0 * e
	var c := Vector2(s.x - raio - 26 * e, s.y - raio - 26 * e)
	draw_circle(c, raio, Color(0.05, 0.06, 0.06, 0.78))
	draw_arc(c, raio, 0, TAU, 64, Color(1, 1, 1, 0.18), 1.5 * e)
	var yaw := jogador.yaw if jogador else 0.0
	var pos := jogador.position if jogador else Vector3.ZERO
	# estrada (linha clara indicando a direção +Z)
	var escala := raio / 60.0
	var pontos := PackedVector2Array()
	if jogador and jogador.mundo:
		for i in range(-8, 9):
			var z := pos.z + i * 8.0
			var w := Vector3(jogador.mundo.centro_x(z), 0, z)
			var p := _mapa(w - pos, yaw) * escala
			if p.length() < raio - 4 * e:
				pontos.append(c + p)
	if pontos.size() > 1:
		draw_polyline(pontos, Color(0.75, 0.72, 0.6, 0.55), 6 * e)
	for ap in aliados:
		var pa := _mapa(ap - pos, yaw) * escala
		if pa.length() < raio - 6 * e:
			draw_circle(c + pa, 3.5 * e, Color(0.35, 0.85, 0.95))
	for zp in zumbis:
		var p := _mapa(zp - pos, yaw) * escala
		if p.length() < raio - 6 * e:
			draw_circle(c + p, 3.5 * e, Color(0.9, 0.12, 0.1))
	# lugares conhecidos (vila, fazenda, ferro-velho)
	for l in lugares:
		var lp := _mapa(l.pos - pos, yaw) * escala
		if lp.length() > raio - 10 * e:
			lp = lp.normalized() * (raio - 10 * e)
		var q2 := c + lp
		var cor_l: Color = {"vila": Color(0.45, 0.85, 0.5), "fazenda": Color(0.95, 0.85, 0.35), "ferro_velho": Color(0.9, 0.55, 0.3)}.get(l.tipo, Color(0.55, 0.75, 0.95))
		draw_rect(Rect2(q2 + Vector2(-5, -2) * e, Vector2(10, 8) * e), cor_l)
		draw_colored_polygon(PackedVector2Array([q2 + Vector2(-7, -2) * e, q2 + Vector2(0, -9) * e, q2 + Vector2(7, -2) * e]), cor_l)
	# torre de rádio: o que vem pela frente
	for it in radar:
		var rp := _mapa(it.pos - pos, yaw) * escala
		if rp.length() > raio - 10 * e:
			rp = rp.normalized() * (raio - 10 * e)
		var qr := c + rp
		draw_circle(qr, 7 * e, Color(0.05, 0.05, 0.05, 0.8))
		draw_arc(qr, 7 * e, 0, TAU, 16, it.cor, 1.5 * e)
		_texto(it.letra, qr + Vector2(-4, 4.5) * e, int(11 * e), it.cor)
	# marcadores do rádio
	for m in marcadores:
		var mp := _mapa(m - pos, yaw) * escala
		if mp.length() > raio - 10 * e:
			mp = mp.normalized() * (raio - 10 * e)
		var q := c + mp
		draw_colored_polygon(PackedVector2Array([q + Vector2(0, -7) * e, q + Vector2(7, 0) * e, q + Vector2(0, 7) * e, q + Vector2(-7, 0) * e]), DOURADO)
	# trailer
	var tp := _mapa(trailer_pos - pos, yaw) * escala
	if tp.length() > raio - 10 * e:
		tp = tp.normalized() * (raio - 10 * e)
	draw_rect(Rect2(c + tp - Vector2(9, 5) * e, Vector2(18, 10) * e), Color(0.92, 0.92, 0.88))
	draw_circle(c + tp + Vector2(-5, 6) * e, 2.5 * e, Color(0.92, 0.92, 0.88))
	draw_circle(c + tp + Vector2(5, 6) * e, 2.5 * e, Color(0.92, 0.92, 0.88))
	# jogador
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10) * e, c + Vector2(7, 8) * e, c + Vector2(0, 4) * e, c + Vector2(-7, 8) * e]), Color.WHITE)
	# pontos cardeais (norte = +Z)
	var nomes := {"N": Vector3(0, 0, 1), "L": Vector3(-1, 0, 0), "S": Vector3(0, 0, -1), "O": Vector3(1, 0, 0)}
	for k in nomes:
		var d: Vector2 = _mapa(nomes[k], yaw).normalized() * (raio + 13 * e)
		_texto(k, c + d + Vector2(-6, 6) * e, int(16 * e), Color(1, 1, 1, 0.9))

## Converte deslocamento no mundo para o mini-mapa (para cima = para onde o jogador olha).
func _mapa(d: Vector3, yaw: float) -> Vector2:
	var f := Vector3(sin(yaw), 0, cos(yaw))
	var r := Vector3(-cos(yaw), 0, sin(yaw))
	return Vector2(d.dot(r), -d.dot(f))

func _recursos(e: float) -> void:
	if estoque.is_empty():
		return
	var r := Rect2(Vector2(20, 94) * e, Vector2(340, 30) * e)
	r.size.y = 52 * e
	_painel(r)
	_texto("Peças %d   Sucata %d   Pneus %d   Eixos %d   Galões %d" % [estoque.get("pecas", 0), estoque.get("sucata", 0), estoque.get("pneu", 0), estoque.get("eixo", 0), estoque.get("galoes_diesel", 0)], r.position + Vector2(12, 21) * e, int(14 * e), Color(0.85, 0.85, 0.8))
	var cheia := carga_usada >= carga_max - 0.5
	_texto("Carga %d / %d%s%s" % [int(carga_usada), carga_max, ("   ·   Projetos %d" % projetos) if projetos > 0 else "", ("   ·   " + recrutas_txt) if recrutas_txt != "" else ""], r.position + Vector2(12, 42) * e, int(13 * e), Color(0.95, 0.45, 0.3) if cheia else Color(0.7, 0.7, 0.66))

func _painel_veiculo(s: Vector2, e: float) -> void:
	var w := 520.0 * e
	var h := 92.0 * e
	var r := Rect2(Vector2(s.x * 0.5 - w * 0.5, s.y - h - 22 * e), Vector2(w, h))
	_painel(r)
	# velocímetro
	var vel := "%d" % int(round(km_h))
	_texto(vel, r.position + Vector2(18, 58) * e, int(46 * e), Color(1, 1, 1))
	_texto("km/h", r.position + Vector2(20, 80) * e, int(14 * e), Color(1, 1, 1, 0.6))
	if re:
		_texto("R", r.position + Vector2(110, 58) * e, int(30 * e), DOURADO)
	# combustível
	var bx := r.position + Vector2(150, 26) * e
	_texto("DIESEL", bx + Vector2(0, -4) * e, int(13 * e), Color(1, 1, 1, 0.65))
	var bar := Rect2(bx + Vector2(0, 6) * e, Vector2(205, 14) * e)
	draw_rect(bar, Color(1, 1, 1, 0.08))
	var f := clampf(diesel / tanque, 0.0, 1.0)
	var cor := Color(0.9, 0.2, 0.15) if f < 0.15 else Color(0.95, 0.68, 0.22)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), cor)
	for i in range(1, 4):
		var x := bar.position.x + bar.size.x * i / 4.0
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.5), 1.0)
	_texto("%d / %d L" % [int(diesel), int(tanque)], bx + Vector2(0, 42) * e, int(14 * e))
	if fora_estrada:
		_texto("FORA DA ESTRADA", bx + Vector2(85, 42) * e, int(13 * e), Color(0.9, 0.45, 0.2))
	_texto("[F] Sair  [Espaço] Freio  [V] Câmera", bx + Vector2(0, 62) * e, int(12 * e), Color(1, 1, 1, 0.5))
	# temperatura e carga rebocada
	var tx := r.position + Vector2(372, 26) * e
	_texto("MOTOR", tx + Vector2(0, -4) * e, int(13 * e), Color(1, 1, 1, 0.65))
	var tb := Rect2(tx + Vector2(0, 6) * e, Vector2(130, 14) * e)
	draw_rect(tb, Color(1, 1, 1, 0.08))
	var tf := clampf(temperatura, 0.0, 1.0)
	var tc := Color(0.3, 0.6, 0.95).lerp(Color(0.95, 0.75, 0.2), smoothstep(0.4, 0.75, tf)).lerp(Color(0.95, 0.2, 0.12), smoothstep(0.8, 1.0, tf))
	draw_rect(Rect2(tb.position, Vector2(tb.size.x * tf, tb.size.y)), tc)
	draw_line(Vector2(tb.position.x + tb.size.x * 0.8, tb.position.y - 2 * e), Vector2(tb.position.x + tb.size.x * 0.8, tb.end.y + 2 * e), Color(1, 1, 1, 0.5), 1.0)
	var rz := peso_rebocado / maxf(capacidade_reboque, 1.0)
	var cor_rz := Color(0.85, 0.85, 0.8) if rz <= 1.0 else (Color(0.95, 0.7, 0.2) if rz <= 1.4 else Color(0.95, 0.25, 0.15))
	_texto("%.1f / %.1f t" % [peso_rebocado / 1000.0, capacidade_reboque / 1000.0], tx + Vector2(0, 42) * e, int(14 * e), cor_rz)
	if superaquecido and int(Time.get_ticks_msec() / 400) % 2 == 0:
		_texto("SUPERAQUECIDO", tx + Vector2(0, 62) * e, int(12 * e), Color(0.95, 0.25, 0.15))
	elif rz > 1.0:
		_texto("PESO ACIMA DA CAPACIDADE", tx + Vector2(0, 62) * e, int(11 * e), cor_rz)

func _caixa_texto(titulo: String, txt: String, s: Vector2, e: float, y_rel: float) -> void:
	var w := 640.0 * e
	var linhas: Array[String] = []
	for par in txt.split("\n"):
		var atual := ""
		for palavra in par.split(" "):
			if (atual + " " + palavra).length() > 64 and atual != "":
				linhas.append(atual)
				atual = palavra
			else:
				atual = palavra if atual == "" else atual + " " + palavra
		linhas.append(atual)
	var h := (54 + linhas.size() * 24) * e
	var r := Rect2(Vector2(s.x * 0.5 - w * 0.5, s.y * y_rel), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.07, 0.88)
	sb.set_corner_radius_all(int(6 * e))
	sb.border_width_top = int(3 * e)
	sb.border_color = DOURADO
	draw_style_box(sb, r)
	_texto(titulo, r.position + Vector2(20, 30) * e, int(15 * e), DOURADO)
	for i in linhas.size():
		_texto(linhas[i], r.position + Vector2(20, 58 + i * 24) * e, int(17 * e), Color(0.92, 0.9, 0.85))
