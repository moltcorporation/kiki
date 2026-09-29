import { and, eq, ne } from "drizzle-orm";
import { FatalError } from "workflow";
import { db } from "@/db";
import { plan, workout } from "@/db/schema";
import {
  generateBlueprint,
  generateWeeks,
  type Blueprint,
  type PlannedWorkout,
  type RaceContext,
  type RunnerContext,
} from "@/lib/training/coach";
import { loadRunner, toRaceContext } from "@/lib/training/context";

const WEEKS_PER_CHUNK = 4;

/** Builds a complete training plan for a plan row in `generating` status. */
export async function generatePlanWorkflow(planId: string) {
  "use workflow";

  try {
    const { runner, race } = await loadContext(planId);
    const blueprint = await createBlueprint(runner, race);
    await setProgress(planId, 30);

    const chunks: [number, number][] = [];
    for (let from = 1; from <= race.weeks; from += WEEKS_PER_CHUNK) {
      chunks.push([from, Math.min(from + WEEKS_PER_CHUNK - 1, race.weeks)]);
    }
    const weeks = await Promise.all(
      chunks.map(([from, to]) => createWeeks(runner, race, blueprint, from, to)),
    );
    await setProgress(planId, 90);

    await savePlan(planId, runner.userId, blueprint, weeks.flat());
    return { planId, workouts: weeks.flat().length };
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
  return { runner: await loadRunner(row.userId), race: toRaceContext(row) };
}

async function createBlueprint(runner: RunnerContext, race: RaceContext) {
  "use step";
  return generateBlueprint(runner, race);
}

async function createWeeks(
  runner: RunnerContext,
  race: RaceContext,
  blueprint: Blueprint,
  from: number,
  to: number,
) {
  "use step";
  return generateWeeks(runner, race, blueprint, from, to);
}

async function setProgress(planId: string, progress: number) {
  "use step";
  await db.update(plan).set({ progress }).where(eq(plan.id, planId));
}

async function savePlan(
  planId: string,
  userId: string,
  blueprint: Blueprint,
  workouts: PlannedWorkout[],
) {
  "use step";
  // One atomic batch; safe to retry because existing workouts are replaced.
  await db.batch([
    db.delete(workout).where(eq(workout.planId, planId)),
    db.insert(workout).values(workouts.map((w) => ({ ...w, planId, userId }))),
    db
      .update(plan)
      .set({ status: "archived" })
      .where(and(eq(plan.userId, userId), eq(plan.status, "ready"), ne(plan.id, planId))),
    db
      .update(plan)
      .set({
        status: "ready",
        progress: 100,
        title: blueprint.title,
        summary: blueprint.summary,
        predictedTimeS: blueprint.predictedTimeS,
        paces: blueprint.paces,
        phases: blueprint.phases,
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
