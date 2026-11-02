import 'package:flutter/material.dart';
import '../../models/avaliacao.dart';
import '../../models/pedido.dart';
import '../../services/pedido_service.dart';
import '../../widgets/estrelas.dart';


class AvaliacaoScreen extends StatefulWidget {
  final Pedido pedido;

  const AvaliacaoScreen({super.key, required this.pedido});

  @override
  State<AvaliacaoScreen> createState() => _AvaliacaoScreenState();
}

class _AvaliacaoScreenState extends State<AvaliacaoScreen> {
  Avaliacao? _avaliacao;
  bool _recemEnviada = false;

  int _notaLoja = 0;
  int _notaEntregador = 0;
  final _comentarioController = TextEditingController();

  bool _enviando = false;
  String? _erro;

  bool get _temEntregador => (widget.pedido.entregadorNome ?? '').trim().isNotEmpty;

  bool get _podeEnviar =>
      !_enviando && _notaLoja > 0 && (!_temEntregador || _notaEntregador > 0);

  @override
  void initState() {
    super.initState();
    
    _avaliacao = widget.pedido.avaliacao;
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });

    try {
      final avaliacao = await PedidoService.avaliar(
        widget.pedido.id,
        notaLoja: _notaLoja,
        notaEntregador: _temEntregador ? _notaEntregador : null,
        comentario: _comentarioController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _avaliacao = avaliacao;
        _recemEnviada = true;
        _enviando = false;
      });
    } on PedidoException catch (e) {
      if (!mounted) return;

      if (e.conflito) {
       
        try {
          final atualizado = await PedidoService.buscar(widget.pedido.id);
          if (!mounted) return;
          if (atualizado.avaliacao != null) {
            setState(() {
              _avaliacao = atualizado.avaliacao;
              _enviando = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
            return;
          }
        } on PedidoException {
         
        }
      }

      if (!mounted) return;
      
      setState(() {
        _enviando = false;
        _erro = e.mensagem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;

    return Scaffold(
      appBar: AppBar(title: Text('Avaliar pedido #${pedido.numero}')),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    final pedido = widget.pedido;

    if (_avaliacao != null) return _leitura(_avaliacao!);

    if (pedido.status != StatusPedido.entregue) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'A avaliação ainda não está disponível',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Só é possível avaliar pedidos entregues.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_erro != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(_erro!, style: const TextStyle(color: Colors.red))),
              ],
            ),
          ),
        _blocoNota(
          titulo: 'Como foi a loja?',
          subtitulo: pedido.lojaNome,
          nota: _notaLoja,
          aoMudar: (n) => setState(() => _notaLoja = n),
        ),
        if (_temEntregador) ...[
          const SizedBox(height: 12),
          _blocoNota(
            titulo: 'Como foi o entregador?',
            subtitulo: pedido.entregadorNome!,
            nota: _notaEntregador,
            aoMudar: (n) => setState(() => _notaEntregador = n),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _comentarioController,
          enabled: !_enviando,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Comentário (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _podeEnviar ? _enviar : null,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          child: _enviando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar avaliação'),
        ),
        const SizedBox(height: 8),
        Text(
          'Cada pedido só pode ser avaliado uma vez.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _blocoNota({
    required String titulo,
    required String subtitulo,
    required int nota,
    required ValueChanged<int> aoMudar,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(subtitulo, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Estrelas(nota: nota, aoMudar: _enviando ? null : aoMudar),
          ],
        ),
      ),
    );
  }

  Widget _leitura(Avaliacao avaliacao) {
    final pedido = widget.pedido;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _recemEnviada ? 'Obrigado pela avaliação!' : 'Este pedido já foi avaliado',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
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
                const SizedBox(height: 12),
                Text(pedido.lojaNome, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Estrelas(nota: avaliacao.notaLoja, tamanho: 28),
                if (avaliacao.notaEntregador != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Entregador${(pedido.entregadorNome ?? '').isNotEmpty ? ' · ${pedido.entregadorNome}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Estrelas(nota: avaliacao.notaEntregador!, tamanho: 28),
                ],
                if (avaliacao.comentario.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Comentário', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(avaliacao.comentario),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cada pedido só pode ser avaliado uma vez.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
}
