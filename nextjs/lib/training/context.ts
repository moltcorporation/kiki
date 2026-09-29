import { eq } from "drizzle-orm";
import { db } from "@/db";
import { plan, profile } from "@/db/schema";
import type { RaceContext, RunnerContext } from "./coach";
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
    weeklyDistanceM: p.weeklyDistanceM,
    longestRunM: p.longestRunM,
    runDays: [...p.runDays].sort(),
    longRunDay: p.longRunDay,
    injury: p.injury,
  };
}

export function toRaceContext(row: typeof plan.$inferSelect): RaceContext {
  return {
    raceDistance: row.raceDistance,
    raceDistanceM: row.raceDistanceM,
    raceName: row.raceName,
    raceDate: row.raceDate,
    startDate: row.startDate,
    weeks: weekCount(row.startDate, row.raceDate),
    goalType: row.goalType,
    goalTimeS: row.goalTimeS,
    recentRaceDistanceM: row.recentRaceDistanceM,
    recentRaceTimeS: row.recentRaceTimeS,
  };
}
