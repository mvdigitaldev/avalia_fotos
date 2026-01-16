-- Função para calcular expires_at baseado em duration_months do plano
-- Esta função será chamada quando um plano for atribuído a um usuário

CREATE OR REPLACE FUNCTION calculate_plan_expires_at(p_user_plan_id UUID)
RETURNS TIMESTAMP WITH TIME ZONE
LANGUAGE plpgsql
AS $$
DECLARE
  v_duration_months INTEGER;
  v_started_at TIMESTAMP WITH TIME ZONE;
BEGIN
  -- Buscar duration_months do plano e started_at do user_plan
  SELECT 
    p.duration_months,
    up.started_at
  INTO 
    v_duration_months,
    v_started_at
  FROM user_plans up
  JOIN plans p ON p.id = up.plan_id
  WHERE up.id = p_user_plan_id;

  -- Se não encontrou ou duration_months é NULL, retornar NULL (plano sem expiração)
  IF v_duration_months IS NULL OR v_started_at IS NULL THEN
    RETURN NULL;
  END IF;

  -- Calcular expires_at adicionando duration_months ao started_at
  RETURN v_started_at + (v_duration_months || ' months')::INTERVAL;
END;
$$;

-- Trigger para atualizar expires_at automaticamente quando user_plan é criado/atualizado
CREATE OR REPLACE FUNCTION update_user_plan_expires_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Calcular expires_at baseado no duration_months do plano
  NEW.expires_at := calculate_plan_expires_at(NEW.id);
  RETURN NEW;
END;
$$;

-- Criar trigger
DROP TRIGGER IF EXISTS trigger_update_user_plan_expires_at ON user_plans;
CREATE TRIGGER trigger_update_user_plan_expires_at
  BEFORE INSERT OR UPDATE ON user_plans
  FOR EACH ROW
  EXECUTE FUNCTION update_user_plan_expires_at();

-- Atualizar expires_at para user_plans existentes que têm planos com duration_months
UPDATE user_plans up
SET expires_at = calculate_plan_expires_at(up.id)
WHERE EXISTS (
  SELECT 1 FROM plans p
  WHERE p.id = up.plan_id
  AND p.duration_months IS NOT NULL
);

