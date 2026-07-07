-- Supabase Storage for driver onboarding documents.
-- Run after fix_driver_onboarding.sql
-- Create bucket in Dashboard → Storage if insert below fails (name: driver-documents, public read optional).

insert into storage.buckets (id, name, public)
values ('driver-documents', 'driver-documents', true)
on conflict (id) do update set public = true;

drop policy if exists driver_documents_storage_operator on storage.objects;
create policy driver_documents_storage_operator on storage.objects
  for all to authenticated
  using (
    bucket_id = 'driver-documents'
    and exists (select 1 from public.operators o where o.id = auth.uid())
  )
  with check (
    bucket_id = 'driver-documents'
    and exists (select 1 from public.operators o where o.id = auth.uid())
  );

drop policy if exists driver_documents_storage_driver_read on storage.objects;
create policy driver_documents_storage_driver_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists driver_documents_storage_driver_upload on storage.objects;
create policy driver_documents_storage_driver_upload on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
