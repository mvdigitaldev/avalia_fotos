# Como Configurar a Chave da OpenAI

## Método 1: Via Dashboard (Mais Fácil)

1. Acesse: https://supabase.com/dashboard/project/yulxxamlfxujclnzzcjb/settings/functions
2. Role até a seção "Edge Function Secrets"
3. Adicione uma nova secret:
   - **Key:** `OPENAI_API_KEY`
   - **Value:** `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`
4. Clique em **Save**

## Método 2: Via CLI

Se você tiver o Supabase CLI instalado:

```bash
# Navegue até a pasta do projeto
cd /Users/macbookair/Downloads/avalia_fotos

# Configure o secret
supabase secrets set OPENAI_API_KEY=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 --project-ref yulxxamlfxujclnzzcjb
```

## Verificar se foi configurado

Para verificar se o secret foi configurado corretamente:

```bash
supabase secrets list --project-ref yulxxamlfxujclnzzcjb
```

Você deve ver `OPENAI_API_KEY` na lista.

## Importante

- ⚠️ **NUNCA** commite a chave da API no código
- ⚠️ **NUNCA** compartilhe a chave publicamente
- ✅ Use sempre variáveis de ambiente/secrets
- ✅ A Edge Function já está configurada para ler `OPENAI_API_KEY` do ambiente

## Após configurar

Após configurar o secret, a Edge Function `evaluate-photo` estará pronta para uso. Não é necessário fazer redeploy da função - os secrets são carregados automaticamente.

