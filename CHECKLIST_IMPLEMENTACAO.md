# Checklist de Implementação - Próximos Passos

## ✅ Configuração Completa

- [x] Banco de dados Supabase configurado
- [x] Edge Function `evaluate-photo` criada e configurada
- [x] Bucket `photos` criado
- [x] Chave OpenAI configurada
- [x] Serviços Flutter criados
- [x] Modelos de dados criados
- [x] Login funcionando

## 🎯 Próximos Passos Imediatos

### 1. Testar Configuração Básica

```bash
# Instalar dependências
flutter pub get

# Verificar erros
flutter analyze

# Executar app
flutter run
```

### 2. Implementar Telas (Ordem de Prioridade)

#### 🔴 Prioridade CRÍTICA

**Tela de Avaliação** (`lib/pages/avalia/avalia_widget.dart`)
- [ ] Adicionar image picker (galeria/câmera)
- [ ] Mostrar preview da imagem selecionada
- [ ] Implementar upload para Storage
- [ ] Chamar Edge Function para avaliação
- [ ] Mostrar animação durante processamento
- [ ] Exibir resultado (nota, pontos positivos, melhorias)
- [ ] Permitir compartilhar ou não (switch já existe)

**Feed** (`lib/pages/feed/feed_widget.dart`)
- [ ] Buscar fotos compartilhadas do banco
- [ ] Implementar lista com paginação
- [ ] Mostrar imagem, nota, usuário
- [ ] Implementar curtir/descurtir
- [ ] Implementar comentários
- [ ] Implementar compartilhar

#### 🟡 Prioridade ALTA

**Painel** (`lib/pages/painel/painel_widget.dart`)
- [ ] Buscar dados do usuário atual
- [ ] Exibir pontuação mensal
- [ ] Exibir total de fotos avaliadas
- [ ] Exibir posição no ranking

**Histórico** (`lib/pages/historico/historico_widget.dart`)
- [ ] Grid de fotos do usuário
- [ ] Paginação infinita
- [ ] Filtros (todas/compartilhadas/privadas)
- [ ] Modal com detalhes da avaliação

**Ranking** (`lib/pages/ranking/ranking_widget.dart`)
- [ ] Top 10 usuários do mês
- [ ] Melhores fotos do mês
- [ ] UI adequada com medalhas/posições

### 3. Testes Essenciais

- [ ] Criar conta de teste
- [ ] Fazer login
- [ ] Upload de foto
- [ ] Avaliação funcionando
- [ ] Foto aparecendo no feed (se compartilhada)
- [ ] Curtir funcionando
- [ ] Comentar funcionando

### 4. Políticas do Storage

Verificar no dashboard do Supabase:
- [ ] Bucket `photos` existe
- [ ] Política de upload configurada (usuários autenticados podem fazer upload)
- [ ] Política de leitura configurada (fotos públicas podem ser lidas)

## 📋 Comandos Úteis

```bash
# Ver logs da Edge Function
# Acesse: https://supabase.com/dashboard/project/yulxxamlfxujclnzzcjb/functions/evaluate-photo/logs

# Ver tabelas no banco
# Acesse: https://supabase.com/dashboard/project/yulxxamlfxujclnzzcjb/editor

# Ver Storage
# Acesse: https://supabase.com/dashboard/project/yulxxamlfxujclnzzcjb/storage/buckets
```

## 🚀 Começar Agora

Vou implementar a tela de Avaliação primeiro, que é a mais crítica. Depois seguimos com as outras.

