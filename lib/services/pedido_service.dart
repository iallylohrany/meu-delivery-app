import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/avaliacao.dart';
import '../models/pedido.dart';
import 'token_storage.dart';

class PedidoException implements Exception {
  
  final String mensagem;
  final bool tokenInvalido;


  final bool semConexao;

 
  final bool conflito;

  PedidoException(
    this.mensagem, {
    this.tokenInvalido = false,
    this.semConexao = false,
    this.conflito = false,
  });

  @override
  String toString() => mensagem;
}


class PedidoConflitoLojaException implements Exception {
  final String lojaAtualNome;

  PedidoConflitoLojaException(this.lojaAtualNome);
}

class PedidoService {
  PedidoService._();

  static Future<Map<String, String>> _cabecalhos() async {
    final token = await TokenStorage.obterToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Never _erroConexao() {
    throw PedidoException(
      'Não foi possível conectar. Verifique sua conexão.',
      semConexao: true,
    );
  }

  static Future<void> _tratarStatus(http.Response resposta) async {
    if (resposta.statusCode == 401) {
      await TokenStorage.limparToken();
      throw PedidoException('Sua sessão expirou.', tokenInvalido: true);
    }
  }

  static String _mensagemDoCorpo(http.Response resposta, String padrao) {
    try {
      final corpo = jsonDecode(resposta.body);
      if (corpo is Map && corpo['error'] is String) {
        return corpo['error'] as String;
      }
    } catch (_) {}
    return padrao;
  }


  static Future<PreviaPedido> previa(String enderecoId) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.pedidoPreviaPath}');

    http.Response resposta;
    try {
      resposta = await http
          .post(
            uri,
            headers: await _cabecalhos(),
            body: jsonEncode({'enderecoId': enderecoId}),
          )
          .timeout(AppConfig.apiTimeout);
    } catch (_) {
      _erroConexao();
    }

    await _tratarStatus(resposta);

    if (resposta.statusCode != 200) {
      throw PedidoException(
        _mensagemDoCorpo(resposta, 'Não foi possível calcular a entrega.'),
      );
    }

    return PreviaPedido.fromJson(jsonDecode(resposta.body) as Map<String, dynamic>);
  }


  static Future<Pedido> criar({
    required String enderecoId,
    required String formaPagamento,
    double? trocoPara,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.pedidosPath}');

    http.Response resposta;
    try {
      resposta = await http
          .post(
            uri,
            headers: await _cabecalhos(),
            body: jsonEncode({
              'enderecoId': enderecoId,
              'pagamento': {
                'forma': formaPagamento,
                if (trocoPara != null) 'trocoPara': trocoPara,
              },
            }),
          )
          .timeout(AppConfig.apiTimeout);
    } catch (_) {
      _erroConexao();
    }

    await _tratarStatus(resposta);

    if (resposta.statusCode != 200 && resposta.statusCode != 201) {
      throw PedidoException(
        _mensagemDoCorpo(resposta, 'O pedido não pôde ser criado.'),
      );
    }

    return Pedido.fromJson(jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  static Future<Pedido> buscar(String pedidoId) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.pedidoPath(pedidoId)}');

    http.Response resposta;
    try {
      resposta = await http
          .get(uri, headers: await _cabecalhos())
          .timeout(AppConfig.apiTimeout);
    } catch (_) {
      _erroConexao();
    }

    await _tratarStatus(resposta);

    if (resposta.statusCode != 200) {
      throw PedidoException(
        _mensagemDoCorpo(resposta, 'Não foi possível carregar o pedido.'),
      );
    }

    return Pedido.fromJson(jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  static Future<List<Pedido>> listar() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.pedidosPath}');

    http.Response resposta;
    try {
      resposta = await http
          .get(uri, headers: await _cabecalhos())
          .timeout(AppConfig.apiTimeout);
    } catch (_) {
      _erroConexao();
    }

    await _tratarStatus(resposta);

    if (resposta.statusCode != 200) {
      throw PedidoException(
        _mensagemDoCorpo(resposta, 'Não foi possível carregar seus pedidos.'),
      );
    }

    final corpo = jsonDecode(resposta.body);
    final lista = corpo is List ? corpo : (corpo['pedidos'] as List? ?? []);
    return lista
        .map((e) => Pedido.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Pedido> cancelar(String pedidoId) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}${AppConfig.pedidoCancelarPath(pedidoId)}',
    );

    http.Response resposta;
    try {
      resposta = await http
          .post(uri, headers: await _cabecalhos())
          .timeout(AppConfig.apiTimeout);
    } catch (_) {
      _erroConexao();
    }

    await _tratarStatus(resposta);

    if (resposta.statusCode != 200) {
      throw PedidoException(
        _mensagemDoCorpo(resposta, 'Não foi possível cancelar o pedido.'),
      );
    }

    return Pedido.fromJson(jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  
  static Future<RepeticaoPedido> repetir(
    String pedidoId, {
    bool substituir = false,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}${AppConfig.pedidoRepetirPath(pedidoId)}',
    );

    http.Response resposta;
    try {
      resposta = await http
          .post(
            uri,
            headers: await _cabecalhos(),
            body: jsonEncode({'substituir': substituir}),
          )
          .timeout(AppConfig.apiTimeout);
    } catch (_) {
      _erroConexao();
    }

    await _tratarStatus(resposta);

    if (resposta.statusCode == 409) {
      String lojaAtual = 'outra loja';
      try {
        final corpo = jsonDecode(resposta.body);
        if (corpo is Map && corpo['lojaAtualNome'] is String) {
          lojaAtual = corpo['lojaAtualNome'] as String;
        }
      } catch (_) {}
      throw PedidoConflitoLojaException(lojaAtual);
    }

    if (resposta.statusCode != 200) {
      throw PedidoException(
        _mensagemDoCorpo(resposta, 'Não foi possível repetir o pedido.'),
      );
    }

    return RepeticaoPedido.fromJson(
      jsonDecode(resposta.body) as Map<String, dynamic>,
    );
  }

 
  static Future<Avaliacao> avaliar(
    String pedidoId, {
    required int notaLoja,
    int? notaEntregador,
    String comentario = '',
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}${AppConfig.pedidoAvaliacaoPath(pedidoId)}',
    );

    http.Response resposta;
    try {
      resposta = await http
          .post(
            uri,
            headers: await _cabecalhos(),
            body: jsonEncode({
              'notaLoja': notaLoja,
              if (notaEntregador != null) 'notaEntregador': notaEntregador,
              'comentario': comentario,
            }),
          )
          .timeout(AppConfig.apiTimeout);
    } catch (_) {
      _erroConexao();
    }

    await _tratarStatus(resposta);

    if (resposta.statusCode != 200 && resposta.statusCode != 201) {
      throw PedidoException(
        _mensagemDoCorpo(resposta, 'Não foi possível enviar a avaliação.'),
        conflito: resposta.statusCode == 409,
      );
    }

    return Avaliacao.fromJson(jsonDecode(resposta.body) as Map<String, dynamic>);
  }
}
