import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win;
import 'windows/window_native.dart' show readExecutableIcon, rasterizeShellIcon;

class WindowsShellApplication {
  const WindowsShellApplication(this.name, this.target, this.filePath,
      {this.packageRoot = '', this.appUserModelId = ''});
  final String name;
  final String target;
  final String filePath;
  final String packageRoot;
  final String appUserModelId;
}

final _packagesByFamily = DynamicLibrary.open('kernel32.dll').lookupFunction<
    Int32 Function(Pointer<Utf16>, Pointer<Uint32>, Pointer<Pointer<Utf16>>,
        Pointer<Uint32>, Pointer<Utf16>),
    int Function(Pointer<Utf16>, Pointer<Uint32>, Pointer<Pointer<Utf16>>,
        Pointer<Uint32>, Pointer<Utf16>)>('GetPackagesByPackageFamily');
final _packagePath = DynamicLibrary.open('kernel32.dll').lookupFunction<
    Int32 Function(Pointer<Utf16>, Pointer<Uint32>, Pointer<Utf16>),
    int Function(Pointer<Utf16>, Pointer<Uint32>,
        Pointer<Utf16>)>('GetPackagePathByFullName');

String _registeredPackageRoot(String family) {
  final nativeFamily = family.toNativeUtf16();
  final count = calloc<Uint32>();
  final length = calloc<Uint32>();
  Pointer<Pointer<Utf16>>? names;
  Pointer<Utf16>? buffer;
  try {
    _packagesByFamily(nativeFamily, count, nullptr, length, nullptr);
    if (count.value == 0 || count.value > 100 || length.value > 1048576) {
      return '';
    }
    names = calloc<Pointer<Utf16>>(count.value);
    buffer = calloc<Uint16>(length.value).cast<Utf16>();
    if (_packagesByFamily(nativeFamily, count, names, length, buffer) != 0) {
      return '';
    }
    for (var i = 0; i < count.value; i++) {
      final pathLength = calloc<Uint32>();
      Pointer<Utf16>? root;
      try {
        _packagePath(names[i], pathLength, nullptr);
        if (pathLength.value == 0 || pathLength.value > 32768) continue;
        root = calloc<Uint16>(pathLength.value).cast<Utf16>();
        if (_packagePath(names[i], pathLength, root) == 0) {
          return root.toDartString();
        }
      } finally {
        if (root != null) calloc.free(root);
        calloc.free(pathLength);
      }
    }
    return '';
  } finally {
    if (names != null) calloc.free(names);
    if (buffer != null) calloc.free(buffer);
    calloc.free(nativeFamily);
    calloc.free(count);
    calloc.free(length);
  }
}

class WindowsItemIcon {
  const WindowsItemIcon(this.width, this.height, this.pixels);
  final int width;
  final int height;
  final Uint8List pixels;
}

Future<List<String>> readWindowsDesktopDirectories() async {
  if (!Platform.isWindows) return [];
  return Isolate.run(() {
    final results = <String>[];
    for (final id in [win.FOLDERID_Desktop, win.FOLDERID_PublicDesktop]) {
      final guid = win.convertToIID(id);
      final output = calloc<Pointer<Utf16>>();
      try {
        if (!win.FAILED(win.SHGetKnownFolderPath(guid, 0, 0, output))) {
          results.add(output.value.toDartString());
        }
      } finally {
        if (output.value != nullptr) win.CoTaskMemFree(output.value);
        calloc.free(output);
        calloc.free(guid);
      }
    }
    return results;
  });
}

void _release(win.IUnknown? object) {
  if (object == null) return;
  object.detach();
  object.release();
  calloc.free(object.ptr);
}

win.IShellItem? _shellItem(String target) {
  final name = target.toNativeUtf16();
  final iid = win.convertToIID(win.IID_IShellItem);
  final output = calloc<win.COMObject>();
  try {
    if (win.FAILED(
        win.SHCreateItemFromParsingName(name, nullptr, iid, output.cast()))) {
      calloc.free(output);
      return null;
    }
    return win.IShellItem(output);
  } finally {
    calloc.free(name);
    calloc.free(iid);
  }
}

String _displayName(win.IShellItem item, int kind) {
  final output = calloc<Pointer<Utf16>>();
  try {
    if (win.FAILED(item.getDisplayName(kind, output))) return '';
    return output.value.toDartString();
  } finally {
    if (output.value != nullptr) win.CoTaskMemFree(output.value);
    calloc.free(output);
  }
}

/// Enumera a mesma pasta virtual do Explorer, incluindo aplicativos da Store.
/// Toda a consulta COM roda fora da thread que desenha a interface.
Future<List<WindowsShellApplication>> readWindowsAppsFolder() async {
  if (!Platform.isWindows) return [];
  return Isolate.run(_readAppsFolder);
}

List<WindowsShellApplication> _readAppsFolder() {
  final initialized =
      win.CoInitializeEx(nullptr, win.COINIT.COINIT_APARTMENTTHREADED);
  if (win.FAILED(initialized)) return [];
  win.IShellItem? item;
  win.IShellFolder? folder;
  win.IEnumIDList? enumerator;
  final handler = win.convertToIID('{3981E225-F559-11D3-8E3A-00C04F6837D5}');
  final folderId = win.convertToIID(win.IID_IShellFolder);
  final folderOutput = calloc<win.COMObject>();
  final enumOutput = calloc<win.COMObject>();
  final child = calloc<Pointer<win.ITEMIDLIST>>();
  final fetched = calloc<Uint32>();
  final itemId = win.convertToIID(win.IID_IShellItem);
  final results = <WindowsShellApplication>[];
  final packageRoots = <String, String>{};
  try {
    item = _shellItem('shell:AppsFolder');
    if (item == null ||
        win.FAILED(item.bindToHandler(
            nullptr, handler, folderId, folderOutput.cast()))) {
      return results;
    }
    folder = win.IShellFolder(folderOutput);
    // SHCONTF_FOLDERS | SHCONTF_NONFOLDERS: aplicativos também podem ser pastas virtuais.
    if (win.FAILED(folder.enumObjects(0, 0x20 | 0x40, enumOutput.cast())) ||
        enumOutput.ref.isNull) {
      return results;
    }
    enumerator = win.IEnumIDList(enumOutput);
    final createChild = DynamicLibrary.open('shell32.dll').lookupFunction<
        Int32 Function(Pointer<win.ITEMIDLIST>, Pointer,
            Pointer<win.ITEMIDLIST>, Pointer<win.GUID>, Pointer<Pointer>),
        int Function(Pointer<win.ITEMIDLIST>, Pointer, Pointer<win.ITEMIDLIST>,
            Pointer<win.GUID>, Pointer<Pointer>)>('SHCreateItemWithParent');
    while (enumerator.next(1, child, fetched) == 0 && fetched.value == 1) {
      final output = calloc<win.COMObject>();
      win.IShellItem? app;
      try {
        if (win.FAILED(createChild(nullptr, folder.ptr.ref.lpVtbl.cast(),
            child.value, itemId, output.cast()))) {
          continue;
        }
        app = win.IShellItem(output);
        final name = _displayName(app, win.SIGDN.SIGDN_NORMALDISPLAY);
        final target =
            _displayName(app, win.SIGDN.SIGDN_DESKTOPABSOLUTEPARSING);
        if (name.isNotEmpty && target.isNotEmpty) {
          final aumid =
              _displayName(app, win.SIGDN.SIGDN_PARENTRELATIVEPARSING);
          final family = aumid.contains('!') ? aumid.split('!').first : '';
          final packageRoot = family.isEmpty
              ? ''
              : packageRoots.putIfAbsent(
                  family, () => _registeredPackageRoot(family));
          results.add(WindowsShellApplication(
              name, target, _displayName(app, win.SIGDN.SIGDN_FILESYSPATH),
              packageRoot: packageRoot, appUserModelId: aumid));
        }
      } finally {
        if (app != null) {
          _release(app);
        } else {
          calloc.free(output);
        }
        win.CoTaskMemFree(child.value);
        child.value = nullptr;
      }
    }
    return results;
  } finally {
    if (enumerator != null) {
      _release(enumerator);
    } else {
      calloc.free(enumOutput);
    }
    if (folder != null) {
      _release(folder);
    } else {
      calloc.free(folderOutput);
    }
    _release(item);
    calloc.free(handler);
    calloc.free(folderId);
    calloc.free(itemId);
    calloc.free(child);
    calloc.free(fetched);
    win.CoUninitialize();
  }
}

/// Obtém o ícone real de executáveis, atalhos e itens virtuais do Windows.
Future<WindowsItemIcon?> readWindowsItemIcon(String target,
    {int index = 0}) async {
  if (!Platform.isWindows || target.isEmpty) return null;
  return Isolate.run(() {
    if (RegExp(r'\.(exe|dll|ico)$', caseSensitive: false).hasMatch(target)) {
      final raw = readExecutableIcon(target, index: index);
      if (raw != null) return WindowsItemIcon(raw.width, raw.height, raw.bgra);
    }
    return _readIcon(target) ?? _readShellFileIcon(target);
  });
}

final _parseShellName = DynamicLibrary.open('shell32.dll').lookupFunction<
    Int32 Function(Pointer<Utf16>, Pointer, Pointer<Pointer<win.ITEMIDLIST>>,
        Uint32, Pointer<Uint32>),
    int Function(Pointer<Utf16>, Pointer, Pointer<Pointer<win.ITEMIDLIST>>, int,
        Pointer<Uint32>)>('SHParseDisplayName');

/// Fallback do buscador: consulta o mesmo ícone que o Explorer usa, incluindo
/// atalhos customizados e aplicativos virtuais de shell:AppsFolder.
WindowsItemIcon? _readShellFileIcon(String target) {
  final initialized =
      win.CoInitializeEx(nullptr, win.COINIT.COINIT_APARTMENTTHREADED);
  if (win.FAILED(initialized) && initialized != win.RPC_E_CHANGED_MODE) {
    return null;
  }
  final filename = target.toNativeUtf16();
  final pidl = calloc<Pointer<win.ITEMIDLIST>>();
  final attributes = calloc<Uint32>();
  final info = calloc<win.SHFILEINFO>();
  try {
    var flags = 0x100; // SHGFI_ICON | SHGFI_LARGEICON.
    var item = filename;
    if (target.startsWith('shell:') || target.startsWith('::{')) {
      if (win.FAILED(_parseShellName(filename, nullptr, pidl, 0, attributes))) {
        return null;
      }
      item = pidl.value.cast<Utf16>();
      flags |= 0x8; // SHGFI_PIDL.
    }
    if (win.SHGetFileInfo(item, 0, info, sizeOf<win.SHFILEINFO>(), flags) ==
            0 ||
        info.ref.hIcon == 0) {
      return null;
    }
    final raw = rasterizeShellIcon(info.ref.hIcon);
    return raw == null
        ? null
        : WindowsItemIcon(raw.width, raw.height, raw.bgra);
  } finally {
    if (info.ref.hIcon != 0) win.DestroyIcon(info.ref.hIcon);
    if (pidl.value != nullptr) win.CoTaskMemFree(pidl.value);
    calloc.free(filename);
    calloc.free(pidl);
    calloc.free(attributes);
    calloc.free(info);
    if (!win.FAILED(initialized)) win.CoUninitialize();
  }
}

WindowsItemIcon? _readIcon(String target) {
  final initialized =
      win.CoInitializeEx(nullptr, win.COINIT.COINIT_APARTMENTTHREADED);
  if (win.FAILED(initialized)) return null;
  win.IShellItem? item;
  win.IShellItemImageFactory? factory;
  final bitmap = calloc<IntPtr>();
  final size = calloc<win.SIZE>()..ref.cx = 96;
  size.ref.cy = 96;
  final dimensions = calloc<win.BITMAP>();
  final info = calloc<win.BITMAPINFO>();
  Pointer<Uint8>? pixels;
  var dc = 0;
  try {
    item = _shellItem(target);
    if (item == null) return null;
    factory = win.IShellItemImageFactory.from(item);
    // SIIGBF_ICONONLY | SIIGBF_BIGGERSIZEOK.
    if (win.FAILED(factory.getImage(size.ref, 0x4 | 0x1, bitmap))) return null;
    if (win.GetObject(bitmap.value, sizeOf<win.BITMAP>(), dimensions) == 0) {
      return null;
    }
    final width = dimensions.ref.bmWidth;
    final height = dimensions.ref.bmHeight.abs();
    if (width <= 0 || height <= 0 || width > 1024 || height > 1024) return null;
    info.ref.bmiHeader
      ..biSize = sizeOf<win.BITMAPINFOHEADER>()
      ..biWidth = width
      ..biHeight = -height
      ..biPlanes = 1
      ..biBitCount = 32;
    pixels = calloc<Uint8>(width * height * 4);
    dc = win.GetDC(0);
    if (win.GetDIBits(dc, bitmap.value, 0, height, pixels, info, 0) != height) {
      return null;
    }
    final bytes = Uint8List.fromList(pixels.asTypedList(width * height * 4));
    // Alguns ícones antigos não fornecem canal alfa.
    var hasAlpha = false;
    for (var i = 3; i < bytes.length; i += 4) {
      if (bytes[i] != 0) {
        hasAlpha = true;
        break;
      }
    }
    if (!hasAlpha) {
      for (var i = 3; i < bytes.length; i += 4) {
        bytes[i] = 255;
      }
    }
    return WindowsItemIcon(width, height, bytes);
  } catch (_) {
    return null;
  } finally {
    if (dc != 0) win.ReleaseDC(0, dc);
    if (pixels != null) calloc.free(pixels);
    if (bitmap.value != 0) win.DeleteObject(bitmap.value);
    calloc.free(bitmap);
    calloc.free(size);
    calloc.free(dimensions);
    calloc.free(info);
    _release(factory);
    _release(item);
    win.CoUninitialize();
  }
}
