import 'package:flutter/material.dart';
import '../../models/pedido.dart';
import '../../services/pedido_service.dart';
import 'avaliacao_screen.dart';
import 'pedido_acompanhamento_screen.dart';
import 'repetir_pedido.dart';

String _moeda(double valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';


class PedidosScreen extends StatefulWidget {
  final VoidCallback? onSessaoExpirada;

  
  final VoidCallback? onVerLojas;

  const PedidosScreen({super.key, this.onSessaoExpirada, this.onVerLojas});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  bool _carregando = true;
  String? _erro;
  List<Pedido> _pedidos = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
    
      _carregando = _pedidos.isEmpty;
      _erro = null;
    });

    try {
      final pedidos = await PedidoService.listar();
      if (!mounted) return;
      setState(() {
        _pedidos = pedidos;
        _carregando = false;
      });
    } on PedidoException catch (e) {
      if (!mounted) return;

      if (e.tokenInvalido) {
        widget.onSessaoExpirada?.call();
        return;
      }

      setState(() {
        _carregando = false;
        
        if (_pedidos.isEmpty) {
          _erro = e.mensagem;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
        }
      });
    }
  }

  Future<void> _abrir(Pedido pedido) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PedidoAcompanhamentoScreen(
          pedidoId: pedido.id,
          pedidoInicial: pedido,
        ),
      ),
    );
    if (mounted) _carregar();
  }

  Future<void> _avaliar(Pedido pedido) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AvaliacaoScreen(pedido: pedido)),
    );
    if (mounted) _carregar();
  }

  String _data(DateTime? d) {
    if (d == null) return '';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year} às ${dois(d.hour)}:${dois(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro != null) {
      return _Mensagem(
        icone: Icons.cloud_off,
        titulo: 'Não foi possível carregar',
        descricao: _erro!,
        textoBotao: 'Tentar novamente',
        iconeBotao: Icons.refresh,
        aoClicar: _carregar,
      );
    }

    
    if (_pedidos.isEmpty) {
      return _Mensagem(
        icone: Icons.receipt_long_outlined,
        titulo: 'Você ainda não fez nenhum pedido',
        descricao: 'Quando você pedir, seus pedidos aparecem aqui e dá para repetir com um toque.',
        textoBotao: widget.onVerLojas != null ? 'Ver lojas' : null,
        iconeBotao: Icons.storefront_outlined,
        aoClicar: widget.onVerLojas,
      );
    }

    final emAndamento = _pedidos.where((p) => !p.status.ehFinal).toList();
    final anteriores = _pedidos.where((p) => p.status.ehFinal).toList();

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          if (emAndamento.isNotEmpty) ...[
            _titulo('Em andamento'),
            for (final p in emAndamento) _cartao(p),
          ],
          if (anteriores.isNotEmpty) ...[
            _titulo('Histórico'),
            for (final p in anteriores) _cartao(p),
          ],
        ],
      ),
    );
  }

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
        child: Text(
          texto,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      );

  Widget _cartao(Pedido pedido) {
    final cor = pedido.status.terminouComProblema
        ? Colors.red
        : pedido.status == StatusPedido.entregue
            ? Colors.green
            : Theme.of(context).colorScheme.primary;

    final itens = pedido.itens.map((i) => '${i.quantidade}x ${i.nome}').join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrir(pedido),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${pedido.lojaNome} · #${pedido.numero}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Text(
                    pedido.status.rotulo,
                    style: TextStyle(color: cor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                itens,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade800),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_data(pedido.criadoEm)} · ${_moeda(pedido.total)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ),
                  if (pedido.status == StatusPedido.entregue && pedido.avaliacao == null)
                    TextButton.icon(
                      onPressed: () => _avaliar(pedido),
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: const Text('Avaliar'),
                    ),
                  if (pedido.avaliacao != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                          const SizedBox(width: 2),
                          Text(
                            '${pedido.avaliacao!.notaLoja}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  if (pedido.status.ehFinal)
                    TextButton.icon(
                      onPressed: () => repetirPedido(context, pedido),
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('Repetir'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mensagem extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;
  final String? textoBotao;
  final IconData iconeBotao;
  final VoidCallback? aoClicar;

  const _Mensagem({
    required this.icone,
    required this.titulo,
    required this.descricao,
    this.textoBotao,
    this.iconeBotao = Icons.refresh,
    this.aoClicar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            if (textoBotao != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: aoClicar,
                icon: Icon(iconeBotao),
                label: Text(textoBotao!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
