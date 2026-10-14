class_name Retrovisor
extends Control
## Espelho retrovisor (lado do motorista) no alto da tela enquanto dirige.
## Uma câmera presa ao lado da cabine olha para trás, ao longo do trailer.

const TAM := Vector2(400, 140)

var main: Node
var _vp: SubViewport
var _cam: Camera3D
var _tex: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.size = Vector2i(TAM)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 34.0
	_cam.near = 0.3
	_cam.far = 2500.0
	_vp.add_child(_cam)
	_tex = TextureRect.new()
	_tex.texture = _vp.get_texture()
	_tex.flip_h = true      # espelho
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex)
	visible = false

func _process(_dt: float) -> void:
	var ligar: bool = main != null and main.jogando and main.comboio.dirigindo
	if ligar != visible:
		visible = ligar
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if ligar else SubViewport.UPDATE_DISABLED
	if not visible:
		return
	var e := get_viewport_rect().size.x / 1600.0
	size = TAM * e
	position = Vector2((get_viewport_rect().size.x - size.x) * 0.5, 14.0 * e)
	_tex.position = Vector2(6, 6) * e
	_tex.size = size - Vector2(12, 12) * e
	posicionar_camera()
	queue_redraw()

func posicionar_camera() -> void:
	var c: Comboio = main.comboio
	var yaw: float = c.yaw
	var frente := Vector3(sin(yaw), 0, cos(yaw))
	var esquerda := Vector3(cos(yaw), 0, -sin(yaw))
	var p: Vector3 = c.pos + frente * 0.9 + esquerda * 1.35 + Vector3(0, 1.75, 0)
	var alvo := p - frente * 40.0 + esquerda * 1.6 - Vector3(0, 0.6, 0)
	_cam.look_at_from_position(p, alvo, Vector3.UP)

func _draw() -> void:
	var e := size.x / TAM.x
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.05, 0.05, 0.05, 0.95))
	draw_rect(Rect2(Vector2(3, 3) * e, size - Vector2(6, 6) * e), Color(0.22, 0.22, 0.22), false, 2.0 * e)
