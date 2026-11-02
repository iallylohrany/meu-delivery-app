import 'package:flutter/material.dart';
import '../../models/carrinho.dart';
import '../../services/carrinho_service.dart';
import 'checkout_screen.dart';
import 'produto_detail_modal.dart';

class CarrinhoScreen extends StatefulWidget {
  const CarrinhoScreen({super.key});

  @override
  State<CarrinhoScreen> createState() => _CarrinhoScreenState();
}

class _CarrinhoScreenState extends State<CarrinhoScreen> {
  bool _carregando = true;
  String? _erro;
  Carrinho _carrinho = Carrinho.vazio();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final carrinho = await CarrinhoService.buscarCarrinho();
      if (!mounted) return;
      setState(() {
        _carrinho = carrinho;
        _carregando = false;
      });
    } on CarrinhoException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
    }
  }

  Future<void> _editarItem(ItemCarrinho item) async {
    final salvo = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ProdutoDetailModal(
        produto: item.produto,
        lojaId: _carrinho.lojaId ?? '',
        itemExistente: item,
      ),
    );
    if (salvo == true) _carregar();
  }

  Future<void> _alterarQuantidade(ItemCarrinho item, int novaQuantidade) async {
    if (novaQuantidade < 1) {
      _removerItem(item);
      return;
    }

    try {
      final atualizado = await CarrinhoService.atualizarItem(
        itemId: item.id,
        quantidade: novaQuantidade,
      );
      if (!mounted) return;
    
      setState(() => _carrinho = atualizado);
    } on CarrinhoException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }
  Future<void> _finalizar() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
   
    if (mounted) _carregar();
  }

  Future<void> _removerItem(ItemCarrinho item) async {
    try {
      final atualizado = await CarrinhoService.removerItem(item.id);
      if (!mounted) return;
      setState(() => _carrinho = atualizado);
    } on CarrinhoException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carrinho')),
      body: _corpo(),
      bottomNavigationBar: _rodape(),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro != null) {
      return _MensagemVazia(
        icone: Icons.cloud_off,
        titulo: 'Não foi possível carregar',
        descricao: _erro!,
        textoBotao: 'Tentar novamente',
        aoClicar: _carregar,
      );
    }

    if (_carrinho.estaVazio) {
      return const _MensagemVazia(
        icone: Icons.shopping_cart_outlined,
        titulo: 'Seu carrinho está vazio',
        descricao: 'Adicione produtos de uma loja para continuar.',
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Text(
            _carrinho.lojaNome ?? '',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (final item in _carrinho.itens)
            _ItemCarrinhoCard(
              item: item,
              onEditar: () => _editarItem(item),
              onRemover: () => _removerItem(item),
              onAumentar: () => _alterarQuantidade(item, item.quantidade + 1),
              onDiminuir: () => _alterarQuantidade(item, item.quantidade - 1),
            ),
        ],
      ),
    );
  }

  Widget? _rodape() {
    if (_carregando || _erro != null || _carrinho.estaVazio) return null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _linhaValor('Subtotal', _carrinho.subtotal),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'A taxa de entrega e o total final são calculados no fechamento, conforme o endereço.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _finalizar,
                child: const Text('Finalizar pedido'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaValor(String label, double valor, {bool destaque = false}) {
    final estilo = destaque
        ? const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)
        : TextStyle(color: Colors.grey.shade700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: estilo),
          Text('R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}', style: estilo),
        ],
      ),
    );
  }
}

class _ItemCarrinhoCard extends StatelessWidget {
  final ItemCarrinho item;
  final VoidCallback onEditar;
  final VoidCallback onRemover;
  final VoidCallback onAumentar;
  final VoidCallback onDiminuir;

  const _ItemCarrinhoCard({
    required this.item,
    required this.onEditar,
    required this.onRemover,
    required this.onAumentar,
    required this.onDiminuir,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.produto.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Text(
                  'R\$ ${item.precoItem.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (item.complementos.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.complementos.map((c) => c.nome).join(', '),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
            if (item.observacao.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Obs: ${item.observacao}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: onDiminuir,
                  tooltip: item.quantidade == 1 ? 'Remover' : 'Diminuir',
                ),
                Text('${item.quantidade}', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onAumentar,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onRemover,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MensagemVazia extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;
  final String? textoBotao;
  final VoidCallback? aoClicar;

  const _MensagemVazia({
    required this.icone,
    required this.titulo,
    required this.descricao,
    this.textoBotao,
    this.aoClicar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                icon: const Icon(Icons.refresh),
                label: Text(textoBotao!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
