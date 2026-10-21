class_name CabecaOculta
extends SkeletonModifier3D
## Em 1ª pessoa o corpo continua visível (mãos, arma, pés, sombra), mas a cabeça
## "encolhe" para dentro do pescoço: a câmera fica nos olhos sem ver o capuz por dentro.

var ativo := false
var _b := -2

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _b == -2:
		_b = sk.find_bone("Head")
	if _b < 0:
		return
	sk.set_bone_pose_scale(_b, Vector3.ONE * (0.001 if ativo else 1.0))
