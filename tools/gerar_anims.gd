extends SceneTree
## Redireciona (retarget) animações da Universal Animation Library (Quaternius)
## para o esqueleto dos personagens com rosto (Ultimate Animated Character Pack).
## Gera res://assets/personagens/anims_q.res (AnimationLibrary).
## Uso: godot --headless --path . -s tools/gerar_anims.gd

const FPS := 30.0
const ALVO := "res://assets/personagens/Casual_Male.gltf"
const SAIDA := "res://assets/personagens/anims_q.res"

# osso da UAL -> osso do personagem
const MAPA := {
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
	# ---- alvo (personagem com rosto): pose de ligação da malha (T-pose)
	var alvo: Node3D = load(ALVO).instantiate()
	var sk_t: Skeleton3D = alvo.find_child("Skeleton3D", true, false)
	var mi: MeshInstance3D = alvo.find_children("*", "MeshInstance3D", true, false)[0]
	var bind := {}
	for i in mi.skin.get_bind_count():
		bind[String(mi.skin.get_bind_name(i))] = mi.skin.get_bind_pose(i).affine_inverse()
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
	var k_alt: float = bind["Body_2"].origin.y / RS["pelvis"].origin.y
	# deslocamento do tornozelo (pé) no espaço da canela
	var tornozelo := {}
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
		var nova := _redirecionar(anim, sk_s, caminho_s, cadeia_s, RS, sk_t, caminho_t, VT, k_alt, tornozelo)
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
		sk_t: Skeleton3D, caminho_t: String, VT: Dictionary, k_alt: float, tornozelo: Dictionary) -> Animation:
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
		if t == "Body_2" or t.begins_with("Foot"):
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
		# pose global do alvo
		var GT := {}
		GT["Bone"] = sk_t.get_bone_global_rest(id_t["Bone"])
		for s in MAPA:
			var t: String = MAPA[s]
			var gs: Basis = GS[s].basis.orthonormalized()
			var base: Basis = gs * RS[s].basis.orthonormalized().inverse() * VT[t]
			var origem: Vector3
			if t == "Body_2":
				origem = GS[s].origin * k_alt
			elif t.begins_with("Foot"):
				var lado := t.get_slice(".", 1)
				origem = GT["LowerLeg." + lado] * tornozelo[lado]
			else:
				var pai: String = sk_t.get_bone_name(sk_t.get_bone_parent(id_t[t]))
				origem = GT[pai] * sk_t.get_bone_rest(id_t[t]).origin
			GT[t] = Transform3D(base, origem)
		for s in MAPA:
			var t: String = MAPA[s]
			var pai: String = sk_t.get_bone_name(sk_t.get_bone_parent(id_t[t]))
			var local: Transform3D = GT[pai].affine_inverse() * GT[t]
			nova.rotation_track_insert_key(tt[t + "_r"], tempo, local.basis.get_rotation_quaternion())
			if tt.has(t + "_p"):
				nova.position_track_insert_key(tt[t + "_p"], tempo, local.origin)
	return nova
