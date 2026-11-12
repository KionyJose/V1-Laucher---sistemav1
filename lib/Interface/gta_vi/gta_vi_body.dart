import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../Tela/Tela Principal/PrincipalCtrl.dart';
import '../../Widgets/launcher_window_controls.dart';
import '../../System/game_discovery/game_artwork_service.dart';
import '../../System/game_discovery/installed_game_discovery.dart';
import '../launcher_pad_scope.dart';
import 'gta_vi_backdrop.dart';
import 'gta_vi_content.dart';
import 'gta_vi_widgets.dart';
import 'gta_vi_app_icon.dart';
import 'gta_vi_previews.dart';
import 'gta_vi_media_card.dart';
import 'gta_vi_launch.dart';

class GtaViBody extends StatefulWidget {
  const GtaViBody({super.key, required this.ctrl});
  final PrincipalCtrl ctrl;

  @override
  State<GtaViBody> createState() => _GtaViBodyState();
}

class _GtaViBodyState extends State<GtaViBody> with WindowListener {
  static const _tabs = [
    'Jogos',
    'Cinema',
    'Música',
    'Loja',
    'Vídeos',
    'Notícias'
  ];
  final _primaryAction = FocusNode();
  final _tabsScroll = ScrollController();
  final _tabKeys = List.generate(_tabs.length, (_) => GlobalKey());
  final _previews = GlobalKey<GtaViPreviewsState>();
  final _motion = ValueNotifier(Offset.zero);
  final _gamesScroll = ScrollController();
  final _discovery = InstalledGameDiscovery();
  late final _artwork = GameArtworkService(_discovery);
  int _gameFocusRevision = 0;
  final _contentKeys = [
    GlobalKey<GtaViContentState>(),
    GlobalKey<GtaViContentState>()
  ];
  Timer? _sceneTimer;
  int _section = 0, _scene = 0;
  bool _busy = false, _foreground = true;
  PrincipalCtrl get ctrl => widget.ctrl;
  bool get _active =>
      _foreground &&
      !_busy &&
      !ctrl.mouseBloqueado &&
      (ModalRoute.of(context)?.isCurrent ?? false);

  @override
  void initState() {
    super.initState();
    _section = ctrl.selectedIndexAbaGuias.clamp(0, 3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusSection();
    });
    if (Platform.isWindows) windowManager.addListener(this);
    _sceneTimer = Timer.periodic(const Duration(seconds: 24), (_) {
      if (!mounted ||
          !_active ||
          _section != 0 ||
          MediaQuery.disableAnimationsOf(context)) {
        return;
      }
      _nextScene();
    });
  }

  @override
  void dispose() {
    _sceneTimer?.cancel();
    if (Platform.isWindows) windowManager.removeListener(this);
    _primaryAction.dispose();
    _tabsScroll.dispose();
    _gamesScroll.dispose();
    _artwork.dispose();
    _discovery.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  void onWindowFocus() {
    if (mounted) setState(() => _foreground = true);
  }

  @override
  void onWindowBlur() {
    if (mounted) setState(() => _foreground = false);
  }

  void _nextScene() =>
      setState(() => _scene = (_scene + 1) % GtaViScene.values.length);

  void _showSection(int section) {
    if (_busy || ctrl.mouseBloqueado) return;
    ++_gameFocusRevision;
    setState(() => _section = section);
    ctrl.selectedIndexAbaGuias = section < 4 ? section : 0;
    _motion.value = Offset.zero;
    final revision = _gameFocusRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _section == section && revision == _gameFocusRevision) {
        final tabContext = _tabKeys[section].currentContext;
        if (tabContext != null) {
          unawaited(Scrollable.ensureVisible(tabContext,
              alignment: .5,
              duration: Duration(
                  milliseconds:
                      MediaQuery.disableAnimationsOf(context) ? 0 : 160)));
        }
        _focusSection();
      }
    });
  }

  void _collapse() => _showSection(0);

  void _focusSection({bool results = false}) {
    if (_section >= 4) {
      _contentKeys[_section - 4]
          .currentState
          ?.focusEntry(preferResults: results);
      return;
    }
    final nodes = switch (_section) {
      1 => ctrl.focusNodeCinema,
      2 => ctrl.focusNodeMusica,
      3 => ctrl.focusNodeLoja,
      _ => ctrl.listIconsInicial.isEmpty ? <FocusNode>[] : ctrl.focusNodeIcones,
    };
    if (nodes.isNotEmpty) {
      if (_section == 0) {
        _focusGame(ctrl.selectedIndexIcone, enter: true);
      } else {
        nodes.first.requestFocus();
      }
    } else if (_section == 0) {
      _primaryAction.requestFocus();
    } else {
      _focusGame(ctrl.selectedIndexIcone, enter: true);
    }
  }

  bool _command(String command) {
    if (_busy || ctrl.mouseBloqueado) return true;
    command = switch (command) { 'L1' => 'LB', 'R1' => 'RB', _ => command };
    if (ctrl.focusScopeIcones.hasFocus &&
        (command == 'ESQUERDA' || command == 'DIREITA')) {
      _focusGame(ctrl.selectedIndexIcone + (command == 'DIREITA' ? 1 : -1));
      return true;
    }
    if (ctrl.focusScopeIcones.hasFocus && command == 'CIMA') {
      ++_gameFocusRevision;
      if (_section == 0) {
        _previews.currentState?.focusVideos();
      } else {
        _focusSection(results: true);
      }
      return true;
    }
    if (ctrl.focusScopeIcones.hasFocus && command == 'BAIXO') return true;
    if (_section == 0 && (_previews.currentState?.hasFocus ?? false)) {
      if (command == 'ESQUERDA' || command == 'DIREITA') {
        _previews.currentState!.focusHorizontal(command == 'DIREITA');
        return true;
      }
      if (command == 'BAIXO') {
        _focusGame(ctrl.selectedIndexIcone, enter: true);
        return true;
      }
      if (command == 'CIMA') {
        _primaryAction.requestFocus();
        return true;
      }
    }
    if (_section >= 4 &&
        (_contentKeys[_section - 4].currentState?.handleDirection(command) ??
            false)) {
      return true;
    }
    if (command == 'START') {
      unawaited(ctrl.btnMais());
      return true;
    }
    if (command == 'LB' || command == 'RB') {
      final next = (_section + (command == 'RB' ? 1 : -1)) % _tabs.length;
      _showSection(next);
      return true;
    }
    if (command == '3') {
      final content =
          _section >= 4 ? _contentKeys[_section - 4].currentState : null;
      if (!(content?.back() ?? false)) {
        if (_section != 0) {
          _collapse();
        } else {
          _focusGame(ctrl.selectedIndexIcone, enter: true);
        }
      }
      return true;
    }
    return false;
  }

  void _focusGame(int requested, {bool enter = false}) {
    if (ctrl.listIconsInicial.isEmpty) return;
    final index = requested.clamp(0, ctrl.listIconsInicial.length - 1);
    final revision = ++_gameFocusRevision;
    _selectGame(index);
    if (!_gamesScroll.hasClients) return;
    final position = _gamesScroll.position;
    final target = (index * 82.0 - position.viewportDimension / 2 + 36)
        .clamp(0.0, position.maxScrollExtent);
    unawaited(_gamesScroll
        .animateTo(target,
            duration: Duration(
                milliseconds:
                    MediaQuery.disableAnimationsOf(context) ? 0 : 180),
            curve: Curves.easeOutCubic)
        .then((_) {
      if (mounted &&
          _active &&
          (enter || ctrl.focusScopeIcones.hasFocus) &&
          revision == _gameFocusRevision &&
          index < ctrl.focusNodeIcones.length) {
        ctrl.focusNodeIcones[index].requestFocus();
      }
    }));
  }

  void _selectGame(int index) {
    if (_busy ||
        ctrl.mouseBloqueado ||
        index < 0 ||
        index >= ctrl.listIconsInicial.length) {
      return;
    }
    ctrl.selectedIndexIcone = index;
    ctrl.selectedIndexAbaGuias = 0;
    ctrl.imgFundoStr = ctrl.listIconsInicial[index].imgStr;
    _motion.value = Offset(
        ctrl.listIconsInicial.length < 2
            ? 0
            : (index / (ctrl.listIconsInicial.length - 1)) * 2 - 1,
        .15);
    ctrl.attTela();
  }

  Future<void> _launch(int index) async {
    if (_busy || ctrl.mouseBloqueado) return;
    _selectGame(index);
    if (index < 0 || index >= ctrl.listIconsInicial.length) return;
    final game = ctrl.listIconsInicial[index];
    setState(() => _busy = true);
    final ready = ValueNotifier(false);
    final animation = GlobalKey<GtaViLaunchState>();
    final navigator = Navigator.of(context);
    late final DialogRoute<void> route;
    bool returning = false;

    Future<void> returnToLauncher() async {
      if (returning || !route.isActive) return;
      returning = true;
      await animation.currentState?.leave();
      if (route.isCurrent) navigator.pop();
    }

    route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        builder: (dialogContext) => ValueListenableBuilder<bool>(
              valueListenable: ready,
              builder: (_, started, __) => PopScope<void>(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop && started) unawaited(returnToLauncher());
                  },
                  child: LauncherPadScope(
                    menu: false,
                    onCommand: (command) {
                      if (started && (command == '2' || command == '3')) {
                        unawaited(returnToLauncher());
                      }
                      return true;
                    },
                    child: Dialog.fullscreen(
                        backgroundColor: Colors.transparent,
                        child: GtaViLaunch(
                            key: animation,
                            name: game.nome,
                            ready: ready,
                            onReturn: () => unawaited(returnToLauncher()),
                            background: GtaViBackdrop(
                                scene: _scene,
                                motion: _motion,
                                enabled: false))),
                  )),
            ));
    final completed = navigator.push(route);
    try {
      await ctrl.btnEntrar(apresentarInicializacao: () {
        ready.value = true;
        return completed;
      });
    } finally {
      if (route.isCurrent) await returnToLauncher();
      await route.completed;
      ready.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMedia(int index) async {
    if (_busy || ctrl.mouseBloqueado) return;
    ctrl.selectedIndexAbaGuias = _section;
    setState(() => _busy = true);
    try {
      switch (_section) {
        case 1:
          ctrl.selectedIndexCinema = index;
          await ctrl.movFilmes('2');
        case 2:
          ctrl.selectedIndexMusica = index;
          await ctrl.movMusica('2');
        case 3:
          ctrl.selectedIndexLoja = index;
          await ctrl.movLoja('2');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _header() => Padding(
        padding:
            const EdgeInsets.only(left: 26, right: 260, top: 18, bottom: 8),
        child: ExcludeFocus(
            child: SizedBox(
                height: 48,
                child: SingleChildScrollView(
                  controller: _tabsScroll,
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (var index = 0; index < _tabs.length; index++) ...[
                      GtaViButton(
                          key: _tabKeys[index],
                          selected: _section == index,
                          onPressed: () => _showSection(index),
                          child: Text(_tabs[index],
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                    ],
                    GtaViButton(
                        onPressed: () => ctrl.btnMais(),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Menu'),
                            ])),
                  ]),
                ))),
      );

  Widget _hero(double width) {
    final game = ctrl.listIconsInicial.isEmpty
        ? null
        : ctrl.listIconsInicial[
            ctrl.selectedIndexIcone.clamp(0, ctrl.listIconsInicial.length - 1)];
    return LayoutBuilder(
        builder: (context, bounds) =>
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                          width: (width * .48).clamp(280.0, 660.0),
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Image.asset('assets/GtaVI/logo.png',
                                        height: width < 1000 ? 72 : 100),
                                    const SizedBox(height: 20),
                                    const Text('LEONIDA · DO SEU JEITO',
                                        style: TextStyle(
                                            color: Color(0xFFC5F4E0),
                                            fontSize: 10,
                                            letterSpacing: 3,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 12),
                                    Text('O seu lado\ndo paraíso.',
                                        style: TextStyle(
                                            color: gtaCream,
                                            fontSize: width < 1000 ? 35 : 55,
                                            height: 1.02,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -1.8)),
                                    const SizedBox(height: 14),
                                    Text(
                                        game?.nome ??
                                            'Toda grande história começa com uma escolha.',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Color(0xFFE7CFDF),
                                            fontSize: 17)),
                                    const SizedBox(height: 15),
                                    Wrap(spacing: 18, runSpacing: 8, children: [
                                      GtaViButton(
                                          focusNode: _primaryAction,
                                          onPressed: game == null
                                              ? () => ctrl.btnMais()
                                              : () => _launch(
                                                  ctrl.selectedIndexIcone),
                                          child: Text(game == null
                                              ? '+ Adicionar jogos'
                                              : 'A  Iniciar jogo')),
                                      GtaViButton(
                                          onPressed: _nextScene,
                                          child: Text(
                                              '${GtaViScene.values[_scene].name}  ↻',
                                              style: const TextStyle(
                                                  fontSize: 11))),
                                    ]),
                                  ]))))),
              SizedBox(
                  height: (bounds.maxHeight * .25).clamp(125.0, 155.0),
                  width: (width * .77).clamp(300.0, 1120.0),
                  child: GtaViPreviews(
                      key: _previews,
                      active: _active,
                      onVideos: () => _showSection(4),
                      onNews: () => _showSection(5))),
              const SizedBox(height: 6),
            ]));
  }

  Widget _media() {
    final names = switch (_section) {
      1 => ctrl.listCinema.map((item) => item.nome).toList(),
      2 => ctrl.listMusica.map((item) => item.nome).toList(),
      _ => ctrl.listLojas.map((item) => item.nome).toList(),
    };
    final images = switch (_section) {
      1 => ctrl.listCinema.map((item) => item.imgLocal).toList(),
      2 => ctrl.listMusica.map((item) => item.imgLocal).toList(),
      _ => ctrl.listLojas.map((item) => item.logo).toList(),
    };
    final nodes = switch (_section) {
      1 => ctrl.focusNodeCinema,
      2 => ctrl.focusNodeMusica,
      _ => ctrl.focusNodeLoja,
    };
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0x8857426E), Color(0x3338325C)]),
            borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_tabs[_section],
              style: const TextStyle(
                  color: gtaCream, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Expanded(
              child: names.isEmpty
                  ? const Center(
                      child: Text('Nenhum item disponível.',
                          style: TextStyle(color: gtaCream)))
                  : FocusScope(
                      node: switch (_section) {
                        1 => ctrl.focusScopeCinema,
                        2 => ctrl.focusScopeMusica,
                        _ => ctrl.focusScopeLoja,
                      },
                      child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 230,
                                  mainAxisExtent: 188,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12),
                          itemCount: names.length,
                          itemBuilder: (_, index) => GtaViMediaCard(
                              name: names[index],
                              image: images[index],
                              focusNode:
                                  index < nodes.length ? nodes[index] : null,
                              onPressed: () => _openMedia(index))))),
        ]));
  }

  Widget _library(double height) => Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(36, 8, 36, 6),
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x003E304D), Color(0x70533A61)])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('MEU PC',
              style: TextStyle(
                  color: Color(0xFFC1EDDB),
                  fontSize: 9,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 18),
          Expanded(
              child: Text(
                  ctrl.listIconsInicial.isEmpty
                      ? 'Sua biblioteca'
                      : ctrl
                          .listIconsInicial[ctrl.selectedIndexIcone
                              .clamp(0, ctrl.listIconsInicial.length - 1)]
                          .nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: gtaCream, fontSize: 12))),
          const Text('L1/R1 · Q/E  ABAS    A  ABRIR    B  VOLTAR',
              style: TextStyle(
                  color: Color(0xFFDFC6DB), fontSize: 9, letterSpacing: .8)),
        ]),
        const SizedBox(height: 5),
        Expanded(
            child: ctrl.listIconsInicial.isEmpty
                ? GtaViButton(
                    onPressed: () => ctrl.btnMais(),
                    child: const Text('+ Adicionar jogos'))
                : FocusScope(
                    node: ctrl.focusScopeIcones,
                    child: ListView.separated(
                        controller: _gamesScroll,
                        scrollDirection: Axis.horizontal,
                        itemCount: ctrl.listIconsInicial.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, index) {
                          final game = ctrl.listIconsInicial[index];
                          return SizedBox(
                              key: ValueKey('${game.local}:$index'),
                              width: 72,
                              child: Tooltip(
                                  message: game.nome,
                                  child: GtaViButton(
                                      focusNode: ctrl.focusNodeIcones[index],
                                      bare: true,
                                      onFocusChange: (focused) {
                                        if (focused) _selectGame(index);
                                      },
                                      selected:
                                          index == ctrl.selectedIndexIcone,
                                      padding: const EdgeInsets.all(8),
                                      onPressed: () => _launch(index),
                                      child: AnimatedScale(
                                          scale:
                                              index == ctrl.selectedIndexIcone
                                                  ? 1.12
                                                  : 1,
                                          duration: Duration(
                                              milliseconds: MediaQuery
                                                      .disableAnimationsOf(
                                                          context)
                                                  ? 0
                                                  : 200),
                                          child: GtaViAppIcon(
                                              key: ValueKey(game.local),
                                              game: game,
                                              artwork: _artwork,
                                              size: 36)))));
                        }))),
      ]));

  @override
  Widget build(BuildContext context) => LauncherPadScope(
      enabled: !ctrl.mouseBloqueado && !_busy,
      onCommand: _command,
      child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, event) {
            final command = event.logicalKey == LogicalKeyboardKey.keyQ
                ? 'LB'
                : event.logicalKey == LogicalKeyboardKey.keyE
                    ? 'RB'
                    : null;
            if (command == null) return KeyEventResult.ignored;
            if (event is KeyDownEvent) _command(command);
            return KeyEventResult.handled;
          },
          child: Stack(fit: StackFit.expand, children: [
            RepaintBoundary(
                child: ValueListenableBuilder<Offset>(
                    valueListenable: _motion,
                    builder: (_, __, ___) => GtaViBackdrop(
                        scene: _scene,
                        motion: _motion,
                        enabled: _active && _section == 0))),
            const IgnorePointer(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                  Color(0x9A312B52),
                  Color(0x284D315B),
                  Color(0x003F3155)
                ],
                            stops: [
                  0,
                  .5,
                  1
                ])))),
            LayoutBuilder(
                builder: (context, bounds) => Column(children: [
                      _header(),
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.fromLTRB(36, 4, 36, 12),
                              child: TweenAnimationBuilder<double>(
                                  key: ValueKey(_section),
                                  tween: Tween(begin: 0, end: 1),
                                  duration: Duration(
                                      milliseconds:
                                          MediaQuery.disableAnimationsOf(
                                                  context)
                                              ? 0
                                              : 340),
                                  builder: (_, opacity, child) =>
                                      Opacity(opacity: opacity, child: child),
                                  child: SizedBox.expand(
                                      child: _section == 0
                                          ? _hero(bounds.maxWidth)
                                          : _section < 4
                                              ? _media()
                                              : GtaViContent(
                                                  key: _contentKeys[
                                                      _section - 4],
                                                  news: _section == 5,
                                                  active: _active,
                                                  onClose: _collapse,
                                                  onLibraryFocus: () =>
                                                      _focusGame(
                                                          ctrl.selectedIndexIcone,
                                                          enter: true),
                                                  onOpenSource: (url) async {
                                                    await ctrl.sairDaTelaMedia(
                                                        url,
                                                        'Lendo notícias de GTA VI.');
                                                  }))))),
                      _library(100),
                    ])),
            const LauncherWindowControls(transparent: true),
          ])));
}
