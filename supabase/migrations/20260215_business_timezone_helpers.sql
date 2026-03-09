-- Padronização de data de negócio: helpers para America/Sao_Paulo
-- Mantém UTC no banco; dia/mês calculados no fuso Brasil

-- Fuso canônico de negócio
CREATE OR REPLACE FUNCTION app_business_tz() RETURNS text
LANGUAGE sql STABLE AS $$ SELECT 'America/Sao_Paulo' $$;

-- Data de negócio (dia) a partir de timestamptz
CREATE OR REPLACE FUNCTION business_date(ts timestamptz) RETURNS date
LANGUAGE sql STABLE AS $$
  SELECT (ts AT TIME ZONE app_business_tz())::date
$$;

-- Limites UTC do mês de negócio (start inclusive, end exclusive)
CREATE OR REPLACE FUNCTION business_month_bounds_utc(p_year int, p_month int)
RETURNS TABLE(start_utc timestamptz, end_utc timestamptz)
LANGUAGE sql STABLE AS $$
  SELECT
    (make_timestamp(p_year, p_month, 1, 0, 0, 0)::timestamp AT TIME ZONE app_business_tz())::timestamptz,
    (make_timestamp(
      CASE WHEN p_month = 12 THEN p_year + 1 ELSE p_year END,
      CASE WHEN p_month = 12 THEN 1 ELSE p_month + 1 END,
      1, 0, 0, 0
    )::timestamp AT TIME ZONE app_business_tz())::timestamptz
$$;

-- Limites UTC do dia de negócio
CREATE OR REPLACE FUNCTION business_day_bounds_utc(p_date date)
RETURNS TABLE(start_utc timestamptz, end_utc timestamptz)
LANGUAGE sql STABLE AS $$
  SELECT
    (p_date::timestamp AT TIME ZONE app_business_tz())::timestamptz,
    ((p_date + 1)::timestamp AT TIME ZONE app_business_tz())::timestamptz
$$;

-- Mês/ano de negócio atual
CREATE OR REPLACE FUNCTION business_month_year_now()
RETURNS TABLE(p_month int, p_year int)
LANGUAGE sql STABLE AS $$
  SELECT
    EXTRACT(MONTH FROM (now() AT TIME ZONE app_business_tz()))::int,
    EXTRACT(YEAR FROM (now() AT TIME ZONE app_business_tz()))::int
$$;
