import type { GatewayProviderOptions } from "@ai-sdk/gateway";
import { generateText, Output } from "ai";
import { z } from "zod";
import { dateFor, isoWeekday } from "./dates";
import {
  paceZonesSchema,
  planPhaseSchema,
  workoutStepSchema,
  type Experience,
  type Feeling,
  type GoalType,
  type PaceZones,
  type PlanPhase,
  type RaceDistance,
  type Units,
  type WorkoutStep,
  type WorkoutType,
} from "./types";

const MODEL = "anthropic/claude-sonnet-5.5";
const FALLBACK_MODELS = ["openai/gpt-5.5"];

function gateway(userId: string, feature: string) {
  return {
    gateway: {
      models: FALLBACK_MODELS,
      user: userId,
      tags: [feature],
    } satisfies GatewayProviderOptions,
  };
}

// ---------------------------------------------------------------------------
// Context passed between workflow steps (must stay plain, serializable data)
// ---------------------------------------------------------------------------

export type RunnerContext = {
  userId: string;
  firstName: string | null;
  units: Units;
  age: number | null;
  heightCm: number | null;
  weightKg: number | null;
  experience: Experience;
  weeklyDistanceM: number;
  longestRunM: number;
  runDays: number[];
  longRunDay: number;
  injury: string | null;
};

export type RaceContext = {
  raceDistance: RaceDistance;
  raceDistanceM: number;
  raceName: string | null;
  raceDate: string;
  startDate: string;
  weeks: number;
  goalType: GoalType;
  goalTimeS: number | null;
  recentRaceDistanceM: number | null;
  recentRaceTimeS: number | null;
};

export type PlannedWorkout = {
  date: string;
  week: number;
  type: WorkoutType;
  title: string;
  description: string;
  distanceM: number | null;
  durationS: number | null;
  steps: WorkoutStep[];
};

// ---------------------------------------------------------------------------
// Prompt building
// ---------------------------------------------------------------------------

const WEEKDAYS = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

export function km(m: number | null | undefined) {
  return m == null ? "-" : `${(m / 1000).toFixed(1)} km`;
}

export function duration(s: number | null | undefined) {
  if (s == null) return "-";
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  return h > 0
    ? `${h}:${String(m).padStart(2, "0")}:${String(sec).padStart(2, "0")}`
    : `${m}:${String(sec).padStart(2, "0")}`;
}

function pace(sPerKm: number) {
  return `${duration(Math.round(sPerKm))}/km`;
}

const RACE_LABEL: Record<RaceDistance, string> = {
  "5k": "5K",
  "10k": "10K",
  half: "half marathon",
  marathon: "marathon",
  other: "race",
};

export const COACH_SYSTEM = `You are Kiki, an elite running coach who builds individualized, evidence-based training plans for runners of every level, from first-time 5K runners to experienced marathoners.

Coaching principles you always follow:
- Most running (about 80%) is easy, conversational effort. Quality sessions are the exception, not the rule.
- New and beginner runners get at most one quality session per week (strides, gentle fartlek or short tempo). Intermediate runners get 1–2. Advanced runners get 2, rarely 3. Never schedule hard days back to back, and the day after the long run is easy or rest.
- Build weekly volume gradually (roughly 10% or less per week), starting from the runner's current volume, not an idealized one. Insert a cutback week (about 20–30% lower) every 3–4 weeks.
- The long run grows steadily and should rarely exceed ~30–35% of weekly volume for experienced runners; low-volume runners may go higher out of necessity. Cap marathon long runs around 32–35 km (about 3 hours for slower runners); half marathon long runs around 16–22 km.
- Taper before race day: about 2–3 weeks for a marathon, 1–2 weeks for a half, about a week for 5K/10K, reducing volume while keeping some intensity.
- New runners use run/walk intervals where appropriate and build time on feet before speed.
- If the runner reports an injury or pain, be conservative: lower volume, fewer and gentler quality sessions, and cross-training where useful.
- Workouts must match the runner's paces. Derive pace zones from a recent race result when available (VDOT-style equivalence), otherwise from experience, current volume and goal. Keep goals realistic and say so kindly if a goal is very ambitious.
- Only schedule runs on the runner's available days, and put the long run on their chosen long-run day.

Writing style for workouts:
- Titles are short and clear (e.g. "Easy Run", "Long Run", "Tempo Run", "Track Intervals", "Hill Repeats", "Shakeout").
- Descriptions are 1–3 short sentences of coaching: the purpose and how it should feel. Do not write distances, times or paces in titles or descriptions; the app shows those from the structured fields and steps, in the runner's units.
- Use steps for structured sessions (warmup, repeated work/recovery, cooldown). Easy and long runs can have an empty steps list.
- All distances are in meters and durations in seconds. Paces are seconds per kilometer.`;

export function describeRunner(runner: RunnerContext, race: RaceContext) {
  const lines = [
    `Runner${runner.firstName ? `: ${runner.firstName}` : ""}`,
    `- Experience: ${runner.experience}`,
    `- Current weekly volume: ${km(runner.weeklyDistanceM)}`,
    `- Longest recent run: ${km(runner.longestRunM)}`,
    `- Available days: ${runner.runDays.map((d) => WEEKDAYS[d]).join(", ")} (${runner.runDays.length} days/week)`,
    `- Long run day: ${WEEKDAYS[runner.longRunDay]}`,
    `- Prefers ${runner.units === "mi" ? "miles" : "kilometers"} (round distances to sensible values in that unit)`,
  ];
  if (runner.age) lines.push(`- Age: ${runner.age}`);
  if (runner.heightCm) lines.push(`- Height: ${Math.round(runner.heightCm)} cm`);
  if (runner.weightKg) lines.push(`- Weight: ${Math.round(runner.weightKg)} kg`);
  lines.push(`- Injuries or pain: ${runner.injury?.trim() || "none reported"}`);

  lines.push(
    "",
    "Race",
    `- ${race.raceName ? `${race.raceName} (${RACE_LABEL[race.raceDistance]})` : RACE_LABEL[race.raceDistance]}: ${km(race.raceDistanceM)} on ${race.raceDate} (${WEEKDAYS[isoWeekday(race.raceDate)]})`,
    race.goalType === "time" && race.goalTimeS
      ? `- Goal: finish in ${duration(race.goalTimeS)}`
      : "- Goal: finish strong and healthy",
  );
  if (race.recentRaceDistanceM && race.recentRaceTimeS) {
    lines.push(`- Recent race: ${km(race.recentRaceDistanceM)} in ${duration(race.recentRaceTimeS)}`);
  }
  lines.push(
    "",
    "Plan window",
    `- Starts ${race.startDate} (${WEEKDAYS[isoWeekday(race.startDate)]}), ${race.weeks} Monday-based weeks. Week 1 only includes days from the start date onward; the final week ends on race day.`,
  );
  return lines.join("\n");
}

function describePaces(p: PaceZones) {
  return (Object.keys(p) as (keyof PaceZones)[])
    .map((k) => `${k}: ${pace(p[k].min)}–${pace(p[k].max)}`)
    .join(", ");
}

// ---------------------------------------------------------------------------
// Stage 1: blueprint (phases, paces, weekly targets)
// ---------------------------------------------------------------------------

const blueprintSchema = z.object({
  title: z.string().describe("Short plan title, max ~40 characters"),
  summary: z
    .string()
    .describe("2–3 warm sentences to the runner explaining the approach of this plan"),
  predictedTimeS: z
    .number()
    .int()
    .nullable()
    .describe("Realistic predicted race finish time in seconds after this plan"),
  paces: paceZonesSchema,
  phases: z.array(planPhaseSchema),
  weeks: z.array(
    z.object({
      week: z.number().int(),
      distanceM: z.number().int().describe("Total planned running distance for the week"),
      longRunM: z.number().int(),
      cutback: z.boolean(),
      focus: z.string().describe("Focus of the week, max ~8 words"),
    }),
  ),
});
export type Blueprint = z.infer<typeof blueprintSchema>;

export async function generateBlueprint(runner: RunnerContext, race: RaceContext) {
  const { output } = await generateText({
    model: MODEL,
    providerOptions: gateway(runner.userId, "plan-blueprint"),
    system: COACH_SYSTEM,
    output: Output.object({ schema: blueprintSchema }),
    prompt: `${describeRunner(runner, race)}

Design the blueprint for this plan: realistic pace zones, training phases, and targets for each of the ${race.weeks} weeks (numbered 1 to ${race.weeks}). Week 1's target should be close to the runner's current volume, scaled down if week 1 is partial. The final week includes the race itself.`,
  });
  return normalizeBlueprint(output, race);
}

function normalizeBlueprint(bp: Blueprint, race: RaceContext): Blueprint {
  const byWeek = new Map(bp.weeks.map((w) => [w.week, w]));
  if (byWeek.size < race.weeks) {
    throw new Error(`Blueprint covers ${byWeek.size} of ${race.weeks} weeks`);
  }

  // Guard against unsafe jumps in weekly volume.
  const weeks: Blueprint["weeks"] = [];
  let lastBuild = 0;
  for (let i = 1; i <= race.weeks; i++) {
    const w = { ...byWeek.get(i)! };
    if (lastBuild > 0 && !w.cutback) {
      const cap = Math.round(lastBuild * 1.12 + 1600);
      if (w.distanceM > cap) {
        w.longRunM = Math.round(w.longRunM * (cap / w.distanceM));
        w.distanceM = cap;
      }
    }
    if (!w.cutback) lastBuild = Math.max(lastBuild, w.distanceM);
    weeks.push(w);
  }

  const paces = { ...bp.paces };
  for (const key of Object.keys(paces) as (keyof PaceZones)[]) {
    const { min, max } = paces[key];
    paces[key] = { min: Math.min(min, max), max: Math.max(min, max) };
  }

  return { ...bp, paces, weeks };
}

// ---------------------------------------------------------------------------
// Stage 2: daily workouts for a range of weeks
// ---------------------------------------------------------------------------

const RUN_TYPES = [
  "easy",
  "recovery",
  "long",
  "tempo",
  "intervals",
  "hills",
  "fartlek",
  "progression",
  "race_pace",
  "cross_training",
  "race",
] as const;

const aiWorkoutSchema = z.object({
  type: z.enum(RUN_TYPES),
  title: z.string(),
  description: z.string(),
  distanceM: z.number().int().nullable(),
  durationS: z.number().int().nullable(),
  steps: z.array(workoutStepSchema),
});

const weekDetailSchema = z.object({
  weeks: z.array(
    z.object({
      week: z.number().int(),
      workouts: z.array(
        aiWorkoutSchema.extend({
          day: z.number().int().describe("ISO weekday, 1 = Monday … 7 = Sunday"),
        }),
      ),
    }),
  ),
});

export async function generateWeeks(
  runner: RunnerContext,
  race: RaceContext,
  blueprint: Blueprint,
  fromWeek: number,
  toWeek: number,
): Promise<PlannedWorkout[]> {
  const targets = blueprint.weeks
    .map(
      (w) =>
        `Week ${w.week}${w.week >= fromWeek && w.week <= toWeek ? " (detail this week)" : ""}: ${km(w.distanceM)}, long run ${km(w.longRunM)}${w.cutback ? ", cutback" : ""} · ${w.focus}`,
    )
    .join("\n");

  const { output } = await generateText({
    model: MODEL,
    providerOptions: gateway(runner.userId, "plan-weeks"),
    system: COACH_SYSTEM,
    output: Output.object({ schema: weekDetailSchema }),
    prompt: `${describeRunner(runner, race)}

Plan: ${blueprint.title}
Paces (per km): ${describePaces(blueprint.paces)}
Phases: ${blueprint.phases.map((p) => `${p.name} (weeks ${p.startWeek}–${p.endWeek}): ${p.focus}`).join("; ")}

Weekly targets:
${targets}

Write the daily running workouts for weeks ${fromWeek} to ${toWeek}. Only include running days (rest days are added automatically). Use only the runner's available days, put the long run on the long-run day, and hit each week's targets closely. Skip days before the start date.${toWeek === race.weeks ? " The race is on race day in the final week; include it as a workout of type \"race\" and keep the days before it light." : ""}`,
  });

  return normalizeWeeks(output, runner, race, fromWeek, toWeek);
}

function normalizeWeeks(
  detail: z.infer<typeof weekDetailSchema>,
  runner: RunnerContext,
  race: RaceContext,
  fromWeek: number,
  toWeek: number,
): PlannedWorkout[] {
  const runDays = new Set(runner.runDays);
  const byDate = new Map<string, PlannedWorkout>();

  for (const week of detail.weeks) {
    if (week.week < fromWeek || week.week > toWeek) continue;
    for (const w of week.workouts) {
      if (w.day < 1 || w.day > 7) continue;
      const date = dateFor(race.startDate, week.week, w.day);
      if (date < race.startDate || date > race.raceDate) continue;
      if (date !== race.raceDate && (!runDays.has(w.day) || w.type === "race")) continue;
      if (byDate.has(date)) continue;
      byDate.set(date, toPlanned(w, date, week.week));
    }
  }

  const result: PlannedWorkout[] = [];
  for (let week = fromWeek; week <= toWeek; week++) {
    for (let day = 1; day <= 7; day++) {
      const date = dateFor(race.startDate, week, day);
      if (date < race.startDate || date > race.raceDate) continue;
      if (date === race.raceDate) {
        result.push(raceDay(race, week, byDate.get(date)));
      } else {
        result.push(byDate.get(date) ?? restDay(date, week));
      }
    }
  }
  return result;
}

function toPlanned(
  w: Omit<z.infer<typeof aiWorkoutSchema>, "type"> & { type: WorkoutType },
  date: string,
  week: number,
): PlannedWorkout {
  const distanceM = w.distanceM && w.distanceM > 0 ? Math.min(w.distanceM, 60_000) : null;
  const durationS = w.durationS && w.durationS > 0 ? Math.min(w.durationS, 6 * 3600) : null;
  return {
    date,
    week,
    type: w.type,
    title: w.title.trim().slice(0, 60),
    description: w.description.trim().slice(0, 600),
    distanceM,
    durationS: distanceM == null && durationS == null ? 1800 : durationS,
    steps: w.steps.slice(0, 12),
  };
}

export function restDay(date: string, week: number): PlannedWorkout {
  return {
    date,
    week,
    type: "rest",
    title: "Rest",
    description: "Recovery is where fitness is built. Keep it easy: a walk, some mobility, or nothing at all.",
    distanceM: null,
    durationS: null,
    steps: [],
  };
}

function raceDay(race: RaceContext, week: number, ai?: PlannedWorkout): PlannedWorkout {
  return {
    date: race.raceDate,
    week,
    type: "race",
    title: race.raceName ?? "Race Day",
    description:
      ai?.type === "race" && ai.description
        ? ai.description
        : "This is what you trained for. Start controlled, settle into your rhythm, and finish strong.",
    distanceM: race.raceDistanceM,
    durationS: race.goalType === "time" ? race.goalTimeS : null,
    steps: [],
  };
}

// ---------------------------------------------------------------------------
// Adjustments: the runner asks the coach to change upcoming workouts
// ---------------------------------------------------------------------------

const adjustmentSchema = z.object({
  reply: z
    .string()
    .describe("2–4 warm, direct sentences to the runner explaining what you changed and why"),
  changes: z.array(
    z.object({
      date: z.string().describe("YYYY-MM-DD of the workout to replace"),
      workout: aiWorkoutSchema.extend({ type: z.enum([...RUN_TYPES, "rest"]) }),
    }),
  ),
});

export type AdjustmentContext = {
  runner: RunnerContext;
  race: RaceContext;
  today: string;
  planSummary: string | null;
  paces: PaceZones | null;
  phases: PlanPhase[] | null;
  workouts: (PlannedWorkout & { status: string })[];
  recentRuns: {
    date: string;
    distanceM: number;
    durationS: number;
    effort: number | null;
    feeling: Feeling | null;
    notes: string | null;
  }[];
  reason: string;
  message: string | null;
};

const REASON_TEXT: Record<string, string> = {
  missed: "I missed a workout (or will miss one).",
  tired: "I'm feeling tired / fatigued.",
  injured: "I have pain or an injury.",
  too_easy: "The plan feels too easy.",
  too_hard: "The plan feels too hard.",
  schedule: "My schedule changed.",
  race_changed: "My race details changed.",
  other: "I'd like to change something.",
};

export async function generateAdjustment(ctx: AdjustmentContext) {
  const upcoming = ctx.workouts
    .map(
      (w) =>
        `${w.date} ${WEEKDAYS[isoWeekday(w.date)].slice(0, 3)} | ${w.type} | ${w.title} | ${km(w.distanceM)} | ${w.status}`,
    )
    .join("\n");
  const runs =
    ctx.recentRuns
      .map(
        (r) =>
          `${r.date}: ${km(r.distanceM)} in ${duration(r.durationS)}${r.effort ? `, effort ${r.effort}/10` : ""}${r.feeling ? `, felt ${r.feeling}` : ""}${r.notes ? ` ("${r.notes}")` : ""}`,
      )
      .join("\n") || "none logged";

  const { output } = await generateText({
    model: MODEL,
    providerOptions: gateway(ctx.runner.userId, "plan-adjust"),
    system: COACH_SYSTEM,
    output: Output.object({ schema: adjustmentSchema }),
    prompt: `${describeRunner(ctx.runner, ctx.race)}

Today is ${ctx.today} (${WEEKDAYS[isoWeekday(ctx.today)]}).
${ctx.planSummary ? `Plan approach: ${ctx.planSummary}\n` : ""}${ctx.paces ? `Paces (per km): ${describePaces(ctx.paces)}\n` : ""}${ctx.phases ? `Phases: ${ctx.phases.map((p) => `${p.name} weeks ${p.startWeek}–${p.endWeek}`).join("; ")}\n` : ""}
Schedule (date | type | title | distance | status):
${upcoming}

Recent runs:
${runs}

The runner says: ${REASON_TEXT[ctx.reason] ?? REASON_TEXT.other}${ctx.message ? `\n"${ctx.message}"` : ""}

Adjust the plan like a thoughtful coach would. Only change workouts dated today or later, never completed workouts, and never race day. Make the smallest set of changes that genuinely helps (often just the next several days to two weeks); the rest of the plan should stay intact. Runs may go on any day if the runner's message asks for it. If there's pain, favor rest and easy running and suggest seeing a professional if it persists. Return an empty changes list if no change is warranted, and explain why in the reply.`,
  });

  const known = new Map(ctx.workouts.map((w) => [w.date, w]));
  const changes: PlannedWorkout[] = [];
  const seen = new Set<string>();
  for (const change of output.changes) {
    const existing = known.get(change.date);
    if (!existing || seen.has(change.date)) continue;
    if (change.date < ctx.today || change.date >= ctx.race.raceDate) continue;
    if (existing.status === "completed") continue;
    seen.add(change.date);
    changes.push(
      change.workout.type === "rest"
        ? restDay(change.date, existing.week)
        : toPlanned(change.workout, change.date, existing.week),
    );
  }

  return { reply: output.reply.trim(), changes };
}
