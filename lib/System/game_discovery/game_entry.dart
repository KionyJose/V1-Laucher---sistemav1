class GameEntry {
  GameEntry(
      {required this.name,
      required this.exePath,
      required this.installDir,
      required this.platform,
      this.id,
      this.thumbnailPath,
      this.iconSource,
      this.artworkSource,
      this.iconSources = const [],
      this.backgroundSources = const [],
      this.arguments = const [],
      this.workingDirectory,
      this.priority = 100,
      bool? isGame})
      : _isGame = isGame;
  final bool? _isGame;
  bool get isGame =>
      _isGame ?? const ['Steam', 'Epic Games', 'GOG'].contains(platform);
  final String name;
  final String exePath;
  final String installDir;
  final String platform;
  final String? id;
  final String? thumbnailPath;
  final String? iconSource;
  final String? artworkSource;
  final List<String> iconSources;
  final List<String> backgroundSources;
  final List<String> arguments;
  final String? workingDirectory;
  final int priority;

  /// Preserva o alvo e os metadados da fonte preferida ao unir um jogo detectado.
  GameEntry asGame() => isGame
      ? this
      : GameEntry(
          name: name,
          exePath: exePath,
          installDir: installDir,
          platform: platform,
          id: id,
          thumbnailPath: thumbnailPath,
          iconSource: iconSource,
          artworkSource: artworkSource,
          iconSources: iconSources,
          backgroundSources: backgroundSources,
          arguments: arguments,
          workingDirectory: workingDirectory,
          priority: priority,
          isGame: true,
        );

  String get key =>
      id == null ? '$platform:${exePath.toLowerCase()}' : '$platform:$id';
}
