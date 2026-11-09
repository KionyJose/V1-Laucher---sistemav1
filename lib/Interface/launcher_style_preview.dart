import 'dart:io';

import 'package:flutter/material.dart';

/// Miniaturas dos layouts, sem montar os corpos reais e seus FocusNodes.
/// Uma tela de 960 x 540 e reduzida uniformemente para preservar o 16:9.
class LauncherStylePreview extends StatelessWidget {
  const LauncherStylePreview(
      {super.key, required this.style, this.capas = const []});
  final String style;
  final List<String> capas;

  static const _accent = Color(0xFFC9B9FF);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: IgnorePointer(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 960,
                  height: 540,
                  child: Stack(fit: StackFit.expand, children: [
                    const ColoredBox(color: Color(0xFF0B101C)),
                    if (style == 'futurista')
                      Image.asset('assets/Futurista/aurora_lake.png',
                          fit: BoxFit.cover),
                    if (style != 'futurista' && style != 'slim')
                      Opacity(opacity: .28, child: _arte(0)),
                    const DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                          Color(0x50080A12),
                          Color(0xE6080A12)
                        ]))),
                    if (style != 'slim') _cabecalho(),
                    ..._conteudo(),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _arte(int index) {
    Widget reserva() => DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                Color.lerp(const Color(0xFF31546B), const Color(0xFF614477),
                    (index % 5) / 4)!,
                const Color(0xFF141B2A)
              ])),
          child: Center(
              child: Icon(Icons.sports_esports_outlined,
                  size: 44, color: Colors.white.withValues(alpha: .35))),
        );
    if (capas.isEmpty) return reserva();
    final capa = capas[index % capas.length];
    if (capa.startsWith('assets/')) {
      return Image.asset(capa,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => reserva());
    }
    return Image.file(File(capa),
        fit: BoxFit.cover,
        cacheWidth: 800,
        errorBuilder: (_, __, ___) => reserva());
  }

  Widget _capa(int index, double width, double height,
          {bool selected = false, bool square = false}) =>
      Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(selected ? 3 : 0),
        decoration: BoxDecoration(
            color: selected ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(square ? 2 : 16)),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(square ? 1 : 13),
            child: Stack(fit: StackFit.expand, children: [
              _arte(index),
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xA0000000)]))),
            ])),
      );

  Widget _cabecalho() => Positioned(
        left: 42,
        right: 42,
        top: 30,
        child: Row(children: [
          const Text('V1',
              style: TextStyle(
                  fontSize: 26,
                  letterSpacing: 4,
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 36),
          for (final nome in ['Games', 'Cinema', 'Musica', 'Loja'])
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                    color: nome == 'Games'
                        ? Colors.white.withValues(alpha: .15)
                        : null,
                    borderRadius: BorderRadius.circular(24)),
                child: Text(nome,
                    style: TextStyle(
                        fontSize: 16,
                        color:
                            nome == 'Games' ? Colors.white : Colors.white54))),
          const Spacer(),
          const Icon(Icons.more_horiz, color: Colors.white60),
        ]),
      );

  Widget _texto(String texto, double size, {Color color = Colors.white}) =>
      Text(texto,
          style: TextStyle(
              fontSize: size,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: .8));

  List<Widget> _conteudo() => switch (style) {
        'grid' => [
            Positioned(left: 42, top: 112, child: _texto('BIBLIOTECA', 18)),
            Positioned(
                left: 42,
                right: 42,
                top: 157,
                bottom: 32,
                child: Column(children: [
                  for (var row = 0; row < 2; row++) ...[
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var i = 0; i < 5; i++)
                            _capa(row * 5 + i, 164, 159,
                                selected: row == 0 && i == 1),
                        ]),
                    if (row == 0) const SizedBox(height: 18),
                  ],
                ])),
          ],
        'transversal' => [
            Positioned(
                left: 42,
                top: 110,
                child: _texto('EXPLORE SUA BIBLIOTECA', 20)),
            for (var i = 0; i < 5; i++)
              Positioned(
                  left: 42 + i * 196.0,
                  top: i == 1 ? 160 : 185,
                  child: Transform(
                      transform: Matrix4.skewX(-.14),
                      child:
                          _capa(i, 180, i == 1 ? 320 : 275, selected: i == 1))),
          ],
        'futurista' => [
            Positioned(
                left: 48, top: 115, child: _texto('SUA PROXIMA JORNADA', 20)),
            Positioned(
                left: 48,
                top: 182,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 5; i++) ...[
                        _capa(i, i == 1 ? 216 : 164, i == 1 ? 216 : 164,
                            selected: i == 1),
                        const SizedBox(width: 20),
                      ],
                    ])),
            Positioned(
                left: 258,
                top: 426,
                child: _texto('JOGAR  /  DETALHES', 15,
                    color: const Color(0xFFA9EEE4))),
          ],
        'moderno' => [
            Positioned(
                left: 42, top: 126, child: _capa(0, 300, 300, selected: true)),
            Positioned(
                left: 380,
                top: 135,
                right: 42,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _texto('EM DESTAQUE', 16, color: _accent),
                      const SizedBox(height: 18),
                      _texto('Sua biblioteca de jogos', 30),
                      const SizedBox(height: 25),
                      Row(children: [
                        for (var i = 1; i < 4; i++) ...[
                          _capa(i, 150, 160),
                          const SizedBox(width: 14),
                        ]
                      ]),
                    ])),
            Positioned(
                left: 42,
                right: 42,
                bottom: 32,
                child: Container(
                    height: 52,
                    padding: const EdgeInsets.all(15),
                    color: Colors.white.withValues(alpha: .08),
                    child:
                        _texto('NOTICIAS  /  Novidades dos seus jogos', 16))),
          ],
        'retro' => [
            Positioned(
                left: 42,
                top: 105,
                child: _texto('SELECIONE SEU JOGO', 22,
                    color: const Color(0xFFB9F6CA))),
            Positioned(
                left: 42,
                top: 166,
                child:
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < 5; i++) ...[
                    _capa(i, i == 1 ? 196 : 148, i == 1 ? 264 : 226,
                        selected: i == 1, square: true),
                    const SizedBox(width: 24),
                  ],
                ])),
            Positioned(
                left: 42,
                bottom: 42,
                child: _texto(
                    'A  INICIAR     SELECT  ORDENAR     START  MENU', 15)),
          ],
        'slim' => [
            Positioned(
                left: 50,
                top: 42,
                child: _texto('WINDOWS', 16, color: Colors.white38)),
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                    height: 220,
                    padding: const EdgeInsets.all(24),
                    color: const Color(0xEE101018),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            for (var i = 0; i < 7; i++) ...[
                              _capa(i, 114, 124, selected: i == 1),
                              const SizedBox(width: 16),
                            ]
                          ]),
                          const SizedBox(height: 20),
                          _texto('GAMES     CINEMA     MUSICA     LOJA', 14,
                              color: Colors.white60),
                        ]))),
          ],
        _ => [
            Positioned(
                left: 42, top: 126, child: _texto('BIBLIOTECA DE JOGOS', 22)),
            Positioned(
                left: 42,
                top: 190,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 5; i++) ...[
                        _capa(i, i == 1 ? 194 : 144, i == 1 ? 265 : 215,
                            selected: i == 1),
                        const SizedBox(width: 24),
                      ],
                    ])),
          ],
      };
}
