import type { GatewayProviderOptions } from "@ai-sdk/gateway";
import { generateText, Output } from "ai";
import { z } from "zod";
import { dateFor, isoWeekday } from "./dates";
import {
  paceZonesSchema,
  workoutStepSchema,
  type CoachingStyle,
  type Experience,
  type Feeling,
  type GoalKind,
  type GoalType,
  type PaceZones,
  type RaceDistance,
  type Units,
  type WorkoutStep,
  type WorkoutType,
} from "./types";

/**
 * One call writes the whole plan, which is mostly output (every workout as
 * structured JSON), so a fast model keeps generation quick. Sonnet is the
 * fallback.
 */
const MODEL = "google/gemini-3.8-flash";
const FALLBACK_MODELS = ["anthropic/claude-sonnet-5.5"];

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
// Context passed between workflow steps (plain, serializable data)
// ---------------------------------------------------------------------------

export type RunnerContext = {
  userId: string;
  firstName: string | null;
  units: Units;
  age: number | null;
  heightCm: number | null;
  weightKg: number | null;
  experience: Experience;
  coachingStyle: CoachingStyle;
  weeklyDistanceM: number;
  runDays: number[];
  longRunDay: number;
};

export type GoalContext = {
  goalKind: GoalKind;
  raceDistance: RaceDistance | null;
  raceDistanceM: number | null;
  raceName: string | null;
  goalType: GoalType;
  goalTimeS: number | null;
  startDate: string;
  /** Last day of the plan (race day for race goals). */
  endDate: string;
  weeks: number;
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

const DISTANCE_LABEL: Record<RaceDistance, string> = {
  "5k": "5K",
  "10k": "10K",
  half: "half marathon",
  marathon: "marathon",
  other: "custom distance",
};

/** Matches the running-experience choices shown in onboarding. */
const EXPERIENCE_TEXT: Record<Experience, string> = {
  new: "Beginner: new to running, or can run less than 1 km without stopping",
  beginner: "Intermediate: can run 1.5–5 km continuously",
  intermediate: "Advanced: can comfortably run 5–10 km without stopping",
  advanced: "Elite: regularly runs 10+ km without stopping",
};

/** Matches the coaching-style choices shown in onboarding. */
const STYLE_TEXT: Record<CoachingStyle, string> = {
  gentle:
    "Gentle: progress slowly (about 5–7% more per week), extra rest, very encouraging and reassuring tone.",
  balanced: "Balanced: steady progress with a supportive, practical tone.",
  push:
    "Push me: progress as fast as is still safe (up to 10% per week), include challenging sessions their level allows, direct and motivating tone.",
};

export const COACH_SYSTEM = `You are Kiki, a hall-of-fame running coach who coaches runners of every level, from first-timers to elite. You write simple, encouraging, jargon-free plans that are easy to follow, and you match the training to the runner's level exactly.

How you coach:
- Start exactly where the runner is today and build gradually (never more than about 10% more per week). Every 4th week is an easier week.
- Match the training to their level:
  - Beginner: run/walk intervals, easy runs and a slightly longer weekend session. No hard sessions.
  - Intermediate: mostly easy running, plus one faster session a week (pickups, fartlek or a short tempo) and a weekly long run.
  - Advanced: mostly easy running, one or two quality sessions a week (tempo, intervals, hills) and a progressing long run.
  - Elite: a full training week with two quality sessions, a substantial long run, and easy volume on other days.
- Keep most running easy and conversational at every level. Never put hard days back to back; the day after a long run is easy or rest.
- Put the long run on the runner's long-run day.
- The final week before a race, time trial or goal run is lighter so they arrive fresh.
- Only schedule runs on the runner's available days. Beginners often do best with 3 runs a week even if more days are available.
- Follow the runner's coaching style for progression and tone, always within these safety rules.

How you build each workout:
- Pick each workout's type and its numbers; the app supplies titles and descriptions.
- Steps: only for run/walk and faster sessions (tempo, intervals, hills, fartlek, progression, race pace). Always this shape: a warmup (easy), one work step with a repeat count (or a single block for tempo and progression), its recovery step with the same repeat count when there are repeats, and a cooldown (easy). Easy, recovery and long runs have no steps.
- Use duration (seconds) for run/walk and beginner sessions; use distance (meters) for runners who can cover it.
- All distances in meters, durations in seconds, paces in seconds per km.`;

function describeGoal(goal: GoalContext) {
  const distance =
    goal.raceDistance === "other"
      ? km(goal.raceDistanceM)
      : goal.raceDistance
        ? `${DISTANCE_LABEL[goal.raceDistance]} (${km(goal.raceDistanceM)})`
        : null;
  const target = goal.goalType === "time" && goal.goalTimeS ? ` in ${duration(goal.goalTimeS)}` : "";
  switch (goal.goalKind) {
    case "start":
      return "Start running: build from where they are to running 30 minutes without stopping. The plan ends with a 30-minute Goal Run on the last day.";
    case "race":
      return `Train for a race: ${goal.raceName ? `${goal.raceName}, ` : ""}${distance} on ${goal.endDate}. Goal: ${goal.goalType === "time" ? `finish${target}` : "finish strong and healthy"}.`;
    case "faster":
      return `Get faster: run ${distance}${target}. The plan ends with a Time Trial of that distance on ${goal.endDate}.`;
    case "fit":
      return "Stay fit and consistent: steady, enjoyable running that builds a lasting habit. No race at the end.";
  }
}

export function describeRunner(runner: RunnerContext, goal: GoalContext) {
  const lines = [
    `Runner${runner.firstName ? `: ${runner.firstName}` : ""}`,
    `- Experience: ${EXPERIENCE_TEXT[runner.experience]}`,
    `- Coaching style: ${STYLE_TEXT[runner.coachingStyle]}`,
  ];
  if (runner.weeklyDistanceM > 0) lines.push(`- Currently runs about ${km(runner.weeklyDistanceM)} per week`);
  lines.push(
    `- Available days: ${runner.runDays.map((d) => WEEKDAYS[d]).join(", ")}`,
    `- Long-run day: ${WEEKDAYS[runner.longRunDay]}`,
    `- Prefers ${runner.units === "mi" ? "miles" : "kilometers"} (round distances to sensible values in that unit)`,
  );
  if (runner.age) lines.push(`- Age: ${runner.age}`);
  if (runner.heightCm) lines.push(`- Height: ${Math.round(runner.heightCm)} cm`);
  if (runner.weightKg) lines.push(`- Weight: ${Math.round(runner.weightKg)} kg`);
  lines.push(
    "",
    `Goal: ${describeGoal(goal)}`,
    `Plan window: starts ${goal.startDate} (${WEEKDAYS[isoWeekday(goal.startDate)]}), ends ${goal.endDate}; ${goal.weeks} Monday-based weeks. Week 1 only includes days from the start date onward.`,
  );
  return lines.join("\n");
}

function describePaces(p: PaceZones) {
  return (Object.keys(p) as (keyof PaceZones)[])
    .map((k) => `${k}: ${pace(p[k].min)}–${pace(p[k].max)}`)
    .join(", ");
}

// ---------------------------------------------------------------------------
// Plan generation (one AI call)
// ---------------------------------------------------------------------------

const RUN_TYPES = [
  "run_walk",
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

// The AI picks the type and the numbers only. Titles, descriptions and
// step notes come from the app's fixed copy (WORKOUT_COPY), so every
// workout of a type reads the same, day to day and plan to plan.
const aiWorkoutSchema = z.object({
  type: z.enum(RUN_TYPES),
  distanceM: z.number().int().nullable(),
  durationS: z.number().int().nullable(),
  steps: z.array(workoutStepSchema.omit({ note: true })),
});

/** The title and one-line "how it should feel" for each workout type. */
export const WORKOUT_COPY: Record<Exclude<WorkoutType, "rest" | "race">, { title: string; description: string }> = {
  run_walk: { title: "Run/Walk", description: "Alternate easy running and walking. Keep every run relaxed." },
  easy: { title: "Easy Run", description: "Relaxed the whole way. You should be able to talk in full sentences." },
  recovery: { title: "Recovery Run", description: "Very easy and short. Just loosen up your legs." },
  long: { title: "Long Run", description: "Slow and steady. Time on your feet builds your endurance." },
  tempo: {
    title: "Tempo Run",
    description: "Easy, then comfortably hard in the middle. You can say a few words, not sentences.",
  },
  intervals: {
    title: "Intervals",
    description: "Short, fast repeats with easy recovery between. Run each one at the same pace.",
  },
  hills: { title: "Hill Repeats", description: "Run strong up the hill, then recover easy on the way down." },
  fartlek: { title: "Fartlek", description: "An easy run with short, faster bursts mixed in by feel." },
  progression: { title: "Progression Run", description: "Start easy and finish at a strong, steady pace." },
  race_pace: { title: "Race Pace", description: "Practice your goal pace so it feels familiar on race day." },
  cross_training: { title: "Cross-Train", description: "Low-impact cardio, like cycling or swimming, at an easy effort." },
};

const planSchema = z.object({
  title: z.string().describe("Short plan title, max ~30 characters, e.g. 'First 30 Minutes' or 'Brooklyn Half'"),
  summary: z
    .string()
    .describe("One or two short, warm sentences to the runner by first name about how this plan gets them to their goal"),
  predictedTimeS: z
    .number()
    .int()
    .nullable()
    .describe("Realistic finish time in seconds for time goals only, else null"),
  paces: paceZonesSchema
    .nullable()
    .describe("Pace zones only for time goals or runners past beginner level, else null"),
  weeks: z.array(
    z.object({
      week: z.number().int(),
      workouts: z.array(aiWorkoutSchema.extend({ day: z.number().int().describe("ISO weekday, 1 = Monday") })),
    }),
  ),
});

export type GeneratedPlan = {
  title: string;
  summary: string;
  predictedTimeS: number | null;
  paces: PaceZones | null;
  workouts: PlannedWorkout[];
};

export async function generatePlan(
  runner: RunnerContext,
  goal: GoalContext,
  model: string = MODEL,
): Promise<GeneratedPlan> {
  const { output } = await generateText({
    model,
    providerOptions: gateway(runner.userId, "plan-generate"),
    system: COACH_SYSTEM,
    output: Output.object({ schema: planSchema }),
    prompt: `${describeRunner(runner, goal)}

Write the complete plan: weeks 1 to ${goal.weeks}, listing only running days (rest days are added automatically).`,
  });

  return {
    title: clip(output.title, 40),
    summary: clip(output.summary, 220),
    predictedTimeS: goal.goalType === "time" ? output.predictedTimeS : null,
    paces: output.paces ? fixPaces(output.paces) : null,
    workouts: normalizePlan(output, runner, goal),
  };
}

function fixPaces(p: PaceZones): PaceZones {
  const fixed = { ...p };
  for (const key of Object.keys(fixed) as (keyof PaceZones)[]) {
    const { min, max } = fixed[key];
    fixed[key] = { min: Math.min(min, max), max: Math.max(min, max) };
  }
  return fixed;
}

/**
 * Turns the AI's weeks into dated workouts for every day of the plan: keeps
 * only the runner's available days, caps weekly jumps, fills rest days, and
 * adds the finale (race, time trial or goal run) on the last day.
 */
function normalizePlan(
  plan: z.infer<typeof planSchema>,
  runner: RunnerContext,
  goal: GoalContext,
): PlannedWorkout[] {
  const runDays = new Set(runner.runDays);
  const byDate = new Map<string, PlannedWorkout>();

  for (const week of plan.weeks) {
    if (week.week < 1 || week.week > goal.weeks) continue;
    for (const w of week.workouts) {
      if (w.day < 1 || w.day > 7 || !runDays.has(w.day) || w.type === "race") continue;
      const date = dateFor(goal.startDate, week.week, w.day);
      if (date < goal.startDate || date >= goal.endDate || byDate.has(date)) continue;
      byDate.set(date, toPlanned(w, date, week.week));
    }
  }
  capWeeklyGrowth([...byDate.values()]);

  const result: PlannedWorkout[] = [];
  for (let week = 1; week <= goal.weeks; week++) {
    for (let day = 1; day <= 7; day++) {
      const date = dateFor(goal.startDate, week, day);
      if (date < goal.startDate || date > goal.endDate) continue;
      const planned = byDate.get(date) ?? restDay(date, week);
      result.push(date === goal.endDate ? (finale(goal, week) ?? planned) : planned);
    }
  }
  return result;
}

/** Scales down any week whose distance jumps more than ~15% over the best week so far. */
function capWeeklyGrowth(workouts: PlannedWorkout[]) {
  const totals = new Map<number, number>();
  for (const w of workouts) totals.set(w.week, (totals.get(w.week) ?? 0) + (w.distanceM ?? 0));
  let best = 0;
  for (const week of [...totals.keys()].sort((a, b) => a - b)) {
    const total = totals.get(week)!;
    const cap = best > 0 ? best * 1.15 + 1500 : total;
    if (total > cap) {
      const factor = cap / total;
      for (const w of workouts) {
        if (w.week === week && w.distanceM) w.distanceM = Math.round((w.distanceM * factor) / 100) * 100;
      }
    }
    best = Math.max(best, Math.min(total, cap));
  }
}

function finale(goal: GoalContext, week: number): PlannedWorkout | null {
  const base = { date: goal.endDate, week, type: "race" as const, steps: [] };
  switch (goal.goalKind) {
    case "race":
      return {
        ...base,
        title: clip(goal.raceName ?? "Race Day", 40),
        description: "This is what you trained for. Start easy and enjoy it.",
        distanceM: goal.raceDistanceM,
        durationS: goal.goalType === "time" ? goal.goalTimeS : null,
      };
    case "faster":
      return {
        ...base,
        title: "Time Trial",
        description: "Run it hard and even. See how far you've come.",
        distanceM: goal.raceDistanceM,
        durationS: goal.goalTimeS,
      };
    case "start":
      return {
        ...base,
        title: "Goal Run",
        description: "Thirty minutes, no walking. You're ready for this.",
        distanceM: null,
        durationS: 30 * 60,
      };
    case "fit":
      return null;
  }
}

function clip(text: string, max: number) {
  const t = text.trim();
  return t.length <= max ? t : `${t.slice(0, max - 1).trimEnd()}…`;
}

function toPlanned(
  w: Omit<z.infer<typeof aiWorkoutSchema>, "type"> & { type: WorkoutType },
  date: string,
  week: number,
): PlannedWorkout {
  const distanceM = w.distanceM && w.distanceM > 0 ? Math.min(w.distanceM, 50_000) : null;
  const durationS = w.durationS && w.durationS > 0 ? Math.min(w.durationS, 5 * 3600) : null;
  return {
    date,
    week,
    type: w.type,
    ...WORKOUT_COPY[w.type === "rest" || w.type === "race" ? "easy" : w.type],
    distanceM,
    durationS: distanceM == null && durationS == null ? 1800 : durationS,
    steps: w.steps.slice(0, 6).map((s) => ({ ...s, note: null })),
  };
}

export function restDay(date: string, week: number): PlannedWorkout {
  return {
    date,
    week,
    type: "rest",
    title: "Rest",
    description: "Recover. A walk or light stretching is perfect.",
    distanceM: null,
    durationS: null,
    steps: [],
  };
}

// ---------------------------------------------------------------------------
// Adjustments: the runner asks the coach to change upcoming workouts
// ---------------------------------------------------------------------------

const adjustmentSchema = z.object({
  reply: z
    .string()
    .describe("Two or three short, warm sentences to the runner explaining what you changed and why"),
  changes: z.array(
    z.object({
      date: z.string().describe("YYYY-MM-DD of the workout to replace"),
      workout: aiWorkoutSchema.extend({ type: z.enum([...RUN_TYPES, "rest"]) }),
    }),
  ),
});

export type AdjustmentContext = {
  runner: RunnerContext;
  goal: GoalContext;
  today: string;
  planSummary: string | null;
  paces: PaceZones | null;
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

function amount(w: PlannedWorkout) {
  if (w.distanceM) return km(w.distanceM);
  if (w.durationS) return `${Math.round(w.durationS / 60)} min`;
  return "-";
}

export async function generateAdjustment(ctx: AdjustmentContext) {
  const upcoming = ctx.workouts
    .map((w) => `${w.date} ${WEEKDAYS[isoWeekday(w.date)].slice(0, 3)} | ${w.type} | ${w.title} | ${amount(w)} | ${w.status}`)
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
    prompt: `${describeRunner(ctx.runner, ctx.goal)}

Today is ${ctx.today} (${WEEKDAYS[isoWeekday(ctx.today)]}).
${ctx.planSummary ? `Plan: ${ctx.planSummary}\n` : ""}${ctx.paces ? `Paces (per km): ${describePaces(ctx.paces)}\n` : ""}
Schedule (date | type | title | amount | status):
${upcoming}

Recent runs:
${runs}

The runner says: ${REASON_TEXT[ctx.reason] ?? REASON_TEXT.other}${ctx.message ? `\n"${ctx.message}"` : ""}

Adjust the plan like a thoughtful coach would. Only change workouts dated today or later, never completed workouts, and never the final day. Make the smallest set of changes that genuinely helps (usually the next few days to two weeks). Runs may go on any day if the runner asks. If there's pain, favor rest and easy running and suggest seeing a professional if it persists. Return an empty changes list if no change is needed, and say why in the reply.`,
  });

  const known = new Map(ctx.workouts.map((w) => [w.date, w]));
  const changes: PlannedWorkout[] = [];
  const seen = new Set<string>();
  for (const change of output.changes) {
    const existing = known.get(change.date);
    if (!existing || seen.has(change.date)) continue;
    if (change.date < ctx.today || change.date >= ctx.goal.endDate) continue;
    if (existing.status === "completed") continue;
    seen.add(change.date);
    changes.push(
      change.workout.type === "rest"
        ? restDay(change.date, existing.week)
        : toPlanned(change.workout, change.date, existing.week),
    );
  }

  return { reply: clip(output.reply, 400), changes };
}
