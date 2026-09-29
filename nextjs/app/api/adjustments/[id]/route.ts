import { and, eq } from "drizzle-orm";
import { db } from "@/db";
import { planAdjustment } from "@/db/schema";
import { notFound, uuidParam, withUser } from "@/lib/api";

/** Poll until `status` is `applied` or `failed`. */
export const GET = withUser(async (_req, me, { params }: RouteContext<"/api/adjustments/[id]">) => {
  const id = uuidParam((await params).id);
  const row = await db.query.planAdjustment.findFirst({
    where: and(eq(planAdjustment.id, id), eq(planAdjustment.userId, me.id)),
  });
  if (!row) throw notFound();
  return Response.json({ adjustment: row });
});
