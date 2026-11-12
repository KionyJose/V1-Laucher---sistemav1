import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Reprodução oficial do YouTube; os comandos continuam pertencendo ao launcher.
class YoutubeWebPlayback extends ChangeNotifier {
  YoutubeWebPlayback(this.videoId, {this.loop = false});

  // O ambiente pertence ao processo; não a cada vídeo. Ele precisa continuar
  // vivo enquanto houver criações nativas pendentes de outras prévias.
  static Future<WebViewEnvironment>? _environmentFuture;

  static Future<WebViewEnvironment> _sharedEnvironment() async {
    final future = _environmentFuture ??= WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(
        additionalBrowserArguments:
            '--autoplay-policy=no-user-gesture-required',
      ),
    );
    try {
      return await future;
    } catch (_) {
      if (identical(_environmentFuture, future)) _environmentFuture = null;
      rethrow;
    }
  }

  final String videoId;
  final bool loop;
  final keepAlive = InAppWebViewKeepAlive();
  HttpServer? _server;
  WebViewEnvironment? environment;
  InAppWebViewController? _web;
  String? url;
  String? error;
  bool ready = false;
  bool playing = false;
  bool started = false;
  bool completed = false;
  bool get wantsPlay => _wantsPlay;
  bool get viewCreated => _web != null;
  bool _disposed = false;
  bool _wantsPlay = true;
  double _volume = 100;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  Timer? _timeout;
  int _mountedViews = 0;
  Completer<void>? _viewsDetached;
  Future<void>? _releaseFuture;

  void _viewMounted() {
    if (_mountedViews++ == 0) _viewsDetached = Completer<void>();
  }

  void _viewUnmounted() {
    if (--_mountedViews == 0) _viewsDetached?.complete();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      if (!RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) {
        throw const FormatException('ID de vídeo inválido');
      }
      if (Platform.isWindows) {
        final env = await _sharedEnvironment();
        if (_disposed) return;
        environment = env;
      }
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      if (_disposed) {
        await server.close(force: true);
        return;
      }
      _server = server;
      url = 'http://127.0.0.1:${server.port}/';
      server.listen((request) async {
        try {
          request.response.headers.contentType = ContentType.html;
          request.response.headers
              .set(HttpHeaders.cacheControlHeader, 'no-store');
          request.response.write(_html);
          await request.response.close();
        } catch (_) {
          // A WebView pode fechar enquanto a resposta está sendo enviada.
        }
      });
      _timeout = Timer(const Duration(seconds: 35), () {
        fail('O YouTube demorou para carregar este vídeo.');
      });
      _notify();
    } catch (_) {
      fail('Não foi possível iniciar o reprodutor do YouTube.');
    }
  }

  String get _html => '''<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;background:#000;height:100%;overflow:hidden}
#player{position:absolute;inset:0;width:100%;height:100%}</style>
</head><body><div id="player"></div><script>
var player, youtubeReady=false, readyReported=false, readyReporting=false;
function send(name,...args) {
  if(window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
    return window.flutter_inappwebview.callHandler(name,...args);
  }
}
function reportReady() {
  if(!youtubeReady || readyReported || readyReporting) return;
  var response=send('ready');
  if(response && response.then) {
    readyReporting=true;
    response.then(function(){readyReported=true;readyReporting=false;})
      .catch(function(){readyReporting=false;});
  }
}
window.addEventListener('flutterInAppWebViewPlatformReady',reportReady);
function onYouTubeIframeAPIReady() {
  player=new YT.Player('player',{
    videoId:${jsonEncode(videoId)},width:'100%',height:'100%',
    playerVars:{autoplay:${_wantsPlay ? 1 : 0},controls:0,disablekb:1,fs:0,playsinline:1,
      iv_load_policy:3,rel:0,origin:location.origin},
    events:{onReady:function(e){
        youtubeReady=true;
        e.target.setVolume($_volume);
        ${_wantsPlay ? 'e.target.playVideo();' : 'e.target.pauseVideo();'}
        reportReady();
      },
      onStateChange:function(e){
        send('state',e.data);
        if(e.data===0 && ${loop ? 'true' : 'false'}){player.seekTo(0,true);player.playVideo();}
      },
      onError:function(e){send('error',e.data);}}
  });
}
setInterval(function(){
  reportReady();
  if(youtubeReady && readyReported) {
    send('time',player.getCurrentTime(),player.getDuration());
    send('state',player.getPlayerState());
  }
},400);
</script><script src="https://www.youtube.com/iframe_api"></script></body></html>''';

  void attach(InAppWebViewController controller) {
    _web = controller;
    if (_disposed) {
      unawaited(_release());
      return;
    }
    controller.addJavaScriptHandler(
        handlerName: 'ready',
        callback: (_) {
          if (_disposed) return;
          ready = true;
          error = null;
          _timeout?.cancel();
          setVolume(_volume);
          if (_wantsPlay) {
            play();
          } else {
            pause();
          }
          _notify();
        });
    controller.addJavaScriptHandler(
        handlerName: 'state',
        callback: (args) {
          if (_disposed || args.isEmpty) return;
          playing = args.first == 1;
          completed = args.first == 0 && !loop;
          if (args.first == 0 && !loop) _wantsPlay = false;
          if (playing) {
            started = true;
            error = null;
            _timeout?.cancel();
          }
          _notify();
        });
    controller.addJavaScriptHandler(
        handlerName: 'time',
        callback: (args) {
          if (_disposed || args.length < 2) return;
          final pos = args[0];
          final dur = args[1];
          if (pos is! num || dur is! num || !pos.isFinite || !dur.isFinite) {
            return;
          }
          position = Duration(milliseconds: (pos * 1000).round());
          duration = Duration(milliseconds: (dur * 1000).round());
          _notify();
        });
    controller.addJavaScriptHandler(
        handlerName: 'error',
        callback: (args) {
          fail('Não foi possível reproduzir este vídeo no YouTube'
              '${args.isEmpty ? '.' : ' (código ${args.first}).'}');
        });
  }

  void fail(String message) {
    if (_disposed) return;
    _timeout?.cancel();
    error = message;
    playing = false;
    _notify();
  }

  Future<void> _js(String source) async {
    if (_disposed || !ready) return;
    try {
      await _web?.evaluateJavascript(source: source);
    } catch (_) {
      fail('Não foi possível enviar o comando ao reprodutor.');
    }
  }

  void play() {
    _wantsPlay = true;
    unawaited(_js('player.playVideo();'));
  }

  void pause() {
    _wantsPlay = false;
    unawaited(_js('player.pauseVideo();'));
  }

  void playOrPause() {
    // O primeiro Play durante o carregamento mantém a intenção de iniciar.
    if (!started) {
      play();
    } else {
      _wantsPlay ? pause() : play();
    }
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 100.0);
    unawaited(_js('player.setVolume($_volume);'));
  }

  void seek(Duration target) {
    final end = duration > Duration.zero
        ? duration.inMilliseconds
        : target.inMilliseconds;
    final ms = target.inMilliseconds.clamp(0, end < 0 ? 0 : end);
    position = Duration(milliseconds: ms);
    unawaited(_js('player.seekTo(${ms / 1000},true);'));
    _notify();
  }

  Future<void> _release() => _releaseFuture ??= _releaseResources();

  Future<void> _releaseResources() async {
    // O State do plugin deve cancelar suas medições antes de fechar o canal.
    if (_mountedViews > 0) await _viewsDetached?.future;
    try {
      if (_web != null) {
        await _web?.evaluateJavascript(
            source:
                'if(typeof player !== "undefined" && player.destroy) player.destroy();');
      }
    } catch (_) {
      // A plataforma pode já ter removido a view ao sair da rota.
    }
    try {
      await InAppWebViewController.disposeKeepAlive(keepAlive);
    } catch (_) {
      // A view pode ter sido descartada pela plataforma.
    }
    try {
      await _server?.close(force: true);
    } catch (_) {
      // O encerramento não deve propagar erros para a próxima tela.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timeout?.cancel();
    unawaited(_release());
    super.dispose();
  }
}

class YoutubeWebVideo extends StatelessWidget {
  const YoutubeWebVideo({
    super.key,
    required this.playback,
    this.fit = BoxFit.contain,
  });

  final YoutubeWebPlayback playback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (playback.url == null) return const SizedBox.expand();
    final view = ExcludeFocus(
      child: IgnorePointer(
        child: _YoutubeWebViewSurface(
          key: ObjectKey(playback),
          playback: playback,
        ),
      ),
    );
    if (fit != BoxFit.cover) return view;
    return LayoutBuilder(builder: (_, constraints) {
      final size = constraints.biggest;
      if (!size.isFinite || size.isEmpty) return view;
      final wide = size.width / size.height > 16 / 9;
      return ClipRect(
        child: OverflowBox(
          minWidth: wide ? size.width : size.height * 16 / 9,
          maxWidth: wide ? size.width : size.height * 16 / 9,
          minHeight: wide ? size.width * 9 / 16 : size.height,
          maxHeight: wide ? size.width * 9 / 16 : size.height,
          child: view,
        ),
      );
    });
  }
}

/// Controla a vida do widget separadamente da vida da reprodução/keepAlive.
class _YoutubeWebViewSurface extends StatefulWidget {
  const _YoutubeWebViewSurface({super.key, required this.playback});

  final YoutubeWebPlayback playback;

  @override
  State<_YoutubeWebViewSurface> createState() => _YoutubeWebViewSurfaceState();
}

class _YoutubeWebViewSurfaceState extends State<_YoutubeWebViewSurface> {
  @override
  void initState() {
    super.initState();
    widget.playback._viewMounted();
  }

  @override
  void dispose() {
    widget.playback._viewUnmounted();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    return InAppWebView(
      keepAlive: playback.keepAlive,
      webViewEnvironment: playback.environment,
      initialUrlRequest: URLRequest(url: WebUri(playback.url!)),
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        disableContextMenu: true,
      ),
      onWebViewCreated: playback.attach,
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame == true) {
          playback.fail('Não foi possível carregar o reprodutor do YouTube.');
        }
      },
    );
  }
}
