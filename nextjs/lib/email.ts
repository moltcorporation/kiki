import "server-only";

const FROM = "Kiki <hello@moltcorporation.com>";
const TEAM = "stuart@moltcorporation.com";

/** Sends a plain-text email to the team through Resend. */
export async function emailTeam({ subject, text, replyTo }: { subject: string; text: string; replyTo?: string | null }) {
  const key = process.env.RESEND_API_KEY;
  if (!key) throw new Error("RESEND_API_KEY is not set");
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: FROM, to: [TEAM], subject, text, ...(replyTo ? { reply_to: replyTo } : {}) }),
  });
  if (!res.ok) throw new Error(`Resend ${res.status}: ${(await res.text()).slice(0, 300)}`);
}
