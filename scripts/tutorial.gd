class_name Tutorial
extends Control
## Tutorial do começo do jogo: passos curtos, cada um com as teclas e uma condição
## que completa sozinha quando o jogador faz a ação. Aparece no primeiro jogo
## (fica salvo em user://config.cfg); F1 reabre; Enter pula o passo; Backspace encerra.

const CONFIG := "user://config.cfg"
const PASSOS := [
	{"titulo": "Bem-vindo à estrada", "texto": "O mundo acabou. Tudo o que você tem é a picape e o trailer.\nAnde um pouco para se acostumar.", "teclas": ["W", "A", "S", "D"], "cond": "mover"},
	{"titulo": "Olhe em volta e corra", "texto": "Gire a câmera com o mouse. Segure Shift para correr\n(gasta fôlego, a barra verde).", "teclas": ["Mouse", "Shift"], "cond": "correr"},
	{"titulo": "Agache e ande em silêncio", "texto": "Agachado você faz menos barulho, e um golpe pelas costas\nde um zumbi distraído causa o triplo de dano.", "teclas": ["Ctrl"], "cond": "agachar"},
	{"titulo": "Golpeie", "texto": "Clique com o botão esquerdo para usar o facão.\nCada golpe cansa: cuidado com a fôlego.", "teclas": ["Botão esq."], "cond": "atacar"},
	{"titulo": "Barra rápida", "texto": "Troque o que está na mão com as teclas 1 a 9 ou a roda do mouse.\nComida, água e curativos também ficam aqui.", "teclas": ["1-9", "Roda"], "cond": "barra"},
	{"titulo": "Compartimentos do trailer", "texto": "Vá até a lateral do trailer e abra um compartimento.\nDespensa, caixa de ferramentas e bagageiro guardam suas coisas.", "teclas": ["E"], "cond": "compartimento"},
	{"titulo": "Entre no trailer", "texto": "Pela porta lateral você entra no trailer: lá dá para dormir,\nouvir o rádio e se esconder. Saia com F.", "teclas": ["E", "F"], "cond": "trailer"},
	{"titulo": "Oficina", "texto": "Tab abre a oficina: conserte e melhore a picape, o trailer\ne os reboques com peças e sucata.", "teclas": ["Tab"], "cond": "oficina"},
	{"titulo": "Criação", "texto": "B abre a criação: curta peles, faça armaduras de couro,\nrefine metal e prepare comida.", "teclas": ["B"], "cond": "criar"},
	{"titulo": "Pegue a estrada", "texto": "Chegue perto da porta da picape e aperte F para dirigir.\nEspaço freia, V troca a câmera. Diesel é vida.", "teclas": ["F", "Espaço", "V"], "cond": "dirigir"},
	{"titulo": "Boa sorte", "texto": "Vasculhe casas e carros, junte recrutas, ache reboques e\ndefenda assentamentos da horda. F1 reabre este tutorial.", "teclas": ["F1"], "cond": "tempo"},
]

var main: Node
var passo := 0
var ativo := false
var _t := 0.0
var _anim := 0.0
var _feito_t := -1.0
var _ref := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

static func ja_visto() -> bool:
	var c := ConfigFile.new()
	if c.load(CONFIG) != OK:
		return false
	return c.get_value("tutorial", "visto", false)

static func marcar_visto() -> void:
	var c := ConfigFile.new()
	c.load(CONFIG)
	c.set_value("tutorial", "visto", true)
	c.save(CONFIG)

func iniciar() -> void:
	ativo = true
	visible = true
	passo = 0
	_comecar_passo()

func encerrar() -> void:
	ativo = false
	visible = false
	marcar_visto()

func _comecar_passo() -> void:
	_t = 0.0
	_anim = 0.0
	_feito_t = -1.0
	var j: Node3D = main.jogador
	_ref = {"pos": j.global_position, "yaw": j.yaw, "sel": main.equip.sel, "dist": 0.0, "giro": 0.0, "correu": 0.0, "dentro": false}

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_F1:
			iniciar()
		elif ativo and e.keycode == KEY_ENTER:
			_avancar()
		elif ativo and e.keycode == KEY_BACKSPACE:
			encerrar()

func _avancar() -> void:
	passo += 1
	if passo >= PASSOS.size():
		encerrar()
		return
	_comecar_passo()

func _process(dt: float) -> void:
	if not ativo or main == null:
		return
	_t += dt
	_anim = minf(1.0, _anim + dt * 3.0)
	if _feito_t >= 0.0:
		_feito_t += dt
		if _feito_t > 1.1:
			_avancar()
		queue_redraw()
		return
	if _cumpriu(PASSOS[passo].cond, dt):
		_feito_t = 0.0
	queue_redraw()

func _cumpriu(c: String, dt: float) -> bool:
	var j = main.jogador
	match c:
		"mover":
			var p: Vector3 = j.global_position
			_ref.dist += Vector2(p.x - _ref.pos.x, p.z - _ref.pos.z).length()
			_ref.pos = p
			return _ref.dist > 4.0
		"correr":
			_ref.giro += absf(wrapf(j.yaw - _ref.yaw, -PI, PI))
			_ref.yaw = j.yaw
			if Input.is_action_pressed("sprint") and j.intensidade > 0.5:
				_ref.correu += dt
			return _ref.giro > 1.2 and _ref.correu > 0.8
		"agachar":
			if j.agachado and j.intensidade > 0.3:
				_ref.correu += dt
			return _ref.correu > 0.6
		"atacar":
			return j._t_golpe > 0.0
		"barra":
			return main.equip.sel != _ref.sel
		"compartimento":
			for id in main.trailer.compartimentos_abertos:
				if main.trailer.compartimentos_abertos[id]:
					return true
			return false
		"trailer":
			if main.dentro == main.trailer:
				_ref.dentro = true
			return _ref.dentro and main.dentro == null
		"oficina":
			return main.oficina.visible
		"criar":
			return Input.is_action_just_pressed("criar")
		"dirigir":
			return main.comboio.dirigindo and absf(main.comboio.velocidade) > 3.0
		"tempo":
			return _t > 7.0
	return false

# ------------------------------------------------------------ desenho
func _draw() -> void:
	if not ativo:
		return
	var s := get_viewport_rect().size
	var e := clampf(s.y / 900.0, 0.7, 2.0)
	var p: Dictionary = PASSOS[passo]
	var w := 540.0 * e
	var h := 150.0 * e
	var y := 104.0 * e
	var r := Rect2(Vector2(s.x - w - 20 * e + (1.0 - _anim) * 40.0 * e, y), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.065, 0.06, 0.88 * _anim)
	sb.set_corner_radius_all(int(8 * e))
	sb.border_width_top = int(3 * e)
	sb.border_color = Color(0.95, 0.68, 0.22, _anim)
	draw_style_box(sb, r)
	var f := get_theme_default_font()
	var dour := Color(0.95, 0.68, 0.22, _anim)
	var branco := Color(0.92, 0.9, 0.86, _anim)
	var cinza := Color(0.65, 0.63, 0.6, _anim)
	draw_string(f, r.position + Vector2(20, 30) * e, "TUTORIAL  %d/%d" % [passo + 1, PASSOS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * e), cinza)
	draw_string(f, r.position + Vector2(20, 56) * e, p.titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * e), dour)
	var linhas: PackedStringArray = String(p.texto).split("\n")
	for i in linhas.size():
		draw_string(f, r.position + Vector2(20, 82 + i * 20) * e, linhas[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * e), branco)
	# teclas
	var x := r.position.x + 20 * e
	var ty := r.position.y + h - 30 * e
	for t in p.teclas:
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * e)).x + 18 * e
		var kr := Rect2(Vector2(x, ty - 2 * e), Vector2(tw, 24 * e))
		var kb := StyleBoxFlat.new()
		kb.bg_color = Color(0.2, 0.19, 0.17, _anim)
		kb.set_corner_radius_all(int(4 * e))
		kb.border_width_bottom = int(3 * e)
		kb.border_color = Color(0.05, 0.05, 0.05, _anim)
		draw_style_box(kb, kr)
		draw_string(f, kr.position + Vector2(9 * e, 17 * e), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * e), branco)
		x += tw + 8 * e
	draw_string(f, Vector2(r.end.x - 260 * e, ty + 16 * e), "Enter: pular passo   Backspace: sair", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * e), cinza)
	# barra de progresso dos passos
	for i in PASSOS.size():
		var bw := (w - 40 * e) / PASSOS.size()
		var br := Rect2(Vector2(r.position.x + 20 * e + i * bw, r.end.y - 6 * e), Vector2(bw - 3 * e, 3 * e))
		draw_rect(br, dour if i < passo or (i == passo and _feito_t >= 0.0) else Color(0.3, 0.29, 0.27, _anim))
	if _feito_t >= 0.0:
		var a := clampf(1.0 - _feito_t, 0.0, 1.0)
		draw_string(f, Vector2(r.end.x - 120 * e, r.position.y + 56 * e), "FEITO!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * e), Color(0.45, 0.85, 0.35, a + 0.3))
