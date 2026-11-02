import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/entrega.dart';
import '../models/oferta.dart';

class EntregadorException implements Exception {
  final String mensagem;
  final bool semConexao;


  final bool ofertaIndisponivel;

  EntregadorException(
    this.mensagem, {
    this.semConexao = false,
    this.ofertaIndisponivel = false,
  });

  @override
  String toString() => mensagem;
}


class EntregadorService {
  EntregadorService._();

  static const _cabecalhos = {'Content-Type': 'application/json'};

  static Never _erroConexao() {
    throw EntregadorException(
      'Não foi possível conectar. Verifique sua conexão.',
      semConexao: true,
    );
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


  static Future<bool> buscarDisponibilidade() async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}${AppConfig.entregadorDisponibilidadePath()}',
    );

    http.Response resposta;
    try {
      resposta = await http.get(uri, headers: _cabecalhos).timeout(AppConfig.apiTimeout);
    } catch (_) {
      _erroConexao();
    }

    if (resposta.statusCode != 200) {
      throw EntregadorException(
        _mensagemDoCorpo(resposta, 'Não foi possível carregar sua situação.'),
      );
    }

    final corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
    return corpo['online'] as bool? ?? false;
  }

  static Future<bool> definirDisponibilidade(bool online) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}${AppConfig.entregadorDisponibilidadePath()}',
    );

    http.Response resposta;
    try {
      resposta = await http
          .put(uri, headers: _cabecalhos, body: jsonEncode({'online': online}))
          .timeout(AppConfig.apiTimeout);
    } catch (_) {
      _erroConexao();
    }

    if (resposta.statusCode != 200) {
      throw EntregadorException(
        _mensagemDoCorpo(resposta, 'Não foi possível alterar sua situação.'),
      );
    }

    final corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
    return corpo['online'] as bool? ?? online;
  }


  static Future<RespostaOferta> buscarOferta({String? atualId}) async {
    final base = '${AppConfig.apiBaseUrl}${AppConfig.entregadorOfertaPath()}';
    final uri = Uri.parse(
      atualId != null ? '$base?atual=${Uri.encodeQueryComponent(atualId)}' : base,
    );

    http.Response resposta;
    try {
      resposta = await http.get(uri, headers: _cabecalhos).timeout(AppConfig.apiTimeout);
    } catch (_) {
      _erroConexao();
    }

    if (resposta.statusCode != 200) {
      throw EntregadorException(
        _mensagemDoCorpo(resposta, 'Não foi possível buscar ofertas.'),
      );
    }

    return RespostaOferta.fromJson(jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  static bool _ofertaNaoVale(int status) => status == 404 || status == 409 || status == 410;

  static Future<Entrega> aceitar(String ofertaId) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}${AppConfig.entregadorOfertaAceitarPath(ofertaId)}',
    );

    http.Response resposta;
    try {
      resposta = await http.post(uri, headers: _cabecalhos).timeout(AppConfig.apiTimeout);
    } catch (_) {
      _erroConexao();
    }

    if (resposta.statusCode != 200) {
      throw EntregadorException(
        _mensagemDoCorpo(resposta, 'Não foi possível aceitar a oferta.'),
        ofertaIndisponivel: _ofertaNaoVale(resposta.statusCode),
      );
    }

    return Entrega.fromJson(jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  static Future<void> recusar(String ofertaId) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}${AppConfig.entregadorOfertaRecusarPath(ofertaId)}',
    );

    http.Response resposta;
    try {
      resposta = await http.post(uri, headers: _cabecalhos).timeout(AppConfig.apiTimeout);
    } catch (_) {
      _erroConexao();
    }

    if (resposta.statusCode != 200) {
      throw EntregadorException(
        _mensagemDoCorpo(resposta, 'Não foi possível recusar a oferta.'),
        ofertaIndisponivel: _ofertaNaoVale(resposta.statusCode),
      );
    }
  }


  static Future<dynamic> _chamar(
    String metodo,
    String caminho, {
    Map<String, dynamic>? corpo,
    required String mensagemPadrao,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$caminho');

    http.Response resposta;
    try {
      resposta = metodo == 'GET'
          ? await http.get(uri, headers: _cabecalhos).timeout(AppConfig.apiTimeout)
          : await http
              .post(
                uri,
                headers: _cabecalhos,
                body: corpo != null ? jsonEncode(corpo) : null,
              )
              .timeout(AppConfig.apiTimeout);
    } catch (_) {
      _erroConexao();
    }

    if (resposta.statusCode != 200) {
      throw EntregadorException(_mensagemDoCorpo(resposta, mensagemPadrao));
    }

    return jsonDecode(resposta.body);
  }

 
  static Future<List<Entrega>> listarAtivas() async {
    final corpo = await _chamar(
      'GET',
      '${AppConfig.entregadorEntregasPath()}?status=ativas',
      mensagemPadrao: 'Não foi possível carregar sua entrega.',
    );
    return (corpo as List)
        .map((e) => Entrega.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Entrega> buscarEntrega(String entregaId) async {
    final corpo = await _chamar(
      'GET',
      AppConfig.entregadorEntregaPath(entregaId),
      mensagemPadrao: 'Não foi possível carregar a entrega.',
    );
    return Entrega.fromJson(corpo as Map<String, dynamic>);
  }


  static Future<Entrega> confirmarColeta(String entregaId) async {
    final corpo = await _chamar(
      'POST',
      '${AppConfig.entregadorEntregaPath(entregaId)}/coleta',
      mensagemPadrao: 'Não foi possível confirmar a coleta.',
    );
    return Entrega.fromJson(corpo as Map<String, dynamic>);
  }


  static Future<Entrega> confirmarEntrega(String entregaId) async {
    final corpo = await _chamar(
      'POST',
      '${AppConfig.entregadorEntregaPath(entregaId)}/entrega',
      mensagemPadrao: 'Não foi possível confirmar a entrega.',
    );
    return Entrega.fromJson(corpo as Map<String, dynamic>);
  }

  
  static Future<Entrega> registrarInsucesso(String entregaId, String motivo) async {
    final corpo = await _chamar(
      'POST',
      '${AppConfig.entregadorEntregaPath(entregaId)}/insucesso',
      corpo: {'motivo': motivo},
      mensagemPadrao: 'Não foi possível registrar o insucesso.',
    );
    return Entrega.fromJson(corpo as Map<String, dynamic>);
  }


  static Future<GanhosDoDia> buscarGanhos() async {
    final corpo = await _chamar(
      'GET',
      AppConfig.entregadorGanhosPath(),
      mensagemPadrao: 'Não foi possível carregar seus ganhos.',
    );
    return GanhosDoDia.fromJson(corpo as Map<String, dynamic>);
  }
}
