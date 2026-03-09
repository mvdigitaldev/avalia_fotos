-- RPC is_photo_of_the_day_by_photo_id: verifica por ID usando business_date
-- Depende de 20260215_business_timezone_helpers.sql

CREATE OR REPLACE FUNCTION is_photo_of_the_day_by_photo_id(p_photo_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM photo_of_the_day pod
    INNER JOIN photos ph ON ph.id = p_photo_id
    WHERE pod.photo_id = p_photo_id
      AND pod.selected_date = business_date(ph.created_at)
  )
$$;
