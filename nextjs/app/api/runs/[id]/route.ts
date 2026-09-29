import { and, eq } from "drizzle-orm";
import { db } from "@/db";
import { run } from "@/db/schema";
import { notFound, uuidParam, withUser } from "@/lib/api";
import { releaseWorkout } from "@/lib/runs";

type Ctx = RouteContext<"/api/runs/[id]">;

/** Full run including route and splits. */
export const GET = withUser(async (_req, me, { params }: Ctx) => {
  const id = uuidParam((await params).id);
  const row = await db.query.run.findFirst({ where: and(eq(run.id, id), eq(run.userId, me.id)) });
  if (!row) throw notFound();
  return Response.json({ run: row });
});

export const DELETE = withUser(async (_req, me, { params }: Ctx) => {
  const id = uuidParam((await params).id);
  const [deleted] = await db
    .delete(run)
    .where(and(eq(run.id, id), eq(run.userId, me.id)))
    .returning({ id: run.id, workoutId: run.workoutId });
  if (deleted) await releaseWorkout(deleted.workoutId, deleted.id);
  return new Response(null, { status: 204 });
});
