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
  platform?: string;
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
    .select("apns_token, platform")
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

  // Only built when there is an iOS device to send to — an Android-only user
  // should not fail because the APNs secrets are absent.
  const hasApns = (devices as UserDevice[]).some((d) => d.platform !== "android");
  const jwt = hasApns ? await buildJwt() : "";

  let sent = 0;
  for (const device of devices as UserDevice[]) {
    const result = device.platform === "android"
      ? await sendToAndroidDevice(device.apns_token, body)
      : await sendToDevice(device.apns_token, body, jwt);

    if (result.status === 200) {
      sent++;
      continue;
    }

    // Stale token — purge so subsequent sends don't waste time on it.
    if (
      result.status === 410 ||
      (result.status === 400 && result.reason === "BadDeviceToken") ||
      // FCM reports a dead registration as 404 UNREGISTERED / 400 INVALID_ARGUMENT.
      (result.status === 404 && result.reason === "UNREGISTERED") ||
      (result.status === 400 && result.reason === "INVALID_ARGUMENT")
    ) {
      await supabase
        .from("user_devices")
        .delete()
        .eq("apns_token", device.apns_token);
      console.log(`Removed stale token: ${device.apns_token.substring(0, 8)}…`);
      continue;
    }

    console.error(
      `${device.platform === "android" ? "FCM" : "APNs"} error ${result.status} ` +
        `${result.reason ?? ""} for token ${device.apns_token.substring(0, 8)}…`,
    );
  }

  return new Response(JSON.stringify({ sent }), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
});

// ---------------------------------------------------------------------------
// FCM (Android)
//
// FCM v1 needs an OAuth2 access token minted from a service-account key, the
// same ES256/RS256 JWT dance as APNs but against Google's token endpoint.
//
// Required secrets:
//   FCM_PROJECT_ID           - Firebase project id
//   FCM_CLIENT_EMAIL         - service account client_email
//   FCM_PRIVATE_KEY          - service account private_key, with BEGIN/END lines
// ---------------------------------------------------------------------------

let cachedGoogleToken: { token: string; expiresAt: number } | null = null;

async function googleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedGoogleToken && cachedGoogleToken.expiresAt > now + 60) {
    return cachedGoogleToken.token;
  }

  const clientEmail = Deno.env.get("FCM_CLIENT_EMAIL")!;
  const pem = Deno.env.get("FCM_PRIVATE_KEY")!.replace(/\\n/g, "\n");

  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const signingInput =
    `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(pem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );

  const assertion = `${signingInput}.${base64url(new Uint8Array(signature))}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(`Google token exchange failed: ${response.status}`);
  }

  const json = await response.json();
  cachedGoogleToken = {
    token: json.access_token,
    expiresAt: now + (json.expires_in ?? 3600),
  };
  return cachedGoogleToken.token;
}

async function sendToAndroidDevice(
  token: string,
  body: PushRequest,
): Promise<{ status: number; reason?: string }> {
  const projectId = Deno.env.get("FCM_PROJECT_ID");
  if (!projectId) {
    // Android push not configured yet: report rather than throw, so an iOS
    // send in the same call still goes out.
    return { status: 500, reason: "FCM_NOT_CONFIGURED" };
  }

  let accessToken: string;
  try {
    accessToken = await googleAccessToken();
  } catch (error) {
    console.error("FCM auth failed:", error);
    return { status: 500, reason: "FCM_AUTH_FAILED" };
  }

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: body.payload.title,
            body: body.payload.body,
          },
          // Key matches the iOS payload's `deepLink` so both clients route
          // through the same handler.
          data: { deepLink: body.payload.deepLink },
          android: { priority: "high" },
        },
      }),
    },
  );

  if (response.status === 200) return { status: 200 };

  const errorBody = await response.json().catch(() => null);
  return {
    status: response.status,
    reason: errorBody?.error?.status ?? errorBody?.error?.message,
  };
}
