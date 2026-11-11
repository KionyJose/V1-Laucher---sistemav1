import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../windows_app_catalog.dart';
import '../windows_game_discovery.dart';
import 'game_entry.dart';
import 'valve_key_values.dart';

class DiscoveryUpdate {
  const DiscoveryUpdate(this.source, this.games, {this.error});
  final String source;
  final List<GameEntry> games;
  final String? error;
}

/// Descoberta por metadados de cada loja, independente de janelas abertas.
/// Não há prazo global nem limite que descarte jogos de bibliotecas grandes.
class InstalledGameDiscovery {
  bool _cancelled = false;
  Future<List<WindowsInstalledProgram>>? _programsFuture;
  Future<List<String>>? _steamRootsFuture;
  Future<List<WindowsShellApplication>>? _appsFuture;
  Future<List<String>>? _drivesFuture;
  final _files = <String, Future<List<FileSystemEntity>>>{};
  final _executables = <String, Future<String?>>{};

  void dispose() {
    _cancelled = true;
  }

  Future<List<WindowsInstalledProgram>> get _programs =>
      _programsFuture ??= readWindowsInstalledPrograms();
  Future<List<WindowsShellApplication>> get _apps =>
      _appsFuture ??= readWindowsAppsFolder();
  Future<List<String>> get _drives => _drivesFuture ??= readWindowsGameDrives();

  Future<List<FileSystemEntity>> _list(String directory) =>
      _files.putIfAbsent(p.normalize(directory).toLowerCase(), () async {
        if (directory.isEmpty || _cancelled) return [];
        try {
          return await Directory(directory).list(followLinks: false).toList();
        } on FileSystemException {
          return [];
        }
      });

  Stream<DiscoveryUpdate> scan() {
    final output = StreamController<DiscoveryUpdate>();
    Future<void> source(
        String name, Future<List<GameEntry>> Function() read) async {
      try {
        final games = await read();
        if (!_cancelled) {
          debugPrint('[GAMES_BUSCA] $name: ${games.length} itens');
          output.add(DiscoveryUpdate(name, games));
        }
      } catch (error) {
        debugPrint('[GAMES_BUSCA] $name: $error');
        if (!_cancelled) {
          output.add(DiscoveryUpdate(name, const [], error: '$error'));
        }
      }
    }

    Future<void> collect() async {
      try {
        await Future.wait([
          source('Área de Trabalho', _desktop),
          source('Steam', _steam),
          source('Epic Games', _epic),
          source('GOG', _gog),
          source('Microsoft Store', _windowsApps),
          source('Xbox / Game Pass', _gdk),
          source('Programas instalados', _registeredPrograms),
          source('Pastas de jogos', _portable),
        ]);
      } finally {
        await output.close();
      }
    }

    unawaited(collect());
    return output.stream;
  }

  Future<Map<String, dynamic>?> _json(String filename) async {
    try {
      final decoded = jsonDecode(await File(filename).readAsString());
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  String _text(dynamic value) => value is String ? value : '';

  Future<List<String>> _steamRoots() => _steamRootsFuture ??= () async {
        final roots = <String, String>{};
        void add(String value) {
          if (value.isEmpty) return;
          final root = p.windows.normalize(expandWindowsEnvironment(value));
          roots[root.toLowerCase()] = root;
        }

        for (final root in await readWindowsSteamDirectories()) {
          add(root);
        }
        for (final base in [
          Platform.environment['ProgramFiles(x86)'],
          Platform.environment['ProgramFiles'],
          r'C:\Program Files (x86)',
          r'C:\Program Files'
        ]) {
          if (base != null) add(p.join(base, 'Steam'));
        }
        // Bibliotecas movidas ou clientes sem registro ainda podem ser encontrados.
        for (final root in [r'D:\SteamLibrary', r'E:\SteamLibrary']) {
          add(root);
        }
        final visited = <String>{};
        while (!_cancelled) {
          final next =
              roots.keys.where((key) => !visited.contains(key)).firstOrNull;
          if (next == null) break;
          visited.add(next);
          final root = roots[next]!;
          for (final relative in [
            'steamapps/libraryfolders.vdf',
            'config/libraryfolders.vdf',
            'config/config.vdf'
          ]) {
            try {
              final data = parseValveKeyValues(
                  await File(p.join(root, relative)).readAsString());
              void paths(Map values) {
                for (final entry in values.entries) {
                  if (entry.value is Map) {
                    paths(entry.value as Map);
                  } else if (entry.value is String &&
                      (entry.key == 'path' ||
                          '${entry.key}'.startsWith('baseinstallfolder') ||
                          RegExp(r'^\d+$').hasMatch('${entry.key}')) &&
                      p.windows.isAbsolute(entry.value as String)) {
                    add(entry.value as String);
                  }
                }
              }

              paths(data);
            } on FileSystemException {
              /* Cliente ou formato alternativo ausente. */
            }
          }
        }
        return roots.values.toList();
      }();

  Future<List<GameEntry>> _steam() async {
    final roots = await _steamRoots();
    final registered = <String, WindowsInstalledProgram>{};
    for (final item in await _programs) {
      final id = RegExp(r'^Steam App (\d+)$', caseSensitive: false)
          .firstMatch(item.registryKey)
          ?.group(1);
      if (id != null) registered[id] = item;
    }
    final games = <String, GameEntry>{};
    for (final root in roots) {
      if (_cancelled) break;
      final steamapps = p.join(root, 'steamapps');
      for (final file in await _list(steamapps)) {
        if (_cancelled) break;
        if (file is! File ||
            !RegExp(r'^appmanifest_\d+\.acf$', caseSensitive: false)
                .hasMatch(p.basename(file.path))) {
          continue;
        }
        try {
          final document = parseValveKeyValues(await file.readAsString());
          final state = document['appstate'];
          if (state is! Map) continue;
          final id = _text(state['appid']);
          final name = _text(state['name']);
          final install = _text(state['installdir']);
          if (id.isEmpty || name.isEmpty || install.isEmpty || id == '228980') {
            continue;
          }
          final directory = p.join(steamapps, 'common', install);
          if (!await Directory(directory).exists()) continue;
          final art = await _steamArtwork(roots, id);
          games[id] = GameEntry(
              id: id,
              name: name,
              exePath: 'steam://rungameid/$id',
              installDir: directory,
              platform: 'Steam',
              priority: 0,
              iconSources: [
                if (registered[id]?.icon.isNotEmpty == true)
                  registered[id]!.icon,
                ...art.icons
              ],
              backgroundSources: art.backgrounds);
        } catch (error) {
          debugPrint(
              '[GAMES_BUSCA] Manifesto Steam ignorado ${file.path}: $error');
        }
      }
    }
    // O registro complementa instalações cujo ACF esteja temporariamente sendo
    // regravado pelo cliente. O AppID permanece a chave, não o nome do jogo.
    for (final entry in registered.entries) {
      if (_cancelled) break;
      final item = entry.value;
      if (games.containsKey(entry.key) ||
          entry.key == '228980' ||
          item.installDirectory.isEmpty ||
          !await Directory(item.installDirectory).exists()) {
        continue;
      }
      final art = await _steamArtwork(roots, entry.key);
      games[entry.key] = GameEntry(
          id: entry.key,
          name: item.name,
          exePath: 'steam://rungameid/${entry.key}',
          installDir: item.installDirectory,
          platform: 'Steam',
          priority: 0,
          iconSources: [item.icon, ...art.icons],
          backgroundSources: art.backgrounds);
    }
    return games.values.toList();
  }

  Future<({List<String> icons, List<String> backgrounds})> _steamArtwork(
      List<String> roots, String id) async {
    final icons = <String>[];
    final backgrounds = <String>[];
    for (final root in roots) {
      final cache = p.join(root, 'appcache', 'librarycache');
      final top = await _list(cache);
      final images = <File>[];
      for (final item in top) {
        if (item is Directory && p.basename(item.path) == id) {
          images.addAll((await _list(item.path)).whereType<File>());
        } else if (item is File && p.basename(item.path).startsWith('${id}_')) {
          images.add(item);
        }
      }
      for (final file in images) {
        final name = p.basename(file.path).toLowerCase();
        if (RegExp(r'^[0-9a-f]{40}\.(jpg|png|ico)$').hasMatch(name) ||
            name.contains('icon')) {
          icons.add(file.path);
        }
        if (name.contains('library_hero') && !name.contains('blur')) {
          backgrounds.insert(0, file.path);
        } else if (name.contains('header') || name.contains('600x900')) {
          backgrounds.add(file.path);
        }
      }
    }
    return (icons: icons, backgrounds: backgrounds);
  }

  Future<List<GameEntry>> _epic() async {
    final base = p.join(
        Platform.environment['PROGRAMDATA'] ?? r'C:\ProgramData', 'Epic');
    final manifests = <String, Map<String, dynamic>>{};
    for (final file in await _list(
        p.join(base, 'EpicGamesLauncher', 'Data', 'Manifests'))) {
      if (_cancelled) break;
      if (file is! File || p.extension(file.path).toLowerCase() != '.item') {
        continue;
      }
      final data = await _json(file.path);
      if (data != null && data['bIsIncompleteInstall'] != true) {
        manifests[_text(data['AppName'])] = data;
      }
    }
    final installed = await _json(
        p.join(base, 'UnrealEngineLauncher', 'LauncherInstalled.dat'));
    final entries = installed?['InstallationList'];
    if (entries is List) {
      for (final entry in entries.whereType<Map>()) {
        final app = _text(entry['AppName']);
        manifests.putIfAbsent(
            app,
            () => {
                  'AppName': app,
                  'InstallLocation': entry['InstallLocation'],
                  'CatalogNamespace': entry['NamespaceId'],
                  'CatalogItemId': entry['ItemId'],
                });
      }
    }
    final games = <GameEntry>[];
    for (final entry in manifests.entries) {
      if (_cancelled) break;
      final data = entry.value;
      final app = entry.key;
      final directory = _text(data['InstallLocation']);
      if (app.isEmpty ||
          app.startsWith('UE_') ||
          directory.isEmpty ||
          !await Directory(directory).exists()) {
        continue;
      }
      final parent = _text(data['MainGameAppName']);
      if (parent.isNotEmpty &&
          parent != app &&
          _text(data['LaunchExecutable']).isEmpty) {
        continue;
      }
      final namespace = _text(data['CatalogNamespace']);
      final item = _text(data['CatalogItemId']);
      final id = namespace.isNotEmpty && item.isNotEmpty
          ? '$namespace:$item:$app'
          : app;
      final executable = _text(data['LaunchExecutable']);
      games.add(GameEntry(
          id: id,
          name: _text(data['DisplayName']).isNotEmpty
              ? _text(data['DisplayName'])
              : p.basename(directory),
          exePath:
              'com.epicgames.launcher://apps/${Uri.encodeComponent(id)}?action=launch&silent=true',
          installDir: directory,
          platform: 'Epic Games',
          priority: 0,
          iconSources: [
            if (executable.isNotEmpty) p.join(directory, executable)
          ],
          backgroundSources: await imageFiles(directory)));
    }
    return games;
  }

  Future<List<GameEntry>> _gog() async {
    final locations =
        <String, ({String directory, String name, String icon})>{};
    for (final item in await _programs) {
      if (!item.publisher.toLowerCase().contains('gog')) continue;
      final id = RegExp(r'^(\d+)_is1').firstMatch(item.registryKey)?.group(1);
      if (id != null && item.installDirectory.isNotEmpty) {
        locations[id] = (
          directory: item.installDirectory,
          name: item.name,
          icon: item.icon
        );
      }
    }
    // Instalações portáteis/offline também podem conter o manifesto GOG.
    for (final root in [
      r'C:\GOG Games',
      r'D:\GOG Games',
      r'C:\Program Files (x86)\GOG Galaxy\Games',
      r'C:\Program Files\GOG Galaxy\Games'
    ]) {
      for (final folder in (await _list(root)).whereType<Directory>()) {
        for (final file in (await _list(folder.path)).whereType<File>()) {
          final id = RegExp(r'^goggame-(\d+)\.info$', caseSensitive: false)
              .firstMatch(p.basename(file.path))
              ?.group(1);
          if (id != null) {
            locations.putIfAbsent(
                id,
                () => (
                      directory: folder.path,
                      name: p.basename(folder.path),
                      icon: ''
                    ));
          }
        }
      }
    }
    final games = <GameEntry>[];
    for (final entry in locations.entries) {
      if (_cancelled) break;
      final id = entry.key;
      final location = entry.value;
      final info = await _json(p.join(location.directory, 'goggame-$id.info'));
      if (info == null) continue;
      final parent = _text(info['rootGameId']);
      if (parent.isNotEmpty && parent != id) continue;
      final tasks = info['playTasks'];
      if (tasks is! List) continue;
      final task = tasks
          .whereType<Map>()
          .where((t) => t['isPrimary'] == true && _text(t['path']).isNotEmpty)
          .firstOrNull;
      if (task == null) continue;
      final executable =
          p.normalize(p.join(location.directory, _text(task['path'])));
      if (!await File(executable).exists()) continue;
      final working = _text(task['workingDir']);
      games.add(GameEntry(
          id: id,
          name: _text(info['name']).isNotEmpty
              ? _text(info['name'])
              : location.name,
          exePath: executable,
          installDir: location.directory,
          platform: 'GOG',
          priority: 0,
          arguments: splitWindowsArguments(_text(task['arguments'])),
          workingDirectory: working.isEmpty
              ? p.dirname(executable)
              : p.join(location.directory, working),
          iconSources: [
            location.icon,
            p.join(location.directory, 'goggame-$id.ico'),
            executable
          ],
          backgroundSources: await imageFiles(location.directory)));
    }
    return games;
  }

  Future<List<GameEntry>> _desktop() async {
    final games = <GameEntry>[];
    final directories = <String>{...await readWindowsDesktopDirectories()};
    for (final directory in directories) {
      for (final file in (await _list(directory)).whereType<File>()) {
        if (_cancelled) break;
        if (!['.exe', '.lnk', '.url']
            .contains(p.extension(file.path).toLowerCase())) {
          continue;
        }
        games.add(GameEntry(
            name: p.basenameWithoutExtension(file.path),
            exePath: file.path,
            installDir: directory,
            platform: 'Outros',
            priority: 10,
            iconSources: [file.path]));
      }
    }
    return games;
  }

  Future<List<GameEntry>> _windowsApps() async {
    final result = <GameEntry>[];
    for (final app in await _apps) {
      if (_cancelled) break;
      final packaged = app.packageRoot.isNotEmpty;
      final assets = packaged ? await _packageArtwork(app) : null;
      result.add(GameEntry(
          id: app.appUserModelId.isEmpty ? app.target : app.appUserModelId,
          name: app.name,
          exePath: app.target,
          installDir: app.packageRoot,
          platform: packaged ? 'Microsoft Store' : 'Outros',
          priority: packaged ? 0 : 20,
          artworkSource: app.filePath,
          iconSources: [...?assets?.icons, app.target, app.filePath],
          backgroundSources: assets?.backgrounds ?? const []));
    }
    return result;
  }

  Future<({List<String> icons, List<String> backgrounds})> _packageArtwork(
      WindowsShellApplication app) async {
    try {
      final manifest = await File(p.join(app.packageRoot, 'AppxManifest.xml'))
          .readAsString();
      final id = app.appUserModelId.split('!').last;
      var block = manifest;
      for (final match in RegExp(
              r'<(?:\w+:)?Application\b([^>]*)([\s\S]*?)</(?:\w+:)?Application>',
              caseSensitive: false)
          .allMatches(manifest)) {
        if (xmlAttributes(match.group(1)!)['Id'] == id) {
          block = match.group(0)!;
          break;
        }
      }
      final icons = <String>[];
      final backgrounds = <String>[];
      for (final tag in RegExp(r'<[^!?][^>]*>').allMatches(block)) {
        final attrs = xmlAttributes(tag.group(0)!);
        for (final name in [
          'Square44x44Logo',
          'Square150x150Logo',
          'Square480x480Logo',
          'Logo'
        ]) {
          if (attrs[name]?.isNotEmpty == true) {
            icons.addAll(await _assetVariants(app.packageRoot, attrs[name]!));
          }
        }
        for (final name in ['Wide310x150Logo', 'SplashScreenImage']) {
          if (attrs[name]?.isNotEmpty == true) {
            backgrounds
                .addAll(await _assetVariants(app.packageRoot, attrs[name]!));
          }
        }
        if (tag.group(0)!.contains('SplashScreen') && attrs['Image'] != null) {
          backgrounds
              .addAll(await _assetVariants(app.packageRoot, attrs['Image']!));
        }
      }
      return (icons: icons, backgrounds: backgrounds);
    } on FileSystemException {
      return (icons: <String>[], backgrounds: <String>[]);
    }
  }

  Future<List<GameEntry>> _gdk() async {
    final apps = await _apps;
    final roots = <String>{
      for (final app in apps)
        if (app.packageRoot.isNotEmpty) app.packageRoot
    };
    for (final drive in await _drives) {
      for (final folder
          in (await _list(p.join(drive, 'XboxGames'))).whereType<Directory>()) {
        roots.add(p.join(folder.path, 'Content'));
        roots.add(folder.path);
      }
    }
    final games = <GameEntry>[];
    for (final root in roots) {
      if (_cancelled) break;
      try {
        final xml =
            await File(p.join(root, 'MicrosoftGame.config')).readAsString();
        final identityTag =
            RegExp(r'<Identity\b[^>]*>', caseSensitive: false).firstMatch(xml);
        final identity =
            xmlAttributes(identityTag?.group(0) ?? '')['Name'] ?? '';
        final app = apps
            .where((a) =>
                a.packageRoot.toLowerCase() == root.toLowerCase() ||
                (identity.isNotEmpty &&
                    a.appUserModelId.startsWith('${identity}_')))
            .firstOrNull;
        // Gaming Services e autenticação são preservados pela ação registrada.
        if (app == null) continue;
        final visualsTag =
            RegExp(r'<ShellVisuals\b[^>]*>', caseSensitive: false)
                .firstMatch(xml);
        final visuals = xmlAttributes(visualsTag?.group(0) ?? '');
        final icons = <String>[];
        final backgrounds = <String>[];
        for (final key in [
          'Square44x44Logo',
          'Square150x150Logo',
          'Square480x480Logo',
          'StoreLogo'
        ]) {
          if (visuals[key]?.isNotEmpty == true) {
            icons.addAll(await _assetVariants(root, visuals[key]!));
          }
        }
        if (visuals['SplashScreenImage']?.isNotEmpty == true) {
          backgrounds.addAll(
              await _assetVariants(root, visuals['SplashScreenImage']!));
        }
        games.add(GameEntry(
            id: app.appUserModelId.isEmpty ? app.target : app.appUserModelId,
            name: visuals['DefaultDisplayName']?.isNotEmpty == true &&
                    !visuals['DefaultDisplayName']!.startsWith('ms-resource:')
                ? visuals['DefaultDisplayName']!
                : app.name,
            exePath: app.target,
            installDir: root,
            platform: 'Microsoft Store',
            isGame: true,
            priority: 0,
            iconSources: [...icons, app.target],
            backgroundSources: backgrounds));
      } on FileSystemException {/* Esta pasta não contém um pacote GDK. */}
    }
    return games;
  }

  Future<List<GameEntry>> _portable() async {
    final games = <GameEntry>[];
    for (final drive in await _drives) {
      for (final name in ['Games', 'Jogos']) {
        for (final folder
            in (await _list(p.join(drive, name))).whereType<Directory>()) {
          if (_cancelled) return games;
          final candidate = GameEntry(
              name: p.basename(folder.path),
              exePath: '',
              installDir: folder.path,
              platform: 'Outros',
              priority: 60);
          final executable = await executableFor(candidate);
          if (executable != null) {
            games.add(GameEntry(
                name: candidate.name,
                exePath: executable,
                installDir: folder.path,
                platform: 'Outros',
                priority: 60,
                isGame: true,
                iconSources: [executable],
                workingDirectory: p.dirname(executable)));
          }
        }
      }
    }
    return games;
  }

  Future<List<String>> _assetVariants(String root, String relative) async {
    final exact = p.join(root, relative.replaceAll('/', p.separator));
    final stem = p.basenameWithoutExtension(exact).toLowerCase();
    final candidates = (await _list(p.dirname(exact)))
        .whereType<File>()
        .where((file) =>
            p
                .basenameWithoutExtension(file.path)
                .toLowerCase()
                .startsWith(stem) &&
            ['.png', '.jpg', '.jpeg']
                .contains(p.extension(file.path).toLowerCase()))
        .toList();
    candidates.sort((a, b) {
      int score(File f) {
        final name = p.basename(f.path).toLowerCase();
        return (name.contains('unplated') ? 10000 : 0) +
            (int.tryParse(RegExp(r'(?:targetsize-|scale-)(\d+)')
                        .firstMatch(name)
                        ?.group(1) ??
                    '') ??
                100);
      }

      return score(b).compareTo(score(a));
    });
    return candidates.map((f) => f.path).toList();
  }

  Future<List<GameEntry>> _registeredPrograms() async {
    final results = <GameEntry>[];
    for (final item in await _programs) {
      if (_cancelled) break;
      if (item.registryKey.toLowerCase().startsWith('steam app ') ||
          item.publisher.toLowerCase().contains('gog')) {
        continue;
      }
      final reference = parseIconReference(item.icon);
      // Um ícone DLL não é um alvo de inicialização. Nesses casos o AppsFolder
      // ou o atalho fornece a ação correta; não inventamos um executável.
      if (!reference.path.toLowerCase().endsWith('.exe') ||
          !await File(reference.path).exists() ||
          isSupportExecutable(reference.path)) {
        continue;
      }
      final publisher = item.publisher.toLowerCase();
      final platform = publisher.contains('ubisoft')
          ? 'Ubisoft'
          : publisher.contains('electronic arts')
              ? 'EA'
              : 'Outros';
      results.add(GameEntry(
          name: item.name,
          exePath: reference.path,
          installDir: item.installDirectory.isEmpty
              ? p.dirname(reference.path)
              : item.installDirectory,
          platform: platform,
          priority: 50,
          iconSources: [item.icon, reference.path]));
    }
    return results;
  }

  /// Resolve somente quando é preciso ícone ou quando um jogo portátil não
  /// possui manifesto. A lista instalada nunca depende desta varredura.
  Future<String?> executableFor(GameEntry game) =>
      _executables.putIfAbsent('${game.installDir.toLowerCase()}|${game.name}',
          () async {
        if (game.installDir.isEmpty) return null;
        final queue = <({String directory, int depth})>[
          (directory: game.installDir, depth: 0)
        ];
        final candidates = <({String file, int score})>[];
        final wanted = _words(game.name);
        while (queue.isNotEmpty && !_cancelled) {
          final folder = queue.removeAt(0);
          final items = await _list(folder.directory);
          final names =
              items.map((f) => p.basename(f.path).toLowerCase()).toSet();
          for (final file in items.whereType<File>()) {
            if (p.extension(file.path).toLowerCase() != '.exe' ||
                isSupportExecutable(file.path)) {
              continue;
            }
            final name = p.basenameWithoutExtension(file.path);
            final words = _words(name);
            final common = words.intersection(wanted).length;
            var score = common * 300 + (folder.depth == 0 ? 40 : 0);
            final relative =
                p.relative(file.path, from: game.installDir).toLowerCase();
            if (relative.contains('win64') || relative.contains('x64')) {
              score += 70;
            }
            if (name.toLowerCase().endsWith('-shipping')) score += 80;
            if (names.contains('${name.toLowerCase()}_data')) score += 200;
            if (names.contains('steam_api64.dll') ||
                names.contains('steam_api.dll')) {
              score += 100;
            }
            if (RegExp(r'launcher|bootstrap|config|benchmark',
                    caseSensitive: false)
                .hasMatch(name)) {
              score -= 250;
            }
            candidates.add((file: file.path, score: score));
          }
          if (folder.depth < 5) {
            for (final child in items.whereType<Directory>()) {
              if (!p.basename(child.path).toLowerCase().endsWith('_data') &&
                  !RegExp(r'^(engine|content|redist|_commonredist|support|tools|mods|cache|logs|extras|data)$',
                          caseSensitive: false)
                      .hasMatch(p.basename(child.path))) {
                queue.add((directory: child.path, depth: folder.depth + 1));
              }
            }
          }
        }
        final descriptions = await readWindowsExecutableDescriptions(
            candidates.map((c) => c.file).toList());
        int score(({String file, int score}) candidate) {
          final description = descriptions[candidate.file] ?? '';
          final compactName = p
              .basenameWithoutExtension(candidate.file)
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '');
          final compactTitle =
              game.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          final descriptionScore =
              _words(description).intersection(wanted).length * 500;
          final nameScore = compactName == compactTitle
              ? 800
              : compactName.length > 3 && compactTitle.contains(compactName)
                  ? 350
                  : 0;
          final helperPenalty = RegExp(
                      r'launcher|installer|crash|service|helper|server',
                      caseSensitive: false)
                  .hasMatch(description)
              ? 1500
              : 0;
          return candidate.score + descriptionScore + nameScore - helperPenalty;
        }

        candidates.sort((a, b) => score(b).compareTo(score(a)));
        return candidates.firstOrNull?.file;
      });

  Set<String> _words(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'\b(win64|win32|shipping|edition|game|the)\b'), ' ')
      .split(RegExp(r'[^a-z0-9]+'))
      .where((s) => s.isNotEmpty)
      .toSet();

  Future<List<String>> imageFiles(String directory) async {
    final images = (await _list(directory))
        .whereType<File>()
        .where((file) => ['.png', '.jpg', '.jpeg', '.webp', '.bmp']
            .contains(p.extension(file.path).toLowerCase()))
        .map((f) => f.path)
        .toList();
    images.sort((a, b) {
      int score(String name) => RegExp(r'hero|background|wallpaper',
                  caseSensitive: false)
              .hasMatch(name)
          ? 3
          : RegExp(r'cover|banner|header', caseSensitive: false).hasMatch(name)
              ? 2
              : 1;
      return score(p.basename(b)).compareTo(score(p.basename(a)));
    });
    return images;
  }
}

bool isSupportExecutable(String filename) => RegExp(
        r'(^|[\\/])(unins\w*|setup\w*|install\w*|.*crash.*|.*redist.*|dxsetup|.*anticheat.*|.*helper|.*server)\.exe$',
        caseSensitive: false)
    .hasMatch(filename);

({String path, int index}) parseIconReference(String raw) {
  final match = RegExp(r'^\s*"?(.*?)"?\s*,\s*(-?\d+)\s*$').firstMatch(raw);
  return (
    path: expandWindowsEnvironment(
        (match?.group(1) ?? raw).replaceAll('"', '').trim()),
    index: int.tryParse(match?.group(2) ?? '') ?? 0
  );
}

Map<String, String> xmlAttributes(String text) => {
      for (final match
          in RegExp(r'''([\w:.-]+)\s*=\s*(["'])(.*?)\2''', dotAll: true)
              .allMatches(text))
        match.group(1)!: match
            .group(3)!
            .replaceAll('&amp;', '&')
            .replaceAll('&quot;', '"')
            .replaceAll('&apos;', "'")
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>'),
    };

/// Regras de aspas e barras da linha de comando do Windows, sem chamar shell.
List<String> splitWindowsArguments(String input) {
  final args = <String>[];
  final token = StringBuffer();
  var quoted = false;
  var started = false;
  var i = 0;
  while (i < input.length) {
    if (input[i] == '\\') {
      final start = i;
      while (i < input.length && input[i] == '\\') {
        i++;
      }
      final count = i - start;
      if (i < input.length && input[i] == '"') {
        token.write('\\' * (count ~/ 2));
        if (count.isOdd) {
          token.write('"');
        } else {
          quoted = !quoted;
        }
        i++;
      } else {
        token.write('\\' * count);
      }
      started = true;
    } else if (input[i] == '"') {
      quoted = !quoted;
      started = true;
      i++;
    } else if (!quoted && input[i].trim().isEmpty) {
      if (started) {
        args.add(token.toString());
        token.clear();
        started = false;
      }
      i++;
    } else {
      token.write(input[i++]);
      started = true;
    }
  }
  if (started) args.add(token.toString());
  return args;
}
