import { eq } from "drizzle-orm";
import { db } from "@/db";
import { profile, user } from "@/db/schema";
import { withUser } from "@/lib/api";
import { revokeAppleTokens } from "@/lib/apple";
import { captureServerError } from "@/lib/posthog-server";

export const GET = withUser(async (_req, me) => {
  const row = await db.query.profile.findFirst({ where: eq(profile.userId, me.id) });
  return Response.json({
    user: { id: me.id, email: me.email, name: me.name },
    profile: row ?? null,
  });
});

/**
 * Permanently deletes the account and all training data, and revokes the
 * Sign in with Apple authorization (App Store guideline 5.1.1(v)).
 */
export const DELETE = withUser(async (_req, me) => {
  try {
    await revokeAppleTokens(me.id);
  } catch (error) {
    // Deletion must still succeed; surface the revoke failure for follow-up.
    await captureServerError(error, me.id, { step: "apple_revoke" });
  }
  await db.delete(user).where(eq(user.id, me.id));
  return new Response(null, { status: 204 });
});
