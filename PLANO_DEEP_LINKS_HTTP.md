# Plano: Implementar Deep Links HTTP e Página Web de Fallback

## Objetivo

Atualizar o app Flutter e backend Supabase para suportar links HTTP públicos (`https://avaliafotos.com.br/p/{photoId}`) que:
- Abrem o app diretamente quando instalado (via Universal Links/App Links)
- Mostram página web com foto e botão de download quando app não está instalado

## Componentes a Implementar

### 1. Banco de Dados - Tabela app_store_links

Criar tabela no Supabase para armazenar links das lojas de aplicativos.

**Arquivo**: Migration SQL ou criar via MCP Supabase

**SQL**:
```sql
CREATE TABLE IF NOT EXISTS app_store_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform TEXT NOT NULL UNIQUE CHECK (platform IN ('ios', 'android')),
  store_url TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Inserir links iniciais (atualizar com links reais)
INSERT INTO app_store_links (platform, store_url) VALUES
  ('ios', 'https://apps.apple.com/app/avaliafotos/idXXXXX'),
  ('android', 'https://play.google.com/store/apps/details?id=com.example.avaliafotos')
ON CONFLICT (platform) DO UPDATE SET store_url = EXCLUDED.store_url;
```

### 2. Edge Function - get-photo-share

Criar Edge Function pública para buscar foto e links das lojas.

**Arquivo**: `supabase/functions/get-photo-share/index.ts` (NOVO)

**Funcionalidade**:
- Recebe `photoId` como query parameter
- Busca foto pública do Supabase (is_shared = true)
- Busca links das lojas da tabela app_store_links
- Retorna JSON com dados da foto e links
- Permite CORS para acesso da página web

### 3. Configuração Universal Links (iOS)

Adicionar suporte para links HTTP abrirem o app quando instalado.

**Arquivo**: `ios/Runner/Runner.entitlements`

**Alteração**: Adicionar associated-domains:
```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:avaliafotos.com.br</string>
</array>
```

**Nota**: Arquivo `.well-known/apple-app-site-association` deve ser criado no servidor web (fora do escopo do app).

### 4. Configuração App Links (Android)

Adicionar suporte para links HTTP abrirem o app quando instalado.

**Arquivo**: `android/app/src/main/AndroidManifest.xml`

**Alteração**: Adicionar intent-filter para HTTPS dentro da activity principal:
```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data
    android:scheme="https"
    android:host="avaliafotos.com.br"
    android:pathPrefix="/p" />
</intent-filter>
```

**Nota**: Arquivo `.well-known/assetlinks.json` deve ser criado no servidor web (fora do escopo do app).

### 5. Tratamento de Deep Links HTTP no App Flutter

Adicionar lógica para detectar quando app é aberto via link HTTP e navegar para foto.

**Arquivo**: `lib/flutter_flow/nav/nav.dart`

**Alteração**: 
- Adicionar listener de deep links no GoRouter
- Detectar URLs no formato `https://avaliafotos.com.br/p/{photoId}`
- Converter para rota interna `/photo-detail/{photoId}`
- Navegar automaticamente para a foto

**Implementação**:
- Usar `GoRouter` com `onException` ou adicionar listener de URI
- Detectar padrão `/p/{photoId}` na URL inicial
- Extrair photoId e navegar para `/photo-detail/{photoId}`

## Fluxo de Funcionamento

1. Usuário acessa `https://avaliafotos.com.br/p/{photoId}` no navegador
2. Sistema tenta abrir app via Universal Link/App Link
3. Se app instalado: app abre e navega para `/photo-detail/{photoId}`
4. Se app não instalado: página web carrega, busca foto via Edge Function, mostra foto e botão de download

## Arquivos a Criar/Modificar

### Supabase
- Migration SQL para tabela `app_store_links` (ou criar via MCP)
- `supabase/functions/get-photo-share/index.ts` (NOVO)

### iOS
- `ios/Runner/Runner.entitlements` (adicionar associated-domains)

### Android
- `android/app/src/main/AndroidManifest.xml` (adicionar intent-filter HTTPS)

### Flutter
- `lib/flutter_flow/nav/nav.dart` (adicionar tratamento de deep links HTTP)

## Observações

- Arquivos `.well-known` devem ser criados no servidor web (não fazem parte do app)
- Links das lojas podem ser atualizados via dashboard do Supabase após criação da tabela
- Edge Function deve ser pública (sem autenticação) para acesso da página web
