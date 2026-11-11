import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart' as win;

class OpenAppWindow {
  const OpenAppWindow(
      {required this.hwnd,
      required this.pid,
      required this.title,
      required this.processName,
      required this.executablePath});
  final int hwnd;
  final int pid;
  final String title;
  final String processName;
  final String executablePath;
}

class NativeWindowIcon {
  const NativeWindowIcon(this.bgra, {this.width = 32, this.height = 32});
  final Uint8List bgra;
  final int width;
  final int height;
}

String _processPath(int pid) {
  if (pid == 0) return '';
  final process = win.OpenProcess(
      win.PROCESS_ACCESS_RIGHTS.PROCESS_QUERY_LIMITED_INFORMATION, 0, pid);
  if (process == 0) return '';
  final text = calloc<Uint16>(32768).cast<Utf16>();
  final length = calloc<Uint32>()..value = 32768;
  try {
    return win.QueryFullProcessImageName(process, 0, text, length) != 0
        ? text.toDartString(length: length.value)
        : '';
  } finally {
    calloc.free(text);
    calloc.free(length);
    win.CloseHandle(process);
  }
}

int _pid(int hwnd) {
  final pid = calloc<Uint32>();
  try {
    win.GetWindowThreadProcessId(hwnd, pid);
    return pid.value;
  } finally {
    calloc.free(pid);
  }
}

/// ApplicationFrameHost é apenas o host visual. A CoreWindow identifica
/// o executável do aplicativo UWP que realmente aparece dentro da janela.
String _applicationPath(int hwnd, String ownerPath) {
  if (path.windows.basename(ownerPath).toLowerCase() !=
      'applicationframehost.exe') {
    return ownerPath;
  }
  var realPath = '';
  final className = calloc<Uint16>(256).cast<Utf16>();
  final callback =
      NativeCallable<win.WNDENUMPROC>.isolateLocal((int child, int _) {
    try {
      if (win.GetClassName(child, className, 256) > 0 &&
          className.toDartString() == 'Windows.UI.Core.CoreWindow') {
        realPath = _processPath(_pid(child));
        if (realPath.isNotEmpty) return 0;
      }
    } catch (_) {/* Uma janela pode fechar durante a enumeração. */}
    return 1;
  }, exceptionalReturn: 1);
  try {
    win.EnumChildWindows(hwnd, callback.nativeFunction, 0);
    return realPath.isEmpty ? ownerPath : realPath;
  } finally {
    callback.close();
    calloc.free(className);
  }
}

/// Chamado exclusivamente no isolate de trabalho; não abre processos externos.
List<OpenAppWindow> enumerateOpenWindows() {
  final result = <OpenAppWindow>[];
  final paths = <int, String>{};
  final ownPid = win.GetCurrentProcessId();
  final cloaked = calloc<Uint32>();
  final callback =
      NativeCallable<win.WNDENUMPROC>.isolateLocal((int hwnd, int _) {
    try {
      if (win.IsWindowVisible(hwnd) == 0 ||
          win.GetWindow(hwnd, win.GET_WINDOW_CMD.GW_OWNER) != 0 ||
          (win.GetWindowLongPtr(hwnd, -20) &
                  win.WINDOW_EX_STYLE.WS_EX_TOOLWINDOW) !=
              0) {
        return 1;
      }
      final length = win.GetWindowTextLength(hwnd);
      if (length <= 0 || length > 32767) return 1;
      cloaked.value = 0;
      // DWMWA_CLOAKED exclui UWP suspenso e janelas de outros desktops.
      if (win.DwmGetWindowAttribute(hwnd, 14, cloaked, sizeOf<Uint32>()) >= 0 &&
          cloaked.value != 0) {
        return 1;
      }
      final pid = _pid(hwnd);
      if (pid == 0 || pid == ownPid) return 1;
      final title = calloc<Uint16>(length + 1).cast<Utf16>();
      try {
        final count = win.GetWindowText(hwnd, title, length + 1);
        if (count <= 0) return 1;
        final ownerPath = paths.putIfAbsent(pid, () => _processPath(pid));
        final executable = _applicationPath(hwnd, ownerPath);
        result.add(OpenAppWindow(
            hwnd: hwnd,
            pid: pid,
            title: title.toDartString(length: count),
            processName: path.windows.basename(executable),
            executablePath: executable));
      } finally {
        calloc.free(title);
      }
    } catch (_) {/* Acesso negado não interrompe as demais janelas. */}
    return 1;
  }, exceptionalReturn: 1);
  try {
    win.EnumWindows(callback.nativeFunction, 0);
  } finally {
    callback.close();
    calloc.free(cloaked);
  }
  result.sort((a, b) {
    final process =
        a.processName.toLowerCase().compareTo(b.processName.toLowerCase());
    return process != 0
        ? process
        : a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return result;
}

// Bindings ausentes no win32 5.5.4. Handles são IntPtr em Windows x64.
final _drawIconEx = DynamicLibrary.open('user32.dll').lookupFunction<
    Int32 Function(
        IntPtr, Int32, Int32, IntPtr, Int32, Int32, Uint32, IntPtr, Uint32),
    int Function(int, int, int, int, int, int, int, int, int)>('DrawIconEx');
final _extractIconEx = DynamicLibrary.open('shell32.dll').lookupFunction<
    Uint32 Function(
        Pointer<Utf16>, Int32, Pointer<IntPtr>, Pointer<IntPtr>, Uint32),
    int Function(Pointer<Utf16>, int, Pointer<IntPtr>, Pointer<IntPtr>,
        int)>('ExtractIconExW');

final _gdiFlush = DynamicLibrary.open('gdi32.dll')
    .lookupFunction<Int32 Function(), int Function()>('GdiFlush');
final _privateExtractIcons = DynamicLibrary.open('user32.dll').lookupFunction<
    Uint32 Function(Pointer<Utf16>, Int32, Int32, Int32, Pointer<IntPtr>,
        Pointer<Uint32>, Uint32, Uint32),
    int Function(Pointer<Utf16>, int, int, int, Pointer<IntPtr>,
        Pointer<Uint32>, int, int)>('PrivateExtractIconsW');

/// Ícones de WM_GETICON e da classe são emprestados: nunca os destruímos.
NativeWindowIcon? readOpenWindowIcon(int hwnd) {
  if (win.IsWindow(hwnd) == 0) return null;
  final response = calloc<IntPtr>();
  final clock = Stopwatch()..start();
  try {
    for (final kind in [win.ICON_BIG, win.ICON_SMALL2, win.ICON_SMALL]) {
      final remaining = 120 - clock.elapsedMilliseconds;
      if (remaining <= 0) break;
      response.value = 0;
      // SendMessage sem prazo bloquearia também em aplicativos hung.
      final replied = win.SendMessageTimeout(
          hwnd,
          win.WM_GETICON,
          kind,
          0,
          win.SEND_MESSAGE_TIMEOUT_FLAGS.SMTO_ABORTIFHUNG |
              win.SEND_MESSAGE_TIMEOUT_FLAGS.SMTO_BLOCK |
              win.SEND_MESSAGE_TIMEOUT_FLAGS.SMTO_ERRORONEXIT,
          remaining,
          response);
      if (replied == 0) break;
      if (response.value != 0) {
        final icon = _rasterize(response.value);
        if (icon != null) return icon;
      }
    }
    for (final index in [
      win.GET_CLASS_LONG_INDEX.GCLP_HICON,
      win.GET_CLASS_LONG_INDEX.GCLP_HICONSM
    ]) {
      final handle = win.GetClassLongPtr(hwnd, index);
      if (handle != 0) {
        final icon = _rasterize(handle);
        if (icon != null) return icon;
      }
    }
    // Janelas sem ícone próprio herdam o ícone do executável. Para UWP,
    // consulta a CoreWindow em vez de extrair o ícone genérico do host.
    final executable = _applicationPath(hwnd, _processPath(_pid(hwnd)));
    return executable.isEmpty ? null : readExecutableIcon(executable, size: 32);
  } finally {
    calloc.free(response);
  }
}

/// Apenas os HICON retornados por ExtractIconEx pertencem a este serviço.
NativeWindowIcon? readExecutableIcon(String executable,
    {int index = 0, int size = 256}) {
  if (executable.isEmpty) return null;
  final filename = executable.toNativeUtf16();
  final big = calloc<IntPtr>();
  final small = calloc<IntPtr>();
  final iconId = calloc<Uint32>();
  try {
    for (final dimension
        in [256, 128, 96, 64, 48, 32].where((s) => s <= size)) {
      final count = _privateExtractIcons(
          filename, index, dimension, dimension, big, iconId, 1, 0);
      if (count != 0 && count != 0xffffffff && big.value != 0) {
        try {
          final image = _rasterize(big.value, side: dimension);
          if (image != null) return image;
        } finally {
          win.DestroyIcon(big.value);
          big.value = 0;
        }
      }
    }
    if (_extractIconEx(filename, index, big, small, 1) == 0) return null;
    return (big.value == 0 ? null : _rasterize(big.value)) ??
        (small.value == 0 ? null : _rasterize(small.value));
  } finally {
    if (big.value != 0) win.DestroyIcon(big.value);
    if (small.value != 0 && small.value != big.value) {
      win.DestroyIcon(small.value);
    }
    calloc.free(filename);
    calloc.free(big);
    calloc.free(small);
    calloc.free(iconId);
  }
}

NativeWindowIcon? rasterizeShellIcon(int hicon) => _rasterize(hicon, side: 96);

NativeWindowIcon? _rasterize(int hicon, {int side = 32}) {
  final byteCount = side * side * 4;
  final screen = win.GetDC(0);
  if (screen == 0) return null;
  final info = calloc<win.BITMAPINFO>();
  final bits = calloc<Pointer<Void>>();
  final dc = win.CreateCompatibleDC(screen);
  var bitmap = 0;
  var previous = 0;
  try {
    if (dc == 0) return null;
    info.ref.bmiHeader
      ..biSize = sizeOf<win.BITMAPINFOHEADER>()
      ..biWidth = side
      ..biHeight = -side
      ..biPlanes = 1
      ..biBitCount = 32;
    bitmap = win.CreateDIBSection(screen, info, 0, bits, 0, 0);
    if (bitmap == 0 || bits.value == nullptr) return null;
    previous = win.SelectObject(dc, bitmap);
    if (previous == 0 || previous == -1) return null;
    final dib = bits.value.cast<Uint8>().asTypedList(byteCount);
    dib.fillRange(0, byteCount, 0);
    if (_drawIconEx(dc, 0, 0, hicon, side, side, 0, 0, 3) == 0) return null;
    _gdiFlush(); // Sincroniza o GDI antes de acessar diretamente o DIB.
    final bgra = Uint8List.fromList(dib);
    var hasAlpha = false;
    for (var i = 3; i < byteCount; i += 4) {
      if (bgra[i] != 0) {
        hasAlpha = true;
        break;
      }
    }
    if (!hasAlpha) {
      // Ícone legado: DI_MASK fornece branco nos pixels transparentes.
      // Reconstrói alfa e pré-multiplica também os pixels das bordas.
      dib.fillRange(0, byteCount, 0);
      if (_drawIconEx(dc, 0, 0, hicon, side, side, 0, 0, 1) == 0) return null;
      _gdiFlush();
      for (var i = 0; i < byteCount; i += 4) {
        final alpha = 255 - dib[i];
        bgra[i + 3] = alpha;
        for (var channel = 0; channel < 3; channel++) {
          bgra[i + channel] = (bgra[i + channel] * alpha + 127) ~/ 255;
        }
      }
    }
    // DrawIconEx usa AC_SRC_OVER para ícones modernos: desenhar sobre o DIB
    // zerado já produz BGRA pré-multiplicado. Multiplicar novamente escureceria
    // as bordas. https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-drawiconex
    return NativeWindowIcon(bgra, width: side, height: side);
  } finally {
    if (previous != 0 && previous != -1) win.SelectObject(dc, previous);
    if (bitmap != 0) win.DeleteObject(bitmap);
    if (dc != 0) win.DeleteDC(dc);
    calloc.free(info);
    calloc.free(bits);
    win.ReleaseDC(0, screen);
  }
}
