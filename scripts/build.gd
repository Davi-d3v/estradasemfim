class_name B
## Utilitários de construção procedural de geometria e materiais.

static var _mats := {}

## Material padrão (cacheado por chave).
static func mat(color: Color, rough := 0.8, metal := 0.0, key := "") -> StandardMaterial3D:
	var k := key if key != "" else "%s_%.2f_%.2f" % [color.to_html(), rough, metal]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	_mats[k] = m
	return m

static func emissive(color: Color, energy := 2.0) -> StandardMaterial3D:
	var k := "em_%s_%.1f" % [color.to_html(), energy]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_mats[k] = m
	return m

static var _shader_pintura: Shader

## Pintura desgastada procedural. Chame atualizar_pintura() quando o veículo se mover.
static func pintura(cor: Color, condicao: float, rough := 0.65, metal := 0.1, altura_sujeira := 1.1) -> ShaderMaterial:
	if _shader_pintura == null:
		_shader_pintura = load("res://shaders/pintura.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader_pintura
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("condicao", condicao)
	m.set_shader_parameter("rugosidade", rough)
	m.set_shader_parameter("metalico", metal)
	m.set_shader_parameter("altura_sujeira", altura_sujeira)
	return m

static func atualizar_pintura(m: ShaderMaterial, raiz: Node3D) -> void:
	m.set_shader_parameter("inv_raiz", Projection(raiz.global_transform.affine_inverse()))

## Aplica desgaste: escurece e puxa a cor para tons de ferrugem/sujeira.
static func worn(base: Color, condicao: float) -> Color:
	var rust := Color(0.36, 0.2, 0.11)
	var dirt := Color(0.32, 0.29, 0.24)
	var c := base.lerp(dirt, 0.25)
	return c.lerp(rust, clampf(1.0 - condicao, 0.0, 1.0) * 0.55)

static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _add(parent, bm, pos, m, rot)

static func cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO, sides := 16, r_top := -1.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	return _add(parent, cm, pos, m, rot)

static func sphere(parent: Node3D, r: float, pos: Vector3, m: Material, scale := Vector3.ONE, seg := 12) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = maxi(seg / 2, 4)
	var mi := _add(parent, sm, pos, m)
	mi.scale = scale
	return mi

static func capsule(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(h, r * 2.0)
	cm.radial_segments = 10
	cm.rings = 4
	return _add(parent, cm, pos, m, rot)

## Triângulo com normal explícita; corrige a ordem dos vértices para o padrão do Godot.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)

## Extruda um perfil 2D (z, y) em sentido anti-horário ao longo do eixo X.
static func extrude(profile: PackedVector2Array, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var area := 0.0
	for i in profile.size():
		var a2 := profile[i]
		var b2 := profile[(i + 1) % profile.size()]
		area += a2.x * b2.y - b2.x * a2.y
	if area < 0.0:
		profile = profile.duplicate()
		profile.reverse()
	var idx :=Geometry2D.triangulate_polygon(profile)
	for side in [1.0, -1.0]:
		var n := Vector3(side, 0, 0)
		for i in range(0, idx.size(), 3):
			var p0 := profile[idx[i]]
			var p1 := profile[idx[i + 1]]
			var p2 := profile[idx[i + 2]]
			_tri(st, Vector3(hw * side, p0.y, p0.x), Vector3(hw * side, p1.y, p1.x), Vector3(hw * side, p2.y, p2.x), n)
	var cnt := profile.size()
	for i in cnt:
		var p := profile[i]
		var q := profile[(i + 1) % cnt]
		var d := q - p
		var n := Vector3(0, -d.x, d.y).normalized()
		var a := Vector3(hw, p.y, p.x)
		var b := Vector3(hw, q.y, q.x)
		var c := Vector3(-hw, q.y, q.x)
		var e := Vector3(-hw, p.y, p.x)
		_tri(st, a, b, c, n)
		_tri(st, a, c, e, n)
	return st.commit()

static func extruded(parent: Node3D, profile: PackedVector2Array, width: float, pos: Vector3, m: Material) -> MeshInstance3D:
	return _add(parent, extrude(profile, width), pos, m)

## Roda off-road: pneu, banda de rodagem, aro e cubo. Eixo de rotação em X.
static func wheel(parent: Node3D, pos: Vector3, radius := 0.42, width := 0.3, rim_color := Color(0.08, 0.08, 0.09)) -> Node3D:
	var w := Node3D.new()
	w.position = pos
	parent.add_child(w)
	var tire := mat(Color(0.07, 0.07, 0.07), 0.95)
	cyl(w, radius, width, Vector3.ZERO, tire, Vector3(0, 0, 90), 24)
	# blocos da banda de rodagem
	for i in 26:
		var ang := TAU * i / 26.0
		var lug := box(w, Vector3(width * (0.55 if i % 2 == 0 else 0.85), 0.03, 0.07), Vector3(0, cos(ang) * radius, sin(ang) * radius), tire)
		lug.rotation.x = ang
	var rim := mat(rim_color, 0.5, 0.6)
	cyl(w, radius * 0.6, width + 0.02, Vector3.ZERO, rim, Vector3(0, 0, 90), 16)
	cyl(w, radius * 0.18, width + 0.06, Vector3.ZERO, mat(Color(0.25, 0.25, 0.27), 0.4, 0.8), Vector3(0, 0, 90), 8)
	for i in 6:
		var ang := TAU * i / 6.0
		var sp := box(w, Vector3(width + 0.03, 0.05, radius * 0.75), Vector3.ZERO, rim)
		sp.rotation.x = ang
	return w

## Galão de combustível/água estilo jerrycan.
static func jerrycan(parent: Node3D, pos: Vector3, color: Color, rot := Vector3.ZERO) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	j.rotation_degrees = rot
	parent.add_child(j)
	var m := mat(color, 0.55)
	box(j, Vector3(0.17, 0.46, 0.34), Vector3(0, 0.23, 0), m)
	box(j, Vector3(0.19, 0.04, 0.3), Vector3(0, 0.3, 0), m)
	box(j, Vector3(0.19, 0.04, 0.3), Vector3(0, 0.14, 0), m)
	box(j, Vector3(0.05, 0.06, 0.14), Vector3(0, 0.49, -0.06), m)
	cyl(j, 0.035, 0.06, Vector3(0, 0.49, 0.11), mat(Color(0.1, 0.1, 0.1)), Vector3.ZERO, 8)
	return j

## Junta todas as malhas estáticas de uma subárvore em poucas malhas (uma por material).
## Reduz muito o custo de desenho. Pula nós que precisam continuar separados
## (pessoas, zumbis, reboques, carros desmontáveis, luzes e textos).
static func mesclar(raiz: Node3D) -> void:
	var grupos := {}       # material -> SurfaceTool
	var apagar: Array[Node] = []
	var inv := raiz.global_transform.affine_inverse() if raiz.is_inside_tree() else Transform3D.IDENTITY
	_coletar(raiz, raiz, Transform3D.IDENTITY, grupos, apagar)
	for n in apagar:
		n.get_parent().remove_child(n)
		n.free()
	for mat in grupos:
		var st: SurfaceTool = grupos[mat]
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		raiz.add_child(mi)

static func _coletar(raiz: Node3D, n: Node, xf: Transform3D, grupos: Dictionary, apagar: Array[Node]) -> void:
	for c in n.get_children():
		if not (c is Node3D):
			continue
		if c is Humanoid or c is Reboque or c.has_meta("chave") or c.has_meta("nao_mesclar"):
			continue
		var cxf: Transform3D = xf * c.transform
		if c is MeshInstance3D and c.material_override and c.mesh and c.get_child_count() == 0 and c.mesh is PrimitiveMesh:
			var mat: Material = c.material_override
			if not grupos.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				grupos[mat] = st
			var surf_st: SurfaceTool = grupos[mat]
			surf_st.append_from(c.mesh, 0, cxf)
			apagar.append(c)
		elif c.get_class() == "Node3D":
			_coletar(raiz, c, cxf, grupos, apagar)
			if c.get_child_count() == 0 or _so_apagados(c, apagar):
				apagar.append(c)

static func _so_apagados(n: Node, apagar: Array[Node]) -> bool:
	for c in n.get_children():
		if not apagar.has(c):
			return false
	return true
