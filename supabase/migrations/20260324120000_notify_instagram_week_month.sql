-- Webhook n8n (Instagram): chamar Edge Functions ao selecionar foto da semana / do mês.
-- Mesmo padrão de call_notify_photo_of_the_day (extensão http + private.app_secrets).

CREATE OR REPLACE FUNCTION public.call_notify_photo_of_the_week(p_record jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_response http_response;
  v_service_role_key TEXT;
BEGIN
  SELECT value INTO v_service_role_key
  FROM private.app_secrets
  WHERE name = 'supabase_service_role_key';

  IF v_service_role_key IS NULL OR length(trim(v_service_role_key)) = 0 THEN
    RAISE WARNING 'call_notify_photo_of_the_week: supabase_service_role_key ausente em private.app_secrets';
    RETURN;
  END IF;

  SELECT * INTO v_response
  FROM http((
    'POST',
    'https://yulxxamlfxujclnzzcjb.supabase.co/functions/v1/notify-photo-of-the-week',
    ARRAY[
      http_header('Content-Type', 'application/json'),
      http_header('Authorization', 'Bearer ' || v_service_role_key)
    ],
    'application/json',
    jsonb_build_object('record', p_record)::text
  )::http_request);

  RAISE NOTICE 'notify-photo-of-the-week Edge respondeu: % - %', v_response.status, left(coalesce(v_response.content, ''), 500);

EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Erro em call_notify_photo_of_the_week: %', SQLERRM;
END;
$$;

CREATE OR REPLACE FUNCTION public.call_notify_photo_of_the_month(p_record jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_response http_response;
  v_service_role_key TEXT;
BEGIN
  SELECT value INTO v_service_role_key
  FROM private.app_secrets
  WHERE name = 'supabase_service_role_key';

  IF v_service_role_key IS NULL OR length(trim(v_service_role_key)) = 0 THEN
    RAISE WARNING 'call_notify_photo_of_the_month: supabase_service_role_key ausente em private.app_secrets';
    RETURN;
  END IF;

  SELECT * INTO v_response
  FROM http((
    'POST',
    'https://yulxxamlfxujclnzzcjb.supabase.co/functions/v1/notify-photo-of-the-month',
    ARRAY[
      http_header('Content-Type', 'application/json'),
      http_header('Authorization', 'Bearer ' || v_service_role_key)
    ],
    'application/json',
    jsonb_build_object('record', p_record)::text
  )::http_request);

  RAISE NOTICE 'notify-photo-of-the-month Edge respondeu: % - %', v_response.status, left(coalesce(v_response.content, ''), 500);

EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Erro em call_notify_photo_of_the_month: %', SQLERRM;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_photo_of_the_week()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.call_notify_photo_of_the_week(row_to_json(NEW)::jsonb);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_photo_of_the_month()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.call_notify_photo_of_the_month(row_to_json(NEW)::jsonb);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_notify_photo_of_the_week ON public.photo_of_the_week;
CREATE TRIGGER trigger_notify_photo_of_the_week
  AFTER INSERT OR UPDATE ON public.photo_of_the_week
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_photo_of_the_week();

DROP TRIGGER IF EXISTS trigger_notify_photo_of_the_month ON public.photo_of_the_month;
CREATE TRIGGER trigger_notify_photo_of_the_month
  AFTER INSERT OR UPDATE ON public.photo_of_the_month
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_photo_of_the_month();
