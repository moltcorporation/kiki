import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db";
import { plan, profile } from "@/db/schema";
import { parseBody, withUser } from "@/lib/api";
import { emailTeam } from "@/lib/email";

const bodySchema = z.object({
  message: z.string().trim().min(1).max(4000),
  appVersion: z.string().max(32).optional(),
});

/** A feature request from the app, emailed to the team (reply goes to the runner). */
export const POST = withUser(async (req, me) => {
  const { message, appVersion } = await parseBody(req, bodySchema);
  const [runner, current] = await Promise.all([
    db.query.profile.findFirst({ where: eq(profile.userId, me.id) }),
    db.query.plan.findFirst({ where: and(eq(plan.userId, me.id), eq(plan.status, "ready")) }),
  ]);
  const name = runner?.firstName || "A runner";
  const goal = current ? (current.raceName ?? current.title ?? current.goalKind) : "no plan yet";
  await emailTeam({
    subject: `Feature request from ${name}`,
    replyTo: me.email,
    text: [
      message,
      "",
      "—",
      `From: ${name}${me.email ? ` <${me.email}>` : ""}`,
      `Plan: ${goal}`,
      `User: ${me.id}`,
      appVersion ? `App: ${appVersion}` : null,
    ]
      .filter((line) => line !== null)
      .join("\n"),
  });
  return new Response(null, { status: 204 });
});
