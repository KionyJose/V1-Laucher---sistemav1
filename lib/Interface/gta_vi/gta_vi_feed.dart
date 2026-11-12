import 'dart:isolate';
import 'dart:math';

import '../../Class/WebScrap.dart';
import '../../Modelos/NoticiaGame.dart';
import '../../Modelos/videoYT.dart';
import '../futuristic_game_feed.dart';

/// A página inicial e as seções dedicadas compartilham as mesmas requisições.
class GtaViFeed {
  static final _random = Random();
  static String? _lastSuggestion, _lastVideo;
  static const _suggestions = [
    ('GTA VI', 'notícias'),
    ('GTA VI', 'highlights'),
    ('GTA 6', 'gameplay'),
    ('GTA VI', 'funny'),
    ('GTA 6', 'curiosidades'),
    ('GTA VI', 'Vice City exploração'),
  ];

  static Future<VideoYT?> suggestion() async {
    final choices = _suggestions
        .where((item) => '${item.$1}|${item.$2}' != _lastSuggestion)
        .toList();
    final choice = choices[_random.nextInt(choices.length)];
    _lastSuggestion = '${choice.$1}|${choice.$2}';
    final items = await videos(choice.$2, game: choice.$1, refresh: true);
    if (items.isEmpty) return null;
    final fresh = items.where((video) => video.videoID != _lastVideo).toList();
    final pool = fresh.isEmpty ? items : fresh;
    final video = pool[_random.nextInt(pool.length.clamp(1, 8))];
    _lastVideo = video.videoID;
    return video;
  }

  static final _cache = <String, ({DateTime at, List<VideoYT> videos})>{};
  static final _pending = <String, Future<List<VideoYT>>>{};

  static Future<List<NoticiaGame>> news(
      {String topic = '', bool refresh = false}) async {
    final query = 'Grand Theft Auto VI $topic'.trim();
    if (refresh) FuturisticGameFeed.invalidate(query);
    final feed = await FuturisticGameFeed.load(query);
    return feed.news;
  }

  static Future<List<VideoYT>> videos(String topic,
      {String game = 'GTA VI', bool refresh = false}) {
    final key = '$game|$topic';
    final cached = _cache[key];
    if (!refresh &&
        cached != null &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 15)) {
      return Future.value(cached.videos);
    }
    return _pending.putIfAbsent(key, () async {
      try {
        final videos = await Isolate.run(() => WebScrap.buscaVideosYT(
            Uri.encodeQueryComponent('$game $topic'),
            'Grand Theft Auto VI')).timeout(const Duration(seconds: 25));
        final unique = <String, VideoYT>{};
        for (final video in videos) {
          if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(video.videoID)) {
            unique.putIfAbsent(video.videoID, () => video);
          }
        }
        final items = unique.values.take(18).toList();
        if (items.isNotEmpty) {
          _cache[key] = (at: DateTime.now(), videos: items);
        }
        return items;
      } finally {
        _pending.remove(key);
      }
    });
  }
}
