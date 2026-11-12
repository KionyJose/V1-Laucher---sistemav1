# Implementação — revisão com foco no pad

Detalhes do redesenho atual em `REDESIGN_PAD.md`.
Animação de abertura com carro e fundo desfocado em `LOTTIE_ABERTURA.md`.

## Como acessar

No seletor de interfaces do launcher, escolher **GTA VI · Vice City** e aplicar.
A escolha utiliza `viewType: gta_vi`, persistido pela configuração existente.
O modo Slim continua tendo precedência quando ativo.

## Implementado

- Corpo independente em `lib/Interface/gta_vi/`, integrado à transição de
  interfaces existente para não montar duas árvores com os mesmos FocusNodes.
- Seis cenários: Ocean Drive, Vice City à noite, Pelas ruas, Leonida Keys,
  Grassrivers e Depois do pôr do sol. Alternância automática
  a cada 24 segundos na biblioteca, além de troca manual pelo botão do cenário.
- Fundo, carro e personagens com movimentos de profundidade diferentes.
  Movimento pela seleção no pad; não há paralaxe pelo mouse. Biblioteca e textos estáveis.
- Alternância automática e movimento ambiente pausam fora de primeiro plano,
  em menus, durante abertura e com redução de animações habilitada.
- Faixa inferior com ícones nativos de 36 px, extraídos dos executáveis/atalhos
  pelo serviço existente, sem caixas de fundo. Nome do item selecionado no rodapé.
- Abas Jogos, Cinema, Música, Loja, Vídeos e Notícias.
- Cinema, Música e Loja reutilizam os itens e ações existentes do controlador.
- Vídeos por assunto, com busca assíncrona, cache em memória por 15 minutos,
  deduplicação, carregamento, atualização, vazio e nova tentativa.
- Prévia muda na página inicial após estabilizar o foco. Player dedicado de
  trailers aberto após confirmação, com pausa e saltos
  de dez segundos. Recolher ou trocar a aba desmonta o player.
- Notícias reutilizam o feed existente, com temas em texto,
  destaque, fonte, data e leitura sem imagens dentro da própria seção. A matéria completa
  abre pelo fluxo existente de acesso à fonte.
- L1/R1 (LB/RB) e Q/E alternam abas; direcionais navegam no conteúdo; A confirma; B volta primeiro do
  player e depois recolhe o painel; START abre o menu existente do sistema.
- Apresentação temática de abertura, usando a espera de um segundo do
  controlador. Retorno ao launcher depende da ação do jogador.

## Avaliação pendente do usuário

- Enquadramento e contraste na resolução e escala de tela usadas de fato.
- Intensidade do paralaxe, proporção dos personagens e posição do carro.
- Navegação completa pelo pad e retorno após abrir jogos e mídias.
- Disponibilidade e relevância dos vídeos/notícias retornados pelas fontes.

Não foram executados testes nem iniciado o app para avaliação visual.
Validação de código: `flutter analyze --no-pub` dos arquivos novos e pontos de
integração, sem problemas. Após os últimos ajustes locais, `dart analyze
lib/Interface/gta_vi` também concluiu sem problemas.

## Refinamentos planejados

- Separar pessoas e elementos menores quando houver vantagem para a composição.
- Tratar menus adicionais com a mesma identidade, incluindo painel de telefone
  e apresentação de rádio mais específica.
- Ajustar a composição com o feedback visual do usuário.
