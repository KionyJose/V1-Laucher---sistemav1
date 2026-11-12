# Carro na abertura dos jogos

## Material

- Fonte: `C:\Users\kiony\Downloads\carr.json`.
- Original preservado em `01_originais/carr.json`.
- Cópia de entrega em `04_exportados/car-loading.json`.
- Asset usado no app: `assets/GtaVI/car-loading.json`.
- Composição vetorial, 800 × 800, 60 fps, frames 0–181: aproximadamente 3,02 s.
- O JSON já tem canvas transparente. Os sólidos encontrados estão mascarados e
  compõem detalhes do carro e da pista; não são fundos opacos de tela inteira.
  O arquivo foi preservado sem remover camadas da arte.

## Integração

`lib/Interface/gta_vi/gta_vi_launch.dart` apresenta o carro na abertura dos jogos
do tema GTA VI. Usa o pacote Lottie 3.6.1 já instalado, sem dependências novas.

- O fundo da composição fica desfocado, com sigma 14, atrás do carro e do texto.
- Depois de carregar o asset, o carro entra pela direita em 900 ms, desacelerando
  com easeOutCubic até parar no centro.
- O Lottie repete seu loop enquanto a apresentação está aberta, inclusive depois
  de o jogo ser iniciado. O indicador de carregamento existente continua na
  preparação; a espera de um segundo do controlador não foi alterada.
- A/B no pad, o botão de retorno e a ação de voltar usam a mesma saída: o carro
  deixa a tela pela esquerda em 650 ms; somente depois a rota é fechada.
- Com redução de animações habilitada no sistema, movimentos e loop são omitidos.
- Controllers e notificadores são descartados ao terminar a apresentação.

## Verificação

JSON inspecionado por estrutura e conteúdo das camadas; integração verificada
com analyze. Não foram executados testes, harness de renderização ou aplicativo,
conforme a preferência do usuário. A reprodução visual fica para sua avaliação.
