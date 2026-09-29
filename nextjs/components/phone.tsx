const week = [
  { d: "M", done: true },
  { d: "T", done: true },
  { d: "W", rest: true },
  { d: "T", today: true },
  { d: "F", rest: true },
  { d: "S" },
  { d: "S" },
];

/** A static, CSS-only rendering of the Kiki "Today" screen. */
export function PhoneMockup() {
  return (
    <div
      role="img"
      aria-label="The Kiki app showing today's tempo run and the week ahead"
      className="relative mx-auto w-[300px] rounded-[52px] border-[10px] border-ink bg-paper p-5 shadow-[0_40px_80px_-30px_rgba(21,24,29,0.45)]"
    >
      <div className="mx-auto mb-5 h-7 w-28 rounded-full bg-ink" />
      <p className="text-[13px] font-medium text-subtle">Thursday · Week 6 of 12</p>
      <p className="mt-1 text-[28px] font-bold leading-tight tracking-tight">Today</p>

      <div className="mt-4 flex justify-between">
        {week.map((day, i) => (
          <div key={i} className="flex flex-col items-center gap-1.5">
            <span className="text-[11px] font-medium text-subtle">{day.d}</span>
            <span
              className={`grid size-8 place-items-center rounded-full text-[11px] font-semibold ${
                day.today
                  ? "bg-ink text-paper"
                  : day.done
                    ? "bg-wash text-ink"
                    : "border border-line text-subtle"
              }`}
            >
              {day.done ? "✓" : day.rest ? "–" : ""}
            </span>
          </div>
        ))}
      </div>

      <div className="mt-5 rounded-3xl bg-ink p-5 text-paper">
        <p className="text-[12px] font-semibold uppercase tracking-wider text-white/60">Tempo</p>
        <p className="mt-1 text-[24px] font-bold leading-tight tracking-tight">Tempo Run</p>
        <div className="mt-4 flex gap-6">
          <div>
            <p className="text-[22px] font-bold italic">6.0</p>
            <p className="text-[11px] text-white/60">miles</p>
          </div>
          <div>
            <p className="text-[22px] font-bold italic">8:05</p>
            <p className="text-[11px] text-white/60">tempo /mi</p>
          </div>
        </div>
        <p className="mt-4 text-[13px] leading-snug text-white/75">
          Comfortably hard. You could speak a few words, not full sentences.
        </p>
        <div className="mt-5 rounded-full bg-paper py-3 text-center text-[14px] font-semibold text-ink">
          Mark as done
        </div>
      </div>

      <div className="mt-3 flex items-center justify-between rounded-2xl bg-wash px-4 py-3">
        <div>
          <p className="text-[12px] text-subtle">Saturday</p>
          <p className="text-[14px] font-semibold">Long Run · 11 mi</p>
        </div>
        <span className="text-subtle">›</span>
      </div>
    </div>
  );
}
