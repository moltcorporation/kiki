import Link from "next/link";
import { PhoneShot, WelcomePhone } from "@/components/phone";
import { DownloadCTA } from "@/components/site";
import { guides } from "@/lib/guides";
import { site } from "@/lib/site";

const goals = ["Your first run", "First 5K", "10K", "Half marathon", "Marathon", "A faster time", "Staying fit"];

const steps = [
  {
    title: "Tell Kiki about you",
    body: "Your goal, your race date, how much you run now and which days you're free. A couple of minutes, mostly taps.",
  },
  {
    title: "Get your plan in seconds",
    body: "Every day of your training, built around you. Easy runs, a weekly long run and, when you're ready, faster sessions.",
  },
  {
    title: "Run. Kiki adapts.",
    body: "Log runs or sync them from Apple Health. Tired, busy or sore? Tell Kiki and the next few days adjust.",
  },
];

const principles = [
  ["Mostly easy", "Most runs are conversational, so you build fitness without burning out."],
  ["Built gradually", "Small steps up each week, and lighter weeks to absorb the work."],
  ["Your level", "Beginners get run/walk and easy miles. Tempo runs and intervals come when you're ready."],
  ["Arrive fresh", "Your final weeks ease off so you start race day strong."],
];

const faqs = [
  {
    q: "What is Kiki?",
    a: "Kiki is an AI running coach for iPhone. It builds a personal running plan from your goal, your current fitness and your schedule, then adjusts it as you train, like a real coach would.",
  },
  {
    q: "Who is Kiki for?",
    a: "Anyone who wants to run: complete beginners building up to 30 minutes, runners training for a 5K, 10K, half marathon or marathon, and experienced runners chasing a faster time or simply staying consistent.",
  },
  {
    q: "How does Kiki build my plan?",
    a: "Kiki's coach starts from where you are today, including your weekly distance and longest recent run if you already run. It plans easy runs, a weekly long run and, for experienced runners, tempo runs and intervals, with lighter weeks before your goal. Every workout has one clear target pace.",
  },
  {
    q: "Can I change my plan?",
    a: "Anytime. Adjust a single day (tired, too hard, can't make it, something hurts) or the whole plan (make it easier, push me harder, my schedule changed), or just tell Kiki in your own words. Kiki makes targeted changes and tells you what changed.",
  },
  {
    q: "Does Kiki work with Apple Watch, Strava or Garmin?",
    a: "Kiki connects to Apple Health. Runs from Apple Watch, and from apps that save to Apple Health such as Strava and Garmin Connect, check off your planned runs automatically. You can also record runs with GPS in Kiki, with a Live Activity on your Lock Screen.",
  },
  {
    q: "Is Kiki available on Android?",
    a: "Not right now. Kiki is made for iPhone and available on the App Store.",
  },
  {
    q: "Is Kiki medical advice?",
    a: "No. Kiki is a training tool. If you have pain, an injury or a health condition, check with a qualified professional before training.",
  },
];

function Feature({
  id,
  eyebrow,
  title,
  body,
  points,
  shot,
  reverse = false,
}: {
  id?: string;
  eyebrow: string;
  title: string;
  body: string;
  points: string[];
  shot: React.ReactNode;
  reverse?: boolean;
}) {
  return (
    <section id={id} className="scroll-mt-20 border-t border-line">
      <div className="mx-auto grid max-w-6xl items-center gap-14 px-5 py-24 md:grid-cols-2 md:gap-20 md:py-32">
        <div className={`flex justify-center ${reverse ? "md:order-2" : ""}`}>{shot}</div>
        <div>
          <p className="text-sm font-semibold text-subtle">{eyebrow}</p>
          <h2 className="mt-3 text-balance text-4xl font-black italic leading-[0.98] tracking-[-0.03em] sm:text-[56px]">
            {title}
          </h2>
          <p className="mt-6 max-w-md text-pretty text-lg leading-relaxed text-muted">{body}</p>
          <ul className="mt-8 space-y-4">
            {points.map((point) => (
              <li key={point} className="flex gap-3 text-[17px] leading-snug">
                <span aria-hidden className="mt-[7px] size-2 shrink-0 rounded-full bg-[#CEFF00]" />
                <span className="text-ink/90">{point}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}

export default function Home() {
  const jsonLd = [
    {
      "@context": "https://schema.org",
      "@type": "MobileApplication",
      name: site.name,
      description: site.description,
      operatingSystem: "iOS",
      applicationCategory: "HealthApplication",
      url: site.url,
      installUrl: site.appStoreUrl,
      publisher: { "@type": "Organization", name: site.company },
    },
    {
      "@context": "https://schema.org",
      "@type": "Organization",
      name: site.name,
      legalName: site.company,
      url: site.url,
      logo: `${site.url}/kiki-icon.png`,
      email: site.supportEmail,
    },
    {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      mainEntity: faqs.map((f) => ({ "@type": "Question", name: f.q, acceptedAnswer: { "@type": "Answer", text: f.a } })),
    },
  ];

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />

      {/* Hero */}
      <section className="asphalt -mt-16 overflow-hidden pt-16">
        <div className="mx-auto grid max-w-6xl items-center gap-16 px-5 pb-24 pt-14 md:grid-cols-[1.1fr_1fr] md:pb-32 md:pt-24">
          <div className="min-w-0">
            <p className="mb-6 inline-flex items-center gap-2 rounded-full border border-line bg-white/[0.04] px-3.5 py-1.5 text-sm font-medium text-muted">
              <span aria-hidden className="size-1.5 rounded-full bg-[#CEFF00]" />
              Made for iPhone
            </p>
            <h1 className="text-balance text-[clamp(3rem,13vw,4rem)] font-black italic leading-[0.9] tracking-[-0.045em] sm:text-7xl lg:text-[104px]">
              Your AI running coach.
            </h1>
            <p className="mt-8 max-w-lg text-pretty text-xl leading-relaxed text-muted">
              A running plan built around your goal, your schedule and where you are today. When
              life happens, Kiki adapts it, just like a real coach.
            </p>
            <div className="mt-10">
              <DownloadCTA />
            </div>
          </div>
          <div className="relative mx-auto h-[600px] w-full max-w-[300px] sm:h-[650px] lg:max-w-[500px]">
            <div className="absolute left-1/2 top-0 z-10 -translate-x-1/2 -rotate-3 lg:left-0 lg:translate-x-0">
              <WelcomePhone />
            </div>
            <div className="absolute right-0 top-16 hidden rotate-[4deg] lg:block">
              <PhoneShot
                src="/screens/home.png"
                alt="Kiki's Home screen: Good morning, Sam, with the Chicago Marathon goal card, 9 days to go"
                priority
              />
            </div>
          </div>
        </div>
      </section>

      {/* Goals */}
      <section className="border-t border-line">
        <div className="mx-auto max-w-6xl px-5 py-14">
          <p className="text-center text-sm font-semibold text-subtle">Whatever you&apos;re running toward</p>
          <ul className="mt-6 flex flex-wrap justify-center gap-2.5">
            {goals.map((goal) => (
              <li key={goal} className="rounded-full border border-line px-4 py-2 text-[15px] font-medium text-ink/85">
                {goal}
              </li>
            ))}
          </ul>
        </div>
      </section>

      <Feature
        id="features"
        eyebrow="Your plan"
        title="A plan that's actually yours."
        body="Not a template. Kiki starts from what you can run today and builds every week between now and your goal, on the days that suit you."
        points={[
          "Starts where you are, from your first run to your tenth marathon",
          "Only on the days you choose, with your long run where you want it",
          "Builds gradually, then eases off so you arrive fresh",
          "List or calendar view, and share your plan as a PDF",
        ]}
        shot={<PhoneShot src="/screens/plan.png" alt="Kiki's Plan tab: this week's runs for the Chicago Marathon, with completed runs checked off" />}
      />

      <Feature
        eyebrow="Every day"
        title="Know exactly what to run today."
        body="Open Kiki and today's run is right there. Every workout spells out what to do, how far and one clear target pace. No jargon."
        points={[
          "Easy runs, long runs, tempo runs and intervals, matched to your level",
          "Step by step: warm up, the main set, cool down",
          "One target pace per effort, in miles or kilometers",
        ]}
        shot={<PhoneShot src="/screens/workout.png" alt="A Tempo Run in Kiki: 4.0 miles, about 34 minutes, with warm up, tempo and cool down steps" />}
        reverse
      />

      <Feature
        eyebrow="Adapts"
        title="Life happens. Kiki adapts."
        body="Real training never goes exactly to plan. Tell Kiki what's going on and it makes small, targeted changes to the days ahead, then tells you why."
        points={[
          "Adjust a day: tired, too hard, can't make it, something hurts",
          "Adjust the plan: make it easier, push me harder, schedule changed",
          "Or tell Kiki in your own words",
          "Skip a run without derailing the rest of your plan",
        ]}
        shot={<PhoneShot src="/screens/adjust.png" alt="Kiki's Adjust today sheet with options: I'm tired, It's too hard, Can't make it, Something hurts, Skip it" />}
      />

      <Feature
        eyebrow="Run"
        title="Track it. Or just tap done."
        body="Hit the play button to record your run with GPS: distance, pace and time, live on your Lock Screen. Already run with your Apple Watch, Strava or Garmin? Kiki picks it up from Apple Health."
        points={[
          "GPS tracking with a Live Activity and pause from your Lock Screen",
          "Syncs runs from Apple Health, Apple Watch and apps that save to Health",
          "Runs check off your plan automatically, without double counting",
        ]}
        shot={<PhoneShot src="/screens/run.png" alt="Kiki's run tracker recording a run along Chicago's lakefront" />}
        reverse
      />

      <Feature
        eyebrow="Progress"
        title="Watch the miles add up."
        body="Every run you finish fills in your calendar. See how far you've come, your longest run and the days left until your goal."
        points={[
          "A calendar of every run, done and to come",
          "Your total distance and longest run so far",
          "A countdown to race day",
        ]}
        shot={<PhoneShot src="/screens/calendar.png" alt="Kiki's calendar view for September 2026, with every completed run marked" />}
      />

      <Feature
        eyebrow="Learn"
        title="Run smarter, one short read at a time."
        body="Short, practical guides inside the app: running form, breathing, race day, strength and the science of rest. Each one takes two or three minutes."
        points={["Written for real runners, not experts", "Key takeaways at the end of every guide", "From your first run to your first marathon"]}
        shot={<PhoneShot src="/screens/learn.png" alt="Kiki's Learn tab with guides on running basics and running form" />}
        reverse
      />

      {/* How it works */}
      <section id="how" className="asphalt scroll-mt-20 border-t border-line">
        <div className="mx-auto max-w-6xl px-5 py-28">
          <h2 className="max-w-2xl text-4xl font-black italic leading-[0.98] tracking-[-0.03em] sm:text-6xl">
            From first step to finish line.
          </h2>
          <ol className="mt-14 grid gap-4 md:grid-cols-3">
            {steps.map((step, i) => (
              <li key={step.title} className="rounded-3xl border border-line bg-paper/60 p-8 backdrop-blur">
                <span className="text-5xl font-black italic text-ink/20">{i + 1}</span>
                <h3 className="mt-6 text-xl font-semibold">{step.title}</h3>
                <p className="mt-2 leading-relaxed text-muted">{step.body}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* Principles */}
      <section className="border-t border-line">
        <div className="mx-auto max-w-6xl px-5 py-28">
          <h2 className="max-w-2xl text-4xl font-black italic leading-[0.98] tracking-[-0.03em] sm:text-6xl">
            Personal plans. Proven principles.
          </h2>
          <p className="mt-6 max-w-xl text-lg leading-relaxed text-muted">
            Every plan follows the fundamentals great coaches use, tuned to you. Safety first, always.
          </p>
          <div className="mt-14 grid gap-px overflow-hidden rounded-3xl border border-line bg-line sm:grid-cols-2 lg:grid-cols-4">
            {principles.map(([title, body]) => (
              <div key={title} className="bg-paper p-8">
                <h3 className="text-xl font-black italic">{title}</h3>
                <p className="mt-2 leading-relaxed text-muted">{body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Guides */}
      <section className="border-t border-line">
        <div className="mx-auto max-w-6xl px-5 py-28">
          <div className="flex flex-wrap items-end justify-between gap-6">
            <h2 className="max-w-xl text-4xl font-black italic leading-[0.98] tracking-[-0.03em] sm:text-6xl">
              Free running guides.
            </h2>
            <Link href="/guides" className="text-[15px] font-semibold text-ink underline-offset-4 hover:underline">
              All guides →
            </Link>
          </div>
          <div className="mt-12 grid gap-4 md:grid-cols-3">
            {guides.slice(0, 3).map((g) => (
              <Link
                key={g.slug}
                href={`/guides/${g.slug}`}
                className="group rounded-3xl border border-line bg-surface p-8 transition-colors hover:border-ink/25"
              >
                <p className="text-sm font-medium text-subtle">{g.category} · {g.minutes} min read</p>
                <h3 className="mt-4 text-xl font-semibold leading-snug group-hover:underline group-hover:underline-offset-4">{g.title}</h3>
                <p className="mt-3 line-clamp-3 leading-relaxed text-muted">{g.description}</p>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section id="faq" className="scroll-mt-20 border-t border-line">
        <div className="mx-auto max-w-3xl px-5 py-28">
          <h2 className="text-4xl font-black italic tracking-[-0.03em] sm:text-6xl">Questions</h2>
          <div className="mt-10 divide-y divide-line border-y border-line">
            {faqs.map((f) => (
              <details key={f.q} className="group py-6">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-6 text-lg font-semibold">
                  {f.q}
                  <span aria-hidden className="text-2xl font-light text-subtle transition-transform group-open:rotate-45">+</span>
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
          <h2 className="mx-auto max-w-4xl text-balance text-5xl font-black italic leading-[0.92] tracking-[-0.045em] sm:text-8xl">
            Your best run starts today.
          </h2>
          <p className="mx-auto mt-8 max-w-md text-lg text-muted">
            Get your personal plan in a couple of minutes.
          </p>
          <div className="mt-10 flex justify-center">
            <DownloadCTA center />
          </div>
        </div>
      </section>
    </>
  );
}
