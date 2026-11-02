
class OfertaEntrega {
  final String id;
  final String origem;
  final String destino;
  final double distanciaKm;
  final double valor;

 
  final int prazoSegundos;


  final int segundosRestantes;

  OfertaEntrega({
    required this.id,
    required this.origem,
    required this.destino,
    required this.distanciaKm,
    required this.valor,
    required this.prazoSegundos,
    required this.segundosRestantes,
  });

  factory OfertaEntrega.fromJson(Map<String, dynamic> json) {
    return OfertaEntrega(
      id: (json['id'] ?? '').toString(),
      origem: json['origem'] as String? ?? '',
      destino: json['destino'] as String? ?? '',
      distanciaKm: (json['distanciaKm'] as num? ?? 0.0).toDouble(),
      valor: (json['valor'] as num? ?? 0.0).toDouble(),
      prazoSegundos: (json['prazoSegundos'] as num?)?.toInt() ?? 0,
      segundosRestantes: (json['segundosRestantes'] as num?)?.toInt() ?? 0,
    );
  }
}


class RespostaOferta {
  final OfertaEntrega? oferta;
  final String? mensagemEncerrada;

  RespostaOferta({required this.oferta, required this.mensagemEncerrada});

  factory RespostaOferta.fromJson(Map<String, dynamic> json) {
    final oferta = json['oferta'];
    final encerrada = json['encerrada'];
    return RespostaOferta(
      oferta: oferta is Map<String, dynamic> ? OfertaEntrega.fromJson(oferta) : null,
      mensagemEncerrada:
          encerrada is Map ? encerrada['mensagem'] as String? : null,
    );
  }
}
