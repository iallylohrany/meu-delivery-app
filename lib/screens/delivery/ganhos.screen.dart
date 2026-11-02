import 'package:flutter/material.dart';
import '../../models/entrega.dart';
import '../../services/entregador_service.dart';

String _moeda(double valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';


class GanhosScreen extends StatefulWidget {
  const GanhosScreen({super.key});

  @override
  State<GanhosScreen> createState() => _GanhosScreenState();
}

class _GanhosScreenState extends State<GanhosScreen> {
  bool _carregando = true;
  String? _erro;
  GanhosDoDia? _ganhos;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      
      _carregando = _ganhos == null;
      _erro = null;
    });

    try {
      final ganhos = await EntregadorService.buscarGanhos();
      if (!mounted) return;
      setState(() {
        _ganhos = ganhos;
        _carregando = false;
      });
    } on EntregadorException catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        if (_ganhos == null) {
          _erro = e.mensagem;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
        }
      });
    }
  }

  String _hora(DateTime? d) {
    if (d == null) return '';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.hour)}:${dois(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    final ganhos = _ganhos;

    if (_erro != null || ganhos == null) {
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
                _erro ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _carregar,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final cores = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cores.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ganhos de hoje · ${ganhos.dataFormatada}',
                  style: TextStyle(color: cores.onPrimaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  _moeda(ganhos.total),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: cores.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ganhos.quantidade} ${ganhos.quantidade == 1 ? 'entrega' : 'entregas'}',
                  style: TextStyle(color: cores.onPrimaryContainer),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (ganhos.entregas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhuma entrega concluída hoje',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'As entregas que você fechar aparecem aqui.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          else ...[
            const Text(
              'Entregas do dia',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            for (final e in ganhos.entregas)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(e.lojaNome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${e.destino}\n${_hora(e.finalizadaEm)}'),
                  isThreeLine: true,
                  trailing: Text(
                    _moeda(e.valor),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
