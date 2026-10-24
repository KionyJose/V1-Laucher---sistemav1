import 'package:flutter/material.dart';

/// Implementação pública: a loja interna não está disponível nesta build.
///
/// Quem builda localmente com o pacote privado (via `dependency_overrides`
/// em `pubspec_overrides.yaml`, nunca versionado) recebe a tela real no lugar
/// desta. Veja `packages/loja_feature_stub/README.md`.
Widget buildLojaScreen() => const _LojaIndisponivel();

class _LojaIndisponivel extends StatelessWidget {
  const _LojaIndisponivel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.storefront_outlined, size: 48),
              SizedBox(height: 12),
              Text('Loja interna não disponível nesta build.',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
