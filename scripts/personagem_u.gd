class_name PersonagemU
## Personagem com proporção realista e rosto (Quaternius: Universal Base Characters +
## roupas modulares), no mesmo esqueleto da Universal Animation Library: as animações
## da UAL valem direto, sem conversão.
## Monta: cabeça/pescoço/mãos do corpo base + roupa + cabelo/barba/sobrancelha.

const DIR := "res://assets/personagens_u/"
## Ossos que ficam à mostra do corpo base (o resto fica coberto pela roupa).
const OSSOS_PELE := ["Head", "neck_01", "hand_l", "hand_r"]

static var _cenas := {}
static var _malhas_cortadas := {}

static func _cena(c: String) -> PackedScene:
	if not _cenas.has(c):
		_cenas[c] = load(c)
	return _cenas[c]

static func disponivel() -> bool:
	return ResourceLoader.exists(DIR + "base/Superhero_Male_FullBody.gltf")

## Malha do corpo base só com cabeça, pescoço e mãos (cacheada).
static func _corpo_cortado(mi: MeshInstance3D, sk: Skeleton3D, chave: String) -> ArrayMesh:
	if _malhas_cortadas.has(chave):
		return _malhas_cortadas[chave]
	var keep := {}
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b)
		var pai := b
		var ok := false
		while pai >= 0:
			if sk.get_bone_name(pai) in OSSOS_PELE:
				ok = true
				break
			pai = sk.get_bone_parent(pai)
		keep[b] = ok
	# os índices de JOINTS são índices do Skin, não do esqueleto
	var skin := mi.skin
	var por_bind := {}
	for i in skin.get_bind_count():
		var bi := skin.get_bind_bone(i)
		if bi < 0:
			bi = sk.find_bone(skin.get_bind_name(i))
		por_bind[i] = keep.get(bi, false)
	var orig: Mesh = mi.mesh
	var nova := ArrayMesh.new()
	for s in orig.get_surface_count():
		var arr := orig.surface_get_arrays(s)
		var ossos = arr[Mesh.ARRAY_BONES]
		var pesos = arr[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var nv: int = arr[Mesh.ARRAY_VERTEX].size()
		var k: int = ossos.size() / nv
		var vis := PackedByteArray()
		vis.resize(nv)
		for v in nv:
			var melhor := 0
			var mp := -1.0
			for q in k:
				if pesos[v * k + q] > mp:
					mp = pesos[v * k + q]
					melhor = ossos[v * k + q]
			vis[v] = 1 if por_bind.get(melhor, false) else 0
		var ni := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if vis[idx[t]] == 1 and vis[idx[t + 1]] == 1 and vis[idx[t + 2]] == 1:
				ni.append(idx[t])
				ni.append(idx[t + 1])
				ni.append(idx[t + 2])
		arr[Mesh.ARRAY_INDEX] = ni
		var flags := 0
		if orig.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
			flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		nova.surface_set_material(s, orig.surface_get_material(s))
	_malhas_cortadas[chave] = nova
	return nova

## Junta as malhas de outra cena (roupa, cabelo) no esqueleto do corpo.
static func _vestir(sk: Skeleton3D, caminho: String, tinta := Color.WHITE, tinta_pele := Color.WHITE) -> void:
	if not ResourceLoader.exists(caminho):
		return
	var c: Node3D = _cena(caminho).instantiate()
	for mi in c.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		m.owner = null
		m.get_parent().remove_child(m)
		sk.add_child(m)
		m.skeleton = NodePath("..")
		if tinta != Color.WHITE or tinta_pele != Color.WHITE:
			for s in m.mesh.get_surface_count():
				var mat: Material = m.mesh.surface_get_material(s)
				if mat is StandardMaterial3D:
					var d: StandardMaterial3D = mat.duplicate()
					# partes de pele que a roupa traz (antebraço) seguem o tom de pele
					d.albedo_color = d.albedo_color * (tinta_pele if mat.resource_name.begins_with("MI_Regular") else tinta)
					m.set_surface_override_material(s, d)
	c.free()

static func _tingir(m: MeshInstance3D, tinta: Color) -> void:
	for s in m.mesh.get_surface_count():
		var mat: Material = m.mesh.surface_get_material(s)
		if mat is StandardMaterial3D:
			var d: StandardMaterial3D = mat.duplicate()
			d.albedo_color = d.albedo_color * tinta
			m.set_surface_override_material(s, d)

## Corta a malha deixando só os ossos da lista (e descendentes). Cacheado por chave.
static func _cortar(mi: MeshInstance3D, sk: Skeleton3D, ossos: Array, chave: String, desloc := Vector3.ZERO) -> ArrayMesh:
	if _malhas_cortadas.has(chave):
		return _malhas_cortadas[chave]
	var keep := {}
	for b in sk.get_bone_count():
		var pai := b
		var ok := false
		while pai >= 0:
			if sk.get_bone_name(pai) in ossos:
				ok = true
				break
			pai = sk.get_bone_parent(pai)
		keep[b] = ok
	var skin := mi.skin
	var por_bind := {}
	for i in skin.get_bind_count():
		var bi := skin.get_bind_bone(i)
		if bi < 0:
			bi = sk.find_bone(skin.get_bind_name(i))
		por_bind[i] = keep.get(bi, false)
	var orig: Mesh = mi.mesh
	var nova := ArrayMesh.new()
	for s in orig.get_surface_count():
		var arr := orig.surface_get_arrays(s)
		var ossos_v = arr[Mesh.ARRAY_BONES]
		var pesos = arr[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nv: int = vs.size()
		var k: int = ossos_v.size() / nv
		var vis := PackedByteArray()
		vis.resize(nv)
		for v in nv:
			var melhor := 0
			var mp := -1.0
			for q in k:
				if pesos[v * k + q] > mp:
					mp = pesos[v * k + q]
					melhor = ossos_v[v * k + q]
			vis[v] = 1 if por_bind.get(melhor, false) else 0
		var ni := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if vis[idx[t]] == 1 and vis[idx[t + 1]] == 1 and vis[idx[t + 2]] == 1:
				ni.append(idx[t])
				ni.append(idx[t + 1])
				ni.append(idx[t + 2])
		if ni.is_empty():
			continue
		arr[Mesh.ARRAY_INDEX] = ni
		for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[c] = null
		if desloc != Vector3.ZERO:
			for v in nv:
				vs[v] += desloc
			arr[Mesh.ARRAY_VERTEX] = vs
		var flags := 0
		if orig.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
			flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		nova.surface_set_material(nova.get_surface_count() - 1, orig.surface_get_material(s))
	_malhas_cortadas[chave] = nova
	return nova

static func _bind(mi: MeshInstance3D, osso: String) -> Transform3D:
	for i in mi.skin.get_bind_count():
		if mi.skin.get_bind_name(i) == osso:
			return mi.skin.get_bind_pose(i).affine_inverse()
	return Transform3D()

## Cabeça feminina (rosto, olhos, sobrancelhas) posta no esqueleto masculino.
static func _cabeca_feminina(sk_m: Skeleton3D, corpo_m: MeshInstance3D, tinta_pele: Color, cor_cabelo: Color) -> void:
	var f: Node3D = _cena(DIR + "base/Superhero_Female_FullBody.gltf").instantiate()
	var sk_f: Skeleton3D = f.find_children("*", "Skeleton3D", true, false)[0]
	var corpo_f: MeshInstance3D = null
	for mi in sk_f.get_children():
		if mi is MeshInstance3D and String(mi.name).to_lower().begins_with("superhero"):
			corpo_f = mi
	var desloc := _bind(corpo_m, "Head").origin - _bind(corpo_f, "Head").origin
	for mi in sk_f.get_children():
		if not (mi is MeshInstance3D):
			continue
		var nome := String(mi.name)
		var ossos := ["neck_01"] if mi == corpo_f else ["root"]
		var m := MeshInstance3D.new()
		m.name = "F_" + nome
		m.mesh = _cortar(mi, sk_f, ossos, "fem_" + nome, desloc)
		m.skin = corpo_m.skin
		sk_m.add_child(m)
		m.skeleton = NodePath("..")
		if mi == corpo_f and tinta_pele != Color.WHITE:
			_tingir(m, tinta_pele)
		elif nome == "Eyebrows":
			_tingir(m, cor_cabelo)
	f.free()

## Monta o personagem. visual: {feminino, cabelo, barba, tinta_roupa, tinta_pele}
## pecas: roupa montada peça por peça, [[peça, tinta], ...] com peça em
## Peasant_Body/Arms/Legs/Feet, Ranger_Body/Arms/Legs/Feet_Boots/Head_Hood/Acc_Pauldron
## (vazio = roupa de camponês inteira com tinta_roupa).
static func montar(feminino: bool, cabelo: String, barba: bool, tinta_roupa := Color.WHITE, tinta_pele := Color.WHITE, cor_cabelo := Color(0.25, 0.17, 0.1), pecas: Array = []) -> Dictionary:
	# o esqueleto e o corpo são sempre os do base masculino (a roupa foi feita para ele);
	# para mulheres, a cabeça vem do base feminino
	var raiz: Node3D = _cena(DIR + "base/Superhero_Male_FullBody.gltf").instantiate()
	var sk: Skeleton3D = raiz.find_children("*", "Skeleton3D", true, false)[0]
	var corpo: MeshInstance3D = null
	for mi in sk.get_children():
		if mi is MeshInstance3D and String(mi.name).to_lower().begins_with("superhero"):
			corpo = mi
	for mi in sk.get_children():
		if not (mi is MeshInstance3D):
			continue
		if mi == corpo:
			mi.mesh = _cortar(mi, sk, ["hand_l", "hand_r"] if feminino else OSSOS_PELE, "m_maos" if feminino else "m_pele")
			if tinta_pele != Color.WHITE:
				_tingir(mi, tinta_pele)
		elif feminino:
			mi.visible = false
		elif String(mi.name) == "Eyebrows":
			_tingir(mi, cor_cabelo)
	if feminino:
		_cabeca_feminina(sk, corpo, tinta_pele, cor_cabelo)
	if pecas.is_empty():
		_vestir(sk, DIR + "outfits/Male_Peasant.gltf", tinta_roupa, tinta_pele)
	else:
		for pc in pecas:
			_vestir(sk, DIR + "parts/Male_%s.gltf" % pc[0], pc[1], tinta_pele)
	if cabelo != "":
		_vestir(sk, DIR + "hair/%s.gltf" % cabelo, cor_cabelo)
	if barba and not feminino:
		_vestir(sk, DIR + "hair/Hair_Beard.gltf", cor_cabelo)
	var aps := raiz.find_children("*", "AnimationPlayer", true, false)
	var ap: AnimationPlayer = aps[0] if aps.size() > 0 else null
	if ap == null:
		ap = AnimationPlayer.new()
		raiz.add_child(ap)
	return {"raiz": raiz, "esqueleto": sk, "player": ap}
