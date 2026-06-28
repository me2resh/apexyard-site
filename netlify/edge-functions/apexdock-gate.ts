// Basic-auth gate for /apexdock/* — per-founder credentials.
//
// Credentials live ONLY in the Netlify env var `APEXDOCK_CREDS` (never in the
// repo). Format: comma- or newline-separated `username:<sha256-hex-of-password>`
// pairs — one per founder. Passwords are stored HASHED so the env var holds no
// plaintext. Generate a founder's hash with:
//
//     printf '%s' 'their-password' | shasum -a 256   # → the 64-char hex
//
// Add a founder  → append `user:<hash>` to APEXDOCK_CREDS in Netlify.
// Revoke a founder → remove their pair. (No redeploy needed for env-var edits.)
//
// Gating happens at the edge, so it covers the page AND the .dmg under
// /apexdock/assets/. Served over HTTPS, so Basic credentials are encrypted in
// transit.

import type { Context } from "https://edge.netlify.com";

const REALM = "ApexDock — restricted";

function unauthorized(): Response {
  return new Response("Authentication required.", {
    status: 401,
    headers: {
      "WWW-Authenticate": `Basic realm="${REALM}", charset="UTF-8"`,
      "Cache-Control": "no-store",
    },
  });
}

async function sha256hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Constant-time string compare (avoids leaking match length via timing).
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return result === 0;
}

function parseCreds(raw: string): Map<string, string> {
  const creds = new Map<string, string>();
  for (const pair of raw.split(/[,\n]/)) {
    const trimmed = pair.trim();
    if (!trimmed) continue;
    const sep = trimmed.indexOf(":");
    if (sep < 0) continue;
    const user = trimmed.slice(0, sep).trim();
    const hash = trimmed.slice(sep + 1).trim().toLowerCase();
    if (user && hash) creds.set(user, hash);
  }
  return creds;
}

export default async (request: Request, context: Context): Promise<Response> => {
  const header = request.headers.get("authorization") ?? "";
  if (!header.startsWith("Basic ")) return unauthorized();

  let decoded = "";
  try {
    decoded = atob(header.slice(6));
  } catch {
    return unauthorized();
  }
  const sep = decoded.indexOf(":");
  if (sep < 0) return unauthorized();
  const user = decoded.slice(0, sep);
  const password = decoded.slice(sep + 1);

  const creds = parseCreds(Deno.env.get("APEXDOCK_CREDS") ?? "");
  // Fail closed: no creds configured → nobody gets in.
  const expected = creds.get(user);
  if (!expected) return unauthorized();

  const got = await sha256hex(password);
  if (!timingSafeEqual(got, expected)) return unauthorized();

  // Authorized — let the static file (page or .dmg) serve normally.
  return context.next();
};
