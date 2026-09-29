import { db } from "@/db";
import { profile } from "@/db/schema";
import { parseBody, withUser } from "@/lib/api";
import { profileInputSchema } from "@/lib/training/types";

export const PUT = withUser(async (req, me) => {
  const input = await parseBody(req, profileInputSchema);
  const values = { ...input, userId: me.id, runDays: [...new Set(input.runDays)].sort() };
  const [row] = await db
    .insert(profile)
    .values(values)
    .onConflictDoUpdate({ target: profile.userId, set: values })
    .returning();
  return Response.json({ profile: row });
});
