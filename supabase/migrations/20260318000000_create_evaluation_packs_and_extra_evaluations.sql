-- Tabela evaluation_packs: pacotes de avaliações extras disponíveis para compra
CREATE TABLE IF NOT EXISTS public.evaluation_packs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  evaluations_count integer NOT NULL,
  price numeric(10, 2) NOT NULL,
  link_checkout text,
  is_popular boolean NOT NULL DEFAULT false,
  has_savings boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.evaluation_packs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "evaluation_packs_select_authenticated" ON public.evaluation_packs
  FOR SELECT TO authenticated USING (true);

-- Tabela user_extra_evaluations: saldo de avaliações extras por usuário
CREATE TABLE IF NOT EXISTS public.user_extra_evaluations (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  extra_count integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_extra_evaluations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_extra_evaluations_select_own" ON public.user_extra_evaluations
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "user_extra_evaluations_update_own" ON public.user_extra_evaluations
  FOR UPDATE TO authenticated USING (auth.uid() = user_id);

-- Tabela evaluation_pack_purchases: histórico de compras (admin credita manualmente)
CREATE TABLE IF NOT EXISTS public.evaluation_pack_purchases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pack_id uuid NOT NULL REFERENCES public.evaluation_packs(id) ON DELETE CASCADE,
  extra_count integer NOT NULL,
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'cancelled')),
  transaction_id text,
  credited_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.evaluation_pack_purchases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "evaluation_pack_purchases_admin_all" ON public.evaluation_pack_purchases
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND is_admin = true)
  );

CREATE POLICY "evaluation_pack_purchases_select_own" ON public.evaluation_pack_purchases
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- RPC: get_user_extra_count
CREATE OR REPLACE FUNCTION public.get_user_extra_count(p_user_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(extra_count, 0)::integer
  FROM public.user_extra_evaluations
  WHERE user_id = p_user_id;
$$;

-- RPC: decrement_user_extra_evaluation
CREATE OR REPLACE FUNCTION public.decrement_user_extra_evaluation(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT extra_count INTO v_count
  FROM public.user_extra_evaluations
  WHERE user_id = p_user_id
  FOR UPDATE;
  
  IF v_count IS NULL OR v_count <= 0 THEN
    RETURN false;
  END IF;
  
  UPDATE public.user_extra_evaluations
  SET extra_count = extra_count - 1,
      updated_at = now()
  WHERE user_id = p_user_id;
  
  RETURN true;
END;
$$;

-- RPC: credit_user_extra_evaluations (admin credita manualmente)
CREATE OR REPLACE FUNCTION public.credit_user_extra_evaluations(
  p_user_id uuid,
  p_pack_id uuid,
  p_count integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.user_extra_evaluations (user_id, extra_count, updated_at)
  VALUES (p_user_id, p_count, now())
  ON CONFLICT (user_id)
  DO UPDATE SET
    extra_count = public.user_extra_evaluations.extra_count + p_count,
    updated_at = now();
  
  INSERT INTO public.evaluation_pack_purchases (user_id, pack_id, extra_count, payment_status, credited_at)
  VALUES (p_user_id, p_pack_id, p_count, 'paid', now());
END;
$$;

-- Seed inicial com 3 pacotes de exemplo (links placeholder)
INSERT INTO public.evaluation_packs (name, evaluations_count, price, link_checkout, is_popular, has_savings, sort_order)
SELECT 'Pacote Inicial', 10, 9.90, NULL, false, false, 1
WHERE NOT EXISTS (SELECT 1 FROM public.evaluation_packs WHERE name = 'Pacote Inicial');

INSERT INTO public.evaluation_packs (name, evaluations_count, price, link_checkout, is_popular, has_savings, sort_order)
SELECT 'Pacote Pro', 50, 39.90, NULL, true, false, 2
WHERE NOT EXISTS (SELECT 1 FROM public.evaluation_packs WHERE name = 'Pacote Pro');

INSERT INTO public.evaluation_packs (name, evaluations_count, price, link_checkout, is_popular, has_savings, sort_order)
SELECT 'Pacote Studio', 150, 99.90, NULL, false, true, 3
WHERE NOT EXISTS (SELECT 1 FROM public.evaluation_packs WHERE name = 'Pacote Studio');
