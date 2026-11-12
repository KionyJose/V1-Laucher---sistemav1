import 'dart:math' as math;

import 'package:flutter/material.dart';

class GtaViScene {
  const GtaViScene(this.name, this.background,
      {this.characters, this.car, this.object});
  final String name, background;
  final String? characters, car, object;

  static const values = [
    GtaViScene('Ocean Drive', 'assets/GtaVI/sunset-clean.png',
        characters: 'assets/GtaVI/couple.png', car: 'assets/GtaVI/car.png'),
    GtaViScene('Vice City à noite', 'assets/GtaVI/vice-night.jpg',
        characters: 'assets/GtaVI/couple.png'),
    GtaViScene('Pelas ruas', 'assets/GtaVI/vice-skyline.jpg',
        characters: 'assets/GtaVI/combat-isolated.png',
        car: 'assets/GtaVI/car.png'),
    GtaViScene('Leonida Keys', 'assets/GtaVI/leonida-coast.jpg',
        object: 'assets/GtaVI/palm.png'),
    GtaViScene('Grassrivers', 'assets/GtaVI/grassrivers.jpg',
        object: 'assets/GtaVI/gator.png'),
    GtaViScene('Depois do pôr do sol', 'assets/GtaVI/club-background.jpg',
        characters: 'assets/GtaVI/boobie-layer.png'),
  ];
}

/// Só as camadas de arte animam; foco, biblioteca e textos permanecem estáveis.
class GtaViBackdrop extends StatefulWidget {
  const GtaViBackdrop(
      {super.key,
      required this.scene,
      required this.motion,
      required this.enabled});
  final int scene;
  final ValueNotifier<Offset> motion;
  final bool enabled;

  @override
  State<GtaViBackdrop> createState() => _GtaViBackdropState();
}

class _GtaViBackdropState extends State<GtaViBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: const Duration(seconds: 18));

  void _sync() {
    if (widget.enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!_drift.isAnimating) _drift.repeat(reverse: true);
    } else {
      _drift.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(GtaViBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  Widget _image(String asset,
          {BoxFit fit = BoxFit.cover,
          Alignment alignment = Alignment.center}) =>
      Image.asset(asset,
          fit: fit,
          alignment: alignment,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => asset == 'assets/GtaVI/sunset-clean.png'
              ? Image.asset('assets/GtaVI/vice-night.jpg', fit: fit)
              : const SizedBox.shrink());

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
        child: ClipRect(
            child: LayoutBuilder(
      builder: (context, bounds) => TweenAnimationBuilder<Offset>(
        tween: Tween(
            begin: Offset.zero,
            end: reduce ? Offset.zero : widget.motion.value),
        duration: Duration(milliseconds: reduce ? 0 : 550),
        curve: Curves.easeOutCubic,
        builder: (_, pointer, __) => AnimatedBuilder(
          animation: _drift,
          builder: (_, __) {
            final drift = reduce ? 0.0 : math.sin(_drift.value * math.pi) * 5;
            return AnimatedSwitcher(
              duration: Duration(milliseconds: reduce ? 0 : 1300),
              child: SizedBox.expand(
                  key: ValueKey(widget.scene),
                  child: Stack(fit: StackFit.expand, children: [
                    const DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                          Color(0xFF373459),
                          Color(0xFF9A668D),
                          Color(0xFFD88C99),
                          Color(0xFF485178)
                        ],
                                stops: [
                          0,
                          .42,
                          .72,
                          1
                        ]))),
                    Transform.translate(
                        offset:
                            Offset(pointer.dx * -8 + drift, pointer.dy * -5),
                        child: Transform.scale(
                            scale: 1.07,
                            child: Opacity(
                                opacity: .30,
                                child: _image(GtaViScene
                                    .values[widget.scene].background)))),
                    const DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: RadialGradient(
                                center: Alignment(.5, -.3),
                                radius: 1.1,
                                colors: [
                          Color(0x35FFD1AD),
                          Color(0x004A3259)
                        ]))),
                    if (GtaViScene.values[widget.scene].car
                        case final String car)
                      Positioned(
                          left: bounds.maxWidth * .52,
                          right: -bounds.maxWidth * .03,
                          bottom: bounds.maxHeight * .12,
                          height: bounds.maxHeight * .35,
                          child: Transform.translate(
                              offset: Offset(pointer.dx * 13, pointer.dy * 7),
                              child: _image(car,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomRight))),
                    if (GtaViScene.values[widget.scene].characters
                        case final String people)
                      Positioned(
                          right: -bounds.maxWidth * .015,
                          bottom: 0,
                          width: bounds.maxWidth * .52,
                          height: bounds.maxHeight * .83,
                          child: Transform.translate(
                              offset: Offset(pointer.dx * 23 - drift, 0),
                              child: _image(people,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomRight))),
                    if (GtaViScene.values[widget.scene].object
                        case final String object)
                      Positioned(
                          right: bounds.maxWidth * .035,
                          bottom: bounds.maxHeight * .16,
                          width: bounds.maxWidth * .40,
                          height: bounds.maxHeight * .66,
                          child: Transform.translate(
                              offset: Offset(pointer.dx * 14, pointer.dy * 6),
                              child: _image(object,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomRight))),
                  ])),
            );
          },
        ),
      ),
    )));
  }
}
