# Guia de Implementação - AvaliaFotos

## Status da Implementação

### ✅ Concluído

1. **Banco de Dados Supabase**
   - Tabelas criadas: users, photos, likes, comments, user_monthly_scores
   - Índices otimizados para performance
   - RLS (Row Level Security) configurado
   - RPC Functions para atualização de scores

2. **Edge Function**
   - Função `evaluate-photo` criada e deployada
   - Integração com OpenAI GPT-4 Vision
   - Processamento de imagens e avaliação

3. **Serviços Flutter**
   - `SupabaseService` - Cliente Supabase singleton
   - `AuthService` - Autenticação (login, registro, logout)
   - `StorageService` - Upload de imagens
   - `PhotoService` - CRUD de fotos, feed, histórico
   - `AIEvaluationService` - Integração com Edge Function
   - `RankingService` - Rankings mensais

4. **Modelos**
   - `UserModel` - Modelo de usuário
   - `PhotoModel` - Modelo de foto
   - `EvaluationResultModel` - Resultado da avaliação
   - `RankingItemModel` - Item do ranking

5. **Autenticação**
   - Tela de login integrada com Supabase Auth
   - Navegação após login

### 🔄 Em Andamento / Pendente

1. **Tela de Avaliação** (`lib/pages/avalia/avalia_widget.dart`)
   - Integrar image picker
   - Upload de imagem
   - Chamada da Edge Function
   - Exibição de resultado

2. **Feed** (`lib/pages/feed/feed_widget.dart`)
   - Lista de fotos compartilhadas
   - Paginação infinita
   - Curtir/comentar/compartilhar

3. **Painel** (`lib/pages/painel/painel_widget.dart`)
   - Estatísticas do usuário
   - Pontuação mensal
   - Posição no ranking

4. **Histórico** (`lib/pages/historico/historico_widget.dart`)
   - Grid de fotos do usuário
   - Filtros
   - Modal com detalhes

5. **Ranking** (`lib/pages/ranking/ranking_widget.dart`)
   - Top 10 usuários do mês
   - Melhores fotos do mês

## Configuração Necessária

### 1. Variáveis de Ambiente

O projeto já está configurado com as credenciais do Supabase, mas para produção, configure via:

```bash
flutter run --dart-define=SUPABASE_URL=https://yulxxamlfxujclnzzcjb.supabase.co --dart-define=SUPABASE_ANON_KEY=sua_chave_aqui
```

### 2. Supabase Storage

Crie o bucket `photos` no Supabase Storage:
1. Acesse o dashboard do Supabase
2. Vá em Storage
3. Crie um novo bucket chamado `photos`
4. Configure políticas de acesso:
   - Public: false (para uploads autenticados)
   - Allowed MIME types: image/jpeg, image/png, image/webp

### 3. OpenAI API Key

Configure a chave da OpenAI na Edge Function:
1. Acesse o dashboard do Supabase
2. Vá em Edge Functions > evaluate-photo
3. Configure a variável de ambiente: `OPENAI_API_KEY`

### 4. Instalar Dependências

```bash
flutter pub get
```

## Próximos Passos

1. **Completar implementação das telas** seguindo o padrão já estabelecido no login
2. **Testar fluxo completo** de avaliação de fotos
3. **Implementar otimizações** (cache, paginação, etc.)
4. **Adicionar tratamento de erros** global
5. **Testes** em diferentes dispositivos

## Estrutura de Arquivos

```
lib/
├── config/
│   └── supabase_config.dart
├── models/
│   ├── user_model.dart
│   ├── photo_model.dart
│   ├── evaluation_result_model.dart
│   └── ranking_item_model.dart
├── services/
│   ├── supabase_service.dart
│   ├── auth_service.dart
│   ├── storage_service.dart
│   ├── photo_service.dart
│   ├── ai_evaluation_service.dart
│   └── ranking_service.dart
├── pages/
│   ├── avalia/
│   │   ├── avalia_widget.dart (pendente integração completa)
│   │   └── avalia_state.dart
│   ├── feed/
│   │   └── feed_widget.dart (pendente integração)
│   ├── painel/
│   │   └── painel_widget.dart (pendente integração)
│   ├── historico/
│   │   └── historico_widget.dart (pendente integração)
│   └── ranking/
│       └── ranking_widget.dart (pendente integração)
└── login/
    └── login_widget.dart (✅ implementado)
```

## Notas Importantes

- O sistema de pontuação funciona conforme especificado: `monthly_score += (score/2) + 2`
- As fotos só aparecem no feed se `is_shared = true`
- O ranking é calculado mensalmente
- Todas as queries estão otimizadas com índices apropriados

