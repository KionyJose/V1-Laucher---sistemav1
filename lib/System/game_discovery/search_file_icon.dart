import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win;

import '../windows_app_catalog.dart' show WindowsItemIcon;

// Adaptado do núcleo de window_icon_service.dart do nav_flutuante:
// ExtractIconExW -> DIB com DC da tela -> DrawIconEx -> máscara/alfa -> BGRA.
// Aqui a chave é o caminho/índice do recurso, pois o app pode estar fechado.
final _extractIconEx = DynamicLibrary.open('shell32.dll').lookupFunction<
    Uint32 Function(
        Pointer<Utf16>, Int32, Pointer<IntPtr>, Pointer<IntPtr>, Uint32),
    int Function(Pointer<Utf16>, int, Pointer<IntPtr>, Pointer<IntPtr>,
        int)>('ExtractIconExW');
final _drawIconEx = DynamicLibrary.open('user32.dll').lookupFunction<
    Int32 Function(
        IntPtr, Int32, Int32, IntPtr, Int32, Int32, Uint32, IntPtr, Uint32),
    int Function(int, int, int, int, int, int, int, int, int)>('DrawIconEx');
final _flush = DynamicLibrary.open('gdi32.dll')
    .lookupFunction<Int32 Function(), int Function()>('GdiFlush');

Future<WindowsItemIcon?> readSearchFileIcon(String filename,
    {int index = 0}) async {
  if (!Platform.isWindows || filename.isEmpty) return null;
  return Isolate.run(() => _extractFileIcon(filename, index));
}

WindowsItemIcon? _extractFileIcon(String filename, int index) {
  final nativePath = filename.toNativeUtf16();
  final large = calloc<IntPtr>();
  final small = calloc<IntPtr>();
  try {
    // Como no nav_flutuante, tentamos os dois HICON. O índice também pode ser
    // um ID negativo de recurso registrado em DLL/EXE ou no próprio atalho.
    _extractIconEx(nativePath, index, large, small, 1);
    for (final handle in {large.value, small.value}) {
      if (handle == 0) continue;
      final image = _render(handle);
      if (image != null) return image;
    }
    return null;
  } finally {
    if (large.value != 0) win.DestroyIcon(large.value);
    if (small.value != 0 && small.value != large.value) {
      win.DestroyIcon(small.value);
    }
    calloc.free(nativePath);
    calloc.free(large);
    calloc.free(small);
  }
}

WindowsItemIcon? _render(int handle) {
  const side = 96;
  const byteCount = side * side * 4;
  final screen = win.GetDC(0);
  if (screen == 0) return null;
  final headerSize = sizeOf<win.BITMAPINFOHEADER>();
  final info = calloc<Uint8>(headerSize + 16).cast<win.BITMAPINFOHEADER>();
  final bits = calloc<Pointer<Void>>();
  var dc = 0;
  var bitmap = 0;
  var previous = 0;
  try {
    info.ref
      ..biSize = headerSize
      ..biWidth = side
      ..biHeight = -side
      ..biPlanes = 1
      ..biBitCount = 32
      ..biCompression = 0; // BI_RGB.
    bitmap = win.CreateDIBSection(screen, info.cast(), 0, bits, 0, 0);
    if (bitmap == 0 || bits.value == nullptr) return null;
    dc = win.CreateCompatibleDC(screen);
    if (dc == 0) return null;
    previous = win.SelectObject(dc, bitmap);
    if (previous == 0 || previous == -1) return null;
    final raw = bits.value.cast<Uint8>().asTypedList(byteCount);
    raw.fillRange(0, byteCount, 0);
    if (_drawIconEx(dc, 0, 0, handle, side, side, 0, 0, 3) == 0) return null;
    _flush();
    final pixels = Uint8List.fromList(raw);
    var hasAlpha = false;
    for (var i = 3; i < byteCount; i += 4) {
      if (pixels[i] != 0) {
        hasAlpha = true;
        break;
      }
    }
    if (!hasAlpha) {
      raw.fillRange(0, byteCount, 0);
      final maskDrawn = _drawIconEx(dc, 0, 0, handle, side, side, 0, 0, 1) != 0;
      _flush();
      for (var i = 0; i < byteCount; i += 4) {
        final alpha = maskDrawn && raw[i] != 0 ? 0 : 255;
        pixels[i + 3] = alpha;
        if (alpha == 0) {
          pixels[i] = pixels[i + 1] = pixels[i + 2] = 0;
        }
      }
    }
    // DrawIconEx sobre DIB transparente já entrega ícones modernos com alfa
    // pré-multiplicado. A máscara acima trata os ícones legados (alfa 0/255).
    if (!pixels.indexed.any((p) => p.$1 % 4 == 3 && p.$2 != 0)) return null;
    return WindowsItemIcon(side, side, pixels);
  } finally {
    if (dc != 0) {
      if (previous != 0 && previous != -1) win.SelectObject(dc, previous);
      win.DeleteDC(dc);
    }
    if (bitmap != 0) win.DeleteObject(bitmap);
    calloc.free(bits);
    calloc.free(info);
    win.ReleaseDC(0, screen);
  }
}
