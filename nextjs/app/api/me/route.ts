import { eq } from "drizzle-orm";
import { db } from "@/db";
import { profile, user } from "@/db/schema";
import { withUser } from "@/lib/api";

export const GET = withUser(async (_req, me) => {
  const row = await db.query.profile.findFirst({ where: eq(profile.userId, me.id) });
  return Response.json({
    user: { id: me.id, email: me.email, name: me.name },
    profile: row ?? null,
  });
});

/** Permanently deletes the account and all training data (App Store 5.1.1(v)). */
export const DELETE = withUser(async (_req, me) => {
  await db.delete(user).where(eq(user.id, me.id));
  return new Response(null, { status: 204 });
});
