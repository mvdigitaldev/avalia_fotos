-- Auditoria imutável: uma linha por INSERT em photos; DELETE em photos só zera photo_id (SET NULL).

CREATE TABLE public.photo_evaluation_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  photo_id uuid REFERENCES public.photos(id) ON DELETE SET NULL,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  evaluated_at timestamptz NOT NULL,
  business_month int NOT NULL CHECK (business_month >= 1 AND business_month <= 12),
  business_year int NOT NULL,
  score numeric NOT NULL,
  image_url text NOT NULL,
  thumbnail_url text,
  positive_points text[],
  improvement_points text[],
  observacao text,
  categoria text,
  recado text,
  is_shared boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX photo_evaluation_audit_photo_id_unique
  ON public.photo_evaluation_audit (photo_id)
  WHERE photo_id IS NOT NULL;

CREATE INDEX photo_evaluation_audit_user_month_year_idx
  ON public.photo_evaluation_audit (user_id, business_year, business_month);

CREATE INDEX photo_evaluation_audit_evaluated_at_idx
  ON public.photo_evaluation_audit (evaluated_at);

COMMENT ON TABLE public.photo_evaluation_audit IS 'Snapshot por avaliação; não apagar em DELETE de photos (photo_id vira NULL).';

CREATE OR REPLACE FUNCTION public.audit_photo_after_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_month int;
  v_year int;
  v_ts timestamptz;
BEGIN
  v_ts := COALESCE(NEW.created_at, now());
  v_month := EXTRACT(MONTH FROM public.business_date(v_ts))::int;
  v_year := EXTRACT(YEAR FROM public.business_date(v_ts))::int;

  INSERT INTO public.photo_evaluation_audit (
    photo_id,
    user_id,
    evaluated_at,
    business_month,
    business_year,
    score,
    image_url,
    thumbnail_url,
    positive_points,
    improvement_points,
    observacao,
    categoria,
    recado,
    is_shared
  ) VALUES (
    NEW.id,
    NEW.user_id,
    v_ts,
    v_month,
    v_year,
    NEW.score,
    NEW.image_url,
    NEW.thumbnail_url,
    NEW.positive_points,
    NEW.improvement_points,
    NEW.observacao,
    NEW.categoria,
    NEW.recado,
    COALESCE(NEW.is_shared, false)
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER photos_audit_after_insert
  AFTER INSERT ON public.photos
  FOR EACH ROW
  EXECUTE FUNCTION public.audit_photo_after_insert();

ALTER TABLE public.photo_evaluation_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY "photo_evaluation_audit_select_own"
  ON public.photo_evaluation_audit
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

GRANT SELECT ON public.photo_evaluation_audit TO authenticated;
GRANT ALL ON public.photo_evaluation_audit TO service_role;
