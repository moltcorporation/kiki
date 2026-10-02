import type { GatewayProviderOptions } from "@ai-sdk/gateway";
import { generateText, Output } from "ai";
import { z } from "zod";
import { dateFor, isoWeekday } from "./dates";
import {
  paceZonesSchema,
  PHASES,
  PLAN_WORKOUT_TYPES,
  workoutStepSchema,
  type CoachingStyle,
  type Experience,
  type Feeling,
  type GoalKind,
  type GoalType,
  type PaceZones,
  type Phase,
  type PlanWorkoutType,
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
    // The plan is long structured output; light reasoning keeps it fast.
    google: { thinkingConfig: { thinkingLevel: "low" } },
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
  longestRunM: number;
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
  phase: Phase | null;
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
  new: "New to running, or can run less than 1 km without stopping",
  beginner: "Can run 1.5–5 km without stopping",
  intermediate: "Can comfortably run 5–10 km without stopping",
  advanced: "Regularly runs 10+ km without stopping",
};

/** Matches the coaching-style choices shown in onboarding. */
const STYLE_TEXT: Record<CoachingStyle, string> = {
  gentle: "Gentle: wants to ease in, with extra recovery and a reassuring tone.",
  balanced: "Balanced: steady progress and a supportive, practical tone.",
  push: "Push me: wants to be challenged; progress as quickly as is still safe, with a direct, motivating tone.",
};

export const COACH_SYSTEM = `You are Kiki, a world-class running coach. You write tailored training plans for one runner at a time, the way a great personal coach would: built around where they are today, the goal they're chasing, the time they have, and how they like to be coached.

Workout types (use only these; any day without a workout is a rest day):
- easy: comfortable, conversational effort that builds the aerobic base. Walking is allowed; for newer runners, structure it as run/walk repeats in the steps.
- long: the week's longest run, at an easy or even slower effort. It's about distance and time on feet.
- tempo: a continuous, comfortably hard block after an easy warm up. No walking.
- intervals: fast repeats with an easy jog or walk between.

Phases: label every week base, build, peak or taper. Base builds consistent easy running; build adds distance and harder sessions; peak is the most demanding stretch; taper is lighter so they arrive fresh. Use what fits the plan's length and goal (a short plan may skip phases; a stay-fit plan can stay in base and build).

How you coach:
- Start from what the runner can do now (their weekly distance and longest recent run when given), not from zero. A runner who's already training picks up where they are.
- Safety first: no injuries, no burnout. Progress at a rate that suits their experience, age and coaching style. Runners who ask to be pushed, are experienced, or have a time goal can handle more.
- Match the workouts to their experience and goal. New and beginner runners get easy runs (with walk breaks where needed) and a long run, nothing else: tempo and intervals are for experienced runners, or for time goals where they help.
- Keep most running easy. No hard sessions on back-to-back days. The long run goes on their long-run day. Only use their available days; newer runners often do best with fewer runs.
- If the time available is ambitious for the goal, still write the most realistic, safe plan for that time.

Numbers: distances in meters, durations in seconds, paces in seconds per km. Round distances to sensible values in the runner's unit. Use durations for run/walk and newer runners, distances otherwise.
Steps: only for run/walk easy runs, tempo and intervals, always in this shape: warmup, one work step (with a repeat count when it repeats), its recovery with the same repeat count, cooldown. Other easy and long runs have no steps.`;

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
      return "Start running: build to running 30 minutes without stopping. The plan ends with a 30-minute Goal Run on the last day.";
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
  if (runner.experience !== "new") {
    if (runner.weeklyDistanceM > 0) lines.push(`- Currently runs about ${km(runner.weeklyDistanceM)} a week`);
    if (runner.longestRunM > 0) lines.push(`- Longest run in the last few weeks: about ${km(runner.longestRunM)}`);
  }
  lines.push(
    `- Available days: ${runner.runDays.map((d) => WEEKDAYS[d]).join(", ")}`,
    `- Long-run day: ${WEEKDAYS[runner.longRunDay]}`,
    `- Uses ${runner.units === "mi" ? "miles" : "kilometers"}`,
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
    .map((k) => {
      // Older plans stored a range; use its middle.
      const v = p[k] as number | { min: number; max: number };
      return `${k}: ${pace(typeof v === "number" ? v : (v.min + v.max) / 2)}`;
    })
    .join(", ");
}

// ---------------------------------------------------------------------------
// Plan generation (one AI call)
// ---------------------------------------------------------------------------

// The AI picks the type and the numbers only. Titles, descriptions and
// step wording come from the app's fixed copy (WORKOUT_COPY), so every
// workout of a type reads the same, day to day and plan to plan.
const aiWorkoutSchema = z.object({
  type: z.enum(PLAN_WORKOUT_TYPES),
  distanceM: z.number().int().nullable(),
  durationS: z.number().int().nullable(),
  steps: z.array(workoutStepSchema.omit({ note: true })),
});

/** The title and one-line "what to do" for each workout type. */
export const WORKOUT_COPY: Record<PlanWorkoutType, { title: string; description: string }> = {
  easy: { title: "Easy Run", description: "Comfortable, conversational pace. Walk breaks are fine." },
  long: { title: "Long Run", description: "Slow and steady. Distance is the goal, not speed." },
  tempo: { title: "Tempo Run", description: "Warm up easy, then hold a comfortably hard pace. No walking." },
  intervals: { title: "Intervals", description: "Fast repeats with an easy jog or walk between." },
};

const planSchema = z.object({
  title: z.string().describe("Short plan title, max ~30 characters, e.g. 'First 30 Minutes' or 'Brooklyn Half'"),
  summary: z
    .string()
    .describe(
      "One or two short, warm sentences to the runner by first name about how this plan gets them there. If the timeline is ambitious, say so kindly.",
    ),
  predictedTimeS: z
    .number()
    .int()
    .nullable()
    .describe("Realistic finish time in seconds for time goals only, else null"),
  paces: paceZonesSchema
    .nullable()
    .describe("One recommended target pace per effort, only for time goals or runners past beginner level, else null"),
  weeks: z.array(
    z.object({
      week: z.number().int(),
      phase: z.enum(PHASES),
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

Write the complete plan: weeks 1 to ${goal.weeks}, each with its phase, listing only running days.`,
  });

  return {
    title: clip(output.title, 40),
    summary: clip(output.summary, 220),
    predictedTimeS: goal.goalType === "time" ? output.predictedTimeS : null,
    paces: output.paces,
    workouts: normalizePlan(output, runner, goal),
  };
}

/**
 * Turns the AI's weeks into dated workouts for every day of the plan: keeps
 * only the runner's available days, guards against runaway weekly jumps,
 * fills rest days, and adds the finale (race, time trial or goal run) on
 * the last day.
 */
function normalizePlan(
  plan: z.infer<typeof planSchema>,
  runner: RunnerContext,
  goal: GoalContext,
): PlannedWorkout[] {
  const runDays = new Set(runner.runDays);
  const byDate = new Map<string, PlannedWorkout>();
  const phases = new Map<number, Phase>();

  for (const week of plan.weeks) {
    if (week.week < 1 || week.week > goal.weeks) continue;
    phases.set(week.week, week.phase);
    for (const w of week.workouts) {
      if (w.day < 1 || w.day > 7 || !runDays.has(w.day)) continue;
      const date = dateFor(goal.startDate, week.week, w.day);
      if (date < goal.startDate || date >= goal.endDate || byDate.has(date)) continue;
      byDate.set(date, toPlanned(w, date, week.week, week.phase));
    }
  }
  guardWeeklyJumps([...byDate.values()]);

  const result: PlannedWorkout[] = [];
  for (let week = 1; week <= goal.weeks; week++) {
    const phase = phases.get(week) ?? null;
    for (let day = 1; day <= 7; day++) {
      const date = dateFor(goal.startDate, week, day);
      if (date < goal.startDate || date > goal.endDate) continue;
      const planned = byDate.get(date) ?? restDay(date, week, phase);
      result.push(date === goal.endDate ? (finale(goal, week, phase) ?? planned) : planned);
    }
  }
  return result;
}

/**
 * A safety net for model glitches, not a coaching rule (the coach decides
 * progression): scales down any week that more than ~30% exceeds the
 * biggest week before it.
 */
function guardWeeklyJumps(workouts: PlannedWorkout[]) {
  const totals = new Map<number, number>();
  for (const w of workouts) totals.set(w.week, (totals.get(w.week) ?? 0) + (w.distanceM ?? 0));
  let best = 0;
  for (const week of [...totals.keys()].sort((a, b) => a - b)) {
    const total = totals.get(week)!;
    const cap = best > 0 ? best * 1.3 + 3000 : total;
    if (total > cap) {
      const factor = cap / total;
      for (const w of workouts) {
        if (w.week === week && w.distanceM) w.distanceM = Math.round((w.distanceM * factor) / 100) * 100;
      }
    }
    best = Math.max(best, Math.min(total, cap));
  }
}

function finale(goal: GoalContext, week: number, phase: Phase | null): PlannedWorkout | null {
  const base = { date: goal.endDate, week, type: "race" as const, steps: [], phase };
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
  w: z.infer<typeof aiWorkoutSchema>,
  date: string,
  week: number,
  phase: Phase | null,
): PlannedWorkout {
  const distanceM = w.distanceM && w.distanceM > 0 ? Math.min(w.distanceM, 50_000) : null;
  const durationS = w.durationS && w.durationS > 0 ? Math.min(w.durationS, 5 * 3600) : null;
  // Long runs never walk-structured; tempo and intervals always have steps.
  const steps =
    w.type === "long"
      ? []
      : w.steps
          .filter((s) => (s.distanceM ?? 0) > 0 || (s.durationS ?? 0) > 0)
          .slice(0, 6)
          .map((s) => ({ ...s, note: null }));
  return {
    date,
    week,
    type: w.type,
    ...WORKOUT_COPY[w.type],
    distanceM,
    durationS: distanceM == null && durationS == null ? 1800 : durationS,
    steps,
    phase,
  };
}

export function restDay(date: string, week: number, phase: Phase | null): PlannedWorkout {
  return {
    date,
    week,
    type: "rest",
    title: "Rest",
    description: "Rest up. A walk, stretching or light strength work is fine.",
    distanceM: null,
    durationS: null,
    steps: [],
    phase,
  };
}

// ---------------------------------------------------------------------------
// Adjustments: targeted edits to upcoming workouts
// ---------------------------------------------------------------------------

const adjustmentSchema = z.object({
  reply: z.string().describe("One or two short, warm sentences to the runner saying what you changed and why"),
  changes: z
    .array(
      z.object({
        date: z.string().describe("YYYY-MM-DD of the workout to replace"),
        workout: aiWorkoutSchema.extend({ type: z.enum([...PLAN_WORKOUT_TYPES, "rest"]) }),
      }),
    )
    .describe("Only the days that change"),
});

export type AdjustmentContext = {
  runner: RunnerContext;
  goal: GoalContext;
  today: string;
  /** The day being adjusted; null for the whole plan. */
  targetDate: string | null;
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

const REASON_TEXT: Record<string, { day: string; plan: string }> = {
  missed: { day: "I missed this run.", plan: "I've missed some runs." },
  tired: { day: "I'm feeling tired today.", plan: "I've been feeling tired." },
  injured: { day: "Something hurts.", plan: "Something hurts." },
  too_easy: { day: "This run looks too easy.", plan: "The plan is too easy. Push me harder." },
  too_hard: { day: "This run is too hard for me today.", plan: "The plan is too aggressive. Make it easier." },
  schedule: { day: "I can't make this run on this day.", plan: "My schedule changed." },
  race_changed: { day: "My race details changed.", plan: "My race details changed." },
  other: { day: "I'd like to change this run.", plan: "I'd like to change my plan." },
};

function amount(w: PlannedWorkout) {
  if (w.distanceM) return km(w.distanceM);
  if (w.durationS) return `${Math.round(w.durationS / 60)} min`;
  return "-";
}

export async function generateAdjustment(ctx: AdjustmentContext) {
  const line = (w: PlannedWorkout & { status: string }) =>
    `${w.date} ${WEEKDAYS[isoWeekday(w.date)].slice(0, 3)} | ${w.phase ?? "-"} | ${w.type} | ${amount(w)} | ${w.status}`;
  const past = ctx.workouts.filter((w) => w.date < ctx.today && w.type !== "rest");
  // A day only needs the next couple of weeks; the plan needs all of it.
  const horizon = ctx.targetDate ? addDaysISO(ctx.targetDate, 14) : ctx.goal.endDate;
  const upcoming = ctx.workouts.filter((w) => w.date >= ctx.today && w.date <= horizon);
  const runs =
    ctx.recentRuns
      .map(
        (r) =>
          `${r.date}: ${km(r.distanceM)} in ${duration(r.durationS)}${r.effort ? `, effort ${r.effort}/10` : ""}${r.feeling ? `, felt ${r.feeling}` : ""}${r.notes ? ` ("${r.notes}")` : ""}`,
      )
      .join("\n") || "none logged";

  const reason = REASON_TEXT[ctx.reason] ?? REASON_TEXT.other;
  const target = ctx.targetDate ? ctx.workouts.find((w) => w.date === ctx.targetDate) : undefined;
  const ask = target
    ? `The runner is asking about ${target.date} (${target.type}, ${amount(target)}): ${reason.day}`
    : `The runner is asking about their plan overall: ${reason.plan}`;
  const scope = target
    ? "Change that day. Only touch other days when it's needed (say, moving the run to another day this week, or easing the next day or two after pain). Leave everything else as it is."
    : "Make targeted changes to the upcoming weeks that address this, keeping the plan's goal, structure and phases. Don't rewrite weeks that don't need it.";

  const { output } = await generateText({
    model: MODEL,
    providerOptions: gateway(ctx.runner.userId, "plan-adjust"),
    system: COACH_SYSTEM,
    output: Output.object({ schema: adjustmentSchema }),
    prompt: `${describeRunner(ctx.runner, ctx.goal)}

Today is ${ctx.today} (${WEEKDAYS[isoWeekday(ctx.today)]}).
${ctx.planSummary ? `Plan: ${ctx.planSummary}\n` : ""}${ctx.paces ? `Paces (per km): ${describePaces(ctx.paces)}\n` : ""}
Recent workouts (date | phase | type | amount | status):
${past.map(line).join("\n") || "none yet"}

Recent runs:
${runs}

Upcoming (date | phase | type | amount | status):
${upcoming.map(line).join("\n")}

${ask}${ctx.message ? `\nIn their words: "${ctx.message}"` : ""}

${scope} Only change days from today on, never completed workouts or the final day. A day can become rest. If there's pain, favor rest and easy running and suggest seeing a professional if it persists. Return only the days that change (an empty list if nothing should), and say what you did in the reply, with any distances in ${ctx.runner.units === "mi" ? "miles" : "kilometers"}.`,
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
    const { type, ...rest } = change.workout;
    changes.push(
      type === "rest"
        ? restDay(change.date, existing.week, existing.phase)
        : toPlanned({ type, ...rest }, change.date, existing.week, existing.phase),
    );
  }

  return { reply: clip(output.reply, 280), changes };
}

function addDaysISO(date: string, days: number) {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}
