-- Copy passenger ratings from audit_logs into trips.rating when the trip row was never updated.
-- Run after fix_trip_ratings.sql if admin still shows unrated trips that were rated in the app.

update public.trips t
set
  rating = src.rating,
  review_text = coalesce(t.review_text, src.review_text),
  complaint_tags = case
    when coalesce(array_length(src.complaint_tags, 1), 0) > 0 then src.complaint_tags
    else t.complaint_tags
  end,
  rating_submitted_at = coalesce(t.rating_submitted_at, src.rated_at)
from (
  select distinct on (entity_id)
    entity_id,
    coalesce(
      (metadata->>'rating')::smallint,
      substring(summary from '(\d)★')::smallint
    ) as rating,
    nullif(metadata->>'review_text', '') as review_text,
    case
      when jsonb_typeof(metadata->'complaint_tags') = 'array' then
        array(select jsonb_array_elements_text(metadata->'complaint_tags'))
      else '{}'::text[]
    end as complaint_tags,
    created_at as rated_at
  from public.audit_logs
  where action = 'trip.rate'
    and entity_type = 'trips'
    and entity_id is not null
  order by entity_id, created_at desc
) src
where t.id::text = src.entity_id
  and t.status = 'completed'
  and t.rating is null
  and src.rating between 1 and 5;

notify pgrst, 'reload schema';
