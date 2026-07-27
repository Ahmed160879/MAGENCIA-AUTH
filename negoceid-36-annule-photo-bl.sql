-- ============================================================
-- NégoceID — Annule la fonctionnalité "photo/lien du BL" (revert de
-- negoceid-35-photo-bl.sql). Remet validate_passage_chantier à sa
-- version d'origine (chantier + n° de BL texte uniquement).
-- Sans danger à exécuter même si negoceid-35-photo-bl.sql n'a jamais
-- été déployé.
--
-- À exécuter dans Supabase → SQL Editor → New query → Run
-- ============================================================

drop function if exists validate_passage_chantier(bigint, text, text, text);
drop function if exists validate_passage_chantier(bigint, text, text);

create or replace function validate_passage_chantier(
  p_passage_id bigint,
  p_chantier text,
  p_bon_livraison text default null
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
      bon_livraison = coalesce(nullif(trim(p_bon_livraison), ''), bon_livraison)
  where id = p_passage_id;

  return true;
end;
$$;

grant execute on function validate_passage_chantier(bigint, text, text) to anon, authenticated;

-- Colonne devenue inutile (si elle avait été créée) — sans danger si absente.
alter table passages drop column if exists bon_livraison_photo;
