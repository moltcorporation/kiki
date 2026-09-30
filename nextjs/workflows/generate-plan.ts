import { and, eq, ne } from "drizzle-orm";
import { FatalError } from "workflow";
import { db } from "@/db";
import { plan, workout } from "@/db/schema";
import {
  generatePlan,
  type GeneratedPlan,
  type GoalContext,
  type RunnerContext,
} from "@/lib/training/coach";
import { loadRunner, toGoalContext } from "@/lib/training/context";

/** Builds a complete training plan for a plan row in `generating` status. */
export async function generatePlanWorkflow(planId: string) {
  "use workflow";

  try {
    const { runner, goal } = await loadContext(planId);
    await setProgress(planId, 20);
    const generated = await createPlan(runner, goal);
    await savePlan(planId, runner.userId, generated);
    return { planId, workouts: generated.workouts.length };
  } catch (error) {
    await markFailed(planId, error instanceof Error ? error.message : String(error));
    throw error;
  }
}

async function loadContext(planId: string) {
  "use step";
  const row = await db.query.plan.findFirst({ where: eq(plan.id, planId) });
  if (!row) throw new FatalError(`Plan ${planId} not found`);
  if (row.status !== "generating") throw new FatalError(`Plan ${planId} is ${row.status}`);
  return { runner: await loadRunner(row.userId), goal: toGoalContext(row) };
}

async function createPlan(runner: RunnerContext, goal: GoalContext) {
  "use step";
  return generatePlan(runner, goal);
}

async function setProgress(planId: string, progress: number) {
  "use step";
  await db.update(plan).set({ progress }).where(eq(plan.id, planId));
}

async function savePlan(planId: string, userId: string, generated: GeneratedPlan) {
  "use step";
  // One atomic batch; safe to retry because existing workouts are replaced.
  await db.batch([
    db.delete(workout).where(eq(workout.planId, planId)),
    db.insert(workout).values(generated.workouts.map((w) => ({ ...w, planId, userId }))),
    db
      .update(plan)
      .set({ status: "archived" })
      .where(and(eq(plan.userId, userId), eq(plan.status, "ready"), ne(plan.id, planId))),
    db
      .update(plan)
      .set({
        status: "ready",
        progress: 100,
        title: generated.title,
        summary: generated.summary,
        predictedTimeS: generated.predictedTimeS,
        paces: generated.paces,
        phases: null,
        error: null,
      })
      .where(eq(plan.id, planId)),
  ]);
}

async function markFailed(planId: string, message: string) {
  "use step";
  await db
    .update(plan)
    .set({ status: "failed", error: message.slice(0, 500) })
    .where(and(eq(plan.id, planId), eq(plan.status, "generating")));
}
