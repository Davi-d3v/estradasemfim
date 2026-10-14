class_name Armas
## Dados de armas, consumíveis e armaduras (sem lógica).

## tipo "branca": dano por golpe, alcance em m, cad = segundos entre golpes, durab = golpes até quebrar (0 = não quebra).
## tipo "fogo": pente, munição, recarga (s), disp = dispersão (rad), projeteis por tiro, coice (rad de câmera).
const LISTA := {
	"facao": {"nome": "Facão", "tipo": "branca", "dano": [26.0, 38.0], "alcance": 2.1, "cad": 0.55, "ruido": 10.0, "empurrao": 6.0, "estamina": 0.06, "durab": 0},
	"pe_de_cabra": {"nome": "Pé de cabra", "tipo": "branca", "dano": [30.0, 42.0], "alcance": 2.2, "cad": 0.62, "ruido": 10.0, "empurrao": 7.0, "estamina": 0.07, "durab": 220},
	"taco": {"nome": "Taco com pregos", "tipo": "branca", "dano": [34.0, 50.0], "alcance": 2.4, "cad": 0.8, "ruido": 12.0, "empurrao": 11.0, "estamina": 0.09, "durab": 90},
	"machado": {"nome": "Machado", "tipo": "branca", "dano": [50.0, 72.0], "alcance": 2.3, "cad": 1.0, "ruido": 12.0, "empurrao": 8.0, "estamina": 0.11, "durab": 160},
	"pistola": {"nome": "Pistola 9 mm", "tipo": "fogo", "dano": [40.0, 58.0], "alcance": 38.0, "cad": 0.3, "pente": 12, "municao": "municao_pistola", "recarga": 1.4, "ruido": 48.0, "disp": 0.03, "projeteis": 1, "coice": 0.035, "zoom": 40.0},
	"espingarda": {"nome": "Espingarda 12", "tipo": "fogo", "dano": [16.0, 24.0], "alcance": 16.0, "cad": 0.95, "pente": 2, "municao": "cartucho", "recarga": 2.2, "ruido": 62.0, "disp": 0.1, "projeteis": 8, "coice": 0.09, "zoom": 44.0},
	"rifle": {"nome": "Rifle de caça", "tipo": "fogo", "dano": [95.0, 130.0], "alcance": 85.0, "cad": 1.25, "pente": 5, "municao": "municao_rifle", "recarga": 2.6, "ruido": 75.0, "disp": 0.008, "projeteis": 1, "coice": 0.06, "zoom": 26.0},
	"besta": {"nome": "Besta", "tipo": "fogo", "dano": [70.0, 95.0], "alcance": 45.0, "cad": 1.4, "pente": 1, "municao": "virote", "recarga": 1.6, "ruido": 4.0, "disp": 0.018, "projeteis": 1, "coice": 0.01, "zoom": 34.0},
}
const ORDEM := ["facao", "pe_de_cabra", "taco", "machado", "pistola", "espingarda", "rifle", "besta"]

## Consumíveis usados pela barra rápida (botão esquerdo com o item selecionado).
const CONSUMIVEIS := {
	"bandagem": {"vida": 0.22, "tempo": 2.0, "texto": "Bandagem aplicada."},
	"analgesico": {"vida": 0.08, "estamina": 1.0, "tempo": 0.5, "efeito": "analgesico", "texto": "Analgésico: a dor some por um tempo."},
	"remedio": {"infeccao": -0.6, "vida": 0.15, "tempo": 1.0, "texto": "Remédio tomado."},
	"comida": {"fome": 0.3, "tempo": 1.5, "texto": "Você comeu uma lata."},
	"agua": {"sede": 0.35, "tempo": 1.0, "texto": "Você bebeu água."},
	"carne_assada": {"fome": 0.45, "vida": 0.04, "tempo": 2.0, "texto": "Carne assada. Quentinha."},
	"carne_crua": {"fome": 0.18, "tempo": 2.0, "enjoo": 0.35, "texto": "Carne crua..."},
	"cafe": {"sede": 0.1, "tempo": 1.0, "texto": "Café quente e forte."},
	"sopa": {"fome": 0.35, "sede": 0.2, "vida": 0.05, "tempo": 1.8, "texto": "Sopa quente."},
	"ensopado": {"fome": 0.7, "vida": 0.12, "tempo": 2.5, "texto": "Ensopado de caça. Comida de verdade."},
	"antibiotico": {"vida": 0.05, "tempo": 0.6, "texto": "Antibiótico tomado."},
	"molotov": {"arremesso": true},
	"sinalizador": {"arremesso": true},
}
const ORDEM_CONSUMIVEIS := ["bandagem", "analgesico", "remedio", "antibiotico", "molotov", "sinalizador", "ensopado", "sopa", "cafe", "carne_assada", "comida", "agua", "carne_crua"]

## Peças de armadura: defesa base (fração do dano bloqueada) e proteção contra mordida.
## Reforço com chapas de metal: até 3 níveis, cada um soma defesa (e peso: estamina).
const ARMADURA := {
	"capuz_couro": {"nome": "Capuz de couro", "slot": "cabeca", "defesa": 0.06, "mordida": 0.15},
	"colete_couro": {"nome": "Colete de couro", "slot": "torso", "defesa": 0.14, "mordida": 0.3},
	"calca_couro": {"nome": "Calça de couro", "slot": "pernas", "defesa": 0.08, "mordida": 0.25},
	"bracadeiras": {"nome": "Braçadeiras de couro", "slot": "bracos", "defesa": 0.05, "mordida": 0.3},
}
const REFORCO_DEFESA := 0.05
