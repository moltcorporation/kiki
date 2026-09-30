import { and, asc, desc, eq, gte, ne } from "drizzle-orm";
import { FatalError } from "workflow";
import { db } from "@/db";
import { plan, planAdjustment, run, workout } from "@/db/schema";
import {
  generateAdjustment,
  type AdjustmentContext,
  type PlannedWorkout,
} from "@/lib/training/coach";
import { loadRunner, toGoalContext } from "@/lib/training/context";
import { addDays } from "@/lib/training/dates";

/** Applies an AI coach adjustment to the runner's upcoming workouts. */
export async function adjustPlanWorkflow(adjustmentId: string, today: string) {
  "use workflow";

  try {
    const ctx = await loadContext(adjustmentId, today);
    const result = await proposeChanges(ctx);
    await applyChanges(adjustmentId, result.reply, result.changes);
    return { changed: result.changes.length };
  } catch (error) {
    await markFailed(adjustmentId);
    throw error;
  }
}

async function loadContext(adjustmentId: string, today: string): Promise<AdjustmentContext> {
  "use step";
  const adj = await db.query.planAdjustment.findFirst({
    where: eq(planAdjustment.id, adjustmentId),
  });
  if (!adj) throw new FatalError(`Adjustment ${adjustmentId} not found`);
  const planRow = await db.query.plan.findFirst({ where: eq(plan.id, adj.planId) });
  if (!planRow || planRow.status !== "ready") throw new FatalError("Plan is not ready");

  const [runner, workouts, recentRuns] = await Promise.all([
    loadRunner(adj.userId),
    db
      .select()
      .from(workout)
      .where(and(eq(workout.planId, planRow.id), gte(workout.date, addDays(today, -7))))
      .orderBy(asc(workout.date)),
    db
      .select()
      .from(run)
      .where(and(eq(run.userId, adj.userId), gte(run.startedAt, new Date(`${addDays(today, -21)}T00:00:00Z`))))
      .orderBy(desc(run.startedAt))
      .limit(20),
  ]);

  return {
    runner,
    goal: toGoalContext(planRow),
    today,
    planSummary: planRow.summary,
    paces: planRow.paces,
    workouts: workouts.map((w) => ({
      date: w.date,
      week: w.week,
      type: w.type,
      title: w.title,
      description: w.description,
      distanceM: w.distanceM,
      durationS: w.durationS,
      steps: w.steps,
      status: w.status,
    })),
    recentRuns: recentRuns.map((r) => ({
      date: r.startedAt.toISOString().slice(0, 10),
      distanceM: r.distanceM,
      durationS: r.durationS,
      effort: r.effort,
      feeling: r.feeling,
      notes: r.notes,
    })),
    reason: adj.reason,
    message: adj.message,
  };
}

async function proposeChanges(ctx: AdjustmentContext) {
  "use step";
  return generateAdjustment(ctx);
}

async function applyChanges(adjustmentId: string, reply: string, changes: PlannedWorkout[]) {
  "use step";
  const adj = await db.query.planAdjustment.findFirst({
    where: eq(planAdjustment.id, adjustmentId),
  });
  if (!adj || adj.status === "applied") return;

  await db.batch([
    db
      .update(planAdjustment)
      .set({ status: "applied", reply, changedDates: changes.map((w) => w.date) })
      .where(eq(planAdjustment.id, adjustmentId)),
    ...changes.map((w) =>
      db
        .update(workout)
        .set({
          type: w.type,
          title: w.title,
          description: w.description,
          distanceM: w.distanceM,
          durationS: w.durationS,
          steps: w.steps,
          status: "planned",
        })
        .where(
          and(
            eq(workout.planId, adj.planId),
            eq(workout.date, w.date),
            ne(workout.status, "completed"),
          ),
        ),
    ),
  ]);
}

async function markFailed(adjustmentId: string) {
  "use step";
  await db
    .update(planAdjustment)
    .set({ status: "failed" })
    .where(and(eq(planAdjustment.id, adjustmentId), eq(planAdjustment.status, "pending")));
}
