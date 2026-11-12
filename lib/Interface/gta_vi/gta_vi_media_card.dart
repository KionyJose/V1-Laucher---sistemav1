import 'package:flutter/material.dart';

import '../futuristic_artwork.dart';
import 'gta_vi_widgets.dart';

/// Reserva a legenda fora da imagem, sem deslocar a grade ao mudar o foco.
class GtaViMediaCard extends StatefulWidget {
  const GtaViMediaCard(
      {super.key,
      required this.name,
      required this.image,
      required this.onPressed,
      this.focusNode});
  final String name, image;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  @override
  State<GtaViMediaCard> createState() => _GtaViMediaCardState();
}

class _GtaViMediaCardState extends State<GtaViMediaCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(
            child: Semantics(
                label: widget.name,
                child: GtaViButton(
                    focusNode: widget.focusNode,
                    bare: true,
                    padding: EdgeInsets.zero,
                    radius: 4,
                    onFocusChange: (focused) {
                      if (mounted) setState(() => _focused = focused);
                    },
                    onPressed: widget.onPressed,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox.expand(
                            child: FuturisticArtwork(
                                image: widget.image, fit: BoxFit.cover)))))),
        const SizedBox(height: 6),
        SizedBox(
            height: 22,
            child: _focused
                ? Text(widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: gtaCream,
                        fontSize: 13,
                        fontWeight: FontWeight.w600))
                : null),
      ]);
}
