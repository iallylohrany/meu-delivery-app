import 'package:flutter/material.dart';
import '../models/loja.dart';


class LojaCard extends StatelessWidget {
  final Loja loja;
  final VoidCallback? onTap;

  const LojaCard({super.key, required this.loja, this.onTap});

  @override
  Widget build(BuildContext context) {
    final conteudo = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        
        onTap: loja.aberta ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Foto(loja: loja),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            loja.nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _EtiquetaStatus(aberta: loja.aberta),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loja.categoria,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14),
                        const SizedBox(width: 4),
                        Text('${loja.tempoEstimadoMin} min'),
                        const SizedBox(width: 12),
                        const Icon(Icons.delivery_dining, size: 14),
                        const SizedBox(width: 4),
                        Text(loja.taxaFormatada),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    
    return Opacity(opacity: loja.aberta ? 1.0 : 0.45, child: conteudo);
  }
}

class _Foto extends StatelessWidget {
  final Loja loja;
  const _Foto({required this.loja});

  @override
  Widget build(BuildContext context) {
    const tamanho = 64.0;

    if (loja.fotoUrl == null || loja.fotoUrl!.isEmpty) {
      return _placeholder(tamanho);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        loja.fotoUrl!,
        width: tamanho,
        height: tamanho,
        fit: BoxFit.cover,
        
        errorBuilder: (_, __, ___) => _placeholder(tamanho),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: tamanho,
            height: tamanho,
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder(double tamanho) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.storefront, color: Colors.grey.shade500),
    );
  }
}

class _EtiquetaStatus extends StatelessWidget {
  final bool aberta;
  const _EtiquetaStatus({required this.aberta});

  @override
  Widget build(BuildContext context) {
    final cor = aberta ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor),
      ),
      child: Text(
        aberta ? 'Aberta' : 'Fechada',
        style: TextStyle(
          color: cor.shade800,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  final Loja loja;
  const _Nota({required this.loja});

  @override
  Widget build(BuildContext context) {
    if (loja.mediaAvaliacao == null) {
      return Text(
        'Sem avaliações',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: 16, color: Colors.amber.shade700),
        const SizedBox(width: 2),
        Text(
          loja.mediaFormatada,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          ' (${loja.totalAvaliacoes})',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
}
