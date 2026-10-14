class_name Menu
extends Control
## Tela inicial (escolha do modo) e tela de morte.

signal escolheu(modo: String)
signal continuar
signal recomecar
signal carregar

const DOURADO := Color(0.95, 0.68, 0.22)
var _caixa: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_dt: float) -> void:
	if visible:
		size = get_viewport_rect().size

func _limpar() -> void:
	for c in get_children():
		c.queue_free()

func _fundo(alfa: float) -> void:
	var f := ColorRect.new()
	f.color = Color(0.03, 0.025, 0.03, alfa)
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(f)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	_caixa = VBoxContainer.new()
	_caixa.add_theme_constant_override("separation", 14)
	_caixa.custom_minimum_size = Vector2(760, 0)
	centro.add_child(_caixa)

func _label(t: String, tam: int, cor := Color(0.93, 0.91, 0.86), centro := true) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centro:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caixa.add_child(l)
	return l

func _cartao(titulo: String, texto: String, acao: Callable, destaque := false) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(760, 116)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.09, 0.92)
	sb.set_corner_radius_all(8)
	sb.border_width_left = 4
	sb.border_color = DOURADO if destaque else Color(0.5, 0.5, 0.5)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	var sh := sb.duplicate()
	sh.bg_color = Color(0.14, 0.12, 0.1, 0.95)
	sh.border_color = DOURADO
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("focus", sh)
	b.pressed.connect(func(): Som.tela("clique_ui", -6.0))
	b.pressed.connect(acao)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_right = -24
	v.offset_top = 14
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var t := Label.new()
	t.text = titulo
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", DOURADO)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var d := Label.new()
	d.text = texto
	d.add_theme_font_size_override("font_size", 16)
	d.add_theme_color_override("font_color", Color(0.82, 0.8, 0.76))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(700, 0)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	_caixa.add_child(b)

func mostrar_inicio() -> void:
	_limpar()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fundo(0.55)
	_label("ESTRADA SEM FIM", 64, Color(0.96, 0.93, 0.85))
	_label("O mundo caiu. Tudo o que você tem é o seu comboio.", 18, DOURADO)
	var esp := Control.new()
	esp.custom_minimum_size = Vector2(0, 18)
	_caixa.add_child(esp)
	var rs := Salvar.resumo()
	if not rs.is_empty():
		var modo_txt := "Sobrevivência total" if rs.modo == Jogo.MODO_TOTAL else "Estrada sem fim"
		_cartao("Continuar", "%s · Dia %d · %.1f km rodados · %d reboque%s · %d recruta%s\nSalvo em %s" % [modo_txt, rs.dia, rs.km, rs.reboques, "" if rs.reboques == 1 else "s", rs.recrutas, "" if rs.recrutas == 1 else "s", String(rs.data).replace("T", " ").substr(0, 16)], func():
			visible = false
			carregar.emit(), true)
		_label("Ou comece um jogo novo (o salvo atual fica guardado como \"anterior\"):", 15, Color(0.7, 0.7, 0.68))
	else:
		_label("Escolha o modo. Ele não pode ser trocado depois.", 16, Color(0.7, 0.7, 0.68))
	_cartao("Sobrevivência total", "Morreu ou perdeu uma defesa, acabou: o mundo é gerado de novo e você recomeça do zero, só com a picape e o trailer.", func(): _escolher(Jogo.MODO_TOTAL), rs.is_empty())
	_cartao("Estrada sem fim", "Morrer cobra caro: reboques perdidos ou destruídos, recrutas mortos, metade da carga perdida. Mas a estrada continua e o progresso fica.", func(): _escolher(Jogo.MODO_INFINITO))
	var esp2 := Control.new()
	esp2.custom_minimum_size = Vector2(0, 8)
	_caixa.add_child(esp2)
	_label("CONTROLES", 15, DOURADO)
	_label("WASD andar · Shift correr · Ctrl agachar · Mouse olhar · Botão esq. atacar/usar · Botão dir. mirar · R recarregar\n1-9 / rodinha trocar item · E interagir/vasculhar · F entrar/dirigir · Tab oficina · B criação · C acampar · H remédio · Z binóculo · J diário\nNo carro: WASD dirigir · Espaço freio · G engatar · L luz · V câmera · R abastecer com galão · Esc solta o mouse · F5 salvar · J diário", 13, Color(0.8, 0.78, 0.74))

func _escolher(m: String) -> void:
	visible = false
	escolheu.emit(m)

## Tela de morte. linhas = penalidades (modo infinito) ou estatísticas (modo total).
func mostrar_morte(causa: String, linhas: Array, total: bool) -> void:
	_limpar()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fundo(0.82)
	_label("VOCÊ MORREU" if total else "VOCÊ CAIU", 60, Color(0.85, 0.2, 0.15))
	_label(causa, 20, Color(0.9, 0.88, 0.82))
	var esp := Control.new()
	esp.custom_minimum_size = Vector2(0, 10)
	_caixa.add_child(esp)
	for l in linhas:
		_label(l, 17, Color(0.8, 0.78, 0.74))
	var esp2 := Control.new()
	esp2.custom_minimum_size = Vector2(0, 10)
	_caixa.add_child(esp2)
	if total:
		_cartao("Começar de novo", "Um novo mundo, uma nova estrada.", func(): recomecar.emit(), true)
	else:
		_cartao("Acordar", "Você recobra a consciência dentro do trailer, na manhã seguinte.", func():
			visible = false
			continuar.emit(), true)
