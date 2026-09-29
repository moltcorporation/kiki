import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db";
import { plan, workout } from "@/db/schema";
import { ApiError, notFound, parseBody, uuidParam, withUser } from "@/lib/api";

const patchSchema = z.object({
  status: z.enum(["planned", "completed", "skipped"]).optional(),
  /** Move this workout to another day of the plan, swapping with that day. */
  moveTo: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

export const PATCH = withUser(async (req, me, { params }: RouteContext<"/api/workouts/[id]">) => {
  const id = uuidParam((await params).id);
  const input = await parseBody(req, patchSchema);

  const current = await db.query.workout.findFirst({
    where: and(eq(workout.id, id), eq(workout.userId, me.id)),
  });
  if (!current) throw notFound();

  if (input.moveTo && input.moveTo !== current.date) {
    const [target, planRow] = await Promise.all([
      db.query.workout.findFirst({
        where: and(eq(workout.planId, current.planId), eq(workout.date, input.moveTo)),
      }),
      db.query.plan.findFirst({ where: eq(plan.id, current.planId) }),
    ]);
    if (!target) throw new ApiError(400, "invalid_date", "That day isn't part of your plan");
    if ([current, target].some((w) => w.status === "completed" || w.type === "race")) {
      throw new ApiError(400, "not_movable", "Completed workouts and race day can't be moved");
    }
    if (planRow?.raceDate === input.moveTo) {
      throw new ApiError(400, "not_movable", "Race day can't be changed");
    }

    // Swap contents so each date keeps exactly one workout.
    const content = (w: typeof current) => ({
      type: w.type,
      title: w.title,
      description: w.description,
      distanceM: w.distanceM,
      durationS: w.durationS,
      steps: w.steps,
      status: w.status,
    });
    const [[a], [b]] = await db.batch([
      db.update(workout).set(content(target)).where(eq(workout.id, current.id)).returning(),
      db.update(workout).set(content(current)).where(eq(workout.id, target.id)).returning(),
    ]);
    return Response.json({ workouts: [a, b] });
  }

  if (input.status) {
    const [updated] = await db
      .update(workout)
      .set({ status: input.status })
      .where(eq(workout.id, current.id))
      .returning();
    return Response.json({ workouts: [updated] });
  }

  return Response.json({ workouts: [current] });
});
