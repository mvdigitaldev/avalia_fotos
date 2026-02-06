---
name: Performance Feed Supabase
overview: "Plano executável de otimização do feed (Flutter + Supabase) em PRs pequenos: select mínimo, comments_count local, foto do dia em batch, instrumentação, idempotência de push e demais itens com critérios de aceite e riscos."
todos:
  - id: pr1-select-minimo
    content: "PR1 - Select mínimo no feed (remover select *)"
  - id: pr2-comments-count-local
    content: "PR2 - comments_count local após comentar (remover getPhotoById)"
  - id: pr3-foto-do-dia-batch
    content: "PR3 - Foto do dia em batch (1 query por página)"
  - id: instrumentacao
    content: "Instrumentação antes/depois (contador + Supabase)"
isProject: false
---

# Plano executável – Performance Feed (PRs pequenos)

## Ordem dos PRs e arquivos

| PR | Objetivo | Arquivos prováveis |
|----|----------|--------------------|
| **PR1** | Select mínimo no feed (remover `select *`) | `lib/services/photo_service.dart`, `lib/models/photo_model.dart` (se precisar) |
| **PR2** | Atualizar `comments_count` no estado local; remover `getPhotoById` após comentar | `lib/pages/feed/feed_widget.dart` |
| **PR3** | Foto do dia em batch (1 query por página) | `lib/services/photo_of_the_day_service.dart`, `lib/pages/feed/feed_widget.dart`, Supabase migration (RPC ou view) |
| **PR4** | Instrumentação por pontos críticos (evitar interceptor HTTP) | Wrapper/helper em Feed load, Feed scroll, Like, Comment add |
| **PR5** | Idempotência de push com `notification_sent_log` | Supabase: trigger `send_push_on_notification_created` |
| **PR6** | Índices (se faltarem) | Supabase migration |
| **PR7** | Cache de feed (TTL, sem refetch ao voltar) | Novo provider/serviço, `lib/pages/feed/feed_widget.dart` |
| **PR8** | Fila + cron para notificações push (batch) | Supabase: tabela, cron, trigger |

---

## PR1 – Select mínimo no feed

**Objetivo:** Reduzir payload e eliminar `select('*')` na listagem do feed.

**O que muda (resumo):**
- Em `getFeedPhotos`, trocar `select('*', 'users:user_id (...)')` por lista explícita de colunas de `photos` usadas no card do feed.
- Manter join `users:user_id (username, avatar_url)`.
- Manter RPC `get_users_paid_plan_status` e batch de likes como estão (sem refactor grande).

**Flutter:**
- **Arquivo:** [lib/services/photo_service.dart](lib/services/photo_service.dart)
- **Função:** `getFeedPhotos`
- **Alteração:** Substituir a string do `.select()` por algo como:
  `id, user_id, image_url, thumbnail_url, score, recado, is_shared, likes_count, comments_count, created_at, categoria, users:user_id (username, avatar_url)`.
- Garantir que [lib/models/photo_model.dart](lib/models/photo_model.dart) `fromJson` não exija colunas removidas (ex.: `positive_points`, `improvement_points`, `observacao` podem ser listas vazias ou opcionais quando ausentes).

**Supabase:**
- Nenhuma alteração (apenas o cliente passa a pedir menos colunas).

**Critério de aceite:**
- Feed continua exibindo corretamente (imagem, autor, score, recado, likes_count, comments_count, data).
- Requests por página do feed permanecem 3 (1 feed + 1 RPC paid plan + 1 batch likes); tamanho da resposta da query do feed reduz (medir bytes ou via Network do Supabase).
- Nenhum `select('*')` em `getFeedPhotos`.
- **Extra:** Zero crashes do tipo "Null is not a subtype" — `PhotoModel.fromJson` com fallbacks (`?? []`, `?? null`, parse seguro de datas/números).

**Riscos e como testar:**
- **Risco:** Card do feed usa alguma coluna que foi removida e quebra (ex. null em campo obrigatório no model).
- **Teste:** Abrir feed, scroll, pull-to-refresh; abrir foto do feed e voltar; checar logs/erros. Testar com foto com e sem `recado`/`categoria`.

---

## PR2 – comments_count local (remover getPhotoById após comentar)

**Objetivo:** Evitar 1 request extra ao Supabase após adicionar comentário; atualizar apenas o estado local do feed.

**O que muda (resumo):**
- Bottom sheet **retorna** `didAddComment` ao fechar (ex.: ao tapar no X); no feed, ao receber `true`, incrementar `comments_count` localmente. Evita callback perdido se o sheet fechar rápido.
- Remover `onCommentAdded` e `_refreshPhotoComments` que usam `getPhotoById`.

**Flutter:**
- **Arquivo:** [lib/pages/feed/feed_widget.dart](lib/pages/feed/feed_widget.dart)
- **Onde:** 
  - `_CommentsBottomSheet`: estado `_didAddComment`; em `_submitComment` (sucesso) setar `_didAddComment = true`; no botão fechar fazer `Navigator.pop(context, _didAddComment)`.
  - `_showCommentsBottomSheet`: `final didAddComment = await showModalBottomSheet<bool>(...)`; se `didAddComment == true`, `safeSetState` incrementando `commentsCount` do item correspondente em `_model.photos`.
  - Remover parâmetro `onCommentAdded` e a função `_refreshPhotoComments`.

**Supabase:**
- Nenhuma alteração.

**Critério de aceite:**
- Ao adicionar um comentário no bottom sheet, o número de comentários no card da foto no feed atualiza imediatamente sem nova requisição.
- Requests: após comentar, não deve haver chamada a `getPhotoById` (verificar via instrumentação ou log).

**Riscos e como testar:**
- **Risco:** Se o usuário adicionar comentário e outro apagar ao mesmo tempo, o count pode ficar desatualizado até o próximo refresh — aceitável.
- **Teste:** Abrir comentários, adicionar comentário, fechar sheet; conferir que o número no card subiu e que não houve request extra (instrumentação PR4).

---

## PR3 – Foto do dia (zero request extra)

**Regra confirmada:** Badge = “foto do dia **na data da própria foto**” (photo_of_the_day.selected_date = date(photo.created_at)), não “foto do dia hoje”. Como as datas variam por foto, a opção escolhida foi **incluir boolean na query do feed** (view com EXISTS/join), em vez de batch RPC — zero request extra.

**O que muda (resumo):**
- View `feed_photos` no Supabase: colunas mínimas do feed + `is_photo_of_the_day` (EXISTS em `photo_of_the_day` onde `photo_id = p.id` e `selected_date = (p.created_at)::date`).
- `getFeedPhotos` passa a usar `.from('feed_photos')` e inclui `is_photo_of_the_day` no select.
- No feed, badge usa `photo.isPhotoOfTheDay == true` (valor vindo da query); removido FutureBuilder e N chamadas a `_isPhotoOfTheDay`.

**Flutter:**
- **Arquivos:** [lib/services/photo_service.dart](lib/services/photo_service.dart), [lib/pages/feed/feed_widget.dart](lib/pages/feed/feed_widget.dart), [lib/models/photo_model.dart](lib/models/photo_model.dart)
- **PhotoModel:** campo opcional `isPhotoOfTheDay` (bool?); `fromJson` lê `json['is_photo_of_the_day']`.
- **FeedWidget:** em `_buildImageWidget`, trocar FutureBuilder por `if (photo.isPhotoOfTheDay == true) Positioned(..., PhotoTrophyBadge(...))`.

**Supabase:**
- **Migration:** `CREATE VIEW feed_photos AS SELECT p.id, p.user_id, ..., EXISTS (SELECT 1 FROM photo_of_the_day pod WHERE pod.photo_id = p.id AND pod.selected_date = (p.created_at AT TIME ZONE 'UTC')::date) AS is_photo_of_the_day FROM photos p WHERE p.is_shared = true`.

**Critério de aceite:**
- Por página do feed, existe no máximo 1 chamada relacionada a “foto do dia” (a do batch), em vez de N.
- Badge “foto do dia” continua aparecendo corretamente nas fotos que forem foto do dia.
- Requests por scroll (primeira página): redução de N para 1 para foto do dia (N = número de fotos na página).

**Riscos e como testar:**
- **Risco:** Datas em timezone (created_at com timezone vs date no photo_of_the_day). Usar mesma regra de “data” que já existe em `isPhotoOfTheDay` (date only).
- **Teste:** Feed com e sem fotos do dia; trocar de página e verificar que não há múltiplas chamadas `get_photo_of_the_day` ou `isPhotoOfTheDay` por item.

---

## PR4 – Instrumentação (medir antes/depois)

**Objetivo:** Contador de requests por tela/ação para validar redução de chamadas.

**O que implementar:**
- **No app (Flutter):**
  - Interceptor ou wrapper no cliente Supabase que registra cada request (from/table, rpc name, ou path de Edge Function) e opcionalmente um “contexto” (ex.: tela atual: feed, photo_detail, etc.).
  - Log em debug: por sessão ou por tela, número de requests (ex.: “Feed: 3 requests na carga inicial”, “Feed: +1 ao scroll”, “PhotoDetail: 2 requests”).
  - Pode ser um `RequestCounter` que expõe `increment(String label)` e `getCount(String label)` / `reset()` e que seja chamado a partir do SupabaseService ou de um interceptor de funções que fazem `client.from(...).select()` / `client.rpc()`.
- **Arquivos prováveis:** [lib/services/supabase_service.dart](lib/services/supabase_service.dart) (ou extensão do client), novo `lib/utils/request_counter.dart` ou `lib/services/request_logger.dart`; opcionalmente passar “contexto de tela” a partir das páginas (ex.: Feed, PhotoDetail).

**Métricas Supabase (dashboard):**
- **Database:** Requests por minuto/hora; tamanho de resposta (se disponível).
- **Edge Functions:** Invocações por função (ex.: `send-push-notification`) por período.
- Documentar no PR ou em doc interno: “Antes: X requests ao abrir feed e dar scroll em 2 páginas; depois: Y requests”.

**Critério de aceite:**
- Em build de debug, ao usar feed e comentários, é possível ver no log quantas chamadas foram feitas (por contexto/tela).
- Instrução breve no README ou em comentário de como ativar/ler a métrica para “antes/depois”.

**Riscos e como testar:**
- **Risco:** Overhead em produção — manter contador apenas em debug ou atrás de feature flag.
- **Teste:** Abrir feed, scroll, abrir comentários e comentar; verificar que os números batem com o esperado (ex.: PR2 reduz em 1 a contagem após comentar).

---

## PR5 – Idempotência de push com `notification_sent_log`

**Cuidado:** Inserir no log “antes” evita duplicação mas pode perder push se a Edge Function falhar. Preferível: log com status (pending/sent/failed) em 2 fases. Se não mexer nisso agora: pelo menos **ON CONFLICT DO NOTHING após o envio** (inserir em `notification_sent_log` só depois de chamar a Edge Function com sucesso).

**Objetivo:** Reforçar que o envio de push seja idempotente e reduzir duplicações antes de implementar fila/cron, aproveitando `notification_sent_log`.

**O que muda (resumo):**
- O trigger `send_push_on_notification_created` já verifica `notification_sent_log` antes de enviar e insere no log após enviar. Revisar para garantir:
  - Condição “só envia se não existe em notification_sent_log” no início (já existe).
  - Inserção em `notification_sent_log` com `ON CONFLICT (notification_id) DO NOTHING` para evitar race entre duas execuções do trigger para a mesma notificação (se houver unique em `notification_id`).
- Opcional: usar `SELECT ... FOR UPDATE SKIP LOCKED` ou lock por notification_id ao processar, para evitar envio duplicado em concorrência.

**Supabase:**
- **Arquivo:** Nova migration (ex.: `strengthen_notification_sent_log_idempotency.sql`).
- **Alterações:** 
  - Garantir UNIQUE em `notification_sent_log(notification_id)` se ainda não existir.
  - No trigger: manter a checagem `EXISTS (SELECT 1 FROM notification_sent_log WHERE notification_id = NEW.id)` e o `INSERT ... ON CONFLICT (notification_id) DO NOTHING` antes (ou logo após) chamar `call_send_push_notification`, para que em caso de retry não envie de novo.
  - Ordem sugerida: 1) Checar se já está em notification_sent_log; 2) Se não, inserir em notification_sent_log com ON CONFLICT DO NOTHING; 3) Se a inserção “pegou” (e.g. verificar que agora existe), chamar envio. Assim, quem inserir primeiro ganha e envia; os outros não enviam. (Ou manter lógica atual e apenas adicionar UNIQUE + ON CONFLICT se faltar.)

**Flutter:**
- Nenhuma alteração.

**Critério de aceite:**
- Para uma mesma notificação (mesmo INSERT em `notifications`), a Edge Function de push é chamada no máximo uma vez.
- Duplicação de notificação (ex.: trigger disparado duas vezes por bug ou retry) não gera dois pushes para o mesmo notification_id.

**Riscos e como testar:**
- **Risco:** Lock ou ordem de operações pode atrasar envio em alta concorrência — aceitável para notificação push.
- **Teste:** Simular like/comment e verificar no dashboard de Edge Functions que há uma invocação por notificação; forçar (se possível) situação de concorrência e verificar idempotência.

---

## PR6 – Índices (se faltarem)

**Objetivo:** Garantir índices que sustentem as queries do feed e batch de likes/comments.

**Estado atual (já existem):**
- `photos`: `idx_photos_shared_created (is_shared, created_at DESC)`.
- `likes`: `idx_likes_user (user_id)`, unique `(photo_id, user_id)`.
- `comments`: `idx_comments_photo (photo_id, created_at DESC)`.

**Supabase:**
- Migration apenas se, após medição, alguma query aparecer lenta. Possível índice adicional: `likes (user_id, photo_id)` para o batch “likes do usuário nas fotos da página” (já coberto por idx_likes_user para filtro por user_id e depois inFilter photo_id).

**Critério de aceite:**
- Queries do feed e do batch de likes permanecem dentro de tempo aceitável (ex.: < 500 ms no p99).

**Riscos:** Quase nenhum; criação de índice é online em Postgres.

---

## PR7 – Cache de feed (TTL, sem refetch ao voltar)

**Objetivo:** Ao voltar para a tela do feed (ex.: após photo-detail), não refazer a primeira página se o cache for válido (TTL ex.: 5 min).

**Flutter:**
- Novo provider ou singleton (ex.: `FeedCache` ou `FeedStateHolder`) que guarda: `List<PhotoModel> photos`, `currentPage`, `hasMore`, `DateTime? lastFetched`.
- Na tela do feed: em `initState` (ou equivalente), se houver cache com `lastFetched` dentro do TTL, popular `_model.photos` (e estado de paginação) a partir do cache e não chamar `_loadFeed()` na primeira página; pull-to-refresh continua limpando cache e recarregando.
- Invalidação: apenas no refresh explícito; like/comment já atualizam estado local.

**Supabase:** Nenhuma alteração.

**Critério de aceite:**
- Navegar Feed → Photo Detail → Voltar: não há nova requisição de feed se TTL não expirou.
- Pull-to-refresh ou botão “Atualizar” invalidam e recarregam.

**Riscos:** Estado “antigo” até TTL ou refresh; aceitável. Testar com TTL curto (ex.: 1 min) primeiro.

---

## PR8 – Fila + cron para notificações push (batch)

**Objetivo:** Reduzir chamadas à Edge Function de push: em vez de 1 por like/comment, processar em batch por usuário (ou por lote) via fila e cron.

**Supabase:**
- Nova tabela `notification_push_queue` (user_id, title, body, data, created_at, processado opcional).
- Trigger em `notifications`: em vez de chamar `call_send_push_notification`, fazer `INSERT INTO notification_push_queue`.
- Job pg_cron (ex.: a cada 1–2 min): agregar por user_id (e talvez tipo), montar uma mensagem ou lote e chamar a Edge Function uma vez por usuário (ou uma chamada com array na EF).
- Marcar itens da fila como processados para não reenviar.

**Flutter:** Nenhuma alteração.

**Critério de aceite:**
- N likes/comments para o mesmo usuário em 1 minuto geram 1 (ou poucas) invocações da Edge Function em vez de N.
- Notificações ainda são entregues (com delay aceitável de até 1–2 min).

**Riscos:** Atraso no push; testes de carga para garantir que o cron processa a fila a tempo.

---

## Resumo das 3 primeiras implementações (maior impacto, menor risco)

1. **PR1 – Select mínimo no feed:** Só altera a string do select e garante que o model aceite campos opcionais/ausentes. Reduz payload e cumpre “select só com campos necessários”.
2. **PR2 – comments_count local:** Só altera o callback no feed para atualizar estado local e remove getPhotoById nesse fluxo. Reduz 1 request por comentário.
3. **PR3 – Foto do dia em batch:** Nova RPC + uso no feed + cache no widget; remove N chamadas por página. Reduz N–1 requests por página.

Ordem recomendada: **PR1 → PR2 → PR3**, depois instrumentação (PR4) e idempotência push (PR5).

---

## Regras obrigatórias (revisão de PRs)

- Usar **select só com campos necessários** (sem `*` em listagens).
- **Não** buscar dados em toda mudança de tela; apenas init e refresh explícito no feed.
- **Não** introduzir Realtime no feed.
- Evitar refactors grandes nos PRs iniciais; mudanças cirúrgicas por PR.

---

## Instrumentação sugerida (resumo)

| Onde | O que medir |
|------|-------------|
| **App (Flutter)** | Contador de requests por “contexto” (ex.: Feed carga, Feed scroll, PhotoDetail, Comentário adicionado). Log em debug com rótulo e contagem. |
| **Supabase Database** | Dashboard: requests/min, tamanho de resposta (quando disponível). Comparar antes/depois dos PRs. |
| **Supabase Edge Functions** | Invocações por função (ex.: send-push-notification) por período; reduzir após PR5 e PR8. |

Antes de PR1/2/3: anotar “baseline” (ex.: X requests ao abrir feed e dar 2 scrolls; Y requests ao abrir comentários e adicionar 1 comentário). Depois: comparar com os mesmos passos.
