-- ============================================================
-- NégoceID — Photo du bon de livraison prise directement par le
-- négociant (au lieu de dépendre d'un lien externe, souvent privé
-- comme un lien Gmail, qui ne fonctionne pas pour l'entreprise cliente).
-- La photo est stockée directement dans la base (même principe que la
-- photo salarié) et affichée en un clic dans le dashboard admin.
--
-- À exécuter dans Supabase → SQL Editor → New query → Run
-- ============================================================

alter table passages add column if not exists bon_livraison_photo text;

drop function if exists validate_passage_chantier(bigint, text, text);
drop function if exists validate_passage_chantier(bigint, text, text, text);

create or replace function validate_passage_chantier(
  p_passage_id bigint,
  p_chantier text,
  p_bon_livraison text default null,
  p_bon_livraison_photo text default null
)
returns boolean
language plpgsql security definer
as $$
declare
  v_code text;
  v_chantiers text[];
  v_is_unrestricted boolean;
  v_valid boolean;
begin
  select code_salarie into v_code from passages where id = p_passage_id;
  if v_code is null or p_chantier is null or trim(p_chantier) = '' then
    return false;
  end if;

  select chantiers into v_chantiers from salaries where code = v_code;
  v_chantiers := coalesce(v_chantiers, '{}');

  select coalesce(bool_or(lower(trim(c)) like 'tous%' or lower(trim(c)) like 'toutes%'), false)
  into v_is_unrestricted
  from unnest(v_chantiers) as c;

  v_valid := v_is_unrestricted or (p_chantier = any(v_chantiers));

  if not v_valid then
    return false;
  end if;

  update passages
  set chantier = p_chantier,
      bon_livraison = coalesce(nullif(trim(p_bon_livraison), ''), bon_livraison),
      bon_livraison_photo = coalesce(p_bon_livraison_photo, bon_livraison_photo)
  where id = p_passage_id;

  return true;
end;
$$;

grant execute on function validate_passage_chantier(bigint, text, text, text) to anon, authenticated;
