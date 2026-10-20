class_name PegadaArma
extends SkeletonModifier3D
## Pega arma longa com as duas mãos, por cima da animação (a biblioteca de animações não
## tem poses de fuzil): coronha no ombro direito, mão direita na empunhadura, mão esquerda
## no guarda-mão, cotovelos com dobra natural (IK analítico de dois ossos), tronco virado
## de lado como um atirador de verdade e cabeça olhando para a frente.
##
## A arma em si continua presa à mão direita (Modelos.arma_na_mao); aqui só se move o braço
## para que a mão (e a arma junto) fique alinhada com a mira.

var ativo := false
var mira := Vector3(0, 0, 1)        # direção da mira (mundo)
var baixa := 0.0                   # 0 = mirando, 1 = arma baixa (andando, recarregando)
var ombro := Vector3(-0.3, 0.05, 0) # coronha em relação à empunhadura (espaço da arma, m)
var apoio := Vector3(0.3, 0.05, 0)  # guarda-mão em relação à empunhadura (espaço da arma, m)
var corpo: Node3D                  # nó do personagem (frente = +Z)
var peso := 0.0                    # mistura suave ao entrar/sair

const BASE_MAO := Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
const CENTRO_MAO := Vector3(0.0, 0.08, 0.0)

var _b := {}

func _ossos(sk: Skeleton3D) -> bool:
	if _b.is_empty():
		for n in ["spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "upperarm_r", "lowerarm_r", "hand_r", "upperarm_l", "lowerarm_l", "hand_l"]:
			_b[n] = sk.find_bone(n)
	return _b.upperarm_r >= 0 and _b.hand_l >= 0

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or corpo == null or not _ossos(sk):
		return
	var dt := get_process_delta_time() if is_inside_tree() else 0.016
	peso = move_toward(peso, 1.0 if ativo else 0.0, dt * 6.0)
	if peso <= 0.001:
		return
	var gs := sk.global_transform
	var rs := gs.basis.orthonormalized()
	# o esqueleto da UAL olha para +Z e a mão direita fica em -X
	var frente := (rs * Vector3(0, 0, 1)).normalized()
	var direita := (rs * Vector3(-1, 0, 0)).normalized()
	var cima := Vector3.UP
	# direção da arma: a mira, abaixada quando "baixa" (ponta para o chão, à frente)
	var m := mira.normalized()
	var desce := frente.slerp(-cima, 0.38).normalized()
	var wx := m.slerp(desce, baixa).normalized()
	# 1) tronco de lado (ombro esquerdo à frente) e cabeça de volta para a mira
	var giro := -0.5 * peso
	_girar(sk, gs, rs, _b.spine_03, cima, giro * 0.6)
	_girar(sk, gs, rs, _b.spine_02, cima, giro * 0.4)
	_girar(sk, gs, rs, _b.neck_01, cima, -giro * 0.85)
	# cabeça encostada na coronha ao mirar (inclina para a direita e para baixo)
	_girar(sk, gs, rs, _b.neck_01, frente, 0.22 * peso * (1.0 - baixa))
	_girar(sk, gs, rs, _b.neck_01, direita, 0.12 * peso * (1.0 - baixa))
	# inclina o tronco junto com a mira (para cima/baixo)
	var pitch := asin(clampf(wx.y, -1.0, 1.0))
	_girar(sk, gs, rs, _b.spine_03, direita, -pitch * 0.45 * peso)
	# clavícula esquerda para frente: o braço alcança o guarda-mão
	_girar(sk, gs, rs, _b.clavicle_l, cima, -0.35 * peso)
	# 2) quadro da arma
	var wy := (cima - wx * wx.dot(cima)).normalized()
	var wz := wx.cross(wy)
	var W := Basis(wx, wy, wz)
	var ombro_d := _mundo(sk, gs, _b.upperarm_r).origin
	var ombro_e := _mundo(sk, gs, _b.upperarm_l).origin
	var meio := (ombro_d + ombro_e) * 0.5
	# coronha no "bolso" do ombro: um pouco para dentro e para frente da articulação
	var bolso := ombro_d.lerp(meio, 0.35) + frente * 0.07 - cima * 0.04
	bolso += direita * 0.05 * baixa - cima * 0.07 * baixa + cima * 0.025 * (1.0 - baixa)
	var empunhadura := bolso - W * ombro
	# 3) mão direita: posição e giro exatos para a arma ficar no quadro W
	var Hd := W * BASE_MAO.inverse()
	var alvo_d := empunhadura - Hd * CENTRO_MAO
	_braco(sk, gs, rs, _b.upperarm_r, _b.lowerarm_r, _b.hand_r, alvo_d, Hd, -cima * 1.0 + direita * 0.7)
	# 4) mão esquerda por baixo do guarda-mão: palma para cima, dedos para frente-direita
	var ye := (wx * 0.75 + wz * 0.66).normalized()
	var xe := wy
	var ze := xe.cross(ye)
	var He := Basis(xe, ye, ze).orthonormalized()
	var ponto_e := empunhadura + W * apoio
	var alvo_e := ponto_e - He * Vector3(0.04, 0.08, 0.0)
	_braco(sk, gs, rs, _b.upperarm_l, _b.lowerarm_l, _b.hand_l, alvo_e, He, -cima * 1.0 - direita * 0.4)

func _mundo(sk: Skeleton3D, gs: Transform3D, b: int) -> Transform3D:
	return gs * sk.get_bone_global_pose(b)

## Põe o osso b na transformação t (mundo), só a rotação (a posição vem do pai).
func _por_rot(sk: Skeleton3D, gs: Transform3D, rs: Basis, b: int, base_mundo: Basis) -> void:
	var p := sk.get_bone_global_pose(b)
	var atual := (rs * p.basis.orthonormalized())
	var novo := atual.slerp(base_mundo.orthonormalized(), peso) if peso < 0.999 else base_mundo.orthonormalized()
	p.basis = (rs.inverse() * novo).orthonormalized().scaled(p.basis.get_scale())
	sk.set_bone_global_pose(b, p)

func _girar(sk: Skeleton3D, gs: Transform3D, rs: Basis, b: int, eixo: Vector3, ang: float) -> void:
	if b < 0 or absf(ang) < 0.0001:
		return
	var p := sk.get_bone_global_pose(b)
	var atual := rs * p.basis.orthonormalized()
	var novo := Basis(eixo.normalized(), ang) * atual
	p.basis = (rs.inverse() * novo).orthonormalized().scaled(p.basis.get_scale())
	sk.set_bone_global_pose(b, p)

static func _rot_entre(a: Vector3, b: Vector3) -> Basis:
	var u := a.normalized()
	var v := b.normalized()
	var c := u.cross(v)
	var s := c.length()
	var d := clampf(u.dot(v), -1.0, 1.0)
	if s < 0.00001:
		return Basis() if d > 0.0 else Basis(u.cross(Vector3.UP if absf(u.y) < 0.9 else Vector3.RIGHT).normalized(), PI)
	return Basis(c / s, atan2(s, d))

## IK de dois ossos: braço (b1), antebraço (b2) e mão (b3). alvo = origem da mão (mundo),
## giro = base da mão (mundo), polo = para onde o cotovelo aponta.
func _braco(sk: Skeleton3D, gs: Transform3D, rs: Basis, b1: int, b2: int, b3: int, alvo: Vector3, giro: Basis, polo: Vector3) -> void:
	var A := _mundo(sk, gs, b1).origin
	var C0 := _mundo(sk, gs, b2).origin
	var M0 := _mundo(sk, gs, b3).origin
	var l1 := A.distance_to(C0)
	var l2 := C0.distance_to(M0)
	# alvo misturado com a pose da animação conforme o peso
	var T := M0.lerp(alvo, peso)
	var dv := T - A
	var d := clampf(dv.length(), absf(l1 - l2) + 0.001, (l1 + l2) * 0.999)
	var dir := dv.normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var p := polo - dir * polo.dot(dir)
	if p.length() < 0.001:
		p = Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
	p = p.normalized()
	var E := A + dir * (l1 * ca) + p * (l1 * sqrt(1.0 - ca * ca))
	# braço
	var r1 := _rot_entre(C0 - A, E - A)
	var t1 := _mundo(sk, gs, b1)
	_por_rot_direto(sk, rs, b1, r1 * t1.basis.orthonormalized())
	# antebraço (já com o braço novo)
	var t2 := _mundo(sk, gs, b2)
	var M1 := _mundo(sk, gs, b3).origin
	var r2 := _rot_entre(M1 - t2.origin, A + dir * d - t2.origin)
	_por_rot_direto(sk, rs, b2, r2 * t2.basis.orthonormalized())
	# mão
	_por_rot(sk, gs, rs, b3, giro)

func _por_rot_direto(sk: Skeleton3D, rs: Basis, b: int, base_mundo: Basis) -> void:
	var p := sk.get_bone_global_pose(b)
	p.basis = (rs.inverse() * base_mundo).orthonormalized().scaled(p.basis.get_scale())
	sk.set_bone_global_pose(b, p)
