extends SceneTree
## Redireciona (retarget) animações da Universal Animation Library (Quaternius)
## para o esqueleto dos personagens com rosto (Ultimate Animated Character Pack).
## Gera res://assets/personagens/anims_q.res (AnimationLibrary).
## Uso: godot --headless --path . -s tools/gerar_anims.gd

const FPS := 30.0
var ALVO := "res://assets/personagens/Casual_Male.gltf"
var SAIDA := "res://assets/personagens/anims_q.res"
var MAPA: Dictionary
var RAIZ_QUADRIL := "Body_2"

# Kenney (Animated Characters): esqueleto estilo Mixamo
const MAPA_K := {
	"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Chest", "spine_03": "UpperChest", "neck_01": "Neck", "Head": "Head",
	"clavicle_l": "LeftShoulder", "upperarm_l": "LeftArm", "lowerarm_l": "LeftForeArm", "hand_l": "LeftHand",
	"index_01_l": "LeftHandIndex1", "index_02_l": "LeftHandIndex2", "index_03_l": "LeftHandIndex3",
	"thumb_01_l": "LeftHandThumb1", "thumb_02_l": "LeftHandThumb2",
	"clavicle_r": "RightShoulder", "upperarm_r": "RightArm", "lowerarm_r": "RightForeArm", "hand_r": "RightHand",
	"index_01_r": "RightHandIndex1", "index_02_r": "RightHandIndex2", "index_03_r": "RightHandIndex3",
	"thumb_01_r": "RightHandThumb1", "thumb_02_r": "RightHandThumb2",
	"thigh_l": "LeftUpLeg", "calf_l": "LeftLeg", "foot_l": "LeftFoot", "ball_l": "LeftToes",
	"thigh_r": "RightUpLeg", "calf_r": "RightLeg", "foot_r": "RightFoot", "ball_r": "RightToes",
}

# osso da UAL -> osso do personagem (Quaternius)
const MAPA_Q := {
	"pelvis": "Body_2", "spine_01": "Hips", "spine_02": "Abdomen", "spine_03": "Torso",
	"neck_01": "Neck", "Head": "Head",
	"clavicle_l": "Shoulder.L", "upperarm_l": "UpperArm.L", "lowerarm_l": "LowerArm.L", "hand_l": "Fist.L",
	"clavicle_r": "Shoulder.R", "upperarm_r": "UpperArm.R", "lowerarm_r": "LowerArm.R", "hand_r": "Fist.R",
	"thigh_l": "UpperLeg.L", "calf_l": "LowerLeg.L", "foot_l": "Foot.L",
	"thigh_r": "UpperLeg.R", "calf_r": "LowerLeg.R", "foot_r": "Foot.R",
}
const LOOPS := ["Idle", "Idle_LookAround", "Idle_Talking", "Idle_Tired", "Idle_FoldArms", "Idle_Torch", "Walk", "Walk_Formal",
	"Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Crawl_Fwd", "Crawl_Idle", "Pistol_Idle", "Pistol_Aim_Neutral",
	"Pistol_Aim_Down", "Pistol_Aim_Up", "Fixing_Kneeling", "GroundSit_Idle", "Sitting_Idle", "Sitting_Talking",
	"Zombie_Idle", "Zombie_Walk_Fwd", "Zombie_Run_Fwd", "Farm_Harvest", "Farm_Watering", "Mining", "TreeChopping",
	"Walk_Carry", "Sword_Idle", "Swim_Idle", "Driving", "Crying", "Dance", "Idle_Lantern", "Idle_TalkingPhone", "Idle_Rail", "Consume"]
const CLIPES := ["Idle", "Idle_LookAround", "Idle_Talking", "Idle_Tired", "Idle_Torch", "Walk", "Walk_Formal", "Jog_Fwd", "Sprint",
	"Crouch_Idle", "Crouch_Fwd", "Crawl_Fwd", "Crawl_Idle", "Death01", "Death02", "Drink", "Driving", "Fixing_Kneeling",
	"GroundSit_Idle", "Sitting_Idle", "Sitting_Talking", "Hit_Chest", "Hit_Head", "Hit_Shoulder_L", "Hit_Shoulder_R", "Hit_Stomach",
	"Interact", "Jump", "Kick", "PickUp_Kneeling", "PickUp_Table", "Pistol_Aim_Down", "Pistol_Aim_Neutral", "Pistol_Aim_Up",
	"Pistol_Idle", "Pistol_Reload", "Pistol_Shoot", "Punch_Cross", "Punch_Jab", "Push", "Roll", "Sword_Attack", "Sword_Idle",
	"Crying", "Dance", "Celebration",
	"Bandage", "Consume", "Farm_Harvest", "Farm_PlantSeed", "Farm_Watering", "Hit_Knockback", "Idle_FoldArms", "Idle_Lantern",
	"Idle_No", "Idle_TalkingPhone", "Idle_Rail", "Melee_Hook", "Melee_Uppercut", "Mining", "OverhandThrow", "Sword_Heavy_A",
	"Sword_Light_A", "Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C", "TreeChopping", "Walk_Carry", "Yes", "Surprise",
	"Zombie_Bite", "Zombie_Idle", "Zombie_Run_Fwd", "Zombie_Scratch", "Zombie_Spawn", "Zombie_Walk_Fwd", "Chest_Open", "LayToIdle", "IdleToLay"]

var fonte_cenas := {}

func _init() -> void:
	MAPA = MAPA_Q
	if "kenney" in OS.get_cmdline_user_args():
		ALVO = "res://assets/personagens_k/characterMedium.fbx"
		SAIDA = "res://assets/personagens_k/anims_k.res"
		MAPA = MAPA_K
		RAIZ_QUADRIL = "Hips"
	# ---- alvo (personagem com rosto): pose de ligação da malha (T-pose), em espaço do modelo
	var alvo: Node3D = load(ALVO).instantiate()
	var sk_t: Skeleton3D = alvo.find_children("*", "Skeleton3D", true, false)[0]
	var cadeia_t := _cadeia(alvo, sk_t)
	var mi: MeshInstance3D = alvo.find_children("*", "MeshInstance3D", true, false)[0]
	var bind := {}
	for b in sk_t.get_bone_count():
		bind[sk_t.get_bone_name(b)] = cadeia_t * sk_t.get_bone_global_rest(b)
	for i in mi.skin.get_bind_count():
		var nm := String(mi.skin.get_bind_name(i))
		if nm == "" and mi.skin.get_bind_bone(i) >= 0:
			nm = sk_t.get_bone_name(mi.skin.get_bind_bone(i))
		bind[nm] = cadeia_t * mi.skin.get_bind_pose(i).affine_inverse()
	var caminho_t := String(alvo.get_path_to(sk_t))
	# ---- fontes (UAL1 e UAL2 têm o mesmo esqueleto)
	var lib := AnimationLibrary.new()
	var faltando: Array = []
	var ual := []
	for p in ["res://assets/personagens/UAL1.glb", "res://assets/personagens/UAL2.glb"]:
		var c: Node3D = load(p).instantiate()
		ual.append(c)
	var sk_s: Skeleton3D = ual[0].find_children("*", "Skeleton3D", true, false)[0]
	var cadeia_s := _cadeia(ual[0], sk_s)
	var caminho_s := String(ual[0].get_path_to(sk_s))
	# rest global da fonte
	var RS := {}
	for b in sk_s.get_bone_count():
		RS[sk_s.get_bone_name(b)] = cadeia_s * sk_s.get_bone_global_rest(b)
	# rotação "virtual" de descanso do alvo: alinha o eixo do osso do alvo ao da fonte
	var VT := {}
	for s in MAPA:
		var t: String = MAPA[s]
		var bt: Basis = bind[t].basis.orthonormalized()
		var rs: Basis = RS[s].basis.orthonormalized()
		var a := Quaternion.IDENTITY
		if not t.begins_with("Foot"):
			a = Quaternion(bt.y.normalized(), rs.y.normalized())
		VT[t] = Basis(a) * bt
	var k_alt: float = bind[RAIZ_QUADRIL].origin.y / RS["pelvis"].origin.y
	# deslocamento do tornozelo (pé IK do Quaternius) no espaço da canela
	var tornozelo := {}
	if MAPA.has("foot_l") and String(MAPA["foot_l"]).begins_with("Foot."):
		for lado in ["L", "R"]:
			tornozelo[lado] = (bind["LowerLeg." + lado].affine_inverse() * bind["Foot." + lado]).origin
	for nome in CLIPES:
		var anim: Animation = null
		for c in ual:
			var ap: AnimationPlayer = c.find_children("*", "AnimationPlayer", true, false)[0]
			if ap.has_animation(nome):
				anim = ap.get_animation(nome)
				break
		if anim == null:
			faltando.append(nome)
			continue
		var nova := _redirecionar(anim, sk_s, caminho_s, cadeia_s, RS, sk_t, caminho_t, cadeia_t, VT, k_alt, tornozelo)
		nova.loop_mode = Animation.LOOP_LINEAR if nome in LOOPS else Animation.LOOP_NONE
		lib.add_animation(nome, nova)
	print("faltando: ", faltando)
	print("salvo ", lib.get_animation_list().size(), " animações: ", ResourceSaver.save(lib, SAIDA))
	quit()

func _cadeia(raiz: Node, n: Node) -> Transform3D:
	var t := Transform3D()
	while n != raiz:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

func _redirecionar(anim: Animation, sk_s: Skeleton3D, caminho_s: String, cadeia_s: Transform3D, RS: Dictionary,
		sk_t: Skeleton3D, caminho_t: String, cadeia_t: Transform3D, VT: Dictionary, k_alt: float, tornozelo: Dictionary) -> Animation:
	var esc_t: float = cadeia_t.basis.get_scale().x
	var cadeia_inv := cadeia_t.affine_inverse()
	var nova := Animation.new()
	nova.length = anim.length
	# trilhas da fonte por osso
	var tr_rot := {}
	var tr_pos := {}
	for i in anim.get_track_count():
		var pth := String(anim.track_get_path(i))
		var osso := pth.get_slice(":", 1)
		if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			tr_rot[osso] = i
		elif anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			tr_pos[osso] = i
	# trilhas novas
	var tt := {}
	for s in MAPA:
		var t: String = MAPA[s]
		var ir := nova.add_track(Animation.TYPE_ROTATION_3D)
		nova.track_set_path(ir, NodePath(caminho_t + ":" + t))
		tt[t + "_r"] = ir
		if t == RAIZ_QUADRIL or (t.begins_with("Foot") and tornozelo.size() > 0):
			var ip := nova.add_track(Animation.TYPE_POSITION_3D)
			nova.track_set_path(ip, NodePath(caminho_t + ":" + t))
			tt[t + "_p"] = ip
	var n_q := maxi(2, int(ceil(anim.length * FPS)) + 1)
	var ordem_s: Array = []
	for b in sk_s.get_bone_count():
		ordem_s.append(b)   # pais sempre vêm antes dos filhos no Skeleton3D
	var id_t := {}
	for b in sk_t.get_bone_count():
		id_t[sk_t.get_bone_name(b)] = b
	for q in n_q:
		var tempo := minf(anim.length, q / FPS)
		# pose global da fonte
		var GS := {}
		for b in ordem_s:
			var nm := sk_s.get_bone_name(b)
			var rest := sk_s.get_bone_rest(b)
			var rot := rest.basis.get_rotation_quaternion()
			var pos := rest.origin
			if tr_rot.has(nm):
				rot = anim.rotation_track_interpolate(tr_rot[nm], tempo)
			if tr_pos.has(nm):
				pos = anim.position_track_interpolate(tr_pos[nm], tempo)
			var local := Transform3D(Basis(rot), pos)
			var par := sk_s.get_bone_parent(b)
			GS[nm] = (GS[sk_s.get_bone_name(par)] if par >= 0 else cadeia_s) * local
		# pose global do alvo (espaço do modelo, em metros, bases ortonormais)
		var GT := {}
		for s in MAPA:
			var t: String = MAPA[s]
			var gs: Basis = GS[s].basis.orthonormalized()
			var base: Basis = gs * RS[s].basis.orthonormalized().inverse() * VT[t]
			var origem: Vector3
			var pai_id := sk_t.get_bone_parent(id_t[t])
			var pai: String = sk_t.get_bone_name(pai_id) if pai_id >= 0 else ""
			if t == RAIZ_QUADRIL:
				origem = GS[s].origin * k_alt
			elif tornozelo.size() > 0 and t.begins_with("Foot"):
				var lado := t.get_slice(".", 1)
				origem = GT["LowerLeg." + lado] * tornozelo[lado]
			elif GT.has(pai):
				origem = GT[pai] * (sk_t.get_bone_rest(id_t[t]).origin * esc_t)
			else:
				origem = (cadeia_t * sk_t.get_bone_global_rest(id_t[t])).origin
			GT[t] = Transform3D(base, origem)
		for s in MAPA:
			var t: String = MAPA[s]
			var pai_id := sk_t.get_bone_parent(id_t[t])
			# volta para o espaço do esqueleto
			var g_sk: Transform3D = cadeia_inv * GT[t]
			var p_sk: Transform3D = Transform3D()
			if pai_id >= 0:
				var pai: String = sk_t.get_bone_name(pai_id)
				p_sk = cadeia_inv * GT[pai] if GT.has(pai) else sk_t.get_bone_global_rest(pai_id)
			var local: Transform3D = p_sk.affine_inverse() * g_sk
			nova.rotation_track_insert_key(tt[t + "_r"], tempo, local.basis.get_rotation_quaternion())
			if tt.has(t + "_p"):
				nova.position_track_insert_key(tt[t + "_p"], tempo, local.origin)
	return nova
