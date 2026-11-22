// Sends FCM v1 push messages for rows inserted into public.notifications.
// Secrets: FIREBASE_SERVICE_ACCOUNT (service account JSON, as a string), PUSH_SECRET.
import { createClient } from "jsr:@supabase/supabase-js@2";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

interface PushPayload {
  user_id?: string;
  user_ids?: string[];
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

function base64Url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToBytes(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const raw = atob(body);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes;
}

let cachedToken: { value: string; expiresAt: number } | null = null;

async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(
    JSON.stringify({
      iss: account.client_email,
      scope: FCM_SCOPE,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const json = await response.json();
  if (!response.ok) {
    throw new Error(`token ${response.status}: ${JSON.stringify(json)}`);
  }
  cachedToken = { value: json.access_token, expiresAt: now + (json.expires_in ?? 3600) };
  return cachedToken.value;
}

function stringData(data?: Record<string, unknown>): Record<string, string> {
  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(data ?? {})) {
    if (value == null) continue;
    result[key] = typeof value === "string" ? value : JSON.stringify(value);
  }
  return result;
}

async function sendToToken(
  token: string,
  bearer: string,
  projectId: string,
  payload: PushPayload,
): Promise<"ok" | "gone" | "error"> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${bearer}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: payload.title, body: payload.body },
          data: stringData(payload.data),
          android: { priority: "high", notification: { sound: "default" } },
        },
      }),
    },
  );

  if (response.ok) return "ok";

  const text = await response.text();
  if (response.status === 404 || text.includes("UNREGISTERED") || text.includes("INVALID_ARGUMENT")) {
    return "gone";
  }
  console.error("fcm failure", response.status, text);
  return "error";
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const secret = Deno.env.get("PUSH_SECRET") ?? "";
  const provided = req.headers.get("x-push-secret") ?? "";
  if (!secret || provided !== secret) {
    return new Response("forbidden", { status: 403 });
  }

  let payload: PushPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response("invalid json", { status: 400 });
  }

  const userIds = payload.user_ids ?? (payload.user_id ? [payload.user_id] : []);
  if (userIds.length === 0 || !payload.title) {
    return new Response("missing user/title", { status: 400 });
  }

  const account: ServiceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");
  if (!account.project_id || !account.private_key) {
    return new Response("firebase service account missing", { status: 500 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: rows, error } = await supabase
    .from("device_tokens")
    .select("token")
    .in("user_id", userIds);
  if (error) return new Response(error.message, { status: 500 });

  const tokens = [...new Set((rows ?? []).map((row) => row.token as string))];
  if (tokens.length === 0) {
    return Response.json({ sent: 0, removed: 0, tokens: 0 });
  }

  let bearer: string;
  try {
    bearer = await accessToken(account);
  } catch (error) {
    console.error(String(error));
    return new Response("firebase auth failed", { status: 502 });
  }

  let sent = 0;
  const gone: string[] = [];
  for (const token of tokens) {
    const result = await sendToToken(token, bearer, account.project_id, payload);
    if (result === "ok") sent += 1;
    if (result === "gone") gone.push(token);
  }

  if (gone.length > 0) {
    await supabase.from("device_tokens").delete().in("token", gone);
  }

  return Response.json({ sent, removed: gone.length, tokens: tokens.length });
});
