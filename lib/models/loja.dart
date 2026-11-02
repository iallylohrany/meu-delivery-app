
class Loja {
  final String id;
  final String nome;
  final String categoria;
  final String? fotoUrl;
  final int tempoEstimadoMin;
  final double taxaEntrega;
  final bool aberta;

  const Loja({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.fotoUrl,
    required this.tempoEstimadoMin,
    required this.taxaEntrega,
    required this.aberta,
  });

  factory Loja.fromJson(Map<String, dynamic> json) {
    return Loja(
      id: (json['id'] ?? '').toString(),
      nome: json['nome'] as String? ?? 'Sem nome',
      categoria: json['categoria'] as String? ?? 'Outros',
      fotoUrl: json['fotoUrl'] as String?,
      tempoEstimadoMin: (json['tempoEstimadoMin'] as num?)?.toInt() ?? 0,
      taxaEntrega: (json['taxaEntrega'] as num?)?.toDouble() ?? 0,
    
      aberta: json['aberta'] as bool? ?? false,
      mediaAvaliacao: (json['mediaAvaliacao'] as num?)?.toDouble(),
      totalAvaliacoes: (json['totalAvaliacoes'] as num?)?.toInt() ?? 0,
    );
  }

  String get mediaFormatada =>
      mediaAvaliacao == null ? '' : mediaAvaliacao!.toStringAsFixed(1).replaceAll('.', ',');

  String get taxaFormatada {
    if (taxaEntrega <= 0) return 'Grátis';
    return 'R\$ ${taxaEntrega.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}
