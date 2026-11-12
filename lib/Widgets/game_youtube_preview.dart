import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../Tela/Cinema/cinema_trailer.dart';

/// Busca somente o ID; a reprodução usa a mesma WebView dos trailers.
class GameYoutubePreview extends StatefulWidget {
  const GameYoutubePreview({
    super.key,
    required this.game,
    required this.active,
    required this.fallback,
    this.tags = const ['Gameplay', 'cinematic'],
    this.onPlayingChanged,
  });

  final String game;
  final bool active;
  final Widget fallback;
  final List<String> tags;
  final ValueChanged<bool>? onPlayingChanged;

  @override
  State<GameYoutubePreview> createState() => _GameYoutubePreviewState();
}

class _GameYoutubePreviewState extends State<GameYoutubePreview> {
  Timer? _delay;
  YoutubeExplode? _search;
  String? _videoId;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(GameYoutubePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.game != oldWidget.game || widget.active != oldWidget.active) {
      _schedule();
    }
  }

  void _schedule() {
    final revision = ++_revision;
    _delay?.cancel();
    _search?.close();
    _search = null;
    _videoId = null;
    if (!widget.active || widget.game.isEmpty) return;
    final game = widget.game;
    _delay = Timer(const Duration(milliseconds: 500), () async {
      final search = YoutubeExplode();
      _search = search;
      try {
        final tags = widget.tags;
        final tag =
            tags.isEmpty ? 'Gameplay' : tags[Random().nextInt(tags.length)];
        final results = await search.search
            .search('$game $tag')
            .timeout(const Duration(seconds: 20));
        if (!mounted || revision != _revision || results.isEmpty) return;
        final video = results[Random().nextInt(results.length.clamp(1, 5))];
        setState(() => _videoId = video.id.value);
      } catch (_) {
        // A arte permanece como fundo se a busca não encontrar uma prévia.
      } finally {
        search.close();
        if (identical(_search, search)) _search = null;
      }
    });
  }

  @override
  void dispose() {
    ++_revision;
    _delay?.cancel();
    _search?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        widget.fallback,
        if (_videoId != null && widget.active)
          TrailerCine(
            key: ValueKey(_videoId),
            youtubeId: _videoId,
            tocar: widget.active,
            mudo: true,
            espera: Duration.zero,
            onTocando: widget.onPlayingChanged,
          ),
      ]);
}
