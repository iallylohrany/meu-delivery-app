class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const String healthCheckPath = '/health';


  static const String authLoginPath = '/auth/login';
  static const String authRegisterPath = '/auth/cadastro';
  static const String authMePath = '/auth/me';


  static String cardapioPath(dynamic lojaId) => '/lojas/$lojaId/cardapio';
  static const String lojasPath = '/lojas';
  static const String categoriasPath = '/categorias';
  

  static const String enderecosPath = '/enderecos';
  static String enderecoPath(String enderecoId) => '/enderecos/$enderecoId';
  static String enderecoFavoritoPath(String enderecoId) =>
      '/enderecos/$enderecoId/favorito';


  static const String carrinhoPath = '/carrinho';
  static const String carrinhoItensPath = '/carrinho/itens';
  static String carrinhoItemPath(dynamic itemId) => '/carrinho/itens/$itemId';

  static const String pedidosPath = '/pedidos';
  static const String pedidoPreviaPath = '/pedidos/previa';
  static String pedidoPath(String pedidoId) => '/pedidos/$pedidoId';
  static String pedidoCancelarPath(String pedidoId) =>
      '/pedidos/$pedidoId/cancelar';

  static String pedidoRepetirPath(String pedidoId) =>
      '/pedidos/$pedidoId/repetir';

  
  static const String entregadorId = String.fromEnvironment(
    'ENTREGADOR_ID',
    defaultValue: 'e1',
  );
  static String entregadorDisponibilidadePath() =>
      '/entregadores/$entregadorId/disponibilidade';
  static String entregadorOfertaPath() => '/entregadores/$entregadorId/oferta';
  static String entregadorOfertaAceitarPath(String ofertaId) =>
      '/entregadores/$entregadorId/ofertas/$ofertaId/aceitar';
  static String entregadorOfertaRecusarPath(String ofertaId) =>
      '/entregadores/$entregadorId/ofertas/$ofertaId/recusar';

  static String pedidoAvaliacaoPath(String pedidoId) =>
      '/pedidos/$pedidoId/avaliacao';

  static String entregadorEntregasPath() => '/entregadores/$entregadorId/entregas';
  static String entregadorEntregaPath(String entregaId) =>
      '/entregadores/$entregadorId/entregas/$entregaId';
  static String entregadorGanhosPath() => '/entregadores/$entregadorId/ganhos';

  static const Duration apiTimeout = Duration(seconds: 5);
}