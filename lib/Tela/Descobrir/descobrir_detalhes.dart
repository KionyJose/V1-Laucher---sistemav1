import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Controllers/SonsSistema.dart';
import '../../Interface/launcher_header.dart';
import '../../Interface/launcher_pad_scope.dart';
import '../Tela loja/componentes/erro_catalogo_painel.dart';
import '../Tela loja/scraps/catalogo_scraper.dart';
import '../Tela loja/scraps/diagnostico_catalogo.dart';
import '../Tela loja/scraps/jogo_detalhes.dart';
import '../Tela loja/componentes/trailer_player.dart';

/// Galeria imersiva da Steam com capturas ampli?veis e trailers internos.
class DescobrirDetalhes extends StatefulWidget {
  const DescobrirDetalhes({
    super.key,
    required this.jogo,
    required this.scraper,
    this.sons = true,
  });

  final JogoCatalogo jogo;
  final DetalhesScraper scraper;
  final bool sons;

  @override
  State<DescobrirDetalhes> createState() => _DescobrirDetalhesState();
}

/// Onde o Pad está dentro da ficha, de cima para baixo.
enum _Zona { acao, galeria }

/// Uma miniatura da faixa: captura do jogo ou trailer.
class _Midia {
  const _Midia(
      {required this.miniatura, this.imagem, this.video, this.trailer});
  final TrailerJogo? trailer;
  final Uri miniatura;

  /// Captura para mostrar grande; nulo quando é vídeo.
  final Uri? imagem;

  /// Endereço do trailer; nulo quando é captura.
  final Uri? video;

  bool get ehVideo => video != null;
}

class _DescobrirDetalhesState extends State<DescobrirDetalhes> {
  late Future<JogoDetalhes> _ficha;
  final _abrirFocus = FocusNode(debugLabel: 'abrir na loja');
  final _galeriaFocus = FocusNode(debugLabel: 'galeria Steam');
  final _rolagemDescricao = ScrollController();
  final _rolagemMiniaturas = ScrollController();

  _Zona _zona = _Zona.galeria;
  int _midia = 0;
  GlobalKey<TrailerPlayerState> _playerKey = GlobalKey<TrailerPlayerState>();

  static const _violeta = Color(0xFFB6A8FF);
  static const _larguraDaMiniatura = 132.0;

  @override
  void initState() {
    super.initState();
    _abrirFocus.addListener(() {
      if (_abrirFocus.hasFocus && _zona != _Zona.acao && mounted) {
        setState(() => _zona = _Zona.acao);
      }
    });
    _ficha = widget.scraper.carregar(widget.jogo.pagina);
  }

  @override
  void dispose() {
    _abrirFocus.dispose();
    _galeriaFocus.dispose();
    _rolagemDescricao.dispose();
    _rolagemMiniaturas.dispose();
    widget.scraper.dispose();
    super.dispose();
  }

  void _recarregar() =>
      setState(() => _ficha = widget.scraper.carregar(widget.jogo.pagina));

  void _som(void Function() tocar) {
    if (widget.sons) tocar();
  }

  /// Trailers primeiro, seguidos das capturas do jogo.
  List<_Midia> _midias(JogoDetalhes jogo) => [
        for (final trailer in jogo.trailers)
          _Midia(
              miniatura: trailer.miniatura,
              video: trailer.url,
              trailer: trailer),
        for (final imagem in jogo.imagens)
          _Midia(miniatura: imagem, imagem: imagem),
      ];

  /// A captura grande é a última selecionada; um trailer não troca a imagem.
  Uri? _imagemGrande(List<_Midia> midias) {
    if (midias.isEmpty) return null;
    for (var i = _midia.clamp(0, midias.length - 1); i >= 0; i--) {
      final atual = midias[i].imagem;
      if (atual != null) return atual;
    }
    for (final midia in midias) {
      if (midia.imagem != null) return midia.imagem;
    }
    return null;
  }

  Future<void> _abrirNoNavegador(Uri endereco) async {
    _som(SonsSistema.futuristicOpen);
    try {
      if (await launchUrl(endereco, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {/* Mostra o aviso sem derrubar a ficha. */}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o endereço.')));
  }

  void _irParaMidia(int destino, int total) {
    if (total == 0) return;
    final alvo = destino.clamp(0, total - 1);
    if (alvo == _midia && _zona == _Zona.galeria) return;
    setState(() {
      if (_midia != alvo) _playerKey = GlobalKey<TrailerPlayerState>();
      _midia = alvo;
      _zona = _Zona.galeria;
    });
    _galeriaFocus.requestFocus();
    _som(SonsSistema.futuristicMove);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revelarMiniatura(alvo);
    });
  }

  /// Mantém a miniatura escolhida dentro da faixa visível.
  void _revelarMiniatura(int indice) {
    if (!_rolagemMiniaturas.hasClients) return;
    final posicao = _rolagemMiniaturas.position;
    const passo = _larguraDaMiniatura + 8;
    final inicio = indice * passo;
    final fim = inicio + passo;
    final alvo = inicio < posicao.pixels
        ? inicio
        : fim > posicao.pixels + posicao.viewportDimension
            ? fim - posicao.viewportDimension
            : posicao.pixels;
    _rolagemMiniaturas.animateTo(alvo.clamp(0.0, posicao.maxScrollExtent),
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _irParaZona(_Zona zona) {
    if (_zona == zona) return;
    setState(() => _zona = zona);
    if (zona == _Zona.acao) {
      _abrirFocus.requestFocus();
    } else {
      _galeriaFocus.requestFocus();
    }
    _som(SonsSistema.futuristicMove);
  }

  bool _comando(String comando, JogoDetalhes? ficha) {
    if (ficha == null) return false;
    final midias = _midias(ficha);
    if (_zona == _Zona.galeria &&
        (comando == '2' ||
            comando == 'R3' ||
            comando == 'LB' ||
            comando == 'RB' ||
            comando.startsWith('LT') ||
            comando.startsWith('RT')) &&
        (_playerKey.currentState?.command(comando) ?? false)) {
      return true;
    }
    switch (_zona) {
      case _Zona.acao:
        if (['ESQUERDA', 'CIMA', 'BAIXO'].contains(comando)) {
          _irParaZona(_Zona.galeria);
          return true;
        }
        if (comando == 'DIREITA') return true;
        if (comando == '2') {
          _abrirNoNavegador(ficha.urlLoja ?? widget.jogo.pagina);
          return true;
        }
        return false;
      case _Zona.galeria:
        switch (comando) {
          case 'ESQUERDA':
            _irParaMidia(_midia - 1, midias.length);
            return true;
          case 'DIREITA':
            if (midias.isEmpty || _midia >= midias.length - 1) {
              _irParaZona(_Zona.acao);
            } else {
              _irParaMidia(_midia + 1, midias.length);
            }
            return true;
          case 'CIMA':
          case 'BAIXO':
            _irParaZona(_Zona.acao);
            return true;
          case 'R3':
          case '2':
            _ampliarImagem(midias);
            return true;
        }
        return false;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<JogoDetalhes>(
        future: _ficha,
        builder: (context, snapshot) => LauncherPadScope(
          revealInitialFocus: false,
          onCommand: (comando) => _comando(comando, snapshot.data),
          child: Focus(
            focusNode: _galeriaFocus,
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              final command = {
                LogicalKeyboardKey.enter: '2',
                LogicalKeyboardKey.space: '2',
                LogicalKeyboardKey.f11: 'R3',
              }[event.logicalKey];
              return command != null && _comando(command, snapshot.data)
                  ? KeyEventResult.handled
                  : KeyEventResult.ignored;
            },
            child: Scaffold(
              backgroundColor: const Color(0xFF07060C),
              extendBodyBehindAppBar: true,
              appBar: const LauncherHeader(title: Text('STEAM / DESCOBRIR')),
              body: _corpo(context, snapshot),
            ),
          ),
        ),
      );

  Widget _corpo(BuildContext context, AsyncSnapshot<JogoDetalhes> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator(color: _violeta));
    }
    final erro = snapshot.error;
    if (erro != null || snapshot.data == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ErroCatalogoPainel(
              mensagem: erro is ErroCatalogo
                  ? erro.mensagem
                  : 'Não foi possível carregar a ficha deste jogo.',
              diagnostico: erro is ErroCatalogo
                  ? erro.diagnostico
                  : (erro == null
                      ? null
                      : DiagnosticoCatalogo.de(erro,
                          endereco: widget.jogo.pagina)),
              carregando: false,
              onTentarNovamente: _recarregar,
            ),
          ),
        ),
      );
    }
    return _ficha_(context, snapshot.data!);
  }

  Widget _ficha_(BuildContext context, JogoDetalhes jogo) {
    final midias = _midias(jogo);
    final fundo = _imagemGrande(midias) ?? jogo.capa ?? widget.jogo.imagem;
    return Stack(fit: StackFit.expand, children: [
      if (fundo != null)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [...previous, if (current != null) current],
          ),
          child: CachedNetworkImage(
              key: ValueKey(fundo),
              imageUrl: fundo.toString(),
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.expand()),
        ),
      const DecoratedBox(
          decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xED090D18), Color(0xBA151326), Color(0xF2070910)]),
      )),
      SafeArea(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 70),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1600),
            child: LayoutBuilder(builder: (context, bounds) {
              final wide = bounds.maxWidth >= 1000;
              final short = bounds.maxHeight < 480;
              final gallery = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _imagemGrandeWidget(midias)),
                  if (midias.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                        height: short ? 64 : 90, child: _faixaDeMidias(midias)),
                  ],
                ],
              );
              final info = _painelInformacoes(context, jogo, short: short);
              if (wide) {
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: gallery),
                      const SizedBox(width: 28),
                      SizedBox(width: 320, child: info),
                    ]);
              }
              return Column(children: [
                Expanded(flex: 5, child: gallery),
                const SizedBox(height: 14),
                Expanded(flex: 3, child: info),
              ]);
            }),
          ),
        ),
      )),
    ]);
  }

  Widget _painelInformacoes(BuildContext context, JogoDetalhes jogo,
          {required bool short}) =>
      Container(
        padding: EdgeInsets.all(short ? 16 : 24),
        decoration: BoxDecoration(
          color: const Color(0xB3121725),
          borderRadius: BorderRadius.circular(26),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('EM DESTAQUE NA STEAM',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFFA9EEE4), fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 10),
          Text(jogo.nome,
              textAlign: TextAlign.center,
              maxLines: short ? 1 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: short ? 22 : 30,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          if (!short && jogo.generos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(jogo.generos.take(4).join('  \u00b7  '),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _violeta, height: 1.5, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          Expanded(
              child: jogo.descricao.isEmpty
                  ? const SizedBox.shrink()
                  : _descricao(context, jogo)),
          const SizedBox(height: 14),
          if (jogo.preco.isNotEmpty) ...[
            Text(jogo.preco,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            focusNode: _abrirFocus,
            onPressed: () =>
                _abrirNoNavegador(jogo.urlLoja ?? widget.jogo.pagina),
            style: FilledButton.styleFrom(
                backgroundColor:
                    _zona == _Zona.acao ? _violeta : const Color(0xFF242434),
                foregroundColor: _zona == _Zona.acao
                    ? const Color(0xFF101020)
                    : Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                    color:
                        _zona == _Zona.acao ? Colors.white : Colors.transparent,
                    width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Ver na Steam'),
          ),
          if (!short) ...[
            const SizedBox(height: 14),
            const Text(
                'Esquerda / direita: imagens\nCima / baixo: Ver na Steam\nA: ampliar / pausar  |  B: voltar',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white38, height: 1.7, fontSize: 11)),
          ],
        ]),
      );

  Future<void> _ampliarImagem(List<_Midia> midias) async {
    final imagens = midias.where((midia) => midia.imagem != null).toList();
    if (imagens.isEmpty) return;
    final selecionada = _imagemGrande(midias);
    var indice = imagens.indexWhere((midia) => midia.imagem == selecionada);
    if (indice < 0) indice = 0;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (routeContext) => StatefulBuilder(builder: (context, update) {
        void mover(int delta) => update(() {
              indice = (indice + delta).clamp(0, imagens.length - 1);
            });
        return LauncherPadScope(
          menu: false,
          revealFocus: false,
          onCommand: (command) {
            if (command == 'ESQUERDA') {
              mover(-1);
              return true;
            }
            if (command == 'DIREITA') {
              mover(1);
              return true;
            }
            if (command == 'R3' || command == '2') {
              Navigator.of(routeContext).pop();
              return true;
            }
            return false;
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Focus(
                autofocus: true,
                child: Stack(fit: StackFit.expand, children: [
                  InteractiveViewer(
                      key: ValueKey(indice),
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                          child: CachedNetworkImage(
                              imageUrl: imagens[indice].imagem.toString(),
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white54)))),
                  SafeArea(
                      child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: IconButton.filledTonal(
                                  tooltip: 'Fechar imagem',
                                  onPressed: () =>
                                      Navigator.of(routeContext).pop(),
                                  icon: const Icon(Icons.close))))),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton.filledTonal(
                          onPressed: indice > 0 ? () => mover(-1) : null,
                          icon: const Icon(Icons.chevron_left, size: 32))),
                  Align(
                      alignment: Alignment.centerRight,
                      child: IconButton.filledTonal(
                          onPressed: indice < imagens.length - 1
                              ? () => mover(1)
                              : null,
                          icon: const Icon(Icons.chevron_right, size: 32))),
                  Positioned(
                      bottom: 24,
                      left: 24,
                      child: Text(
                          '${indice + 1} / ${imagens.length}  |  Role para ampliar',
                          style: const TextStyle(color: Colors.white70))),
                ])),
          ),
        );
      }),
    ));
  }

  Widget _imagemGrandeWidget(List<_Midia> midias) {
    final grande = _imagemGrande(midias);
    final atual =
        midias.isEmpty ? null : midias[_midia.clamp(0, midias.length - 1)];
    final media = _BordasSuaves(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: atual?.trailer != null
            ? TrailerPlayer(
                key: _playerKey,
                trailer: atual!.trailer!,
                inline: true,
                fit: BoxFit.cover)
            : grande == null
                ? const ColoredBox(
                    color: Color(0xFF14121E),
                    child: Center(
                        child: Text('Este jogo não tem capturas publicadas.',
                            style: TextStyle(color: Color(0xFF8E88A3)))),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    layoutBuilder: (current, previous) => Stack(
                      fit: StackFit.expand,
                      children: [...previous, if (current != null) current],
                    ),
                    child: CachedNetworkImage(
                      key: ValueKey(grande),
                      imageUrl: grande.toString(),
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Color(0xFF14121E)),
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: Color(0xFF14121E)),
                    ),
                  ),
      ),
    );
    return Stack(fit: StackFit.expand, children: [
      media,
      Positioned(
          top: 14,
          left: 14,
          child: IgnorePointer(
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                color: const Color(0xB3101420),
                borderRadius: BorderRadius.circular(20)),
            child: Text(atual?.ehVideo == true ? 'TRAILER' : 'CAPTURA',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10, letterSpacing: 2)),
          ))),
      if (atual != null)
        Positioned(
            top: 12,
            right: 12,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${_midia + 1} / ${midias.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    shadows: [
                      Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1)),
                    ],
                  )),
              const SizedBox(width: 8),
              IconButton(
                tooltip: atual.ehVideo
                    ? 'Ampliar trailer (R3)'
                    : 'Ampliar imagem (A)',
                onPressed: () {
                  if (atual.ehVideo) {
                    _playerKey.currentState?.command('R3');
                  } else {
                    _ampliarImagem(midias);
                  }
                },
                icon: const Icon(Icons.fullscreen_rounded,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1)),
                    ]),
              ),
            ])),
    ]);
  }

  Widget _faixaDeMidias(List<_Midia> midias) => ListView.separated(
        controller: _rolagemMiniaturas,
        scrollDirection: Axis.horizontal,
        itemCount: midias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final midia = midias[i];
          final apontada = i == _midia && _zona == _Zona.galeria;
          return GestureDetector(
            onTap: () => midia.ehVideo && i == _midia
                ? _playerKey.currentState?.togglePlayback()
                : _irParaMidia(i, midias.length),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: _larguraDaMiniatura,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: apontada
                    ? [
                        BoxShadow(
                          color: _violeta.withValues(alpha: .28),
                          blurRadius: 10,
                        )
                      ]
                    : null,
                border: Border.all(
                    color: apontada ? _violeta : Colors.transparent,
                    width: apontada ? 2 : 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(fit: StackFit.expand, children: [
                  CachedNetworkImage(
                      imageUrl: midia.miniatura.toString(),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: Color(0xFF14121E))),
                  if (midia.ehVideo)
                    const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0x66000000)),
                      child: Center(
                          child: Icon(Icons.play_circle_fill_rounded,
                              color: Colors.white, size: 30)),
                    ),
                ]),
              ),
            ),
          );
        },
      );

  Widget _descricao(BuildContext context, JogoDetalhes jogo) => Scrollbar(
        controller: _rolagemDescricao,
        child: SingleChildScrollView(
          controller: _rolagemDescricao,
          child: Text(jogo.descricao,
              textAlign: TextAlign.justify,
              style: const TextStyle(
                  height: 1.65, fontSize: 13, color: Colors.white70)),
        ),
      );
}

/// Transparencia progressiva nos 20 pixels junto de cada borda.
class _BordasSuaves extends StatelessWidget {
  const _BordasSuaves({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            final fade = (20 / rect.width).clamp(0.0, .5);
            return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent
                ],
                stops: [
                  0,
                  fade,
                  1 - fade,
                  1
                ]).createShader(rect);
          },
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) {
              final fade = (20 / rect.height).clamp(0.0, .5);
              return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent
                  ],
                  stops: [
                    0,
                    fade,
                    1 - fade,
                    1
                  ]).createShader(rect);
            },
            child: child,
          ),
        ),
      );
}
