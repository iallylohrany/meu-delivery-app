import 'package:flutter/material.dart';
import '../../models/carrinho.dart';
import '../../models/endereco.dart';
import '../../models/pedido.dart';
import '../../services/carrinho_service.dart';
import '../../services/endereco_service.dart';
import '../../services/pedido_service.dart';
import 'endereco_form_screen.dart';
import 'pedido_acompanhamento_screen.dart';

String _moeda(double valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';


class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _carregando = true;
  String? _erroCarga;
  Carrinho _carrinho = Carrinho.vazio();
  List<Endereco> _enderecos = [];
  String? _enderecoId;

  PreviaPedido? _previa;
  bool _calculandoPrevia = false;
  String? _erroPrevia;
  int _versaoPrevia = 0;

  String? _forma;
  bool _semTroco = false;
  final _trocoController = TextEditingController();

  bool _enviando = false;

 
  String? _recusa;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _trocoController.dispose();
    super.dispose();
  }

  Endereco? get _enderecoSelecionado {
    for (final e in _enderecos) {
      if (e.id == _enderecoId) return e;
    }
    return null;
  }

  
  String? _idPadrao(List<Endereco> enderecos) {
    if (enderecos.isEmpty) return null;
    for (final e in enderecos) {
      if (e.favorito) return e.id;
    }
    return enderecos.first.id;
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erroCarga = null;
    });

    try {
      final carrinho = await CarrinhoService.buscarCarrinho();
      final enderecos = await EnderecoService.listarEnderecos();
      if (!mounted) return;
      setState(() {
        _carrinho = carrinho;
        _enderecos = enderecos;
        _enderecoId = _idPadrao(enderecos);
        _carregando = false;
      });
      _atualizarPrevia();
    } on CarrinhoException catch (e) {
      _falhaDeCarga(e.mensagem);
    } on EnderecoException catch (e) {
      _falhaDeCarga(e.mensagem);
    }
  }

  void _falhaDeCarga(String mensagem) {
    if (!mounted) return;
    setState(() {
      _erroCarga = mensagem;
      _carregando = false;
    });
  }

  Future<void> _atualizarPrevia() async {
    final id = _enderecoId;
    if (id == null || _carrinho.estaVazio) {
      setState(() {
        _previa = null;
        _erroPrevia = null;
        _calculandoPrevia = false;
      });
      return;
    }

    final versao = ++_versaoPrevia;
    setState(() {
      _previa = null;
      _erroPrevia = null;
      _recusa = null;
      _calculandoPrevia = true;
    });

    try {
      final previa = await PedidoService.previa(id);
      if (!mounted || versao != _versaoPrevia) return;
      setState(() {
        _previa = previa;
        _calculandoPrevia = false;
      });
    } on PedidoException catch (e) {
      if (!mounted || versao != _versaoPrevia) return;
      setState(() {
        _erroPrevia = e.mensagem;
        _calculandoPrevia = false;
      });
    }
  }

  Future<void> _escolherEndereco() async {
    final escolhido = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Escolha o endereço de entrega',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            for (final e in _enderecos)
              ListTile(
                leading: Icon(
                  e.favorito ? Icons.star : Icons.location_on_outlined,
                  color: e.favorito ? Colors.amber.shade700 : Colors.grey,
                ),
                title: Text(e.resumo),
                subtitle: Text(e.resumoBairroCidade),
                trailing: e.id == _enderecoId
                    ? Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, e.id),
              ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Cadastrar novo endereço'),
              onTap: () => Navigator.pop(ctx, '__novo__'),
            ),
          ],
        ),
      ),
    );

    if (escolhido == null) return;

    if (escolhido == '__novo__') {
      await _cadastrarEndereco();
      return;
    }

    if (escolhido != _enderecoId) {
      setState(() => _enderecoId = escolhido);
      _atualizarPrevia();
    }
  }

  Future<void> _cadastrarEndereco() async {
    final criado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EnderecoFormScreen()),
    );
    if (criado != true || !mounted) return;

    try {
      final enderecos = await EnderecoService.listarEnderecos();
      if (!mounted) return;
      setState(() {
        _enderecos = enderecos;
        // O endereço recém-cadastrado é o último da lista.
        _enderecoId = enderecos.isNotEmpty ? enderecos.last.id : null;
      });
      _atualizarPrevia();
    } on EnderecoException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  double? get _trocoDigitado =>
      double.tryParse(_trocoController.text.trim().replaceAll(',', '.'));

  bool get _precisaDeTroco => _forma == 'dinheiro' && !_semTroco;

  bool get _trocoValido {
    if (!_precisaDeTroco) return true;
    final valor = _trocoDigitado;
    final previa = _previa;
    if (valor == null || previa == null) return false;
    return valor >= previa.total;
  }

  bool get _podeConfirmar {
    final previa = _previa;
    return !_enviando &&
        !_carrinho.estaVazio &&
        _enderecoId != null &&
        previa != null &&
        previa.dentroDaArea &&
        _forma != null &&
        _trocoValido;
  }

  Future<void> _confirmar() async {
    setState(() {
      _enviando = true;
      _recusa = null;
    });

    try {
      final pedido = await PedidoService.criar(
        enderecoId: _enderecoId!,
        formaPagamento: _forma!,
        trocoPara: _precisaDeTroco ? _trocoDigitado : null,
      );
      if (!mounted) return;
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PedidoAcompanhamentoScreen(
            pedidoId: pedido.id,
            pedidoInicial: pedido,
          ),
        ),
        (rota) => rota.isFirst,
      );
    } on PedidoException catch (e) {
      if (!mounted) return;
      
      setState(() {
        _enviando = false;
        _recusa = e.mensagem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fechar pedido')),
      body: _corpo(),
      bottomNavigationBar: _rodape(),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erroCarga != null) {
      return _MensagemCentral(
        icone: Icons.cloud_off,
        titulo: 'Não foi possível carregar',
        descricao: _erroCarga!,
        textoBotao: 'Tentar novamente',
        aoClicar: _carregar,
      );
    }

    if (_carrinho.estaVazio) {
      return const _MensagemCentral(
        icone: Icons.shopping_cart_outlined,
        titulo: 'Seu carrinho está vazio',
        descricao: 'Adicione produtos para fechar um pedido.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _secaoTitulo('Resumo do pedido'),
        _cartaoResumo(),
        const SizedBox(height: 20),
        _secaoTitulo('Endereço de entrega'),
        _cartaoEndereco(),
        const SizedBox(height: 20),
        _secaoTitulo('Pagamento'),
        _opcaoPagamento('pix', Icons.pix),
        _opcaoPagamento('cartao_entrega', Icons.credit_card),
        _opcaoPagamento('dinheiro', Icons.payments_outlined),
        if (_forma == 'dinheiro') _campoTroco(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _secaoTitulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          texto,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );

  Widget _cartaoResumo() {
    final previa = _previa;

    String taxaTexto;
    String totalTexto;
    if (previa == null) {
      taxaTexto = _calculandoPrevia ? 'calculando...' : '—';
      totalTexto = _calculandoPrevia ? 'calculando...' : '—';
    } else if (!previa.dentroDaArea) {
      taxaTexto = 'fora da área';
      totalTexto = '—';
    } else {
      taxaTexto = _moeda(previa.taxaEntrega);
      totalTexto = _moeda(previa.total);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _carrinho.lojaNome ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            for (final item in _carrinho.itens)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.quantidade}x ${item.produto.nome}'),
                          if (item.complementos.isNotEmpty)
                            Text(
                              item.complementos.map((c) => c.nome).join(', '),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          if (item.observacao.trim().isNotEmpty)
                            Text(
                              'Obs: ${item.observacao}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_moeda(item.precoItem)),
                  ],
                ),
              ),
            const Divider(height: 20),
            _linha('Subtotal', _moeda(_carrinho.subtotal)),
            _linha('Taxa de entrega', taxaTexto),
            const SizedBox(height: 4),
            _linha('Total', totalTexto, destaque: true),
          ],
        ),
      ),
    );
  }

  Widget _linha(String rotulo, String valor, {bool destaque = false}) {
    final estilo = destaque
        ? const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)
        : TextStyle(color: Colors.grey.shade700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(rotulo, style: estilo), Text(valor, style: estilo)],
      ),
    );
  }

  Widget _cartaoEndereco() {
    final endereco = _enderecoSelecionado;

    if (endereco == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Você ainda não tem endereço cadastrado.'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _cadastrarEndereco,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Cadastrar endereço'),
              ),
            ],
          ),
        ),
      );
    }

    final previa = _previa;
    final foraDaArea = previa != null && !previa.dentroDaArea;

    return Card(
      margin: EdgeInsets.zero,
      shape: foraDaArea
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.red),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  endereco.favorito ? Icons.star : Icons.location_on_outlined,
                  color: endereco.favorito ? Colors.amber.shade700 : Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        endereco.resumo,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (endereco.resumoBairroCidade.isNotEmpty)
                        Text(endereco.resumoBairroCidade),
                      if (endereco.pontoReferencia.trim().isNotEmpty)
                        Text(
                          'Ref: ${endereco.pontoReferencia}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _enviando ? null : _escolherEndereco,
                  child: const Text('Trocar'),
                ),
              ],
            ),
            if (_calculandoPrevia)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Conferindo a área de entrega...'),
                  ],
                ),
              ),
            if (_erroPrevia != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _erroPrevia!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    TextButton(
                      onPressed: _atualizarPrevia,
                      child: const Text('Tentar de novo'),
                    ),
                  ],
                ),
              ),
            if (foraDaArea)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        previa?.mensagem ?? 'Este endereço está fora da área de entrega.',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _opcaoPagamento(String forma, IconData icone) {
    final selecionado = _forma == forma;
    final cor = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selecionado ? cor : Colors.grey.shade300,
          width: selecionado ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icone, color: selecionado ? cor : Colors.grey),
        title: Text(
          PagamentoPedido.rotuloDaForma(forma),
          style: TextStyle(fontWeight: selecionado ? FontWeight.bold : FontWeight.normal),
        ),
        trailing: selecionado
            ? Icon(Icons.check_circle, color: cor)
            : const Icon(Icons.circle_outlined, color: Colors.grey),
        onTap: _enviando
            ? null
            : () => setState(() {
                  _forma = forma;
                  _recusa = null;
                }),
      ),
    );
  }

  Widget _campoTroco() {
    final previa = _previa;
    String? erro;
    if (!_semTroco && _trocoController.text.trim().isNotEmpty && previa != null) {
      final valor = _trocoDigitado;
      if (valor == null || valor < previa.total) {
        erro = 'O valor precisa ser maior ou igual ao total (${_moeda(previa.total)}).';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Não preciso de troco'),
            value: _semTroco,
            onChanged: _enviando ? null : (v) => setState(() => _semTroco = v ?? false),
          ),
          if (!_semTroco)
            TextField(
              controller: _trocoController,
              enabled: !_enviando,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Troco para quanto?',
                prefixText: 'R\$ ',
                border: const OutlineInputBorder(),
                errorText: erro,
              ),
            ),
        ],
      ),
    );
  }

  Widget? _rodape() {
    if (_carregando || _erroCarga != null || _carrinho.estaVazio) return null;

    final previa = _previa;
    final textoBotao = (previa != null && previa.dentroDaArea)
        ? 'Confirmar pedido • ${_moeda(previa.total)}'
        : 'Confirmar pedido';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_recusa != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _recusa!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _podeConfirmar ? _confirmar : null,
                child: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(textoBotao),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MensagemCentral extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;
  final String? textoBotao;
  final VoidCallback? aoClicar;

  const _MensagemCentral({
    required this.icone,
    required this.titulo,
    required this.descricao,
    this.textoBotao,
    this.aoClicar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              descricao,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (textoBotao != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: aoClicar,
                icon: const Icon(Icons.refresh),
                label: Text(textoBotao!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
