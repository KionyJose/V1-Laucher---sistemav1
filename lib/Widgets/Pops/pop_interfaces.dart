import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:v1_game/Controllers/SonsSistema.dart';
import 'package:v1_game/Controllers/slim_mode_config_controller.dart';
import 'package:v1_game/Global.dart';

import '../../Interface/launcher_pad_scope.dart';
import '../../Interface/launcher_style_preview.dart';

/// Um ajuste de uma tela, do jeito que o Pad consegue mexer nele.
sealed class AjusteDeTela {
  const AjusteDeTela(this.nome);
  final String nome;
}

/// Liga/desliga, alternado com A.
class AjusteLiga extends AjusteDeTela {
  const AjusteLiga(super.nome, {required this.ler, required this.gravar});
  final bool Function() ler;
  final void Function(bool) gravar;
}

/// Valor de 0 a 1, movido com LB/RB — o direcional já troca de coluna.
class AjusteVolume extends AjusteDeTela {
  const AjusteVolume(super.nome, {required this.ler, required this.gravar});
  final double Function() ler;
  final void Function(double) gravar;

  static const passo = .1;
}

/// Uma tela do launcher e os ajustes que pertencem só a ela.
class TelaDoLauncher {
  const TelaDoLauncher({
    required this.id,
    required this.nome,
    required this.icone,
    required this.resumo,
    this.ajustes = const [],
  });

  /// `viewType` da tela, ou [idSlim] para o modo de janela.
  final String id;
  final String nome;
  final IconData icone;

  /// Uma linha dizendo o que a tela é.
  final String resumo;

  final List<AjusteDeTela> ajustes;

  static const idSlim = 'slim';
  bool get ehSlim => id == idSlim;
}

/// Todas as telas, com o que cada uma tem de ajuste próprio.
///
/// Só entram aqui os ajustes que pertencem **àquela** tela. Volume geral,
/// FPS e sequências do controle valem para o launcher inteiro e continuam em
/// Configurações — repeti-los aqui faria parecer que mudam por tela.
List<TelaDoLauncher> telasDoLauncher() => [
      TelaDoLauncher(
        id: 'list',
        nome: 'Principal',
        icone: Icons.view_agenda_rounded,
        resumo: 'Lista de capas com vídeo de fundo.',
        ajustes: [
          AjusteLiga('Vídeos na tela',
              ler: () => configSistema.videosTelaPrincipal,
              gravar: (v) => configSistema.videosTelaPrincipal = v),
          AjusteLiga('Notícias no card',
              ler: () => configSistema.noticias,
              gravar: (v) => configSistema.noticias = v),
        ],
      ),
      TelaDoLauncher(
        id: 'moderno',
        nome: 'Moderno',
        icone: Icons.auto_awesome_mosaic_rounded,
        resumo: 'Capas grandes com faixa de notícias.',
        ajustes: [
          AjusteLiga('Notícias no card',
              ler: () => configSistema.noticias,
              gravar: (v) => configSistema.noticias = v),
        ],
      ),
      const TelaDoLauncher(
        id: 'retro',
        nome: 'Retro',
        icone: Icons.videogame_asset_rounded,
        resumo: 'Visual de console antigo.',
      ),
      const TelaDoLauncher(
        id: 'grid',
        nome: 'Grade',
        icone: Icons.grid_view_rounded,
        resumo: 'Todos os jogos de uma vez.',
      ),
      const TelaDoLauncher(
        id: 'transversal',
        nome: 'Transversal',
        icone: Icons.view_carousel_rounded,
        resumo: 'Painéis inclinados em movimento.',
      ),
      TelaDoLauncher(
        id: 'futurista',
        nome: 'Futurista',
        icone: Icons.blur_on_rounded,
        resumo: 'Vidro, água e som ambiente.',
        ajustes: [
          AjusteVolume('Música ambiente',
              ler: () => configSistema.volumeMusicaFuturista,
              gravar: (v) => configSistema.volumeMusicaFuturista = v),
          AjusteVolume('Som ao abrir',
              ler: () => configSistema.volumeSomInicioFuturista,
              gravar: (v) => configSistema.volumeSomInicioFuturista = v),
        ],
      ),
      const TelaDoLauncher(
        id: 'gta_vi',
        nome: 'GTA VI · Vice City',
        icone: Icons.local_florist_rounded,
        resumo: 'Vice City em camadas, paralaxe, vídeos e notícias.',
      ),
      const TelaDoLauncher(
        id: TelaDoLauncher.idSlim,
        nome: 'Slim',
        icone: Icons.width_normal_rounded,
        resumo: 'Faixa no pé da tela, por cima do Windows.',
      ),
    ];

/// Seletor de telas com lista e painel de ajustes independentes.
///
/// Devolve `'salvar'` quando algo mudou — quem chama aplica a interface —, ou
/// vazio ao sair sem mexer.
class PopInterfaces {
  static const colunas = 3;

  /// [gravar] e [definirSlim] existem para o teste não escrever por cima da
  /// configuração real do usuário: `configSistema` é global e `save()` vai
  /// direto ao disco.
  static Future<String> abrir(
    BuildContext context, {
    List<String> capas = const [],
    Future<bool> Function()? gravar,
    Future<void> Function(bool)? definirSlim,
  }) async =>
      await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PopInterfaces(
            gravar: gravar, definirSlim: definirSlim, capas: capas),
      ) ??
      '';
}

class _PopInterfaces extends StatefulWidget {
  const _PopInterfaces({this.gravar, this.definirSlim, this.capas = const []});
  final List<String> capas;
  final Future<bool> Function()? gravar;
  final Future<void> Function(bool)? definirSlim;

  @override
  State<_PopInterfaces> createState() => _PopInterfacesState();
}

class _PopInterfacesState extends State<_PopInterfaces> {
  late final List<TelaDoLauncher> _telas = telasDoLauncher();
  final _slim = const SlimModeConfigController();
  final _listaScroll = ScrollController();
  final _ajustesScroll = ScrollController();
  final _keyboardFocus = FocusNode(debugLabel: 'navegacao de telas');
  late final List<GlobalKey> _telaKeys;
  late List<GlobalKey> _ajusteKeys;
  final _aplicarKey = GlobalKey();
  int _tela = 0;
  int _ajuste = 0;
  bool _editando = false;
  bool _mudou = false;
  bool _fechando = false;
  int _revisaoScroll = 0;
  static const _violeta = Color(0xFFB6A8FF);

  TelaDoLauncher get _selecionada => _telas[_tela];
  bool get _noAplicar => _ajuste >= _selecionada.ajustes.length;

  @override
  void initState() {
    super.initState();
    final atual = _telas.indexWhere(_ehAtual);
    _tela = atual < 0 ? 0 : atual;
    _telaKeys = List.generate(_telas.length, (_) => GlobalKey());
    _criarChavesDosAjustes();
    _revelarSelecao();
  }

  void _criarChavesDosAjustes() {
    _ajusteKeys =
        List.generate(_selecionada.ajustes.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _listaScroll.dispose();
    _ajustesScroll.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  bool _ehAtual(TelaDoLauncher tela) => tela.ehSlim
      ? SlimModeConfigController.active.value
      : !SlimModeConfigController.active.value &&
          configSistema.viewType == tela.id;

  Future<void> _escreverSlim(bool ativo) =>
      widget.definirSlim?.call(ativo) ?? _slim.writeActive(ativo);

  void _revelarSelecao() {
    final revisao = ++_revisaoScroll;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revisao != _revisaoScroll) return;
      // A acao de aplicar permanece visivel fora da area rolavel.
      if (_editando && _noAplicar) return;
      final key = !_editando
          ? _telaKeys[_tela]
          : _noAplicar
              ? _aplicarKey
              : _ajusteKeys[_ajuste];
      final target = key.currentContext;
      if (target == null) return;
      final item = target.findRenderObject();
      final viewport = Scrollable.maybeOf(target)?.context.findRenderObject();
      if (item is RenderBox && viewport is RenderBox) {
        final top = item.localToGlobal(Offset.zero, ancestor: viewport).dy;
        if (top >= 8 && top + item.size.height <= viewport.size.height - 8) {
          return;
        }
      }
      Scrollable.ensureVisible(target,
          alignment: .25,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic);
    });
  }

  void _selecionarTela(int index) {
    if (_fechando) return;
    final destino = index.clamp(0, _telas.length - 1);
    if (destino == _tela && !_editando) return;
    final mudouTela = destino != _tela;
    setState(() {
      _tela = destino;
      _ajuste = 0;
      _editando = false;
      if (mudouTela) _criarChavesDosAjustes();
    });
    if (mudouTela && _ajustesScroll.hasClients) _ajustesScroll.jumpTo(0);
    _keyboardFocus.requestFocus();
    SonsSistema.direction();
    _revelarSelecao();
  }

  void _editar(int index) {
    if (_fechando) return;
    final destino = index.clamp(0, _selecionada.ajustes.length);
    if (_editando && _ajuste == destino) return;
    setState(() {
      _editando = true;
      _ajuste = destino;
    });
    _keyboardFocus.requestFocus();
    SonsSistema.direction();
    _revelarSelecao();
  }

  void _voltarParaLista() {
    setState(() => _editando = false);
    _keyboardFocus.requestFocus();
    SonsSistema.direction();
    _revelarSelecao();
  }

  bool _comando(String comando) {
    if (_fechando) return true;
    if (!_editando) {
      switch (comando) {
        case 'CIMA':
          _selecionarTela(_tela - 1);
        case 'BAIXO':
          _selecionarTela(_tela + 1);
        case 'DIREITA':
        case '2':
          _editar(0);
        case 'LB':
          _selecionarTela(_tela - 1);
        case 'RB':
          _selecionarTela(_tela + 1);
        case '3':
        case 'START':
          _fechar();
      }
      return true;
    }
    switch (comando) {
      case 'CIMA':
        _editar(_ajuste - 1);
      case 'BAIXO':
        _editar(_ajuste + 1);
      case 'ESQUERDA':
        _voltarParaLista();
      case 'LB':
        _mexerNoVolume(-AjusteVolume.passo);
      case 'RB':
        _mexerNoVolume(AjusteVolume.passo);
      case '2':
        if (_noAplicar) {
          _aplicar(_selecionada);
        } else {
          _acionarAjuste(_selecionada.ajustes[_ajuste]);
        }
      case '3':
        _voltarParaLista();
      case 'START':
        _fechar();
    }
    return true;
  }

  void _acionarAjuste(AjusteDeTela ajuste) {
    if (_fechando || ajuste is! AjusteLiga) return;
    SonsSistema.click();
    setState(() {
      ajuste.gravar(!ajuste.ler());
      _mudou = true;
    });
  }

  void _mexerNoVolume(double delta) {
    if (!_editando || _noAplicar) return;
    final ajuste = _selecionada.ajustes[_ajuste];
    if (ajuste is! AjusteVolume) return;
    final novo = (ajuste.ler() + delta).clamp(0.0, 1.0);
    if (novo == ajuste.ler()) return;
    SonsSistema.direction();
    _gravarVolume(ajuste, novo);
  }

  void _gravarVolume(AjusteVolume ajuste, double valor) {
    if (_fechando) return;
    setState(() {
      ajuste.gravar(valor.clamp(0.0, 1.0));
      _mudou = true;
    });
  }

  Future<void> _aplicar(TelaDoLauncher tela) async {
    if (_fechando) return;
    // Trava comandos durante a escrita para impedir duas aplicacoes simultaneas.
    setState(() => _fechando = true);
    SonsSistema.click();
    try {
      if (tela.ehSlim) {
        await _escreverSlim(true);
      } else {
        configSistema.viewType = tela.id;
        if (SlimModeConfigController.active.value) await _escreverSlim(false);
      }
      _mudou = true;
      await _salvarEFechar();
    } catch (_) {
      if (mounted) {
        setState(() => _fechando = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'N\u00e3o foi poss\u00edvel salvar a tela. Tente novamente.')));
      }
    }
  }

  Future<void> _fechar() async {
    if (_fechando || !mounted) return;
    setState(() => _fechando = true);
    try {
      await _salvarEFechar();
    } catch (_) {
      if (mounted) {
        setState(() => _fechando = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'N\u00e3o foi poss\u00edvel salvar os ajustes. Tente novamente.')));
      }
    }
  }

  Future<void> _salvarEFechar() async {
    if (_mudou) {
      final salvo = await (widget.gravar?.call() ?? configSistema.save());
      if (!salvo) throw StateError('Falha ao salvar ajustes');
    }
    if (mounted) Navigator.of(context).pop(_mudou ? 'salvar' : '');
  }

  String get _dica {
    if (!_editando) {
      return 'Cima / baixo: escolher tela   |   A / direita: editar   |   B: fechar';
    }
    if (_noAplicar) {
      return 'A: aplicar esta tela   |   Esquerda / B: lista de telas';
    }
    final ajuste = _selecionada.ajustes[_ajuste];
    return ajuste is AjusteVolume
        ? 'LB / RB: diminuir / aumentar   |   Cima / baixo: ajustes   |   B: lista'
        : 'A: ligar / desligar   |   Cima / baixo: ajustes   |   B: lista';
  }

  @override
  Widget build(BuildContext context) {
    final tamanho = MediaQuery.sizeOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _comando('3');
      },
      child: LauncherPadScope(
        menu: false,
        revealFocus: false,
        onCommand: _comando,
        child: Focus(
          focusNode: _keyboardFocus,
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space) {
              _comando('2');
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.pageUp) {
              _comando('LB');
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.pageDown) {
              _comando('RB');
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: ExcludeFocus(
              child: Dialog(
            backgroundColor: const Color(0xFF0D101A),
            elevation: 0,
            insetPadding: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: (tamanho.width - 32).clamp(0.0, 1440.0),
              height: (tamanho.height - 32).clamp(0.0, 920.0),
              child: Column(children: [
                _cabecalho(),
                const Divider(height: 1, color: Color(0x18FFFFFF)),
                Expanded(child: LayoutBuilder(builder: (context, bounds) {
                  final compact = bounds.maxWidth < 760;
                  final larguraLista = compact
                      ? (bounds.maxWidth * .34).clamp(120.0, 240.0)
                      : 310.0;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: larguraLista,
                        child: ColoredBox(
                          color: const Color(0xFF111522),
                          child: Scrollbar(
                            controller: _listaScroll,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _listaScroll,
                              padding: const EdgeInsets.all(12),
                              child: Column(children: [
                                for (var i = 0; i < _telas.length; i++)
                                  _itemTela(i, compact),
                              ]),
                            ),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1, color: Color(0x18FFFFFF)),
                      Expanded(child: _editor(compact)),
                    ],
                  );
                })),
                const Divider(height: 1, color: Color(0x18FFFFFF)),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(children: [
                    Icon(
                        _editando ? Icons.tune_rounded : Icons.gamepad_outlined,
                        color: _violeta,
                        size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_fechando ? 'Salvando...' : _dica,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12))),
                    if (_mudou)
                      const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Text('Ajustes alterados',
                              style: TextStyle(
                                  color: Color(0xFFA9EEE4), fontSize: 11))),
                  ]),
                ),
              ]),
            ),
          )),
        ),
      ),
    );
  }

  Widget _cabecalho() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 16, 18),
        child: Row(children: [
          const Icon(Icons.dashboard_customize_rounded,
              color: _violeta, size: 28),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Telas',
                    style:
                        TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
                Text(
                    '${_telas.length} estilos dispon\u00edveis. Escolha, ajuste e aplique.',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ])),
          IconButton(
              tooltip: 'Salvar e fechar',
              onPressed: _fechando ? null : _fechar,
              icon: const Icon(Icons.close_rounded)),
        ]),
      );

  Widget _itemTela(int index, bool compact) {
    final tela = _telas[index];
    final selecionada = index == _tela;
    final foco = selecionada && !_editando;
    return Padding(
      key: _telaKeys[index],
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _selecionarTela(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: selecionada ? const Color(0xFF29243D) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: foco ? _violeta : Colors.transparent, width: 2),
          ),
          child: Row(children: [
            if (!compact) ...[
              Icon(tela.icone,
                  color: selecionada ? _violeta : Colors.white38, size: 24),
              const SizedBox(width: 14),
            ],
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(tela.nome,
                      style: TextStyle(
                          fontSize: compact ? 13 : 16,
                          fontWeight: FontWeight.w600,
                          color: selecionada ? Colors.white : Colors.white60)),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text('${tela.ajustes.length} ajustes',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ])),
            if (_ehAtual(tela))
              Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.check_circle_rounded,
                      size: compact ? 15 : 18, color: const Color(0xFFA9EEE4))),
          ]),
        ),
      ),
    );
  }

  String _detalhesDaTela(TelaDoLauncher tela) => switch (tela.id) {
        'list' => 'Navegue pela lista de capas com o jogo em destaque. '
            'Ative os v\u00eddeos de fundo e as not\u00edcias nos ajustes abaixo.',
        'moderno' => 'Capas grandes e informa\u00e7\u00f5es do jogo em uma '
            'composi\u00e7\u00e3o ampla. A faixa de not\u00edcias pode ser personalizada.',
        'retro' => 'Uma apresenta\u00e7\u00e3o inspirada em consoles antigos, '
            'com navega\u00e7\u00e3o entre as capas pelo controle.',
        'grid' => 'Veja v\u00e1rios jogos ao mesmo tempo em uma grade. '
            'Percorra linhas e colunas para encontrar o que quer jogar.',
        'transversal' =>
          'Pain\u00e9is inclinados e transi\u00e7\u00f5es laterais '
              'destacam a arte dos jogos durante a navega\u00e7\u00e3o.',
        'futurista' => 'Vidro, reflexos e paisagem com \u00e1gua. '
            'Personalize os volumes da m\u00fasica ambiente e do som de abertura.',
        'slim' => 'Uma faixa compacta no rodap\u00e9 do Windows para acessar '
            'a biblioteca mantendo a \u00e1rea de trabalho ao fundo.',
        _ => tela.resumo,
      };

  Widget _editor(bool compact) {
    final tela = _selecionada;
    final aplicarSelecionado = _editando && _noAplicar;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
          child: Scrollbar(
        controller: _ajustesScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _ajustesScroll,
          padding: EdgeInsets.all(compact ? 16 : 28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(tela.icone, color: _violeta, size: compact ? 28 : 36),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(tela.nome,
                      style: TextStyle(
                          fontSize: compact ? 24 : 32,
                          fontWeight: FontWeight.w700))),
              if (!compact && _ehAtual(tela))
                const _Etiqueta(texto: 'Em uso', cor: Color(0xFFA9EEE4)),
            ]),
            const SizedBox(height: 16),
            Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 840),
                    child: LauncherStylePreview(
                        style: tela.id, capas: widget.capas))),
            const SizedBox(height: 8),
            const Text('Pr\u00e9via ilustrativa  /  16:9',
                style: TextStyle(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 18),
            Text(tela.resumo,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_detalhesDaTela(tela),
                style: const TextStyle(
                    color: Colors.white60, fontSize: 13, height: 1.6)),
            const SizedBox(height: 24),
            const Text('PERSONALIZAR',
                style: TextStyle(
                    color: Colors.white38, fontSize: 11, letterSpacing: 2)),
            const SizedBox(height: 14),
            if (tela.ajustes.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Pronta para usar, sem ajustes exclusivos.',
                      style: TextStyle(color: Colors.white54, height: 1.6))),
            for (var i = 0; i < tela.ajustes.length; i++)
              _linhaDeAjuste(i, compact),
          ]),
        ),
      )),
      Container(
        key: _aplicarKey,
        padding:
            EdgeInsets.fromLTRB(compact ? 16 : 28, 14, compact ? 16 : 28, 14),
        decoration: const BoxDecoration(
            color: Color(0xFF121623),
            border: Border(top: BorderSide(color: Color(0x18FFFFFF)))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color:
                        aplicarSelecionado ? Colors.white : Colors.transparent,
                    width: 2)),
            child: FilledButton.icon(
              onPressed: _fechando ? null : () => _aplicar(tela),
              style: FilledButton.styleFrom(
                  backgroundColor:
                      aplicarSelecionado ? _violeta : const Color(0xFF423658),
                  foregroundColor:
                      aplicarSelecionado ? Colors.black : Colors.white,
                  padding: EdgeInsets.symmetric(vertical: compact ? 14 : 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13))),
              icon: _fechando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(_fechando ? 'Salvando...' : 'Usar este estilo'),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text('Aplicar ${tela.nome} e salvar os ajustes',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ]),
      ),
    ]);
  }

  Widget _linhaDeAjuste(int index, bool compact) {
    final ajuste = _selecionada.ajustes[index];
    final apontada = _editando && _ajuste == index;
    return Padding(
      key: _ajusteKeys[index],
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _editar(index);
          if (ajuste is AjusteLiga) _acionarAjuste(ajuste);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: EdgeInsets.all(compact ? 12 : 20),
          decoration: BoxDecoration(
              color:
                  apontada ? const Color(0xFF262238) : const Color(0xFF151925),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: apontada ? _violeta : Colors.transparent, width: 2)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Text(ajuste.nome,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600))),
              const SizedBox(width: 12),
              if (ajuste is AjusteLiga)
                Switch(
                    value: ajuste.ler(),
                    activeTrackColor: _violeta,
                    onChanged: _fechando
                        ? null
                        : (_) {
                            _editar(index);
                            _acionarAjuste(ajuste);
                          }),
              if (ajuste is AjusteVolume)
                Text('${(ajuste.ler() * 100).round()}%',
                    style: const TextStyle(
                        color: _violeta,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
            ]),
            if (ajuste is AjusteVolume) ...[
              const SizedBox(height: 10),
              Slider(
                  value: ajuste.ler().clamp(0.0, 1.0),
                  divisions: 10,
                  activeColor: _violeta,
                  label: '${(ajuste.ler() * 100).round()}%',
                  onChangeStart: (_) => _editar(index),
                  onChanged: _fechando
                      ? null
                      : (valor) => _gravarVolume(ajuste, valor)),
              const Text('LB diminui   /   RB aumenta',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.cor});
  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: cor.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cor)),
        child: Text(texto,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: cor)),
      );
}
