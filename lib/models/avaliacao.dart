
class Avaliacao {
  final int notaLoja;

 
  final int? notaEntregador;
  final String comentario;
  final DateTime? criadaEm;

  Avaliacao({
    required this.notaLoja,
    required this.notaEntregador,
    required this.comentario,
    required this.criadaEm,
  });

  factory Avaliacao.fromJson(Map<String, dynamic> json) {
    return Avaliacao(
      notaLoja: (json['notaLoja'] as num?)?.toInt() ?? 0,
      notaEntregador: (json['notaEntregador'] as num?)?.toInt(),
      comentario: json['comentario'] as String? ?? '',
      criadaEm: DateTime.tryParse(json['criadaEm'] as String? ?? '')?.toLocal(),
    );
  }
}
