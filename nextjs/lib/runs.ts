import "server-only";
import { and, count, eq, getTableColumns, ne } from "drizzle-orm";
import { db } from "@/db";
import { run, workout } from "@/db/schema";
import { ApiError } from "@/lib/api";

/** Run columns for list views (without the heavy route and splits). */
const { route: _route, splits: _splits, ...summaryColumns } = getTableColumns(run);
export const runSummaryColumns = summaryColumns;

export async function assertOwnWorkout(userId: string, workoutId: string | null | undefined) {
  if (!workoutId) return;
  const row = await db.query.workout.findFirst({
    where: and(eq(workout.id, workoutId), eq(workout.userId, userId)),
    columns: { id: true },
  });
  if (!row) throw new ApiError(400, "invalid_workout", "Workout not found");
}

/** Reverts a workout to planned when its last linked run goes away. */
export async function releaseWorkout(workoutId: string | null, exceptRunId: string) {
  if (!workoutId) return;
  const [{ linked }] = await db
    .select({ linked: count() })
    .from(run)
    .where(and(eq(run.workoutId, workoutId), ne(run.id, exceptRunId)));
  if (linked === 0) {
    await db
      .update(workout)
      .set({ status: "planned" })
      .where(and(eq(workout.id, workoutId), eq(workout.status, "completed")));
  }
}
