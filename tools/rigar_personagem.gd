extends SceneTree
## Transforma um personagem estático (malha só, sem ossos — como o "post apo character" do
## Sketchfab) num personagem animável no esqueleto da Universal Animation Library:
##   1. junta os pedaços da malha, solda vértices repetidos e simplifica (meshoptimizer,
##      o mesmo que o Godot usa nos níveis de detalhe) até ~N triângulos;
##   2. põe na escala e na posição do esqueleto (pés no chão, de frente para +Z);
##   3. dobra os braços do esqueleto até a pose da malha (pose A) e usa essa pose como
##      "pose de ligação" (bind) — as animações da UAL depois mexem os ossos normalmente;
##   4. pesos de pele automáticos: cada vértice segue os ossos mais próximos (distância
##      ao segmento do osso), sem misturar perna esquerda com direita nem braço com tronco.
## Uso: godot --headless --path . -s res://tools/rigar_personagem.gd -- entrada.glb saida_dir [triangulos]

const UAL := "res://assets/personagens_u/base/Superhero_Male_FullBody.gltf"

# segmentos que puxam a pele: [osso, ponta (osso filho ou deslocamento), peso extra (encolhe a distância)]
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
	var entrada: String = args[0]
	var saida: String = args[1]
	var alvo_tri: int = int(args[2]) if args.size() > 2 else 30000
	var altura_alvo: float = float(args[3]) if args.size() > 3 else 1.82
	# ---------------------------------------------------------------- 1) malha
	var doc := GLTFDocument.new()
	var st_g := GLTFState.new()
	if doc.append_from_file(entrada, st_g) != OK:
		push_error("não abriu " + entrada)
		quit(1)
		return
	var cena: Node = doc.generate_scene(st_g)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pilha: Array = [[cena, Transform3D()]]
	while not pilha.is_empty():
		var it: Array = pilha.pop_back()
		var n: Node = it[0]
		var t: Transform3D = it[1]
		if n is Node3D and n != cena:
			t = t * (n as Node3D).transform
		if n is ImporterMeshInstance3D:
			var im: ImporterMesh = (n as ImporterMeshInstance3D).mesh
			for s in im.get_surface_count():
				var am := ArrayMesh.new()
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _so_basico(im.get_surface_arrays(s)))
				st.append_from(am, 0, t)
		elif n is MeshInstance3D:
			var m: Mesh = (n as MeshInstance3D).mesh
			for s in m.get_surface_count():
				var am2 := ArrayMesh.new()
				am2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _so_basico(m.surface_get_arrays(s)))
				st.append_from(am2, 0, t)
		for c in n.get_children():
			pilha.append([c, t])
	st.index()
	var arr := st.commit_to_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	print("malha original: %d vértices, %d triângulos" % [vs.size(), idx.size() / 3])
	# simplifica pelos níveis de detalhe do Godot (meshoptimizer)
	arr[Mesh.ARRAY_TANGENT] = null
	# os níveis de detalhe param cedo em malhas muito grandes: repete sobre o último nível
	var melhor := idx
	for rodada in 6:
		if melhor.size() / 3 <= alvo_tri * 1.3:
			break
		var a_lod := arr.duplicate()
		a_lod[Mesh.ARRAY_INDEX] = melhor
		var imp := ImporterMesh.new()
		imp.add_surface(Mesh.PRIMITIVE_TRIANGLES, a_lod)
		imp.generate_lods(25.0, 60.0, [])
		var antes := melhor.size()
		for l in imp.get_surface_lod_count(0):
			var li := imp.get_surface_lod_indices(0, l)
			print("  rodada %d LOD %d: %d triângulos" % [rodada, l, li.size() / 3])
			if li.size() / 3 >= alvo_tri * 0.7 or melhor.size() == antes:
				melhor = li
		if melhor.size() == antes:
			break
	print("usando %d triângulos" % [melhor.size() / 3])
	# compacta (só os vértices usados)
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var novo_de := PackedInt32Array()
	novo_de.resize(vs.size())
	novo_de.fill(-1)
	var V := PackedVector3Array()
	var N := PackedVector3Array()
	var U := PackedVector2Array()
	var I := PackedInt32Array()
	for k in melhor:
		if novo_de[k] < 0:
			novo_de[k] = V.size()
			V.append(vs[k])
			N.append(nrm[k])
			U.append(uv[k])
		I.append(novo_de[k])
	# ---------------------------------------------------------------- 2) escala/posição
	var mn := Vector3.INF
	var mx := -Vector3.INF
	for p in V:
		mn = mn.min(p)
		mx = mx.max(p)
	var esc := altura_alvo / (mx.y - mn.y)
	var desl := Vector3(-(mn.x + mx.x) * 0.5, -mn.y, 0.0)
	# centro em z: o meio dos pés/quadril (vértices abaixo de 40% da altura)
	var zc := 0.0
	var nz := 0
	for p in V:
		if p.y < mn.y + (mx.y - mn.y) * 0.45:
			zc += p.z
			nz += 1
	desl.z = -zc / maxf(nz, 1)
	for i in V.size():
		V[i] = (V[i] + desl) * esc
	# ---------------------------------------------------------------- 3) esqueleto na pose da malha
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
	# ---------------------------------------------------------------- 4) pesos
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
	# ---------------------------------------------------------------- 5) grava
	var skin := Skin.new()
	for bone in bind_lista:
		skin.add_named_bind(sk.get_bone_name(bone), (GL[bone] as Transform3D).affine_inverse())
	var final := []
	final.resize(Mesh.ARRAY_MAX)
	final[Mesh.ARRAY_VERTEX] = V
	final[Mesh.ARRAY_NORMAL] = N
	final[Mesh.ARRAY_TEX_UV] = U
	final[Mesh.ARRAY_INDEX] = I
	final[Mesh.ARRAY_BONES] = BO
	final[Mesh.ARRAY_WEIGHTS] = PE
	var st2 := SurfaceTool.new()
	st2.create_from_arrays(final)
	st2.generate_tangents()
	var arr2 := st2.commit_to_arrays()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(saida + "/cor.jpg")
	mat.roughness_texture = load(saida + "/orm.jpg")
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.metallic_texture = load(saida + "/orm.jpg")
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.metallic = 1.0
	mat.roughness = 1.0
	mat.normal_enabled = true
	mat.normal_texture = load(saida + "/normal.png")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	ResourceSaver.save(mesh, saida + "/corpo.res", ResourceSaver.FLAG_COMPRESS)
	ResourceSaver.save(skin, saida + "/corpo_skin.tres")
	print("gravado: %d vértices, %d triângulos, %d ossos" % [V.size(), I.size() / 3, bind_lista.size()])
	r.free()
	cena.free()
	quit()

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
