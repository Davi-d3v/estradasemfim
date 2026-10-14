class_name Regioes
extends RefCounted
## Divide a estrada infinita em regiões (15 a 25 km), cada uma com bioma, nome,
## lugares no fim de estradas de terra e um marco que bloqueia a passagem no final.
## Tudo é determinístico a partir da semente.

const BIOMAS := {
	"rural": {"baixa": 0.0, "nome": "Interior", "morro": 14.0, "curva": 1.0, "elev": 1.0, "nevoa": 0.0028,
		"seco": Color(0.36, 0.31, 0.17), "verde": Color(0.16, 0.19, 0.08), "capim": 1.0, "arvores": 1.0,
		"capim_cor": Color(1.0, 0.95, 0.85), "nevoa_cor": Color(0.55, 0.33, 0.35)},
	"serra": {"baixa": 0.0, "nome": "Serra", "morro": 38.0, "curva": 1.7, "elev": 3.2, "nevoa": 0.0065,
		"seco": Color(0.24, 0.27, 0.15), "verde": Color(0.1, 0.16, 0.08), "capim": 0.8, "arvores": 2.4,
		"capim_cor": Color(0.75, 0.95, 0.7), "nevoa_cor": Color(0.5, 0.52, 0.58)},
	"cidade": {"baixa": 0.0, "nome": "Cidade", "morro": 5.0, "curva": 0.5, "elev": 0.4, "nevoa": 0.0045,
		"seco": Color(0.33, 0.3, 0.22), "verde": Color(0.2, 0.2, 0.12), "capim": 0.45, "arvores": 0.3,
		"capim_cor": Color(0.95, 0.9, 0.75), "nevoa_cor": Color(0.5, 0.42, 0.4)},
	"industrial": {"baixa": 0.0, "nome": "Polo industrial", "morro": 4.0, "curva": 0.4, "elev": 0.3, "nevoa": 0.005,
		"seco": Color(0.3, 0.28, 0.22), "verde": Color(0.18, 0.18, 0.12), "capim": 0.55, "arvores": 0.25,
		"capim_cor": Color(0.85, 0.82, 0.7), "nevoa_cor": Color(0.48, 0.45, 0.42)},
	"alagado": {"baixa": -1.6, "nome": "Várzea alagada", "morro": 3.0, "curva": 0.8, "elev": 0.25, "nevoa": 0.0055,
		"seco": Color(0.26, 0.28, 0.16), "verde": Color(0.12, 0.17, 0.09), "capim": 1.1, "arvores": 0.5,
		"capim_cor": Color(0.7, 0.9, 0.6), "nevoa_cor": Color(0.45, 0.5, 0.5)},
}

## Nomes próprios para dar identidade às regiões e aos lugares.
const NOMES_REGIAO := {
	"rural": ["Campos Gerais", "Vale do Ivaí", "Planalto Seco", "Terra Roxa", "Campo Largo"],
	"serra": ["Serra do Mar", "Serra da Esperança", "Serra Negra", "Morro do Frio"],
	"cidade": ["Ponta Grossa", "Nova Aurora", "Cidade Baixa", "São Mateus"],
	"industrial": ["Distrito Industrial", "Polo Petroquímico", "Cinturão das Fábricas"],
	"alagado": ["Várzea do Iguaçu", "Banhado Grande", "Pantanal do Sul"],
}
const NOMES_VILA := ["Esperança", "São Jorge", "Recanto", "Boa Vista", "Santa Luzia", "Porto Novo", "Cruzeiro",
	"Água Clara", "Bom Retiro", "Pedra Branca", "Três Barras", "Alvorada"]
const NOMES_FAZENDA := ["Santa Rita", "Três Irmãos", "Boa Sorte", "São Pedro", "Lagoa Seca", "Vista Alegre"]
const NOMES_BASE := ["Quartel do 12º BI", "Base de Apoio Logístico", "Quartel do 5º BEC", "Base Militar Serra Alta"]
const NOMES_PRESIDIO := ["Presídio Estadual de Itaúna", "Penitenciária do Vale", "Cadeia Pública de Ouro Branco"]
const NOMES_SHOPPING := ["Shopping Rodovia", "Shopping Vale Verde", "Center Norte", "Shopping das Águas"]
const NOMES_FERRO := ["Ferro-velho do Tião", "Sucatão Central", "Desmanche Rota 116", "Auto Peças Zé"]
const NOMES_ASSENT := ["Assentamento Nova Canaã", "Refúgio São Miguel", "Comunidade Pedra Branca", "Forte Boa Esperança",
	"Assentamento Rio Claro", "Colônia Santa Fé", "Reduto do Vale", "Assentamento Terra Firme", "Refúgio Bela Vista"]

## Lugares que aparecem no fim das estradas de terra, por bioma (pesos).
const LUGARES := {
	"rural": {"vila": 3, "fazenda": 4, "ferro_velho": 2},
	"serra": {"vila": 3, "fazenda": 2, "ferro_velho": 1},
	"cidade": {"vila": 2, "fazenda": 0, "ferro_velho": 3},
	"industrial": {"vila": 1, "fazenda": 0, "ferro_velho": 4},
	"alagado": {"vila": 2, "fazenda": 3, "ferro_velho": 1},
}
const ORDEM_BIOMAS := ["rural", "serra", "cidade", "industrial", "alagado"]
const MIX := 400.0   # metros de transição entre biomas

var semente := 0
var _limites: Array[float] = [-2000.0]   # início de cada região
var _biomas: Array[String] = []
var _nomes: Array[String] = []

func _init(s: int) -> void:
	semente = s

func _rng(i: int, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([semente, i, salt, "regiao"])
	return r

func _garantir(i: int) -> void:
	while _biomas.size() <= i:
		var n := _biomas.size()
		var r := _rng(n, 1)
		var b := "rural"
		if n > 0:
			var opcoes: Array = ORDEM_BIOMAS.filter(func(x): return x != _biomas[n - 1])
			b = opcoes[r.randi() % opcoes.size()]
		_biomas.append(b)
		var lista: Array = NOMES_REGIAO[b]
		_nomes.append(lista[r.randi() % lista.size()])
		var comp := r.randf_range(15000.0, 25000.0)
		if n == 0:
			comp = 2000.0 + 16000.0   # a primeira começa antes da origem
		_limites.append(_limites[n] + comp)

func indice(z: float) -> int:
	if z < _limites[0]:
		return 0
	_garantir(0)
	while _limites[_limites.size() - 1] <= z:
		_garantir(_biomas.size())
	# busca binária
	var lo := 0
	var hi := _biomas.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if _limites[mid] <= z:
			lo = mid
		else:
			hi = mid - 1
	return lo

func inicio(i: int) -> float:
	_garantir(i)
	return _limites[i]

func fim(i: int) -> float:
	_garantir(i)
	return _limites[i + 1]

func bioma(i: int) -> String:
	_garantir(i)
	return _biomas[i]

func nome(i: int) -> String:
	_garantir(i)
	return _nomes[i]

func info_bioma(i: int) -> Dictionary:
	return BIOMAS[bioma(i)]

## Mistura de dois biomas perto da fronteira: {a, b, t}.
func mistura(z: float) -> Array:
	var i := indice(z)
	var a := bioma(i)
	var dfim := fim(i) - z
	if dfim < MIX:
		return [a, bioma(i + 1), 0.5 - 0.5 * dfim / MIX]
	var dini := z - inicio(i)
	if i > 0 and dini < MIX:
		return [bioma(i - 1), a, 0.5 + 0.5 * dini / MIX]
	return [a, a, 0.0]

func param(z: float, chave: String) -> float:
	var m := mistura(z)
	return lerpf(float(BIOMAS[m[0]][chave]), float(BIOMAS[m[1]][chave]), smoothstep(0.0, 1.0, m[2]))

func cor(z: float, chave: String) -> Color:
	var m := mistura(z)
	return (BIOMAS[m[0]][chave] as Color).lerp(BIOMAS[m[1]][chave], smoothstep(0.0, 1.0, m[2]))

## Marco no fim da região: o que bloqueia a estrada principal.
func marco(i: int) -> Dictionary:
	var r := _rng(i, 2)
	var tipo := "barreira" if r.randf() < 0.5 else "ponte"
	if i == 0:
		tipo = "barreira"
	return {"tipo": tipo, "z": fim(i) - 250.0, "lado": 1.0 if r.randf() < 0.5 else -1.0}

## Entradas para estradas de terra ao longo da região (sem o caminho, que depende do terreno).
func juncoes(i: int) -> Array:
	var r := _rng(i, 3)
	var lista: Array = []
	var b := bioma(i)
	var z := inicio(i) + r.randf_range(1200.0, 2200.0)
	if i == 0:
		z = 420.0    # a primeira fica logo no começo do jogo
	var limite: float = float(marco(i).z) - 900.0
	var n := 0
	var teve_grande := false
	while z < limite:
		var tipo := _sortear(r, LUGARES[b])
		# lugares grandes e raros: só a partir de certa região, e de vez em quando
		var grande := r.randf()
		if i >= 1 and grande < 0.2 and not teve_grande:
			var op: Array = []
			if b in ["rural", "serra", "industrial", "alagado"]:
				op.append("base_militar")
			if i >= 2 and b in ["rural", "industrial", "serra"]:
				op.append("presidio")
			if b in ["cidade", "industrial"]:
				op.append("shopping")
			if not op.is_empty():
				tipo = op[r.randi() % op.size()]
				teve_grande = true
		var nome_lugar := ""
		match tipo:
			"vila":
				nome_lugar = "Vila " + NOMES_VILA[r.randi() % NOMES_VILA.size()]
			"fazenda":
				nome_lugar = "Fazenda " + NOMES_FAZENDA[r.randi() % NOMES_FAZENDA.size()]
			"ferro_velho":
				nome_lugar = NOMES_FERRO[r.randi() % NOMES_FERRO.size()]
			"base_militar":
				nome_lugar = NOMES_BASE[r.randi() % NOMES_BASE.size()]
			"presidio":
				nome_lugar = NOMES_PRESIDIO[r.randi() % NOMES_PRESIDIO.size()]
			"shopping":
				nome_lugar = NOMES_SHOPPING[r.randi() % NOMES_SHOPPING.size()]
		if i == 0 and n == 0:
			tipo = "fazenda"
			nome_lugar = "Fazenda Santa Rita"
		lista.append({"id": "%d:%d" % [i, n], "regiao": i, "z": z, "lado": 1.0 if r.randf() < 0.5 else -1.0,
			"tipo": tipo, "nome": nome_lugar, "avanco": r.randf_range(140.0, 260.0), "afast": r.randf_range(95.0, 150.0),
			"curva": r.randf_range(-25.0, 25.0), "semente": r.randi()})
		n += 1
		z += r.randf_range(900.0, 1900.0)
	# um assentamento por região, perto do fim (antes do marco); na primeira, logo no começo
	var ra := _rng(i, 9)
	var za: float = float(marco(i).z) - ra.randf_range(1400.0, 2100.0)
	if i == 0:
		za = 2300.0
	lista = lista.filter(func(jj): return absf(float(jj.z) - za) > 700.0)
	lista.append({"id": "%d:a" % i, "regiao": i, "z": za, "lado": 1.0 if ra.randf() < 0.5 else -1.0,
		"tipo": "assentamento", "nome": NOMES_ASSENT[(ra.randi() + i) % NOMES_ASSENT.size()],
		"avanco": ra.randf_range(120.0, 180.0), "afast": ra.randf_range(120.0, 150.0),
		"curva": ra.randf_range(-15.0, 15.0), "semente": ra.randi()})
	lista.sort_custom(func(a, b): return a.z < b.z)
	return lista

func _sortear(r: RandomNumberGenerator, pesos: Dictionary) -> String:
	var total := 0
	for k in pesos:
		total += pesos[k]
	var x := r.randi_range(1, maxi(total, 1))
	for k in pesos:
		x -= pesos[k]
		if x <= 0:
			return k
	return pesos.keys()[0]
