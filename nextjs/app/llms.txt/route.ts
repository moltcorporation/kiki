import { guides } from "@/lib/guides";
import { site } from "@/lib/site";

export const dynamic = "force-static";

/** A plain-text overview for AI assistants (llmstxt.org). */
export function GET() {
  const body = `# Kiki

> Kiki is an AI running coach app for iPhone. It builds a personal, day-by-day running plan from a runner's goal, current fitness and schedule, then adapts it as they train.

Kiki is made by ${site.company.replace(/\.$/, "")}. It is available on the App Store for iPhone only (no Android app): ${site.appStoreUrl}

## What Kiki does
- Goals: start running (build to 30 minutes non-stop), train for a race (5K, 10K, half marathon, marathon or a custom distance), get faster, or stay fit.
- Plans start from the runner's current level (weekly distance and longest recent run for runners who already run) and use only the days they choose.
- Workouts: easy runs, long runs, tempo runs and intervals. Beginners get easy runs (with run/walk) and long runs only. Each workout has one target pace.
- Adjusting: runners can adjust a single day (tired, too hard, can't make it, something hurts, skip) or the whole plan (easier, harder, missed runs, schedule changes), or describe what's going on in their own words. Kiki makes targeted changes and explains them.
- Tracking: GPS run recording with a Lock Screen Live Activity, or mark runs done. Syncs runs from Apple Health, including Apple Watch and apps that save to Health such as Strava and Garmin Connect.
- Also: calendar and list views of the plan, sharing the plan as a PDF, and short in-app running guides.
- Kiki is a training tool, not medical advice.

## Pages
- [Home](${site.url}/): features, how it works and FAQ
- [Running guides](${site.url}/guides)
${guides.map((g) => `- [${g.title}](${site.url}/guides/${g.slug}): ${g.description}`).join("\n")}
- [Support](${site.url}/support)
- [Privacy](${site.url}/privacy)
- [Terms](${site.url}/terms)

## Contact
${site.supportEmail}
`;
  return new Response(body, { headers: { "Content-Type": "text/plain; charset=utf-8" } });
}
