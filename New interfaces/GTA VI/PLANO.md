# Interface GTA VI — Vice City

Status: primeira implementação integrada ao seletor de interfaces; aguardando
avaliação visual e funcional do usuário. Veja `IMPLEMENTACAO.md` e `MATERIAIS.md`.

## Objetivo

Criar mais uma interface temática selecionável no launcher, com composição em
camadas, paralaxe e transições. Manter a biblioteca de jogos acessível e os
ícones dos jogos visíveis em uma faixa estável na parte inferior.

## Decisões combinadas

- Separar fundo, cenário, personagens, carros, objetos e logo quando a imagem
  permitir. Cada personagem deve ter seu próprio arquivo quando possível.
- Preservar os arquivos originais. Recortes devem ter transparência e bordas
  limpas, incluindo cabelo, acessórios e detalhes dos veículos.
- Reconstruir as regiões do cenário escondidas pelos elementos recortados para
  que o paralaxe não revele buracos ou silhuetas duplicadas.
- Manter a faixa de jogos estável e legível, com fundo escurecido, foco evidente
  e nome do jogo selecionado. Reservar essa área ao posicionar a arte.
- Usar o roteador de comandos do pad existente, sem reaplicar comandos em builds.
- Reaproveitar os dados da biblioteca e o fluxo existente de abertura de jogos.
- Manter a espera configurada de um segundo antes de solicitar a abertura;
  preparações mais demoradas podem aumentar o tempo efetivo.
- Alterações visuais ficam no launcher, sem modificar o tema do Windows.
- Validar alterações de código com analyze. Não rodar testes sem autorização
  explícita do usuário; ele fará a avaliação visual e funcional.

## Direção visual proposta

Identidade inspirada nas artes promocionais de GTA VI: paisagem tropical,
pôr do sol, rosa, lilás, coral e superfícies escuras para contraste.
O HUD será uma composição própria para o launcher.

- Topo: marca do tema e acesso às categorias Jogos, Cinema, Música, Loja,
  Vídeos e Notícias.
- Área principal: cenário em profundidade, personagens e veículos; destaque do
  jogo selecionado com título, plataforma e ação Jogar.
- Rodapé: faixa navegável de ícones/capas dos jogos, sempre acessível na biblioteca.
- Menus: proposta de painel inspirado em telefone; música com linguagem de rádio.
- Composição final, intensidade dos efeitos e tipografia serão definidas após
  examinar os arquivos fornecidos.

## Abas de conteúdo: Vídeos e Notícias

Solicitação adicionada: uma aba de vídeos que se expande ao clicar, com conteúdo
dinâmico organizado por assuntos, e outra de notícias reaproveitando o recurso
que já existe no app.

### Vídeos

- Na tela inicial, mostrar uma entrada compacta com miniatura, título e ação
  de expandir. Clique ou confirmação pelo pad abre o painel de conteúdo.
- Expandir sobre a área principal, suavizando o cenário ao fundo e preservando
  a faixa inferior dos jogos. A biblioteca continua acessível sem disputar foco
  com o painel; a reprodução em tela cheia pode ocultá-la temporariamente.
- Organizar vídeos em temas como trailers oficiais, personagens, cidades,
  veículos, gameplay, análises e curiosidades, conforme o conteúdo disponível.
- Carregar conteúdo dinamicamente ao abrir ou atualizar o painel, com cache,
  carregamento progressivo e estados de vazio, erro e nova tentativa.
- Mostrar título, canal e miniatura; separar material oficial de análises da
  comunidade. Usar os recursos existentes de busca e reprodução de vídeo após
  conferir suas interfaces e limitações na implementação.
- Reproduzir apenas após seleção explícita. Pausar o player ao recolher a aba,
  trocar de seção ou iniciar um jogo, evitando áudio concorrente.
- Voltar pelo pad recolhe o painel e restaura o foco na entrada de Vídeos;
  dentro do player, voltar primeiro retorna à lista.
- Referência consolidada em GTA VI após o usuário fornecer o site oficial de VI
  e as imagens de Jason e Lucia. As buscas desta interface usam GTA VI.

### Notícias

- Acrescentar uma entrada própria com cards de manchete, imagem, fonte e data.
- Reaproveitar a busca, o cache e a abertura de notícias existentes no app,
  após identificar os componentes disponíveis; adaptar a apresentação ao tema.
- Expandir a notícia selecionada para leitura, com retorno à mesma posição
  e ao mesmo card. Manter acesso à fonte original.
- Distinguir informações oficiais, reportagens e rumores quando a fonte
  fornecer essa classificação; não apresentar especulação como anúncio oficial.
- Atualizar sem deslocar o foco ou reorganizar os cards durante a navegação.

### Comportamento compartilhado

- Abrir apenas um painel expandido por vez, com animação coerente com as camadas.
- Suportar mouse, teclado e pad, com foco visível e rolagem acompanhando a seleção.
- Aplicar limites de carregamento e descartar ou pausar players fora de uso.
- Manter o acesso aos jogos como parte permanente da composição da biblioteca.

## Pastas

| Pasta | Uso |
| --- | --- |
| `01_originais/` | Imagens recebidas ou baixadas, sem alterações |
| `02_camadas/fundos/` | Céu e paisagens distantes, incluindo reconstrução |
| `02_camadas/cenarios/` | Arquitetura, ruas, palmeiras e planos intermediários |
| `02_camadas/personagens/` | Recortes individuais com transparência |
| `02_camadas/carros/` | Veículos recortados |
| `02_camadas/objetos/` | Elementos de primeiro plano |
| `02_camadas/logos/` | Logos isolados com transparência |
| `03_composicoes/` | Prévias de composição, enquadramento e áreas do HUD |
| `04_exportados/` | Arquivos otimizados destinados à integração no Flutter |

## Preparação dos materiais

1. Inventariar as imagens: nome, origem, resolução, formato e elementos úteis.
2. Escolher uma composição principal; preferir cenário horizontal em 4K ou maior.
3. Identificar arquivos oficiais já separados antes de fazer novos recortes.
4. Recortar elementos e reconstruir o fundo necessário.
5. Registrar a posição de cada camada em uma tela de referência comum para
   recompor a arte sem desalinhamento. Preservar os recortes mestres.
6. Reservar margem de imagem além do enquadramento para o movimento não expor
   bordas vazias. Definir os limites conforme os arquivos reais.
7. Conferir visualmente transparências, contornos, sobreposições e área dos jogos.
8. Exportar versões adequadas ao aplicativo, com tamanho e memória controlados.

## Movimento e interação

- Fundo se move menos; cenário e veículos têm deslocamento intermediário;
  personagens e objetos próximos têm maior deslocamento relativo.
- Logo tem animação própria, mantendo legibilidade.
- O movimento acompanha a navegação com suavização e limites discretos.
- A seleção dos jogos responde imediatamente. Mudanças da arte de destaque
  aguardam uma breve estabilização do foco para evitar flashes durante navegação.
- Biblioteca e comandos ficam estáveis; não acompanham o paralaxe da arte.
- Considerar preferência por redução de animações e pausar efeitos fora da tela
  ou enquanto o aplicativo estiver em segundo plano.
- A abertura pode afastar as camadas e ocultar suavemente a biblioteca.

## Etapas de implementação propostas

- [x] Receber e inventariar as imagens.
- [x] Definir composição inicial e áreas para os jogos e textos.
- [x] Preparar camadas de fundo, casal, carro e logo, incluindo fundo reconstruído.
- [ ] Produzir uma prévia visual para revisão do usuário.
- [x] Integrar nova opção ao seletor de interfaces e persistir a escolha.
- [x] Implementar tela principal, biblioteca e navegação por pad/mouse/teclado.
- [x] Implementar paralaxe e apresentação temática de abertura.
- [x] Conferir e reaproveitar os recursos existentes de vídeos e notícias.
- [x] Consolidar GTA VI como assunto das fontes e buscas de conteúdo.
- [x] Implementar aba expansível de vídeos com organização dinâmica por temas.
- [x] Implementar aba de notícias com leitura e retorno pelo diálogo existente.
- [ ] Estender identidade aos menus e categorias conforme a composição aprovada.
- [x] Rodar analyze nos arquivos alterados e entregar para avaliação do usuário.

## Referências

- Site oficial: https://www.rockstargames.com/VI
- Artes e wallpapers: https://www.rockstargames.com/VI/media/artwork-wallpapers
- Mídia oficial: https://www.rockstargames.com/VI/media

Referências pesquisadas e materiais oficiais baixados em 12/11/2026.
Fontes e transformações registradas em `MATERIAIS.md`.
