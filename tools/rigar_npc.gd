extends SceneTree
## Avatares Rocketbox (Microsoft, MIT; .fbx com esqueleto "Bip01" do 3ds Max) ligados ao
## esqueleto da Universal Animation Library, do mesmo jeito que o protagonista
## (tools/rigar_personagem.gd): pose dos braços igualada, pesos automáticos por distância
## aos ossos. Mantém as superfícies separadas (corpo, cabeça, cílios/cabelo com recorte).
## A malha é posta na altura do esqueleto (1,82 m); a altura real do avatar vai em
## meta "altura" e o jogo escala o personagem inteiro.
## Uso: godot --headless --path . -s res://tools/rigar_npc.gd -- pasta_fbx res://assets/npcs Nome1 Nome2 ...

const UAL := "res://assets/personagens_u/base/Superhero_Male_FullBody.gltf"
const ALTURA_UAL := 1.82

const SEGS := [
	["pelvis", "spine_01", 1.0], ["spine_01", "spine_02", 1.0], ["spine_02", "spine_03", 1.0],
	["spine_03", "neck_01", 1.0], ["neck_01", "Head", 1.0], ["Head", Vector3(0, 0.22, 0.02), 1.0],
	["clavicle_l", "upperarm_l", 0.6], ["upperarm_l", "lowerarm_l", 1.0], ["lowerarm_l", "hand_l", 1.0], ["hand_l", "middle_04_leaf_l", 1.0],
	["clavicle_r", "upperarm_r", 0.6], ["upperarm_r", "lowerarm_r", 1.0], ["lowerarm_r", "hand_r", 1.0], ["hand_r", "middle_04_leaf_r", 1.0],
	["thigh_l", "calf_l", 1.0], ["calf_l", "foot_l", 1.0], ["foot_l", "ball_l", 1.0], ["ball_l", "ball_leaf_l", 1.0],
	["thigh_r", "calf_r", 1.0], ["calf_r", "foot_r", 1.0], ["foot_r", "ball_r", 1.0], ["ball_r", "ball_leaf_r", 1.0],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var pasta_fbx: String = args[0]
	var saida_base: String = args[1]
	for nome in args.slice(2):
		_rigar(pasta_fbx.path_join(nome + ".fbx"), saida_base + "/" + nome)
	quit()

func _rigar(fbx: String, saida: String) -> void:
	var doc := FBXDocument.new()
	var st_f := FBXState.new()
	if doc.append_from_file(fbx, st_f) != OK:
		push_error("não abriu " + fbx)
		return
	var cena: Node = doc.generate_scene(st_f)
	# superfícies: [nome do material, V, N, UV, I]
	var sups: Array = []
	var pilha: Array = [[cena, Transform3D()]]
	while not pilha.is_empty():
		var it: Array = pilha.pop_back()
		var n: Node = it[0]
		var t: Transform3D = it[1]
		if n is Node3D and n != cena:
			t = t * (n as Node3D).transform
		if n is MeshInstance3D:
			var m: Mesh = (n as MeshInstance3D).mesh
			for s in m.get_surface_count():
				var a := m.surface_get_arrays(s)
				var vs := PackedVector3Array()
				var ns := PackedVector3Array()
				for v in (a[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					vs.append(t * v)
				for v in (a[Mesh.ARRAY_NORMAL] as PackedVector3Array):
					ns.append((t.basis * v).normalized())
				var mat := m.surface_get_material(s)
				sups.append([mat.resource_name if mat else "", vs, ns, a[Mesh.ARRAY_TEX_UV], a[Mesh.ARRAY_INDEX]])
		for c in n.get_children():
			pilha.append([c, t])
	cena.free()
	# junta tudo numa lista só (para os pesos), lembrando onde começa cada superfície
	var V := PackedVector3Array()
	var N := PackedVector3Array()
	var inicio: Array = []
	for sp in sups:
		inicio.append(V.size())
		V.append_array(sp[1])
		N.append_array(sp[2])
	# eixo de cima: Z (3ds Max) -> Y, frente -Y -> +Z
	var mn := Vector3.INF
	var mx := -Vector3.INF
	for p in V:
		mn = mn.min(p)
		mx = mx.max(p)
	var tam := mx - mn
	if tam.z > tam.y * 1.5:
		for i in V.size():
			V[i] = Vector3(V[i].x, V[i].z, -V[i].y)
			N[i] = Vector3(N[i].x, N[i].z, -N[i].y)
		mn = Vector3.INF
		mx = -Vector3.INF
		for p in V:
			mn = mn.min(p)
			mx = mx.max(p)
	var altura := mx.y - mn.y
	if altura > 10.0:
		altura *= 0.01   # centímetros
	var esc := ALTURA_UAL / (mx.y - mn.y)
	var desl := Vector3(-(mn.x + mx.x) * 0.5, -mn.y, 0.0)
	var zc := 0.0
	var nz := 0
	for p in V:
		if p.y < mn.y + (mx.y - mn.y) * 0.45:
			zc += p.z
			nz += 1
	desl.z = -zc / maxf(nz, 1)
	for i in V.size():
		V[i] = (V[i] + desl) * esc
	var r: Node3D = load(UAL).instantiate()
	var sk: Skeleton3D = r.find_children("*", "Skeleton3D", true, false)[0]
	sk.reset_bone_poses()
	var z_ual: float = (_globais(sk)[sk.find_bone("pelvis")] as Transform3D).origin.z
	for i in V.size():
		V[i].z += z_ual
	for lado in ["l", "r"]:
		var s := 1.0 if lado == "l" else -1.0
		var b_up := sk.find_bone("upperarm_" + lado)
		var ombro := sk.get_bone_global_pose(b_up).origin
		var mao0 := (_globais(sk)[sk.find_bone("hand_" + lado)] as Transform3D).origin
		# pulso da malha: vértices mais afastados para o lado (mão) -> ponto médio
		var xmax := 0.0
		for p in V:
			xmax = maxf(xmax, p.x * s)
		var soma := Vector3.ZERO
		var q := 0
		for p in V:
			if p.x * s > xmax - 0.16 and p.x * s < xmax - 0.06:
				soma += p
				q += 1
		var pulso := soma / maxf(q, 1)
		var d0 := (mao0 - ombro).normalized()
		var d1 := (pulso - ombro).normalized()
		var rot := Quaternion(d0, d1)
		var gl := _globais(sk)
		var g: Transform3D = gl[b_up]
		g.basis = Basis(rot) * g.basis
		var pai_g: Transform3D = gl[sk.get_bone_parent(b_up)]
		var loc := pai_g.affine_inverse() * g
		sk.set_bone_pose_rotation(b_up, loc.basis.get_rotation_quaternion())
		print("braço %s: ângulo %.1f°, pulso da malha %s, mão do esqueleto %s" % [lado, rad_to_deg(d0.angle_to(d1)), pulso.snapped(Vector3.ONE * 0.01), (_globais(sk)[sk.find_bone("hand_" + lado)] as Transform3D).origin.snapped(Vector3.ONE * 0.01)])
	var GL := _globais(sk)
	var segs: Array = []   # [bone, a, b, fator, lado(-1,0,1), grupo]
	for sg in SEGS:
		var b := sk.find_bone(sg[0])
		var a: Vector3 = (GL[b] as Transform3D).origin
		var pb: Vector3
		if sg[1] is Vector3:
			pb = a + (sg[1] as Vector3)
		else:
			pb = (GL[sk.find_bone(sg[1])] as Transform3D).origin
		var nome: String = sg[0]
		var lado := 0
		if nome.ends_with("_l"):
			lado = 1
		elif nome.ends_with("_r"):
			lado = -1
		var grupo := "tronco"
		if nome.begins_with("thigh") or nome.begins_with("calf") or nome.begins_with("foot") or nome.begins_with("ball"):
			grupo = "perna"
		elif nome.begins_with("upperarm") or nome.begins_with("lowerarm") or nome.begins_with("hand"):
			grupo = "braco"
		segs.append([b, a, pb, float(sg[2]), lado, grupo])
	var y_virilha: float = (_globais(sk)[sk.find_bone("thigh_l")] as Transform3D).origin.y - 0.08
	var ombro_x: float = absf((_globais(sk)[sk.find_bone("upperarm_l")] as Transform3D).origin.x)
	var binds := {}   # bone -> índice do bind
	var bind_lista: Array = []
	var BO := PackedInt32Array()
	var PE := PackedFloat32Array()
	BO.resize(V.size() * 4)
	PE.resize(V.size() * 4)
	for i in V.size():
		var p := V[i]
		var cands: Array = []
		for sg in segs:
			var lado: int = sg[4]
			# lado certo: perna/braço esquerdo só pega vértice do lado esquerdo (com folga no meio)
			if lado != 0 and p.x * lado < -0.02:
				continue
			# perna só abaixo do quadril; braço só para fora do ombro (ou abaixo dele, pendurado)
			if sg[5] == "perna" and p.y > y_virilha + 0.18:
				continue
			var d := _dist_seg(p, sg[1], sg[2]) / float(sg[3])
			if sg[5] == "tronco" and p.y < y_virilha - 0.12 and absf(p.x) > 0.04:
				d *= 3.0   # coxas não seguem a bacia
			if sg[5] == "braco" and absf(p.x) < ombro_x - 0.04:
				d *= 2.5   # tronco não segue o braço
			cands.append([d, sg[0]])
		cands.sort_custom(func(a, b): return a[0] < b[0])
		var tot := 0.0
		var ws: Array = []
		var d0: float = cands[0][0]
		for k in mini(4, cands.size()):
			var d: float = cands[k][0]
			# só mistura com ossos quase tão perto quanto o mais perto (junta macia, resto firme)
			var w := 0.0 if d > d0 + 0.07 else pow(1.0 / (d + 0.012), 4.0)
			ws.append(w)
			tot += w
		for k in 4:
			var w2: float = (ws[k] / tot) if k < ws.size() else 0.0
			var bone: int = cands[k][1] if k < cands.size() else cands[0][1]
			if not binds.has(bone):
				binds[bone] = bind_lista.size()
				bind_lista.append(bone)
			BO[i * 4 + k] = binds[bone]
			PE[i * 4 + k] = w2
	var skin := Skin.new()
	for bone in bind_lista:
		skin.add_named_bind(sk.get_bone_name(bone), (GL[bone] as Transform3D).affine_inverse())
	var mesh := ArrayMesh.new()
	for k in sups.size():
		var sp: Array = sups[k]
		var a0: int = inicio[k]
		var nv: int = (sp[1] as PackedVector3Array).size()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = V.slice(a0, a0 + nv)
		arr[Mesh.ARRAY_NORMAL] = N.slice(a0, a0 + nv)
		arr[Mesh.ARRAY_TEX_UV] = sp[3]
		arr[Mesh.ARRAY_INDEX] = sp[4]
		arr[Mesh.ARRAY_BONES] = BO.slice(a0 * 4, (a0 + nv) * 4)
		arr[Mesh.ARRAY_WEIGHTS] = PE.slice(a0 * 4, (a0 + nv) * 4)
		var st2 := SurfaceTool.new()
		st2.create_from_arrays(arr)
		st2.generate_tangents()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st2.commit_to_arrays())
		var nome_mat: String = String(sp[0]).to_lower()
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.85
		if nome_mat.contains("opacity"):
			mat.albedo_texture = load(saida + "/opacity.png")
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.4
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		else:
			# m111_helmet -> helmet (textura preparada por tools/preparar_npcs.py)
			var parte := nome_mat.split("_", true, 1)[1] if nome_mat.contains("_") else "body"
			if not ResourceLoader.exists(saida + "/" + parte + ".jpg"):
				for pedaco in parte.split("_"):     # head_a / a_head -> head
					if ResourceLoader.exists(saida + "/" + pedaco + ".jpg"):
						parte = pedaco
			if not ResourceLoader.exists(saida + "/" + parte + ".jpg"):
				parte = "body"
			mat.albedo_texture = load(saida + "/" + parte + ".jpg")
			if ResourceLoader.exists(saida + "/" + parte + "_n.jpg"):
				mat.normal_enabled = true
				mat.normal_texture = load(saida + "/" + parte + "_n.jpg")
		mesh.surface_set_material(k, mat)
	mesh.set_meta("altura", altura)
	ResourceSaver.save(mesh, saida + "/corpo.res", ResourceSaver.FLAG_COMPRESS)
	ResourceSaver.save(skin, saida + "/corpo_skin.tres")
	print("%s: %.2f m, %d vértices, %d superfícies, %d ossos" % [saida.get_file(), altura, V.size(), sups.size(), bind_lista.size()])
	r.free()

## Transformações globais dos ossos a partir das poses locais (o esqueleto fora da árvore
## não atualiza as globais sozinho).
static func _globais(sk: Skeleton3D) -> Array:
	var g: Array = []
	g.resize(sk.get_bone_count())
	for b in sk.get_bone_count():
		var loc := Transform3D(Basis(sk.get_bone_pose_rotation(b)).scaled(sk.get_bone_pose_scale(b)), sk.get_bone_pose_position(b))
		var p := sk.get_bone_parent(b)
		g[b] = loc if p < 0 else (g[p] as Transform3D) * loc
	return g

static func _so_basico(a: Array) -> Array:
	var b := []
	b.resize(Mesh.ARRAY_MAX)
	b[Mesh.ARRAY_VERTEX] = a[Mesh.ARRAY_VERTEX]
	b[Mesh.ARRAY_NORMAL] = a[Mesh.ARRAY_NORMAL]
	b[Mesh.ARRAY_TEX_UV] = a[Mesh.ARRAY_TEX_UV]
	b[Mesh.ARRAY_INDEX] = a[Mesh.ARRAY_INDEX]
	return b

static func _dist_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return p.distance_to(a + ab * t)
