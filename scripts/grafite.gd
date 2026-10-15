class_name Grafite
## Pichações de verdade (ambientCG GraffitiSet001, CC0): 16 tags num atlas com
## transparência, coladas como decalque fino em paredes, muros, barreiras e carros.

const ATLAS := "res://assets/texturas/pichacao/cor_alfa.png"
const RECORTES := [
	Rect2(0.0059, 0.0312, 0.2373, 0.1963), Rect2(0.2607, 0.0352, 0.2305, 0.1699), Rect2(0.5068, 0.0498, 0.2363, 0.1768), Rect2(0.7568, 0.0508, 0.2363, 0.1367),
	Rect2(0.0039, 0.3135, 0.2344, 0.1074), Rect2(0.2559, 0.3252, 0.2402, 0.1035), Rect2(0.5049, 0.3271, 0.2393, 0.0977), Rect2(0.7549, 0.2910, 0.2441, 0.1562),
	Rect2(0.0059, 0.5547, 0.2334, 0.1699), Rect2(0.2568, 0.5693, 0.2363, 0.1318), Rect2(0.5039, 0.5430, 0.2402, 0.1562), Rect2(0.7549, 0.5615, 0.2432, 0.1445),
	Rect2(0.0068, 0.7959, 0.2374, 0.1504), Rect2(0.2529, 0.8252, 0.2461, 0.1064), Rect2(0.5049, 0.8301, 0.2393, 0.0840), Rect2(0.7539, 0.8164, 0.2402, 0.1123),
]
static var _mats := {}
static var _tex: Texture2D

static func _mat(i: int) -> StandardMaterial3D:
	if _mats.has(i):
		return _mats[i]
	if _tex == null:
		_tex = load(ATLAS) if ResourceLoader.exists(ATLAS) else null
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.roughness = 0.75
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var rc: Rect2 = RECORTES[i]
	m.uv1_scale = Vector3(rc.size.x, rc.size.y, 1.0)
	m.uv1_offset = Vector3(rc.position.x, rc.position.y, 0.0)
	# tinta velha: um pouco desbotada
	m.albedo_color = Color(0.86, 0.84, 0.82, 0.92)
	_mats[i] = m
	return m

## Cola uma pichação: pos no plano da parede, normal para fora (direção em que a tag "olha").
static func colar(pai: Node3D, pos: Vector3, normal: Vector3, largura: float, r: RandomNumberGenerator) -> MeshInstance3D:
	if not ResourceLoader.exists(ATLAS):
		return null
	var i := r.randi() % RECORTES.size()
	var rc: Rect2 = RECORTES[i]
	var q := QuadMesh.new()
	q.size = Vector2(largura, largura * rc.size.y / rc.size.x)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _mat(i)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	var n := normal.normalized()
	mi.position = pos + n * 0.025
	# o quad olha para +Z local: gira para olhar ao longo da normal, com leve inclinação
	var up := Vector3.UP if absf(n.y) < 0.9 else Vector3.FORWARD
	mi.basis = Basis.looking_at(-n, up) * Basis(Vector3.BACK, r.randf_range(-0.08, 0.08))
	return mi
