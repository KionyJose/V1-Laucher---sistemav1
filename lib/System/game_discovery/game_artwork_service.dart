import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../app_storage.dart';
import '../windows_app_catalog.dart';
import '../windows_game_discovery.dart';
import 'game_entry.dart';
import 'installed_game_discovery.dart';
import 'search_file_icon.dart';

/// Imagens de arquivos são decodificadas pelo Flutter; ICO/EXE/DLL e itens do
/// shell são extraídos por FFI. Não confunde uma capa com o ícone do aplicativo.
class GameArtworkService {
  GameArtworkService(this.discovery);
  final InstalledGameDiscovery discovery;
  final _icons = <String, Future<ui.Image?>>{};
  final _backgrounds = <String, Future<String?>>{};
  final _gameStatus = <String, Future<bool>>{};
  final _links = <String, Future<WindowsShortcutDetails?>>{};
  final _resolvedPaths = <String, Set<String>>{};
  final _images = <ui.Image>{};
  final _waiting = <Completer<void>>[];
  int _active = 0;
  bool _disposed = false;

  String fingerprint(GameEntry game) =>
      '${game.key}|${game.iconSources.join('|')}|${game.backgroundSources.join('|')}|${game.isGame}';

  Set<String> resolvedIconPaths(GameEntry game) =>
      _resolvedPaths[game.key] ?? const {};

  Future<bool> isGameFor(GameEntry game) =>
      _gameStatus.putIfAbsent(fingerprint(game), () async {
        if (game.isGame) return true;
        try {
          var source = game.artworkSource?.isNotEmpty == true
              ? game.artworkSource!
              : game.exePath;
          if (source.toLowerCase().endsWith('.lnk')) {
            source = (await _link(source))?.target ?? '';
          }
          if (source.toLowerCase().endsWith('.url')) {
            final text = await _readUrlShortcut(source);
            return RegExp(r'^URL=(steam|com\.epicgames\.launcher)://',
                    multiLine: true, caseSensitive: false)
                .hasMatch(text);
          }
          final file = parseIconReference(source).path;
          if (!file.toLowerCase().endsWith('.exe') ||
              isSupportExecutable(file) ||
              RegExp(r'^(steam|epicgameslauncher|galaxyclient|ubisoftconnect|uplay|eadesktop|origin|launcher)\.exe$',
                      caseSensitive: false)
                  .hasMatch(p.basename(file))) {
            return false;
          }
          final folder = p.dirname(file);
          final entries = await Directory(folder)
              .list(followLinks: false)
              .toList()
              .timeout(const Duration(seconds: 2));
          final names =
              entries.map((e) => p.basename(e.path).toLowerCase()).toSet();
          return names.contains(
                  '${p.basenameWithoutExtension(file).toLowerCase()}_data') ||
              names.any((name) => const {
                    'steam_api.dll',
                    'steam_api64.dll',
                    'unityplayer.dll',
                    'gameassembly.dll',
                    'eossdk-win64-shipping.dll',
                    'galaxypeer64.dll',
                    'microsoftgame.config'
                  }.contains(name)) ||
              RegExp(r'[\\/](games|jogos|gog games|steamapps[\\/]common)[\\/]',
                      caseSensitive: false)
                  .hasMatch(file);
        } catch (_) {
          return false;
        }
      });

  Future<String> _readUrlShortcut(String filename) async {
    final bytes = await File(filename).readAsBytes();
    if (bytes.length >= 2 &&
        ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
            (bytes[0] == 0xfe && bytes[1] == 0xff))) {
      final little = bytes[0] == 0xff;
      return String.fromCharCodes([
        for (var i = 2; i + 1 < bytes.length; i += 2)
          little ? bytes[i] | bytes[i + 1] << 8 : bytes[i] << 8 | bytes[i + 1]
      ]);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<T?> _limited<T>(Future<T?> Function() work) async {
    if (_disposed) return null;
    if (_active >= 3) {
      final ready = Completer<void>();
      _waiting.add(ready);
      await ready.future;
    } else {
      _active++;
    }
    try {
      return _disposed ? null : await work();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _active--;
      }
    }
  }

  Future<ui.Image?> iconFor(GameEntry game) => _icons.putIfAbsent(
      fingerprint(game), () => _limited(() => _loadIcon(game)));

  Future<WindowsShortcutDetails?> _link(String source) =>
      _links.putIfAbsent(source, () async {
        try {
          return await readWindowsShortcutDetails(source)
              .timeout(const Duration(seconds: 2));
        } catch (_) {
          return null;
        }
      });

  Future<ui.Image?> _loadIcon(GameEntry game) async {
    final candidates = <String>{
      if (game.platform == 'Outros' && game.artworkSource?.isNotEmpty == true)
        game.artworkSource!,
      ...game.iconSources,
      if (game.iconSource != null) game.iconSource!,
      if (game.artworkSource != null) game.artworkSource!,
      game.exePath
    };
    for (final candidate in candidates) {
      if (_disposed) return null;
      if (candidate.trim().isEmpty || candidate.contains('://')) continue;
      try {
        final reference = parseIconReference(candidate);
        final paths = _resolvedPaths.putIfAbsent(game.key, () => {});
        paths.add(reference.path);
        if (reference.path.toLowerCase().endsWith('.lnk')) {
          final details = await _link(reference.path);
          if (details != null) {
            if (details.target.isNotEmpty) paths.add(details.target);
            for (final value in [
              if (details.icon.isNotEmpty)
                '${details.icon},${details.iconIndex}',
              details.target
            ]) {
              if (value.isEmpty) continue;
              try {
                final image = await _fileIcon(value);
                if (image != null) return _remember(image);
              } catch (_) {
                /* Um recurso inválido não elimina o ícone do alvo. */
              }
            }
          }
        } else if (reference.path.toLowerCase().endsWith('.url')) {
          final content = await _readUrlShortcut(reference.path);
          final icon =
              RegExp(r'^IconFile=(.+)$', multiLine: true, caseSensitive: false)
                  .firstMatch(content)
                  ?.group(1)
                  ?.trim();
          final index = RegExp(r'^IconIndex=(-?\d+)',
                      multiLine: true, caseSensitive: false)
                  .firstMatch(content)
                  ?.group(1) ??
              '0';
          if (icon != null) {
            final image = await _fileIcon('$icon,$index');
            if (image != null) return _remember(image);
          }
        } else {
          final image = await _fileIcon(candidate);
          if (image != null) return _remember(image);
        }
        // O Shell conhece também ícones customizados do atalho e apps UWP.
        if (reference.path.toLowerCase().endsWith('.lnk') ||
            reference.path.toLowerCase().endsWith('.url')) {
          final image = await _nativeIcon(reference.path);
          if (image != null) return _remember(image);
        }
      } catch (_) {/* Tenta a próxima fonte real do mesmo jogo. */}
      // Mesmo se o caminho do recurso/índice estiver inválido, o Explorer pode
      // ter o ícone real em cache. Essa tentativa vale também para "Outros".
      try {
        final ref = parseIconReference(candidate);
        final icon = await _nativeIcon(ref.path, index: ref.index);
        if (icon != null) return _remember(icon);
      } catch (_) {/* Segue para a próxima origem do mesmo item. */}
    }
    if (!_disposed && game.platform != 'Outros' && game.installDir.isNotEmpty) {
      try {
        final executable = await discovery.executableFor(game);
        if (executable != null) {
          final image = await _fileIcon(executable);
          if (image != null) return _remember(image);
        }
      } catch (_) {/* Sem ícone do executável: mantém o placeholder. */}
    }
    return null;
  }

  ui.Image? _remember(ui.Image image) {
    if (_disposed) {
      image.dispose();
      return null;
    }
    _images.add(image);
    return image;
  }

  Future<ui.Image?> _fileIcon(String source) async {
    final ref = parseIconReference(source);
    if (ref.path.isEmpty) return null;
    if (ref.path.startsWith('shell:') || ref.path.startsWith('::{')) {
      return _nativeIcon(ref.path);
    }
    final file = File(ref.path);
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) return null;
    final extension = p.extension(ref.path).toLowerCase();
    if (['.png', '.jpg', '.jpeg', '.webp', '.bmp'].contains(extension)) {
      return _decodeFile(file);
    }
    if (!['.ico', '.exe', '.dll'].contains(extension)) return null;
    final hash = sha256.convert(utf8.encode(
        '${ref.path}|${ref.index}|${stat.modified.millisecondsSinceEpoch}|${stat.size}|nav-task-v2'));
    final cached =
        File(p.join(AppStorage.root.path, 'cache', 'game-icons', '$hash.png'));
    if (await cached.exists()) {
      try {
        return await _decodeFile(cached);
      } catch (_) {/* Cache incompleto será regravado. */}
    }
    final image = await _nativeIcon(ref.path, index: ref.index);
    if (image != null) {
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        if (png != null) {
          await cached.parent.create(recursive: true);
          await cached.writeAsBytes(
              png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes));
        }
      } on FileSystemException {/* Cache indisponível não esconde o ícone. */}
    }
    return image;
  }

  Future<ui.Image> _decodeFile(File file) async {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes(),
        targetWidth: 192, allowUpscaling: false);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  Future<ui.Image?> _nativeIcon(String target, {int index = 0}) async {
    WindowsItemIcon? raw;
    if (RegExp(r'\.(exe|dll|ico)$', caseSensitive: false).hasMatch(target)) {
      raw = await readSearchFileIcon(target, index: index)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
    }
    raw ??= await readWindowsItemIcon(target, index: index)
        .timeout(const Duration(seconds: 3), onTimeout: () => null);
    if (raw == null || _disposed) return null;
    final decoded = Completer<ui.Image>();
    ui.decodeImageFromPixels(raw.pixels, raw.width, raw.height,
        ui.PixelFormat.bgra8888, decoded.complete);
    return decoded.future;
  }

  Future<String?> backgroundFor(GameEntry game) => _backgrounds.putIfAbsent(
          '${game.key}|${game.backgroundSources.join('|')}', () async {
        final candidates = [
          ...game.backgroundSources,
          if (game.thumbnailPath != null) game.thumbnailPath!
        ];
        for (final file in candidates) {
          if (_disposed) return null;
          if (file.isNotEmpty && await File(file).exists()) return file;
        }
        var directory = game.installDir;
        final source = game.artworkSource ?? game.exePath;
        if (source.toLowerCase().endsWith('.lnk')) {
          final target = (await _link(source))?.target;
          directory = target == null || target.isEmpty ? '' : p.dirname(target);
        } else if (source.toLowerCase().endsWith('.exe')) {
          directory = p.dirname(source);
        }
        if (directory.isNotEmpty && !_disposed) {
          final images = await discovery.imageFiles(directory);
          if (images.isNotEmpty) return images.first;
        }
        // A lista não espera rede. Só o card visível usa este fallback pelo
        // AppID conhecido, sem pesquisa aproximada que possa trocar a capa.
        if (game.platform == 'Steam' && game.id != null) {
          return 'https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/${game.id}/header.jpg';
        }
        return null;
      });

  void dispose() {
    _disposed = true;
    for (final image in _images) {
      image.dispose();
    }
    _images.clear();
  }
}
