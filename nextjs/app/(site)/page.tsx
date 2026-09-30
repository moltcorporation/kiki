import { TodayPhone, WelcomePhone } from "@/components/phone";
import { DownloadButton } from "@/components/site";

const goals = ["Start running", "Train for a race", "Get faster", "Stay fit"];

const steps = [
  {
    title: "Tell Kiki about you",
    body: "Your goal, how much you run now and which days you're free. Two minutes, mostly taps.",
  },
  {
    title: "Get your plan",
    body: "A day-by-day plan built for you, at your level and on your schedule. No jargon, just what to run today.",
  },
  {
    title: "Train. Kiki adapts.",
    body: "Missed a day? Tired? Sore? Tell Kiki and your upcoming weeks adjust, just like a real coach.",
  },
];

const features = [
  {
    title: "Built around you",
    body: "Plans start from where you are today, whether that's your first run or your hundredth race.",
  },
  {
    title: "A coach in your pocket",
    body: "Change anything, anytime. Kiki explains every change so you always know why.",
  },
  {
    title: "Clear at a glance",
    body: "Today, this week, or the whole month. Always know exactly what's next.",
  },
  {
    title: "Track, or just tap done",
    body: "Record your run with GPS and a Live Activity on your Lock Screen, or simply mark it done.",
  },
];

const principles = [
  ["Mostly easy", "Most runs feel comfortable, so you build fitness without burning out."],
  ["Build gradually", "Small weekly steps up, never sudden jumps."],
  ["Recover on purpose", "Easier weeks are built in so your body can adapt."],
  ["Your level", "Every run is set for you, from run/walk to fast workouts."],
];

const faqs = [
  {
    q: "Who is Kiki for?",
    a: "Anyone who wants to run: complete beginners starting from zero, runners training for a 5K to a marathon, and experienced runners chasing a faster time or just staying consistent.",
  },
  {
    q: "How is the plan created?",
    a: "Kiki uses AI guided by proven coaching principles (mostly easy running, gradual build-ups and regular easier weeks) to create a plan from your answers. Every plan is checked against safety rules like limits on weekly increases.",
  },
  {
    q: "Can I change my plan?",
    a: "Anytime. Move a workout, skip one, change your goal, or tell Kiki you're tired, busy or sore, and your upcoming workouts adapt.",
  },
  {
    q: "Do I have to track runs with Kiki?",
    a: "No. You can record runs with GPS in Kiki, or just mark a workout done and add your distance, time and how it felt.",
  },
  {
    q: "Is Kiki medical advice?",
    a: "No. Kiki is a training tool, not a medical service. If you have pain, an injury or a health condition, check with a qualified professional before training.",
  },
];

export default function Home() {
  return (
    <>
      {/* Hero */}
      <section className="asphalt -mt-16 overflow-hidden pt-16">
        <div className="mx-auto grid max-w-6xl items-center gap-16 px-5 pb-24 pt-16 md:grid-cols-[1.15fr_1fr] md:pb-32 md:pt-24">
          <div className="min-w-0">
            <ul className="mb-8 flex flex-wrap gap-2" aria-label="Goals">
              {goals.map((goal) => (
                <li
                  key={goal}
                  className="rounded-full border border-line bg-white/[0.03] px-3.5 py-1.5 text-sm font-medium text-muted"
                >
                  {goal}
                </li>
              ))}
            </ul>
            <h1 className="text-balance text-[clamp(2.75rem,12vw,3.75rem)] font-black italic leading-[0.92] tracking-[-0.04em] sm:text-7xl lg:text-[104px]">
              Your AI running coach.
            </h1>
            <p className="mt-8 max-w-md text-pretty text-xl leading-relaxed text-muted">
              A running plan built around your goal, your schedule and your body. And it adapts
              every time life happens.
            </p>
            <div className="mt-10">
              <DownloadButton />
            </div>
          </div>
          <WelcomePhone />
        </div>
      </section>

      {/* How it works */}
      <section id="how" className="scroll-mt-20 border-t border-line">
        <div className="mx-auto max-w-6xl px-5 py-28">
          <h2 className="max-w-xl text-4xl font-black italic tracking-[-0.03em] sm:text-6xl">
            From first step to finish line.
          </h2>
          <ol className="mt-14 grid gap-4 md:grid-cols-3">
            {steps.map((step, i) => (
              <li key={step.title} className="rounded-3xl border border-line bg-surface p-8">
                <span className="text-5xl font-black italic text-ink/15">{i + 1}</span>
                <h3 className="mt-6 text-xl font-semibold">{step.title}</h3>
                <p className="mt-2 leading-relaxed text-muted">{step.body}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* Adapts */}
      <section className="border-t border-line">
        <div className="mx-auto grid max-w-6xl items-center gap-14 px-5 py-28 md:grid-cols-2">
          <div>
            <h2 className="text-4xl font-black italic tracking-[-0.03em] sm:text-6xl">
              Life happens. Kiki adapts.
            </h2>
            <p className="mt-6 max-w-md text-lg leading-relaxed text-muted">
              Real training rarely goes to plan. Kiki rebalances your upcoming runs so you stay
              consistent without overdoing it.
            </p>
          </div>
          <div className="space-y-3" aria-label="Example conversation with Kiki">
            <div className="ml-auto w-fit max-w-[85%] rounded-3xl rounded-br-lg bg-wash px-5 py-3.5 text-[17px]">
              I&apos;m wiped out this week. Work has been brutal.
            </div>
            <div className="flex items-end gap-3">
              {/* eslint-disable-next-line @next/next/no-img-element -- tiny static asset */}
              <img src="/kiki-icon.png" alt="" aria-hidden className="size-9 shrink-0 rounded-[22.5%]" />
              <div className="w-fit max-w-[85%] rounded-3xl rounded-bl-lg bg-ink px-5 py-3.5 text-[17px] leading-relaxed text-paper">
                No problem. I swapped Thursday&apos;s run for rest and eased up Saturday.
                We&apos;ll pick it back up next week.
              </div>
            </div>
            <div className="flex flex-wrap gap-2 pt-3">
              {["Missed a run", "Feeling tired", "Something hurts", "Too easy", "Busy week"].map(
                (chip) => (
                  <span key={chip} className="rounded-full border border-line px-4 py-2 text-sm font-medium text-muted">
                    {chip}
                  </span>
                ),
              )}
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="border-t border-line">
        <div className="mx-auto grid max-w-6xl items-center gap-16 px-5 py-28 md:grid-cols-[1fr_1.1fr]">
          <TodayPhone />
          <div>
            <h2 className="max-w-xl text-4xl font-black italic tracking-[-0.03em] sm:text-6xl">
              Everything you need. Nothing you don&apos;t.
            </h2>
            <div className="mt-12 grid gap-x-10 gap-y-10 sm:grid-cols-2">
              {features.map((f) => (
                <div key={f.title}>
                  <h3 className="text-lg font-semibold">{f.title}</h3>
                  <p className="mt-2 leading-relaxed text-muted">{f.body}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* Principles */}
      <section className="asphalt border-t border-line">
        <div className="mx-auto max-w-6xl px-5 py-28">
          <h2 className="max-w-2xl text-4xl font-black italic tracking-[-0.03em] sm:text-6xl">
            Personal plans. Proven principles.
          </h2>
          <p className="mt-6 max-w-xl text-lg leading-relaxed text-muted">
            Every Kiki plan follows the fundamentals great coaches use, tailored to where you are
            today.
          </p>
          <div className="mt-14 grid gap-px overflow-hidden rounded-3xl border border-line bg-line sm:grid-cols-2 lg:grid-cols-4">
            {principles.map(([title, body]) => (
              <div key={title} className="bg-asphalt/90 p-8">
                <h3 className="text-xl font-black italic">{title}</h3>
                <p className="mt-2 leading-relaxed text-muted">{body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section id="faq" className="scroll-mt-20 border-t border-line">
        <div className="mx-auto max-w-3xl px-5 py-28">
          <h2 className="text-4xl font-black italic tracking-[-0.03em] sm:text-6xl">Questions</h2>
          <div className="mt-10 divide-y divide-line">
            {faqs.map((f) => (
              <details key={f.q} className="group py-6">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-6 text-lg font-semibold">
                  {f.q}
                  <span className="text-2xl font-light text-subtle transition-transform group-open:rotate-45">+</span>
                </summary>
                <p className="mt-3 leading-relaxed text-muted">{f.a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="asphalt border-t border-line">
        <div className="mx-auto max-w-6xl px-5 py-32 text-center">
          <h2 className="mx-auto max-w-3xl text-balance text-5xl font-black italic leading-[0.95] tracking-[-0.04em] sm:text-8xl">
            Your best run starts today.
          </h2>
          <div className="mt-12 flex justify-center">
            <DownloadButton />
          </div>
        </div>
      </section>
    </>
  );
}
