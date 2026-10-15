class_name Kit
## Objetos low poly do KayKit RPG Tools Bits (Kay Lousberg, CC0): bigorna, rebolo,
## ferramentas, balde, lampião, corda, cadernos e mapas. Escala ajustada ao tamanho real.

const ESCALA := {
	"anvil": 0.4, "grindstone": 0.55, "axe": 0.55, "pickaxe": 0.5, "shovel": 0.7, "hammer": 0.4,
	"mallet": 0.38, "saw": 0.45, "wrench_A": 0.3, "wrench_B": 0.3, "bucket_metal": 0.3, "lantern": 0.3,
	"rope_bundle_A": 0.3, "rope_bundle_B": 0.32, "journal_closed": 0.32, "journal_open": 0.32,
	"map": 0.3, "map_rolled": 0.35, "handdrill": 0.3, "handplane": 0.28, "screwdriver_A_long_color": 0.25,
	"tongs": 0.35, "torch_burnt": 0.45, "knife": 0.25, "chisel": 0.25, "file": 0.25,
}
static var _cenas := {}

## Põe um objeto. giro em graus (Vector3), escala relativa ao tamanho real.
static func por(pai: Node3D, id: String, pos: Vector3, giro := Vector3.ZERO, escala := 1.0, alcance := 45.0) -> Node3D:
	if not _cenas.has(id):
		var c := "res://assets/kaykit/%s.gltf" % id
		_cenas[id] = load(c) if ResourceLoader.exists(c) else null
	var cena: PackedScene = _cenas[id]
	if cena == null:
		return null
	var n: Node3D = cena.instantiate()
	n.position = pos
	n.rotation_degrees = giro
	n.scale = Vector3.ONE * float(ESCALA.get(id, 0.4)) * escala
	n.set_meta("nao_mesclar", true)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		m.visibility_range_end = alcance
		if alcance < 30.0:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(n)
	return n

## Ferramentas penduradas num painel (pos = centro do painel, normal = para onde ele olha).
static func painel(pai: Node3D, centro: Vector3, giro_y: float, r: RandomNumberGenerator, n := 5, largura := 1.3) -> void:
	var ids := ["hammer", "wrench_A", "saw", "mallet", "wrench_B", "screwdriver_A_long_color", "tongs", "file", "chisel"]
	var b := Basis(Vector3.UP, deg_to_rad(giro_y))
	for i in n:
		var x := -largura * 0.5 + (i + 0.5) * largura / n
		var id: String = ids[(i + r.randi()) % ids.size()]
		por(pai, id, centro + b * Vector3(x, 0, 0.03), Vector3(0, giro_y, r.randf_range(-12, 12)), 1.0, 30.0)
