// Para rodar:
//   node mock_server.js
//
// Rotas disponíveis:
//   GET  /health
//   POST /auth/cadastro          { nome, email, telefone, senha }
//   POST /auth/login             { email, senha }
//   GET  /auth/me                (com header Authorization: Bearer <token>)
//   POST /auth/invalidar-tokens
//   GET  /lojas                  ?busca= &categoria=
//   GET  /categorias
//   GET  /lojas/:id/cardapio
//   POST /admin/lista-vazia      (liga/desliga lista vazia)
//
//   -- Endereços (autenticado) --
//   GET    /enderecos
//   POST   /enderecos            { rua, numero, complemento, bairro, cidade, pontoReferencia, favorito }
//   PUT    /enderecos/:id
//   DELETE /enderecos/:id
//   POST   /enderecos/:id/favorito
//
//   -- Carrinho (autenticado, de uma loja por vez) --
//   GET    /carrinho
//   POST   /carrinho/itens       { lojaId, produtoId, quantidade, complementos, observacao, substituir }
//   PUT    /carrinho/itens/:id   { quantidade?, complementos?, observacao? }
//   DELETE /carrinho/itens/:id
//
//   -- Pedidos (autenticado) --
//   POST   /pedidos/previa       { enderecoId }  -> área de entrega, taxa da faixa e total
//   POST   /pedidos              { enderecoId, pagamento: { forma, trocoPara? } }  (422 = recusa da loja)
//   GET    /pedidos              (do cliente)
//   GET    /pedidos/:id
//   POST   /pedidos/:id/cancelar (só enquanto aguardando confirmação)
//
//   -- Simulam a loja (sem auth, só para testar) --
//   GET    /painel/pedidos       ?lojaId=
//   POST   /admin/pedidos/:id/status   { status, tempoEstimadoMin?, entregadorNome?, motivo? }
//   POST   /admin/lojas/:id/aberta     { aberta }
//   POST   /admin/produtos/:id/disponivel { disponivel }
//   POST   /admin/produtos/:id/preco      { precoBase }
//
//   -- Repetir pedido (autenticado) --
//   POST   /pedidos/:id/repetir  { substituir? } -> itens de volta ao carrinho, com os preços de hoje
//
//   -- Entregador (ainda sem login: o mock tem o entregador "e1") --
//   GET    /entregadores/:id/disponibilidade
//   PUT    /entregadores/:id/disponibilidade   { online }
//   GET    /entregadores/:id/oferta            ?atual=ID  (oferta pendente, se online)
//   POST   /entregadores/:id/ofertas/:oid/aceitar
//   POST   /entregadores/:id/ofertas/:oid/recusar
//   POST   /admin/ofertas                      { pedidoId?, prazoSegundos?, valor?, distanciaKm?, origem?, destino? }
//   POST   /admin/ofertas/:id/repassar
//
//   -- Entregas do entregador (cada um só enxerga e mexe nas suas; os entregadores do mock: e1, e2) --
//   GET    /entregadores/:id/entregas          ?status=ativas
//   GET    /entregadores/:id/entregas/:eid
//   POST   /entregadores/:id/entregas/:eid/coleta
//   POST   /entregadores/:id/entregas/:eid/entrega
//   POST   /entregadores/:id/entregas/:eid/insucesso   { motivo }
//   GET    /entregadores/:id/ganhos            ?data=AAAA-MM-DD (padrão: hoje)
//
//   -- Avaliação (autenticado) --
//   POST   /pedidos/:id/avaliacao  { notaLoja, notaEntregador?, comentario? }  (só pedido entregue, uma por pedido)

const http = require('http');
const { URL } = require('url');

const PORT = 3000;

const usuarios = []; // { nome, email, telefone, senha }
const sessoes = new Map(); // token -> email

let forcarListaVazia = false;

const mockLojas = [
  {
    id: '1',
    nome: 'Burguer King da Praça',
    categoria: 'Hambúrgueres',
    fotoUrl: 'https://picsum.photos/seed/bk/150',
    tempoEstimadoMin: 35,
    taxaEntrega: 5.9,
    aberta: true,
  },
  {
    id: '2',
    nome: 'Pizza Express',
    categoria: 'Pizzas',
    fotoUrl: 'https://picsum.photos/seed/pizza/150',
    tempoEstimadoMin: 45,
    taxaEntrega: 7.5,
    aberta: true,
  },
  {
    id: '3',
    nome: 'Sushi House',
    categoria: 'Japonesa',
    fotoUrl: 'https://picsum.photos/seed/sushi/150',
    tempoEstimadoMin: 50,
    taxaEntrega: 9.0,
    aberta: false,
  },
  {
    id: '4',
    nome: 'Açaí do Parque',
    categoria: 'Açaí',
    fotoUrl: 'https://picsum.photos/seed/acai/150',
    tempoEstimadoMin: 25,
    taxaEntrega: 0,
    aberta: true,
  },
];

const mockCardapios = {
  '1': [
    {
      id: 'cat_burgers',
      nome: 'Hambúrgueres',
      produtos: [
        {
          id: 'p1',
          nome: 'X-Burguer Artesanal',
          descricao:
            'Pão brioche, carne 180g, queijo cheddar e molho especial.',
          precoBase: 25.0,
          fotoUrl: 'https://picsum.photos/seed/xb/150',
          disponivel: true,
          gruposComplemento: [
            {
              id: 'g_ponto',
              titulo: 'Ponto da carne',
              minQtd: 1,
              maxQtd: 1,
              opcoes: [
                { id: 'op1', nome: 'Ao Ponto', preco: 0.0 },
                { id: 'op2', nome: 'Bem Passado', preco: 0.0 },
              ],
            },
            {
              id: 'g_extras',
              titulo: 'Adicionais',
              minQtd: 0,
              maxQtd: 2,
              opcoes: [
                { id: 'op3', nome: 'Bacon Extra', preco: 4.5 },
                { id: 'op4', nome: 'Queijo Extra', preco: 3.0 },
                { id: 'op5', nome: 'Cebola Caramelizada', preco: 2.5 },
              ],
            },
          ],
        },
        {
          id: 'p2',
          nome: 'X-Salada Especial',
          descricao: 'Produto temporariamente esgotado.',
          precoBase: 22.0,
          fotoUrl: null,
          disponivel: false,
          gruposComplemento: [],
        },
        {
          id: 'p4',
          nome: 'Duplo Cheddar Bacon',
          descricao: 'Dois burgers, cheddar, bacon crocante e molho da casa.',
          precoBase: 32.9,
          fotoUrl: 'https://picsum.photos/seed/duplo/150',
          disponivel: true,
          gruposComplemento: [
            {
              id: 'g_ponto2',
              titulo: 'Ponto da carne',
              minQtd: 1,
              maxQtd: 1,
              opcoes: [
                { id: 'op1b', nome: 'Ao Ponto', preco: 0.0 },
                { id: 'op2b', nome: 'Mal Passado', preco: 0.0 },
              ],
            },
          ],
        },
      ],
    },
    {
      id: 'cat_bebidas',
      nome: 'Bebidas',
      produtos: [
        {
          id: 'p3',
          nome: 'Refrigerante Lata 350ml',
          descricao: 'Coca-Cola ou Guaraná Antarctica.',
          precoBase: 6.0,
          fotoUrl: null,
          disponivel: true,
          gruposComplemento: [
            {
              id: 'g_sabor',
              titulo: 'Sabor',
              minQtd: 1,
              maxQtd: 1,
              opcoes: [
                { id: 'op6', nome: 'Coca-Cola', preco: 0.0 },
                { id: 'op7', nome: 'Guaraná', preco: 0.0 },
                { id: 'op8', nome: 'Sprite', preco: 0.0 },
              ],
            },
          ],
        },
      ],
    },
  ],
  '2': [
    {
      id: 'cat_pizzas',
      nome: 'Pizzas',
      produtos: [
        {
          id: 'pz1',
          nome: 'Margherita',
          descricao: 'Molho de tomate, mussarela e manjericão.',
          precoBase: 39.9,
          fotoUrl: 'https://picsum.photos/seed/marg/150',
          disponivel: true,
          gruposComplemento: [
            {
              id: 'g_tamanho',
              titulo: 'Tamanho',
              minQtd: 1,
              maxQtd: 1,
              opcoes: [
                { id: 't1', nome: 'Média (30cm)', preco: 0.0 },
                { id: 't2', nome: 'Grande (35cm)', preco: 12.0 },
              ],
            },
            {
              id: 'g_borda',
              titulo: 'Borda',
              minQtd: 0,
              maxQtd: 1,
              opcoes: [
                { id: 'b1', nome: 'Catupiry', preco: 8.0 },
                { id: 'b2', nome: 'Cheddar', preco: 8.0 },
              ],
            },
          ],
        },
        {
          id: 'pz2',
          nome: 'Calabresa',
          descricao: 'Calabresa fatiada, cebola e orégano.',
          precoBase: 42.0,
          fotoUrl: null,
          disponivel: true,
          gruposComplemento: [
            {
              id: 'g_tamanho2',
              titulo: 'Tamanho',
              minQtd: 1,
              maxQtd: 1,
              opcoes: [
                { id: 't3', nome: 'Média (30cm)', preco: 0.0 },
                { id: 't4', nome: 'Grande (35cm)', preco: 12.0 },
              ],
            },
          ],
        },
      ],
    },
  ],
  '4': [
    {
      id: 'cat_acai',
      nome: 'Açaí',
      produtos: [
        {
          id: 'a1',
          nome: 'Açaí 500ml',
          descricao: 'Açaí puro batido na hora.',
          precoBase: 18.0,
          fotoUrl: 'https://picsum.photos/seed/acai1/150',
          disponivel: true,
          gruposComplemento: [
            {
              id: 'g_top',
              titulo: 'Toppings',
              minQtd: 0,
              maxQtd: 3,
              opcoes: [
                { id: 'tp1', nome: 'Granola', preco: 2.0 },
                { id: 'tp2', nome: 'Banana', preco: 2.5 },
                { id: 'tp3', nome: 'Leite condensado', preco: 3.0 },
                { id: 'tp4', nome: 'Paçoca', preco: 2.0 },
              ],
            },
          ],
        },
      ],
    },
  ],
};

// --- Endereços e Carrinho: dados por usuário (por e-mail da sessão) ---
const enderecosPorUsuario = new Map(); // email -> [endereco]
const carrinhosPorUsuario = new Map(); // email -> { lojaId, lojaNome, itens: [] }

let proximoEnderecoId = 1;
let proximoItemCarrinhoId = 1;

function round2(n) {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

function autenticarEmail(req) {
  const auth = req.headers['authorization'] || '';
  const token = auth.replace('Bearer ', '').trim();
  return sessoes.get(token) || null;
}

function enderecosDoUsuario(email) {
  if (!enderecosPorUsuario.has(email)) enderecosPorUsuario.set(email, []);
  return enderecosPorUsuario.get(email);
}

function carrinhoDoUsuario(email) {
  if (!carrinhosPorUsuario.has(email)) {
    carrinhosPorUsuario.set(email, { lojaId: null, lojaNome: null, itens: [] });
  }
  return carrinhosPorUsuario.get(email);
}

function encontrarProduto(lojaId, produtoId) {
  const categorias = mockCardapios[lojaId] || [];
  for (const cat of categorias) {
    const produto = cat.produtos.find((p) => p.id === produtoId);
    if (produto) return produto;
  }
  return null;
}

// Confere as opções escolhidas contra o cardápio de verdade (nunca confia
// só no que o app mandou) e valida min/max de cada grupo.
function resolverComplementos(produto, complementosBrutos) {
  const escolhidos = Array.isArray(complementosBrutos) ? complementosBrutos : [];
  const porGrupo = new Map();

  for (const escolha of escolhidos) {
    const grupo = produto.gruposComplemento.find((g) => g.id === escolha.grupoId);
    if (!grupo) throw new Error('Grupo de complemento inválido.');
    const opcao = grupo.opcoes.find((o) => o.id === escolha.opcaoId);
    if (!opcao) throw new Error('Opção de complemento inválida.');

    if (!porGrupo.has(grupo.id)) porGrupo.set(grupo.id, []);
    porGrupo.get(grupo.id).push({
      grupoId: grupo.id,
      opcaoId: opcao.id,
      nome: opcao.nome,
      preco: opcao.preco,
    });
  }

  for (const grupo of produto.gruposComplemento) {
    const qtd = (porGrupo.get(grupo.id) || []).length;
    if (qtd < grupo.minQtd || qtd > grupo.maxQtd) {
      throw new Error(
        `O grupo "${grupo.titulo}" precisa de ${grupo.minQtd} a ${grupo.maxQtd} opção(ões).`,
      );
    }
  }

  return [...porGrupo.values()].flat();
}

function calcularPrecoItem(produto, complementos, quantidade) {
  const totalComplementos = complementos.reduce((soma, c) => soma + c.preco, 0);
  return round2((produto.precoBase + totalComplementos) * quantidade);
}

function serializarCarrinho(carrinho) {
  const subtotal = carrinho.itens.reduce((soma, i) => soma + i.precoItem, 0);
  const loja = carrinho.lojaId
    ? mockLojas.find((l) => l.id === carrinho.lojaId)
    : null;
  const taxaEntrega = 0; // a taxa depende do endereço: é calculada no fechamento do pedido (APP7)

  return {
    lojaId: carrinho.lojaId,
    lojaNome: carrinho.lojaNome,
    itens: carrinho.itens.map((i) => ({
      id: i.id,
      produto: i.produto,
      quantidade: i.quantidade,
      observacao: i.observacao,
      complementos: i.complementos,
      precoItem: round2(i.precoItem),
    })),
    subtotal: round2(subtotal),
    taxaEntrega: round2(taxaEntrega),
    total: round2(subtotal + taxaEntrega),
  };
}

// --- Pedidos (APP7/APP8) ---
// Área de entrega de cada loja: bairros atendidos e a taxa da faixa de cada um.
const areasEntrega = {
  '1': [
    { bairro: 'Centro', taxa: 5.9 },
    { bairro: 'Boa Viagem', taxa: 8.0 },
  ],
  '2': [
    { bairro: 'Centro', taxa: 7.5 },
    { bairro: 'Boa Viagem', taxa: 9.5 },
    { bairro: 'Casa Forte', taxa: 11.0 },
  ],
  '3': [{ bairro: 'Centro', taxa: 9.0 }],
  '4': [
    { bairro: 'Centro', taxa: 0 },
    { bairro: 'Boa Viagem', taxa: 3.0 },
  ],
};

const STATUS_PEDIDO = [
  'aguardando_confirmacao',
  'em_preparo',
  'pronto',
  'a_caminho',
  'entregue',
  'recusado',
  'cancelado',
  'nao_entregue',
];
const STATUS_COM_MOTIVO = ['recusado', 'cancelado', 'nao_entregue'];
const STATUS_FINAIS = ['entregue', ...STATUS_COM_MOTIVO];
const FORMAS_PAGAMENTO = ['dinheiro', 'cartao_entrega', 'pix'];

const pedidos = []; // todos os pedidos, de todos os clientes (o "painel da loja" lê daqui)
let proximoPedidoId = 1;

function normalizarTexto(s) {
  return String(s || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase();
}

// O servidor decide se o endereço está na área e qual é a taxa da faixa.
function avaliarEntrega(lojaId, endereco) {
  const faixas = areasEntrega[lojaId] || [];
  const faixa = faixas.find(
    (f) => normalizarTexto(f.bairro) === normalizarTexto(endereco.bairro),
  );
  if (faixa) return { dentroDaArea: true, taxa: faixa.taxa, mensagem: null };

  const atendidos = faixas.map((f) => f.bairro).join(', ');
  return {
    dentroDaArea: false,
    taxa: 0,
    mensagem:
      `Esta loja não entrega no bairro "${endereco.bairro}". ` +
      `Escolha outro endereço ou cadastre um em um bairro atendido (${atendidos}).`,
  };
}

function serializarPedido(p) {
  return {
    id: p.id,
    numero: p.numero,
    lojaId: p.lojaId,
    lojaNome: p.lojaNome,
    status: p.status,
    itens: p.itens,
    subtotal: p.subtotal,
    taxaEntrega: p.taxaEntrega,
    total: p.total,
    endereco: p.endereco,
    pagamento: p.pagamento,
    tempoEstimadoMin: p.tempoEstimadoMin,
    entregadorNome: p.entregadorNome,
    motivo: p.motivo,
    criadoEm: p.criadoEm,
    avaliacao: p.avaliacao || null,
  };
}

function pedidoDoUsuario(email, id) {
  return pedidos.find((p) => p.id === id && p.usuario === email) || null;
}

// --- Entregador (APP10): ainda sem login, o mock assume entregadores fixos ---
const enderecosLojas = {
  '1': 'Praça da República, 100 – Centro',
  '2': 'Av. Conde da Boa Vista, 250 – Centro',
  '3': 'Rua do Sol, 40 – Centro',
  '4': 'Parque da Jaqueira, s/n – Boa Viagem',
};
const entregadores = new Map([
  ['e1', { id: 'e1', nome: 'Carlos Silva', online: false }],
  ['e2', { id: 'e2', nome: 'Ana Souza', online: false }],
]);
const ofertas = []; // ofertas de entrega enviadas aos entregadores
const entregas = []; // entregas aceitas
let proximaOfertaId = 1;
let proximaEntregaId = 1;
const PRAZO_OFERTA_PADRAO_S = 30;
const MSG_OFERTA_PASSOU = 'O prazo acabou e a oferta passou para outro entregador.';

// O servidor é quem manda no prazo: oferta pendente que passou do limite
// vira "expirada" (passou para outro entregador).
function expirarOfertas() {
  const agora = Date.now();
  for (const o of ofertas) {
    if (o.status === 'pendente' && agora > o.expiraEmMs) o.status = 'expirada';
  }
}

function mensagemOferta(status) {
  if (status === 'expirada') return MSG_OFERTA_PASSOU;
  if (status === 'aceita') return 'Você já aceitou esta oferta.';
  if (status === 'recusada') return 'Você recusou esta oferta.';
  return 'Esta oferta não está mais disponível.';
}

function serializarOferta(o) {
  return {
    id: o.id,
    origem: o.origem,
    destino: o.destino,
    distanciaKm: o.distanciaKm,
    valor: o.valor,
    prazoSegundos: o.prazoSegundos,
    segundosRestantes: Math.max(0, Math.ceil((o.expiraEmMs - Date.now()) / 1000)),
  };
}

function serializarEntrega(e) {
  return {
    id: e.id,
    pedidoId: e.pedidoId,
    lojaNome: e.lojaNome,
    origem: e.origem,
    destino: e.destino,
    pontoReferencia: e.pontoReferencia,
    itens: e.itens,
    distanciaKm: e.distanciaKm,
    valor: e.valor,
    status: e.status,
    motivoInsucesso: e.motivoInsucesso,
    finalizadaEm: e.finalizadaEm,
  };
}

// --- Entregas do entregador (APP11) ---
const STATUS_ENTREGA_ATIVA = ['indo_para_loja', 'a_caminho'];
const MOTIVOS_INSUCESSO = {
  cliente_ausente: 'Cliente ausente',
  endereco_nao_encontrado: 'Endereço não encontrado',
  cliente_recusou: 'Cliente recusou o pedido',
  cliente_nao_atende: 'Cliente não atende o telefone',
  outro: 'Outro motivo',
};

function entregaAtiva(entregadorId) {
  return (
    entregas.find(
      (e) => e.entregadorId === entregadorId && STATUS_ENTREGA_ATIVA.includes(e.status),
    ) || null
  );
}

// O entregador só enxerga e mexe nas entregas que são dele.
function entregaDoEntregador(entregadorId, entregaId) {
  return entregas.find((e) => e.id === entregaId && e.entregadorId === entregadorId) || null;
}

function chaveDoDia(data) {
  const d = new Date(data);
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

// --- Avaliações (APP12) ---
const avaliacoes = []; // { pedidoId, usuario, lojaId, notaLoja, notaEntregador, comentario, criadaEm }

// Avaliações antigas de outros clientes, para a média já aparecer na lista de lojas.
for (const nota of [5, 4, 5, 5, 4, 5, 4, 5, 5, 4]) {
  avaliacoes.push({ pedidoId: null, usuario: 'seed', lojaId: '1', notaLoja: nota, notaEntregador: null, comentario: '', criadaEm: '2026-08-01T12:00:00.000Z' });
}
for (const nota of [4, 3, 4, 5, 4, 3]) {
  avaliacoes.push({ pedidoId: null, usuario: 'seed', lojaId: '2', notaLoja: nota, notaEntregador: null, comentario: '', criadaEm: '2026-08-01T12:00:00.000Z' });
}

function notaValida(n) {
  return Number.isInteger(n) && n >= 1 && n <= 5;
}

function mediaDaLoja(lojaId) {
  const notas = avaliacoes.filter((a) => a.lojaId === lojaId).map((a) => a.notaLoja);
  if (notas.length === 0) return { mediaAvaliacao: null, totalAvaliacoes: 0 };
  const media = notas.reduce((s, n) => s + n, 0) / notas.length;
  return { mediaAvaliacao: Math.round(media * 10) / 10, totalAvaliacoes: notas.length };
}

function gerarToken(email) {
  return `fake-jwt-${email}-${Date.now()}`;
}

function lerCorpo(req) {
  return new Promise((resolve, reject) => {
    let dados = '';
    req.on('data', (chunk) => (dados += chunk));
    req.on('end', () => {
      if (!dados) return resolve({});
      try {
        resolve(JSON.parse(dados));
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', reject);
  });
}

function enviarJson(res, status, corpo) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  });
  res.end(JSON.stringify(corpo));
}

const server = http.createServer(async (req, res) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    });
    return res.end();
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);
  const pathname = url.pathname;

  console.log(`${new Date().toLocaleTimeString()} - ${req.method} ${req.url}`);

  try {
    if (pathname === '/health' && req.method === 'GET') {
      return enviarJson(res, 200, { status: 'ok' });
    }

    if (pathname === '/auth/cadastro' && req.method === 'POST') {
      const { nome, email, telefone, senha } = await lerCorpo(req);
      if (!nome || !email || !telefone || !senha) {
        return enviarJson(res, 400, { error: 'Preencha todos os campos.' });
      }
      if (usuarios.some((u) => u.email === email)) {
        return enviarJson(res, 400, { error: 'E-mail já cadastrado.' });
      }
      usuarios.push({ nome, email, telefone, senha });
      const token = gerarToken(email);
      sessoes.set(token, email);
      return enviarJson(res, 201, { token });
    }

    if (pathname === '/auth/login' && req.method === 'POST') {
      const { email, senha } = await lerCorpo(req);
      const usuario = usuarios.find(
        (u) => u.email === email && u.senha === senha,
      );
      if (!usuario) {
        return enviarJson(res, 401, { error: 'Credenciais inválidas.' });
      }
      const token = gerarToken(email);
      sessoes.set(token, email);
      return enviarJson(res, 200, { token });
    }

    if (pathname === '/auth/me' && req.method === 'GET') {
      const auth = req.headers['authorization'] || '';
      const token = auth.replace('Bearer ', '').trim();
      const email = sessoes.get(token);
      if (!email) {
        return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });
      }
      return enviarJson(res, 200, { email });
    }

    if (pathname === '/auth/invalidar-tokens' && req.method === 'POST') {
      sessoes.clear();
      return enviarJson(res, 200, { status: 'sessões invalidadas' });
    }

    // --- Lojas ---
    if (pathname === '/lojas' && req.method === 'GET') {
      if (forcarListaVazia) {
        return enviarJson(res, 200, []);
      }
      let lista = [...mockLojas];
      const busca = (url.searchParams.get('busca') || '').toLowerCase().trim();
      const categoria = (url.searchParams.get('categoria') || '').trim();
      if (busca) {
        lista = lista.filter((l) => l.nome.toLowerCase().includes(busca));
      }
      if (categoria) {
        lista = lista.filter((l) => l.categoria === categoria);
      }
      // A média vem calculada pelo servidor, a partir das avaliações dos pedidos.
      return enviarJson(res, 200, lista.map((l) => ({ ...l, ...mediaDaLoja(l.id) })));
    }

    if (pathname === '/categorias' && req.method === 'GET') {
      const cats = [...new Set(mockLojas.map((l) => l.categoria))];
      return enviarJson(res, 200, cats);
    }

    // Cardápio: /lojas/:id/cardapio
    const cardapioMatch = pathname.match(/^\/lojas\/([^/]+)\/cardapio$/);
    if (cardapioMatch && req.method === 'GET') {
      const lojaId = cardapioMatch[1];
      const cardapio = mockCardapios[lojaId];
      if (!cardapio) {
        return enviarJson(res, 404, { error: 'Cardápio não encontrado.' });
      }
      return enviarJson(res, 200, cardapio);
    }

    // Admin: alterna lista vazia
    if (pathname === '/admin/lista-vazia' && req.method === 'POST') {
      forcarListaVazia = !forcarListaVazia;
      return enviarJson(res, 200, {
        listaVazia: forcarListaVazia,
        msg: forcarListaVazia
          ? 'Lista de lojas agora retorna vazia'
          : 'Lista de lojas voltou ao normal',
      });
    }

    // --- Endereços ---
    if (pathname === '/enderecos' && req.method === 'GET') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });
      return enviarJson(res, 200, enderecosDoUsuario(email));
    }

    if (pathname === '/enderecos' && req.method === 'POST') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });

      const corpo = await lerCorpo(req);
      const { rua, numero, complemento, bairro, cidade, pontoReferencia, favorito } = corpo;
      if (!rua || !numero || !bairro || !cidade) {
        return enviarJson(res, 400, {
          error: 'Preencha rua, número, bairro e cidade.',
        });
      }

      const lista = enderecosDoUsuario(email);
      const ehPrimeiro = lista.length === 0;
      const novoFavorito = ehPrimeiro || Boolean(favorito);

      if (novoFavorito) {
        lista.forEach((e) => (e.favorito = false));
      }

      const novo = {
        id: String(proximoEnderecoId++),
        rua,
        numero,
        complemento: complemento || '',
        bairro,
        cidade,
        pontoReferencia: pontoReferencia || '',
        favorito: novoFavorito,
      };
      lista.push(novo);
      return enviarJson(res, 201, novo);
    }

    const enderecoFavoritoMatch = pathname.match(/^\/enderecos\/([^/]+)\/favorito$/);
    if (enderecoFavoritoMatch && req.method === 'POST') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });

      const id = enderecoFavoritoMatch[1];
      const lista = enderecosDoUsuario(email);
      const alvo = lista.find((e) => e.id === id);
      if (!alvo) return enviarJson(res, 404, { error: 'Endereço não encontrado.' });

      lista.forEach((e) => (e.favorito = e.id === id));
      return enviarJson(res, 200, lista);
    }

    const enderecoMatch = pathname.match(/^\/enderecos\/([^/]+)$/);
    if (enderecoMatch && req.method === 'PUT') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });

      const id = enderecoMatch[1];
      const lista = enderecosDoUsuario(email);
      const alvo = lista.find((e) => e.id === id);
      if (!alvo) return enviarJson(res, 404, { error: 'Endereço não encontrado.' });

      const corpo = await lerCorpo(req);
      const { rua, numero, complemento, bairro, cidade, pontoReferencia, favorito } = corpo;
      if (!rua || !numero || !bairro || !cidade) {
        return enviarJson(res, 400, {
          error: 'Preencha rua, número, bairro e cidade.',
        });
      }

      alvo.rua = rua;
      alvo.numero = numero;
      alvo.complemento = complemento || '';
      alvo.bairro = bairro;
      alvo.cidade = cidade;
      alvo.pontoReferencia = pontoReferencia || '';

      if (favorito) {
        lista.forEach((e) => (e.favorito = e.id === id));
      }

      return enviarJson(res, 200, alvo);
    }

    if (enderecoMatch && req.method === 'DELETE') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });

      const id = enderecoMatch[1];
      const lista = enderecosDoUsuario(email);
      const indice = lista.findIndex((e) => e.id === id);
      if (indice === -1) return enviarJson(res, 404, { error: 'Endereço não encontrado.' });

      const [removido] = lista.splice(indice, 1);
      if (removido.favorito && lista.length > 0) {
        lista[0].favorito = true;
      }

      return enviarJson(res, 200, { status: 'removido' });
    }

    // --- Carrinho ---
    if (pathname === '/carrinho' && req.method === 'GET') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });
      return enviarJson(res, 200, serializarCarrinho(carrinhoDoUsuario(email)));
    }

    if (pathname === '/carrinho/itens' && req.method === 'POST') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });

      const corpo = await lerCorpo(req);
      const { lojaId, produtoId, quantidade, complementos, observacao, substituir } = corpo;

      if (!lojaId || !produtoId) {
        return enviarJson(res, 400, { error: 'Loja e produto são obrigatórios.' });
      }

      const loja = mockLojas.find((l) => l.id === String(lojaId));
      if (!loja) return enviarJson(res, 404, { error: 'Loja não encontrada.' });

      const produto = encontrarProduto(String(lojaId), produtoId);
      if (!produto) return enviarJson(res, 404, { error: 'Produto não encontrado.' });
      if (produto.disponivel === false) {
        return enviarJson(res, 400, { error: 'Este produto está indisponível.' });
      }

      const carrinho = carrinhoDoUsuario(email);

      if (
        carrinho.itens.length > 0 &&
        carrinho.lojaId !== String(lojaId) &&
        !substituir
      ) {
        return enviarJson(res, 409, {
          error: 'Seu carrinho tem itens de outra loja.',
          lojaAtualId: carrinho.lojaId,
          lojaAtualNome: carrinho.lojaNome,
        });
      }

      if (carrinho.lojaId !== String(lojaId)) {
        // Loja nova (carrinho estava vazio, ou o cliente confirmou a troca).
        carrinho.itens = [];
        carrinho.lojaId = String(lojaId);
        carrinho.lojaNome = loja.nome;
      }

      let complementosResolvidos;
      try {
        complementosResolvidos = resolverComplementos(produto, complementos);
      } catch (e) {
        return enviarJson(res, 400, { error: e.message });
      }

      const qtd = Number.isFinite(Number(quantidade)) && Number(quantidade) > 0
        ? Math.floor(Number(quantidade))
        : 1;

      const item = {
        id: String(proximoItemCarrinhoId++),
        produto,
        quantidade: qtd,
        observacao: typeof observacao === 'string' ? observacao : '',
        complementos: complementosResolvidos,
        precoItem: calcularPrecoItem(produto, complementosResolvidos, qtd),
      };

      carrinho.itens.push(item);
      return enviarJson(res, 201, serializarCarrinho(carrinho));
    }

    const itemCarrinhoMatch = pathname.match(/^\/carrinho\/itens\/([^/]+)$/);
    if (itemCarrinhoMatch && req.method === 'PUT') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });

      const id = itemCarrinhoMatch[1];
      const carrinho = carrinhoDoUsuario(email);
      const item = carrinho.itens.find((i) => i.id === id);
      if (!item) return enviarJson(res, 404, { error: 'Item não encontrado no carrinho.' });

      const corpo = await lerCorpo(req);
      const { quantidade, complementos, observacao } = corpo;

      if (complementos !== undefined) {
        try {
          item.complementos = resolverComplementos(item.produto, complementos);
        } catch (e) {
          return enviarJson(res, 400, { error: e.message });
        }
      }

      if (quantidade !== undefined) {
        const qtd = Number(quantidade);
        if (!Number.isFinite(qtd) || qtd < 1) {
          return enviarJson(res, 400, { error: 'Quantidade inválida.' });
        }
        item.quantidade = Math.floor(qtd);
      }

      if (observacao !== undefined) {
        item.observacao = typeof observacao === 'string' ? observacao : '';
      }

      item.precoItem = calcularPrecoItem(item.produto, item.complementos, item.quantidade);

      return enviarJson(res, 200, serializarCarrinho(carrinho));
    }

    if (itemCarrinhoMatch && req.method === 'DELETE') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });

      const id = itemCarrinhoMatch[1];
      const carrinho = carrinhoDoUsuario(email);
      const indice = carrinho.itens.findIndex((i) => i.id === id);
      if (indice === -1) {
        return enviarJson(res, 404, { error: 'Item não encontrado no carrinho.' });
      }

      carrinho.itens.splice(indice, 1);
      if (carrinho.itens.length === 0) {
        carrinho.lojaId = null;
        carrinho.lojaNome = null;
      }

      return enviarJson(res, 200, serializarCarrinho(carrinho));
    }

    // --- Pedidos: prévia do fechamento (área de entrega + taxa da faixa) ---
    if (pathname === '/pedidos/previa' && req.method === 'POST') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });

      const carrinho = carrinhoDoUsuario(email);
      if (carrinho.itens.length === 0) {
        return enviarJson(res, 400, { error: 'Seu carrinho está vazio.' });
      }

      const { enderecoId } = await lerCorpo(req);
      const endereco = enderecosDoUsuario(email).find((e) => e.id === enderecoId);
      if (!endereco) {
        return enviarJson(res, 400, { error: 'Selecione um endereço de entrega.' });
      }

      const entrega = avaliarEntrega(carrinho.lojaId, endereco);
      const subtotal = round2(carrinho.itens.reduce((s, i) => s + i.precoItem, 0));
      return enviarJson(res, 200, {
        dentroDaArea: entrega.dentroDaArea,
        mensagem: entrega.mensagem,
        subtotal,
        taxaEntrega: round2(entrega.taxa),
        total: round2(subtotal + entrega.taxa),
      });
    }

    // --- Pedidos: criar (W07) ---
    if (pathname === '/pedidos' && req.method === 'POST') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });

      const carrinho = carrinhoDoUsuario(email);
      if (carrinho.itens.length === 0) {
        return enviarJson(res, 400, { error: 'Seu carrinho está vazio.' });
      }

      const { enderecoId, pagamento } = await lerCorpo(req);
      const endereco = enderecosDoUsuario(email).find((e) => e.id === enderecoId);
      if (!endereco) {
        return enviarJson(res, 400, { error: 'Selecione um endereço de entrega.' });
      }

      const forma = pagamento && pagamento.forma;
      if (!FORMAS_PAGAMENTO.includes(forma)) {
        return enviarJson(res, 400, { error: 'Escolha a forma de pagamento.' });
      }

      // Recusas do servidor (422): o app mostra exatamente esta mensagem.
      const loja = mockLojas.find((l) => l.id === carrinho.lojaId);
      if (!loja || !loja.aberta) {
        return enviarJson(res, 422, {
          error: `A loja "${carrinho.lojaNome}" fechou e não está aceitando pedidos agora.`,
        });
      }

      for (const item of carrinho.itens) {
        const atual = encontrarProduto(carrinho.lojaId, item.produto.id);
        if (!atual || atual.disponivel === false) {
          return enviarJson(res, 422, {
            error: `O item "${item.produto.nome}" esgotou. Remova-o do carrinho para continuar.`,
          });
        }
      }

      const entrega = avaliarEntrega(carrinho.lojaId, endereco);
      if (!entrega.dentroDaArea) {
        return enviarJson(res, 422, { error: entrega.mensagem });
      }

      const subtotal = round2(carrinho.itens.reduce((s, i) => s + i.precoItem, 0));
      const total = round2(subtotal + entrega.taxa);

      let trocoPara = null;
      if (forma === 'dinheiro' && pagamento.trocoPara !== undefined && pagamento.trocoPara !== null) {
        trocoPara = Number(pagamento.trocoPara);
        if (!Number.isFinite(trocoPara) || trocoPara < total) {
          return enviarJson(res, 400, {
            error: `O valor para troco precisa ser maior ou igual ao total do pedido (R$ ${total.toFixed(2).replace('.', ',')}).`,
          });
        }
      }

      const numero = proximoPedidoId;
      const pedido = {
        id: String(proximoPedidoId++),
        numero,
        usuario: email,
        lojaId: carrinho.lojaId,
        lojaNome: carrinho.lojaNome,
        status: 'aguardando_confirmacao',
        itens: carrinho.itens.map((i) => ({
          nome: i.produto.nome,
          quantidade: i.quantidade,
          observacao: i.observacao,
          complementos: i.complementos.map((c) => c.nome),
          precoItem: i.precoItem,
        })),
        // Só para "repetir pedido" (APP9): ids para remontar o carrinho com os preços de hoje.
        itensRepeticao: carrinho.itens.map((i) => ({
          produtoId: i.produto.id,
          nome: i.produto.nome,
          quantidade: i.quantidade,
          observacao: i.observacao,
          complementosIds: i.complementos.map((c) => ({
            grupoId: c.grupoId,
            opcaoId: c.opcaoId,
          })),
          precoItem: i.precoItem,
        })),
        subtotal,
        taxaEntrega: round2(entrega.taxa),
        total,
        endereco: { ...endereco, favorito: false },
        pagamento: { forma, trocoPara },
        tempoEstimadoMin: null,
        entregadorNome: null,
        motivo: null,
        criadoEm: new Date().toISOString(),
      };
      pedidos.push(pedido);

      // Pedido criado: o carrinho do cliente é esvaziado.
      carrinho.itens = [];
      carrinho.lojaId = null;
      carrinho.lojaNome = null;

      return enviarJson(res, 201, serializarPedido(pedido));
    }

    // --- Pedidos: lista do cliente (mais recentes primeiro) ---
    if (pathname === '/pedidos' && req.method === 'GET') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });
      const lista = pedidos
        .filter((p) => p.usuario === email)
        .reverse()
        .map(serializarPedido);
      return enviarJson(res, 200, lista);
    }

    const pedidoCancelarMatch = pathname.match(/^\/pedidos\/([^/]+)\/cancelar$/);
    if (pedidoCancelarMatch && req.method === 'POST') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });

      const pedido = pedidoDoUsuario(email, pedidoCancelarMatch[1]);
      if (!pedido) return enviarJson(res, 404, { error: 'Pedido não encontrado.' });

      if (pedido.status !== 'aguardando_confirmacao') {
        const msg = STATUS_FINAIS.includes(pedido.status)
          ? 'Este pedido já foi encerrado.'
          : 'O preparo já começou, não é mais possível cancelar.';
        return enviarJson(res, 409, { error: msg });
      }

      pedido.status = 'cancelado';
      pedido.motivo = 'Cancelado pelo cliente.';
      return enviarJson(res, 200, serializarPedido(pedido));
    }

    const pedidoMatch = pathname.match(/^\/pedidos\/([^/]+)$/);
    if (pedidoMatch && req.method === 'GET') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });

      const pedido = pedidoDoUsuario(email, pedidoMatch[1]);
      if (!pedido) return enviarJson(res, 404, { error: 'Pedido não encontrado.' });
      return enviarJson(res, 200, serializarPedido(pedido));
    }

    // --- "Painel da loja" e controles de teste (simulam o que a loja faz) ---
    if (pathname === '/painel/pedidos' && req.method === 'GET') {
      const lojaId = url.searchParams.get('lojaId');
      const lista = pedidos
        .filter((p) => !lojaId || p.lojaId === lojaId)
        .reverse()
        .map((p) => ({ ...serializarPedido(p), clienteEmail: p.usuario }));
      return enviarJson(res, 200, lista);
    }

    const adminStatusMatch = pathname.match(/^\/admin\/pedidos\/([^/]+)\/status$/);
    if (adminStatusMatch && req.method === 'POST') {
      const pedido = pedidos.find((p) => p.id === adminStatusMatch[1]);
      if (!pedido) return enviarJson(res, 404, { error: 'Pedido não encontrado.' });

      const { status, tempoEstimadoMin, entregadorNome, motivo } = await lerCorpo(req);
      if (!STATUS_PEDIDO.includes(status)) {
        return enviarJson(res, 400, {
          error: `Status inválido. Use um destes: ${STATUS_PEDIDO.join(', ')}.`,
        });
      }
      if (STATUS_COM_MOTIVO.includes(status) && !motivo) {
        return enviarJson(res, 400, { error: 'Informe o motivo (campo "motivo").' });
      }
      if (status === 'a_caminho' && !(entregadorNome || pedido.entregadorNome)) {
        return enviarJson(res, 400, {
          error: 'Informe o nome do entregador (campo "entregadorNome").',
        });
      }

      pedido.status = status;
      if (tempoEstimadoMin !== undefined) pedido.tempoEstimadoMin = tempoEstimadoMin;
      if (entregadorNome) pedido.entregadorNome = entregadorNome;
      if (motivo) pedido.motivo = motivo;
      return enviarJson(res, 200, serializarPedido(pedido));
    }

    const adminLojaMatch = pathname.match(/^\/admin\/lojas\/([^/]+)\/aberta$/);
    if (adminLojaMatch && req.method === 'POST') {
      const loja = mockLojas.find((l) => l.id === adminLojaMatch[1]);
      if (!loja) return enviarJson(res, 404, { error: 'Loja não encontrada.' });
      const { aberta } = await lerCorpo(req);
      loja.aberta = Boolean(aberta);
      return enviarJson(res, 200, { id: loja.id, aberta: loja.aberta });
    }

    const adminProdutoMatch = pathname.match(/^\/admin\/produtos\/([^/]+)\/disponivel$/);
    if (adminProdutoMatch && req.method === 'POST') {
      const { disponivel } = await lerCorpo(req);
      let achado = null;
      for (const categorias of Object.values(mockCardapios)) {
        for (const cat of categorias) {
          const p = cat.produtos.find((x) => x.id === adminProdutoMatch[1]);
          if (p) achado = p;
        }
      }
      if (!achado) return enviarJson(res, 404, { error: 'Produto não encontrado.' });
      achado.disponivel = Boolean(disponivel);
      return enviarJson(res, 200, { id: achado.id, disponivel: achado.disponivel });
    }

    // --- Pedidos: repetir (APP9) — devolve os itens ao carrinho com os preços de hoje ---
    const pedidoRepetirMatch = pathname.match(/^\/pedidos\/([^/]+)\/repetir$/);
    if (pedidoRepetirMatch && req.method === 'POST') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });

      const pedido = pedidoDoUsuario(email, pedidoRepetirMatch[1]);
      if (!pedido) return enviarJson(res, 404, { error: 'Pedido não encontrado.' });

      const loja = mockLojas.find((l) => l.id === pedido.lojaId);
      if (!loja) return enviarJson(res, 404, { error: 'Esta loja não existe mais.' });

      const { substituir } = await lerCorpo(req);

      const novos = [];
      const indisponiveis = [];
      const precosAlterados = [];

      for (const it of pedido.itensRepeticao) {
        const produto = encontrarProduto(pedido.lojaId, it.produtoId);
        if (!produto) {
          indisponiveis.push({ nome: it.nome, motivo: 'não está mais no cardápio.' });
          continue;
        }
        if (produto.disponivel === false) {
          indisponiveis.push({ nome: it.nome, motivo: 'está indisponível no momento.' });
          continue;
        }

        let complementos;
        try {
          complementos = resolverComplementos(produto, it.complementosIds);
        } catch (e) {
          indisponiveis.push({
            nome: it.nome,
            motivo: 'as opções que você tinha escolhido mudaram no cardápio.',
          });
          continue;
        }

        const precoItem = calcularPrecoItem(produto, complementos, it.quantidade);
        if (precoItem !== it.precoItem) {
          precosAlterados.push({ nome: it.nome, de: it.precoItem, para: precoItem });
        }

        novos.push({
          id: String(proximoItemCarrinhoId++),
          produto,
          quantidade: it.quantidade,
          observacao: it.observacao,
          complementos,
          precoItem,
        });
      }

      const carrinho = carrinhoDoUsuario(email);

      if (novos.length > 0) {
        if (
          carrinho.itens.length > 0 &&
          carrinho.lojaId !== pedido.lojaId &&
          !substituir
        ) {
          return enviarJson(res, 409, {
            error: 'Seu carrinho tem itens de outra loja.',
            lojaAtualId: carrinho.lojaId,
            lojaAtualNome: carrinho.lojaNome,
          });
        }
        if (carrinho.lojaId !== pedido.lojaId) {
          carrinho.itens = [];
          carrinho.lojaId = pedido.lojaId;
          carrinho.lojaNome = loja.nome;
        }
        carrinho.itens.push(...novos);
      }

      return enviarJson(res, 200, {
        adicionados: novos.length,
        indisponiveis,
        precosAlterados,
        lojaAberta: loja.aberta,
        carrinho: serializarCarrinho(carrinho),
      });
    }

    // Muda o preço de um produto (para testar "preços da época" x "preços de hoje")
    const adminPrecoMatch = pathname.match(/^\/admin\/produtos\/([^/]+)\/preco$/);
    if (adminPrecoMatch && req.method === 'POST') {
      const { precoBase } = await lerCorpo(req);
      const novoPreco = Number(precoBase);
      if (!Number.isFinite(novoPreco) || novoPreco <= 0) {
        return enviarJson(res, 400, { error: 'Informe um precoBase maior que zero.' });
      }
      let achado = null;
      for (const categorias of Object.values(mockCardapios)) {
        for (const cat of categorias) {
          const p = cat.produtos.find((x) => x.id === adminPrecoMatch[1]);
          if (p) achado = p;
        }
      }
      if (!achado) return enviarJson(res, 404, { error: 'Produto não encontrado.' });
      achado.precoBase = novoPreco;
      return enviarJson(res, 200, { id: achado.id, precoBase: achado.precoBase });
    }

    // --- Entregador (APP10) ---
    const entDispMatch = pathname.match(/^\/entregadores\/([^/]+)\/disponibilidade$/);
    if (entDispMatch && req.method === 'GET') {
      const ent = entregadores.get(entDispMatch[1]);
      if (!ent) return enviarJson(res, 404, { error: 'Entregador não encontrado.' });
      return enviarJson(res, 200, { online: ent.online });
    }

    if (entDispMatch && req.method === 'PUT') {
      const ent = entregadores.get(entDispMatch[1]);
      if (!ent) return enviarJson(res, 404, { error: 'Entregador não encontrado.' });

      const { online } = await lerCorpo(req);
      if (typeof online !== 'boolean') {
        return enviarJson(res, 400, { error: 'Informe "online" como true ou false.' });
      }

      ent.online = online;
      if (!online) {
        // Offline: a oferta pendente deixa de ser dele (passa para outro).
        for (const o of ofertas) {
          if (o.entregadorId === ent.id && o.status === 'pendente') o.status = 'recusada';
        }
      }
      return enviarJson(res, 200, { online: ent.online });
    }

    const entOfertaMatch = pathname.match(/^\/entregadores\/([^/]+)\/oferta$/);
    if (entOfertaMatch && req.method === 'GET') {
      const ent = entregadores.get(entOfertaMatch[1]);
      if (!ent) return enviarJson(res, 404, { error: 'Entregador não encontrado.' });

      expirarOfertas();

      // ?atual=ID: a oferta que o app está mostrando. Se ela já não vale
      // mais, o servidor diz por quê (ex.: passou para outro).
      let encerrada = null;
      const atual = url.searchParams.get('atual');
      if (atual) {
        const o = ofertas.find((x) => x.id === atual && x.entregadorId === ent.id);
        if (o && o.status !== 'pendente') {
          encerrada = { id: o.id, status: o.status, mensagem: mensagemOferta(o.status) };
        }
      }

      const pendente = ent.online && !entregaAtiva(ent.id)
        ? ofertas.find((o) => o.entregadorId === ent.id && o.status === 'pendente')
        : null;

      return enviarJson(res, 200, {
        oferta: pendente ? serializarOferta(pendente) : null,
        encerrada,
      });
    }

    const entRespostaMatch = pathname.match(
      /^\/entregadores\/([^/]+)\/ofertas\/([^/]+)\/(aceitar|recusar)$/,
    );
    if (entRespostaMatch && req.method === 'POST') {
      const [, entId, ofertaId, acao] = entRespostaMatch;
      const ent = entregadores.get(entId);
      if (!ent) return enviarJson(res, 404, { error: 'Entregador não encontrado.' });

      expirarOfertas();
      const oferta = ofertas.find((o) => o.id === ofertaId && o.entregadorId === ent.id);
      if (!oferta) return enviarJson(res, 404, { error: 'Oferta não encontrada.' });

      if (oferta.status === 'expirada') {
        return enviarJson(res, 410, { error: MSG_OFERTA_PASSOU });
      }
      if (oferta.status !== 'pendente') {
        return enviarJson(res, 409, { error: 'Esta oferta não está mais disponível.' });
      }

      if (acao === 'recusar') {
        oferta.status = 'recusada';
        return enviarJson(res, 200, { status: 'recusada' });
      }

      if (entregaAtiva(ent.id)) {
        return enviarJson(res, 409, {
          error: 'Você já tem uma entrega em andamento. Conclua-a para aceitar outra.',
        });
      }

      if (!ent.online) {
        return enviarJson(res, 409, {
          error: 'Você está offline. Fique online para aceitar ofertas.',
        });
      }

      oferta.status = 'aceita';
      // Ofertas ligadas a um pedido levam os dados reais dele; as de teste
      // (sem pedidoId) levam dados de exemplo.
      const pedidoLigado = oferta.pedidoId
        ? pedidos.find((p) => p.id === oferta.pedidoId)
        : null;
      const entrega = {
        id: String(proximaEntregaId++),
        ofertaId: oferta.id,
        entregadorId: ent.id,
        pedidoId: oferta.pedidoId,
        lojaNome: pedidoLigado ? pedidoLigado.lojaNome : String(oferta.origem).split(' · ')[0],
        origem: oferta.origem,
        destino: oferta.destino,
        pontoReferencia: pedidoLigado
          ? pedidoLigado.endereco.pontoReferencia
          : 'Portão azul, ao lado da padaria',
        itens: pedidoLigado
          ? pedidoLigado.itens.map((i) => ({
              nome: i.nome,
              quantidade: i.quantidade,
              observacao: i.observacao,
              complementos: i.complementos,
            }))
          : [{ nome: 'X-Burguer Artesanal', quantidade: 1, observacao: '', complementos: [] }],
        distanciaKm: oferta.distanciaKm,
        valor: oferta.valor,
        status: 'indo_para_loja',
        motivoInsucesso: null,
        criadaEm: new Date().toISOString(),
        finalizadaEm: null,
      };
      entregas.push(entrega);

      if (oferta.pedidoId) {
        const pedido = pedidos.find((p) => p.id === oferta.pedidoId);
        if (pedido) pedido.entregadorNome = ent.nome;
      }

      return enviarJson(res, 200, serializarEntrega(entrega));
    }

    // Simula o sistema mandando uma oferta de entrega para o entregador
    if (pathname === '/admin/ofertas' && req.method === 'POST') {
      const corpo = await lerCorpo(req);
      const ent = entregadores.get(corpo.entregadorId || 'e1');
      if (!ent) return enviarJson(res, 404, { error: 'Entregador não encontrado.' });

      let origem = corpo.origem;
      let destino = corpo.destino;
      let pedidoId = null;

      if (corpo.pedidoId) {
        const p = pedidos.find((x) => x.id === String(corpo.pedidoId));
        if (!p) return enviarJson(res, 404, { error: 'Pedido não encontrado.' });
        pedidoId = p.id;
        origem = origem || `${p.lojaNome} · ${enderecosLojas[p.lojaId] || ''}`;
        destino = destino || `${p.endereco.rua}, ${p.endereco.numero} – ${p.endereco.bairro}`;
      }

      const prazo =
        Number(corpo.prazoSegundos) > 0
          ? Math.floor(Number(corpo.prazoSegundos))
          : PRAZO_OFERTA_PADRAO_S;

      // Uma oferta pendente por vez: a anterior passa para outro entregador.
      for (const o of ofertas) {
        if (o.entregadorId === ent.id && o.status === 'pendente') o.status = 'expirada';
      }

      const oferta = {
        id: String(proximaOfertaId++),
        entregadorId: ent.id,
        pedidoId,
        origem: origem || 'Burguer King da Praça · Praça da República, 100 – Centro',
        destino: destino || 'Rua das Flores, 45 – Boa Viagem',
        distanciaKm: Number.isFinite(Number(corpo.distanciaKm)) && corpo.distanciaKm != null
          ? Number(corpo.distanciaKm)
          : 2.4,
        valor: Number.isFinite(Number(corpo.valor)) && corpo.valor != null
          ? Number(corpo.valor)
          : 8.5,
        prazoSegundos: prazo,
        expiraEmMs: Date.now() + prazo * 1000,
        status: 'pendente',
      };
      ofertas.push(oferta);

      return enviarJson(res, 201, {
        ...serializarOferta(oferta),
        entregadorOnline: ent.online,
      });
    }

    // Simula a oferta passando para outro entregador antes de o prazo acabar
    const adminRepassarMatch = pathname.match(/^\/admin\/ofertas\/([^/]+)\/repassar$/);
    if (adminRepassarMatch && req.method === 'POST') {
      const oferta = ofertas.find((o) => o.id === adminRepassarMatch[1]);
      if (!oferta) return enviarJson(res, 404, { error: 'Oferta não encontrada.' });
      if (oferta.status === 'pendente') oferta.status = 'expirada';
      return enviarJson(res, 200, { id: oferta.id, status: oferta.status });
    }

    // --- Entregas do entregador (APP11) ---
    const entEntregasMatch = pathname.match(/^\/entregadores\/([^/]+)\/entregas$/);
    if (entEntregasMatch && req.method === 'GET') {
      const ent = entregadores.get(entEntregasMatch[1]);
      if (!ent) return enviarJson(res, 404, { error: 'Entregador não encontrado.' });
      const soAtivas = url.searchParams.get('status') === 'ativas';
      const lista = entregas
        .filter((e) => e.entregadorId === ent.id)
        .filter((e) => !soAtivas || STATUS_ENTREGA_ATIVA.includes(e.status))
        .map(serializarEntrega);
      return enviarJson(res, 200, lista);
    }

    const entEntregaMatch = pathname.match(/^\/entregadores\/([^/]+)\/entregas\/([^/]+)$/);
    if (entEntregaMatch && req.method === 'GET') {
      const ent = entregadores.get(entEntregaMatch[1]);
      if (!ent) return enviarJson(res, 404, { error: 'Entregador não encontrado.' });
      const entrega = entregaDoEntregador(ent.id, entEntregaMatch[2]);
      if (!entrega) return enviarJson(res, 404, { error: 'Entrega não encontrada.' });
      return enviarJson(res, 200, serializarEntrega(entrega));
    }

    const entAcaoMatch = pathname.match(
      /^\/entregadores\/([^/]+)\/entregas\/([^/]+)\/(coleta|entrega|insucesso)$/,
    );
    if (entAcaoMatch && req.method === 'POST') {
      const [, entId, entregaId, acao] = entAcaoMatch;
      const ent = entregadores.get(entId);
      if (!ent) return enviarJson(res, 404, { error: 'Entregador não encontrado.' });

      // Entrega de outro entregador: para este, é como se não existisse.
      const entrega = entregaDoEntregador(ent.id, entregaId);
      if (!entrega) return enviarJson(res, 404, { error: 'Entrega não encontrada.' });

      if (!STATUS_ENTREGA_ATIVA.includes(entrega.status)) {
        return enviarJson(res, 409, { error: 'Esta entrega já foi encerrada.' });
      }

      const pedido = entrega.pedidoId
        ? pedidos.find((p) => p.id === entrega.pedidoId)
        : null;
      if (pedido && STATUS_FINAIS.includes(pedido.status)) {
        return enviarJson(res, 409, {
          error: 'O pedido já foi encerrado, então esta entrega não pode mais ser concluída.',
        });
      }

      if (acao === 'coleta') {
        if (entrega.status !== 'indo_para_loja') {
          return enviarJson(res, 409, { error: 'A coleta já foi confirmada.' });
        }
        entrega.status = 'a_caminho';
        if (pedido) {
          pedido.status = 'a_caminho';
          pedido.entregadorNome = ent.nome;
        }
        return enviarJson(res, 200, serializarEntrega(entrega));
      }

      // Entrega e insucesso só depois de a coleta ter sido confirmada.
      if (entrega.status !== 'a_caminho') {
        return enviarJson(res, 409, {
          error: 'Confirme a coleta antes de registrar a entrega.',
        });
      }

      if (acao === 'entrega') {
        entrega.status = 'entregue';
        entrega.finalizadaEm = new Date().toISOString();
        if (pedido) pedido.status = 'entregue'; // é essa confirmação que fecha o pedido
        return enviarJson(res, 200, serializarEntrega(entrega));
      }

      // insucesso: exige o motivo
      const { motivo } = await lerCorpo(req);
      if (!Object.prototype.hasOwnProperty.call(MOTIVOS_INSUCESSO, motivo)) {
        return enviarJson(res, 400, { error: 'Escolha o motivo do insucesso.' });
      }
      const rotulo = MOTIVOS_INSUCESSO[motivo];
      entrega.status = 'insucesso';
      entrega.motivoInsucesso = rotulo;
      entrega.finalizadaEm = new Date().toISOString();
      if (pedido) {
        pedido.status = 'nao_entregue';
        pedido.motivo = `Não foi possível entregar: ${rotulo}.`;
      }
      return enviarJson(res, 200, serializarEntrega(entrega));
    }

    // Ganhos do dia: só entregas concluídas contam
    const entGanhosMatch = pathname.match(/^\/entregadores\/([^/]+)\/ganhos$/);
    if (entGanhosMatch && req.method === 'GET') {
      const ent = entregadores.get(entGanhosMatch[1]);
      if (!ent) return enviarJson(res, 404, { error: 'Entregador não encontrado.' });

      const dia = url.searchParams.get('data') || chaveDoDia(Date.now());
      if (!/^\d{4}-\d{2}-\d{2}$/.test(dia)) {
        return enviarJson(res, 400, { error: 'Use data no formato AAAA-MM-DD.' });
      }

      const doDia = entregas
        .filter(
          (e) =>
            e.entregadorId === ent.id &&
            e.status === 'entregue' &&
            e.finalizadaEm &&
            chaveDoDia(e.finalizadaEm) === dia,
        )
        .sort((a, b) => b.finalizadaEm.localeCompare(a.finalizadaEm));

      return enviarJson(res, 200, {
        data: dia,
        quantidade: doDia.length,
        total: round2(doDia.reduce((s, e) => s + e.valor, 0)),
        entregas: doDia.map((e) => ({
          id: e.id,
          lojaNome: e.lojaNome,
          destino: e.destino,
          valor: e.valor,
          finalizadaEm: e.finalizadaEm,
        })),
      });
    }

    // --- Avaliação do pedido (APP12): uma por pedido, só para pedido entregue ---
    const pedidoAvaliacaoMatch = pathname.match(/^\/pedidos\/([^/]+)\/avaliacao$/);
    if (pedidoAvaliacaoMatch && req.method === 'POST') {
      const email = autenticarEmail(req);
      if (!email) return enviarJson(res, 401, { error: 'Token inválido ou expirado.' });

      const pedido = pedidoDoUsuario(email, pedidoAvaliacaoMatch[1]);
      if (!pedido) return enviarJson(res, 404, { error: 'Pedido não encontrado.' });

      if (pedido.status !== 'entregue') {
        return enviarJson(res, 409, { error: 'Só é possível avaliar pedidos entregues.' });
      }
      if (pedido.avaliacao) {
        return enviarJson(res, 409, { error: 'Este pedido já foi avaliado.' });
      }

      const { notaLoja, notaEntregador, comentario } = await lerCorpo(req);
      if (!notaValida(notaLoja)) {
        return enviarJson(res, 400, { error: 'Dê uma nota de 1 a 5 para a loja.' });
      }
      const temEntregador = Boolean(pedido.entregadorNome);
      if (temEntregador && !notaValida(notaEntregador)) {
        return enviarJson(res, 400, { error: 'Dê uma nota de 1 a 5 para o entregador.' });
      }

      pedido.avaliacao = {
        notaLoja,
        notaEntregador: temEntregador ? notaEntregador : null,
        comentario: typeof comentario === 'string' ? comentario.trim().slice(0, 500) : '',
        criadaEm: new Date().toISOString(),
      };
      avaliacoes.push({
        pedidoId: pedido.id,
        usuario: email,
        lojaId: pedido.lojaId,
        ...pedido.avaliacao,
      });

      return enviarJson(res, 201, pedido.avaliacao);
    }

    enviarJson(res, 404, { error: 'não encontrado' });
  } catch (e) {
    console.error(e);
    enviarJson(res, 400, { error: 'corpo da requisição inválido' });
  }
});

server.listen(PORT, () => {
  console.log(`Mock server rodando em http://localhost:${PORT}`);
  console.log(
    'Deixe este terminal aberto enquanto testa o app. Ctrl+C para parar.',
  );
});