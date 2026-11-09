# Plano — Telas modulares / plugáveis (Home + telas secundárias)

## Contexto

O launcher hoje decide "qual tela mostrar" em pontos espalhados e duplicados,
e abre telas secundárias (Downloads, Descobrir, Loja) com widgets literais
hardcoded nos locais onde o menu é montado — não existe nenhum registro
central de telas. Isso torna caro adicionar uma tela nova: é preciso editar
vários arquivos ao mesmo tempo e não há um contrato formal que diga "o que
uma tela precisa implementar para funcionar com o pad".

O usuário quer abrir essa porta para fora do próprio desenvolvimento: dar a
uma IA um arquivo-semente com o contrato e as instruções, receber de volta um
`.dart` novo, soltar na pasta certa, registrar em uma linha, recompilar — e a
tela aparecer nos seletores existentes (Interfaces / Mais) sem precisar caçar
outros arquivos.

**Importante**: esta tarefa é só a análise e o plano. Nenhum código do app foi
alterado nesta etapa. O único artefato produzido é este documento.

### Por que plugin em Dart (e não um DSL em JSON)

Flutter desktop é compilado (AOT) — não existe "soltar um arquivo e o app já
carrega" sem recompilar, isso vale tanto para Dart quanto para qualquer outro
formato. A diferença é o que se ganha recompilando:

- Um **DSL declarativo (JSON)** evitaria o rebuild, mas exigiria construir um
  interpretador genérico que reproduzisse o vocabulário visual que já existe
  (vidro, partículas, dobra de card, espelho, etc. em `lib/Interface/futuristic_*.dart`)
  — ou abandoná-lo. É engenharia nova grande para, no fim, produzir telas
  visualmente mais pobres que as atuais.
- Um **plugin em Dart** reaproveita 100% do que já existe (os próprios
  widgets `futuristic_*`, `CardGame`, `LauncherPadScope`) e já tem precedente
  real no projeto: `packages/loja_feature_stub` é exatamente isso — um
  pacote local com API pública mínima (`lojaInternaDisponivel` + `buildLojaScreen()`),
  importado como `package:loja_feature/loja_feature.dart`.

Por isso o plano usa plugin em Dart, formalizando dois contratos (tela de
Home e tela independente) e dois registros centrais, no lugar do DSL.

### Pontos de dor mapeados (o que o plano resolve)

Hoje o `viewType` (`list`/`moderno`/`retro`/`grid`/`transversal`/`futurista`)
é lido/decidido em **7 lugares independentes**:

1. `PrincipalCtrl._recalcularModos()` — monta as flags booleanas (`futuristicMode` etc.)
2. `PrincipalCtrl.comandoSlim()` — switch de comandos do pad com `if (futuristicMode...)`
3. `PrincipalPage.bodyPageView()`/`scaffold()` — switch de qual Widget desenhar
4. `PrincipalPage._modernStartup` — liga a animação de abertura só se `viewType == 'moderno'`
5. `SonsSistema.futuristicActive` — escolhe o conjunto de efeitos sonoros
6. `lib/Widgets/Pops/pop_interfaces.dart` → `telasDoLauncher()` — lista nova do seletor "Interfaces"
7. `lib/Widgets/Pops/pop_config.dart` — seletor **legado**, com uma lista hardcoded *diferente* e incompleta (falta `'grid'`/`'slim'`) — duas fontes de verdade divergentes hoje.

E telas secundárias (`Downloads`, `Descobrir`, `Loja`) são abertas via
`abrirTelaLauncher(context, <Widget literal>)` direto em `launcher_menu.dart`
e `PrincipalCtrl.abrirTelaInterna`/`movLoja` — sem nenhuma lista central;
quem monta o menu precisa saber de cada tela individualmente.

### O que já existe e vai ser reaproveitado (não recriado)

- `LauncherPadScope` (`lib/Interface/launcher_pad_scope.dart`) — já traduz
  comandos do pad (`CIMA/BAIXO/ESQUERDA/DIREITA`, `'2'`=confirmar, `'3'`=voltar,
  `START`=menu) para `FocusTraversalPolicy`/`Actions` do Flutter, com um
  `onCommand` de escape para telas que precisam de lógica própria. Já é usado
  por `BodyFuturista`, `LauncherMoreGrid`, `PopInterfaces` e pelas telas
  secundárias modernas — ele já é, na prática, o contrato de pad de qualquer
  tela nova.
- `TelaDoLauncher`/`AjusteDeTela` (`pop_interfaces.dart`) — já é uma lista de
  metadados por tela (id, nome, ícone, resumo, ajustes próprios) usada para
  desenhar o seletor "Interfaces". Vira a base do novo registro de Home, só
  ganhando o `builder`.
- `loja_feature_stub` — precedente de "pacote de feature" com API mínima.
  Inspira o formato do contrato (poucos campos, função builder), não o
  empacotamento completo (um `.dart` solto é suficiente para telas de
  usuário; não vale exigir um pacote Dart inteiro por tela).
- `Paad`/`PadInterfaceRouter` (`lib/Class/Paad.dart`, `pad_interface_router.dart`)
  — já emite o vocabulário completo de comandos (`CIMA/BAIXO/ESQUERDA/DIREITA`,
  `'1'/'2'/'3'/'4'`, `LB/RB/L3/R3`, `START/SELECT/GUIDE`, `LT-$valor/RT-$valor`,
  combos `[LB-RB]`/`ST-SL`/`[L3; R3]`/`HOME`) — este é o vocabulário a documentar
  no arquivo-semente para a IA, não um vocabulário novo a inventar.

## Desenho proposto

### 1. Dois registros + dois contratos

**A. Telas independentes** (`StandaloneScreenEntry`) — para telas tipo
Downloads/Descobrir/Loja e qualquer tela nova que não precise da biblioteca
de jogos compartilhada:
```dart
class StandaloneScreenEntry {
  final String id;
  final String label;
  final IconData icon;
  final WidgetBuilder builder; // deve conter um LauncherPadScope
  final bool Function()? isAvailable; // flag de capacidade, como lojaInternaDisponivel
}
```
Um registro (`List<StandaloneScreenEntry>`) substitui os `Widget` literais
hardcoded em `launcher_menu.dart`/`PrincipalCtrl.abrirTelaInterna`: esses
locais passam a iterar a lista e chamar `abrirTelaLauncher(context, entry.builder(context))`.

**B. Telas de Home** (`HomeScreenEntry`) — para o nível que hoje é `viewType`:
```dart
class HomeScreenEntry {
  final String id; // mesmo valor de configSistema.viewType
  final String label;
  final IconData icon;
  final String summary;
  final List<AjusteDeTela> settings; // reaproveita AjusteDeTela já existente
  final bool compactNavigation; // substitui a checagem manual futuristicMode/slimMode
  final Widget Function(HomeScreenApi api) build;
}
```
`HomeScreenApi` é uma interface estreita (não o `PrincipalCtrl` inteiro) com
só o que uma tela de Home legitimamente precisa: lista de jogos, índice
selecionado + setter, focus nodes, callbacks de abrir/menu/trocar aba, e
passthrough de comando do pad. `PrincipalCtrl` passa a expor um getter
`HomeScreenApi get homeApi` que embrulha os campos já existentes — aditivo,
sem reescrever a lógica interna do controller.

As 7 leituras de `viewType` listadas acima (exceto o próprio campo em
`configs_sistema.dart`) passam a consultar esse registro por id, em vez de
comparar strings cada uma do seu jeito. Telas embutidas (`moderno`, `retro`,
`grid`, `transversal`, `futurista`, `list`) ganham uma entrada cada, só
embrulhando o widget que já existe (`BodyIconesJogosModerno`, `BodyFuturista`
etc.) — zero mudança de comportamento, só indireção. `slim` continua um modo
transversal separado, como hoje (não é um "estilo de Home").

`pop_interfaces.dart` perde sua lista própria e passa a desenhar a partir do
registro; `pop_config.dart` (legado) passa a iterar a mesma lista em vez da
cópia incompleta que tem hoje — corrige de brinde a divergência entre os dois
seletores.

### 2. Arquivos-semente para a IA

Pasta nova `lib/UserScreens/`:
- `_INSTRUCOES_PARA_IA.md` — texto para colar no prompt de uma IA: os dois
  contratos acima, a tabela completa do vocabulário do pad, os campos do
  modelo `IconInicial`, um catálogo dos widgets visuais reaproveitáveis
  (`futuristic_*`, `CardGame`, `GlassPanel`/`GlassScene`/`GlassBackdrop`) e o
  passo final de registro.
- `template_home_screen.dart` — exemplo mínimo e completo de uma
  `HomeScreenEntry`, comentado.
- `template_standalone_screen.dart` — exemplo mínimo e completo de uma
  `StandaloneScreenEntry`, comentado.
- `registry.dart` — o único arquivo que o usuário edita à mão depois de gerar
  uma tela nova: duas listas (`homeScreens`, `standaloneScreens`) somadas aos
  registros embutidos na inicialização.

### 3. Fluxo final para quem usa uma IA para criar uma tela

Copiar `_INSTRUCOES_PARA_IA.md` + o template certo para o prompt → receber um
`.dart` novo → salvar em `lib/UserScreens/` → acrescentar uma linha em
`registry.dart` → recompilar → a tela aparece sozinha no seletor "Interfaces"
(Home) ou no menu "Mais" (independente), porque ambos os seletores já
desenham a partir da lista.

## Arquivos principais a tocar (quando a implementação começar)

- Novos: `lib/Interface/Screens/{standalone_screen.dart, standalone_screen_registry.dart, home_screen_api.dart, home_screen_entry.dart, home_screen_registry.dart}`, `lib/UserScreens/{_INSTRUCOES_PARA_IA.md, template_home_screen.dart, template_standalone_screen.dart, registry.dart}`.
- Consolidar para ler do registro: `PrincipalCtrl.dart` (`_recalcularModos`, `comandoSlim`), `PrincipalPage.dart` (`bodyPageView`/`scaffold`, `_modernStartup`), `SonsSistema.dart` (`futuristicActive`), `pop_interfaces.dart` (`telasDoLauncher`), `pop_config.dart` (lista de ciclo), `launcher_menu.dart` e `PrincipalCtrl.abrirTelaInterna`/`movLoja`.
- `main.dart`: uma chamada nova (`UserScreenRegistry.registerAll()`) antes do `runApp`.

## Verificação (quando a implementação começar)

- `flutter analyze` depois de cada etapa de migração (conforme preferência já combinada: só analisar, o teste manual é feito pelo usuário).
- `git diff` dos widgets de Home existentes (`BodyIconesJogosModerno`, `BodyFuturista` etc.) deve ficar vazio — eles só passam a ser referenciados por um `build:` no registro, não editados.
- Teste de fumaça único: registrar temporariamente uma tela de exemplo (o próprio `template_home_screen.dart`), confirmar que aparece em "Interfaces" e responde ao pad, depois remover — valida o caminho registro → seletor → pad de ponta a ponta antes de qualquer conteúdo real depender dele.

## Apêndice — material para o arquivo-semente (`_INSTRUCOES_PARA_IA.md`)

Confirmado por exploração direta do código: **não existe nenhum
`Map<String,VoidCallback>` declarativo de botões** no projeto — toda tela
hoje implementa seu próprio `bool _command(String) { if (command=='X'){...; return true;} ... }`
passado como `onCommand` do `LauncherPadScope`; botões ganham ativação de
graça só pela convenção `FocusNode` + `ActivateIntent` (usada por
`FuturisticActionTile`/`FuturisticTopicLabel`). O contrato `HomeScreenApi`/
`StandaloneScreenEntry` do plano segue exatamente essa convenção já existente
— não inventa um mecanismo novo de input.

**Vocabulário completo de comandos do pad** (emitido por `Paad`, confirmado
como fechado — nenhum arquivo `pad_*.dart` acrescenta comando novo):
`CIMA/BAIXO/ESQUERDA/DIREITA` (direção), `'1'/'2'/'3'/'4'` (X/A/B/Y),
`LB/RB` (ombros), `L3/R3` (cliques do analógico), `START/SELECT/GUIDE`,
`LT-<valor>/RT-<valor>` (gatilhos analógicos), combos `[LB-RB]`, `ST-SL`,
`[L3; R3]`, `[LB; RB; A (2)]`, `HOME`, e `""` no soltar o botão.

**Catálogo de widgets visuais reaproveitáveis** (todos em `lib/Interface/futuristic_*.dart`,
salvo indicado): `FuturisticActionTile` (botão focável padrão — base de
qualquer tile), `FuturisticArtwork` (imagem com fallback), `FuturisticCardEffect`/
`FuturisticCardFold`/`FuturisticCardMirror`/`FuturisticCardEntrance` (efeitos
de card), `FuturisticContentSkeleton` (placeholder de carregamento),
`FuturisticGameBackdrop`/`FuturisticLandscape` (fundo animado), `FuturisticParticles`
(partículas reativas ao scroll), `FuturisticTopicLabel` (título focável),
`FuturisticViewBox` (transição entre páginas), `GlassPanel`/`GlassBackdrop`/
`GlassScene`/`FuturisticPalette` (`futuristic_material.dart` — o tema de
vidro inteiro), `CardGame` (`lib/Widgets/cardGame.dart` — card do estilo
antigo, não-Futurista). `futuristic_game_details.dart` e `body_futurista.dart`
são as referências de composição real a apontar para a IA como exemplo de
como essas peças se encaixam numa tela completa.

Este apêndice é a matéria-prima do `_INSTRUCOES_PARA_IA.md` da Parte 2 — na
implementação, ele só precisa ser reformatado como instrução, não
repesquisado.

## Fora de escopo (não tratado aqui)

O bug relatado no início da sessão — `SELECT` faz o pad perder os comandos de
movimento na tela Futurista (`PrincipalCtrl.comandoSlim`, `case 'SELECT'` →
`trocaViewIcones()` alterna `cardGamesGrid` e aparentemente desincroniza os
focus nodes entre a esteira e a grade) — continua aberto, mas não faz parte
deste plano de modularidade por pedido explícito do usuário. Fica registrado
aqui para retomar depois, isoladamente.

## Entregável desta etapa

Nenhuma alteração de código. Este documento é o artefato desta etapa.
