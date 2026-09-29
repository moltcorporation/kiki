import "server-only";
import { and, asc, desc, eq, inArray } from "drizzle-orm";
import { db } from "@/db";
import { plan, workout } from "@/db/schema";

export async function workoutsFor(planId: string) {
  return db.select().from(workout).where(eq(workout.planId, planId)).orderBy(asc(workout.date));
}

/**
 * What the app shows: the active (ready) plan with its workouts, plus a newer
 * plan that is still generating or has failed, if any.
 */
export async function currentPlan(userId: string) {
  const [latest] = await db
    .select()
    .from(plan)
    .where(and(eq(plan.userId, userId), inArray(plan.status, ["generating", "ready", "failed"])))
    .orderBy(desc(plan.createdAt))
    .limit(1);

  const ready =
    latest?.status === "ready"
      ? latest
      : (
          await db
            .select()
            .from(plan)
            .where(and(eq(plan.userId, userId), eq(plan.status, "ready")))
            .orderBy(desc(plan.createdAt))
            .limit(1)
        )[0];

  return {
    plan: ready ?? null,
    workouts: ready ? await workoutsFor(ready.id) : [],
    pending: latest && latest.status !== "ready" ? latest : null,
  };
}
