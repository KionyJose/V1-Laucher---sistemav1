import 'dart:async';

import 'package:flutter/material.dart';

import '../../Modelos/NoticiaGame.dart';
import '../../Modelos/videoYT.dart';
import '../../Tela/Cinema/cinema_trailer.dart';
import 'gta_vi_feed.dart';
import 'gta_vi_widgets.dart';

/// Prévias editoriais discretas; o vídeo só anima depois de estabilizar o foco.
class GtaViPreviews extends StatefulWidget {
  const GtaViPreviews(
      {super.key,
      required this.active,
      required this.onVideos,
      required this.onNews});
  final bool active;
  final VoidCallback onVideos, onNews;

  @override
  State<GtaViPreviews> createState() => GtaViPreviewsState();
}

class GtaViPreviewsState extends State<GtaViPreviews> {
  VideoYT? _video;
  NoticiaGame? _news;
  Timer? _settle;
  bool _preview = false;
  int _revision = 0;
  final _videoFocus = FocusNode();
  final _newsFocus = FocusNode();
  bool get hasFocus => _videoFocus.hasFocus || _newsFocus.hasFocus;
  void focusVideos() => _videoFocus.requestFocus();
  void focusHorizontal(bool right) =>
      right ? _newsFocus.requestFocus() : _videoFocus.requestFocus();

  @override
  void initState() {
    super.initState();
    unawaited(_loadSuggestion());
    unawaited(GtaViFeed.news().then((items) {
      if (mounted && items.isNotEmpty) setState(() => _news = items.first);
    }).catchError((Object _) {}));
  }

  @override
  void didUpdateWidget(GtaViPreviews oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) unawaited(_loadSuggestion());
  }

  Future<void> _loadSuggestion() async {
    final revision = ++_revision;
    _settle?.cancel();
    _preview = false;
    try {
      final video = await GtaViFeed.suggestion();
      if (!mounted || revision != _revision) return;
      setState(() {
        if (video != null) _video = video;
      });
      if (_videoFocus.hasFocus && widget.active) _focusVideo(true);
    } catch (_) {/* A paisagem permanece disponível sem conexão. */}
  }

  void _focusVideo(bool focused) {
    if (!mounted) return;
    _settle?.cancel();
    if (!focused) {
      if (_preview) setState(() => _preview = false);
      return;
    }
    _settle = Timer(const Duration(milliseconds: 750), () {
      if (mounted) setState(() => _preview = true);
    });
  }

  @override
  void dispose() {
    ++_revision;
    _settle?.cancel();
    _videoFocus.dispose();
    _newsFocus.dispose();
    super.dispose();
  }

  Widget _tile(
          {required String label,
          required String title,
          required String asset,
          required Widget picture,
          required VoidCallback onOpen,
          FocusNode? focusNode,
          ValueChanged<bool>? onFocusChange}) =>
      ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: GtaViButton(
              padding: EdgeInsets.zero,
              onPressed: onOpen,
              focusNode: focusNode,
              onFocusChange: onFocusChange,
              child: LayoutBuilder(builder: (_, bounds) {
                final textStart = (126 * 1.25).clamp(0.0, bounds.maxWidth * .5);
                return Stack(fit: StackFit.expand, children: [
                  ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (rect) => const LinearGradient(colors: [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                            Colors.transparent
                          ], stops: [
                            0,
                            .24,
                            .52,
                            1
                          ]).createShader(rect),
                      child: picture),
                  const DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                    Color(0x003B2C53),
                    Color(0x88422D57),
                    Color(0xB3422D57)
                  ], stops: [
                    0,
                    .45,
                    1
                  ]))),
                  Positioned(
                      left: textStart,
                      top: 12,
                      right: 18,
                      bottom: 12,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              GtaViTopicIcon(asset: asset, size: 27),
                              const SizedBox(width: 7),
                              Expanded(
                                  child: Text(label,
                                      maxLines: 1,
                                      style: const TextStyle(
                                          color: gtaPink,
                                          letterSpacing: 1.6,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800)))
                            ]),
                            const SizedBox(height: 6),
                            Text(title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: gtaCream,
                                    height: 1.25,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(
                                          color: Colors.black54, blurRadius: 10)
                                    ])),
                            const SizedBox(height: 8),
                            const Text('A  EXPLORAR',
                                style: TextStyle(
                                    color: Color(0xFFB9F1E0),
                                    fontSize: 9,
                                    letterSpacing: 1.5)),
                          ])),
                ]);
              })));

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: _tile(
                label: 'VICE FEED',
                title: _video?.titulo ??
                    'Histórias, ruas e descobertas de Leonida',
                asset: 'assets/GtaVI/cruiser.png',
                onOpen: widget.onVideos,
                focusNode: _videoFocus,
                onFocusChange: _focusVideo,
                picture: Stack(fit: StackFit.expand, children: [
                  if (_video != null)
                    Image.network(_video!.capaG,
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                        errorBuilder: (_, __, ___) => Image.asset(
                            'assets/GtaVI/vice-skyline.jpg',
                            fit: BoxFit.cover))
                  else
                    Image.asset('assets/GtaVI/vice-skyline.jpg',
                        fit: BoxFit.cover),
                  if (_preview &&
                      widget.active &&
                      _video != null &&
                      !MediaQuery.disableAnimationsOf(context))
                    TrailerCine(
                        youtubeId: _video!.videoID,
                        tocar: true,
                        mudo: true,
                        espera: Duration.zero),
                ]))),
        const SizedBox(width: 18),
        Expanded(
            child: _tile(
                label: 'LEONIDA WIRE',
                title: _news?.titulo ?? 'O que está acontecendo pelo estado',
                asset: 'assets/GtaVI/phone.png',
                onOpen: widget.onNews,
                focusNode: _newsFocus,
                picture: Image.asset('assets/GtaVI/leonida-coast.jpg',
                    fit: BoxFit.cover))),
      ]);
}
