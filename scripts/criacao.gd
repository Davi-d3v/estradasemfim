class_name Criacao
extends RefCounted
## Criação [B]: sobrevivência (assar carne, bandagens, molotov), couro e armadura
## (curtir pele, costurar peças, vestir) e metal (refinar sucata em chapas na forja
## da oficina, reforçar e consertar armadura e armas).

var main: Node
var aba := "sobrevivencia"

## receita: nome, entra (itens), sai (itens), horas, local (qualquer/fogueira/oficina), extra (diesel em litros)
const RECEITAS := {
	"assar": {"nome": "Assar carne", "entra": {"carne_crua": 1}, "sai": {"carne_assada": 1}, "horas": 0.25, "local": "fogueira", "aba": "sobrevivencia"},
	"cafe": {"nome": "Passar café", "entra": {"po_cafe": 1, "agua": 1}, "sai": {"cafe": 2}, "horas": 0.15, "local": "fogueira", "aba": "sobrevivencia"},
	"sopa": {"nome": "Sopa", "entra": {"comida": 1, "agua": 2}, "sai": {"sopa": 2}, "horas": 0.5, "local": "fogueira", "aba": "sobrevivencia"},
	"ensopado": {"nome": "Ensopado de caça", "entra": {"carne_crua": 2, "comida": 1, "agua": 1}, "sai": {"ensopado": 2}, "horas": 1.0, "local": "fogueira", "aba": "sobrevivencia"},
	"bandagem": {"nome": "Bandagem", "entra": {"tecido": 2}, "sai": {"bandagem": 1}, "horas": 0.2, "local": "qualquer", "aba": "sobrevivencia"},
	"corda": {"nome": "Trançar corda", "entra": {"tecido": 3}, "sai": {"cordame": 1}, "horas": 0.5, "local": "qualquer", "aba": "sobrevivencia"},
	"molotov": {"nome": "Coquetéis molotov", "entra": {"garrafa": 2, "tecido": 2, "galoes_diesel": 1}, "sai": {"molotov": 2}, "horas": 0.3, "local": "qualquer", "aba": "sobrevivencia"},
	"virote": {"nome": "Virotes para besta", "entra": {"sucata": 3}, "sai": {"virote": 5}, "horas": 0.5, "local": "oficina", "aba": "sobrevivencia"},
	"taco": {"nome": "Taco com pregos", "entra": {"sucata": 6, "tecido": 1}, "sai": {"taco": 1}, "horas": 1.0, "local": "oficina", "aba": "sobrevivencia"},
	"curtir": {"nome": "Curtir pele em couro", "entra": {"pele": 1}, "sai": {"couro": 1}, "horas": 3.0, "local": "fogueira", "aba": "couro"},
	"capuz_couro": {"nome": "Capuz de couro", "entra": {"couro": 2, "cordame": 1}, "sai": {"capuz_couro": 1}, "horas": 2.0, "local": "qualquer", "aba": "couro"},
	"colete_couro": {"nome": "Colete de couro", "entra": {"couro": 4, "cordame": 2}, "sai": {"colete_couro": 1}, "horas": 4.0, "local": "qualquer", "aba": "couro"},
	"calca_couro": {"nome": "Calça de couro", "entra": {"couro": 3, "cordame": 1}, "sai": {"calca_couro": 1}, "horas": 3.0, "local": "qualquer", "aba": "couro"},
	"bracadeiras": {"nome": "Braçadeiras de couro", "entra": {"couro": 2}, "sai": {"bracadeiras": 1}, "horas": 1.5, "local": "qualquer", "aba": "couro"},
	"chapa": {"nome": "Refinar sucata em chapa", "entra": {"sucata": 12}, "sai": {"chapa": 1}, "horas": 1.5, "local": "oficina", "diesel": 3.0, "aba": "metal"},
}
const NOMES_LOCAL := {"qualquer": "", "fogueira": "precisa de fogueira (acampamento montado ou cozinha do trailer)", "oficina": "precisa da forja da oficina móvel por perto"}
const NOMES_SLOT := {"cabeca": "Cabeça", "torso": "Torso", "pernas": "Pernas", "bracos": "Braços"}

func local_ok(local: String) -> bool:
	match local:
		"fogueira":
			var tp: Vector3 = main.trailer.global_position
			var perto: bool = main.jogador.global_position.distance_to(tp) < 14.0 or main.dentro == main.trailer
			return perto and (main.acampamento != null or main.trailer.cozinha_aberta > 0.5)
		"oficina":
			var of: Node = main.base.reboque("oficina")
			if of == null or not of.funcional():
				return false
			return main.jogador.global_position.distance_to(of.global_position) < 14.0 or main.dentro == of
	return true

func pode(id: String, vezes := 1) -> bool:
	var rc: Dictionary = RECEITAS[id]
	for k in rc.entra:
		if main.estoque.get(k, 0) < rc.entra[k] * vezes:
			return false
	if rc.has("diesel") and main.comboio.diesel < rc.diesel * vezes:
		return false
	return local_ok(rc.local)

func fazer(id: String, vezes := 1) -> String:
	if not pode(id, vezes):
		return "Faltam materiais ou o lugar certo."
	var rc: Dictionary = RECEITAS[id]
	var livre: float = main.capacidade_carga() - main.volume_usado()
	var sai_v := 0.0
	var entra_v := 0.0
	for k in rc.sai:
		sai_v += main.ITENS[k].vol * rc.sai[k] * vezes
	for k in rc.entra:
		entra_v += main.ITENS[k].vol * rc.entra[k] * vezes
	if livre + entra_v < sai_v - 0.001:
		return "Sem espaço na carga para o resultado."
	for k in rc.entra:
		main.estoque[k] -= rc.entra[k] * vezes
	if rc.has("diesel"):
		main.comboio.diesel -= rc.diesel * vezes
	var ev: String = main.trabalhar(rc.horas * vezes, "%s…" % rc.nome, "Fixing_Kneeling" if rc.local != "qualquer" else "Farm_Harvest")
	var ganhos: Array[String] = []
	for k in rc.sai:
		var n: int = main.adicionar(k, rc.sai[k] * vezes)
		ganhos.append("%d %s" % [n, main.ITENS[k].get("um", main.ITENS[k].nome) if n == 1 else main.ITENS[k].nome.to_lower()])
	return "%s: %s (%s).%s" % [rc.nome, ", ".join(ganhos), main._txt_horas(rc.horas * vezes), (" " + ev) if ev != "" else ""]

func vezes_max(id: String) -> int:
	var rc: Dictionary = RECEITAS[id]
	var n := 99
	for k in rc.entra:
		n = mini(n, main.estoque.get(k, 0) / rc.entra[k])
	if rc.has("diesel"):
		n = mini(n, int(main.comboio.diesel / rc.diesel))
	return n

# ------------------------------------------------------------ armadura
func custo_reforco(slot: String) -> Dictionary:
	var a: Dictionary = main.equip.armadura[slot]
	return {"chapa": a.reforco + 1, "pecas": 2}

func reforcar(slot: String) -> String:
	var a: Dictionary = main.equip.armadura.get(slot, {})
	if a.is_empty() or a.reforco >= 3:
		return ""
	var c := custo_reforco(slot)
	if not main.tem_itens(c) or not local_ok("oficina"):
		return "Faltam chapas/peças ou a forja da oficina."
	main.gastar(c)
	a.reforco += 1
	var ev: String = main.trabalhar(2.0, "Reforçando a armadura")
	main.jogador.atualizar_armadura(main.equip.armadura)
	return "%s reforçado com chapas (nível %d)." % [Armas.ARMADURA[a.id].nome, a.reforco] + ((" " + ev) if ev != "" else "")

func consertar_armadura(slot: String) -> String:
	var a: Dictionary = main.equip.armadura.get(slot, {})
	var c := {"couro": 1}
	if a.reforco > 0:
		c["chapa"] = 1
	if not main.tem_itens(c):
		return "Precisa de %s." % main._txt_custo(c)
	main.gastar(c)
	a.condicao = 1.0
	main.trabalhar(1.0, "Costurando a armadura")
	return "%s consertado." % Armas.ARMADURA[a.id].nome

func consertar_arma(id: String) -> String:
	var c := {"sucata": 4}
	if not main.tem_itens(c) or not local_ok("oficina"):
		return "Precisa de 4 sucata e da oficina."
	main.gastar(c)
	main.equip.cond_armas[id] = 1.0
	main.trabalhar(0.75, "Afiando e consertando")
	return "%s afiado e consertado." % Armas.LISTA[id].nome

func tirar(slot: String) -> String:
	var a: Dictionary = main.equip.armadura.get(slot, {})
	if a.is_empty():
		return ""
	if main.adicionar(a.id, 1) <= 0:
		return "Sem espaço na carga."
	main.equip.armadura.erase(slot)
	main.jogador.atualizar_armadura(main.equip.armadura)
	return "Tirou: %s (o reforço de metal se perde ao guardar)." % Armas.ARMADURA[a.id].nome

# ------------------------------------------------------------ painel
func painel() -> Dictionary:
	var linhas: Array = []
	var botoes: Array = []
	var cinza := Color(0.7, 0.7, 0.68)
	var verm := Color(0.95, 0.45, 0.3)
	for par in [["sobrevivencia", "Sobrevivência"], ["couro", "Couro e armadura"], ["metal", "Metal e reparos"]]:
		var nome: String = ("▸ " if aba == par[0] else "") + par[1]
		botoes.append([nome, func(): aba = par[0]; return "", true])
	var est: Dictionary = main.estoque
	var mat := "Materiais: %d tecido · %d garrafa · %d pele · %d couro · %d corda · %d sucata · %d chapa · %d peças · diesel %d L" % [
		est.get("tecido", 0), est.get("garrafa", 0), est.get("pele", 0), est.get("couro", 0), est.get("cordame", 0),
		est.get("sucata", 0), est.get("chapa", 0), est.get("pecas", 0), int(main.comboio.diesel)]
	linhas.append([mat, Hud.DOURADO])
	for id in RECEITAS:
		var rc: Dictionary = RECEITAS[id]
		if rc.aba != aba:
			continue
		var txt := "%s — %s → %s, %s" % [rc.nome, main._txt_custo(rc.entra) + ((", %d L diesel" % int(rc.diesel)) if rc.has("diesel") else ""), main._txt_custo(rc.sai), main._txt_horas(rc.horas)]
		var ok_l := local_ok(rc.local)
		linhas.append([txt + ("" if ok_l or rc.local == "qualquer" else "  (" + NOMES_LOCAL[rc.local] + ")"), Color(0.92, 0.9, 0.86) if ok_l else cinza])
		botoes.append([rc.nome, fazer.bind(id, 1), pode(id)])
		if id in ["assar", "curtir", "chapa", "bandagem"] and vezes_max(id) > 1:
			var n := mini(vezes_max(id), 6)
			botoes.append(["%s ×%d" % [rc.nome, n], fazer.bind(id, n), pode(id, n)])
	if aba == "couro":
		linhas.append(["Vestido:", Hud.DOURADO])
		for slot in ["cabeca", "torso", "pernas", "bracos"]:
			var a: Dictionary = main.equip.armadura.get(slot, {})
			if a.is_empty():
				linhas.append(["  %s: nada" % NOMES_SLOT[slot], cinza])
			else:
				linhas.append("  %s: %s · reforço %d/3 · condição %d%%" % [NOMES_SLOT[slot], Armas.ARMADURA[a.id].nome, a.reforco, int(a.condicao * 100.0)])
		for id in Armas.ARMADURA:
			if est.get(id, 0) > 0:
				botoes.append(["Vestir %s" % Armas.ARMADURA[id].nome.to_lower(), main.equip.vestir.bind(id), true])
		linhas.append(["Defesa total: −%d%% de dano · mordida −%d%%" % [int(main.equip.defesa() * 100.0), int(main.equip.protecao_mordida() * 100.0)], Color(0.8, 0.7, 0.55)])
	if aba == "metal":
		var ok_of := local_ok("oficina")
		if not ok_of:
			linhas.append(["A forja fica na oficina móvel: engate uma e fique perto dela.", verm])
		for slot in main.equip.armadura:
			var a: Dictionary = main.equip.armadura[slot]
			var nome_p: String = Armas.ARMADURA[a.id].nome
			if a.reforco < 3:
				var c := custo_reforco(slot)
				linhas.append("Reforçar %s com chapas (nível %d → %d): %s, 2 h" % [nome_p.to_lower(), a.reforco, a.reforco + 1, main._txt_custo(c)])
				botoes.append(["Reforçar %s" % nome_p.to_lower(), reforcar.bind(slot), ok_of and main.tem_itens(c)])
			if a.condicao < 0.95:
				botoes.append(["Consertar %s (%d%%)" % [nome_p.to_lower(), int(a.condicao * 100.0)], consertar_armadura.bind(slot), main.estoque.get("couro", 0) > 0])
		for id in main.equip.cond_armas:
			if main.equip.cond_armas[id] < 0.95 and main.estoque.get(id, 0) > 0:
				botoes.append(["Consertar %s (%d%%)" % [Armas.LISTA[id].nome.to_lower(), int(main.equip.cond_armas[id] * 100.0)], consertar_arma.bind(id), ok_of and main.estoque.get("sucata", 0) >= 4])
		linhas.append(["Cada nível de reforço: −5% de dano e mais proteção contra mordida, mas pesa (cansa mais nos golpes).", cinza])
	return {"titulo": "CRIAÇÃO", "subtitulo": "Sobreviver é fazer com o que se tem.", "linhas": linhas, "botoes": botoes}
