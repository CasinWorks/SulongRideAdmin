-- Step 3 of 3 — create your operator row (run AFTER step 1 + 2).
--
-- 1. Supabase Dashboard → Authentication → Users → Add user (email + password)
-- 2. Copy that user's UUID
-- 3. Replace the placeholders below and run in SQL Editor

-- insert into public.operators (id, email, full_name)
-- values ('YOUR_AUTH_USER_UUID', 'ops@yourdomain.com', 'Operator Name');

-- Approve test drivers for Carmona pilot:
-- update public.drivers set approval_status = 'approved' where email = 'driver@example.com';

-- Verify:
-- select * from public.fare_config where is_active = true;
-- select id, email, approval_status from public.drivers limit 20;
