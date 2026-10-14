# Estrada Sem Fim — jogo de sobrevivência zumbi (Godot 4.5)

Projeto do Davi. Textos do jogo e conversa em **português**. Ele quer ver **prints** (não executáveis).

## Ideia
- 3ª pessoa (1ª pessoa dentro do trailer/reboques/picape). Apocalipse zumbi; tudo que você tem é a picape e o trailer.
- Base móvel: picape → trailer (módulos que melhoram e quebram) → reboques extras (apartamentos, oficina, estufa, armazém…), achados ou construídos; difícil conseguir.
- Estrada procedural infinita (chunks de 64 m, regiões/biomas), vilas e assentamentos com vendedores e sobreviventes, florestas densas com saque, prédios com andares.
- Recrutas no reboque de apartamentos ajudam na defesa e automatizam tarefas.
- Dois modos: viagem pela estrada e defesa de assentamento (ondas infinitas da horda).
- Sobrevivência: fome/sede/infecção, caça (veado, javali, capivara, lobo), esfolar, curtir couro, armadura de couro, refinar metal na forja da oficina, criação (tecla B).
- Clima de apocalipse (carros abandonados, fumaça, barricadas, cartazes).

## Estrutura
- `scripts/main.gd` — jogo, HUD, interações, capturas de print (`--capturar`, flags extras), testes (`--teste`, `--teste-armas`, `--teste-recrutas`, `--teste-defesa`, `--teste-eventos`, `--teste-salvar`).
- `scripts/world_gen.gd` mundo/estrada/vegetação; `lugares.gd` vilas e assentamentos; `predio.gd` prédios; `floresta.gd`; `apocalipse.gd`.
- `trailer.gd`, `pickup.gd`, `reboque.gd`, `comboio.gd`, `oficina.gd`.
- `humanoid.gd` (corpo), `player.gd`, `zumbi.gd`, `recruta.gd`, `animal.gd`, `equipamento.gd`, `armas.gd`, `criacao.gd`, `defesa.gd`, `assentamento.gd`, `eventos.gd` (eventos na estrada), `horda_visivel.gd`, `retrovisor.gd`, `vida_recrutas.gd`, `comboio_extra.gd`, `exploracao.gd`, `subsolo.gd`, `cachorro.gd`, `salvar.gd`, `som.gd`.
- `assets/` modelos CC0 (Quaternius: personagens com rosto + zumbis, Universal Animation Library, animais, armas; Kenney: ferramentas). Créditos em `assets/LEIA-ME.txt` e `assets/licencas/`.

## Como rodar (sem GPU)
- `./check.sh` compila/importa; `./capturar.sh [flags]` gera prints em `prints/` (xvfb + gl_compatibility).
- Godot esperado em `../godot/godot` (4.5.1).
- `./backup.sh` gera .zip do projeto.

## Rodada atual / próximos passos
Ver `PROGRESSO.md`.
