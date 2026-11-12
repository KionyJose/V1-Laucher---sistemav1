import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'slim_mode_config_controller.dart';
import '../System/windows/pinned_launcher_window.dart';

/// Geometria e transparência da janela, independentes da apresentação dos cards.
class LauncherWindowController with WindowListener, ScreenListener {
  LauncherWindowController._();
  static final instance = LauncherWindowController._();

  /// Fração da altura útil do monitor reservada à faixa inferior do Slim.
  static const slimScale = .85;
  static const slimHeightFraction = .30 * slimScale;
  Future<void> _pending = Future.value();
  bool _initialized = false;
  bool _applying = false;
  bool _pinned = true;
  Timer? _dockTimer;
  Timer? _pinTimer;
  final nativeWindow = PinnedLauncherWindow();
  Rect? _dockBounds;
  int _contentDepth = 0;

  bool get docked =>
      SlimModeConfigController.active.value && _contentDepth == 0;

  Future<void> initialize() async {
    if (!Platform.isWindows || _initialized) return;
    _initialized = true;
    SlimModeConfigController.active.addListener(_modeChanged);
    windowManager.addListener(this);
    screenRetriever.addListener(this);
    await apply();
  }

  void dispose() {
    if (!_initialized) return;
    SlimModeConfigController.active.removeListener(_modeChanged);
    windowManager.removeListener(this);
    screenRetriever.removeListener(this);
    _dockTimer?.cancel();
    _pinTimer?.cancel();
    _pinTimer = null;
    nativeWindow.setPinned(false);
    _initialized = false;
  }

  void _modeChanged() => unawaited(apply());

  Future<void> apply() {
    if (!Platform.isWindows) return Future.value();
    _pending = _pending.then((_) => _apply()).catchError((Object error) {
      debugPrint('Não foi possível aplicar a janela do launcher: $error');
    });
    return _pending;
  }

  Future<void> _apply() async {
    _applying = true;
    try {
      if (await windowManager.isMinimized()) await windowManager.restore();
      if (docked) {
        final bounds = await windowManager.getBounds();
        final displays = await screenRetriever.getAllDisplays();
        final monitor = displays.where((display) {
              final origin = display.visiblePosition ?? Offset.zero;
              return (origin & (display.visibleSize ?? display.size))
                  .contains(bounds.center);
            }).firstOrNull ??
            await screenRetriever.getPrimaryDisplay();
        final area = (monitor.visiblePosition ?? Offset.zero) &
            (monitor.visibleSize ?? monitor.size);
        // Compensa a faixa residual da barra oculta deslocando a janela para
        // baixo pela diferença real até o fim do monitor. A tolerância inclui
        // os 3 pixels observados e o arredondamento das medidas do Windows.
        // Reservas maiores continuam respeitadas para a barra visível.
        final bottomGap = monitor.size.height - area.height;
        const revealStrip = 4.0;
        final dockBottom = area.bottom +
            (bottomGap > 0 && bottomGap <= revealStrip ? bottomGap : 0);
        final height = area.height * slimHeightFraction;
        if (await windowManager.isMaximized()) await windowManager.unmaximize();
        await windowManager.setAsFrameless();
        await windowManager.setBackgroundColor(Colors.transparent);
        await windowManager.setHasShadow(false);
        await windowManager.setResizable(false);
        await windowManager.setMaximizable(false);
        _dockBounds = Rect.fromLTWH(
          area.left,
          dockBottom - height,
          area.width,
          height,
        );
        await windowManager.setBounds(_dockBounds!);
      } else {
        _dockBounds = null;
        await windowManager.setResizable(true);
        await windowManager.setMaximizable(true);
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        await windowManager.setBackgroundColor(Colors.black);
        await windowManager.setHasShadow(true);
        await windowManager.maximize();
      }
    } finally {
      _applying = false;
      _syncPin();
    }
  }

  Future<void> openContent() async {
    ++_contentDepth;
    if (SlimModeConfigController.active.value) await apply();
  }

  Future<void> setPinned(bool pinned) async {
    _pinned = pinned;
    _syncPin();
  }

  void _syncPin() {
    if (!Platform.isWindows || !_initialized) return;
    nativeWindow.setPinned(_pinned);
    if (!_pinned) {
      _pinTimer?.cancel();
      _pinTimer = null;
      return;
    }
    recoverPinnedWindow();
    _pinTimer ??= Timer.periodic(const Duration(milliseconds: 350), (_) {
      recoverPinnedWindow();
    });
  }

  void recoverPinnedWindow() {
    if (!_initialized || !_pinned || _applying) return;
    nativeWindow.bringToFront(pinned: true);
  }

  Future<void> bringToFront() async {
    if (!Platform.isWindows) return;
    if (docked) await apply();
    await windowManager.show();
    nativeWindow.bringToFront(pinned: _pinned);
  }

  @override
  void onWindowBlur() => recoverPinnedWindow();

  @override
  void onWindowRestore() => recoverPinnedWindow();

  @override
  void onWindowClose() => dispose();

  Future<void> closeContent() async {
    if (_contentDepth > 0) --_contentDepth;
    if (SlimModeConfigController.active.value) await apply();
  }

  void _scheduleDock() {
    if (!_initialized || _applying || !docked) return;
    _dockTimer?.cancel();
    _dockTimer = Timer(const Duration(milliseconds: 150), () async {
      if (!_initialized || _applying || !docked) return;
      final current = await windowManager.getBounds();
      final target = _dockBounds;
      // Windows arredonda pixels físicos em monitores com escala de DPI.
      if (target == null ||
          (current.left - target.left).abs() > 1 ||
          (current.top - target.top).abs() > 1 ||
          (current.width - target.width).abs() > 1 ||
          (current.height - target.height).abs() > 1) {
        await apply();
      }
    });
  }

  @override
  void onWindowMove() => _scheduleDock();

  @override
  void onWindowResize() => _scheduleDock();

  @override
  void onScreenEvent(String eventName) {
    _dockBounds = null;
    _scheduleDock();
  }
}
