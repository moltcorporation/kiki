const week = [
  { d: "M", done: true },
  { d: "T", done: true },
  { d: "W", rest: true },
  { d: "T", today: true },
  { d: "F", rest: true },
  { d: "S" },
  { d: "S" },
];

function Frame({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div
      role="img"
      aria-label={label}
      className="relative mx-auto aspect-[9/19.5] w-[300px] overflow-hidden rounded-[52px] border-[10px] border-[#23262c] bg-paper shadow-[0_30px_60px_-20px_rgba(0,0,0,0.8),0_0_0_1px_rgba(255,255,255,0.06)]"
    >
      <div className="absolute left-1/2 top-3 z-20 h-7 w-28 -translate-x-1/2 rounded-full bg-black" />
      {children}
    </div>
  );
}

/** The app's welcome screen: the running film with the pitch over it. */
export function WelcomePhone() {
  return (
    <Frame label="The Kiki app's welcome screen: a runner at sunset with “Your AI running coach.”">
      <video
        className="absolute inset-0 size-full object-cover"
        src="/welcome.mp4"
        poster="/welcome-poster.jpg"
        autoPlay
        muted
        loop
        playsInline
        preload="auto"
        aria-hidden
      />
      <div className="absolute inset-0 bg-gradient-to-b from-black/30 via-transparent via-35% to-black/90" />
      <div className="absolute inset-x-5 bottom-6 text-center">
        {/* eslint-disable-next-line @next/next/no-img-element -- tiny static asset */}
        <img src="/kiki-wordmark.png" alt="" aria-hidden className="mx-auto mb-2 h-[24px] w-auto" />
        <p className="text-[19px] font-semibold leading-tight text-white">
          Your AI
          <br />
          running coach.
        </p>
        <div className="mt-6 rounded-full bg-white py-3 text-center text-[14px] font-semibold text-[#0b0c0e]">
          Get started
        </div>
        <p className="mt-2.5 text-[11px] text-white/80">
          Already have an account? <span className="font-semibold text-white">Sign in</span>
        </p>
      </div>
    </Frame>
  );
}

/** The app's "Today" screen in dark mode. */
export function TodayPhone() {
  return (
    <Frame label="The Kiki app showing today's tempo run and the week ahead">
      <div className="px-5 pt-14">
        <p className="text-[13px] font-medium text-subtle">Thursday · Week 6 of 12</p>
        <p className="mt-1 text-[26px] font-bold leading-tight tracking-tight">Good morning, Sam</p>

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
          <p className="text-[12px] font-semibold uppercase tracking-wider text-paper/55">Tempo</p>
          <p className="mt-1 text-[24px] font-bold leading-tight tracking-tight">Tempo Run</p>
          <div className="mt-4 flex gap-6">
            <div>
              <p className="text-[22px] font-black italic">6.0</p>
              <p className="text-[11px] text-paper/55">miles</p>
            </div>
            <div>
              <p className="text-[22px] font-black italic">8:05</p>
              <p className="text-[11px] text-paper/55">tempo /mi</p>
            </div>
          </div>
          <p className="mt-4 text-[13px] leading-snug text-paper/70">
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
    </Frame>
  );
}
