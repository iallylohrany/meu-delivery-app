enum StatusEntrega {
  indoParaLoja,
  aCaminho,
  entregue,
  insucesso,
  desconhecido;

  static StatusEntrega fromApi(String? valor) {
    switch (valor) {
      case 'indo_para_loja':
        return StatusEntrega.indoParaLoja;
      case 'a_caminho':
        return StatusEntrega.aCaminho;
      case 'entregue':
        return StatusEntrega.entregue;
      case 'insucesso':
        return StatusEntrega.insucesso;
      default:
        return StatusEntrega.desconhecido;
    }
  }

  String get rotulo {
    switch (this) {
      case StatusEntrega.indoParaLoja:
        return 'Indo para a loja';
      case StatusEntrega.aCaminho:
        return 'A caminho do cliente';
      case StatusEntrega.entregue:
        return 'Entregue';
      case StatusEntrega.insucesso:
        return 'Insucesso na entrega';
      case StatusEntrega.desconhecido:
        return 'Status desconhecido';
    }
  }


  bool get ehAtiva => this == StatusEntrega.indoParaLoja || this == StatusEntrega.aCaminho;
}

class ItemEntrega {
  final String nome;
  final int quantidade;
  final String observacao;
  final List<String> complementos;

  ItemEntrega({
    required this.nome,
    required this.quantidade,
    required this.observacao,
    required this.complementos,
  });

  factory ItemEntrega.fromJson(Map<String, dynamic> json) {
    return ItemEntrega(
      nome: json['nome'] as String? ?? '',
      quantidade: (json['quantidade'] as num?)?.toInt() ?? 1,
      observacao: json['observacao'] as String? ?? '',
      complementos: (json['complementos'] as List? ?? []).map((c) => c.toString()).toList(),
    );
  }
}


class Entrega {
  final String id;
  final String? pedidoId;
  final String lojaNome;
  final String origem;
  final String destino;
  final String pontoReferencia;
  final List<ItemEntrega> itens;
  final double distanciaKm;
  final double valor;
  final StatusEntrega status;
  final String? motivoInsucesso;
  final DateTime? finalizadaEm;

  Entrega({
    required this.id,
    required this.pedidoId,
    required this.lojaNome,
    required this.origem,
    required this.destino,
    required this.pontoReferencia,
    required this.itens,
    required this.distanciaKm,
    required this.valor,
    required this.status,
    required this.motivoInsucesso,
    required this.finalizadaEm,
  });

  factory Entrega.fromJson(Map<String, dynamic> json) {
    return Entrega(
      id: (json['id'] ?? '').toString(),
      pedidoId: json['pedidoId']?.toString(),
      lojaNome: json['lojaNome'] as String? ?? '',
      origem: json['origem'] as String? ?? '',
      destino: json['destino'] as String? ?? '',
      pontoReferencia: json['pontoReferencia'] as String? ?? '',
      itens: (json['itens'] as List? ?? [])
          .map((i) => ItemEntrega.fromJson(i as Map<String, dynamic>))
          .toList(),
      distanciaKm: (json['distanciaKm'] as num? ?? 0.0).toDouble(),
      valor: (json['valor'] as num? ?? 0.0).toDouble(),
      status: StatusEntrega.fromApi(json['status'] as String?),
      motivoInsucesso: json['motivoInsucesso'] as String?,
      finalizadaEm: DateTime.tryParse(json['finalizadaEm'] as String? ?? '')?.toLocal(),
    );
  }

  
  String get enderecoDaLoja {
    final prefixo = '$lojaNome · ';
    return origem.startsWith(prefixo) ? origem.substring(prefixo.length) : origem;
  }
}


class MotivoInsucesso {
  final String codigo;
  final String rotulo;

  const MotivoInsucesso(this.codigo, this.rotulo);

  static const lista = [
    MotivoInsucesso('cliente_ausente', 'Cliente ausente'),
    MotivoInsucesso('endereco_nao_encontrado', 'Endereço não encontrado'),
    MotivoInsucesso('cliente_recusou', 'Cliente recusou o pedido'),
    MotivoInsucesso('cliente_nao_atende', 'Cliente não atende o telefone'),
    MotivoInsucesso('outro', 'Outro motivo'),
  ];
}

class GanhoEntrega {
  final String id;
  final String lojaNome;
  final String destino;
  final double valor;
  final DateTime? finalizadaEm;

  GanhoEntrega({
    required this.id,
    required this.lojaNome,
    required this.destino,
    required this.valor,
    required this.finalizadaEm,
  });

  factory GanhoEntrega.fromJson(Map<String, dynamic> json) {
    return GanhoEntrega(
      id: (json['id'] ?? '').toString(),
      lojaNome: json['lojaNome'] as String? ?? '',
      destino: json['destino'] as String? ?? '',
      valor: (json['valor'] as num? ?? 0.0).toDouble(),
      finalizadaEm: DateTime.tryParse(json['finalizadaEm'] as String? ?? '')?.toLocal(),
    );
  }
}


class GanhosDoDia {
  /// AAAA-MM-DD
  final String data;
  final int quantidade;
  final double total;
  final List<GanhoEntrega> entregas;

  GanhosDoDia({
    required this.data,
    required this.quantidade,
    required this.total,
    required this.entregas,
  });

  factory GanhosDoDia.fromJson(Map<String, dynamic> json) {
    return GanhosDoDia(
      data: json['data'] as String? ?? '',
      quantidade: (json['quantidade'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num? ?? 0.0).toDouble(),
      entregas: (json['entregas'] as List? ?? [])
          .map((e) => GanhoEntrega.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }


  String get dataFormatada {
    final partes = data.split('-');
    if (partes.length != 3) return data;
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }
}
