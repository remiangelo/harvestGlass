// supabase/functions/send-push/index.ts
//
// Sends APNs pushes to a user's registered devices.
//
// Invoked by Postgres triggers via pg_net (see migration
// 20260524130000_push_notification_triggers.sql). Not user-facing.
//
// Required env vars (set in Supabase Dashboard → Edge Functions → Secrets):
//   APNS_KEY_ID       - 10-char Key ID from Apple Developer
//   APNS_TEAM_ID      - 10-char Team ID from Apple Developer
//   APNS_BUNDLE_ID    - e.g. "HarvestGlass.Harvest"
//   APNS_AUTH_KEY     - Full .p8 file contents with BEGIN/END lines
//   APNS_ENVIRONMENT  - "production" (TestFlight + App Store) or "development" (Xcode dev builds)
//
// Also requires the standard Supabase Edge Function env vars
// (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY) which are auto-injected.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// -------- types

interface SendPushRequest {
  recipient_user_id: string;
  type: "message" | "match" | "like" | "seed";
  payload: {
    title: string;
    body: string;
    deepLink: string;
    threadId?: string;
    badgeCount?: number;
  };
}

interface UserDevice {
  apns_token: string;
}

// -------- JWT cache (warm-start across invocations)

let cachedJwt: { token: string; issuedAt: number } | null = null;
const JWT_MAX_AGE_SECONDS = 50 * 60; // refresh 10 min before APNs's 60-min limit

// -------- JWT signing

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function base64url(input: Uint8Array | string): string {
  const bytes =
    typeof input === "string"
      ? new TextEncoder().encode(input)
      : input;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

async function buildJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.issuedAt < JWT_MAX_AGE_SECONDS) {
    return cachedJwt.token;
  }

  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const pem = Deno.env.get("APNS_AUTH_KEY")!;

  const header = { alg: "ES256", kid: keyId };
  const claims = { iss: teamId, iat: now };

  const headerB64 = base64url(JSON.stringify(header));
  const claimsB64 = base64url(JSON.stringify(claims));
  const signingInput = `${headerB64}.${claimsB64}`;

  const keyData = pemToArrayBuffer(pem);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const sigBuf = await crypto.subtle.sign(
    { name: "ECDSA", hash: { name: "SHA-256" } },
    key,
    new TextEncoder().encode(signingInput),
  );
  const sigB64 = base64url(new Uint8Array(sigBuf));

  const token = `${signingInput}.${sigB64}`;
  cachedJwt = { token, issuedAt: now };
  return token;
}

// -------- APNs delivery

function apnsHost(): string {
  const env = Deno.env.get("APNS_ENVIRONMENT") ?? "production";
  return env === "development"
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";
}

async function sendToDevice(
  token: string,
  body: SendPushRequest,
  jwt: string,
): Promise<{ status: number; reason?: string }> {
  const apsAlert = { title: body.payload.title, body: body.payload.body };
  const apnsPayload: Record<string, unknown> = {
    aps: {
      alert: apsAlert,
      sound: "default",
      ...(body.payload.threadId ? { "thread-id": body.payload.threadId } : {}),
      ...(body.payload.badgeCount !== undefined
        ? { badge: body.payload.badgeCount }
        : {}),
    },
    deepLink: body.payload.deepLink,
  };

  const collapseId =
    body.payload.threadId ?? `${body.type}:${body.recipient_user_id}`;

  const res = await fetch(`https://${apnsHost()}/3/device/${token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": Deno.env.get("APNS_BUNDLE_ID")!,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-collapse-id": collapseId,
      "content-type": "application/json",
    },
    body: JSON.stringify(apnsPayload),
  });

  if (res.status === 200) return { status: 200 };

  let reason: string | undefined;
  try {
    const json = await res.json();
    reason = json?.reason;
  } catch { /* APNs may return empty body on some errors */ }

  return { status: res.status, reason };
}

// -------- main

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  let body: SendPushRequest;
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  if (
    !body.recipient_user_id ||
    !body.type ||
    !body.payload?.title ||
    !body.payload?.body ||
    !body.payload?.deepLink
  ) {
    return new Response("Missing required fields", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: devices, error: fetchError } = await supabase
    .from("user_devices")
    .select("apns_token")
    .eq("user_id", body.recipient_user_id);

  if (fetchError) {
    console.error("Failed to fetch devices:", fetchError);
    return new Response("Server error", { status: 500 });
  }

  if (!devices || devices.length === 0) {
    return new Response(JSON.stringify({ sent: 0, reason: "no_devices" }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }

  const jwt = await buildJwt();

  let sent = 0;
  for (const device of devices as UserDevice[]) {
    const result = await sendToDevice(device.apns_token, body, jwt);

    if (result.status === 200) {
      sent++;
      continue;
    }

    // Stale token — purge so subsequent sends don't waste time on it.
    if (
      result.status === 410 ||
      (result.status === 400 && result.reason === "BadDeviceToken")
    ) {
      await supabase
        .from("user_devices")
        .delete()
        .eq("apns_token", device.apns_token);
      console.log(`Removed stale token: ${device.apns_token.substring(0, 8)}…`);
      continue;
    }

    console.error(
      `APNs error ${result.status} ${result.reason ?? ""} for token ${device.apns_token.substring(0, 8)}…`,
    );
  }

  return new Response(JSON.stringify({ sent }), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
});
