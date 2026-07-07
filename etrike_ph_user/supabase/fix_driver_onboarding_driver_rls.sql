-- Driver self-service onboarding: RLS for document upload, drafts, pipeline read.
-- Run after fix_driver_onboarding.sql and fix_driver_documents_storage.sql

-- driver_documents: driver can upload / update own rows (operator verifies later)
drop policy if exists driver_documents_driver_write on public.driver_documents;
create policy driver_documents_driver_write on public.driver_documents
  for insert to authenticated
  with check (auth.uid() = driver_id);

drop policy if exists driver_documents_driver_update on public.driver_documents;
create policy driver_documents_driver_update on public.driver_documents
  for update to authenticated
  using (auth.uid() = driver_id)
  with check (auth.uid() = driver_id);

-- registration draft wizard progress
drop policy if exists registration_drafts_driver_own on public.driver_registration_drafts;
create policy registration_drafts_driver_own on public.driver_registration_drafts
  for all to authenticated
  using (auth.uid() = driver_id)
  with check (auth.uid() = driver_id);

-- hiring pipeline: driver read + create own row on first login
drop policy if exists hiring_pipeline_driver_read on public.driver_hiring_pipeline;
create policy hiring_pipeline_driver_read on public.driver_hiring_pipeline
  for select to authenticated
  using (auth.uid() = driver_id);

drop policy if exists hiring_pipeline_driver_insert on public.driver_hiring_pipeline;
create policy hiring_pipeline_driver_insert on public.driver_hiring_pipeline
  for insert to authenticated
  with check (auth.uid() = driver_id);

drop policy if exists hiring_pipeline_driver_update on public.driver_hiring_pipeline;
create policy hiring_pipeline_driver_update on public.driver_hiring_pipeline
  for update to authenticated
  using (auth.uid() = driver_id)
  with check (auth.uid() = driver_id);

-- storage: allow replace (upsert) of own files
drop policy if exists driver_documents_storage_driver_delete on storage.objects;
create policy driver_documents_storage_driver_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- timeline: driver read events + log own submissions
drop policy if exists onboarding_timeline_driver_read on public.onboarding_timeline;
create policy onboarding_timeline_driver_read on public.onboarding_timeline
  for select to authenticated
  using (auth.uid() = driver_id);

drop policy if exists onboarding_timeline_driver_insert on public.onboarding_timeline;
create policy onboarding_timeline_driver_insert on public.onboarding_timeline
  for insert to authenticated
  with check (auth.uid() = driver_id and actor_id = auth.uid());

-- storage upsert for document re-uploads
drop policy if exists driver_documents_storage_driver_update on storage.objects;
create policy driver_documents_storage_driver_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

grant select, insert, update on public.driver_documents to authenticated;
grant select, insert, update on public.driver_registration_drafts to authenticated;
grant select, insert, update on public.driver_hiring_pipeline to authenticated;
grant select, insert on public.onboarding_timeline to authenticated;

notify pgrst, 'reload schema';
