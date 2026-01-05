-- Adicionar colunas para Product IDs das plataformas
ALTER TABLE plans
ADD COLUMN IF NOT EXISTS apple_product_id TEXT,
ADD COLUMN IF NOT EXISTS google_product_id TEXT;

-- Adicionar comentários para documentação
COMMENT ON COLUMN plans.apple_product_id IS 'Product ID do App Store Connect (ex: com.yourapp.plan.basic_monthly)';
COMMENT ON COLUMN plans.google_product_id IS 'Product ID do Google Play Console (ex: com.yourapp.plan.basic_monthly)';

