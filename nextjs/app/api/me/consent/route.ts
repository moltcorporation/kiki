import { z } from "zod";
import { db } from "@/db";
import { consent } from "@/db/schema";
import { parseBody, withUser } from "@/lib/api";

const bodySchema = z.object({
  /** The Terms/Privacy "last updated" date the user agreed to. */
  version: z.string().min(1).max(32),
  acceptedAt: z.iso.datetime({ offset: true }).optional(),
  appVersion: z.string().max(32).optional(),
});

/** Records that the user agreed to the Terms and Privacy Policy (append-only). */
export const POST = withUser(async (req, me) => {
  const body = await parseBody(req, bodySchema);
  await db.insert(consent).values({
    userId: me.id,
    version: body.version,
    clientAcceptedAt: body.acceptedAt ? new Date(body.acceptedAt) : null,
    appVersion: body.appVersion ?? null,
  });
  return new Response(null, { status: 204 });
});
