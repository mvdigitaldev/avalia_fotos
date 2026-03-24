-- Foto da semana e foto do mês (alinhado a photo_of_the_day)
-- Semana = segunda ISO (week_start); candidatos da semana = linhas photo_of_the_day na janela [week_start, week_start+6].
-- Mês = candidatos = photo_of_the_week cuja semana intersecta o mês civil.

CREATE OR REPLACE FUNCTION public.week_start_monday(p_date date)
RETURNS date
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
  SELECT (p_date - (EXTRACT(isodow FROM p_date)::integer - 1) * INTERVAL '1 day')::date;
$$;

CREATE TABLE IF NOT EXISTS public.photo_of_the_week (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL UNIQUE,
  photo_id uuid NOT NULL REFERENCES public.photos (id) ON DELETE CASCADE,
  selected_by uuid NOT NULL REFERENCES public.users (id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  url_imagem_selo text,
  CONSTRAINT photo_of_the_week_week_start_is_monday CHECK (EXTRACT(isodow FROM week_start)::integer = 1)
);

CREATE TABLE IF NOT EXISTS public.photo_of_the_month (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_start date NOT NULL UNIQUE,
  photo_id uuid NOT NULL REFERENCES public.photos (id) ON DELETE CASCADE,
  selected_by uuid NOT NULL REFERENCES public.users (id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  url_imagem_selo text,
  CONSTRAINT photo_of_the_month_month_start_is_first CHECK (date_trunc('month', month_start::timestamptz)::date = month_start)
);

CREATE INDEX IF NOT EXISTS idx_photo_of_the_week_photo_id ON public.photo_of_the_week (photo_id);
CREATE INDEX IF NOT EXISTS idx_photo_of_the_month_photo_id ON public.photo_of_the_month (photo_id);

ALTER TABLE public.photo_of_the_week ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_of_the_month ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read photo of the week"
  ON public.photo_of_the_week FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "Only admins can insert photo of the week"
  ON public.photo_of_the_week FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.is_admin = true));

CREATE POLICY "Only admins can update photo of the week"
  ON public.photo_of_the_week FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.is_admin = true));

CREATE POLICY "Only admins can delete photo of the week"
  ON public.photo_of_the_week FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.is_admin = true));

CREATE POLICY "Anyone can read photo of the month"
  ON public.photo_of_the_month FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "Only admins can insert photo of the month"
  ON public.photo_of_the_month FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.is_admin = true));

CREATE POLICY "Only admins can update photo of the month"
  ON public.photo_of_the_month FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.is_admin = true));

CREATE POLICY "Only admins can delete photo of the month"
  ON public.photo_of_the_month FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.is_admin = true));

DROP TRIGGER IF EXISTS update_photo_of_the_week_updated_at ON public.photo_of_the_week;
CREATE TRIGGER update_photo_of_the_week_updated_at
  BEFORE UPDATE ON public.photo_of_the_week
  FOR EACH ROW EXECUTE FUNCTION public.update_photo_of_the_day_updated_at();

DROP TRIGGER IF EXISTS update_photo_of_the_month_updated_at ON public.photo_of_the_month;
CREATE TRIGGER update_photo_of_the_month_updated_at
  BEFORE UPDATE ON public.photo_of_the_month
  FOR EACH ROW EXECUTE FUNCTION public.update_photo_of_the_day_updated_at();

-- Candidatas: uma entrada por dia com foto do dia na semana (JSON compatível com PhotoModel + metadados do dia)
CREATE OR REPLACE FUNCTION public.get_candidate_photos_for_week(p_week_start date)
RETURNS SETOF json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  ws date;
BEGIN
  ws := week_start_monday(p_week_start);
  RETURN QUERY
  SELECT row_to_json(x)::json
  FROM (
    SELECT
      pod.id AS pod_id,
      pod.selected_date AS day_selected_date,
      pod.url_imagem_selo AS day_url_imagem_selo,
      ph.id,
      ph.user_id,
      ph.image_url,
      ph.thumbnail_url,
      ph.score,
      ph.positive_points,
      ph.improvement_points,
      ph.observacao,
      ph.categoria,
      ph.recado,
      ph.is_shared,
      ph.likes_count,
      ph.comments_count,
      ph.created_at,
      ph.updated_at,
      u.username,
      u.avatar_url AS user_avatar_url
    FROM photo_of_the_day pod
    INNER JOIN photos ph ON ph.id = pod.photo_id
    LEFT JOIN users u ON u.id = ph.user_id
    WHERE pod.selected_date >= ws
      AND pod.selected_date < ws + 7
    ORDER BY pod.selected_date ASC
  ) x;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_photo_of_the_week(p_week_start date)
RETURNS TABLE (
  id uuid,
  photo_id uuid,
  week_start date,
  selected_by uuid,
  created_at timestamptz,
  url_imagem_selo text,
  photo_data jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  ws date;
BEGIN
  ws := week_start_monday(p_week_start);
  RETURN QUERY
  SELECT
    potw.id,
    potw.photo_id,
    potw.week_start,
    potw.selected_by,
    potw.created_at,
    potw.url_imagem_selo,
    jsonb_build_object(
      'id', p.id,
      'user_id', p.user_id,
      'image_url', p.image_url,
      'thumbnail_url', p.thumbnail_url,
      'score', p.score,
      'positive_points', p.positive_points,
      'improvement_points', p.improvement_points,
      'observacao', p.observacao,
      'categoria', p.categoria,
      'recado', p.recado,
      'is_shared', p.is_shared,
      'likes_count', p.likes_count,
      'comments_count', p.comments_count,
      'created_at', p.created_at,
      'updated_at', p.updated_at,
      'username', u.username,
      'user_avatar_url', u.avatar_url
    ) AS photo_data
  FROM photo_of_the_week potw
  INNER JOIN photos p ON potw.photo_id = p.id
  LEFT JOIN users u ON p.user_id = u.id
  WHERE potw.week_start = ws;
END;
$$;

CREATE OR REPLACE FUNCTION public.select_photo_of_the_week(p_photo_id uuid, p_week_start date)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_is_admin boolean;
  v_ok boolean;
  ws date;
  v_result_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  SELECT is_admin INTO v_is_admin FROM users WHERE id = v_user_id;
  IF v_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'Apenas administradores podem selecionar foto da semana';
  END IF;

  ws := week_start_monday(p_week_start);

  SELECT EXISTS (
    SELECT 1 FROM photo_of_the_day pod
    WHERE pod.photo_id = p_photo_id
      AND pod.selected_date >= ws
      AND pod.selected_date < ws + 7
  ) INTO v_ok;

  IF NOT v_ok THEN
    RAISE EXCEPTION 'A foto deve ser uma das fotos do dia dessa semana';
  END IF;

  INSERT INTO photo_of_the_week (week_start, photo_id, selected_by)
  VALUES (ws, p_photo_id, v_user_id)
  ON CONFLICT (week_start) DO UPDATE SET
    photo_id = EXCLUDED.photo_id,
    selected_by = EXCLUDED.selected_by,
    updated_at = now()
  RETURNING photo_of_the_week.id INTO v_result_id;

  RETURN v_result_id;
END;
$$;

-- Semanas ISO que intersectam o mês civil [primeiro dia, último dia]
CREATE OR REPLACE FUNCTION public.get_candidate_photos_for_month(p_year integer, p_month integer)
RETURNS SETOF json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  ms date;
  me date;
BEGIN
  ms := make_date(p_year, p_month, 1);
  me := (ms + interval '1 month - 1 day')::date;
  RETURN QUERY
  SELECT row_to_json(x)::json
  FROM (
    SELECT
      pow.id AS pow_id,
      pow.week_start,
      pow.url_imagem_selo AS week_url_imagem_selo,
      ph.id,
      ph.user_id,
      ph.image_url,
      ph.thumbnail_url,
      ph.score,
      ph.positive_points,
      ph.improvement_points,
      ph.observacao,
      ph.categoria,
      ph.recado,
      ph.is_shared,
      ph.likes_count,
      ph.comments_count,
      ph.created_at,
      ph.updated_at,
      u.username,
      u.avatar_url AS user_avatar_url
    FROM photo_of_the_week pow
    INNER JOIN photos ph ON ph.id = pow.photo_id
    LEFT JOIN users u ON u.id = ph.user_id
    WHERE pow.week_start <= me
      AND (pow.week_start + 6) >= ms
    ORDER BY pow.week_start ASC
  ) x;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_photo_of_the_month(p_month_start date)
RETURNS TABLE (
  id uuid,
  photo_id uuid,
  month_start date,
  selected_by uuid,
  created_at timestamptz,
  url_imagem_selo text,
  photo_data jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  ms date;
BEGIN
  ms := date_trunc('month', p_month_start::timestamptz)::date;
  RETURN QUERY
  SELECT
    potm.id,
    potm.photo_id,
    potm.month_start,
    potm.selected_by,
    potm.created_at,
    potm.url_imagem_selo,
    jsonb_build_object(
      'id', p.id,
      'user_id', p.user_id,
      'image_url', p.image_url,
      'thumbnail_url', p.thumbnail_url,
      'score', p.score,
      'positive_points', p.positive_points,
      'improvement_points', p.improvement_points,
      'observacao', p.observacao,
      'categoria', p.categoria,
      'recado', p.recado,
      'is_shared', p.is_shared,
      'likes_count', p.likes_count,
      'comments_count', p.comments_count,
      'created_at', p.created_at,
      'updated_at', p.updated_at,
      'username', u.username,
      'user_avatar_url', u.avatar_url
    ) AS photo_data
  FROM photo_of_the_month potm
  INNER JOIN photos p ON potm.photo_id = p.id
  LEFT JOIN users u ON p.user_id = u.id
  WHERE potm.month_start = ms;
END;
$$;

CREATE OR REPLACE FUNCTION public.select_photo_of_the_month(p_photo_id uuid, p_month_start date)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_is_admin boolean;
  v_ok boolean;
  ms date;
  me date;
  v_result_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  SELECT is_admin INTO v_is_admin FROM users WHERE id = v_user_id;
  IF v_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'Apenas administradores podem selecionar foto do mês';
  END IF;

  ms := date_trunc('month', p_month_start::timestamptz)::date;
  me := (ms + interval '1 month - 1 day')::date;

  SELECT EXISTS (
    SELECT 1 FROM photo_of_the_week pow
    WHERE pow.photo_id = p_photo_id
      AND pow.week_start <= me
      AND (pow.week_start + 6) >= ms
  ) INTO v_ok;

  IF NOT v_ok THEN
    RAISE EXCEPTION 'A foto deve ser uma das fotos da semana vencedoras neste mês';
  END IF;

  INSERT INTO photo_of_the_month (month_start, photo_id, selected_by)
  VALUES (ms, p_photo_id, v_user_id)
  ON CONFLICT (month_start) DO UPDATE SET
    photo_id = EXCLUDED.photo_id,
    selected_by = EXCLUDED.selected_by,
    updated_at = now()
  RETURNING photo_of_the_month.id INTO v_result_id;

  RETURN v_result_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_photo_of_the_week_by_photo_id(p_photo_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM photo_of_the_week pow WHERE pow.photo_id = p_photo_id
  );
$$;

CREATE OR REPLACE FUNCTION public.is_photo_of_the_month_by_photo_id(p_photo_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM photo_of_the_month pom WHERE pom.photo_id = p_photo_id
  );
$$;

CREATE OR REPLACE VIEW public.feed_photos AS
SELECT
  p.id,
  p.user_id,
  p.image_url,
  p.thumbnail_url,
  p.score,
  p.recado,
  p.is_shared,
  p.likes_count,
  p.comments_count,
  p.created_at,
  p.updated_at,
  p.categoria,
  EXISTS (
    SELECT 1
    FROM photo_of_the_day pod
    WHERE pod.photo_id = p.id
      AND pod.selected_date = business_date(p.created_at)
  ) AS is_photo_of_the_day,
  EXISTS (
    SELECT 1
    FROM photo_of_the_week pow
    WHERE pow.photo_id = p.id
  ) AS is_photo_of_the_week,
  EXISTS (
    SELECT 1
    FROM photo_of_the_month pom
    WHERE pom.photo_id = p.id
  ) AS is_photo_of_the_month
FROM photos p
WHERE p.is_shared = true;

COMMENT ON VIEW public.feed_photos IS 'Feed de fotos compartilhadas. is_photo_of_the_day usa business_date; semana/mês por photo_id nas tabelas de premiação.';

GRANT SELECT ON public.photo_of_the_week TO anon, authenticated;
GRANT SELECT ON public.photo_of_the_month TO anon, authenticated;

GRANT EXECUTE ON FUNCTION public.week_start_monday(date) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_candidate_photos_for_week(date) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_photo_of_the_week(date) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.select_photo_of_the_week(uuid, date) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_candidate_photos_for_month(integer, integer) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_photo_of_the_month(date) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.select_photo_of_the_month(uuid, date) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_photo_of_the_week_by_photo_id(uuid) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_photo_of_the_month_by_photo_id(uuid) TO PUBLIC;
