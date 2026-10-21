extends SceneTree
## "Assa" cada objeto do catálogo Props numa cena pequena e independente
## (assets/props/<id>.scn): só as malhas e materiais usados, sem carregar o pacote .glb
## inteiro (o City Props tem 90 texturas, o Trailer Park 96...). Carrega mais rápido e
## gasta bem menos memória. Rodar de novo depois de mudar o catálogo.
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Props.ASSADOS))
	var n := 0
	for id in Props.C.keys():
		var m := Props._molde(id, true)
		if m == null:
			continue
		var raiz := Node3D.new()
		raiz.name = id
		raiz.set_meta("tamanho", m.get_meta("tamanho"))
		for c in m.get_children():
			var mi := c as MeshInstance3D
			if mi == null:
				continue
			var malha: ArrayMesh = (mi.mesh as ArrayMesh).duplicate()
			malha.resource_path = ""
			for s in malha.get_surface_count():
				var mat: Material = mi.get_surface_override_material(s)
				if mat == null:
					mat = mi.material_override
				if mat == null:
					mat = mi.mesh.surface_get_material(s)
				if mat:
					var copia: Material = mat.duplicate()
					copia.resource_path = ""
					if copia is BaseMaterial3D:
						_encolher_embutidas(copia as BaseMaterial3D)
					malha.surface_set_material(s, copia)
			var novo := MeshInstance3D.new()
			novo.name = mi.name
			novo.mesh = malha
			novo.transform = mi.transform
			raiz.add_child(novo)
			novo.owner = raiz
		var ps := PackedScene.new()
		ps.pack(raiz)
		var caminho: String = Props.ASSADOS + id + ".scn"
		ResourceSaver.save(ps, caminho, ResourceSaver.FLAG_COMPRESS)
		raiz.free()
		n += 1
	print("assados: ", n)
	quit()

## Texturas que o Godot gerou na importação (ex.: brilho -> rugosidade) vêm embutidas e cruas;
## reduz para 256 px (512 na cor) para a cena não ficar pesada.
static func _encolher_embutidas(m: BaseMaterial3D) -> void:
	for p in BaseMaterial3D.TEXTURE_MAX:
		var t := m.get_texture(p)
		if t == null or not (t is ImageTexture):
			continue
		var img: Image = t.get_image()
		if img == null:
			continue
		var lado := 512 if p == BaseMaterial3D.TEXTURE_ALBEDO else 256
		if img.is_compressed():
			img.decompress()
		if maxi(img.get_width(), img.get_height()) > lado:
			var f := float(lado) / maxi(img.get_width(), img.get_height())
			img.resize(maxi(4, int(img.get_width() * f)), maxi(4, int(img.get_height() * f)), Image.INTERPOLATE_LANCZOS)
		img.generate_mipmaps()
		m.set_texture(p, ImageTexture.create_from_image(img))
