-- Buendia data dump: one row per non-voided observation or order, for every patient.
-- Run by Reporting's SqlFileDataSetDefinition (see data-dump.yml), which prepends
-- "set @<parameter> = 'yyyy-MM-dd'" (or null) for each parameter. Times are UTC, as stored.
-- Doses given are observations of buendia_concept_order_executed, linked by order_uuid;
-- bed placements (buendia_concept_placement) are shown as "<zone> / <bed>"; a zone deleted in
-- OpenMRS shows as "Deleted location".
select
  ps.uuid as patient_uuid,
  (select pi.identifier from patient_identifier pi
     join patient_identifier_type pit on pit.patient_identifier_type_id = pi.identifier_type
    where pi.patient_id = p.patient_id and pi.voided = 0
    order by pit.name = 'MSF' desc, pi.preferred desc, pi.patient_identifier_id limit 1) as patient_id,
  (select pn.given_name from person_name pn where pn.person_id = p.patient_id and pn.voided = 0
    order by pn.preferred desc, pn.person_name_id limit 1) as given_name,
  (select pn.family_name from person_name pn where pn.person_id = p.patient_id and pn.voided = 0
    order by pn.preferred desc, pn.person_name_id limit 1) as family_name,
  ps.gender as sex,
  date_format(ps.birthdate, '%Y-%m-%d') as birthdate,
  date_format(p.date_created, '%Y-%m-%d %H:%i:%s') as patient_registered_utc,
  r.record_type,
  r.record_uuid,
  date_format(e.encounter_datetime, '%Y-%m-%d %H:%i:%s') as encounter_datetime_utc,
  e.uuid as encounter_uuid,
  (select group_concat(distinct coalesce(pr.name, concat_ws(' ', prn.given_name, prn.family_name)) separator '; ')
     from encounter_provider ep
     join provider pr on pr.provider_id = ep.provider_id
     left join person_name prn on prn.person_id = pr.person_id and prn.voided = 0
    where ep.encounter_id = e.encounter_id and ep.voided = 0) as provider,
  r.concept_id,
  c.uuid as concept_uuid,
  case c.uuid
    when 'buendia_concept_free_text_order' then 'Order'
    when 'buendia_concept_order_executed' then 'Dose given'
    when 'buendia_concept_placement' then 'Placement'
    else trim(substring_index(coalesce(cn.name, cnx.name, c.uuid), '[fr:', 1)) end as question_en,
  case
    when c.uuid = 'buendia_concept_free_text_order' then 'Prescription'
    when c.uuid = 'buendia_concept_order_executed' then 'Dose administrée'
    when c.uuid = 'buendia_concept_placement' then 'Emplacement'
    when cn.name like '%[fr:%'
      then trim(trailing ']' from trim(substring_index(cn.name, '[fr:', -1)))
    else trim(substring_index(coalesce(cn.name, cnx.name, c.uuid), '[fr:', 1)) end as question_fr,
  cd.name as datatype,
  case
    when r.value_coded is not null
      then trim(substring_index(coalesce(vn.name, vnx.name, vc.uuid), '[fr:', 1))
    when r.value_datetime is not null and cd.name = 'Date'
      then date_format(r.value_datetime, '%Y-%m-%d')
    when r.value_datetime is not null
      then date_format(r.value_datetime, '%Y-%m-%d %H:%i:%s')
    when r.value_numeric is not null
      then trim(trailing '.' from trim(trailing '0' from cast(r.value_numeric as decimal(30, 6))))
    when c.uuid = 'buendia_concept_placement'
      then concat_ws(' / ', coalesce(pl.name, 'Deleted location'),
                     nullif(substring(r.value_text, length(substring_index(r.value_text, '/', 1)) + 2), ''))
    else r.value_text
  end as value,
  r.value_coded as value_concept_id,
  r.order_uuid,
  r.order_action,
  r.previous_order_uuid,
  date_format(r.order_start, '%Y-%m-%d %H:%i:%s') as order_start_utc,
  date_format(r.order_stop, '%Y-%m-%d %H:%i:%s') as order_stop_utc,
  date_format(r.date_created, '%Y-%m-%d %H:%i:%s') as recorded_at_utc,
  u.username as recorded_by
from (
  select 'observation' as record_type, o.uuid as record_uuid, o.person_id as patient_id,
         o.encounter_id, o.concept_id, o.value_coded, o.value_datetime, o.value_numeric,
         o.value_text, ord.uuid as order_uuid, null as order_action, null as previous_order_uuid,
         null as order_start, null as order_stop, o.date_created, o.creator, o.obs_id as seq
    from obs o
    left join orders ord on ord.order_id = o.order_id
   where o.voided = 0
  union all
  select 'order', ord.uuid, ord.patient_id,
         ord.encounter_id, ord.concept_id, null, null, null,
         ord.instructions, ord.uuid, ord.order_action, prev.uuid,
         coalesce(ord.scheduled_date, ord.date_activated),
         coalesce(ord.date_stopped, ord.auto_expire_date), ord.date_created, ord.creator, ord.order_id
    from orders ord
    left join orders prev on prev.order_id = ord.previous_order_id
   where ord.voided = 0
) r
join patient p on p.patient_id = r.patient_id and p.voided = 0
join person ps on ps.person_id = p.patient_id
left join encounter e on e.encounter_id = r.encounter_id
join concept c on c.concept_id = r.concept_id
join concept_datatype cd on cd.concept_datatype_id = c.datatype_id
left join concept_name cn on cn.concept_name_id = (
  select min(n.concept_name_id) from concept_name n
   where n.concept_id = r.concept_id and n.locale = 'buendia' and n.voided = 0)
left join concept_name cnx on cnx.concept_name_id = (
  select min(n.concept_name_id) from concept_name n
   where n.concept_id = r.concept_id and n.locale = 'en' and n.voided = 0)
left join concept vc on vc.concept_id = r.value_coded
left join concept_name vn on vn.concept_name_id = (
  select min(n.concept_name_id) from concept_name n
   where n.concept_id = r.value_coded and n.locale = 'buendia' and n.voided = 0)
left join concept_name vnx on vnx.concept_name_id = (
  select min(n.concept_name_id) from concept_name n
   where n.concept_id = r.value_coded and n.locale = 'en' and n.locale_preferred = 1 and n.voided = 0)
left join location pl on c.uuid = 'buendia_concept_placement'
  and pl.uuid = substring_index(r.value_text, '/', 1)
left join users u on u.user_id = r.creator
where (@registeredFrom is null or p.date_created >= @registeredFrom)
  and (@registeredTo is null or p.date_created < date_add(@registeredTo, interval 1 day))
  and (@changedSince is null or r.date_created >= @changedSince)
order by patient_id, p.patient_id, coalesce(e.encounter_datetime, r.date_created), r.record_type, r.seq
