import 'package:flutter/material.dart';
import '../Controllers/launcher_window_controller.dart';

/// Mantém os sons do catálogo também nas rotas e diálogos abertos a partir dele.
class LauncherNavigationSounds extends InheritedTheme {
  const LauncherNavigationSounds({super.key, required super.child});

  static bool enabledOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LauncherNavigationSounds>() !=
      null;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      LauncherNavigationSounds(child: child);

  @override
  bool updateShouldNotify(LauncherNavigationSounds oldWidget) => false;
}

Future<T?> abrirTelaLauncher<T>(BuildContext context, Widget tela) async {
  final navigator = Navigator.of(context);
  final sonsNavegacao = LauncherNavigationSounds.enabledOf(context);
  await LauncherWindowController.instance.openContent();
  try {
    if (!context.mounted) return null;
    return await navigator.push<T>(PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => sonsNavegacao
          ? LauncherNavigationSounds(child: tela)
          : tela,
      transitionsBuilder: (_, animation, __, child) {
        final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
            opacity: curve,
            child: SlideTransition(
                position: curve.drive(
                    Tween(begin: const Offset(0, .035), end: Offset.zero)),
                child: child));
      },
    ));
  } finally {
    await LauncherWindowController.instance.closeContent();
  }
}
