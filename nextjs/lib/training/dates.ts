// Calendar-date helpers for YYYY-MM-DD strings. All math happens in UTC so
// results never shift with the server's time zone.

const DAY_MS = 86_400_000;

function toUTC(date: string) {
  return Date.parse(`${date}T00:00:00Z`);
}

function fromUTC(ms: number) {
  return new Date(ms).toISOString().slice(0, 10);
}

export function addDays(date: string, days: number) {
  return fromUTC(toUTC(date) + days * DAY_MS);
}

export function diffDays(later: string, earlier: string) {
  return Math.round((toUTC(later) - toUTC(earlier)) / DAY_MS);
}

/** ISO weekday: 1 = Monday … 7 = Sunday. */
export function isoWeekday(date: string) {
  const day = new Date(toUTC(date)).getUTCDay();
  return day === 0 ? 7 : day;
}

export function mondayOf(date: string) {
  return addDays(date, 1 - isoWeekday(date));
}

/** Today's calendar date in the given IANA time zone. */
export function todayIn(timezone: string) {
  try {
    return new Intl.DateTimeFormat("en-CA", { timeZone: timezone }).format(new Date());
  } catch {
    return fromUTC(Date.now());
  }
}

/** Number of Monday-based training weeks from `start` through `race`. */
export function weekCount(start: string, race: string) {
  return diffDays(mondayOf(race), mondayOf(start)) / 7 + 1;
}

/** Date of a given week (1-based) and ISO weekday within the plan. */
export function dateFor(start: string, week: number, day: number) {
  return addDays(mondayOf(start), (week - 1) * 7 + (day - 1));
}
