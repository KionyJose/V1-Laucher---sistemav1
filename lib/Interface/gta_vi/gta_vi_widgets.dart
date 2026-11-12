import 'package:flutter/material.dart';

const gtaPink = Color(0xFFFF8FBD);
const gtaCream = Color(0xFFFFF3E5);
const gtaSurface = Color(0xF21D152A);

/// Um único tratamento de foco para mouse, teclado e controle.
class GtaViButton extends StatefulWidget {
  const GtaViButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.focusNode,
    this.onFocusChange,
    this.selected = false,
    this.autofocus = false,
    this.bare = false,
    this.radius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  });

  final Widget child;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final bool selected, autofocus, bare;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  State<GtaViButton> createState() => _GtaViButtonState();
}

class _GtaViButtonState extends State<GtaViButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Semantics(
      selected: widget.selected,
      child: AnimatedContainer(
          duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220),
          decoration: BoxDecoration(
            gradient: widget.bare
                ? null
                : LinearGradient(
                    begin: widget.selected
                        ? Alignment.bottomCenter
                        : Alignment.bottomLeft,
                    end: widget.selected
                        ? Alignment.topCenter
                        : Alignment.topRight,
                    colors: [
                        Color(_focused
                            ? 0x338DF4E4
                            : widget.selected
                                ? 0x24FFB8CC
                                : 0x00FFB8CC),
                        const Color(0x00EBA3FC),
                      ]),
            border: Border(
                bottom: BorderSide(
                    color: _focused
                        ? gtaCream
                        : widget.selected
                            ? gtaPink
                            : Colors.transparent,
                    width: _focused ? 2 : 1)),
          ),
          child: TextButton(
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            onFocusChange: (focused) {
              if (!mounted) return;
              setState(() => _focused = focused);
              widget.onFocusChange?.call(focused);
            },
            onPressed: widget.onPressed,
            style: ButtonStyle(
              padding: WidgetStatePropertyAll(widget.padding),
              foregroundColor: const WidgetStatePropertyAll(gtaCream),
              backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
              overlayColor: WidgetStatePropertyAll(
                  widget.bare ? Colors.transparent : const Color(0x0AFFFFFF)),
              side: const WidgetStatePropertyAll(BorderSide.none),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(widget.radius))),
            ),
            child: widget.child,
          )));
}

class GtaViTopic {
  const GtaViTopic(this.label, this.query, this.asset);
  final String label, query, asset;
  static const values = [
    GtaViTopic('Em cartaz', 'Trailers', 'assets/GtaVI/phone.png'),
    GtaViTopic('Pelas ruas', 'Veículos carros', 'assets/GtaVI/cruiser.png'),
    GtaViTopic('Só em Leonida', 'animais natureza curiosidades',
        'assets/GtaVI/gator.png'),
    GtaViTopic(
        'Pelo paraíso', 'Vice City Leonida Keys mapa', 'assets/GtaVI/palm.png'),
    GtaViTopic(
        'Suas histórias', 'Jason Lucia personagens', 'assets/GtaVI/couple.png'),
    GtaViTopic(
        'Sem roteiro', 'Gameplay análises', 'assets/GtaVI/combat-isolated.png'),
  ];
  static const news = [
    GtaViTopic('Destaques', '', 'assets/GtaVI/phone.png'),
    GtaViTopic('Rockstar', 'Rockstar Games anúncios', 'assets/GtaVI/logo.png'),
    GtaViTopic('Pelo mapa', 'mapa Vice City Leonida', 'assets/GtaVI/palm.png'),
    GtaViTopic('Nas ruas', 'veículos carros', 'assets/GtaVI/cruiser.png'),
    GtaViTopic(
        'Só em Leonida', 'curiosidades animais', 'assets/GtaVI/gator.png'),
  ];
}

class GtaViTopicIcon extends StatelessWidget {
  const GtaViTopicIcon({super.key, required this.asset, this.size = 56});
  final String asset;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: 256,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.auto_awesome, color: gtaPink, size: size * .6));
}
