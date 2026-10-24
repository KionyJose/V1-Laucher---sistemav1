import 'package:flutter/material.dart';

/// False nesta build pública: quem chama deve nem mostrar o card/botão da
/// loja interna, não só recusar abri-la. A implementação real (pacote local,
/// nunca versionado) exporta `true` no mesmo nome.
const bool lojaInternaDisponivel = false;

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
