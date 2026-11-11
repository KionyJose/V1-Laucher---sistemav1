import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:v1_game/Modelos/JogoBuscado.dart';
import '../../System/game_discovery/game_entry.dart';
import '../../System/game_discovery/game_artwork_service.dart';
import '../../System/game_discovery/installed_game_discovery.dart';
import '../../System/windows/open_windows_controller.dart';
export '../../System/game_discovery/game_entry.dart';

class GamesBuscaCtrl with ChangeNotifier {
  final OpenWindowsController openWindows = OpenWindowsController();
  final InstalledGameDiscovery _discovery = InstalledGameDiscovery();
  late final GameArtworkService artwork = GameArtworkService(_discovery);
  bool _disposed = false;
  bool closing = false;
  bool scanned = false;
  bool loading = false;
  bool _platformChosen = false;
  String scanStage = '';
  String query = '';
  List<GameEntry> allGames = [];
  List<GameEntry> filtered = [];
  List<String> platformsFound = [];
  int selectedPlatformIndex = 0;
  final Map<String, int> focusedIndex = {};
  final Map<String, String> sourceErrors = {};
  int inputDelayMs = 83;
  int _lastInputAt = 0;

  GamesBuscaCtrl() {
    openWindows.addListener(_windowsChanged);
    openWindows.start();
  }

  void _windowsChanged() {
    if (!closing) notifyListeners();
  }

  Future<ui.Image?> iconFor(GameEntry game) => artwork.iconFor(game);
  Future<String?> backgroundFor(GameEntry game) => artwork.backgroundFor(game);

  ui.Image? windowIconFor(GameEntry game) {
    final sources = [
      game.exePath,
      ...game.iconSources,
      ...artwork.resolvedIconPaths(game)
    ].map((s) => path.windows.normalize(s).toLowerCase()).toSet();
    for (final window in openWindows.windows) {
      if (window.executablePath.isEmpty) continue;
      final file = path.windows.normalize(window.executablePath).toLowerCase();
      if (sources.contains(file) ||
          (game.installDir.isNotEmpty &&
              game.platform != 'Outros' &&
              path.windows.isWithin(game.installDir.toLowerCase(), file))) {
        final icon = openWindows.icons.cached(window.hwnd);
        if (icon != null) return icon;
      }
    }
    return null;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _discovery.dispose();
    artwork.dispose();
    openWindows.removeListener(_windowsChanged);
    openWindows.dispose();
    super.dispose();
  }

  void setQuery(String value) {
    query = value;
    _applyFilter();
  }

  void clear() {
    query = '';
    _applyFilter();
  }

  void _applyFilter() {
    final previous = selectedPlatform;
    filtered = allGames
        .where((game) => game.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    final present = filtered.map((game) => game.platform).toSet();
    platformsFound = [
      'Outros',
      'Steam',
      'Epic Games',
      'Microsoft Store',
      'GOG',
      'Ubisoft',
      'EA'
    ].where(present.contains).toList();
    platformsFound.addAll(present.where((p) => !platformsFound.contains(p)));
    if (platformsFound.isEmpty) platformsFound = ['Todos'];
    final preferred =
        !_platformChosen && present.contains('Outros') ? 'Outros' : previous;
    final index = platformsFound.indexOf(preferred);
    selectedPlatformIndex = index < 0 ? 0 : index;
    for (final platform in platformsFound) {
      final count = filtered
          .where((g) => platform == 'Todos' || g.platform == platform)
          .length;
      focusedIndex[platform] =
          (focusedIndex[platform] ?? 0).clamp(0, count > 0 ? count - 1 : 0);
    }
    notifyListeners();
  }

  String get selectedPlatform => platformsFound.isEmpty
      ? 'Todos'
      : platformsFound[
          selectedPlatformIndex.clamp(0, platformsFound.length - 1)];
  List<GameEntry> get currentList => selectedPlatform == 'Todos'
      ? filtered
      : filtered.where((game) => game.platform == selectedPlatform).toList();

  void startScan() {
    unawaited(scanAll());
  }

  Future<void> scanAll({int? limit}) async {
    if (loading || _disposed || closing) return;
    scanned = true;
    loading = true;
    sourceErrors.clear();
    final pending = {
      'Área de Trabalho',
      'Steam',
      'Epic Games',
      'GOG',
      'Microsoft Store',
      'Xbox / Game Pass',
      'Programas instalados',
      'Pastas de jogos'
    };
    final entries = <String, GameEntry>{};
    scanStage = pending.join(' · ');
    notifyListeners();
    try {
      await for (final batch in _discovery.scan()) {
        if (_disposed || closing) break;
        pending.remove(batch.source);
        if (batch.error != null) sourceErrors[batch.source] = batch.error!;
        for (final game in batch.games) {
          final existing = entries[game.key];
          int artworkScore(GameEntry value) =>
              value.iconSources.length + value.backgroundSources.length * 2;
          if (existing == null) {
            entries[game.key] = game;
          } else {
            final preferred =
                artworkScore(game) >= artworkScore(existing) ? game : existing;
            entries[game.key] =
                game.isGame || existing.isGame ? preferred.asGame() : preferred;
          }
        }
        // IDs de lojas distintas não colidem só porque têm o mesmo nome.
        // Atalhos e entradas genéricas repetidos ficam representados pela fonte
        // que oferece o alvo correto e os melhores metadados.
        final stores =
            entries.values.where((g) => g.platform != 'Outros').toList();
        final generic = <String, GameEntry>{};
        for (final game
            in entries.values.where((g) => g.platform == 'Outros')) {
          final storeIndex = stores.indexWhere((s) =>
              s.name.toLowerCase() == game.name.toLowerCase() ||
              s.exePath.toLowerCase() == game.exePath.toLowerCase());
          if (storeIndex >= 0) {
            if (game.isGame) {
              stores[storeIndex] = stores[storeIndex].asGame();
            }
            continue;
          }
          final key = game.name.toLowerCase();
          final old = generic[key];
          if (old == null) {
            generic[key] = game;
          } else {
            final preferred = game.priority < old.priority ? game : old;
            generic[key] =
                game.isGame || old.isGame ? preferred.asGame() : preferred;
          }
        }
        allGames = [
          ...stores,
          ...generic.values
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        scanStage = pending.join(' · ');
        _applyFilter();
      }
    } catch (error) {
      debugPrint('[GAMES_BUSCA] Erro de descoberta: $error');
    } finally {
      loading = false;
      scanStage = '';
      debugPrint('[GAMES_BUSCA] Busca concluída: ${allGames.length} itens');
      notifyListeners();
    }
  }

  void setPlatformByIndex(int i) {
    _platformChosen = true;
    if (platformsFound.isEmpty) return;
    if (i < 0) {
      selectedPlatformIndex = 0;
    } else if (i >= platformsFound.length) {
      selectedPlatformIndex = platformsFound.length - 1;
    } else {
      selectedPlatformIndex = i;
    }
    notifyListeners();
  }

  void nextPlatform() {
    _platformChosen = true;
    if (platformsFound.isEmpty) return;
    selectedPlatformIndex = (selectedPlatformIndex + 1) % platformsFound.length;
    notifyListeners();
  }

  void prevPlatform() {
    _platformChosen = true;
    if (platformsFound.isEmpty) return;
    selectedPlatformIndex = (selectedPlatformIndex - 1) < 0
        ? platformsFound.length - 1
        : selectedPlatformIndex - 1;
    notifyListeners();
  }

  int focusedForCurrent() {
    final p = selectedPlatform;
    return focusedIndex[p] ?? 0;
  }

  void _setFocusedForCurrent(int v) {
    final p = selectedPlatform;
    focusedIndex[p] = v;
    notifyListeners();
  }

  void moveFocus(String dir) {
    final list = currentList;
    if (list.isEmpty) return;
    const cross = 6; // grid columns
    int idx = focusedForCurrent();
    if (dir == 'ESQUERDA') idx = (idx - 1) < 0 ? 0 : idx - 1;
    if (dir == 'DIREITA') {
      idx = (idx + 1) >= list.length ? list.length - 1 : idx + 1;
    }
    if (dir == 'CIMA') idx = (idx - cross) < 0 ? 0 : idx - cross;
    if (dir == 'BAIXO') {
      idx = (idx + cross) >= list.length ? list.length - 1 : idx + cross;
    }
    _setFocusedForCurrent(idx);
  }

  /// Handle pad input events (called by UI Consumer/escuta)
  void handlePad(String? event, BuildContext context) {
    if (_disposed || closing || !context.mounted) return;
    if (event == null || event.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastInputAt < inputDelayMs) return;
    _lastInputAt = now;
    if (event == 'RB') {
      nextPlatform();
      return;
    }
    if (event == 'LB') {
      prevPlatform();
      return;
    }
    if (event == 'CIMA' ||
        event == 'BAIXO' ||
        event == 'ESQUERDA' ||
        event == 'DIREITA') {
      moveFocus(event);
      return;
    }
    if (event == '2' || event == 'SELECT') {
      // pick focused
      final list = currentList;
      if (list.isEmpty) return;
      final idx = focusedForCurrent();
      if (idx >= 0 && idx < list.length) pickGame(context, list[idx]);
      return;
    }
    if (event == '3' || event == 'START') {
      closing = true;
      Navigator.of(context).pop('cancelar');
      return;
    }
  }

  /// Handler when the user selects a game; returns a `JogoBuscado` model via Navigator.
  void pickGame(BuildContext context, GameEntry game) {
    if (_disposed || closing || !context.mounted) return;
    closing = true;
    final j = JogoBuscado(
      name: game.name,
      exePath: game.exePath,
      installDir: game.installDir,
      platform: game.platform,
      thumbnailPath: game.thumbnailPath,
      arguments: game.arguments,
      workingDirectory: game.workingDirectory,
    );
    Navigator.of(context).pop(j);
  }
}
