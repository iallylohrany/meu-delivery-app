import 'package:flutter/material.dart';
import '../../models/pedido.dart';
import '../../services/pedido_service.dart';
import 'carrinho_screen.dart';

String _moeda(double valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';


Future<void> repetirPedido(BuildContext context, Pedido pedido) async {
  RepeticaoPedido? resultado;

  try {
    resultado = await _executar(context, pedido.id, substituir: false);
  } on PedidoConflitoLojaException catch (e) {
  
    if (!context.mounted) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trocar de loja?'),
        content: Text(
          'Seu carrinho já tem itens de "${e.lojaAtualNome}". '
          'Repetir este pedido vai esvaziar o carrinho atual. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Esvaziar e repetir'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    try {
      resultado = await _executar(context, pedido.id, substituir: true);
    } on PedidoException catch (e2) {
      _avisar(context, e2.mensagem);
      return;
    } on PedidoConflitoLojaException {
      return;
    }
  } on PedidoException catch (e) {
    _avisar(context, e.mensagem);
    return;
  }

  if (resultado == null || !context.mounted) return;
  await _mostrarResultado(context, resultado);
}

Future<RepeticaoPedido> _executar(
  BuildContext context,
  String pedidoId, {
  required bool substituir,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  try {
    return await PedidoService.repetir(pedidoId, substituir: substituir);
  } finally {
    if (context.mounted) Navigator.of(context).pop();
  }
}

void _avisar(BuildContext context, String mensagem) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
}

Future<void> _mostrarResultado(BuildContext context, RepeticaoPedido r) async {
  final verCarrinho = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        r.adicionados > 0 ? 'Itens de volta ao carrinho' : 'Nada foi adicionado',
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (r.adicionados > 0)
              Text(
                '${r.adicionados} ${r.adicionados == 1 ? 'item voltou' : 'itens voltaram'} '
                'ao carrinho com os preços de hoje.',
              ),
            if (r.precosAlterados.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Preços que mudaram (total do item)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final p in r.precosAlterados)
                Text('• ${p.nome}: ${_moeda(p.de)} → ${_moeda(p.para)}'),
            ],
            if (r.indisponiveis.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Não foi possível adicionar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              for (final i in r.indisponiveis)
                Text('• ${i.nome} ${i.motivo}', style: TextStyle(color: Colors.red.shade700)),
            ],
            if (!r.lojaAberta && r.adicionados > 0) ...[
              const SizedBox(height: 12),
              const Text(
                'A loja está fechada agora: você só consegue fechar o pedido quando ela abrir.',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Fechar'),
        ),
        if (r.adicionados > 0)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ver carrinho'),
          ),
      ],
    ),
  );

  if (verCarrinho == true && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CarrinhoScreen()),
    );
  }
}
