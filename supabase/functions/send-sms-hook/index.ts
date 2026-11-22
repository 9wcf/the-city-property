// Supabase Auth "send_sms" hook adapter for OTPiq (https://otpiq.com).
// GoTrue posts { user: { phone }, sms: { otp } } signed with Standard Webhooks;
// the code is forwarded to OTPiq's verification endpoint (Iraq-capable SMS/WhatsApp).

const OTPIQ_URL = "https://api.otpiq.com/api/sms";

function resolveHookSecret(): string {
  return (Deno.env.get("SEND_SMS_HOOK_SECRET") ?? "").replace(/^v1,whsec_/, "");
}

async function importHookKey(): Promise<CryptoKey> {
  const bytes = Uint8Array.from(atob(resolveHookSecret()), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey("raw", bytes, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
}

function timingSafeEqual(a: string, b: string): boolean {
  const ba = new TextEncoder().encode(a);
  const bb = new TextEncoder().encode(b);
  if (ba.length !== bb.length) return false;
  let diff = 0;
  for (let i = 0; i < ba.length; i++) diff |= ba[i] ^ bb[i];
  return diff === 0;
}

async function verifySignature(req: Request, rawBody: string): Promise<boolean> {
  const id = req.headers.get("webhook-id");
  const timestamp = req.headers.get("webhook-timestamp");
  const signatureHeader = req.headers.get("webhook-signature");
  if (!id || !timestamp || !signatureHeader) return false;

  const ageSeconds = Math.abs(Date.now() / 1000 - Number(timestamp));
  if (!Number.isFinite(ageSeconds) || ageSeconds > 300) return false;

  const key = await importHookKey();
  const signedContent = `${id}.${timestamp}.${rawBody}`;
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(signedContent));
  const expected = "v1," + btoa(String.fromCharCode(...new Uint8Array(mac)));
  return signatureHeader.split(" ").some((sig) => timingSafeEqual(sig, expected));
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  const rawBody = await req.text();
  if (!(await verifySignature(req, rawBody))) {
    return Response.json({ error: { http_code: 401, message: "invalid signature" } }, { status: 401 });
  }

  let payload: { user?: { phone?: string }; sms?: { otp?: string } };
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return Response.json({ error: { http_code: 400, message: "invalid json" } }, { status: 400 });
  }

  const phoneNumber = (payload.user?.phone ?? "").replace(/^\+/, "").replace(/\D/g, "");
  const otp = payload.sms?.otp ?? "";
  if (!/^[0-9]{10,15}$/.test(phoneNumber) || !/^[0-9]{6}$/.test(otp)) {
    return Response.json({ error: { http_code: 400, message: "invalid payload" } }, { status: 400 });
  }

  const apiKey = Deno.env.get("OTPIQ_API_KEY") ?? "";
  let otpiqResponse: Response;
  try {
    otpiqResponse = await fetch(OTPIQ_URL, {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ phoneNumber, smsType: "verification", verificationCode: otp }),
      signal: AbortSignal.timeout(10_000),
    });
  } catch (err) {
    return Response.json(
      { error: { http_code: 502, message: `otpiq unreachable: ${String(err)}` } },
      { status: 502 },
    );
  }

  if (!otpiqResponse.ok) {
    const detail = (await otpiqResponse.text()).slice(0, 300);
    return Response.json(
      { error: { http_code: 502, message: `otpiq error ${otpiqResponse.status}: ${detail}` } },
      { status: 502 },
    );
  }

  return Response.json({});
});
