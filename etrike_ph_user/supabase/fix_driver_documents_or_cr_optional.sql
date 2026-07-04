-- Sulong Ride: OR/CR (lto_or, lto_cr) optional for company-owned fleet drivers.
-- No column drops — doc_type remains free text in driver_documents.
--
-- App/admin checklist no longer requires lto_or or lto_cr.
-- Existing rows are preserved; optionally mark legacy uploads as not_required:

-- update public.driver_documents
-- set status = 'not_required', admin_notes = coalesce(admin_notes, 'Legacy — company fleet; OR/CR not required')
-- where doc_type in ('lto_or', 'lto_cr');

-- Vehicle assignment: use vehicles.assigned_driver_id + driver_registration_drafts.employment.vehicle_id
-- (already in fix_driver_onboarding.sql). Operators assign unit in admin Employment step.
