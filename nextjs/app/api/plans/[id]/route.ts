import { and, eq } from "drizzle-orm";
import { db } from "@/db";
import { plan } from "@/db/schema";
import { notFound, uuidParam, withUser } from "@/lib/api";
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
