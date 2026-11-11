import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'games_busca_ctrl.dart';

class GameSearchArtwork extends StatefulWidget {
  const GameSearchArtwork({super.key, required this.game, required this.ctrl});
  final GameEntry game;
  final GamesBuscaCtrl ctrl;

  @override
  State<GameSearchArtwork> createState() => _GameSearchArtworkState();
}

class _GameSearchArtworkState extends State<GameSearchArtwork> {
  ui.Image? _icon;
  ui.Image? _windowIconSource;
  ui.Image? _windowIcon;
  String? _background;
  String? _failedBackground;
  bool _iconLoading = true;
  bool _playable = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _playable = widget.game.isGame;
    unawaited(_loadIcon());
    unawaited(_loadBackground());
    unawaited(_loadPlayable());
  }

  @override
  void didUpdateWidget(GameSearchArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.exePath != widget.game.exePath ||
        widget.ctrl.artwork.fingerprint(oldWidget.game) !=
            widget.ctrl.artwork.fingerprint(widget.game)) {
      _icon?.dispose();
      _icon = null;
      _background = null;
      _failedBackground = null;
      _iconLoading = true;
      _playable = widget.game.isGame;
      unawaited(_loadIcon());
      unawaited(_loadBackground());
      unawaited(_loadPlayable());
    }
  }

  Future<void> _loadIcon() async {
    final revision = ++_revision;
    try {
      final icon = await widget.ctrl.iconFor(widget.game);
      if (icon == null || !mounted || revision != _revision) return;
      final image = icon.clone();
      setState(() => _icon = image);
    } catch (_) {
      // Mantém o fallback do arquivo se nenhuma origem fornecer um ícone.
    } finally {
      if (mounted && revision == _revision) {
        setState(() => _iconLoading = false);
      }
    }
  }

  Future<void> _loadPlayable() async {
    final revision = _revision;
    final playable = await widget.ctrl.artwork.isGameFor(widget.game);
    if (mounted && revision == _revision && playable != _playable) {
      setState(() => _playable = playable);
    }
  }

  void _backgroundFailed(String source) {
    final revision = _revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && revision == _revision && _failedBackground != source) {
        setState(() => _failedBackground = source);
      }
    });
  }

  Future<void> _loadBackground() async {
    final revision = _revision;
    final background = await widget.ctrl.backgroundFor(widget.game);
    if (mounted && revision == _revision && background != null) {
      setState(() => _background = background);
    }
  }

  @override
  void dispose() {
    ++_revision;
    _icon?.dispose();
    _windowIcon?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveIcon = widget.ctrl.windowIconFor(widget.game);
    if (!identical(liveIcon, _windowIconSource)) {
      _windowIcon?.dispose();
      _windowIconSource = liveIcon;
      // O widget possui este clone; o cache pode liberar a imagem original
      // quando a janela fechar sem invalidar o frame que ainda está desenhado.
      _windowIcon = liveIcon?.clone();
    }
    final icon = _windowIcon ?? _icon;
    final source = _background ?? widget.game.thumbnailPath;
    final background = source == _failedBackground ? null : source;
    final hasBackground = background != null;
    return LayoutBuilder(builder: (context, bounds) {
      final iconSize =
          hasBackground ? 52.0 : (bounds.maxWidth * .64).clamp(48.0, 160.0);
      Widget imageError(BuildContext context, Object error, StackTrace? stack) {
        _backgroundFailed(background!);
        return const SizedBox.shrink();
      }

      return Stack(fit: StackFit.expand, children: [
        if (background != null) ...[
          if (background.startsWith('https://'))
            Image.network(background,
                fit: BoxFit.cover, errorBuilder: imageError)
          else
            Image.file(File(background),
                fit: BoxFit.cover, errorBuilder: imageError),
          const DecoratedBox(
              decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99000000)]),
          )),
        ],
        Positioned.fill(
          top: _playable ? 30 : 0,
          child: Align(
            alignment: hasBackground ? Alignment.bottomLeft : Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: iconSize,
                height: iconSize,
                padding: const EdgeInsets.all(4),
                decoration: hasBackground
                    ? BoxDecoration(
                        color: const Color(0xAA101522),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 6)
                        ],
                      )
                    : null,
                child: icon != null
                    ? RawImage(
                        image: icon,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high)
                    : Center(
                        child: _iconLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white54))
                            : Icon(
                                _playable
                                    ? Icons.videogame_asset_outlined
                                    : Icons.insert_drive_file_outlined,
                                size: 36,
                                color: Colors.white54)),
              ),
            ),
          ),
        ),
        if (_playable)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 30,
            child: ColoredBox(
              color: Color(0xFF238636),
              child: Center(
                  child: Text('Jogavel',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700))),
            ),
          ),
      ]);
    });
  }
}
