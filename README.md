# Meu Delivery

App em Flutter/Dart. Inclui as tarefas:

- **A01** — Abertura do app, navegação e menus por perfil
- **A02** — Login e cadastro do cliente
- **A03** — Lista de lojas com busca e categorias
- **A04** — Cardápio da loja no app
- **A05** — Endereços do cliente no app
- **A06** — Carrinho com observações e total
- **A07** — Fechamento do pedido no app
- **A08** — Acompanhamento do pedido por status
- **A09** — Histórico de pedidos e repetir pedido
- **A10** — App do entregador: disponibilidade e oferta
- **A11** — App do entregador: coleta, entrega e insucesso
- **A12** — Avaliação da loja e do entregador

## Como rodar

```bash
flutter pub get
flutter run
```

Por padrão a API é procurada em `http://10.0.2.2:3000` (isso é o "localhost"
do seu PC quando roda no emulador Android). Se não tiver um servidor
rodando ali, o app vai cair na tela de erro — isso é esperado e faz parte
do critério de aceite (você pode clicar em "Tentar novamente").

Para apontar para outro endereço, sem editar código:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:3000
```

### Testando sem o back-end de verdade ainda

O repositório inclui `mock_server.js`, um servidor bem simples (só Node.js,
sem dependências) que simula as rotas que o app já usa. Rode num terminal
separado, deixando ele aberto:

```bash
node mock_server.js
```

Rotas simuladas:

| Rota | Método | Uso |
|------|--------|-----|
| `/health` | GET | checagem de servidor de pé (tarefa A01) |
| `/auth/cadastro` | POST | cria cliente, devolve token |
| `/auth/login` | POST | valida e-mail/senha, devolve token |
| `/auth/me` | GET | valida se o token ainda é válido |
| `/auth/invalidar-tokens` | POST | derruba todas as sessões — útil pra testar o cenário de "token expirado" sem esperar de verdade |
| `/lojas` | GET | lista de lojas; aceita `?busca=` e `?categoria=`; traz a média das avaliações (`mediaAvaliacao`, `totalAvaliacoes`) |
| `/categorias` | GET | categorias disponíveis para o filtro |
| `/lojas/:id/cardapio` | GET | cardápio da loja, separado por categoria |
| `/admin/lista-vazia` | POST | liga/desliga o retorno vazio — para demonstrar a tela de "nenhuma loja" |
| `/enderecos` | GET / POST | lista e cria endereços do cliente logado |
| `/enderecos/:id` | PUT / DELETE | edita ou remove um endereço |
| `/enderecos/:id/favorito` | POST | marca como favorito (desmarca o anterior) |
| `/carrinho` | GET | carrinho atual do cliente, com totais calculados pelo servidor |
| `/carrinho/itens` | POST | adiciona item; se houver itens de outra loja, devolve `409` a menos que `substituir: true` |
| `/carrinho/itens/:id` | PUT / DELETE | altera quantidade/complementos/observação, ou remove o item |
| `/pedidos/previa` | POST | `{ enderecoId }` → diz se o endereço está na área de entrega, a taxa da faixa e o total |
| `/pedidos` | POST / GET | cria o pedido (recusa do servidor = `422` com `error`) / lista os pedidos do cliente |
| `/pedidos/:id` | GET | estado atual do pedido (a tela de acompanhamento consulta esta rota) |
| `/pedidos/:id/cancelar` | POST | só funciona enquanto o pedido está "aguardando confirmação" (senão `409`) |
| `/pedidos/:id/repetir` | POST | devolve os itens do pedido ao carrinho com os preços de hoje e diz o que ficou indisponível (`409` se o carrinho for de outra loja, a menos que `substituir: true`) |
| `/entregadores/:id/disponibilidade` | GET / PUT | situação online/offline do entregador (`{ online }`) |
| `/entregadores/:id/oferta` | GET | oferta pendente (só se estiver online); `?atual=ID` pergunta por que a oferta que a tela mostrava deixou de valer |
| `/entregadores/:id/ofertas/:oid/aceitar` · `/recusar` | POST | responde à oferta; depois do prazo, `410` "passou para outro entregador" |
| `/entregadores/:id/entregas` | GET | entregas do entregador (`?status=ativas` só as em andamento) |
| `/entregadores/:id/entregas/:eid` | GET | uma entrega (`404` se for de outro entregador) |
| `/entregadores/:id/entregas/:eid/coleta` · `/entrega` · `/insucesso` | POST | confirma a coleta, a entrega, ou registra insucesso (`{ motivo }` obrigatório) |
| `/entregadores/:id/ganhos` | GET | entregas concluídas no dia e o total (`?data=AAAA-MM-DD`, padrão hoje) |
| `/pedidos/:id/avaliacao` | POST | `{ notaLoja, notaEntregador?, comentario? }`: só pedido entregue, uma por pedido (`409` nos outros casos) |

Todos os endpoints de `/enderecos*` e `/carrinho*` exigem o header
`Authorization: Bearer <token>` — os dados ficam guardados por usuário
(pela sessão), não por aparelho.

Para demonstrar os estados da tela de lojas:

```bash
# lista vazia (chame de novo para voltar ao normal)
curl -X POST http://localhost:3000/admin/lista-vazia

# falha de rede: simplesmente pare o mock server (Ctrl+C) e puxe
# a lista para baixo no app
```

Para forçar o cenário de token expirado: com o app logado, rode
`curl -X POST http://localhost:3000/auth/invalidar-tokens` e depois reabra
o app (ou tente qualquer ação que valide o token) — ele deve voltar
sozinho pra tela de login, sem travar.

## Estrutura

```
lib/
  main.dart                          # ponto de entrada
  config/app_config.dart             # endereço da API e rotas (único lugar)
  models/
    loja.dart                        # a loja como vem da API
    cardapio.dart                    # categoria/produto/grupo de complemento
    carrinho.dart                    # carrinho e item do carrinho (valores vêm do servidor)
    endereco.dart                    # endereço do cliente
    pedido.dart                      # pedido, status, pagamento, prévia do fechamento e repetição
    oferta.dart                      # oferta de entrega (entregador)
    entrega.dart                     # entrega, motivos de insucesso e ganhos do dia (entregador)
    avaliacao.dart                   # avaliação do pedido (loja e entregador)
  services/
    token_storage.dart               # guarda/lê/apaga o token no aparelho
    auth_service.dart                # login, cadastro, validação de token
    loja_service.dart                # busca lojas, categorias e cardápio na API
    carrinho_service.dart            # adiciona/altera/remove item do carrinho
    endereco_service.dart            # lista/cria/edita/remove/favorita endereço
    pedido_service.dart              # prévia, criar, consultar, listar, cancelar e repetir pedido
    entregador_service.dart          # disponibilidade, oferta, aceitar e recusar (entregador)
  screens/
    splash_screen.dart               # tela de abertura + checa sessão salva
    error_screen.dart                # tela de erro + botão "tentar novamente"
    profile_select_screen.dart       # escolha entre Cliente / Entregador
    client/
      client_home_screen.dart        # menu do cliente + aba "Minha conta" com Sair
      lojas_screen.dart              # lista de lojas, busca e filtro (aba "Lojas")
      cardapio_screen.dart           # cardápio da loja + resumo do carrinho
      produto_detail_modal.dart      # detalhe do produto: complementos, obs., adicionar/editar no carrinho
      carrinho_screen.dart           # carrinho: itens, quantidade, subtotal
      checkout_screen.dart           # fechamento: resumo, endereço, taxa, total, pagamento
      pedido_acompanhamento_screen.dart # acompanhamento por status (atualiza sozinho)
      pedidos_screen.dart            # aba "Meus pedidos": em andamento + histórico
      avaliacao_screen.dart          # avaliar loja e entregador (uma vez por pedido)
      repetir_pedido.dart            # repetir pedido: avisa preços novos e itens indisponíveis
      enderecos_screen.dart          # lista de endereços (aba "Endereços")
      endereco_form_screen.dart      # criar/editar endereço
      auth/login_screen.dart         # tela de login
      auth/register_screen.dart      # tela de cadastro
    delivery/delivery_home_screen.dart # menu do entregador (sem login ainda)
    delivery/entregas_screen.dart    # chave online/offline + oferta com prazo correndo
    delivery/entrega_screen.dart     # entrega: coleta, entrega e insucesso (com motivo)
    delivery/ganhos_screen.dart      # aba "Ganhos": entregas do dia e total
  widgets/
    placeholder_content.dart         # conteúdo genérico das abas sem regra de negócio
    loja_card.dart                   # card da loja (aberta x fechada, média das avaliações)
    estrelas.dart                    # nota em estrelas (mostrar ou escolher)
mock_server.js                       # servidor de teste (auth + lojas + cardápio + endereços + carrinho)
```

## Onde cada critério de aceite foi atendido

### A01 — Abertura, navegação e menus

| # | Critério | Onde |
|---|----------|------|
| 1 | Tela de abertura com a marca | `screens/splash_screen.dart` |
| 2 | Navegação com menu do cliente e do entregador | `profile_select_screen.dart` + `client/client_home_screen.dart` + `delivery/delivery_home_screen.dart` |
| 3 | Endereço da API em configuração | `config/app_config.dart` (nenhuma URL solta no meio do código) |
| 4 | Sem resposta do servidor → tela de erro + botão de tentar de novo | `screens/error_screen.dart`, disparada pela checagem em `splash_screen.dart` |
| 5 | Roda sem travar ao trocar de tela | Navegação via `Navigator.pushReplacement`, sem estado global que quebre ao trocar de aba |

### A02 — Login e cadastro do cliente

| # | Critério | Onde |
|---|----------|------|
| 1 | Login chama a API de autenticação e guarda o token | `auth/login_screen.dart` → `AuthService.login` → `TokenStorage.salvarToken` |
| 2 | Cadastro cria o cliente pela API e já entra logado | `auth/register_screen.dart` → `AuthService.cadastrar` (usa o token da resposta, ou faz login automático se a API não devolver token) |
| 3 | E-mail ou senha errados mostram mensagem genérica | `AuthService.login` sempre lança `"E-mail ou senha inválidos."`, sem dizer qual campo falhou |
| 4 | Token enviado nas chamadas seguintes + app se mantém logado ao reabrir | `AuthService.tokenValido()` manda o header `Authorization: Bearer <token>` e é chamado pela splash a cada abertura do app |
| 5 | Token expirado ou inválido devolve pra login, sem travar | Se `/auth/me` responde 401, `TokenStorage.limparToken()` é chamado e a splash manda pra `ProfileSelectScreen` |
| 6 | Botão Sair apaga o token do aparelho | Aba "Minha conta" em `client_home_screen.dart` → `AuthService.sair()` |

### A03 — Lista de lojas com busca e categorias

| # | Critério | Onde |
|---|----------|------|
| 1 | Lista vem da API com foto, categoria, tempo e taxa | `services/loja_service.dart` + `models/loja.dart` + `widgets/loja_card.dart` |
| 2 | Aberta e fechada são visualmente distintas, e a fechada não abre | `widgets/loja_card.dart`: card fechado fica com `Opacity(0.45)`, etiqueta "Fechada" e `onTap: null` |
| 3 | A informação de aberta vem do servidor | `Loja.aberta` é lido direto do JSON. Não existe nenhum `DateTime.now()` decidindo isso no app |
| 4 | Busca por nome filtra a lista | `lojas_screen.dart`: campo de busca manda `?busca=` para a API (com espera de 400ms para não chamar a cada letra) |
| 5 | Filtro por categoria funciona e pode ser limpo | Chips de categoria; o chip "Todas" limpa o filtro, e a tela de vazio oferece "Limpar filtros" |
| 6 | Lista vazia e falha de rede têm mensagens diferentes | `_MensagemTela` em `lojas_screen.dart`: ícone e texto distintos para cada caso, e só a falha de rede oferece "Tentar novamente" |

### A04 — Cardápio da loja no app

| # | Critério | Onde |
|---|----------|------|
| 1 | O cardápio vem da API separada por categoria | `services/loja_service.dart` (`getCardapio`) + `screens/client/cardapio_screen.dart` |
| 2 | O produto abre com os grupos de complemento e os preços de cada um | `produto_detail_modal.dart`: cada grupo mostra "Obrigatório · min–max" ou "Opcional · até max" e o preço de cada opção |
| 3 | O limite mínimo e máximo de cada grupo é respeitado na tela | `_toggleOpcao` bloqueia seleção acima do máximo; `_validaLimites` trava o botão de adicionar enquanto o mínimo não for atingido — e o servidor valida de novo (nunca confia só no app) |
| 4 | O preço mostrado soma produto mais complementos escolhidos | `_precoTotal` em `produto_detail_modal.dart`, multiplicado pela quantidade |
| 5 | Produto indisponível aparece marcado e não pode ser adicionado | Etiqueta "Indisponível" na lista e no modal; opções e botão de adicionar ficam desabilitados |

### A05 — Endereços do cliente no app

| # | Critério | Onde |
|---|----------|------|
| 1 | A lista de endereços vem da API e mostra todos os do cliente | `services/endereco_service.dart` (`listarEnderecos`) + `enderecos_screen.dart`, por usuário no mock server |
| 2 | Criar, editar e remover endereço chama a API e a tela reflete o resultado | `endereco_form_screen.dart` (criar/editar) e `_confirmarRemocao` em `enderecos_screen.dart`; a lista só é dada como certa depois que o servidor confirma |
| 3 | Marcar favorito persiste no servidor e desmarca o anterior | `EnderecoService.marcarFavorito` → `POST /enderecos/:id/favorito`; o mock server desmarca todos os outros do mesmo usuário |
| 4 | O favorito vem selecionado por padrão na tela do pedido | `EnderecoService.buscarFavorito()` já pronto para a tela de pedido/checkout usar quando essa tarefa existir |
| 5 | Erro de rede ao salvar mostra mensagem e não perde o que foi digitado | `endereco_form_screen.dart`: no erro, só troca `_erroSalvar` — os `TextEditingController` continuam com o que o cliente digitou, o formulário não fecha |

### A06 — Carrinho com observações e total

| # | Critério | Onde |
|---|----------|------|
| 1 | Adicionar ao carrinho chama a API com quantidade, complementos e observação | `CarrinhoService.adicionarItem` (`POST /carrinho/itens`), acionado pelo botão em `produto_detail_modal.dart` |
| 2 | Os valores exibidos são os que a API devolveu, não somados no aplicativo | `Carrinho`/`ItemCarrinho` só guardam `precoItem`/`subtotal`/`total` vindos do JSON; `carrinho_screen.dart` nunca faz conta de preço, só exibe |
| 3 | Alterar quantidade, editar complementos e remover item atualizam o total | `CarrinhoService.atualizarItem` / `removerItem`, cada um devolve o carrinho já recalculado pelo servidor |
| 4 | Produto de outra loja avisa e só esvazia o carrinho após confirmação | Mock server devolve `409` se a loja for diferente; `produto_detail_modal.dart` mostra o diálogo "Trocar de loja?" e só reenvia com `substituir: true` se o cliente confirmar |
| 5 | O carrinho sobrevive ao fechar e reabrir o aplicativo | O carrinho é guardado no servidor por usuário (não em `SharedPreferences` nem em memória do app) — ao reabrir, `GET /carrinho` devolve o mesmo estado |
| 6 | Carrinho vazio tem tela própria e não deixa avançar | `_MensagemVazia` em `carrinho_screen.dart`; sem itens, o rodapé com o subtotal e o botão "Finalizar pedido" nem aparecem |



### A07 — Fechamento do pedido no app

| # | Critério | Onde |
|---|----------|------|
| 1 | A tela mostra resumo, endereço, taxa e total antes de confirmar | `checkout_screen.dart`: itens do carrinho, endereço (o favorito já vem selecionado), taxa e total vindos da prévia do servidor |
| 2 | Endereço fora da área impede confirmar, com mensagem dizendo o que fazer | `POST /pedidos/previa` devolve `dentroDaArea` e a mensagem; fora da área o botão "Confirmar pedido" fica desabilitado e a mensagem (com os bairros atendidos) aparece no cartão do endereço |
| 3 | Escolhendo dinheiro, o valor do troco é pedido | Campo "Troco para quanto?" (ou "Não preciso de troco"); exige valor ≥ total, e o servidor valida de novo |
| 4 | Confirmar chama a API e o pedido aparece no painel da loja | `PedidoService.criar` → `POST /pedidos`; o mock server mostra o pedido em `GET /painel/pedidos` |
| 5 | Recusa do servidor aparece na tela com a mensagem que ele mandou | Qualquer `4xx` vira `PedidoException(mensagem)` e a caixa vermelha acima do botão mostra o texto do servidor (loja fechou, item esgotou, endereço fora da área); o que o cliente escolheu não se perde |
| 6 | Confirmado, o app vai para a tela de acompanhamento | `pushAndRemoveUntil` → `PedidoAcompanhamentoScreen` (o carrinho já foi esvaziado pelo servidor) |

A taxa de entrega depende da faixa (bairro) do endereço, por isso o carrinho mostra só o
subtotal e o total final é calculado no fechamento — sempre pelo servidor.

### A08 — Acompanhamento do pedido por status

| # | Critério | Onde |
|---|----------|------|
| 1 | A tela mostra o estado atual vindo da API e o tempo estimado | `pedido_acompanhamento_screen.dart`: estado + "Tempo estimado: N min" (ou "a loja ainda vai informar") |
| 2 | A tela se atualiza sozinha quando o estado muda | `Timer.periodic` de 5 s consulta `GET /pedidos/:id`; para sozinho quando o pedido chega a um estado final |
| 3 | Pedido a caminho mostra o nome do entregador | Linha "Entregador: …" quando o status é "a caminho" |
| 4 | Recusado, cancelado ou não entregue mostram o motivo registrado | Cartão vermelho "Motivo" com o texto que o servidor guardou |
| 5 | Cancelar aparece só enquanto o preparo não começou, e chama a API | Botão visível só em "aguardando confirmação" (`StatusPedido.podeCancelar`) → `POST /pedidos/:id/cancelar`; o servidor também recusa (`409`) se o preparo já começou |
| 6 | Falha de rede não apaga o que já estava na tela | Se a consulta falha, o pedido mostrado é mantido e aparece só um aviso amarelo; a tela continua tentando |

#### Simulando a loja no mock server

Não existe painel da loja de verdade neste projeto; o mock server tem rotas para fazer o papel dela
(troque `ID` pelo número do pedido):

```bash
# ver os pedidos que chegaram na loja
curl http://localhost:3000/painel/pedidos

# loja confirma e informa o tempo
curl -X POST localhost:3000/admin/pedidos/ID/status -H "Content-Type: application/json" \
  -d '{"status":"em_preparo","tempoEstimadoMin":30}'

# saiu para entrega
curl -X POST localhost:3000/admin/pedidos/ID/status -H "Content-Type: application/json" \
  -d '{"status":"a_caminho","entregadorNome":"Carlos Silva","tempoEstimadoMin":12}'

# recusado / não entregue (exigem motivo)
curl -X POST localhost:3000/admin/pedidos/ID/status -H "Content-Type: application/json" \
  -d '{"status":"recusado","motivo":"Loja sem estoque."}'

# provocar recusas no fechamento: loja fecha / item esgota
curl -X POST localhost:3000/admin/lojas/1/aberta -H "Content-Type: application/json" -d '{"aberta":false}'
curl -X POST localhost:3000/admin/produtos/p1/disponivel -H "Content-Type: application/json" -d '{"disponivel":false}'
```

Status aceitos: `aguardando_confirmacao`, `em_preparo`, `pronto`, `a_caminho`, `entregue`,
`recusado`, `cancelado`, `nao_entregue`. Bairros atendidos no mock: Centro e Boa Viagem
(a Pizza Express também atende Casa Forte); qualquer outro é "fora da área".

### A09 — Histórico de pedidos e repetir pedido

| # | Critério | Onde |
|---|----------|------|
| 1 | O histórico lista os pedidos do cliente com data, loja, itens, total e estado | `pedidos_screen.dart` (aba "Meus pedidos"): "Em andamento" e "Histórico", cada cartão com loja, nº, estado, itens, data e total — vindos de `GET /pedidos` |
| 2 | O pedido antigo mostra os preços praticados na época, não os atuais | O servidor guarda o pedido como um retrato do momento (itens, taxa e total); `pedido_acompanhamento_screen.dart` exibe esses valores, com a legenda "Valores do momento em que o pedido foi feito" |
| 3 | Repetir pedido devolve os itens ao carrinho com os preços atuais | `POST /pedidos/:id/repetir` remonta o carrinho a partir do cardápio de hoje; o diálogo mostra os preços que mudaram. Botão "Repetir" no histórico e no detalhe de pedido encerrado (`repetir_pedido.dart`) |
| 4 | Item indisponível é avisado ao repetir e não entra calado | O diálogo de resultado lista cada item que ficou de fora e o motivo (indisponível, saiu do cardápio, opções mudaram); se nada puder voltar, o carrinho não é alterado |
| 5 | Cliente sem pedido nenhum vê uma tela própria, não uma lista vazia | `pedidos_screen.dart`: tela "Você ainda não fez nenhum pedido" com botão "Ver lojas" |

Se o carrinho tiver itens de outra loja, repetir segue a mesma regra do A06: avisa e só esvazia
depois de confirmar (`409` → diálogo → `substituir: true`).

Para ver "preço da época" x "preço de hoje" no mock: faça um pedido, mude o preço e repita.

```bash
curl -X POST localhost:3000/admin/produtos/p1/preco -H "Content-Type: application/json" -d '{"precoBase":30}'
curl -X POST localhost:3000/admin/produtos/p1/disponivel -H "Content-Type: application/json" -d '{"disponivel":false}'
```

### A10 — App do entregador: disponibilidade e oferta

| # | Critério | Onde |
|---|----------|------|
| 1 | A chave online/offline grava a situação pela API | `EntregadorService.definirDisponibilidade` → `PUT /entregadores/:id/disponibilidade`; a chave só muda quando o servidor confirma (se falhar, volta e avisa) e a situação é lida da API ao abrir a tela |
| 2 | Estando online, a oferta aparece com origem, destino, distância e valor | `entregas_screen.dart`: cartão "Nova oferta de entrega" (busca a oferta a cada 3 s enquanto online) |
| 3 | O prazo aparece correndo na tela até acabar | Contagem regressiva `mm:ss` + barra de progresso, que fica vermelha nos últimos 10 s |
| 4 | Aceitar chama a API e leva à tela da entrega | `POST .../ofertas/:id/aceitar` → `entrega_screen.dart` |
| 5 | Recusar chama a API e a oferta some da tela | `POST .../ofertas/:id/recusar` |
| 6 | Prazo estourado tira a oferta da tela e avisa que passou para outro | Ao zerar, a oferta sai e aparece o aviso "O prazo acabou e a oferta passou para outro entregador." O servidor é quem manda no prazo: se o entregador tocar em Aceitar no limite, a API responde `410` e a tela mostra a mesma verdade; se a oferta for repassada antes do prazo, a consulta periódica também a remove com o aviso |

O entregador ainda não tem login: o app usa o entregador `e1` do mock (troque com
`--dart-define=ENTREGADOR_ID=...`). Para mandar ofertas ao entregador (simula o sistema de despacho):

```bash
# oferta genérica, 30 s de prazo
curl -X POST localhost:3000/admin/ofertas -H "Content-Type: application/json" -d '{}'

# oferta de um pedido real, com prazo curto para ver o aviso de "passou para outro"
curl -X POST localhost:3000/admin/ofertas -H "Content-Type: application/json" \
  -d '{"pedidoId":"1","prazoSegundos":15,"valor":12.5,"distanciaKm":3.1}'

# passa a oferta para outro entregador antes do prazo
curl -X POST localhost:3000/admin/ofertas/ID/repassar
```

### A11 — App do entregador: coleta, entrega e insucesso

| # | Critério | Onde |
|---|----------|------|
| 1 | A tela da entrega mostra origem, destino com ponto de referência e itens | `entrega_screen.dart`: loja e endereço de retirada, endereço de entrega com o ponto de referência em destaque, e a lista de itens (com complementos e observação) |
| 2 | Confirmar coleta chama a API e o pedido passa a A caminho | `POST /entregadores/:id/entregas/:eid/coleta`; o servidor muda o pedido do cliente para "a caminho" (o acompanhamento do cliente atualiza sozinho) |
| 3 | Confirmar entrega chama a API e fecha o pedido como Entregue | `POST .../entrega`, com confirmação antes; só vale depois da coleta (senão `409`); o pedido vira "entregue" |
| 4 | Registrar insucesso exige escolher o motivo antes de enviar | Painel com os motivos; o botão "Registrar" só liga depois de escolher, e o servidor também recusa motivo vazio ou inválido (`400`). O pedido vira "não entregue" com o motivo, que o cliente vê |
| 5 | A tela de ganhos mostra as entregas do dia e o valor total | `ganhos_screen.dart` → `GET /entregadores/:id/ganhos`: total e quantidade somados pelo servidor, só entregas concluídas (insucesso não conta) |
| 6 | O entregador só vê e toca as entregas que são dele | Todas as rotas de entrega ficam sob `/entregadores/:id/...` e o servidor responde `404` para entrega de outro entregador (listar, ver e confirmar) |

Detalhes: com uma entrega em andamento o entregador não recebe nem aceita ofertas novas, e a aba
"Entregas" mostra o cartão "Entrega em andamento" para ele voltar a ela (inclusive depois de fechar o app).

Para testar o fluxo completo (cliente e entregador juntos):

```bash
# 1. o cliente faz um pedido no app (ex.: pedido 1) e o entregador fica online na aba "Entregas"
# 2. manda a oferta ligada ao pedido (a entrega leva os itens e o ponto de referência reais)
curl -X POST localhost:3000/admin/ofertas -H "Content-Type: application/json" -d '{"pedidoId":"1","valor":12.5}'
# 3. no app do entregador: Aceitar -> Confirmar coleta -> Confirmar entrega (ou Registrar insucesso)
# 4. provar que um entregador não mexe na entrega do outro (e2 é o outro entregador do mock)
curl localhost:3000/entregadores/e2/entregas/1          # 404
curl -X POST localhost:3000/entregadores/e2/entregas/1/coleta   # 404
```

Ofertas sem `pedidoId` usam dados de exemplo (itens e ponto de referência de teste).

### A12 — Avaliação da loja e do entregador

| # | Critério | Onde |
|---|----------|------|
| 1 | A avaliação só abre para pedido entregue | `avaliacao_screen.dart` mostra "só é possível avaliar pedidos entregues" para qualquer outro estado, e `POST /pedidos/:id/avaliacao` responde `409` |
| 2 | Nota de 1 a 5 para a loja e para o entregador, com comentário opcional | Estrelas para a loja e para o entregador (se o pedido teve entregador) + comentário opcional; o botão só liga com as notas escolhidas, e o servidor valida de novo (`400`) |
| 3 | Enviar chama a API e a tela passa a mostrar a avaliação dada | `PedidoService.avaliar` → a tela troca o formulário por "Obrigado pela avaliação!" com as notas e o comentário. Se o envio falhar, o que foi marcado e escrito continua na tela |
| 4 | Pedido já avaliado não abre a tela de avaliar de novo | O pedido já vem do servidor com a avaliação; no detalhe e no histórico não existe botão "Avaliar" e o cartão mostra "Sua avaliação". Se alguém tentar avaliar de novo, o servidor responde `409` e a tela mostra a avaliação que ficou registrada |
| 5 | A média da loja aparece na lista de lojas do aplicativo | `GET /lojas` traz `mediaAvaliacao` e `totalAvaliacoes` (calculados pelo servidor) e o `LojaCard` mostra a estrela com a média, ou "Sem avaliações" |

Quando o pedido muda para "entregue" com o cliente olhando o acompanhamento, a tela de avaliação
abre sozinha. No mock, as lojas 1 e 2 já têm avaliações de exemplo e as outras mostram "Sem avaliações".

## Menus por perfil

- **Cliente** — Lojas · Meus pedidos · Endereços · Minha conta (login/cadastro obrigatório antes de entrar)
- **Entregador** — Entregas · Ganhos · Minha conta (ainda sem login — não é o escopo desta tarefa)

## Próximos passos (fora do escopo destas tarefas)

- Login/autenticação do entregador (hoje o app usa um entregador fixo do mock)
- Painel da loja de verdade (hoje as rotas `/admin/*` e `/painel/*` do mock fazem esse papel)
- Atualização em tempo real por push/WebSocket (hoje o acompanhamento consulta a API a cada 5 s)
- Endpoints reais no back-end (o app já está pronto para consumi-los, ajustando só `app_config.dart`)