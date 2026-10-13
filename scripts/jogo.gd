class_name Jogo
## Estado que sobrevive ao recarregar a cena (novo jogo, modo escolhido).

const MODO_TOTAL := "total"        # morreu: tudo recomeça do zero
const MODO_INFINITO := "infinito"  # morreu: penalidades pesadas, mas continua

static var modo := ""
static var semente := 2026
static var mortes := 0
