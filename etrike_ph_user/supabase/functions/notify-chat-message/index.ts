import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface MessageRow {
  id: string;
  trip_id: string;
  sender_id: string;
  sender_role: string;
  message: string;
}

interface TripRow {
  rider_id: string;
  driver_id: string | null;
}

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors });
  }

  try {
    const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!saJson) {
      return new Response(JSON.stringify({ skipped: true, reason: 'FCM not configured' }), {
        status: 200,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json();
    const record = (body.record ?? body) as MessageRow;
    if (!record?.trip_id || !record?.sender_id) {
      return new Response(JSON.stringify({ error: 'invalid payload' }), { status: 400 });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: trip, error: tripErr } = await supabase
      .from('trips')
      .select('rider_id, driver_id')
      .eq('id', record.trip_id)
      .maybeSingle();

    if (tripErr || !trip) {
      return new Response(JSON.stringify({ error: tripErr?.message ?? 'trip not found' }), {
        status: 404,
      });
    }

    const t = trip as TripRow;
    const recipientId =
      record.sender_id === t.rider_id ? t.driver_id : t.rider_id;
    if (!recipientId) {
      return new Response(JSON.stringify({ skipped: true, reason: 'no recipient' }), {
        status: 200,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    const table = recipientId === t.rider_id ? 'users' : 'drivers';
    const { data: profile } = await supabase
      .from(table)
      .select('fcm_token')
      .eq('id', recipientId)
      .maybeSingle();

    const token = profile?.fcm_token as string | undefined;
    if (!token) {
      return new Response(JSON.stringify({ skipped: true, reason: 'no fcm token' }), {
        status: 200,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    const accessToken = await getGoogleAccessToken(saJson);
    const title =
      record.sender_role === 'driver' ? 'Message from driver' : 'Message from rider';
    const preview =
      record.message.length > 120
        ? `${record.message.slice(0, 120)}…`
        : record.message;

    const fcmRes = await fetch(
      'https://fcm.googleapis.com/v1/projects/' +
        JSON.parse(saJson).project_id +
        '/messages:send',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body: preview },
            data: { trip_id: record.trip_id, type: 'chat_message' },
          },
        }),
      },
    );

    const fcmBody = await fcmRes.text();
    return new Response(fcmBody, {
      status: fcmRes.status,
      headers: { ...cors, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }
});

async function getGoogleAccessToken(serviceAccountJson: string): Promise<string> {
  const sa = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = btoa(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${claim}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${btoa(String.fromCharCode(...new Uint8Array(sig)))}`;
  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const tokenJson = await tokenRes.json();
  return tokenJson.access_token as string;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const raw = atob(b64);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}
