import { and, eq } from "drizzle-orm";
import { start } from "workflow/api";
import { db } from "@/db";
import { planAdjustment } from "@/db/schema";
import { ApiError, parseBody, withUser } from "@/lib/api";
import { currentPlan } from "@/lib/plans";
import { isSubscribed } from "@/lib/subscription";
import { adjustmentInputSchema } from "@/lib/training/types";
import { adjustPlanWorkflow } from "@/workflows/adjust-plan";

/** Asks the AI coach to adjust the active plan. Idempotent by client ID. */
export const POST = withUser(async (req, me) => {
  const input = await parseBody(req, adjustmentInputSchema);

  const existing = await db.query.planAdjustment.findFirst({
    where: and(eq(planAdjustment.id, input.id), eq(planAdjustment.userId, me.id)),
  });
  if (existing) return Response.json({ adjustment: existing }, { status: 202 });

  if (!(await isSubscribed(me.id))) {
    throw new ApiError(402, "subscription_required", "Subscribe to adjust your plan");
  }
  const { plan } = await currentPlan(me.id);
  if (!plan) throw new ApiError(409, "no_plan", "You don't have an active plan");

  const [row] = await db
    .insert(planAdjustment)
    .values({
      id: input.id,
      planId: plan.id,
      userId: me.id,
      reason: input.reason,
      message: input.message || null,
      targetDate: input.targetDate ?? null,
      status: "pending",
    })
    .returning();

  const run = await start(adjustPlanWorkflow, [row.id, input.today]);
  await db
    .update(planAdjustment)
    .set({ workflowRunId: run.runId })
    .where(eq(planAdjustment.id, row.id));

  return Response.json({ adjustment: { ...row, workflowRunId: run.runId } }, { status: 202 });
});
