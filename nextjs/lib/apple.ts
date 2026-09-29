import "server-only";
import { and, eq } from "drizzle-orm";
import { importPKCS8, SignJWT } from "jose";
import { db } from "@/db";
import { account } from "@/db/schema";
import { IOS_BUNDLE_ID } from "@/lib/auth";

const APPLE = "https://appleid.apple.com";

/** Short-lived client secret JWT for Apple's token and revoke endpoints. */
async function clientSecret() {
  const { APPLE_PRIVATE_KEY, APPLE_KEY_ID, APPLE_TEAM_ID } = process.env;
  if (!APPLE_PRIVATE_KEY || !APPLE_KEY_ID || !APPLE_TEAM_ID) {
    throw new Error("Sign in with Apple key is not configured");
  }
  const key = await importPKCS8(APPLE_PRIVATE_KEY.replace(/\\n/g, "\n"), "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: APPLE_KEY_ID })
    .setIssuer(APPLE_TEAM_ID)
    .setSubject(IOS_BUNDLE_ID)
    .setAudience(APPLE)
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(key);
}

async function post(path: string, params: Record<string, string>) {
  return fetch(`${APPLE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: IOS_BUNDLE_ID,
      client_secret: await clientSecret(),
      ...params,
    }),
  });
}

/**
 * Exchanges the one-time authorization code from a native Apple sign-in for a
 * refresh token, stored so it can be revoked when the account is deleted.
 */
export async function storeAppleRefreshToken(userId: string, code: string) {
  const res = await post("/auth/token", { code, grant_type: "authorization_code" });
  if (!res.ok) throw new Error(`Apple token exchange failed: ${res.status} ${await res.text()}`);
  const { refresh_token } = (await res.json()) as { refresh_token?: string };
  if (!refresh_token) throw new Error("Apple token exchange returned no refresh token");

  await db
    .update(account)
    .set({ refreshToken: refresh_token })
    .where(and(eq(account.userId, userId), eq(account.providerId, "apple")));
}

/** Revokes the user's Sign in with Apple authorization (App Store 5.1.1(v)). */
export async function revokeAppleTokens(userId: string) {
  const row = await db.query.account.findFirst({
    where: and(eq(account.userId, userId), eq(account.providerId, "apple")),
    columns: { refreshToken: true },
  });
  if (!row?.refreshToken) return false;

  const res = await post("/auth/revoke", {
    token: row.refreshToken,
    token_type_hint: "refresh_token",
  });
  if (!res.ok) throw new Error(`Apple revoke failed: ${res.status} ${await res.text()}`);
  return true;
}
