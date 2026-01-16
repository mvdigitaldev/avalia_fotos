-- Criar novos planos com durações (trimestral e semestral)
-- Mantendo os planos existentes (Free, Premium, Pro)

-- Básico Trimestral (3 meses, R$ 97,00)
INSERT INTO plans (name, monthly_evaluations_limit, storage_limit, price, duration_months, created_at, updated_at)
VALUES (
  'Básico Trimestral',
  100, -- Limite de avaliações mensais
  500, -- Limite de armazenamento
  97.00,
  3,
  NOW(),
  NOW()
)
ON CONFLICT (name) DO NOTHING;

-- Básico Semestral (6 meses, R$ 127,00)
INSERT INTO plans (name, monthly_evaluations_limit, storage_limit, price, duration_months, created_at, updated_at)
VALUES (
  'Básico Semestral',
  100,
  500,
  127.00,
  6,
  NOW(),
  NOW()
)
ON CONFLICT (name) DO NOTHING;

-- PRO Trimestral (3 meses, R$ 117,00)
INSERT INTO plans (name, monthly_evaluations_limit, storage_limit, price, duration_months, created_at, updated_at)
VALUES (
  'PRO Trimestral',
  200,
  1000,
  117.00,
  3,
  NOW(),
  NOW()
)
ON CONFLICT (name) DO NOTHING;

-- PRO Semestral (6 meses, R$ 197,00)
INSERT INTO plans (name, monthly_evaluations_limit, storage_limit, price, duration_months, created_at, updated_at)
VALUES (
  'PRO Semestral',
  200,
  1000,
  197.00,
  6,
  NOW(),
  NOW()
)
ON CONFLICT (name) DO NOTHING;

