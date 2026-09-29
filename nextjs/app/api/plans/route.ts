import { and, count, desc, eq, gt } from "drizzle-orm";
import { start } from "workflow/api";
import { db } from "@/db";
import { plan, profile } from "@/db/schema";
import { ApiError, parseBody, withUser } from "@/lib/api";
import { isSubscribed } from "@/lib/subscription";
import { addDays, todayIn, weekCount } from "@/lib/training/dates";
import { planInputSchema, RACE_DISTANCE_M } from "@/lib/training/types";
import { generatePlanWorkflow } from "@/workflows/generate-plan";

const MAX_WEEKS = 40;
const FREE_PLAN_LIMIT = 3;
const DAILY_PLAN_LIMIT = 10;

/** Starts generating a new plan. The current plan is archived once it's ready. */
export const POST = withUser(async (req, me) => {
  const input = await parseBody(req, planInputSchema);

  const runner = await db.query.profile.findFirst({ where: eq(profile.userId, me.id) });
  if (!runner) throw new ApiError(409, "profile_required", "Complete your profile first");

  const today = todayIn(runner.timezone);
  if (input.raceDate < addDays(today, 7)) {
    throw new ApiError(400, "race_too_soon", "Pick a race at least a week away");
  }
  if (weekCount(today, input.raceDate) > MAX_WEEKS) {
    throw new ApiError(400, "race_too_far", `Pick a race within ${MAX_WEEKS} weeks`);
  }

  const raceDistanceM =
    input.raceDistance === "other" ? input.raceDistanceM : RACE_DISTANCE_M[input.raceDistance];
  if (!raceDistanceM) throw new ApiError(400, "invalid_request", "Race distance is required");

  // A double-tap or retry while a plan is generating returns that plan.
  const inFlight = await db.query.plan.findFirst({
    where: and(
      eq(plan.userId, me.id),
      eq(plan.status, "generating"),
      gt(plan.createdAt, new Date(Date.now() - 10 * 60_000)),
    ),
  });
  if (inFlight) return Response.json({ plan: inFlight }, { status: 202 });

  const [{ total }] = await db.select({ total: count() }).from(plan).where(eq(plan.userId, me.id));
  const [{ recent }] = await db
    .select({ recent: count() })
    .from(plan)
    .where(and(eq(plan.userId, me.id), gt(plan.createdAt, new Date(Date.now() - 86_400_000))));
  if (recent >= DAILY_PLAN_LIMIT) {
    throw new ApiError(429, "rate_limited", "You've created a lot of plans today. Try again tomorrow.");
  }
  if (total >= FREE_PLAN_LIMIT && !(await isSubscribed(me.id))) {
    throw new ApiError(402, "subscription_required", "Subscribe to create more plans");
  }

  const [row] = await db
    .insert(plan)
    .values({
      userId: me.id,
      status: "generating",
      raceDistance: input.raceDistance,
      raceDistanceM,
      raceName: input.raceName || null,
      raceDate: input.raceDate,
      startDate: today,
      goalType: input.goalType,
      goalTimeS: input.goalType === "time" ? (input.goalTimeS ?? null) : null,
      recentRaceDistanceM: input.recentRaceDistanceM ?? null,
      recentRaceTimeS: input.recentRaceTimeS ?? null,
      progress: 5,
    })
    .returning();

  const run = await start(generatePlanWorkflow, [row.id]);
  await db.update(plan).set({ workflowRunId: run.runId }).where(eq(plan.id, row.id));

  return Response.json({ plan: { ...row, workflowRunId: run.runId } }, { status: 202 });
});

/** Recent plans (newest first), without workouts. */
export const GET = withUser(async (_req, me) => {
  const plans = await db
    .select()
    .from(plan)
    .where(eq(plan.userId, me.id))
    .orderBy(desc(plan.createdAt))
    .limit(20);
  return Response.json({ plans });
});
