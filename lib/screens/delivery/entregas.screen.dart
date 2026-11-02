import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/entrega.dart';
import '../../models/oferta.dart';
import '../../services/entregador_service.dart';
import 'entrega_screen.dart';

String _moeda(double valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';


class EntregasScreen extends StatefulWidget {
  const EntregasScreen({super.key});

  @override
  State<EntregasScreen> createState() => _EntregasScreenState();
}

class _EntregasScreenState extends State<EntregasScreen> {
  static const _intervaloBusca = Duration(seconds: 3);
  static const _msgPrazo = 'O prazo acabou e a oferta passou para outro entregador.';

  bool _carregando = true;
  String? _erroInicial;

  bool _online = false;
  bool _alterandoChave = false;

  OfertaEntrega? _oferta;

  
  Entrega? _entregaAtiva;
  DateTime? _prazoFinal;
  int _segundosRestantes = 0;

  
  String? _aviso;
  bool _semConexao = false;

  bool _respondendo = false;
  bool _buscando = false;

  Timer? _buscaTimer;
  Timer? _relogioTimer;

  @override
  void initState() {
    super.initState();
    _carregarSituacao();
  }

  @override
  void dispose() {
    _buscaTimer?.cancel();
    _relogioTimer?.cancel();
    super.dispose();
  }

  Future<void> _carregarSituacao() async {
    setState(() {
      _carregando = true;
      _erroInicial = null;
    });

    try {
      final online = await EntregadorService.buscarDisponibilidade();
      final ativas = await EntregadorService.listarAtivas();
      if (!mounted) return;
      setState(() {
        _online = online;
        _entregaAtiva = ativas.isNotEmpty ? ativas.first : null;
        _carregando = false;
      });
      if (online && _entregaAtiva == null) _comecarABuscar();
    } on EntregadorException catch (e) {
      if (!mounted) return;
      setState(() {
        _erroInicial = e.mensagem;
        _carregando = false;
      });
    }
  }

  void _comecarABuscar() {
    _buscaTimer?.cancel();
    _buscaTimer = Timer.periodic(_intervaloBusca, (_) => _buscarOferta());
    _buscarOferta();
  }

  void _pararTudo() {
    _buscaTimer?.cancel();
    _relogioTimer?.cancel();
  }

  Future<void> _buscarOferta() async {
    if (!_online || _buscando || _respondendo) return;
    _buscando = true;

    try {
      final resposta = await EntregadorService.buscarOferta(atualId: _oferta?.id);
      
      if (!mounted || !_online || _respondendo) return;

      if (_semConexao) setState(() => _semConexao = false);

      final nova = resposta.oferta;
      if (nova != null) {
        if (_oferta?.id != nova.id) _mostrarOferta(nova);
      } else if (_oferta != null) {
        _encerrarOferta(resposta.mensagemEncerrada ?? 'A oferta não está mais disponível.');
      }
    } on EntregadorException {
      if (mounted && !_semConexao) setState(() => _semConexao = true);
    } finally {
      _buscando = false;
    }
  }

  void _mostrarOferta(OfertaEntrega oferta) {
    _prazoFinal = DateTime.now().add(Duration(seconds: oferta.segundosRestantes));
    setState(() {
      _oferta = oferta;
      _segundosRestantes = oferta.segundosRestantes;
      _aviso = null;
    });
    _relogioTimer?.cancel();
    _relogioTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
  }

  void _tic() {
    final prazoFinal = _prazoFinal;
    if (!mounted || _oferta == null || prazoFinal == null) return;

    final restante = (prazoFinal.difference(DateTime.now()).inMilliseconds / 1000).ceil();

    if (restante <= 0) {
      if (_respondendo) {
       
        setState(() => _segundosRestantes = 0);
      } else {
        _encerrarOferta(_msgPrazo);
      }
      return;
    }

    setState(() => _segundosRestantes = restante);
  }

  void _encerrarOferta(String mensagem) {
    _relogioTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _oferta = null;
      _prazoFinal = null;
      _aviso = mensagem;
    });
  }

  Future<void> _alternar(bool novo) async {
    if (_alterandoChave) return;
    setState(() => _alterandoChave = true);

    try {
      final online = await EntregadorService.definirDisponibilidade(novo);
      if (!mounted) return;
      setState(() {
        _online = online;
        _alterandoChave = false;
        if (!online) {
          _oferta = null;
          _prazoFinal = null;
          _aviso = null;
          _semConexao = false;
        }
      });
      if (online) {
        _comecarABuscar();
      } else {
        _pararTudo();
      }
    } on EntregadorException catch (e) {
      if (!mounted) return;
      
      setState(() => _alterandoChave = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _aceitar() async {
    final oferta = _oferta;
    if (oferta == null || _respondendo) return;
    setState(() => _respondendo = true);

    try {
      final entrega = await EntregadorService.aceitar(oferta.id);
      if (!mounted) return;
      _pararTudo();
      setState(() {
        _respondendo = false;
        _oferta = null;
        _prazoFinal = null;
        _aviso = null;
      });
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EntregaScreen(entrega: entrega)),
      );
      if (mounted) _carregarSituacao();
    } on EntregadorException catch (e) {
      if (!mounted) return;
      setState(() => _respondendo = false);
      if (e.ofertaIndisponivel) {
        
        _encerrarOferta(e.mensagem);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }

  Future<void> _recusar() async {
    final oferta = _oferta;
    if (oferta == null || _respondendo) return;
    setState(() => _respondendo = true);

    try {
      await EntregadorService.recusar(oferta.id);
      if (!mounted) return;
      _relogioTimer?.cancel();
      setState(() {
        _respondendo = false;
        _oferta = null;
        _prazoFinal = null;
        _aviso = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oferta recusada.')),
      );
    } on EntregadorException catch (e) {
      if (!mounted) return;
      setState(() => _respondendo = false);
      if (e.ofertaIndisponivel) {
        _encerrarOferta(e.mensagem);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erroInicial != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'Não foi possível carregar',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _erroInicial!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _carregarSituacao,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _cartaoChave(),
        const SizedBox(height: 16),
        if (_semConexao)
          _banner(
            icone: Icons.wifi_off,
            cor: Colors.amber,
            texto: 'Sem conexão. Tentando buscar ofertas de novo...',
          ),
        if (_aviso != null)
          _banner(
            icone: Icons.info_outline,
            cor: Colors.blueGrey,
            texto: _aviso!,
            aoFechar: () => setState(() => _aviso = null),
          ),
        if (_entregaAtiva != null)
          _cartaoEntregaAtiva(_entregaAtiva!)
        else if (!_online)
          _estadoVazio(
            Icons.bedtime_outlined,
            'Você está offline',
            'Fique online para receber ofertas de entrega.',
          )
        else if (_oferta == null)
          _estadoVazio(
            Icons.hourglass_empty,
            'Aguardando ofertas',
            'Assim que aparecer uma entrega perto de você, ela chega aqui.',
          )
        else
          _cartaoOferta(_oferta!),
      ],
    );
  }

  Future<void> _continuarEntrega(Entrega entrega) async {
    _pararTudo();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EntregaScreen(entrega: entrega)),
    );
    if (mounted) _carregarSituacao();
  }

  Widget _cartaoEntregaAtiva(Entrega entrega) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entrega em andamento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(entrega.status.rotulo, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            _linhaInfo(Icons.storefront_outlined, 'Origem', entrega.lojaNome),
            _linhaInfo(Icons.location_on_outlined, 'Destino', entrega.destino),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _continuarEntrega(entrega),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Continuar entrega'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Novas ofertas chegam depois que você concluir esta entrega.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartaoChave() {
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        value: _online,
        onChanged: _alterandoChave ? null : _alternar,
        title: Text(
          _online ? 'Você está online' : 'Você está offline',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _online
              ? 'Você pode receber ofertas de entrega.'
              : 'Ligue a chave para começar a receber ofertas.',
        ),
        secondary: _alterandoChave
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.circle,
                color: _online ? Colors.green : Colors.grey,
              ),
      ),
    );
  }

  Widget _banner({
    required IconData icone,
    required MaterialColor cor,
    required String texto,
    VoidCallback? aoFechar,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: cor.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.shade200),
      ),
      child: Row(
        children: [
          Icon(icone, color: cor.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: TextStyle(color: cor.shade900, fontSize: 13)),
          ),
          if (aoFechar != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: aoFechar,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _estadoVazio(IconData icone, String titulo, String descricao) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Icon(icone, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            descricao,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _tempo(int segundos) {
    final m = (segundos ~/ 60).toString().padLeft(2, '0');
    final s = (segundos % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _linhaInfo(IconData icone, String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 22, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rotulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoOferta(OfertaEntrega oferta) {
    final urgente = _segundosRestantes <= 10;
    final corPrazo = urgente ? Colors.red : Theme.of(context).colorScheme.primary;
    final progresso = oferta.prazoSegundos > 0
        ? (_segundosRestantes / oferta.prazoSegundos).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nova oferta de entrega',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _linhaInfo(Icons.storefront_outlined, 'Origem', oferta.origem),
            _linhaInfo(Icons.location_on_outlined, 'Destino', oferta.destino),
            Row(
              children: [
                Expanded(
                  child: _linhaInfo(
                    Icons.straighten,
                    'Distância',
                    '${oferta.distanciaKm.toStringAsFixed(1).replaceAll('.', ',')} km',
                  ),
                ),
                Expanded(
                  child: _linhaInfo(Icons.payments_outlined, 'Valor', _moeda(oferta.valor)),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.timer_outlined, color: corPrazo),
                const SizedBox(width: 8),
                const Text('Responda em'),
                const Spacer(),
                Text(
                  _tempo(_segundosRestantes),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: corPrazo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progresso,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: corPrazo,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _respondendo ? null : _recusar,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Recusar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _respondendo ? null : _aceitar,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _respondendo
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Aceitar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
