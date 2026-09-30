import { z } from "zod";

export const UNITS = ["km", "mi"] as const;
export type Units = (typeof UNITS)[number];

export const EXPERIENCES = ["new", "beginner", "intermediate", "advanced"] as const;
export type Experience = (typeof EXPERIENCES)[number];

export const RACE_DISTANCES = ["5k", "10k", "half", "marathon", "other"] as const;
export type RaceDistance = (typeof RACE_DISTANCES)[number];

export const RACE_DISTANCE_M: Record<Exclude<RaceDistance, "other">, number> = {
  "5k": 5000,
  "10k": 10000,
  half: 21097,
  marathon: 42195,
};

export const COACHING_STYLES = ["gentle", "balanced", "push"] as const;
export type CoachingStyle = (typeof COACHING_STYLES)[number];

/** What the runner wants from Kiki. Only affects inputs to the AI. */
export const GOAL_KINDS = ["start", "race", "faster", "fit"] as const;
export type GoalKind = (typeof GOAL_KINDS)[number];

export const GOAL_TYPES = ["finish", "time"] as const;
export type GoalType = (typeof GOAL_TYPES)[number];

export const WORKOUT_TYPES = [
  "rest",
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
export type WorkoutType = (typeof WORKOUT_TYPES)[number];

export const FEELINGS = ["great", "good", "okay", "tired", "pain"] as const;
export type Feeling = (typeof FEELINGS)[number];

export const RUN_SOURCES = ["kiki", "manual", "apple_health", "strava"] as const;
export type RunSource = (typeof RUN_SOURCES)[number];

export const PACE_ZONES = ["easy", "long", "tempo", "interval", "race", "recovery"] as const;
export type PaceZone = (typeof PACE_ZONES)[number];

/** Seconds per km. */
export const paceRangeSchema = z.object({
  min: z.number().int().describe("Faster end of the range, seconds per km"),
  max: z.number().int().describe("Slower end of the range, seconds per km"),
});
export type PaceRange = z.infer<typeof paceRangeSchema>;

export const paceZonesSchema = z.object({
  easy: paceRangeSchema,
  long: paceRangeSchema,
  tempo: paceRangeSchema,
  interval: paceRangeSchema,
  race: paceRangeSchema,
  recovery: paceRangeSchema,
});
export type PaceZones = z.infer<typeof paceZonesSchema>;

export const workoutStepSchema = z.object({
  kind: z.enum(["warmup", "work", "recovery", "cooldown"]),
  distanceM: z.number().int().nullable(),
  durationS: z.number().int().nullable(),
  repeat: z.number().int().nullable().describe("Repeat count for work/recovery pairs, else null"),
  pace: z.enum(PACE_ZONES).nullable(),
  note: z.string().nullable(),
});
export type WorkoutStep = z.infer<typeof workoutStepSchema>;

// ---------------------------------------------------------------------------
// API inputs
// ---------------------------------------------------------------------------

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Expected YYYY-MM-DD");
const weekday = z.number().int().min(1).max(7);

export const profileInputSchema = z.object({
  firstName: z.string().trim().max(50).nullish(),
  units: z.enum(UNITS),
  timezone: z.string().min(1).max(64),
  birthYear: z.number().int().min(1920).max(new Date().getFullYear() - 13).nullish(),
  heightCm: z.number().min(100).max(250).nullish(),
  weightKg: z.number().min(30).max(250).nullish(),
  experience: z.enum(EXPERIENCES),
  coachingStyle: z.enum(COACHING_STYLES).default("balanced"),
  weeklyDistanceM: z.number().int().min(0).max(300_000),
  longestRunM: z.number().int().min(0).max(100_000),
  runDays: z.array(weekday).min(1).max(7),
  longRunDay: weekday,
  extras: z.record(z.string(), z.unknown()).nullish(),
}).refine((p) => p.runDays.includes(p.longRunDay), {
  message: "Long run day must be one of the run days",
  path: ["longRunDay"],
});
export type ProfileInput = z.infer<typeof profileInputSchema>;

export const planInputSchema = z
  .object({
    goalKind: z.enum(GOAL_KINDS),
    raceDistance: z.enum(RACE_DISTANCES).nullish(),
    raceDistanceM: z.number().int().min(1000).max(250_000).nullish(),
    raceName: z.string().trim().max(100).nullish(),
    /** Race day (race goals only). */
    raceDate: isoDate.nullish(),
    /** Plan length for "get faster" goals. */
    weeks: z.union([z.literal(8), z.literal(12)]).nullish(),
    goalType: z.enum(GOAL_TYPES).default("finish"),
    goalTimeS: z.number().int().min(600).max(86_400).nullish(),
  })
  .refine((p) => (p.goalKind !== "race" && p.goalKind !== "faster") || p.raceDistance, {
    message: "A distance is required for this goal",
    path: ["raceDistance"],
  })
  .refine((p) => p.goalKind !== "race" || p.raceDate, {
    message: "Race date is required",
    path: ["raceDate"],
  })
  .refine((p) => p.goalKind !== "faster" || p.goalTimeS, {
    message: "Goal time is required",
    path: ["goalTimeS"],
  });
export type PlanInput = z.infer<typeof planInputSchema>;

export const runInputSchema = z.object({
  id: z.uuid(),
  workoutId: z.uuid().nullish(),
  source: z.enum(RUN_SOURCES),
  externalId: z.string().max(200).nullish(),
  startedAt: z.iso.datetime({ offset: true }),
  distanceM: z.number().min(0).max(500_000),
  durationS: z.number().int().min(0).max(172_800),
  elevationGainM: z.number().min(0).max(20_000).nullish(),
  avgHeartRate: z.number().int().min(30).max(250).nullish(),
  route: z.string().max(500_000).nullish(),
  splits: z
    .array(z.object({ distanceM: z.number(), durationS: z.number() }))
    .max(1000)
    .nullish(),
  effort: z.number().int().min(1).max(10).nullish(),
  feeling: z.enum(FEELINGS).nullish(),
  notes: z.string().trim().max(2000).nullish(),
});
export type RunInput = z.infer<typeof runInputSchema>;

export const ADJUSTMENT_REASONS = [
  "missed",
  "tired",
  "injured",
  "too_easy",
  "too_hard",
  "schedule",
  "race_changed",
  "other",
] as const;

export const adjustmentInputSchema = z.object({
  id: z.uuid(),
  reason: z.enum(ADJUSTMENT_REASONS),
  message: z.string().trim().max(1000).nullish(),
  /** The runner's local date, so "today" is unambiguous. */
  today: isoDate,
});
export type AdjustmentInput = z.infer<typeof adjustmentInputSchema>;
