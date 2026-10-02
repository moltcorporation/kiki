import { eq } from "drizzle-orm";
import { db } from "@/db";
import { plan, profile } from "@/db/schema";
import type { GoalContext, RunnerContext } from "./coach";
import { weekCount } from "./dates";

export async function loadRunner(userId: string): Promise<RunnerContext> {
  const p = await db.query.profile.findFirst({ where: eq(profile.userId, userId) });
  if (!p) throw new Error(`No profile for user ${userId}`);
  return {
    userId,
    firstName: p.firstName,
    units: p.units,
    age: p.birthYear ? new Date().getFullYear() - p.birthYear : null,
    heightCm: p.heightCm,
    weightKg: p.weightKg,
    experience: p.experience,
    coachingStyle: p.coachingStyle,
    weeklyDistanceM: p.weeklyDistanceM,
    longestRunM: p.longestRunM,
    runDays: [...p.runDays].sort(),
    longRunDay: p.longRunDay,
  };
}

export function toGoalContext(row: typeof plan.$inferSelect): GoalContext {
  return {
    goalKind: row.goalKind,
    raceDistance: row.raceDistance,
    raceDistanceM: row.raceDistanceM,
    raceName: row.raceName,
    goalType: row.goalType,
    goalTimeS: row.goalTimeS,
    startDate: row.startDate,
    endDate: row.raceDate,
    weeks: weekCount(row.startDate, row.raceDate),
  };
}
