import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../Tela loja/scraps/catalogo_scraper.dart';

/// Um jogo na grade do Descobrir.
///
/// O cartão é 21:9 — mais largo que a capa da loja, que assim preenche a
/// altura inteira e sobra nas pontas, em vez de deixar faixa vazia.
///
/// Quem está selecionado é dito por [selecionado], e não por foco próprio: a
/// grade guarda o índice e o cartão só desenha o estado.
class DescobrirCard extends StatelessWidget {
  const DescobrirCard({
    super.key,
    required this.jogo,
    required this.selecionado,
    required this.onAbrir,
  });

  final JogoCatalogo jogo;
  final bool selecionado;
  final VoidCallback onAbrir;

  static const violeta = Color(0xFFB6A8FF);
  static const _raio = BorderRadius.all(Radius.circular(4));

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selecionado,
        label: jogo.nome,
        child: GestureDetector(
          onTap: onAbrir,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            scale: selecionado ? 1.035 : .92,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: _raio,
                border: Border.all(
                    color: selecionado
                        ? violeta
                        : Colors.white.withValues(alpha: .07),
                    width: selecionado ? 2.2 : 1),
                boxShadow: selecionado
                    ? [
                        BoxShadow(
                            color: violeta.withValues(alpha: .38),
                            blurRadius: 26,
                            spreadRadius: 1),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: _raio,
                child: _Capa(jogo: jogo),
              ),
            ),
          ),
        ),
      );
}

class _Capa extends StatelessWidget {
  const _Capa({required this.jogo});
  final JogoCatalogo jogo;

  @override
  Widget build(BuildContext context) {
    const reserva = ColoredBox(
      color: Color(0xFF1A1726),
      child: Center(
        child: Icon(Icons.sports_esports_outlined,
            size: 40, color: Color(0xFF4B4470)),
      ),
    );
    final imagem = jogo.imagem;
    if (imagem == null) return reserva;
    return CachedNetworkImage(
      imageUrl: imagem.toString(),
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => const ColoredBox(color: Color(0xFF14121E)),
      errorWidget: (_, __, ___) => reserva,
    );
  }
}
