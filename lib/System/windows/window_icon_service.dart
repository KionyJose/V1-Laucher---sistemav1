import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'window_native.dart';

Future<Map<int, NativeWindowIcon?>> _nativeBatch(List<int> hwnds) =>
    Isolate.run(
        () => {for (final hwnd in hwnds) hwnd: readOpenWindowIcon(hwnd)});

/// O serviço possui as imagens. Consumidores de cached() não devem destruí-las.
class WindowIconService extends ChangeNotifier {
  final _cache = <int, ui.Image?>{};
  final _tokens = <int, int>{};
  final _identities = <int, String>{};
  final _pending = <int>{};
  Set<int> _live = {};
  int _sequence = 0;
  bool _disposed = false;

  ui.Image? cached(int hwnd) => _cache[hwnd];
  bool hasResolved(int hwnd) => _cache.containsKey(hwnd);

  void _evict(int hwnd) {
    _cache.remove(hwnd)?.dispose();
    _tokens.remove(hwnd);
    _identities.remove(hwnd);
    _pending.remove(hwnd);
  }

  void retainOnly(Iterable<int> liveHwnds) {
    if (_disposed) return;
    _live = liveHwnds.toSet();
    for (final hwnd in {
      ..._cache.keys,
      ..._tokens.keys,
      ..._identities.keys,
      ..._pending
    }) {
      if (!_live.contains(hwnd)) _evict(hwnd);
    }
  }

  /// HWND pode ser reutilizado depois que outra janela fecha.
  void retainWindows(Iterable<OpenAppWindow> windows) {
    if (_disposed) return;
    final snapshot = windows.toList();
    retainOnly(snapshot.map((w) => w.hwnd));
    for (final window in snapshot) {
      final identity = '${window.pid}|${window.executablePath}';
      final previous = _identities[window.hwnd];
      if (previous != null && previous != identity) _evict(window.hwnd);
      _identities[window.hwnd] = identity;
    }
  }

  Future<void> resolveAll(Iterable<int> hwnds) async {
    if (_disposed || !Platform.isWindows) return;
    final missing = hwnds
        .toSet()
        .where((h) => !_cache.containsKey(h) && !_pending.contains(h))
        .toList();
    _live.addAll(missing);
    for (final hwnd in missing) {
      _pending.add(hwnd);
    }
    // Um isolate por lote, em vez de um isolate para cada ícone a cada frame.
    for (var start = 0; start < missing.length && !_disposed; start += 6) {
      final batch = missing.skip(start).take(6).where(_live.contains).toList();
      final tokens = {for (final h in batch) h: ++_sequence};
      _tokens.addAll(tokens);
      Map<int, NativeWindowIcon?> pixels;
      try {
        pixels = await _nativeBatch(batch);
      } catch (_) {
        pixels = {for (final hwnd in batch) hwnd: null};
      }
      for (final hwnd in batch) {
        if (_disposed ||
            !_live.contains(hwnd) ||
            _tokens[hwnd] != tokens[hwnd]) {
          continue;
        }
        ui.Image? image;
        final raw = pixels[hwnd];
        if (raw != null) {
          try {
            final decoded = Completer<ui.Image>();
            ui.decodeImageFromPixels(raw.bgra, raw.width, raw.height,
                ui.PixelFormat.bgra8888, decoded.complete);
            image = await decoded.future;
          } catch (_) {
            image = null;
          }
        }
        if (_disposed ||
            !_live.contains(hwnd) ||
            _tokens[hwnd] != tokens[hwnd]) {
          image?.dispose();
          continue;
        }
        _cache[hwnd] = image; // Falhas (null) também ficam em cache.
        _pending.remove(hwnd);
      }
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final image in _cache.values) {
      image?.dispose();
    }
    _cache.clear();
    _live.clear();
    _tokens.clear();
    _identities.clear();
    _pending.clear();
    super.dispose();
  }
}
