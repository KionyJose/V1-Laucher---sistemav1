import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:v1_game/Class/Paad.dart';
import 'games_busca_ctrl.dart';
import 'game_search_artwork.dart';

class GamesBuscaTela {
  static Future<dynamic> abrir(BuildContext context) async {
    // Controller de scroll para seguir o foco do Paad
    final ScrollController scrollController = ScrollController();
    // Keys para cada item do grid, usadas com Scrollable.ensureVisible
    final Map<String, GlobalKey> itemKeys = {};

    final resultado = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return ChangeNotifierProvider(
          create: (_) => GamesBuscaCtrl(),
          child: Consumer<GamesBuscaCtrl>(
            builder: (context, ctrl, child) {
              // Atualizações da busca não devem repetir comandos do pad.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted || ctrl.closing) return;

                // Inicia scan quando necessário
                if (!ctrl.loading && !ctrl.scanned) {
                  ctrl.startScan();
                }

                // Lógica para rolar a lista automaticamente conforme o foco
                if (scrollController.hasClients) {
                  final focusedIndex = ctrl.focusedForCurrent();
                  final games = ctrl.currentList;
                  final key = focusedIndex >= 0 && focusedIndex < games.length
                      ? itemKeys[games[focusedIndex].exePath]
                      : null;
                  if (key != null && key.currentContext != null) {
                    // Garante que o item focado fique totalmente visível (maneja último item corretamente)
                    Scrollable.ensureVisible(
                      key.currentContext!,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      alignment: 0.5,
                    );
                  } else {
                    // Fallback: cálculo simples de posição (mantido por segurança)
                    double position = (focusedIndex / 6).floor() * 140.0;
                    final max = scrollController.position.maxScrollExtent;
                    if (position > max) position = max;
                    if (position < 0) position = 0;
                    scrollController.animateTo(
                      position,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                }
              });

              return _GamesBuscaPadScope(
                controller: ctrl,
                child: Dialog(
                  backgroundColor: const Color(0xFF0F1622),
                  insetPadding: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.94,
                    height: MediaQuery.of(context).size.height * 0.9,
                    child: Column(
                      children: [
                        // Header Simplificado
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.videogame_asset,
                                  color: Colors.white70, size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'BIBLIOTECA DE JOGOS',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white54, size: 20),
                                onPressed: () =>
                                    Navigator.of(context).pop('cancelar'),
                              )
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white10),

                        // Abas de Plataformas (Chips menores)
                        if (ctrl.platformsFound.isNotEmpty)
                          Container(
                            height: 40,
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: ctrl.platformsFound.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (context, idx) {
                                final name = ctrl.platformsFound[idx];
                                final selected =
                                    idx == ctrl.selectedPlatformIndex;
                                return GestureDetector(
                                  onTap: () => ctrl.setPlatformByIndex(idx),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.blueAccent
                                              .withAlpha((0.2 * 255).toInt())
                                          : Colors.white
                                              .withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: selected
                                              ? Colors.blueAccent
                                              : Colors.transparent),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${name.toUpperCase()} (${ctrl.filtered.where((g) => name == 'Todos' || g.platform == name).length})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: selected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: selected
                                              ? Colors.white
                                              : Colors.white60,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        if (ctrl.loading && ctrl.currentList.isNotEmpty)
                          const LinearProgressIndicator(minHeight: 2),
                        if (ctrl.loading && ctrl.currentList.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 5),
                            child: Text('Buscando em: ${ctrl.scanStage}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11)),
                          ),
                        if (ctrl.sourceErrors.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 5),
                            child: Text(
                                'Não foi possível ler: ${ctrl.sourceErrors.keys.join(', ')}',
                                style: const TextStyle(
                                    color: Colors.amber, fontSize: 11)),
                          ),
                        // Grid de Jogos (Ícones menores e densos)
                        Expanded(
                          child: Builder(builder: (_) {
                            if (ctrl.loading && ctrl.currentList.isEmpty) {
                              return Center(
                                  child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                      strokeWidth: 2),
                                  const SizedBox(height: 12),
                                  Text('Buscando: ${ctrl.scanStage}',
                                      style: const TextStyle(
                                          color: Colors.white70)),
                                ],
                              ));
                            }
                            final listForPlatform = ctrl.currentList;
                            if (listForPlatform.isEmpty) {
                              return const Center(
                                  child: Text('Nenhum jogo encontrado',
                                      style: TextStyle(color: Colors.white38)));
                            }

                            return GridView.builder(
                              findChildIndexCallback: (key) {
                                if (key is! ValueKey<String>) return null;
                                final index = listForPlatform
                                    .indexWhere((g) => g.exePath == key.value);
                                return index < 0 ? null : index;
                              },
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    6, // Mais colunas = ícones menores
                                childAspectRatio: 9 / 15,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: listForPlatform.length,
                              itemBuilder: (context, index) {
                                final g = listForPlatform[index];
                                final focused =
                                    index == ctrl.focusedForCurrent();

                                return GestureDetector(
                                  key: ValueKey(g.exePath),
                                  onTap: () => ctrl.pickGame(context, g),
                                  child: Builder(builder: (itemCtx) {
                                    final itemKey = itemKeys.putIfAbsent(
                                        g.exePath, () => GlobalKey());
                                    return Container(
                                      key: itemKey,
                                      child: AnimatedScale(
                                        scale: focused ? 1.05 : 1.0,
                                        duration:
                                            const Duration(milliseconds: 100),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Container(
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFF1A1F2B),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: focused
                                                        ? Colors.blueAccent
                                                        : Colors.white10,
                                                    width: focused ? 2 : 1,
                                                  ),
                                                  boxShadow: focused
                                                      ? [
                                                          BoxShadow(
                                                              color: Colors
                                                                  .blueAccent
                                                                  .withValues(
                                                                      alpha:
                                                                          0.3),
                                                              blurRadius: 8)
                                                        ]
                                                      : [],
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  child: GameSearchArtwork(
                                                      game: g, ctrl: ctrl),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              g.name,
                                              maxLines: 1,
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: focused
                                                    ? Colors.white
                                                    : Colors.white70,
                                                fontWeight: focused
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    scrollController.dispose();
    return resultado ?? 'cancelar';
  }
}

/// Recebe apenas comandos novos, independentemente das reconstruções da busca.
class _GamesBuscaPadScope extends StatefulWidget {
  const _GamesBuscaPadScope({required this.controller, required this.child});

  final GamesBuscaCtrl controller;
  final Widget child;

  @override
  State<_GamesBuscaPadScope> createState() => _GamesBuscaPadScopeState();
}

class _GamesBuscaPadScopeState extends State<_GamesBuscaPadScope> {
  Paad? _pad;
  ModalRoute<dynamic>? _route;
  void Function()? _detach;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    final pad = context.read<Paad>();
    if (identical(_pad, pad)) return;
    _detach?.call();
    _pad = pad;
    _detach = pad.interfaceRouter.attach(
      (command) => widget.controller.handlePad(command, context),
      acceptsCommand: () =>
          mounted && !widget.controller.closing && (_route?.isCurrent ?? false),
    );
  }

  @override
  void dispose() {
    _detach?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
