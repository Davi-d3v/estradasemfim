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
- [x] 10. Defesa: o líder mostra os 4 setores do muro (e de onde a horda vem) e você escolhe o que construir em cada um — torre, holofote,
  estacas, fosso (os moradores cavam, gasta comida e água; quem atravessa fica a passo de tartaruga e cai; passagem de tábuas no portão) e
  arame farpado (colado no muro, corta e prende, 40 cargas); onda noturna (+25% e mais corredores); a cada 3 ondas um chefe — o Colosso
  (zumbi gigante, 800 de vida, derruba muro 5× mais rápido) com barra no HUD e aviso do líder antes; vencer o chefe rende munição e chapas;
  consequências: aliados mandam caravanas com mantimentos e às vezes um morador como recruta; quando a horda volta a passar, o aliado
  resiste conforme o nível do que você construiu — ou cai, e você ouve pelo rádio. Teste: --teste-defesa2; prints: --defesa2
- [x] 11. Sobrevivência (scripts/saude.gd): sono (barra roxa; ~22 h acordado até exausto; exausto a estamina cai e, dirigindo, você cochila —
  a tela escurece e a picape sai da pista); doenças: gripe (dormir sem abrigo/na chuva, tomar chuva; estamina até 60% e tosse que os zumbis
  ouvem), intoxicação (lata vencida às vezes, carne crua 1 em 3), ferida aberta (mordida/arranhão: curativo em 6 h ou inflama e só antibiótico
  resolve); cozinha na fogueira: café (tira o sono), sopa (ajuda na gripe e intoxicação), ensopado de caça (comida forte); itens novos:
  antibiótico (farmácias, banheiros, almoxarifado), pó de café; hospital de campanha trata tudo; doenças no HUD; salvo no jogo.
  Teste: --teste-saude; prints: --saude
- [x] 12. Versão v0.8 para Windows (recrutas, comboio, exploração, defesa, sobrevivência)

## Rodada v0.9 (retorno do Davi sobre a v0.7)
- [x] Engasgo ao carregar o mapa: grade de altura por trecho + geração em etapas (~6 ms por quadro). Teste --fluidez: 0 quadros > 100 ms a 90 km/h.
- [x] Mouse vertical estava invertido: corrigido.
- [x] Física dos veículos: picape, trailer e reboques bloqueiam zumbis e jogador (caixas orientadas em WorldGen.colide); zumbis contornam.
- [x] Acampamento [C] (scripts/acampamento.gd): cerca grande (8,5 m de folga nas laterais, 7,5 m nas pontas) com colisão;
  portão por onde só você, recrutas e cachorro passam; fogueira com tripé, lenha e luz tremulando; cadeiras em roda (uma por recruta,
  mínimo 4) — médico, batedor e idoso sentam o dia todo, os outros depois das 17 h; conversam (Sitting_Talking/Nodding/Idle).
- [x] Interações em segundos: nada mais pula horas. Barra de progresso (vasculhar 2–3 s, esfolar 4 s, desmontar carro 11 s,
  criação/consertos/obras 2–12 s); andar cancela vasculhar/esfolar/desmontar; o relógio corre normal. Dormir e "esperar a horda"
  continuam passando o tempo. Trabalhar à noite fora do trailer faz barulho.
  Teste: --teste-fisica; prints: --acampamento
- [x] v0.9 para Windows (branch versoes: EstradaSemFim_Windows_v0.9.zip)

## Rodada v0.10 (refino visual, retorno do Davi sobre a v0.9)
- [x] Pulo [Espaço a pé] com animação e fôlego.
- [x] "Modelos pretos" na estrada: sacos de corpos viraram vinil cinza com zíper, cabeça e pés, no acostamento, com cones;
  manchas no asfalto com borda irregular; vultos da horda somem perto (pontilhado < 70 m).
- [x] Fogo de partículas (scripts/fogo.gd): chamas em 2 camadas, brasas, fumaça, carvão pulsando; lenha em pirâmide, pedras com fuligem.
- [x] Portão do acampamento: mourões com ponta, trave com placa pendurada por correntes, folha com travessa em Z que abre sozinha.
- [x] Casas: shader com relevo procedural (rejunte, frestas, telhas coloniais), reboco caindo com tijolo baiano, barro e escorridos.
- [x] Cabine da picape: ponteiros, odômetro, pedais, maçanetas, capa de bolinhas, cinto, rack de espingarda, trinca no vidro, luz.
- [x] Trailer: colcha de retalhos, cortinas, tapete, prateleira, lampião, varal, casaco, fotos, calendário, galão, botas.
  Prints: --refino [--so=casa|fogo|cabine|trailer|pulo|sacos|horda]
- [x] v0.10 para Windows

## Rodada v0.11 (texturas reais do ambientCG enviadas pelo Davi)
- [x] assets/texturas: tijolo, reboco (com massa caída controlada por área), telha e telha velha (casas abandonadas),
  concreto, metal, asfalto (pista inteira com faixa amarela; bordas viram brancas). Shader superficie.gdshader com
  cor+normal+rugosidade projetadas no espaço do objeto (telhas acompanham a casa); road.gdshader idem.
- [x] Pichações (scripts/grafite.gd): 16 tags do GraffitiSet001 coladas nas casas e nas barreiras de quarentena.
- [x] Frutas, pães e toco escaneados foram testados e retirados (o Davi achou estranho no jogo).
- [x] Escritas (Label3D) nas paredes das casas trocadas por pichações do GraffitiSet (80% das casas, 1 a 3 cada).
  Prints: --refino --so=casa|sacos ; antes/depois em prints/antes_depois_*.png
- [x] v0.13 para Windows: pichações só em pano de parede inteiro (Predio._panos_livres), do tamanho que cabe, fora da frente

## Rodada v0.14 (pacotes do Davi: SBS Tiny Texture Pack 2 e KayKit RPG Tools Bits)
- [x] Madeira (tábuas, portas, venezianas, móveis, piso) e piso de cerâmica com as texturas SBS; normal/rugosidade geradas.
  O .rar só abriu em parte (89 de 170 arquivos vieram sem compressão; não há descompactador de RAR aqui).
- [x] KayKit (scripts/kit.gd): ferramentas na bancada e no painel da oficina, bigorna e tenaz; galpão das vilas com rebolo,
  bigorna, serrote, pá e picareta; trailer com caderno aberto, mapa enrolado e corda; acampamento com cepo e machado,
  balde e lampião. Prints: --refino --so=kit
- [x] v0.14 para Windows

## Rodada v0.15 (plantas da Poly Haven enviadas pelo Davi)
- [x] Conversor de .blend sem Blender (tools/blend_para_obj.py: zstd/gzip, SDNA, malhas antigas e novas) e
  tools/montar_plantas.gd (materiais com recorte de folha, LOD automático).
- [x] Plantas.trecho (scripts/plantas.gd): samambaias na mata, tufos de capim verde/seco na beira da estrada,
  tronco caído com folhas secas; 30% das árvores viram pinheiros; vasos de planta de verdade nos quintais.
  Prints: --refino --so=plantas
- [x] v0.15 para Windows

## Rodada v0.16 (só árvores com modelo)
- [x] Árvores feitas em código saíram: mata, beira da estrada e vilas usam só modelos da Poly Haven (Floresta.MODELOS):
  abeto (fir_tree_01) como árvore principal, pachira ampliada como árvore de copa, pinheirinhos e arbustos (didelta).
  tools/reduzir_arvore.py sorteia pedaços inteiros da folhagem (milhões de triângulos -> ~5-7 mil) e amplia um pouco
  cada pedaço; Godot gera os níveis de detalhe. Fluidez: 0 quadros > 100 ms.
- [x] v0.16 para Windows

## Rodada v0.17 (armas e objetos do Sketchfab enviados pelo Davi)
- [x] Armas com modelo detalhado (scripts/armas_hd.gd normaliza cada .glb: cano +X, origem na empunhadura):
  Pistola 1911, Rifle Kar98k, e novas: Carabina Saiga-9, Fuzil ACR (automático), Fuzil bullpup (automático),
  Dragunov (precisão, zoom), Protótipo (automático, silencioso); munição de fuzil 5,56. Loot militar/armaria.
- [x] Pegada de duas mãos (scripts/pegada_arma.gd, IK de dois ossos por cima da animação): coronha no ombro,
  mão esquerda no guarda-mão, tronco de lado e cabeça na mira; arma baixa ao andar. tools/ver_pegada.gd.
- [x] Objetos (scripts/props.gd, catálogo com tamanho real): cozinha (pia, fogareiro, botijão, panelas, latas),
  estante de ferro, sofá, poltronas, cadeiras, cômodas, estante de livros, abajur, jornais, cinzeiros, dinheiro,
  plantas da estufa, mobiliário de rua (ponto de ônibus, bancos, caçamba, hidrante). Pacotes com muitas peças são
  juntados por material. Casas mobiliadas com eles; acampamento com fogareiro e às vezes casa móvel (Trailer Park);
  vila com bancos, ponto de ônibus, hidrante e caçamba; dinheiro ao lado do cofre do shopping; estufa com mudas.
- [x] Carros com modelo na estrada (Punto, viatura, carro velho enferrujado) — metade dos carros não queimados.
- [x] Muro de carros amassados (scan de 2,5 milhões de triângulos reduzido por tools/reduzir_scan.py) no ferro-velho
  e nas barreiras de quarentena. Prints: --objetos; folha de contato: tools/ver_props.gd.
- Licenças: Dragunov, carro enferrujado e dinheiro russo são CC-BY-NC (não comercial); bullpup e City Props são
  Sketchfab Padrão e ficam fora do repositório (assets/sketchfab_padrao/), só no jogo exportado.

## Rodada v0.18 (protagonista novo e NPCs por profissão)
- [x] Protagonista = "post apo character" (sobrevivente de capuz e máscara de gás, enviado pelo Davi). A malha
  estática (925 mil triângulos, sem ossos) foi simplificada com gltfpack (45 mil) e ligada ao esqueleto da UAL por
  tools/rigar_personagem.gd: braços do esqueleto dobrados até a pose A da malha, pesos automáticos por distância
  aos ossos (sem misturar pernas/braços com o tronco). Todas as animações e a pegada de duas mãos valem.
- [x] NPCs vestidos peça por peça (camponês/patrulheiro da Quaternius, cada peça com cor própria) e detalhes por
  profissão: médico (jaleco branco, máscara, estetoscópio, braçadeira da cruz vermelha, maleta), armeiro (avental
  de couro, bandoleira de munição, óculos de proteção, coldre), agricultor (chapéu de palha, lenço, suspensórios,
  luvas), mecânico (macacão azul, cinto de ferramentas, pano de graxa), vigia (farda, capacete, colete tático,
  rádio), batedor (capuz, lenço no rosto, faca, cantil), líder (casaco com ombreira, cachecol, chapéu),
  vendedor (avental e bolsa), cozinheiro (avental e touca), idoso (cardigã, óculos).
- [x] Armeiro novo: banca de armas e munição nas vilas e nos assentamentos (fuzis raros pedem reputação).
  Ferramentas: tools/ver_personagens.gd (folha de papéis), prints --objetos --so=jogador,bancas.

## Próximos
- ouvir o retorno do Davi sobre a v0.9
