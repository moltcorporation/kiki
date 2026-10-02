// Source of truth for the database schema.
// Conventions: distances in meters, durations in seconds, paces in seconds per km.
// Calendar dates (no time zone) are stored as `date` strings in YYYY-MM-DD.

import { relations } from "drizzle-orm";
import {
  bigint,
  boolean,
  date,
  index,
  integer,
  jsonb,
  pgTable,
  real,
  smallint,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from "drizzle-orm/pg-core";
import type {
  CoachingStyle,
  Experience,
  Feeling,
  GoalKind,
  GoalType,
  PaceZones,
  RaceDistance,
  RunSource,
  Units,
  Phase,
  WorkoutStep,
  WorkoutType,
} from "@/lib/training/types";

const timestamps = {
  createdAt: timestamp("created_at", { withTimezone: true })
    .defaultNow()
    .notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .defaultNow()
    .$onUpdate(() => new Date())
    .notNull(),
};

// ---------------------------------------------------------------------------
// Better Auth (generated with `npx auth generate`, keep in sync with lib/auth.ts)
// ---------------------------------------------------------------------------

export const user = pgTable("user", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  email: text("email").notNull().unique(),
  emailVerified: boolean("email_verified").default(false).notNull(),
  image: text("image"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at")
    .defaultNow()
    .$onUpdate(() => new Date())
    .notNull(),
});

export const session = pgTable(
  "session",
  {
    id: text("id").primaryKey(),
    expiresAt: timestamp("expires_at").notNull(),
    token: text("token").notNull().unique(),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at")
      .$onUpdate(() => new Date())
      .notNull(),
    ipAddress: text("ip_address"),
    userAgent: text("user_agent"),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
  },
  (table) => [index("session_userId_idx").on(table.userId)],
);

export const account = pgTable(
  "account",
  {
    id: text("id").primaryKey(),
    accountId: text("account_id").notNull(),
    providerId: text("provider_id").notNull(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    accessToken: text("access_token"),
    refreshToken: text("refresh_token"),
    idToken: text("id_token"),
    accessTokenExpiresAt: timestamp("access_token_expires_at"),
    refreshTokenExpiresAt: timestamp("refresh_token_expires_at"),
    scope: text("scope"),
    password: text("password"),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at")
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => [index("account_userId_idx").on(table.userId)],
);

export const verification = pgTable(
  "verification",
  {
    id: text("id").primaryKey(),
    identifier: text("identifier").notNull(),
    value: text("value").notNull(),
    expiresAt: timestamp("expires_at").notNull(),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at")
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => [index("verification_identifier_idx").on(table.identifier)],
);

export const rateLimit = pgTable("rate_limit", {
  id: text("id").primaryKey(),
  key: text("key").notNull().unique(),
  count: integer("count").notNull(),
  lastRequest: bigint("last_request", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// Kiki
// ---------------------------------------------------------------------------

/** Everything we know about the runner. One row per user. */
export const profile = pgTable("profile", {
  userId: text("user_id")
    .primaryKey()
    .references(() => user.id, { onDelete: "cascade" }),
  firstName: text("first_name"),
  units: text("units").$type<Units>().notNull(),
  timezone: text("timezone").notNull(),
  birthYear: smallint("birth_year"),
  heightCm: real("height_cm"),
  weightKg: real("weight_kg"),
  experience: text("experience").$type<Experience>().notNull(),
  coachingStyle: text("coaching_style").$type<CoachingStyle>().default("balanced").notNull(),
  weeklyDistanceM: integer("weekly_distance_m").notNull(),
  longestRunM: integer("longest_run_m").notNull(),
  /** ISO weekdays the runner can train, 1 = Monday … 7 = Sunday. */
  runDays: smallint("run_days").array().notNull(),
  longRunDay: smallint("long_run_day").notNull(),
  /** Free-form onboarding answers not needed for planning (e.g. motivation). */
  extras: jsonb("extras").$type<Record<string, unknown>>(),
  ...timestamps,
});

export const plan = pgTable(
  "plan",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    status: text("status")
      .$type<"generating" | "ready" | "failed" | "archived">()
      .notNull(),
    goalKind: text("goal_kind").$type<GoalKind>().default("race").notNull(),
    /** Set for race and "get faster" goals. */
    raceDistance: text("race_distance").$type<RaceDistance>(),
    raceDistanceM: integer("race_distance_m"),
    raceName: text("race_name"),
    /** Last day of the plan: race day, time-trial day, or the plan's end. */
    raceDate: date("race_date").notNull(),
    startDate: date("start_date").notNull(),
    goalType: text("goal_type").$type<GoalType>().notNull(),
    goalTimeS: integer("goal_time_s"),
    title: text("title"),
    summary: text("summary"),
    predictedTimeS: integer("predicted_time_s"),
    paces: jsonb("paces").$type<PaceZones>(),
    /** Coarse progress for the "building your plan" screen. */
    progress: smallint("progress").default(0).notNull(),
    workflowRunId: text("workflow_run_id"),
    error: text("error"),
    ...timestamps,
  },
  (t) => [index("plan_user_status_idx").on(t.userId, t.status)],
);

export const workout = pgTable(
  "workout",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    planId: uuid("plan_id")
      .notNull()
      .references(() => plan.id, { onDelete: "cascade" }),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    date: date("date").notNull(),
    week: smallint("week").notNull(),
    type: text("type").$type<WorkoutType>().notNull(),
    title: text("title").notNull(),
    description: text("description").notNull(),
    distanceM: integer("distance_m"),
    durationS: integer("duration_s"),
    steps: jsonb("steps").$type<WorkoutStep[]>().default([]).notNull(),
    phase: text("phase").$type<Phase>(),
    status: text("status")
      .$type<"planned" | "completed" | "skipped">()
      .default("planned")
      .notNull(),
    ...timestamps,
  },
  (t) => [
    uniqueIndex("workout_plan_date_idx").on(t.planId, t.date),
    index("workout_user_date_idx").on(t.userId, t.date),
  ],
);

/** A completed run: tracked in-app, entered manually, or synced later. */
export const run = pgTable(
  "run",
  {
    /** Generated by the client so retries are idempotent. */
    id: uuid("id").primaryKey(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    workoutId: uuid("workout_id").references(() => workout.id, {
      onDelete: "set null",
    }),
    source: text("source").$type<RunSource>().notNull(),
    externalId: text("external_id"),
    startedAt: timestamp("started_at", { withTimezone: true }).notNull(),
    distanceM: real("distance_m").notNull(),
    durationS: integer("duration_s").notNull(),
    elevationGainM: real("elevation_gain_m"),
    avgHeartRate: smallint("avg_heart_rate"),
    /** Encoded polyline (precision 5). */
    route: text("route"),
    splits: jsonb("splits").$type<{ distanceM: number; durationS: number }[]>(),
    /** Perceived effort 1–10. */
    effort: smallint("effort"),
    feeling: text("feeling").$type<Feeling>(),
    notes: text("notes"),
    ...timestamps,
  },
  (t) => [
    index("run_user_started_idx").on(t.userId, t.startedAt),
    uniqueIndex("run_external_idx").on(t.userId, t.source, t.externalId),
  ],
);

/** A request to the AI coach to change the plan. */
export const planAdjustment = pgTable(
  "plan_adjustment",
  {
    /** Generated by the client so retries are idempotent. */
    id: uuid("id").primaryKey(),
    planId: uuid("plan_id")
      .notNull()
      .references(() => plan.id, { onDelete: "cascade" }),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    reason: text("reason").notNull(),
    message: text("message"),
    /** The day being adjusted; null when adjusting the whole plan. */
    targetDate: date("target_date"),
    status: text("status").$type<"pending" | "applied" | "failed">().notNull(),
    reply: text("reply"),
    changedDates: date("changed_dates").array(),
    workflowRunId: text("workflow_run_id"),
    ...timestamps,
  },
  (t) => [index("plan_adjustment_plan_idx").on(t.planId, t.createdAt)],
);

/**
 * Append-only record of each time a user agreed to the Terms and Privacy
 * Policy, as evidence of acceptance. `version` is the documents' "last
 * updated" date.
 */
export const consent = pgTable(
  "consent",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    version: text("version").notNull(),
    /** When the server recorded it (authoritative). */
    acceptedAt: timestamp("accepted_at", { withTimezone: true }).defaultNow().notNull(),
    /** When the user ticked the box on their device. */
    clientAcceptedAt: timestamp("client_accepted_at", { withTimezone: true }),
    appVersion: text("app_version"),
  },
  (t) => [index("consent_user_idx").on(t.userId, t.acceptedAt)],
);

// ---------------------------------------------------------------------------
// Relations
// ---------------------------------------------------------------------------

export const userRelations = relations(user, ({ many, one }) => ({
  sessions: many(session),
  accounts: many(account),
  profile: one(profile),
  plans: many(plan),
}));

export const sessionRelations = relations(session, ({ one }) => ({
  user: one(user, { fields: [session.userId], references: [user.id] }),
}));

export const accountRelations = relations(account, ({ one }) => ({
  user: one(user, { fields: [account.userId], references: [user.id] }),
}));

export const profileRelations = relations(profile, ({ one }) => ({
  user: one(user, { fields: [profile.userId], references: [user.id] }),
}));

export const planRelations = relations(plan, ({ one, many }) => ({
  user: one(user, { fields: [plan.userId], references: [user.id] }),
  workouts: many(workout),
}));

export const workoutRelations = relations(workout, ({ one, many }) => ({
  plan: one(plan, { fields: [workout.planId], references: [plan.id] }),
  runs: many(run),
}));

export const runRelations = relations(run, ({ one }) => ({
  workout: one(workout, { fields: [run.workoutId], references: [workout.id] }),
}));
