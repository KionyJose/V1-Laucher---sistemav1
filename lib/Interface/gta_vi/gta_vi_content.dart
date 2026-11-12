import 'dart:async';

import 'package:flutter/material.dart';

import '../../Modelos/NoticiaGame.dart';
import '../../Modelos/videoYT.dart';
import '../../Tela/Cinema/cinema_trailer.dart';
import 'gta_vi_feed.dart';
import 'gta_vi_widgets.dart';

/// Duas experiências editoriais próprias, com seleção e leitura pelo pad.
class GtaViContent extends StatefulWidget {
  const GtaViContent(
      {super.key,
      required this.news,
      required this.active,
      required this.onClose,
      required this.onLibraryFocus,
      required this.onOpenSource});
  final bool news, active;
  final VoidCallback onClose, onLibraryFocus;
  final Future<void> Function(String) onOpenSource;
  @override
  State<GtaViContent> createState() => GtaViContentState();
}

class GtaViContentState extends State<GtaViContent> {
  int _topic = 0, _revision = 0, _highlight = 0;
  bool _loading = true;
  String? _error, _lastResult;
  List<VideoYT> _videos = [];
  List<NoticiaGame> _news = [];
  VideoYT? _playing;
  NoticiaGame? _reading;
  Timer? _focusDelay;
  final _player = ControleTrailer();
  final _scroll = ScrollController();
  final _topicsScroll = ScrollController();
  final _readingScroll = ScrollController();
  late final _topicNodes = List.generate(_themes.length, (_) => FocusNode());
  int _focusRevision = 0, _resultCursor = 0, _topicCursor = 0;
  final _back = FocusNode();
  final _sourceFocus = FocusNode();
  final _resultNodes = <String, FocusNode>{};
  int get _count => widget.news ? _news.length : _videos.length;
  List<GtaViTopic> get _themes =>
      widget.news ? GtaViTopic.news : GtaViTopic.values;

  void focusEntry({bool preferResults = false}) {
    if (preferResults && !_loading && _count > 0 && _scroll.hasClients) {
      _focusResultAt(_highlight);
    } else {
      _focusTopicAt(_topic);
    }
  }

  void _focusTopicAt(int index) {
    _topicCursor = index;
    final revision = ++_focusRevision;
    void focus() {
      if (mounted && widget.active && revision == _focusRevision) {
        _topicNodes[index].requestFocus();
      }
    }

    if (!_topicsScroll.hasClients) {
      _back.requestFocus();
      return;
    }
    final position = _topicsScroll.position;
    final target = (index * 140.0 - position.viewportDimension / 2 + 64)
        .clamp(0.0, position.maxScrollExtent);
    unawaited(_topicsScroll
        .animateTo(target,
            duration: Duration(
                milliseconds:
                    MediaQuery.disableAnimationsOf(context) ? 0 : 140),
            curve: Curves.easeOutCubic)
        .then((_) => focus()));
  }

  void _focusResultAt(int index) {
    if (index < 0 || index >= _count || !_scroll.hasClients) return;
    final revision = ++_focusRevision;
    _focusDelay?.cancel();
    _resultCursor = index;
    setState(() => _highlight = index);
    final id = _id(index);
    final position = _scroll.position;
    final target = (index * 108.0 - position.viewportDimension / 2 + 50)
        .clamp(0.0, position.maxScrollExtent);
    unawaited(_scroll
        .animateTo(target,
            duration: Duration(
                milliseconds:
                    MediaQuery.disableAnimationsOf(context) ? 0 : 140),
            curve: Curves.easeOutCubic)
        .then((_) {
      if (!mounted || !widget.active || revision != _focusRevision) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active && revision == _focusRevision) {
          _resultNodes[id]?.requestFocus();
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }));
  }

  bool handleDirection(String command) {
    if (_playing != null) return false;
    if (_reading != null &&
        (command == 'CIMA' || command == 'BAIXO') &&
        _readingScroll.hasClients) {
      final position = _readingScroll.position;
      if (command == 'BAIXO' &&
          position.pixels >= position.maxScrollExtent - 1 &&
          _sourceFocus.context != null) {
        _sourceFocus.requestFocus();
        return true;
      }
      if (command == 'CIMA' && position.pixels <= 1) {
        _back.requestFocus();
        return true;
      }
      unawaited(_readingScroll.animateTo(
          (position.pixels + (command == 'BAIXO' ? 150 : -150))
              .clamp(0.0, position.maxScrollExtent),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic));
      return true;
    }
    final topicFocus = _topicNodes.indexWhere((node) => node.hasFocus);
    if (topicFocus >= 0) {
      if (command == 'ESQUERDA' || command == 'DIREITA') {
        _focusTopicAt((_topicCursor + (command == 'DIREITA' ? 1 : -1))
            .clamp(0, _themes.length - 1));
        return true;
      }
      if (command == 'BAIXO') {
        if (!_loading && _count > 0) _focusResultAt(_highlight);
        return true;
      }
    }
    final resultFocus = _resultNodes.values.any((node) => node.hasFocus);
    if (resultFocus && (command == 'CIMA' || command == 'BAIXO')) {
      if (command == 'CIMA' && _resultCursor <= 0) {
        _focusTopicAt(_topic);
      } else if (command == 'BAIXO' && _resultCursor >= _count - 1) {
        ++_focusRevision;
        widget.onLibraryFocus();
      } else {
        _focusResultAt((_resultCursor + (command == 'BAIXO' ? 1 : -1))
            .clamp(0, _count - 1));
      }
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    ++_revision;
    _focusDelay?.cancel();
    _player.dispose();
    _scroll.dispose();
    _topicsScroll.dispose();
    _readingScroll.dispose();
    for (final node in _topicNodes) {
      node.dispose();
    }
    _back.dispose();
    _sourceFocus.dispose();
    for (final node in _resultNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    _focusDelay?.cancel();
    ++_focusRevision;
    _resultCursor = 0;
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
      _highlight = 0;
    });
    try {
      if (widget.news) {
        final news = await GtaViFeed.news(
            topic: _themes[_topic].query, refresh: refresh);
        if (!mounted || revision != _revision) return;
        setState(() => _news = news);
      } else {
        final result =
            await GtaViFeed.videos(_themes[_topic].query, refresh: refresh);
        if (!mounted || revision != _revision) return;
        setState(() => _videos = result);
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() =>
            _error = 'A conexão com Leonida falhou. Vamos tentar de novo?');
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  String _id(int index) =>
      widget.news ? 'news:${_news[index].url}:$index' : _videos[index].videoID;
  String _title(int index) =>
      widget.news ? _news[index].titulo : _videos[index].titulo;
  String _source(int index) => widget.news
      ? '${_news[index].veiculo}  ·  ${_news[index].dataStr}'
      : _videos[index].canal.isEmpty
          ? 'YouTube'
          : _videos[index].canal;

  void _focusResult(int index) {
    _resultCursor = index;
    _focusDelay?.cancel();
    final revision = _revision;
    _focusDelay = Timer(const Duration(milliseconds: 180), () {
      if (mounted && revision == _revision && index < _count) {
        setState(() => _highlight = index);
      }
    });
  }

  void _openResult(int index) {
    if (index < 0 || index >= _count) return;
    _focusDelay?.cancel();
    setState(() {
      _highlight = index;
      _lastResult = _id(index);
      if (widget.news) {
        _reading = _news[index];
      } else {
        _playing = _videos[index];
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _back.requestFocus();
    });
  }

  bool back() {
    if (_playing == null && _reading == null) return false;
    ++_focusRevision;
    setState(() {
      _playing = null;
      _reading = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _resultNodes[_lastResult];
      if (target?.context != null) {
        target!.requestFocus();
      } else {
        _back.requestFocus();
      }
    });
    return true;
  }

  Widget _picture(int index) => Image.network(_videos[index].capaG,
      fit: BoxFit.cover,
      cacheWidth: 900,
      errorBuilder: (_, __, ___) =>
          Image.asset('assets/GtaVI/vice-skyline.jpg', fit: BoxFit.cover));

  Widget _status(String message) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!widget.news)
          GtaViTopicIcon(
              asset: widget.news
                  ? 'assets/GtaVI/phone.png'
                  : 'assets/GtaVI/gator.png',
              size: 88),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: gtaCream)),
        const SizedBox(height: 12),
        GtaViButton(
            onPressed: () => _load(refresh: true),
            child: const Text('Buscar novamente')),
      ]));

  Widget _topics() => SizedBox(
      height: widget.news ? 46 : 103,
      child: ListView.separated(
          controller: _topicsScroll,
          scrollDirection: Axis.horizontal,
          itemCount: _themes.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, index) {
            final topic = _themes[index];
            return SizedBox(
                width: 128,
                child: GtaViButton(
                    focusNode: _topicNodes[index],
                    onFocusChange: (focused) {
                      if (focused) _topicCursor = index;
                    },
                    selected: _topic == index,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    onPressed: () {
                      if (_topic == index) return;
                      setState(() => _topic = index);
                      if (_scroll.hasClients) _scroll.jumpTo(0);
                      unawaited(_load());
                    },
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!widget.news) ...[
                            GtaViTopicIcon(asset: topic.asset, size: 57),
                            const SizedBox(height: 6),
                          ],
                          Text(topic.label,
                              style: const TextStyle(fontSize: 11)),
                        ])));
          }));

  Widget _newsFeature(int index) {
    final news = _news[index];
    return SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('LEONIDA WIRE',
              style: TextStyle(
                  color: Color(0xFFC2F4DE), fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 20),
          Text(news.titulo,
              style: const TextStyle(
                  color: gtaCream,
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(_source(index),
              style: const TextStyle(color: gtaPink, fontSize: 12)),
          const SizedBox(height: 20),
          Text(news.descricao,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: gtaCream, fontSize: 15, height: 1.6)),
          const SizedBox(height: 20),
          GtaViButton(
              onPressed: () => _openResult(index),
              child: const Text('A  Ler história')),
        ]));
  }

  Widget _feature(int index) => widget.news
      ? _newsFeature(index)
      : ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(fit: StackFit.expand, children: [
            AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                child: SizedBox.expand(
                    key: ValueKey(_id(index)), child: _picture(index))),
            const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x0034274D), Color(0xF23A2955)],
                        stops: [.2, 1]))),
            Positioned(
                left: 24,
                right: 24,
                bottom: 20,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          widget.news
                              ? 'NAS RUAS DE LEONIDA'
                              : _themes[_topic].label.toUpperCase(),
                          style: const TextStyle(
                              color: Color(0xFFC2F4DE),
                              fontSize: 10,
                              letterSpacing: 2)),
                      const SizedBox(height: 9),
                      Text(_title(index),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: gtaCream,
                              fontSize: 24,
                              height: 1.1,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(_source(index),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: gtaPink, fontSize: 11)),
                      const SizedBox(height: 12),
                      GtaViButton(
                          onPressed: () => _openResult(index),
                          child: Text(widget.news
                              ? 'A  Ler história'
                              : 'A  Assistir agora')),
                    ])),
          ]));

  Widget _results() => ListView.separated(
      key: PageStorageKey(
          'gta-results-${widget.news ? 'news' : 'videos'}-$_topic'),
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _count,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) => SizedBox(
          height: 100,
          child: GtaViButton(
              focusNode:
                  _resultNodes.putIfAbsent(_id(index), () => FocusNode()),
              selected: index == _highlight,
              padding: const EdgeInsets.all(8),
              onFocusChange: (focused) {
                if (focused) _focusResult(index);
              },
              onPressed: () => _openResult(index),
              child: Row(children: [
                if (!widget.news)
                  SizedBox(
                      width: 108,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox.expand(child: _picture(index)))),
                if (!widget.news) const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(_title(index),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.25)),
                      const SizedBox(height: 5),
                      Text(_source(index),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: gtaPink, fontSize: 10)),
                    ])),
              ]))));

  Widget _browse() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: gtaPink));
    }
    if (_error != null) return _status(_error!);
    if (_count == 0) return _status('Nenhuma história por aqui agora.');
    final index = _highlight.clamp(0, _count - 1);
    return LayoutBuilder(
        builder: (_, bounds) => bounds.maxWidth >= 900
            ? Row(children: [
                Expanded(flex: 6, child: _feature(index)),
                const SizedBox(width: 26),
                Expanded(flex: 5, child: _results())
              ])
            : _results());
  }

  Widget _reader() {
    final news = _reading!;
    final uri = Uri.tryParse(news.url);
    return SingleChildScrollView(
        controller: _readingScroll,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${news.veiculo}  ·  ${news.dataStr}',
              style: const TextStyle(color: gtaPink, fontSize: 12)),
          const SizedBox(height: 10),
          Text(news.titulo,
              style: const TextStyle(
                  color: gtaCream, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(
              news.descricao.isEmpty
                  ? 'Continue essa história na fonte original.'
                  : news.descricao,
              style:
                  const TextStyle(color: gtaCream, fontSize: 16, height: 1.6)),
          const SizedBox(height: 18),
          if (uri != null &&
              (uri.scheme == 'http' || uri.scheme == 'https') &&
              uri.host.isNotEmpty)
            GtaViButton(
                focusNode: _sourceFocus,
                onPressed: () => widget.onOpenSource(news.url),
                child: const Text('Abrir matéria completa  ↗')),
        ]));
  }

  Widget _playback() => Column(children: [
        Expanded(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: ColoredBox(
                    color: Colors.black,
                    child: TrailerCine(
                        key: ValueKey(_playing!.videoID),
                        youtubeId: _playing!.videoID,
                        tocar: widget.active,
                        controle: _player,
                        espera: Duration.zero)))),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              tooltip: 'Voltar 10 segundos',
              onPressed: () => _player.pular(const Duration(seconds: -10)),
              icon: const Icon(Icons.replay_10, color: gtaCream)),
          ListenableBuilder(
              listenable: _player,
              builder: (_, __) => IconButton(
                  tooltip: 'Reproduzir / pausar',
                  onPressed: _player.alternarPausa,
                  icon: Icon(_player.pausado ? Icons.play_arrow : Icons.pause,
                      color: gtaPink))),
          IconButton(
              tooltip: 'Avançar 10 segundos',
              onPressed: () => _player.pular(const Duration(seconds: 10)),
              icon: const Icon(Icons.forward_10, color: gtaCream)),
        ]),
      ]);

  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xBE48395E),
                Color(0x9A342D50),
                Color(0x79533F64)
              ])),
      child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            Row(children: [
              if (!widget.news)
                GtaViTopicIcon(
                    asset: widget.news
                        ? 'assets/GtaVI/phone.png'
                        : 'assets/GtaVI/gator.png',
                    size: 48),
              if (!widget.news) const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(widget.news ? 'LEONIDA WIRE' : 'VICE FEED',
                        style: const TextStyle(
                            color: Color(0xFFB9F1DF),
                            fontSize: 10,
                            letterSpacing: 3)),
                    Text(
                        _playing != null
                            ? 'Agora em exibição'
                            : _reading != null
                                ? 'Histórias do estado'
                                : widget.news
                                    ? 'O outro lado do paraíso.'
                                    : 'Tem muito mais pelas ruas.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: gtaCream,
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                  ])),
              GtaViButton(
                  focusNode: _back,
                  autofocus: true,
                  onPressed: () {
                    if (!back()) widget.onClose();
                  },
                  child: const Text('B  Voltar')),
              if (_playing == null && _reading == null)
                IconButton(
                    tooltip: 'Atualizar',
                    onPressed: _loading ? null : () => _load(refresh: true),
                    icon: const Icon(Icons.refresh_rounded, color: gtaPink)),
            ]),
            if (_playing == null && _reading == null)
              Padding(padding: const EdgeInsets.only(top: 4), child: _topics()),
            const SizedBox(height: 16),
            Expanded(
                child: _playing != null
                    ? _playback()
                    : _reading != null
                        ? _reader()
                        : _browse()),
          ])));
}
