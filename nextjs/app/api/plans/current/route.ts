import { withUser } from "@/lib/api";
import { currentPlan } from "@/lib/plans";

export const GET = withUser(async (_req, me) => Response.json(await currentPlan(me.id)));
