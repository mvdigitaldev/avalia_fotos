# Verificação do fluxo de reset de senha - AvaliaFotos

## Diagnóstico do erro "Link inválido ou expirado"

O erro ocorre porque o Supabase está enviando um **código PKCE** (`?code=...`) no link, mas o `exchangeCodeForSession` **falha** quando:

1. **O fluxo foi iniciado no app Flutter** (celular)
2. **O link abre no navegador** (site)
3. **O code verifier fica no app** – o navegador não tem como trocar o `code` pela sessão

No fluxo PKCE, o `code` só pode ser trocado junto com o `code_verifier` gerado quando o fluxo começou. Como o fluxo começou no app e o link abre no site, o verifier não existe no navegador.

## Solução: usar fluxo implícito (implicit)

Com `AuthFlowType.implicit`, o Supabase redireciona com os tokens no **hash** da URL:

```
https://avaliafotos.com.br/reset-password#access_token=...&refresh_token=...
```

O site lê o hash e usa `setSession` – não precisa de `code_verifier`.

---

## Checklist de configuração

### 1. Supabase Dashboard (projeto Avalia_fotos)

Acesse: **Authentication → URL Configuration**

| Configuração | Valor esperado |
|-------------|----------------|
| **Site URL** | `https://avaliafotos.com.br` ou `https://www.avaliafotos.com.br` (conforme sua URL canônica) |
| **Redirect URLs** | Deve incluir **exatamente**: |
| | `https://avaliafotos.com.br/reset-password` |
| | `https://www.avaliafotos.com.br/reset-password` |

A URL de redirect precisa ser exatamente igual à configurada no app e no template de e-mail.

### 2. App Flutter – fluxo implícito

O arquivo `lib/services/supabase_service.dart` deve ter:

```dart
authOptions: FlutterAuthClientOptions(
  authFlowType: AuthFlowType.implicit,
),
```

### 3. Deploy do app

O app precisa ser **recompilado e publicado** com essa alteração. Se só o site foi atualizado, o app antigo ainda usa PKCE e o erro continua.

### 4. Template de e-mail

O template deve usar `{{ .ConfirmationURL }}` no link. O Supabase monta a URL com base no fluxo configurado no cliente que iniciou o reset.

### 5. Variáveis de ambiente do site (Vercel)

- `NEXT_PUBLIC_SUPABASE_URL` = `https://yulxxamlfxujclnzzcjb.supabase.co`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` = chave anon do projeto

---

## Como testar

1. Fazer um novo build do app Flutter com `AuthFlowType.implicit`
2. Instalar esse build (ou publicar em teste)
3. No app, solicitar reset de senha
4. Abrir o link do e-mail no navegador
5. A URL deve ter `#access_token=...` (hash), não `?code=...` (query)

Se ainda aparecer `?code=...`, o app em uso ainda está com PKCE (build antigo).
