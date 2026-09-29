import { PhoneMockup } from "@/components/phone";
import { DownloadButton } from "@/components/site";
import { site } from "@/lib/site";

const steps = [
  {
    title: "Tell Kiki about you",
    body: "Your race, your goal, how much you run now and which days you're free. Two minutes, mostly taps.",
  },
  {
    title: "Get your plan",
    body: "A day-by-day plan built for you: easy runs, long runs and workouts at your paces, on your schedule.",
  },
  {
    title: "Train. Kiki adapts.",
    body: "Missed a day? Tired? Tweaked something? Tell Kiki and your upcoming weeks adjust, just like a real coach.",
  },
];

const features = [
  {
    title: "Built around you",
    body: "Plans start from your current fitness, not a template. Paces come from your recent race or experience.",
  },
  {
    title: "A coach in your pocket",
    body: "Change anything, anytime. Kiki explains every change so you always know why.",
  },
  {
    title: "Clear at a glance",
    body: "Today, this week, or the whole month. Switch views with a tap and always know what's next.",
  },
  {
    title: "Track, or just tap done",
    body: "Record your run with GPS and a Live Activity on your Lock Screen, or simply mark it done.",
  },
  {
    title: "How you felt matters",
    body: "Log effort and how you felt after each run. Kiki uses it to keep you fresh and injury-free.",
  },
  {
    title: "Every distance",
    body: "From your first 5K to your next marathon PR, for beginners and experienced runners alike.",
  },
];

const principles = [
  ["80/20 training", "Mostly easy running with focused quality sessions."],
  ["Progressive build", "Gradual volume increases with regular cutback weeks."],
  ["Smart taper", "Arrive at the start line fresh and sharp."],
  ["Personal paces", "Every workout at the effort that's right for you."],
];

const faqs = [
  {
    q: "Who is Kiki for?",
    a: "Anyone training for a race, from a first 5K to a marathon. Kiki adjusts the plan to your experience, current volume and schedule.",
  },
  {
    q: "How is the plan created?",
    a: "Kiki uses AI guided by proven training principles (easy-hard balance, progressive build, cutback weeks and tapering) to create a plan from your answers. Every plan is checked against safety rules like gradual weekly increases.",
  },
  {
    q: "Can I change my plan?",
    a: "Anytime. Move a workout to another day, skip one, or tell Kiki you're tired, busy or sore, and your upcoming workouts adapt.",
  },
  {
    q: "Do I have to track runs with Kiki?",
    a: "No. You can record runs with GPS in Kiki, or just mark a workout done and add your distance, time and how it felt.",
  },
  {
    q: "How much does it cost?",
    a: `Kiki is ${site.pricing.monthly}/month or ${site.pricing.yearly}/year, both with a ${site.pricing.trialDays}-day free trial. We'll remind you before your trial ends, and you can cancel anytime in your Apple ID settings.`,
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
      <section className="mx-auto grid max-w-6xl items-center gap-16 px-5 pb-24 pt-16 md:grid-cols-[1.1fr_1fr] md:pt-24">
        <div>
          <p className="mb-6 inline-flex rounded-full border border-line px-3.5 py-1.5 text-sm font-medium text-muted">
            5K · 10K · Half · Marathon
          </p>
          <h1 className="text-balance text-6xl font-black italic leading-[0.95] tracking-[-0.04em] sm:text-7xl lg:text-8xl">
            Your AI running coach.
          </h1>
          <p className="mt-7 max-w-md text-pretty text-xl leading-relaxed text-muted">
            A training plan built around your race, your schedule and your body, and it adapts
            every time life happens.
          </p>
          <div className="mt-10 flex flex-wrap items-center gap-4">
            <DownloadButton />
            <p className="text-sm text-subtle">
              {site.pricing.trialDays}-day free trial
            </p>
          </div>
        </div>
        <PhoneMockup />
      </section>

      {/* How it works */}
      <section id="how" className="scroll-mt-20 border-t border-line bg-wash">
        <div className="mx-auto max-w-6xl px-5 py-24">
          <h2 className="max-w-xl text-4xl font-bold tracking-tight sm:text-5xl">
            From sign-up to start line.
          </h2>
          <ol className="mt-14 grid gap-5 md:grid-cols-3">
            {steps.map((step, i) => (
              <li key={step.title} className="rounded-3xl bg-paper p-8">
                <span className="text-5xl font-black italic text-ink/15">{i + 1}</span>
                <h3 className="mt-6 text-xl font-semibold">{step.title}</h3>
                <p className="mt-2 leading-relaxed text-muted">{step.body}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* Adapts */}
      <section className="mx-auto grid max-w-6xl items-center gap-14 px-5 py-24 md:grid-cols-2">
        <div>
          <h2 className="text-4xl font-bold tracking-tight sm:text-5xl">
            Life happens. Your plan keeps up.
          </h2>
          <p className="mt-6 max-w-md text-lg leading-relaxed text-muted">
            Real training rarely goes to plan. Kiki rebalances your upcoming workouts so you stay
            consistent without overdoing it.
          </p>
        </div>
        <div className="space-y-3" aria-label="Example conversation with Kiki">
          <div className="ml-auto w-fit max-w-[85%] rounded-3xl rounded-br-lg bg-wash px-5 py-3.5 text-[17px]">
            I&apos;m wiped out this week. Work has been brutal.
          </div>
          <div className="w-fit max-w-[85%] rounded-3xl rounded-bl-lg bg-ink px-5 py-3.5 text-[17px] leading-relaxed text-paper">
            Got it. I swapped Thursday&apos;s intervals for an easy run and trimmed Saturday&apos;s
            long run by two miles. We&apos;ll pick the intensity back up next week.
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
      </section>

      {/* Features */}
      <section className="border-t border-line">
        <div className="mx-auto max-w-6xl px-5 py-24">
          <h2 className="max-w-xl text-4xl font-bold tracking-tight sm:text-5xl">
            Everything you need. Nothing you don&apos;t.
          </h2>
          <div className="mt-14 grid gap-x-10 gap-y-12 sm:grid-cols-2 lg:grid-cols-3">
            {features.map((f) => (
              <div key={f.title}>
                <h3 className="text-lg font-semibold">{f.title}</h3>
                <p className="mt-2 leading-relaxed text-muted">{f.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Principles */}
      <section className="bg-ink text-paper">
        <div className="mx-auto max-w-6xl px-5 py-24">
          <h2 className="max-w-2xl text-4xl font-bold tracking-tight sm:text-5xl">
            Personal plans. Proven principles.
          </h2>
          <p className="mt-6 max-w-xl text-lg leading-relaxed text-white/65">
            Every Kiki plan follows the same fundamentals elite coaches use, tailored to where you
            are today.
          </p>
          <div className="mt-14 grid gap-px overflow-hidden rounded-3xl bg-white/10 sm:grid-cols-2 lg:grid-cols-4">
            {principles.map(([title, body]) => (
              <div key={title} className="bg-ink p-8">
                <h3 className="text-xl font-bold italic">{title}</h3>
                <p className="mt-2 leading-relaxed text-white/65">{body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section id="pricing" className="scroll-mt-20 mx-auto max-w-6xl px-5 py-24">
        <h2 className="text-center text-4xl font-bold tracking-tight sm:text-5xl">Simple pricing.</h2>
        <p className="mt-4 text-center text-lg text-muted">
          Start with a {site.pricing.trialDays}-day free trial. Cancel anytime.
        </p>
        <div className="mx-auto mt-14 grid max-w-3xl gap-5 sm:grid-cols-2">
          <div className="relative rounded-3xl border-2 border-ink p-8">
            <span className="absolute -top-3.5 left-8 rounded-full bg-ink px-3 py-1 text-xs font-semibold text-paper">
              Best value
            </span>
            <h3 className="text-lg font-semibold">Yearly</h3>
            <p className="mt-4 text-5xl font-black italic tracking-tight">{site.pricing.yearly}</p>
            <p className="mt-2 text-muted">per year · just {site.pricing.yearlyPerMonth}/month</p>
          </div>
          <div className="rounded-3xl border border-line p-8">
            <h3 className="text-lg font-semibold">Monthly</h3>
            <p className="mt-4 text-5xl font-black italic tracking-tight">{site.pricing.monthly}</p>
            <p className="mt-2 text-muted">per month</p>
          </div>
        </div>
        <div className="mt-12 flex justify-center">
          <DownloadButton />
        </div>
      </section>

      {/* FAQ */}
      <section id="faq" className="scroll-mt-20 border-t border-line bg-wash">
        <div className="mx-auto max-w-3xl px-5 py-24">
          <h2 className="text-4xl font-bold tracking-tight sm:text-5xl">Questions</h2>
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
      <section className="mx-auto max-w-6xl px-5 py-28 text-center">
        <h2 className="mx-auto max-w-3xl text-balance text-5xl font-black italic leading-[0.95] tracking-[-0.03em] sm:text-7xl">
          Your best race starts today.
        </h2>
        <div className="mt-10 flex justify-center">
          <DownloadButton />
        </div>
      </section>
    </>
  );
}
