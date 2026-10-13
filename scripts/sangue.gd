class_name Sangue
## Efeitos de sangue: jorro no impacto e poça no chão.

static var _mat_gota: StandardMaterial3D
static var _mat_poca: StandardMaterial3D

static func _gota() -> StandardMaterial3D:
	if _mat_gota == null:
		_mat_gota = StandardMaterial3D.new()
		_mat_gota.albedo_color = Color(0.42, 0.03, 0.02)
		_mat_gota.roughness = 0.35
	return _mat_gota

static func _poca_mat() -> StandardMaterial3D:
	if _mat_poca == null:
		_mat_poca = StandardMaterial3D.new()
		_mat_poca.albedo_color = Color(0.22, 0.02, 0.015, 0.92)
		_mat_poca.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_poca.roughness = 0.12
		_mat_poca.metallic_specular = 0.8
	return _mat_poca

## Jorro de gotas na direção do golpe/tiro. forca 0..2.
static func jorro(pai: Node, pos: Vector3, direcao: Vector3, forca := 1.0) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = int(14 + 18 * forca)
	p.lifetime = 0.55
	p.explosiveness = 0.95
	var m := SphereMesh.new()
	m.radius = 0.018
	m.height = 0.036
	m.radial_segments = 4
	m.rings = 2
	m.material = _gota()
	p.mesh = m
	var d := direcao.normalized() if direcao.length() > 0.01 else Vector3.UP
	p.direction = d + Vector3(0, 0.35, 0)
	p.spread = 32.0
	p.initial_velocity_min = 1.5 * forca + 0.8
	p.initial_velocity_max = 3.6 * forca + 1.2
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	pai.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(1.2).timeout.connect(p.queue_free)

## Poça no chão (cresce devagar).
static func poca(pai: Node, pos: Vector3, tamanho := 1.0) -> Node3D:
	if pai == null or not pai.is_inside_tree():
		return null
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.5
	c.bottom_radius = 0.5
	c.height = 0.008
	c.radial_segments = 14
	c.rings = 1
	mi.mesh = c
	mi.material_override = _poca_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.025, 0)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(0.2, 1, 0.16) * tamanho
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1.0, 1, 0.75) * tamanho, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	mi.get_tree().create_timer(90.0).timeout.connect(mi.queue_free)
	return mi
