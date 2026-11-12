# Redesenho imersivo para o pad

## Direção aplicada

- Base em gradiente de Leonida: ameixa, lavanda, coral e rosa, com paisagens
  discretas fundidas à composição e personagens/objetos nas laterais.
- Removido todo o paralaxe de mouse. Movimento sutil pela seleção dos jogos e
  animação ambiente; respeita redução de animações e pausa fora de primeiro plano.
- Personagens ancorados à borda inferior, sem deslocamento vertical, mantendo
  o tamanho e a resolução nativa das artes, com filtragem de alta qualidade.
- Controles de janela transparentes neste tema; sem a etiqueta de versão.
- Botões com brilho em gradiente e linha de foco, sem os antigos blocos chapados.
- Jogos em ícones nativos de 36 px, sem fundo de caixa. O serviço existente
  resolve EXE, ICO, atalhos LNK/URL e Shell; falhas usam um símbolo discreto.
- Cache e limite de concorrência da extração ficam no GameArtworkService.
- Navegação horizontal da biblioteca centraliza o ícone e só restaura foco se
  a ação ainda for atual, sem roubar o foco após entrar em outra seção.

## Conteúdo na página inicial

- Vice Feed: miniatura real do vídeo e prévia muda após 750 ms de foco estável.
  Cada visita/retorno sorteia uma consulta diferente, alternando GTA VI/GTA 6 e
  notícias, highlights, gameplay, funny, curiosidades e exploração. A busca é
  renovada e a seleção evita repetir imediatamente o mesmo vídeo quando possível.
- Leonida Wire: manchete real com paisagem local fixa de Leonida Keys. A busca
  de notícias mantém o fluxo normal; não depende de imagens remotas das matérias.
- Nas duas prévias, a imagem desaparece até a metade do card e o texto começa
  25% mais à direita em relação à composição anterior, com sombreamento suave.
- A confirma a entrada na seção dedicada. As duas prévias compartilham cache
  e requisições com as respectivas seções, evitando consultas duplicadas.
- A prévia para ao perder foco, trocar de seção, abrir menus ou perder atividade.

## Vice Feed

Temas ilustrados: Em cartaz, Pelas ruas, Só em Leonida, Pelo paraíso,
Suas histórias e Sem roteiro. Consultas direcionadas a trailers, veículos,
animais/curiosidades, lugares, personagens e gameplay/análises.

Em telas largas, imagem grande e ação à esquerda, lista editorial à direita.
O destaque acompanha o foco com um atraso de 180 ms e transição suave da imagem.
Em telas menores, a lista assume o espaço principal. Confirmar abre o player;
B retorna à mesma lista, preservando rolagem e foco quando o item está montado.

## Leonida Wire

Temas ilustrados: Destaques, Rockstar, Pelo mapa, Nas ruas e Só em Leonida.
Cada tema muda a consulta; a fonte real continua visível em cada matéria.
O tema Rockstar é uma consulta por assunto, não certificação de fonte oficial.

Esta seção usa somente textos, incluindo tópicos, lista, destaque e leitura.
Leitura integrada à seção, com título, fonte, data, resumo e ação de
abrir a matéria completa. B retorna à lista, sem um popup genérico de notícias.

## Navegação e categorias

- Abas superiores fora do percurso direcional: L1/R1 (LB/RB), Q/E ou clique.
  A aba selecionada é revelada pela rolagem do cabeçalho, sem receber o foco.
- Setas/direcional percorrem biblioteca, sugestões, tópicos, resultados e ações.
  Cima sai da biblioteca para as sugestões ou para os resultados da seção;
  baixo nas sugestões ou no último resultado retorna à biblioteca.
- Navegação de resultados revela itens ainda fora da área visível e cancela
  pedidos de foco antigos ao trocar de seção. Notícias permitem rolagem pelo pad.
- Cinema, Música e Loja usam cards uniformes preenchidos pela imagem em cover
  e bordas de 4 px. O nome aparece somente no item em foco, abaixo da imagem;
  a legenda tem espaço reservado para a grade não mudar de posição.
- START usa o menu Mais padrão. O controlador solicita explicitamente um frame
  para abrir o menu mesmo em abas estáticas, sem depender da animação de Jogos.

## Materiais novos

Referências pesquisadas nas páginas oficiais:

- https://www.rockstargames.com/VI/only-in-leonida
- https://www.rockstargames.com/VI/media/screenshots

Originais preservados em `01_originais/`:

- Grassrivers 01 e 02: jacaré e paisagem de canais.
- Vice City 03 e 04: cidade, palmeiras e personagens.
- Leonida Keys 01: costa, ilhas, ponte e hidroavião.
- Dois pares Hero_BG/Hero_FG: artes oficiais com camadas separadas.

Arquivos usados pelo aplicativo, além dos anteriores:

- `assets/GtaVI/vice-skyline.jpg`
- `assets/GtaVI/leonida-coast.jpg`
- `assets/GtaVI/grassrivers.jpg`
- `assets/GtaVI/club-background.jpg`
- `assets/GtaVI/boobie-layer.png`
- `assets/GtaVI/gator.png`
- `assets/GtaVI/palm.png`
- `assets/GtaVI/cruiser.png`
- `assets/GtaVI/phone.png`

Os quatro ícones novos foram preparados com imagegen integrado a partir das
referências, com transparência. São interpretações/recortes reconstruídos para
o launcher, não ícones oficiais fornecidos pela Rockstar. Mestres guardados em
`02_camadas/objetos/`; prompts e referências em `PROMPTS_PAD.md`.

## Validação

Somente analyze e revisão de código. Não executar testes ou iniciar o aplicativo
para validação visual sem autorização do usuário. A avaliação de contraste,
escala e navegação no controle será feita por ele.
