import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../Modelos/IconeInicial.dart';
import '../../System/game_discovery/game_artwork_service.dart';
import '../../System/game_discovery/game_entry.dart';
import 'gta_vi_widgets.dart';

/// Ícone do alvo real (EXE, atalho ou Shell), nunca uma capa esticada.
class GtaViAppIcon extends StatelessWidget {
  const GtaViAppIcon(
      {super.key, required this.game, required this.artwork, this.size = 40});
  final IconInicial game;
  final GameArtworkService artwork;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size,
      child: FutureBuilder<ui.Image?>(
        future: artwork.iconFor(GameEntry(
            name: game.nome,
            exePath: game.local,
            installDir: path.windows.dirname(game.local),
            platform: 'Outros',
            isGame: true)),
        builder: (_, snapshot) => switch (snapshot.data) {
          final ui.Image icon => RawImage(
              image: icon,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium),
          _ => Icon(Icons.sports_esports_outlined,
              color: gtaCream, size: size * .75),
        },
      ));
}
