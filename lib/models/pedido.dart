import 'avaliacao.dart';
import 'carrinho.dart';
import 'endereco.dart';

enum StatusPedido {
  aguardandoConfirmacao,
  emPreparo,
  pronto,
  aCaminho,
  entregue,
  recusado,
  cancelado,
  naoEntregue,
  desconhecido;

  static StatusPedido fromApi(String? valor) {
    switch (valor) {
      case 'aguardando_confirmacao':
        return StatusPedido.aguardandoConfirmacao;
      case 'em_preparo':
        return StatusPedido.emPreparo;
      case 'pronto':
        return StatusPedido.pronto;
      case 'a_caminho':
        return StatusPedido.aCaminho;
      case 'entregue':
        return StatusPedido.entregue;
      case 'recusado':
        return StatusPedido.recusado;
      case 'cancelado':
        return StatusPedido.cancelado;
      case 'nao_entregue':
        return StatusPedido.naoEntregue;
      default:
        return StatusPedido.desconhecido;
    }
  }

  String get rotulo {
    switch (this) {
      case StatusPedido.aguardandoConfirmacao:
        return 'Aguardando confirmação';
      case StatusPedido.emPreparo:
        return 'Em preparo';
      case StatusPedido.pronto:
        return 'Pronto';
      case StatusPedido.aCaminho:
        return 'A caminho';
      case StatusPedido.entregue:
        return 'Entregue';
      case StatusPedido.recusado:
        return 'Recusado';
      case StatusPedido.cancelado:
        return 'Cancelado';
      case StatusPedido.naoEntregue:
        return 'Não entregue';
      case StatusPedido.desconhecido:
        return 'Status desconhecido';
    }
  }


  bool get terminouComProblema =>
      this == StatusPedido.recusado ||
      this == StatusPedido.cancelado ||
      this == StatusPedido.naoEntregue;

  
  bool get ehFinal => this == StatusPedido.entregue || terminouComProblema;

 
  bool get podeCancelar => this == StatusPedido.aguardandoConfirmacao;
}

class ItemPedido {
  final String nome;
  final int quantidade;
  final String observacao;
  final List<String> complementos;
  final double precoItem;

  ItemPedido({
    required this.nome,
    required this.quantidade,
    required this.observacao,
    required this.complementos,
    required this.precoItem,
  });

  factory ItemPedido.fromJson(Map<String, dynamic> json) {
    return ItemPedido(
      nome: json['nome'] as String? ?? '',
      quantidade: (json['quantidade'] as num?)?.toInt() ?? 1,
      observacao: json['observacao'] as String? ?? '',
      complementos: (json['complementos'] as List? ?? [])
          .map((c) => c.toString())
          .toList(),
      precoItem: (json['precoItem'] as num? ?? 0.0).toDouble(),
    );
  }
}

class PagamentoPedido {
 
  final String forma;
  final double? trocoPara;

  PagamentoPedido({required this.forma, this.trocoPara});

  factory PagamentoPedido.fromJson(Map<String, dynamic> json) {
    return PagamentoPedido(
      forma: json['forma'] as String? ?? '',
      trocoPara: (json['trocoPara'] as num?)?.toDouble(),
    );
  }

  static String rotuloDaForma(String forma) {
    switch (forma) {
      case 'dinheiro':
        return 'Dinheiro';
      case 'cartao_entrega':
        return 'Cartão na entrega';
      case 'pix':
        return 'Pix';
      default:
        return forma;
    }
  }

  String get rotulo => rotuloDaForma(forma);
}

class Pedido {
  final String id;
  final int numero;
  final String lojaId;
  final String lojaNome;
  final StatusPedido status;
  final List<ItemPedido> itens;

 
  final double subtotal;
  final double taxaEntrega;
  final double total;

  final Endereco endereco;
  final PagamentoPedido pagamento;

 
  final int? tempoEstimadoMin;

 
  final String? entregadorNome;


  final String? motivo;

  final DateTime? criadoEm;

 
  final Avaliacao? avaliacao;

  Pedido({
    required this.id,
    required this.numero,
    required this.lojaId,
    required this.lojaNome,
    required this.status,
    required this.itens,
    required this.subtotal,
    required this.taxaEntrega,
    required this.total,
    required this.endereco,
    required this.pagamento,
    required this.tempoEstimadoMin,
    required this.entregadorNome,
    required this.motivo,
    required this.criadoEm,
    required this.avaliacao,
  });

  factory Pedido.fromJson(Map<String, dynamic> json) {
    return Pedido(
      id: (json['id'] ?? '').toString(),
      numero: (json['numero'] as num?)?.toInt() ?? 0,
      lojaId: (json['lojaId'] ?? '').toString(),
      lojaNome: json['lojaNome'] as String? ?? '',
      status: StatusPedido.fromApi(json['status'] as String?),
      itens: (json['itens'] as List? ?? [])
          .map((i) => ItemPedido.fromJson(i as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num? ?? 0.0).toDouble(),
      taxaEntrega: (json['taxaEntrega'] as num? ?? 0.0).toDouble(),
      total: (json['total'] as num? ?? 0.0).toDouble(),
      endereco:
          Endereco.fromJson((json['endereco'] as Map?)?.cast<String, dynamic>() ?? {}),
      pagamento: PagamentoPedido.fromJson(
        (json['pagamento'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      tempoEstimadoMin: (json['tempoEstimadoMin'] as num?)?.toInt(),
      entregadorNome: json['entregadorNome'] as String?,
      motivo: json['motivo'] as String?,
      criadoEm: DateTime.tryParse(json['criadoEm'] as String? ?? '')?.toLocal(),
      avaliacao: json['avaliacao'] is Map
          ? Avaliacao.fromJson((json['avaliacao'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}


class PreviaPedido {
  final bool dentroDaArea;
  final String? mensagem;
  final double subtotal;
  final double taxaEntrega;
  final double total;

  PreviaPedido({
    required this.dentroDaArea,
    required this.mensagem,
    required this.subtotal,
    required this.taxaEntrega,
    required this.total,
  });

  factory PreviaPedido.fromJson(Map<String, dynamic> json) {
    return PreviaPedido(
      dentroDaArea: json['dentroDaArea'] as bool? ?? false,
      mensagem: json['mensagem'] as String?,
      subtotal: (json['subtotal'] as num? ?? 0.0).toDouble(),
      taxaEntrega: (json['taxaEntrega'] as num? ?? 0.0).toDouble(),
      total: (json['total'] as num? ?? 0.0).toDouble(),
    );
  }
}


class ItemIndisponivel {
  final String nome;
  final String motivo;

  ItemIndisponivel({required this.nome, required this.motivo});

  factory ItemIndisponivel.fromJson(Map<String, dynamic> json) {
    return ItemIndisponivel(
      nome: json['nome'] as String? ?? '',
      motivo: json['motivo'] as String? ?? '',
    );
  }
}


class PrecoAlterado {
  final String nome;
  final double de;
  final double para;

  PrecoAlterado({required this.nome, required this.de, required this.para});

  factory PrecoAlterado.fromJson(Map<String, dynamic> json) {
    return PrecoAlterado(
      nome: json['nome'] as String? ?? '',
      de: (json['de'] as num? ?? 0.0).toDouble(),
      para: (json['para'] as num? ?? 0.0).toDouble(),
    );
  }
}


class RepeticaoPedido {
  final int adicionados;
  final List<ItemIndisponivel> indisponiveis;
  final List<PrecoAlterado> precosAlterados;
  final bool lojaAberta;
  final Carrinho carrinho;

  RepeticaoPedido({
    required this.adicionados,
    required this.indisponiveis,
    required this.precosAlterados,
    required this.lojaAberta,
    required this.carrinho,
  });

  factory RepeticaoPedido.fromJson(Map<String, dynamic> json) {
    return RepeticaoPedido(
      adicionados: (json['adicionados'] as num?)?.toInt() ?? 0,
      indisponiveis: (json['indisponiveis'] as List? ?? [])
          .map((e) => ItemIndisponivel.fromJson(e as Map<String, dynamic>))
          .toList(),
      precosAlterados: (json['precosAlterados'] as List? ?? [])
          .map((e) => PrecoAlterado.fromJson(e as Map<String, dynamic>))
          .toList(),
      lojaAberta: json['lojaAberta'] as bool? ?? true,
      carrinho: Carrinho.fromJson(json['carrinho'] as Map<String, dynamic>),
    );
  }
}
