# Janelas abertas e ícones no Windows

`WindowListService.list()` enumera janelas em um isolate com `EnumWindows`.
Retorna `OpenAppWindow` com HWND, PID, título, nome do processo e caminho do
executável. Exclui janelas invisíveis, com proprietário, ferramentas, sem título,
cloaked e do próprio launcher. Ordena por processo e título. A consulta de caminho
usa somente `PROCESS_QUERY_LIMITED_INFORMATION`; acesso negado não impede que
uma janela com título apareça.

`WindowIconService.resolveAll(hwnds)` carrega somente HWNDs ainda não resolvidos.
`cached(hwnd)` é síncrono, e `hasResolved(hwnd)` diferencia um ícone que falhou
(null em cache) de um ícone pendente. As etapas são:

1. `WM_GETICON`: BIG, SMALL2 e SMALL, com orçamento total de 120 ms por janela.
   `SendMessageTimeout` com `SMTO_ABORTIFHUNG` evita aguardar indefinidamente
   aplicativos que não respondem.
2. `GetClassLongPtr`: ícone grande ou pequeno da classe para janelas que não
   definiram um ícone próprio.
3. `ExtractIconExW`: ícone do executável. Se o processo for
   `ApplicationFrameHost.exe`, a enumeração das janelas filhas encontra
   `Windows.UI.Core.CoreWindow` e consulta o executável real do aplicativo UWP.

Os HICON das duas primeiras etapas pertencem ao aplicativo. Somente os handles
obtidos por `ExtractIconExW` são liberados com `DestroyIcon`.

`window_native.dart` contém os bindings manuais de `DrawIconEx` e `ExtractIconExW`
e rasteriza os ícones em um DIB top-down de 32 × 32, 32 bpp. `GdiFlush` sincroniza
o desenho antes da leitura do buffer BGRA. Para ícones legados com alfa zerado,
`DI_MASK` reconstrói o alfa e o RGB é pré-multiplicado. Nos ícones modernos,
`DrawIconEx` desenha com `AC_SRC_OVER` sobre o DIB transparente, produzindo pixels
já pré-multiplicados; multiplicá-los outra vez escureceria as bordas.

Referência: [DrawIconEx, Microsoft Learn](https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-drawiconex).

`retainOnly(liveHwnds)` descarta imagens de janelas fechadas. A variante
`retainWindows(windows)` também identifica a reutilização de um HWND por outro
processo. Tokens impedem que uma extração atrasada repovoe um item descartado.
Cada serviço tem `dispose()`; o consumidor não deve destruir imagens retornadas
por `cached()`. Se precisar preservar a imagem independentemente do cache, deve
obter seu próprio `clone()` e descartar esse clone depois.

## Integração

`OpenWindowsController` consulta a lista a cada três segundos, sem sobrepor
atualizações, chama `retainWindows`, resolve os ícones e notifica os widgets:

```dart
final controller = OpenWindowsController()..start();

// Em um ListenableBuilder/listener do controller:
final window = controller.windows[index];
final icon = controller.icons.cached(window.hwnd);
final widget = icon == null
    ? const Icon(Icons.apps_rounded)
    : RawImage(image: icon, width: 32, height: 32);

// No dispose do dono:
controller.dispose();
```

O buscador usa esse controlador para aproveitar ícones de janelas abertas que
correspondam ao executável ou à pasta de um jogo. Aplicativos fechados continuam
usando o ícone do arquivo/atalho, com três extrações concorrentes no máximo.
Todos esses caminhos usam FFI e APIs do Windows; nenhum inicia processos externos.

## Descoberta dos itens instalados

A enumeração dos jogos e a arte dos itens instalados ficam nos serviços de
[game_discovery](../game_discovery/README.md). As fontes são consultadas em
paralelo, sem corte global que descarte parte de uma biblioteca. A arte é lida
do cache/registro/manifesto de cada launcher, com extração FFI em alta resolução
quando necessária. Os ícones de janelas abertas são um complemento dessas fontes.

Os cards têm chaves baseadas no destino do aplicativo, para preservar suas
imagens e seu estado quando novos resultados mudam a ordem da lista.
