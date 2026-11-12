# Correção local da versão 0.6.0

Origem: flutter_inappwebview_windows 0.6.0, da cópia instalada no Pub Cache.
A licença original está em LICENSE. O código nativo permanece original.

Alterações em lib/src/in_app_webview/custom_platform_view.dart:

- Marca o descarte antes de aguardar a criação nativa e torna dispose idempotente.
- Não executa callbacks da UI se a criação terminar após o descarte.
- Libera um keepAlive criado depois que seu widget saiu da árvore.
- Verifica mounted e RenderBox.attached depois de aguardar a criação, antes
  de medir tamanho ou posição. Não mantém RenderBox através de um await.
- Cancela a repetição de foco e a assinatura de cursor ao descartar o widget.
- Bloqueia comandos depois de dispose; erros de canal em operações em andamento
  só são ignorados se o descarte já foi solicitado. Demais erros são propagados.

O pubspec.yaml do aplicativo usa dependency_overrides para manter a correção
reproduzível no projeto, sem modificar o Pub Cache global.
Se houver pubspec_overrides.yaml local, ele deve incluir o mesmo override,
pois o Pub usa esse arquivo em preferência ao bloco do pubspec.yaml.

No aplicativo, YoutubeWebPlayback aguarda a desmontagem do widget antes de
encerrar o keepAlive, compartilha um único ambiente WebView2 durante o processo
e preserva a superfície quando uma mensagem de vídeo indisponível é exibida.
