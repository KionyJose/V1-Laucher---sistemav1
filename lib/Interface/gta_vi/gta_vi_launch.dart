import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'gta_vi_widgets.dart';

/// O loop do carro permanece até a volta; a saída termina antes de fechar a rota.
class GtaViLaunch extends StatefulWidget {
  const GtaViLaunch(
      {super.key,
      required this.background,
      required this.name,
      required this.ready,
      required this.onReturn});

  final Widget background;
  final String name;
  final ValueListenable<bool> ready;
  final VoidCallback onReturn;

  @override
  State<GtaViLaunch> createState() => GtaViLaunchState();
}

class GtaViLaunchState extends State<GtaViLaunch>
    with TickerProviderStateMixin {
  late final _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final _exit = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  bool _started = false, _leaving = false;
  Future<void>? _leaveFuture;

  void _startEntry() {
    if (!mounted || _started || _leaving) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entry.value = 1;
    } else {
      _entry.forward();
    }
  }

  Future<void> leave() => _leaveFuture ??= _leave();

  Future<void> _leave() async {
    if (!mounted) return;
    setState(() => _leaving = true);
    _entry.stop();
    if (MediaQuery.disableAnimationsOf(context)) {
      _exit.value = 1;
      return;
    }
    try {
      await _exit.forward().orCancel;
    } on TickerCanceled {
      // Fechar o aplicativo pode descartar a rota antes de a saída terminar.
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, bounds) {
        final side = (bounds.maxWidth * .64).clamp(280.0, 900.0);
        final travel = bounds.maxWidth / 2 + side;
        return Stack(fit: StackFit.expand, children: [
          ClipRect(
              child: RepaintBoundary(
                  child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: widget.background))),
          const ColoredBox(color: Color(0x66312646)),
          Positioned(
              top: bounds.maxHeight * .10,
              left: 24,
              right: 24,
              child: Center(
                  child: Image.asset('assets/GtaVI/logo.png', height: 85))),
          Center(
              child: IgnorePointer(
                  child: AnimatedBuilder(
            animation: Listenable.merge([_entry, _exit]),
            child: RepaintBoundary(
                child: Lottie.asset('assets/GtaVI/car-loading.json',
                    width: side,
                    height: side,
                    fit: BoxFit.contain,
                    repeat: true,
                    onLoaded: (_) => _startEntry(),
                    animate: !MediaQuery.disableAnimationsOf(context),
                    frameRate: FrameRate.composition,
                    errorBuilder: (_, __, ___) {
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _startEntry());
                      return const Icon(Icons.directions_car_rounded,
                          color: gtaPink, size: 100);
                    })),
            builder: (_, child) => Transform.translate(
                offset: Offset(
                    (1 - Curves.easeOutCubic.transform(_entry.value)) * travel -
                        Curves.easeInCubic.transform(_exit.value) * travel,
                    0),
                child: child),
          ))),
          Positioned(
              left: 30,
              right: 30,
              bottom: bounds.maxHeight * .08,
              child: ValueListenableBuilder<bool>(
                  valueListenable: widget.ready,
                  builder: (_, started, __) =>
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(widget.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: gtaCream,
                                fontSize: 28,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 18),
                        if (!started)
                          const SizedBox.square(
                              dimension: 26,
                              child: CircularProgressIndicator(
                                  color: gtaPink, strokeWidth: 2))
                        else
                          GtaViButton(
                              autofocus: true,
                              onPressed: _leaving ? null : widget.onReturn,
                              child: const Text('Voltar ao launcher')),
                        const SizedBox(height: 12),
                        Text(
                            started
                                ? 'Seu jogo foi iniciado. Volte quando quiser.'
                                : 'Preparando sua próxima história…',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: gtaCream)),
                      ]))),
        ]);
      });
}
