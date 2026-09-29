import { and, desc, eq, lt } from "drizzle-orm";
import { db } from "@/db";
import { run, workout } from "@/db/schema";
import { notFound, parseBody, withUser } from "@/lib/api";
import { assertOwnWorkout, releaseWorkout, runSummaryColumns } from "@/lib/runs";
import { runInputSchema } from "@/lib/training/types";

/** Newest first. Paginate with `?before=<ISO startedAt>`. */
export const GET = withUser(async (req, me) => {
  const { searchParams } = new URL(req.url);
  const before = searchParams.get("before");
  const limit = Math.min(Number(searchParams.get("limit")) || 50, 200);

  const runs = await db
    .select(runSummaryColumns)
    .from(run)
    .where(
      and(eq(run.userId, me.id), before ? lt(run.startedAt, new Date(before)) : undefined),
    )
    .orderBy(desc(run.startedAt))
    .limit(limit);
  return Response.json({ runs });
});

/** Idempotent create-or-replace keyed by the client-generated run ID. */
export const POST = withUser(async (req, me) => {
  const input = await parseBody(req, runInputSchema);
  await assertOwnWorkout(me.id, input.workoutId);

  const previous = await db.query.run.findFirst({
    where: and(eq(run.id, input.id), eq(run.userId, me.id)),
    columns: { workoutId: true },
  });

  const values = { ...input, userId: me.id, startedAt: new Date(input.startedAt) };
  const { id: _id, ...updates } = values;
  const upsert = db
    .insert(run)
    .values(values)
    .onConflictDoUpdate({ target: run.id, set: updates, setWhere: eq(run.userId, me.id) })
    .returning();

  let saved: typeof run.$inferSelect | undefined;
  let linked: typeof workout.$inferSelect | null = null;
  if (input.workoutId) {
    const [[r], [w]] = await db.batch([
      upsert,
      db
        .update(workout)
        .set({ status: "completed" })
        .where(eq(workout.id, input.workoutId))
        .returning(),
    ]);
    saved = r;
    linked = w ?? null;
  } else {
    [saved] = await upsert;
  }
  if (!saved) throw notFound();

  if (previous?.workoutId && previous.workoutId !== input.workoutId) {
    await releaseWorkout(previous.workoutId, saved.id);
  }

  return Response.json({ run: saved, workout: linked }, { status: 201 });
});
