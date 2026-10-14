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
- [x] 3. Rádio, Zona Segura e marcos (scripts/progresso.gd + scripts/marcos.gd): marcos infinitos (Zona Segura km 40, Refinaria 95, Base Aérea 155,
  Usina 220, Porto Seco 290, depois a cada ~72 km) com muro de contêineres, torres, acampamento e gente; ao chegar escolhe prêmio (reboque nível 3,
  recruta especial ou conserto+suprimentos) e ganha uma peça do mistério; missões do rádio (depósito de diesel, hospital de campanha, comboio militar,
  pedido de socorro com prazo e cerco, sinal estranho) com marcador; 16 cartas/fitas do mistério (saque 6%, marcos, sinais) no diário [J];
  objetivo do HUD mostra próximo marco/missão; trechos de marco e missão sem prédios. Teste: --teste-progresso; prints: --progresso
- [x] 4. Combate com o comboio (scripts/combate_comboio.gd): zumbis se agarram na picape/trailer (até 5), batem na lataria, seguram o comboio (−7% cada)
  e alcançam o motorista pela janela; soltam com ziguezague, acima de 54 km/h ou freada brusca; módulos novos na oficina: Espinhos laterais e
  Posto de tiro (picape), Couraça (trailer: chapas, nível 2 com espinhos); vigia atira da caçamba gastando munição. Teste: --teste-comboio; prints: --comboio-combate
- [x] 5. Comércio, reputação e facções (scripts/comercio.gd): cada lugar tem o que sobra (×0,6) e o que falta (×1,7), preços sobem com a distância
  (diesel ainda mais); bancas da vila (mantimentos, peças/armas, remédios), comerciante nos assentamentos e no marco; crédito por lugar;
  estoque diário; pedidos ("me traga X") com prêmio; reputação Desconhecido/Conhecido/Amigo/Aliado (descontos, itens raros, presente diário;
  defender o assentamento = aliado); 4 facções por distância (Abutres, Irmandade do Asfalto, Carniceiros da BR, Reis do Sertão) que lembram:
  pagou 2× = passagem livre, furou/atirou 2× = pedágio em dobro. Teste: --teste-comercio; prints: --comercio
- [x] 6. Cachorro (scripts/cachorro.gd; modelos Husky e Shiba da Quaternius; latidos/ganido em gerar_sons.py): evento "NÃO ME DEIXE" (cedo, km ~0,8,
  e às vezes depois, se ainda não tiver cachorro); segue a pé, viaja na caçamba, late e avisa a direção de zumbis antes de você ver, fareja
  vasculháveis (e às vezes acha item extra), caça bicho ferido, defende de zumbi colado, foge ganindo se apanhar, pode morrer; [E] painel
  (ficar/seguir, dar comida); salvo no jogo. Teste: --teste-cachorro; prints: --cachorro
- [x] 7. Recrutas com vida (scripts/vida_recrutas.gd): 8 traços (corajoso, medroso, otimista, rabugento, trabalhador, preguiçoso, leal, ganancioso)
  que mudam a luta, a moral e o aprendizado; experiência e nível 1-5 na função (+15% por nível: cura, conserto, colheita, saque, dano, pontaria);
  relações (amizades, brigas por comida, briga feia que machuca), casais, quem tem moral no chão vai embora levando coisas (ganancioso leva arma;
  leal e criança ficam; o par às vezes vai junto); luto (par sofre muito) e túmulo com nome e dia na beira da estrada (salvo);
  funções novas: idoso (ensina, +25% de aprendizado, ajuda na horta e oficina) e criança (anima, acha coisas pequenas ao vasculhar, se esconde)
  — chegam pela carona e pelo ônibus tombado. Teste: --teste-vida; prints: --vida
- [x] 8. Comboio (scripts/comboio_extra.gd + reboques raros em reboque.gd): Hospital de campanha (km 40: cura acelerada, infecção, bandagens de tecido,
  leito de 3 h), Torre de rádio (km 55: mostra no mapa eventos, reboques e postos à frente até 2-5 km e a hora exata da horda), Destilaria (km 75:
  comida vira álcool combustível), Blindado com torreta (km 100: metralhadora automática que gasta munição de rifle); aparecem abandonados (30%
  depois do km) e como prêmio dos marcos; desgaste: motor perde condição com os km e engasga abaixo de 30%, pneus gastam e furam (muito mais na
  terra/mato) — pneu furado limita a 30 km/h e puxa a direção, troca com 1 pneu; cara do comboio: nome pintado no trailer, assinaturas dos
  recrutas veteranos, crânios de brutamonte no quebra-mato (até 4). Teste: --teste-reboques; prints: --reboques-raros
- [x] 9. Exploração (scripts/exploracao.gd + scripts/subsolo.gd): lugares grandes e raros, no máximo um por região a partir da 2ª — base militar
  (muro de chapas, torres, sede de 2 andares, hangar com caminhões, paiol trancado, bunker), presídio (muralha com arame, guaritas, 2 blocos de
  celas, almoxarifado e armaria trancados, zumbis de uniforme laranja) e shopping (estacionamento com carros, fachada e letreiro, farmácia,
  caça e pesca, supermercado, cofre trancado); trancas abrem com cartão militar / chaves do presídio / chave de cofre (achados em outros lugares)
  ou arrombando com pé de cabra (2 h, barulho que chama zumbis); porões (fazendas e cabanas) e bunkers em 1ª pessoa no escuro: sem lanterna
  é quase breu e algo pode morder, com lanterna dá para ver (itens novos: lanterna, binóculo); binóculo [Z]: zoom e marca no mapa os zumbis à
  vista por 1 minuto; pichações de sobreviventes na beira da estrada, algumas apontando um esconderijo de verdade no mato.
  Corrigido: o mundo seguia o comboio quando o jogador estava num subsolo. Teste: --teste-exploracao; prints: --exploracao
- [ ] 10-11. Recrutas, comboio, exploração, defesa, sobrevivência  - [ ] 12. v0.8

## Próximos
- seguir a rodada grande (etapa 10: defesa)
- ouvir o retorno do teste no PC do Davi
