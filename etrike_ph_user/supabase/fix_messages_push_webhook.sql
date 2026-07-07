-- Optional: FCM push when app is fully closed (requires Firebase + Edge Function deploy).
-- See supabase/functions/notify-chat-message/README.md
--
-- After deploying the function, add a Database Webhook in Supabase Dashboard:
--   Table: messages | Event: INSERT | URL: your notify-chat-message function URL
--
-- In-app + background (app still running) notifications work without this via
-- fix_messages_realtime.sql + the mobile apps' local notification listener.

notify pgrst, 'reload schema';
