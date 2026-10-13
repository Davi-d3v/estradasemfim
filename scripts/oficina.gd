class_name Oficina
extends Control
## Menu da oficina com três abas: Picape, Trailer e Engates.

signal fechado
signal desengatar(indice: int)

var trailer: Trailer
var picape: Pickup
var comboio: Comboio
var estoque: Dictionary  # {"pecas": int, "sucata": int, ...}
var aba := "trailer"

var _lista: VBoxContainer
var _cabecalho: Label
var _recursos: Label
var _aviso: Label
var _abas: HBoxContainer

const COR_FUNDO := Color(0.07, 0.07, 0.08, 0.95)
const DOURADO := Color(0.95, 0.68, 0.22)

static func custo_reparo(cond: float) -> int:
	return int(ceil((1.0 - cond) * 5.0))

static func custo_melhoria(nivel: int) -> Dictionary:
	return {"sucata": 6 + nivel * 8, "pecas": nivel * 2}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.45)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var painel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_FUNDO
	sb.set_corner_radius_all(8)
	sb.border_width_top = 3
	sb.border_color = DOURADO
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	painel.add_theme_stylebox_override("panel", sb)
	painel.custom_minimum_size = Vector2(1000, 0)
	centro.add_child(painel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	painel.add_child(col)
	var topo := HBoxContainer.new()
	col.add_child(topo)
	var titulo := Label.new()
	titulo.text = "OFICINA"
	titulo.add_theme_font_size_override("font_size", 26)
	titulo.add_theme_color_override("font_color", DOURADO)
	titulo.custom_minimum_size = Vector2(150, 0)
	topo.add_child(titulo)
	_abas = HBoxContainer.new()
	_abas.add_theme_constant_override("separation", 6)
	_abas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_abas)
	for a in [["picape", "Picape"], ["trailer", "Trailer"], ["engates", "Engates"]]:
		var b := Button.new()
		b.text = a[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(110, 34)
		b.pressed.connect(_trocar_aba.bind(a[0]))
		b.set_meta("aba", a[0])
		_abas.add_child(b)
	_recursos = Label.new()
	_recursos.add_theme_font_size_override("font_size", 17)
	topo.add_child(_recursos)

	_cabecalho = Label.new()
	_cabecalho.add_theme_font_size_override("font_size", 15)
	_cabecalho.add_theme_color_override("font_color", Color(0.75, 0.75, 0.72))
	col.add_child(_cabecalho)
	col.add_child(HSeparator.new())
	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(0, 470)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(rolagem)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 6)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_lista)
	_aviso = Label.new()
	_aviso.add_theme_font_size_override("font_size", 15)
	_aviso.add_theme_color_override("font_color", DOURADO)
	col.add_child(_aviso)
	var rodape := Label.new()
	rodape.text = "[Tab] Fechar   ·   Cada melhoria aumenta o peso do comboio: mais consumo e menos velocidade"
	rodape.add_theme_font_size_override("font_size", 13)
	rodape.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58))
	col.add_child(rodape)
	atualizar()

func _process(_dt: float) -> void:
	if visible:
		size = get_viewport_rect().size

func _trocar_aba(a: String) -> void:
	aba = a
	_aviso.text = ""
	atualizar()

func atualizar() -> void:
	size = get_viewport_rect().size
	if not _lista:
		return
	for b in _abas.get_children():
		b.button_pressed = b.get_meta("aba") == aba
	for c in _lista.get_children():
		c.queue_free()
	_recursos.text = "Peças: %d    Sucata: %d" % [estoque.get("pecas", 0), estoque.get("sucata", 0)]
	var peso := int(comboio.peso_total()) if comboio else 0
	match aba:
		"picape":
			_cabecalho.text = "Puxa sem sofrer: %.1f t   ·   Limite do chassi: %.1f t   ·   Rebocando: %.1f t   ·   Tanque: %d L" % [picape.capacidade_reboque() / 1000.0, picape.limite_engate() / 1000.0, comboio.peso_rebocado() / 1000.0, int(picape.tanque_litros())]
			for slot in picape.config:
				var c: Dictionary = picape.config[slot]
				_lista.add_child(_linha(Pickup.MODULOS[slot].nome, Pickup.MODULOS[slot].desc, c.nivel, Pickup.MODULOS[slot].nivel_max, c.condicao,
					_reparar_picape.bind(slot), _melhorar_picape.bind(slot)))
		"trailer":
			_cabecalho.text = "Peso do trailer: %d kg   ·   Peso total do comboio: %d kg" % [int(trailer.peso_total()), peso]
			for slot in trailer.config:
				var c: Dictionary = trailer.config[slot]
				var info: Dictionary = Trailer.MODULOS[c.id]
				_lista.add_child(_linha(info.nome, "", c.nivel, info.nivel_max, c.condicao,
					_reparar_trailer.bind(slot), _melhorar_trailer.bind(slot)))
		"engates":
			var n := comboio.cadeia.size() - 1
			_cabecalho.text = "Reboques: %d   ·   Rebocando %.1f t   ·   Capacidade %.1f t   ·   Limite do chassi %.1f t" % [n, comboio.peso_rebocado() / 1000.0, picape.capacidade_reboque() / 1000.0, picape.limite_engate() / 1000.0]
			if n == 0:
				var vazio := Label.new()
				vazio.text = "Nenhum reboque engatado. Reboques abandonados são raros e vêm quebrados:\nconserte os defeitos no local (pneus e eixos saem de carros desmontados) e engate com [G].\nCom a Oficina móvel e um projeto, dá para construir os seus."
				vazio.add_theme_color_override("font_color", Color(0.7, 0.7, 0.68))
				_lista.add_child(vazio)
			for i in range(1, comboio.cadeia.size()):
				var r: Reboque = comboio.cadeia[i]
				var desc := "%s: %d %s · %d kg%s" % [r.info().desc, r.capacidade(), r.info().unidade, int(r.peso_total()), "" if r.funcional() else " · PRECISA DE REPARO"]
				var linha := _linha(r.nome_exibicao(), desc, r.nivel, r.info().nivel_max, r.condicao,
					_reparar_reboque.bind(r), _melhorar_reboque.bind(r))
				var bt := Button.new()
				bt.text = "Desengatar"
				bt.custom_minimum_size = Vector2(110, 0)
				bt.pressed.connect(func(): desengatar.emit(i))
				linha.add_child(bt)
				_lista.add_child(linha)

func _linha(nome_txt: String, desc: String, nivel: int, nivel_max: int, cond: float, f_rep: Callable, f_mel: Callable) -> Control:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	var nomes := VBoxContainer.new()
	nomes.custom_minimum_size = Vector2(230, 0)
	nomes.add_theme_constant_override("separation", -4)
	var nome := Label.new()
	nome.text = nome_txt
	nome.add_theme_font_size_override("font_size", 17)
	nomes.add_child(nome)
	if desc != "":
		var d := Label.new()
		d.text = desc
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58))
		nomes.add_child(d)
	linha.add_child(nomes)

	var nv := Label.new()
	var est := ""
	for i in nivel_max:
		est += "■ " if i < nivel else "□ "
	nv.text = "Nv %s" % est
	nv.custom_minimum_size = Vector2(100, 0)
	nv.add_theme_color_override("font_color", DOURADO)
	linha.add_child(nv)

	var instalado := nivel > 0
	var barra := ProgressBar.new()
	barra.max_value = 1.0
	barra.value = cond if instalado else 0.0
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(130, 16)
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.82, 0.2, 0.15).lerp(Color(0.3, 0.75, 0.3), cond)
	barra.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	barra.add_theme_stylebox_override("background", bg)
	linha.add_child(barra)
	var pct := Label.new()
	pct.text = ("%d%%" % int(cond * 100.0)) if instalado else "—"
	pct.custom_minimum_size = Vector2(46, 0)
	linha.add_child(pct)

	var rep := Button.new()
	var cr := custo_reparo(cond) if instalado else 0
	rep.text = ("Reparar (%d %s)" % [cr, "peça" if cr == 1 else "peças"]) if cr > 0 else ("Inteiro" if instalado else "Não instalado")
	rep.custom_minimum_size = Vector2(150, 0)
	rep.disabled = cr == 0 or estoque.get("pecas", 0) < cr
	rep.pressed.connect(f_rep)
	linha.add_child(rep)

	var mel := Button.new()
	if nivel >= nivel_max:
		mel.text = "Nível máximo"
		mel.disabled = true
	else:
		var cm := custo_melhoria(nivel)
		mel.text = ("%s (%d suc. + %d pç)" % ["Melhorar" if instalado else "Instalar", cm.sucata, cm.pecas])
		mel.disabled = estoque.get("sucata", 0) < cm.sucata or estoque.get("pecas", 0) < cm.pecas
	mel.custom_minimum_size = Vector2(190, 0)
	mel.pressed.connect(f_mel)
	linha.add_child(mel)
	return linha

func _pagar_reparo(cond: float) -> bool:
	var custo := custo_reparo(cond)
	if estoque.pecas < custo:
		return false
	estoque.pecas -= custo
	return true

func _pagar_melhoria(nivel: int) -> bool:
	var cm := custo_melhoria(nivel)
	if estoque.sucata < cm.sucata or estoque.pecas < cm.pecas:
		return false
	estoque.sucata -= cm.sucata
	estoque.pecas -= cm.pecas
	return true

func _reparar_trailer(slot: String) -> void:
	if _pagar_reparo(trailer.config[slot].condicao):
		trailer.reparar(slot, 1.0)
		_aviso.text = "%s reparado." % Trailer.MODULOS[trailer.config[slot].id].nome
	atualizar()

func _melhorar_trailer(slot: String) -> void:
	if _pagar_melhoria(trailer.config[slot].nivel):
		trailer.melhorar(slot)
		_aviso.text = "%s agora no nível %d." % [Trailer.MODULOS[trailer.config[slot].id].nome, trailer.config[slot].nivel]
	atualizar()

func _reparar_picape(slot: String) -> void:
	if _pagar_reparo(picape.config[slot].condicao):
		picape.reparar(slot, 1.0)
		_aviso.text = "%s reparado." % Pickup.MODULOS[slot].nome
	atualizar()

func _melhorar_picape(slot: String) -> void:
	if _pagar_melhoria(picape.config[slot].nivel):
		picape.melhorar(slot)
		comboio.diesel = minf(comboio.diesel, picape.tanque_litros())
		comboio._aplicar(0.0)
		_aviso.text = "%s agora no nível %d." % [Pickup.MODULOS[slot].nome, picape.config[slot].nivel]
	atualizar()

func _reparar_reboque(r: Reboque) -> void:
	if _pagar_reparo(r.condicao):
		r.reparar(1.0)
		_aviso.text = "%s reparado." % r.nome_exibicao()
	atualizar()

func _melhorar_reboque(r: Reboque) -> void:
	if _pagar_melhoria(r.nivel):
		r.melhorar()
		comboio._aplicar(0.0)
		_aviso.text = "%s agora no nível %d." % [r.nome_exibicao(), r.nivel]
	atualizar()

func _input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("oficina"):
		get_viewport().set_input_as_handled()
		fechado.emit()
