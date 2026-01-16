-- Adicionar campo duration_months na tabela plans
-- 3 = trimestral, 6 = semestral, NULL = sem duração fixa (free)
ALTER TABLE plans
ADD COLUMN IF NOT EXISTS duration_months INTEGER;

-- Comentário para documentação
COMMENT ON COLUMN plans.duration_months IS 'Duração do plano em meses. NULL para planos sem duração fixa (free).';

