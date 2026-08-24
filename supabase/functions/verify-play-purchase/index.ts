// supabase/functions/verify-play-purchase/index.ts
//
// Validates a Google Play subscription purchase and writes the resulting tier.
//
// The client never writes its own tier: a modified APK could otherwise grant
// itself Gold. It sends only the purchase token, and this function asks Google
// whether that token is real, is for this app, and is currently paying.
//
// Required env vars (Supabase Dashboard → Edge Functions → Secrets):
//   PLAY_PACKAGE_NAME    - "com.harvestglass.harvest"
//   PLAY_CLIENT_EMAIL    - service account client_email with Play Developer API access
//   PLAY_PRIVATE_KEY     - that service account's private_key, BEGIN/END lines included
//
// The service account must be granted "View financial data" on the app in
// Play Console → Users and permissions, and the Play Developer API must be
// linked to the same Google Cloud project.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface VerifyRequest {
  user_id: string;
  product_id: string;
  purchase_token: string;
}

/** Product id → the tier name it grants. Mirrors ProductID in SubscriptionService.swift. */
const PRODUCT_TIERS: Record<string, string> = {
  "com.harvestglass.harvest.grow.weekly": "green",
  "com.harvestglass.harvest.grow.monthly": "green",
  "com.harvestglass.harvest.gold.weekly": "gold",
  "com.harvestglass.harvest.gold.monthly": "gold",
};

function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/\s/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

let cachedToken: { token: string; expiresAt: number } | null = null;

/** OAuth2 access token for the Play Developer API, cached until shortly before expiry. */
async function googleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.token;

  const clientEmail = Deno.env.get("PLAY_CLIENT_EMAIL")!;
  const pem = Deno.env.get("PLAY_PRIVATE_KEY")!.replace(/\\n/g, "\n");

  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/androidpublisher",
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
  cachedToken = { token: json.access_token, expiresAt: now + (json.expires_in ?? 3600) };
  return cachedToken.token;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let body: VerifyRequest;
  try {
    body = await req.json();
  } catch {
    return new Response("Bad request", { status: 400 });
  }

  if (!body.user_id || !body.product_id || !body.purchase_token) {
    return new Response("Missing fields", { status: 400 });
  }

  const tierName = PRODUCT_TIERS[body.product_id];
  if (!tierName) {
    console.error(`Unknown product id: ${body.product_id}`);
    return new Response("Unknown product", { status: 400 });
  }

  // The caller must be the user they claim to be: verify the JWT rather than
  // trusting user_id in the body, or anyone could upgrade anyone.
  const authHeader = req.headers.get("Authorization") ?? "";
  const anonClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: caller } = await anonClient.auth.getUser();
  if (!caller?.user || caller.user.id !== body.user_id) {
    return new Response("Forbidden", { status: 403 });
  }

  const packageName = Deno.env.get("PLAY_PACKAGE_NAME");
  if (!packageName) {
    console.error("PLAY_PACKAGE_NAME not set");
    return new Response("Not configured", { status: 500 });
  }

  // Ask Google whether this token is real and currently paying.
  let accessToken: string;
  try {
    accessToken = await googleAccessToken();
  } catch (error) {
    console.error("Play auth failed:", error);
    return new Response("Verification unavailable", { status: 502 });
  }

  const playUrl =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${packageName}/purchases/subscriptionsv2/tokens/${body.purchase_token}`;

  const playResponse = await fetch(playUrl, {
    headers: { authorization: `Bearer ${accessToken}` },
  });

  if (!playResponse.ok) {
    console.error(`Play verification rejected: ${playResponse.status}`);
    return new Response("Purchase not verified", { status: 402 });
  }

  const purchase = await playResponse.json();

  // Google is the authority on which product this token actually bought. Without
  // this check a cheap Grow token could be sent up claiming to be Gold.
  const purchasedIds: string[] = (purchase.lineItems ?? [])
    .map((item: { productId?: string }) => item.productId)
    .filter(Boolean);

  if (purchasedIds.length > 0 && !purchasedIds.includes(body.product_id)) {
    console.error(
      `Product mismatch: claimed ${body.product_id}, token is for ${purchasedIds.join(", ")}`,
    );
    return new Response("Purchase not verified", { status: 402 });
  }

  // ACTIVE and IN_GRACE_PERIOD both still entitle the user; anything else does
  // not. A cancelled-but-not-yet-expired subscription reports ACTIVE until its
  // period ends, which is the behaviour we want.
  const entitled =
    purchase.subscriptionState === "SUBSCRIPTION_STATE_ACTIVE" ||
    purchase.subscriptionState === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD";

  if (!entitled) {
    console.log(`Purchase not entitling: ${purchase.subscriptionState}`);
    return new Response(
      JSON.stringify({ entitled: false, state: purchase.subscriptionState }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  }

  // Service role: the client must not be able to write its own tier.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: tier, error: tierError } = await admin
    .from("subscription_tiers")
    .select("id")
    .eq("name", tierName)
    .limit(1)
    .maybeSingle();

  if (tierError || !tier) {
    console.error("Tier lookup failed:", tierError);
    return new Response("Tier not found", { status: 500 });
  }

  const now = new Date().toISOString();
  const { error: upsertError } = await admin
    .from("user_subscriptions")
    .upsert({
      user_id: body.user_id,
      tier_id: tier.id,
      status: "active",
      started_at: now,
      cancelled_at: null,
      updated_at: now,
    }, { onConflict: "user_id" });

  if (upsertError) {
    console.error("Failed to write subscription:", upsertError);
    return new Response("Server error", { status: 500 });
  }

  return new Response(
    JSON.stringify({ entitled: true, tier: tierName }),
    { status: 200, headers: { "content-type": "application/json" } },
  );
});
