-- RPCs de score e avaliação mensal com data de negócio (America/Sao_Paulo)
-- Depende de 20260215_business_timezone_helpers.sql

-- Versionar tabelas se não existirem (podem já estar em produção)
CREATE TABLE IF NOT EXISTS user_monthly_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  month int NOT NULL,
  year int NOT NULL,
  score numeric NOT NULL DEFAULT 0,
  photos_count int NOT NULL DEFAULT 0,
  UNIQUE(user_id, month, year)
);

CREATE TABLE IF NOT EXISTS user_monthly_evaluations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  month int NOT NULL,
  year int NOT NULL,
  evaluations_count int NOT NULL DEFAULT 0,
  UNIQUE(user_id, month, year)
);

-- RLS (se não existir)
ALTER TABLE user_monthly_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_monthly_evaluations ENABLE ROW LEVEL SECURITY;

-- Políticas RLS (criar apenas se não existirem)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_monthly_scores' AND policyname = 'Authenticated read user_monthly_scores') THEN
    CREATE POLICY "Authenticated read user_monthly_scores" ON user_monthly_scores
      FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_monthly_evaluations' AND policyname = 'Users read own evaluations') THEN
    CREATE POLICY "Users read own evaluations" ON user_monthly_evaluations
      FOR SELECT TO authenticated USING (auth.uid() = user_id);
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- increment_monthly_score: backend usa business_month_year_now()
CREATE OR REPLACE FUNCTION increment_monthly_score(p_user_id uuid, p_score_to_add numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_month int;
  v_year int;
BEGIN
  SELECT p_month, p_year INTO v_month, v_year FROM business_month_year_now();
  
  INSERT INTO user_monthly_scores (user_id, month, year, score, photos_count)
  VALUES (p_user_id, v_month, v_year, p_score_to_add, 1)
  ON CONFLICT (user_id, month, year)
  DO UPDATE SET
    score = user_monthly_scores.score + EXCLUDED.score,
    photos_count = user_monthly_scores.photos_count + 1;
END;
$$;

-- increment_monthly_evaluation: backend usa business_month_year_now()
CREATE OR REPLACE FUNCTION increment_monthly_evaluation(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_month int;
  v_year int;
BEGIN
  SELECT p_month, p_year INTO v_month, v_year FROM business_month_year_now();
  
  INSERT INTO user_monthly_evaluations (user_id, month, year, evaluations_count)
  VALUES (p_user_id, v_month, v_year, 1)
  ON CONFLICT (user_id, month, year)
  DO UPDATE SET evaluations_count = user_monthly_evaluations.evaluations_count + 1;
END;
$$;

-- get_current_business_month_year: mês/ano atual em BRT
CREATE OR REPLACE FUNCTION get_current_business_month_year()
RETURNS TABLE(month int, year int)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT p_month::int, p_year::int FROM business_month_year_now()
$$;
