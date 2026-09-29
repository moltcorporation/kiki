import { z } from "zod";
import { parseBody, withUser } from "@/lib/api";
import { storeAppleRefreshToken } from "@/lib/apple";

const bodySchema = z.object({ authorizationCode: z.string().min(1).max(2000) });

/** Called by the app right after Sign in with Apple (the code expires in minutes). */
export const POST = withUser(async (req, me) => {
  const { authorizationCode } = await parseBody(req, bodySchema);
  await storeAppleRefreshToken(me.id, authorizationCode);
  return new Response(null, { status: 204 });
});
