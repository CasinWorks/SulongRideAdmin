# notify-chat-message (optional FCM)

Sends a push notification to the trip participant who did **not** send the chat message.

## Prerequisites

1. Firebase project with Cloud Messaging enabled
2. APNs key uploaded (iOS) in Firebase Console
3. `GoogleService-Info.plist` / `google-services.json` in both mobile apps
4. `firebase_messaging` wired in Flutter (not yet in pilot build)
5. Supabase Edge Function secrets:
   - `FIREBASE_SERVICE_ACCOUNT_JSON` — Firebase service account JSON (string)
   - `SUPABASE_URL` — auto-injected
   - `SUPABASE_SERVICE_ROLE_KEY` — auto-injected

## Deploy

```bash
cd etrike_ph_user
supabase functions deploy notify-chat-message --no-verify-jwt
```

## Database webhook

Supabase Dashboard → Database → Webhooks → Create:

| Field | Value |
|-------|--------|
| Table | `messages` |
| Events | Insert |
| Type | Supabase Edge Function |
| Function | `notify-chat-message` |

## Without Firebase

The rider and driver apps already show **local notifications** when:

- There is an active trip
- A new message arrives via Supabase Realtime
- Chat is not open
- Push notifications are enabled in Settings

Run `fix_messages_realtime.sql` in the SQL Editor for instant delivery.
