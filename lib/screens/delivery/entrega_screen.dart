import 'package:flutter/material.dart';
import '../../models/entrega.dart';
import '../../services/entregador_service.dart';

String _moeda(double valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';


class EntregaScreen extends StatefulWidget {
  final Entrega entrega;

  const EntregaScreen({super.key, required this.entrega});

  @override
  State<EntregaScreen> createState() => _EntregaScreenState();
}

class _EntregaScreenState extends State<EntregaScreen> {
  late Entrega _entrega;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _entrega = widget.entrega;
    _recarregar();
  }

 
  Future<void> _recarregar() async {
    try {
      final atual = await EntregadorService.buscarEntrega(_entrega.id);
      if (!mounted) return;
      setState(() => _entrega = atual);
    } on EntregadorException {
    
    }
  }

  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _executar(
    Future<Entrega> Function() acao, {
    String? sucesso,
  }) async {
    setState(() => _enviando = true);

    try {
      final nova = await acao();
      if (!mounted) return;
      setState(() {
        _entrega = nova;
        _enviando = false;
      });
      if (sucesso != null) _avisar(sucesso);
    } on EntregadorException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _avisar(e.mensagem);
     
      _recarregar();
    }
  }

  Future<void> _confirmarColeta() => _executar(
        () => EntregadorService.confirmarColeta(_entrega.id),
        sucesso: 'Coleta confirmada. O pedido está a caminho do cliente.',
      );

  Future<void> _confirmarEntrega() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar entrega?'),
        content: const Text('Isso fecha o pedido como entregue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar entrega'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    await _executar(
      () => EntregadorService.confirmarEntrega(_entrega.id),
      sucesso: 'Entrega confirmada. Pedido fechado como entregue.',
    );
  }

  Future<void> _registrarInsucesso() async {
    final motivo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _MotivoInsucessoSheet(),
    );
    if (motivo == null || !mounted) return;

    await _executar(
      () => EntregadorService.registrarInsucesso(_entrega.id, motivo),
      sucesso: 'Insucesso registrado.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Entrega #${_entrega.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cartaoStatus(),
          const SizedBox(height: 12),
          if (_entrega.status != StatusEntrega.insucesso) _etapas(),
          if (_entrega.status == StatusEntrega.insucesso) _cartaoMotivo(),
          const SizedBox(height: 12),
          _secao(
            icone: Icons.storefront_outlined,
            titulo: 'Retirar em',
            filhos: [
              Text(
                _entrega.lojaNome,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(_entrega.enderecoDaLoja),
            ],
          ),
          const SizedBox(height: 12),
          _secao(
            icone: Icons.location_on_outlined,
            titulo: 'Entregar em',
            filhos: [
              Text(
                _entrega.destino,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _pontoDeReferencia(),
            ],
          ),
          const SizedBox(height: 12),
          _secao(
            icone: Icons.receipt_long_outlined,
            titulo: 'Itens do pedido',
            filhos: [
              if (_entrega.itens.isEmpty)
                Text('Itens não informados.', style: TextStyle(color: Colors.grey.shade600)),
              for (final item in _entrega.itens)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
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
            ],
          ),
          const SizedBox(height: 12),
          _secao(
            icone: Icons.payments_outlined,
            titulo: 'Corrida',
            filhos: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_entrega.distanciaKm.toStringAsFixed(1).replaceAll('.', ',')} km',
                  ),
                  Text(
                    _moeda(_entrega.valor),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: _acoes(),
    );
  }

  Widget _cartaoStatus() {
    final cores = Theme.of(context).colorScheme;
    final status = _entrega.status;

    Color fundo = cores.primaryContainer;
    Color texto = cores.onPrimaryContainer;
    IconData icone = Icons.two_wheeler;
    String descricao;

    switch (status) {
      case StatusEntrega.indoParaLoja:
        descricao = 'Siga até a loja e confirme a coleta quando pegar o pedido.';
        icone = Icons.storefront_outlined;
        break;
      case StatusEntrega.aCaminho:
        descricao = 'Leve o pedido ao cliente e confirme a entrega.';
        icone = Icons.delivery_dining;
        break;
      case StatusEntrega.entregue:
        descricao = 'Entrega concluída. O pedido foi fechado como entregue.';
        icone = Icons.check_circle;
        fundo = Colors.green.shade50;
        texto = Colors.green.shade800;
        break;
      case StatusEntrega.insucesso:
        descricao = 'A entrega não foi concluída.';
        icone = Icons.report_problem;
        fundo = Colors.red.shade50;
        texto = Colors.red.shade800;
        break;
      case StatusEntrega.desconhecido:
        descricao = '';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icone, size: 44, color: texto),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.rotulo,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: texto),
                ),
                const SizedBox(height: 2),
                Text(descricao, style: TextStyle(color: texto)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _etapas() {
    const passos = ['Ir à loja e coletar', 'Levar ao cliente', 'Entregue'];
    final atual = _entrega.status == StatusEntrega.indoParaLoja
        ? 0
        : _entrega.status == StatusEntrega.aCaminho
            ? 1
            : 2;
    final cor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        for (var i = 0; i < passos.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _entrega.status == StatusEntrega.entregue || i < atual
                      ? Icons.check_circle
                      : i == atual
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                  color: i <= atual ? cor : Colors.grey.shade400,
                ),
                const SizedBox(width: 10),
                Text(
                  passos[i],
                  style: TextStyle(
                    fontWeight: i == atual ? FontWeight.bold : FontWeight.normal,
                    color: i <= atual ? null : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cartaoMotivo() {
    return Container(
      width: double.infinity,
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
            'Motivo registrado',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800),
          ),
          const SizedBox(height: 4),
          Text(_entrega.motivoInsucesso ?? 'Não informado'),
        ],
      ),
    );
  }

  Widget _pontoDeReferencia() {
    final ref = _entrega.pontoReferencia.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_outlined, size: 20, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ponto de referência',
                  style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                ),
                Text(
                  ref.isEmpty ? 'Nenhum ponto de referência informado.' : ref,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _secao({
    required IconData icone,
    required String titulo,
    required List<Widget> filhos,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(titulo, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            ...filhos,
          ],
        ),
      ),
    );
  }

  Widget? _acoes() {
    final status = _entrega.status;
    if (!status.ehAtiva) return null;

    final carregando = const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == StatusEntrega.indoParaLoja)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _confirmarColeta,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: _enviando ? carregando : const Icon(Icons.inventory_2_outlined),
                  label: const Text('Confirmar coleta'),
                ),
              ),
            if (status == StatusEntrega.aCaminho) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _confirmarEntrega,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: _enviando ? carregando : const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar entrega'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _enviando ? null : _registrarInsucesso,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Registrar insucesso'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MotivoInsucessoSheet extends StatefulWidget {
  const _MotivoInsucessoSheet();

  @override
  State<_MotivoInsucessoSheet> createState() => _MotivoInsucessoSheetState();
}

class _MotivoInsucessoSheetState extends State<_MotivoInsucessoSheet> {
  String? _escolhido;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Por que a entrega não deu certo?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Escolha o motivo para registrar o insucesso.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            for (final motivo in MotivoInsucesso.lista)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _escolhido == motivo.codigo ? cor : Colors.grey.shade300,
                    width: _escolhido == motivo.codigo ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  title: Text(motivo.rotulo),
                  trailing: _escolhido == motivo.codigo
                      ? Icon(Icons.check_circle, color: cor)
                      : const Icon(Icons.circle_outlined, color: Colors.grey),
                  onTap: () => setState(() => _escolhido = motivo.codigo),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _escolhido == null ? null : () => Navigator.pop(context, _escolhido),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Registrar'),
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
