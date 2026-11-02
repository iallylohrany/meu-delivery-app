import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/pedido.dart';
import '../../services/pedido_service.dart';
import '../../widgets/estrelas.dart';
import 'avaliacao_screen.dart';
import 'repetir_pedido.dart';

String _moeda(double valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';


class PedidoAcompanhamentoScreen extends StatefulWidget {
  final String pedidoId;

 
  final Pedido? pedidoInicial;

  const PedidoAcompanhamentoScreen({
    super.key,
    required this.pedidoId,
    this.pedidoInicial,
  });

  @override
  State<PedidoAcompanhamentoScreen> createState() =>
      _PedidoAcompanhamentoScreenState();
}

class _PedidoAcompanhamentoScreenState extends State<PedidoAcompanhamentoScreen> {
  static const _intervalo = Duration(seconds: 5);

  Pedido? _pedido;
  bool _carregandoInicial = false;
  String? _erroInicial;

  
  String? _aviso;

  bool _buscando = false;
  bool _cancelando = false;
  bool _avaliacaoAberta = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pedido = widget.pedidoInicial;
    _carregandoInicial = _pedido == null;

    _atualizar();
    if (!(_pedido?.status.ehFinal ?? false)) {
      _timer = Timer.periodic(_intervalo, (_) => _atualizar());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _atualizar() async {
    if (_buscando || _cancelando) return;
    _buscando = true;

    try {
      final anterior = _pedido?.status;
      final pedido = await PedidoService.buscar(widget.pedidoId);
      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        _aviso = null;
        _erroInicial = null;
        _carregandoInicial = false;
      });
      if (pedido.status.ehFinal) _timer?.cancel();

      
      if (anterior != null &&
          anterior != StatusPedido.entregue &&
          pedido.status == StatusPedido.entregue &&
          pedido.avaliacao == null) {
        _abrirAvaliacao(pedido);
      }
    } on PedidoException catch (e) {
      if (!mounted) return;
      setState(() {
        _carregandoInicial = false;
        if (_pedido == null) {
          _erroInicial = e.mensagem;
        } else {
          
          _aviso = e.mensagem;
        }
      });
    } finally {
      _buscando = false;
    }
  }

  Future<void> _abrirAvaliacao(Pedido pedido) async {
    if (_avaliacaoAberta || !mounted) return;
    _avaliacaoAberta = true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AvaliacaoScreen(pedido: pedido)),
    );
    _avaliacaoAberta = false;
    
    if (mounted) _atualizar();
  }

  Future<void> _tentarDeNovo() async {
    setState(() {
      _carregandoInicial = true;
      _erroInicial = null;
    });
    await _atualizar();
  }

  Future<void> _cancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido?'),
        content: const Text('A loja ainda não começou o preparo. Deseja cancelar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _cancelando = true);

    try {
      final pedido = await PedidoService.cancelar(widget.pedidoId);
      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        _cancelando = false;
        _aviso = null;
      });
      _timer?.cancel();
    } on PedidoException catch (e) {
      if (!mounted) return;
      setState(() => _cancelando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
      
      _atualizar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = _pedido;
    return Scaffold(
      appBar: AppBar(
        title: Text(pedido != null ? 'Pedido #${pedido.numero}' : 'Pedido'),
      ),
      body: _corpo(pedido),
    );
  }

  Widget _corpo(Pedido? pedido) {
    if (pedido == null) {
      if (_carregandoInicial) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'Não foi possível carregar o pedido',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _erroInicial ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _tentarDeNovo,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final status = pedido.status;

    return RefreshIndicator(
      onRefresh: _atualizar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_aviso != null) _bannerAviso(_aviso!),
          _cartaoStatus(pedido),
          const SizedBox(height: 12),
          if (!status.ehFinal) _linhaTempo(pedido),
          if (_mostraEntregador(pedido)) _linhaEntregador(pedido),
          if (status.terminouComProblema) _cartaoMotivo(pedido),
          if (!status.terminouComProblema) ...[
            const SizedBox(height: 8),
            _etapas(status),
          ],
          if (status == StatusPedido.entregue) ...[
            const SizedBox(height: 12),
            _cartaoAvaliacao(pedido),
          ],
          const SizedBox(height: 16),
          _resumo(pedido),
          if (status.ehFinal) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => repetirPedido(context, pedido),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.replay),
              label: const Text('Repetir pedido'),
            ),
          ],
          if (status.podeCancelar) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _cancelando ? null : _cancelar,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: _cancelando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar pedido'),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _cartaoAvaliacao(Pedido pedido) {
    final avaliacao = pedido.avaliacao;

    if (avaliacao == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Como foi o seu pedido?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                'Avalie a loja e quem entregou.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => _abrirAvaliacao(pedido),
                icon: const Icon(Icons.star_outline),
                label: const Text('Avaliar'),
              ),
            ],
          ),
        ),
      );
    }

   
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sua avaliação',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(pedido.lojaNome)),
                Estrelas(nota: avaliacao.notaLoja, tamanho: 20),
              ],
            ),
            if (avaliacao.notaEntregador != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: Text('Entregador · ${pedido.entregadorNome ?? ''}')),
                  Estrelas(nota: avaliacao.notaEntregador!, tamanho: 20),
                ],
              ),
            ],
            if (avaliacao.comentario.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                avaliacao.comentario,
                style: TextStyle(color: Colors.grey.shade800, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bannerAviso(String mensagem) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$mensagem Mostrando a última informação; tentando de novo...',
              style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  IconData _icone(StatusPedido status) {
    switch (status) {
      case StatusPedido.aguardandoConfirmacao:
        return Icons.hourglass_top;
      case StatusPedido.emPreparo:
        return Icons.restaurant;
      case StatusPedido.pronto:
        return Icons.takeout_dining;
      case StatusPedido.aCaminho:
        return Icons.delivery_dining;
      case StatusPedido.entregue:
        return Icons.check_circle;
      case StatusPedido.recusado:
        return Icons.block;
      case StatusPedido.cancelado:
        return Icons.cancel;
      case StatusPedido.naoEntregue:
        return Icons.report_problem;
      case StatusPedido.desconhecido:
        return Icons.help_outline;
    }
  }

  String _descricao(StatusPedido status) {
    switch (status) {
      case StatusPedido.aguardandoConfirmacao:
        return 'Estamos esperando a loja confirmar o seu pedido.';
      case StatusPedido.emPreparo:
        return 'A loja está preparando o seu pedido.';
      case StatusPedido.pronto:
        return 'Seu pedido está pronto e logo sai para entrega.';
      case StatusPedido.aCaminho:
        return 'Seu pedido saiu para entrega.';
      case StatusPedido.entregue:
        return 'Pedido entregue. Bom apetite!';
      case StatusPedido.recusado:
        return 'A loja não pôde aceitar o seu pedido.';
      case StatusPedido.cancelado:
        return 'Este pedido foi cancelado.';
      case StatusPedido.naoEntregue:
        return 'Não foi possível entregar o seu pedido.';
      case StatusPedido.desconhecido:
        return '';
    }
  }

  Widget _cartaoStatus(Pedido pedido) {
    final status = pedido.status;
    final cores = Theme.of(context).colorScheme;

    Color fundo;
    Color texto;
    if (status.terminouComProblema) {
      fundo = Colors.red.shade50;
      texto = Colors.red.shade800;
    } else if (status == StatusPedido.entregue) {
      fundo = Colors.green.shade50;
      texto = Colors.green.shade800;
    } else {
      fundo = cores.primaryContainer;
      texto = cores.onPrimaryContainer;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(_icone(status), size: 44, color: texto),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.rotulo,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pedido.lojaNome,
                  style: TextStyle(fontWeight: FontWeight.w600, color: texto),
                ),
                const SizedBox(height: 2),
                Text(_descricao(status), style: TextStyle(color: texto)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaTempo(Pedido pedido) {
    final minutos = pedido.tempoEstimadoMin;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              minutos != null
                  ? 'Tempo estimado: $minutos min'
                  : 'A loja ainda vai informar o tempo estimado.',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  bool _mostraEntregador(Pedido pedido) {
    final nome = pedido.entregadorNome;
    if (nome == null || nome.trim().isEmpty) return false;
    return pedido.status == StatusPedido.aCaminho ||
        pedido.status == StatusPedido.entregue ||
        pedido.status == StatusPedido.naoEntregue;
  }

  Widget _linhaEntregador(Pedido pedido) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.two_wheeler),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Entregador: ${pedido.entregadorNome}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoMotivo(Pedido pedido) {
    final motivo = pedido.motivo;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Motivo',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (motivo != null && motivo.trim().isNotEmpty)
                ? motivo
                : 'Nenhum motivo foi registrado.',
          ),
        ],
      ),
    );
  }

  static const _etapasFluxo = [
    StatusPedido.aguardandoConfirmacao,
    StatusPedido.emPreparo,
    StatusPedido.pronto,
    StatusPedido.aCaminho,
    StatusPedido.entregue,
  ];

  Widget _etapas(StatusPedido atual) {
    final indiceAtual = _etapasFluxo.indexOf(atual);
    final cor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        for (var i = 0; i < _etapasFluxo.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(
                  i < indiceAtual
                      ? Icons.check_circle
                      : i == indiceAtual
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                  color: i <= indiceAtual ? cor : Colors.grey.shade400,
                ),
                const SizedBox(width: 10),
                Text(
                  _etapasFluxo[i].rotulo,
                  style: TextStyle(
                    fontWeight: i == indiceAtual ? FontWeight.bold : FontWeight.normal,
                    color: i <= indiceAtual ? null : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _resumo(Pedido pedido) {
    final troco = pedido.pagamento.trocoPara;
    String pagamento = pedido.pagamento.rotulo;
    if (pedido.pagamento.forma == 'dinheiro') {
      pagamento += troco != null ? ' (troco para ${_moeda(troco)})' : ' (sem troco)';
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Valores do momento em que o pedido foi feito.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            for (final item in pedido.itens)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.quantidade}x ${item.nome}'),
                          if (item.complementos.isNotEmpty)
                            Text(
                              item.complementos.join(', '),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          if (item.observacao.trim().isNotEmpty)
                            Text(
                              'Obs: ${item.observacao}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_moeda(item.precoItem)),
                  ],
                ),
              ),
            const Divider(height: 20),
            _linha('Subtotal', _moeda(pedido.subtotal)),
            _linha('Taxa de entrega', _moeda(pedido.taxaEntrega)),
            _linha('Total', _moeda(pedido.total), destaque: true),
            const Divider(height: 20),
            _linha('Entrega em', pedido.endereco.resumo),
            if (pedido.endereco.resumoBairroCidade.isNotEmpty)
              _linha('', pedido.endereco.resumoBairroCidade),
            _linha('Pagamento', pagamento),
          ],
        ),
      ),
    );
  }

  Widget _linha(String rotulo, String valor, {bool destaque = false}) {
    final estilo = destaque
        ? const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
        : TextStyle(color: Colors.grey.shade800);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rotulo, style: estilo),
          const SizedBox(width: 12),
          Flexible(child: Text(valor, textAlign: TextAlign.right, style: estilo)),
        ],
      ),
    );
  }
}
