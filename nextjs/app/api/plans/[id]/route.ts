import { and, eq } from "drizzle-orm";
import { db } from "@/db";
import { plan } from "@/db/schema";
import { z } from "zod";
import { notFound, parseBody, uuidParam, withUser } from "@/lib/api";
import { workoutsFor } from "@/lib/plans";

/** Poll while generating; includes workouts once ready. */
export const GET = withUser(async (_req, me, { params }: RouteContext<"/api/plans/[id]">) => {
  const id = uuidParam((await params).id);
  const row = await db.query.plan.findFirst({
    where: and(eq(plan.id, id), eq(plan.userId, me.id)),
  });
  if (!row) throw notFound();
  return Response.json({
    plan: row,
    workouts: row.status === "ready" ? await workoutsFor(row.id) : [],
  });
});

const patchSchema = z.object({
  /** A label only; changing it doesn't touch the workouts. */
  raceName: z.string().trim().max(80).nullable(),
});

/** Updates plan details that don't change the training (the race name). */
export const PATCH = withUser(async (req, me, { params }: RouteContext<"/api/plans/[id]">) => {
  const id = uuidParam((await params).id);
  const { raceName } = await parseBody(req, patchSchema);
  const [row] = await db
    .update(plan)
    .set({ raceName: raceName || null })
    .where(and(eq(plan.id, id), eq(plan.userId, me.id)))
    .returning();
  if (!row) throw notFound();
  return Response.json({ plan: row });
});
