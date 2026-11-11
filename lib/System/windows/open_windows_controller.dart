import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'window_icon_service.dart';
import 'window_list_service.dart';

class OpenWindowsController extends ChangeNotifier {
  final WindowListService windowList = WindowListService();
  final WindowIconService icons = WindowIconService();
  List<OpenAppWindow> windows = const [];
  Timer? _timer;
  bool _refreshing = false;
  bool _disposed = false;

  OpenWindowsController() {
    icons.addListener(_iconsChanged);
  }

  void _iconsChanged() {
    if (!_disposed) notifyListeners();
  }

  void start({Duration interval = const Duration(seconds: 3)}) {
    if (_disposed || !Platform.isWindows || _timer != null) return;
    unawaited(refresh());
    _timer = Timer.periodic(interval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    if (_disposed || _refreshing) return;
    _refreshing = true;
    try {
      final live = await windowList.list();
      if (_disposed) return;
      windows = List.unmodifiable(live);
      icons.retainWindows(windows);
      notifyListeners();
      await icons.resolveAll(windows.map((w) => w.hwnd));
    } catch (error) {
      debugPrint('[WINDOWS] Não foi possível atualizar as janelas: $error');
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    icons.removeListener(_iconsChanged);
    icons.dispose();
    super.dispose();
  }
}
