import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win;

// Ausente na versão de win32 utilizada pelo projeto.
final _getLastActivePopup = DynamicLibrary.open('user32.dll')
    .lookupFunction<IntPtr Function(IntPtr), int Function(int)>(
        'GetLastActivePopup');

/// Protege somente a janela deste processo e preserva seus diálogos nativos.
class PinnedLauncherWindow {
  static const _topmost = -1;
  static const _notTopmost = -2;
  int _hwnd = 0;

  int _processId(int hwnd) {
    final process = calloc<Uint32>();
    try {
      win.GetWindowThreadProcessId(hwnd, process);
      return process.value;
    } finally {
      calloc.free(process);
    }
  }

  int get handle {
    if (!Platform.isWindows) return 0;
    final ownProcess = win.GetCurrentProcessId();
    if (_hwnd != 0 &&
        win.IsWindow(_hwnd) != 0 &&
        _processId(_hwnd) == ownProcess) {
      return _hwnd;
    }
    _hwnd = 0;
    final className = calloc<Uint16>(256).cast<Utf16>();
    final callback =
        NativeCallable<win.WNDENUMPROC>.isolateLocal((int hwnd, int _) {
      if (_processId(hwnd) == ownProcess &&
          win.GetClassName(hwnd, className, 256) > 0 &&
          className.toDartString() == 'FLUTTER_RUNNER_WIN32_WINDOW') {
        _hwnd = hwnd;
        return 0;
      }
      return 1;
    }, exceptionalReturn: 1);
    try {
      win.EnumWindows(callback.nativeFunction, 0);
      return _hwnd;
    } finally {
      callback.close();
      calloc.free(className);
    }
  }

  bool get foregroundOwned {
    if (!Platform.isWindows) return false;
    final foreground = win.GetForegroundWindow();
    return foreground != 0 &&
        _processId(foreground) == win.GetCurrentProcessId();
  }

  void setPinned(bool pinned) {
    final hwnd = handle;
    if (hwnd == 0) return;
    // NOACTIVATE permite reposicionar sem tirar o foco de um diálogo próprio.
    win.SetWindowPos(
        hwnd,
        pinned ? _topmost : _notTopmost,
        0,
        0,
        0,
        0,
        win.SET_WINDOW_POS_FLAGS.SWP_NOMOVE |
            win.SET_WINDOW_POS_FLAGS.SWP_NOSIZE |
            win.SET_WINDOW_POS_FLAGS.SWP_NOACTIVATE);
  }

  void bringToFront({required bool pinned}) {
    final hwnd = handle;
    if (hwnd == 0) return;
    if (win.IsIconic(hwnd) != 0) {
      win.ShowWindowAsync(hwnd, win.SHOW_WINDOW_CMD.SW_RESTORE);
    }
    final popup = _getLastActivePopup(hwnd);
    final target = popup != 0 &&
            win.IsWindowVisible(popup) != 0 &&
            _processId(popup) == win.GetCurrentProcessId()
        ? popup
        : hwnd;
    setPinned(pinned);
    if (target != hwnd && pinned) {
      win.SetWindowPos(
          target,
          _topmost,
          0,
          0,
          0,
          0,
          win.SET_WINDOW_POS_FLAGS.SWP_NOMOVE |
              win.SET_WINDOW_POS_FLAGS.SWP_NOSIZE |
              win.SET_WINDOW_POS_FLAGS.SWP_NOACTIVATE);
    }
    // Reafirma a ordem Z mesmo se outra janela TOPMOST cobrir o launcher
    // sem mudar o foreground. Foco só é recuperado se saiu deste processo.
    if (!foregroundOwned) win.SetForegroundWindow(target);
  }
}
