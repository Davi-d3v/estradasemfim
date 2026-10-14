# Progresso

## 13/10 — restaurado do zip (rodada de 13/10 01:51) e refeito
- [x] Personagens realistas com rosto: Quaternius Universal Base Characters + roupa modular (scripts/personagem_u.gd), animados direto pela UAL (mesmo esqueleto)
- [x] Zumbis: mesmos corpos, pele pálida, sangue; animações Zombie_* / Crawl / Death01-02 / Hit_*
- [x] Animações de combate e ações: golpes (Sword_*), tiro com coice e tremor, recarga, comer/beber/enfaixar, arremesso; dano sai no meio do golpe; sangue (scripts/sangue.gd)
- [x] Armas de fogo em modelo pronto (Quaternius, descomprimidas de meshopt) presas no osso da mão; mochila proporcional
- [x] Animais animados (veado, cervo, lobo) — lobo novo e agressivo
- [x] Trailer: despensa de 4 portinholas, caixa de ferramentas e bagageiro viraram inventário (E abre, painel por compartimento)
- [x] Vila/assentamento: rua de paralelepípedo com meio-fio e calçada, igreja detalhada com cemitério, parquinho, torres de vigia internas, horta com espantalho, galinheiro, cisterna, árvores, bancos, lenha, lixo (scripts/vila_extra.gd)

## 13/10 noite — versão de teste v0.6 (Windows)
- [x] Javali e capivara com modelo (porco Quaternius recolorido; javali com presas e crina)
- [x] Noite com luar mais claro
- [x] Lâmina das armas brancas no sentido dos golpes; espingarda/rifle nas costas quando não estão em uso
- [x] Tutorial (scripts/tutorial.gd): 11 passos que completam sozinhos; F1 reabre; salvo em user://config.cfg
- [x] Export Windows: ../build/windows/EstradaSemFim.exe (templates 4.5.1 em ~/.local/share/godot/export_templates)

## 14/10 — rodada "salvar, som, eventos, horda" (nessa ordem)
- [x] 1. Salvar e carregar (scripts/salvar.gd): F5, autosave a cada 10 min, ao dormir e ao fechar; "Continuar" no menu; save anterior preservado
- [x] 2. Som (scripts/som.gd + tools/gerar_sons.py + assets/sons/kenney): tiros, golpes, zumbis, passos por superfície, motor pela velocidade, vento/grilos/rádio/uivo
- [x] 3. Eventos na estrada (scripts/eventos.gd), ~6% dos trechos depois do km 0,2:
  - saqueadores: bloqueio com PEDÁGIO (pagar / furar / desvio de 3 h / atirar primeiro); bloqueia de verdade até resolver, depois os carros vão para o acostamento
  - carona: pessoa com placa AJUDA (vira recruta, 22% é isca e roubam a caçamba / dar comida e ouvir dica / seguir)
  - acidente: ônibus tombado (procurar sobreviventes: recruta ferido + remédios ou 6 zumbis / saquear malas / seguir)
  - comboio militar: caminhões com carga "militar" para vasculhar, arame farpado e zumbis fardados
  - resultado salvo em mundo.eventos_feitos; teste: --teste-eventos; prints: ./capturar.sh --eventos
- [x] 4. Horda visível (scripts/horda_visivel.gd + scripts/retrovisor.gd):
  - 1200 vultos animados (MultiMesh + shader de passada) na estrada e nos campos, a partir de 1,6 km; nuvem de poeira escura por cima (sem névoa, aparece de longe)
  - coro de gemidos (assets/sons/horda.ogg, gerado em tools/gerar_sons.py) que cresce com a proximidade
  - mundo mantém até 6 trechos extras atrás (WorldGen.atras_extra) para a horda não andar no vazio
  - retrovisor do lado do motorista no alto da tela enquanto dirige
  - prints: ./capturar.sh --horda (e --horda --alto, vista de cima)

## 14/10 — rodada grande (12 etapas, nessa ordem)
- [x] 1. Dificuldade pela distância: WorldGen.perigo(z) (km/6 + assentamentos defendidos) e 6 faixas (FAIXAS) com aviso na tela;
  tipos de zumbi liberados por faixa (gritador 5 km, brutamonte 15 km, blindado 30 km), mais corredores à noite, mais zumbis por trecho e cidades tomadas;
  zumbi blindado (capacete + colete, segura tiro fraco); ninhos (scripts/ninho.gd) que soltam zumbis até serem queimados (molotov ou galão);
  diesel raro longe (fartura_diesel: postos e galões); horda acelera com a distância. Teste: --teste-perigo; prints: --perigo
- [x] 2. Clima e noite (scripts/clima.gd): estados limpo/nublado/chuva/tempestade/neblina/neve, estações de 10 dias (neve só no inverno);
  partículas, céu fechado, névoa, relâmpago + trovão, asfalto molhado com poças e neve no chão (shaders road/terrain/grass), vento forte na tempestade;
  pista lisa (Comboio.aderencia_clima: curva, freio e derrapagem), zumbis enxergam/escutam menos, horda +45% na tempestade, fome maior no inverno;
  faróis da picape (acendem sozinhos) que atraem zumbis à frente à noite; tempo/estação no HUD; salvo no jogo. Teste: --teste-clima; prints: --clima
- [ ] 3. Rádio/Zona Segura/marcos  - [ ] 4. Combate com o comboio  - [ ] 5. Comércio/reputação/facções
- [ ] 6. Cachorro  - [ ] 7-11. Recrutas, comboio, exploração, defesa, sobrevivência  - [ ] 12. v0.8

## Próximos
- seguir a rodada grande (etapa 3: rádio, Zona Segura e marcos)
- ouvir o retorno do teste no PC do Davi
