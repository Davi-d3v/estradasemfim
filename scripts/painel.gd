class_name Painel
extends Control
## Janela genérica de ações. O conteúdo vem de uma função geradora que devolve:
## {"titulo": String, "subtitulo": String, "linhas": [String | [texto, cor]],
##  "botoes": [[texto, Callable, habilitado(bool)]]}
## Depois de cada botão o conteúdo é gerado de novo.

signal fechado

const DOURADO := Color(0.95, 0.68, 0.22)
var _gerador: Callable
var _titulo: Label
var _sub: Label
var _linhas: VBoxContainer
var _botoes: GridContainer
var _aviso: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.35)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var painel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.08, 0.95)
	sb.set_corner_radius_all(8)
	sb.border_width_top = 3
	sb.border_color = DOURADO
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	painel.add_theme_stylebox_override("panel", sb)
	painel.custom_minimum_size = Vector2(620, 0)
	centro.add_child(painel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	painel.add_child(col)
	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 24)
	_titulo.add_theme_color_override("font_color", DOURADO)
	col.add_child(_titulo)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 14)
	_sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.68))
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_sub)
	col.add_child(HSeparator.new())
	_linhas = VBoxContainer.new()
	_linhas.add_theme_constant_override("separation", 3)
	col.add_child(_linhas)
	_botoes = GridContainer.new()
	_botoes.columns = 2
	_botoes.add_theme_constant_override("h_separation", 8)
	_botoes.add_theme_constant_override("v_separation", 6)
	col.add_child(_botoes)
	_aviso = Label.new()
	_aviso.add_theme_color_override("font_color", DOURADO)
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_aviso)
	var rod := Label.new()
	rod.text = "[Tab] Fechar"
	rod.add_theme_font_size_override("font_size", 13)
	rod.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58))
	col.add_child(rod)
	visible = false

func mostrar(gerador: Callable) -> void:
	_gerador = gerador
	_aviso.text = ""
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	atualizar()

func avisar(t: String) -> void:
	_aviso.text = t

func atualizar() -> void:
	size = get_viewport_rect().size
	if not _gerador.is_valid():
		return
	var d: Dictionary = _gerador.call()
	_titulo.text = d.get("titulo", "")
	_sub.text = d.get("subtitulo", "")
	_sub.visible = _sub.text != ""
	for c in _linhas.get_children():
		c.queue_free()
	for c in _botoes.get_children():
		c.queue_free()
	for l in d.get("linhas", []):
		var lb := Label.new()
		lb.add_theme_font_size_override("font_size", 16)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.custom_minimum_size = Vector2(570, 0)
		if l is Array:
			lb.text = l[0]
			lb.add_theme_color_override("font_color", l[1])
		else:
			lb.text = l
		_linhas.add_child(lb)
	var bts: Array = d.get("botoes", [])
	_botoes.columns = 1 if bts.size() <= 2 else 2
	for b in bts:
		var bt := Button.new()
		bt.text = b[0]
		bt.custom_minimum_size = Vector2(280 if _botoes.columns == 2 else 570, 34)
		bt.disabled = not (b[2] if b.size() > 2 else true)
		var f: Callable = b[1]
		bt.pressed.connect(func():
			var msg = f.call()
			if msg is String and msg != "":
				_aviso.text = msg
			atualizar())
		_botoes.add_child(bt)

func _process(_dt: float) -> void:
	if visible:
		size = get_viewport_rect().size

func _input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("oficina"):
		get_viewport().set_input_as_handled()
		visible = false
		fechado.emit()
