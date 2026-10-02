/**
 * Running guides for kikirunning.com/guides. Each one leads with a short,
 * direct answer, then practical detail. Keep them accurate, plain and
 * jargon-free, like the app's voice.
 */

export type Block =
  | { type: "p"; text: string }
  | { type: "h2"; text: string }
  | { type: "ul"; items: string[] }
  | { type: "ol"; items: string[] }
  | { type: "table"; caption?: string; head: string[]; rows: string[][] }
  | { type: "tip"; text: string };

export type Guide = {
  slug: string;
  title: string;
  /** Search result title, if different from the page title. */
  seoTitle?: string;
  description: string;
  /** The direct answer at the top of the page. */
  answer: string;
  category: "Getting started" | "Race training" | "Training basics" | "Kiki";
  minutes: number;
  updated: string;
  blocks: Block[];
  faqs: { q: string; a: string }[];
};

const updated = "2026-10-02";

export const guides: Guide[] = [
  {
    slug: "how-to-start-running",
    title: "How to start running: a beginner's guide",
    seoTitle: "How to Start Running: A Simple Beginner's Guide",
    description:
      "How to start running from zero: run/walk intervals, how fast to go, how often to run, and how to build to 30 minutes without stopping.",
    answer:
      "Start with run/walk intervals three times a week, such as 1 minute of easy running and 90 seconds of walking, repeated for 20 to 30 minutes. Keep the pace conversational, rest between runs, and add a little more running each week. Most beginners can run 30 minutes non-stop within 8 to 10 weeks.",
    category: "Getting started",
    minutes: 6,
    updated,
    blocks: [
      { type: "h2", text: "What you need" },
      {
        type: "p",
        text: "Less than you think. A pair of comfortable running shoes, clothes you can move in, and 30 minutes three times a week. Fancy watches and gels can wait.",
      },
      {
        type: "ul",
        items: [
          "Shoes that feel comfortable from the first step, with about a thumb's width of space past your longest toe.",
          "A safe route: a park loop, a track or quiet streets.",
          "A plan, so you know what to do each day instead of guessing.",
        ],
      },
      { type: "h2", text: "Your first week" },
      {
        type: "p",
        text: "Begin every session with 5 minutes of brisk walking. Then alternate 1 minute of easy running with 90 seconds of walking, eight times. Finish with a few minutes of walking. That's it. Do this three times in the week, with a rest day between sessions.",
      },
      {
        type: "tip",
        text: "Walk breaks aren't cheating. They let you run more in total, with less strain, and they're how most beginners build up safely.",
      },
      { type: "h2", text: "How fast should you run?" },
      {
        type: "p",
        text: "Slower than you think. Use the talk test: you should be able to speak in full sentences while you run. If you can only get out a few words, slow down or walk. Speed comes later. Early on, the goal is simply to finish each session feeling like you could have done a bit more.",
      },
      { type: "h2", text: "How often to run" },
      {
        type: "p",
        text: "Three runs a week is the sweet spot for most beginners. Your muscles, tendons and bones adapt during the rest days, not during the run itself, so rest days are part of training.",
      },
      { type: "h2", text: "How to progress" },
      {
        type: "p",
        text: "Each week, run a little more and walk a little less. A typical progression goes from 1-minute running intervals to 3, then 5, then 8, until you can run 20 to 30 minutes without stopping. If a week feels hard, repeat it. There's no prize for rushing.",
      },
      {
        type: "table",
        caption: "A simple progression (three sessions a week)",
        head: ["Weeks", "Running", "Walking", "Repeats"],
        rows: [
          ["1–2", "1–2 min", "90 sec", "6–8"],
          ["3–4", "3–5 min", "90 sec–2 min", "3–5"],
          ["5–6", "8–10 min", "2 min", "2–3"],
          ["7–8", "20–30 min", "None", "1"],
        ],
      },
      { type: "h2", text: "Common beginner mistakes" },
      {
        type: "ul",
        items: [
          "Running too fast. It makes every run feel hard and raises your injury risk.",
          "Doing too much too soon. Adding a lot of running in one week is the most common path to shin pain and sore knees.",
          "Skipping rest days. Back-to-back hard days leave you tired, not fitter.",
          "Quitting after one bad run. Everyone has them. The next one is usually better.",
        ],
      },
      { type: "h2", text: "Before you start" },
      {
        type: "p",
        text: "If you have a heart condition, a recent injury, are pregnant, or haven't exercised in a long time, check with a doctor first. Mild muscle soreness is normal in the first weeks. Sharp pain, or pain that gets worse as you run, is a sign to stop and rest.",
      },
    ],
    faqs: [
      {
        q: "How long does it take a beginner to run 5K?",
        a: "Most beginners can run 5K (3.1 miles) without stopping within 8 to 10 weeks, running three times a week with run/walk intervals that gradually become continuous running.",
      },
      {
        q: "Is it okay to walk during a run?",
        a: "Yes. Planned walk breaks help beginners run more in total with less strain. Many experienced runners use them in long runs and marathons too.",
      },
      {
        q: "Should I run every day as a beginner?",
        a: "No. Three runs a week with rest days in between is enough to improve steadily. Rest days are when your body adapts and gets stronger.",
      },
    ],
  },
  {
    slug: "couch-to-5k",
    title: "Couch to 5K: an 8-week plan for total beginners",
    seoTitle: "Couch to 5K Plan: 8 Weeks From Zero to 5K",
    description:
      "A simple 8-week couch to 5K plan with run/walk intervals, three sessions a week. What to do each week, how fast to go, and what to do if a week feels too hard.",
    answer:
      "A couch to 5K plan takes you from no running to running 5K (3.1 miles) in about 8 weeks. You run three times a week, starting with short run/walk intervals and gradually running longer with fewer walk breaks, until you can run 25 to 30 minutes without stopping.",
    category: "Getting started",
    minutes: 5,
    updated,
    blocks: [
      { type: "h2", text: "How the plan works" },
      {
        type: "p",
        text: "Every session starts with a 5-minute brisk walk and ends with a few minutes of easy walking. In between, you alternate easy running and walking. Each week the running gets a little longer. Run on three non-consecutive days, such as Tuesday, Thursday and Saturday.",
      },
      {
        type: "table",
        caption: "The 8-week couch to 5K plan (each session, three times a week)",
        head: ["Week", "Session"],
        rows: [
          ["1", "Run 1 min, walk 90 sec. Repeat 8 times."],
          ["2", "Run 2 min, walk 90 sec. Repeat 6 times."],
          ["3", "Run 3 min, walk 90 sec. Repeat 5 times."],
          ["4", "Run 5 min, walk 2 min. Repeat 3 times."],
          ["5", "Run 8 min, walk 2 min. Repeat 3 times."],
          ["6", "Run 10 min, walk 2 min, run 10 min."],
          ["7", "Run 20 to 25 min without stopping."],
          ["8", "Run 25 to 30 min without stopping. Try your first 5K."],
        ],
      },
      { type: "h2", text: "How fast to run" },
      {
        type: "p",
        text: "Easy. You should be able to talk in full sentences. A 5K takes most beginners 30 to 40 minutes, and that's a great result. Finishing comfortably matters far more than your pace.",
      },
      { type: "h2", text: "If a week feels too hard" },
      {
        type: "p",
        text: "Repeat it. Plenty of people take 10 or 12 weeks, and they still get there. If you miss a few days, pick up where you left off, or go back a week. Don't try to make up missed sessions by doubling up.",
      },
      {
        type: "tip",
        text: "Couch to 5K plans are a template. A plan that adapts to how your runs actually go, like Kiki's, can slow down or speed up the progression for you.",
      },
      { type: "h2", text: "Your first 5K race" },
      {
        type: "p",
        text: "Pick a local 5K a week or two after you finish the plan. On the day, start slower than feels natural, walk through water stations if you like, and enjoy it. The atmosphere tends to carry you.",
      },
    ],
    faqs: [
      {
        q: "Can a complete beginner do couch to 5K?",
        a: "Yes. It's designed for people who don't run at all. The first week is mostly walking with one-minute running intervals.",
      },
      {
        q: "What if I can't run for the full interval?",
        a: "Slow down. If it's still too hard, walk and repeat the previous week. Most people who struggle are running too fast, not too far.",
      },
      {
        q: "How far is a 5K?",
        a: "5 kilometers, or about 3.1 miles.",
      },
    ],
  },
  {
    slug: "half-marathon-training-plan",
    title: "Half marathon training: a simple 12-week guide",
    seoTitle: "Half Marathon Training Plan: A Simple 12-Week Guide",
    description:
      "How to train for a half marathon in 12 weeks: how many runs a week, how long your long run should get, what easy pace means, and how to taper before race day.",
    answer:
      "Most runners train for a half marathon (13.1 miles or 21.1 km) in 10 to 16 weeks. Run three or four times a week, keep most runs easy, and build one weekly long run to about 10 to 12 miles (16 to 19 km). Ease off for the final week or two so you start the race fresh.",
    category: "Race training",
    minutes: 6,
    updated,
    blocks: [
      { type: "h2", text: "Before you start" },
      {
        type: "p",
        text: "A 12-week plan works best if you can already run about 3 miles (5 km) comfortably and run three times a week. If you're starting from zero, build up to that first. A couch to 5K plan is a good way in.",
      },
      { type: "h2", text: "What a training week looks like" },
      {
        type: "table",
        caption: "A typical week",
        head: ["Day", "First half marathon", "Chasing a time"],
        rows: [
          ["Mon", "Rest", "Easy run"],
          ["Tue", "Easy run", "Intervals or tempo run"],
          ["Wed", "Rest", "Rest"],
          ["Thu", "Easy run", "Easy run"],
          ["Fri", "Rest", "Rest"],
          ["Sat", "Long run", "Long run"],
          ["Sun", "Easy run or rest", "Easy run"],
        ],
      },
      { type: "h2", text: "The long run" },
      {
        type: "p",
        text: "Your weekly long run is the key workout. It builds the endurance to go the distance. Start a little longer than your usual run and add about a mile (1 to 2 km) most weeks, with an easier week every three or four weeks. Run it at an easy, chatty pace.",
      },
      {
        type: "table",
        caption: "Sample long-run progression",
        head: ["Week", "Long run", "Week", "Long run"],
        rows: [
          ["1", "4 mi (6 km)", "7", "8 mi (13 km)"],
          ["2", "5 mi (8 km)", "8", "9 mi (14.5 km)"],
          ["3", "6 mi (10 km)", "9", "10 mi (16 km)"],
          ["4", "5 mi (8 km)", "10", "11 mi (18 km)"],
          ["5", "7 mi (11 km)", "11", "8 mi (13 km)"],
          ["6", "6 mi (10 km)", "12", "Race: 13.1 mi"],
        ],
      },
      { type: "h2", text: "Easy runs and faster sessions" },
      {
        type: "p",
        text: "Most of your running should be easy enough to talk in full sentences. If you're running your first half, that's all you need. If you're chasing a time, add one faster session a week: a tempo run (a steady, comfortably hard effort) or intervals (short, fast repeats with easy jogging between).",
      },
      { type: "h2", text: "Fueling and race-day practice" },
      {
        type: "p",
        text: "For runs longer than about 75 minutes, practice taking water and a little carbohydrate, such as an energy gel or sports drink. Use your long runs to test breakfast, shoes and kit. The golden rule: nothing new on race day.",
      },
      { type: "h2", text: "Tapering" },
      {
        type: "p",
        text: "In the last week or two, run less but keep a little faster running in. You might feel restless. That's normal. The fitness is already built; the taper lets your legs recover so you can use it.",
      },
      { type: "h2", text: "Race-day pacing" },
      {
        type: "p",
        text: "Start slower than your goal pace for the first few miles. If you feel good after halfway, pick it up gradually. A strong finish feels far better than hanging on.",
      },
    ],
    faqs: [
      {
        q: "How many weeks do I need to train for a half marathon?",
        a: "Most plans run 10 to 16 weeks. Twelve weeks suits runners who can already run about 3 miles (5 km) comfortably.",
      },
      {
        q: "How long should my longest run be before a half marathon?",
        a: "Most runners peak at 10 to 12 miles (16 to 19 km) two or three weeks before the race. You don't need to run the full 13.1 miles in training.",
      },
      {
        q: "How many days a week should I run?",
        a: "Three or four. First-time half marathoners do well on three runs a week; runners chasing a time often run four or five.",
      },
    ],
  },
  {
    slug: "marathon-training-for-beginners",
    title: "Marathon training for beginners: what 16 to 20 weeks looks like",
    seoTitle: "Marathon Training for Beginners: A 16–20 Week Guide",
    description:
      "How beginners train for a marathon: how long it takes, how far the long run goes, how to fuel, how to taper, and how to pace race day.",
    answer:
      "Beginners usually train for a marathon (26.2 miles or 42.2 km) over 16 to 20 weeks. Build a base first, run mostly easy, and grow one weekly long run to about 18 to 20 miles (29 to 32 km) roughly three weeks before race day. Practice fueling on long runs, then taper for two to three weeks.",
    category: "Race training",
    minutes: 7,
    updated,
    blocks: [
      { type: "h2", text: "Are you ready to start?" },
      {
        type: "p",
        text: "A beginner marathon plan works best if you're already running about 15 to 20 miles (25 to 30 km) a week and can run 6 miles (10 km) comfortably. Many coaches suggest running a half marathon first. If you're not there yet, spend a couple of months building a base before you start the plan.",
      },
      { type: "h2", text: "The shape of a marathon plan" },
      {
        type: "table",
        caption: "How the weeks are usually organized",
        head: ["Phase", "Roughly", "What it's for"],
        rows: [
          ["Base", "Weeks 1–5", "Consistent easy running, a long run that grows slowly."],
          ["Build", "Weeks 6–11", "More distance, longer long runs, some steady or faster running."],
          ["Peak", "Weeks 12–15", "Your biggest weeks and longest runs, up to 18–20 miles."],
          ["Taper", "Last 2–3 weeks", "Less running so you arrive fresh."],
        ],
      },
      { type: "h2", text: "The long run" },
      {
        type: "p",
        text: "The long run is the heart of marathon training. Run it slowly, at a pace where you could chat, and take walk breaks if they help. It builds endurance and gives you a dress rehearsal for race day: the same breakfast, shoes, kit and fueling.",
      },
      { type: "h2", text: "Keep most running easy" },
      {
        type: "p",
        text: "Research on endurance athletes, notably by sports scientist Stephen Seiler, found that they do roughly 80% of their training at a low intensity. Easy running builds your aerobic engine with less wear and tear, which matters most in a long marathon build.",
      },
      { type: "h2", text: "Fueling" },
      {
        type: "p",
        text: "Your body can only store enough carbohydrate for a couple of hours of hard running. Sports nutrition guidance commonly suggests about 30 to 60 grams of carbohydrate per hour for longer events, from gels, chews or sports drink. Practice on every long run so your stomach is used to it.",
      },
      { type: "h2", text: "Tapering" },
      {
        type: "p",
        text: "Cut your running back for the final two to three weeks while keeping a few short, faster efforts. Sleep well and eat normally. It's common to feel sluggish during the taper; trust it.",
      },
      { type: "h2", text: "Race-day pacing" },
      {
        type: "ul",
        items: [
          "Start slower than your goal pace. The first miles should feel easy.",
          "Fuel early and often, before you feel you need it.",
          "Walk through water stations if it helps you drink.",
          "Save your effort for the last 10K. That's where the race really begins.",
        ],
      },
      {
        type: "tip",
        text: "Life will interrupt your training. A missed week or a cold won't ruin your marathon. What matters is adjusting sensibly instead of cramming. Kiki rebalances your upcoming weeks when that happens.",
      },
    ],
    faqs: [
      {
        q: "How long does it take a beginner to train for a marathon?",
        a: "Usually 16 to 20 weeks, assuming you can already run about 6 miles (10 km) comfortably. Newer runners should build a base first.",
      },
      {
        q: "Do I need to run 26.2 miles before the marathon?",
        a: "No. Most plans peak at 18 to 20 miles (29 to 32 km). The taper and race-day atmosphere carry you the rest of the way.",
      },
      {
        q: "Can I walk during a marathon?",
        a: "Yes. Many first-time marathoners use planned walk breaks, and plenty finish faster that way than by running until they're forced to walk.",
      },
    ],
  },
  {
    slug: "easy-run-pace",
    title: "What is an easy run? How to find your easy pace",
    seoTitle: "Easy Run Pace: What It Is and How to Find Yours",
    description:
      "What an easy run is, how slow your easy pace should be, the talk test, heart rate zones, and why easy running makes you faster.",
    answer:
      "An easy run is run at a comfortable, conversational effort: you can speak in full sentences, and it feels about 3 or 4 out of 10. For most runners that's 1 to 2 minutes per mile (about 40 to 75 seconds per kilometer) slower than their 5K race pace. Most of your weekly running should be easy.",
    category: "Training basics",
    minutes: 5,
    updated,
    blocks: [
      { type: "h2", text: "Why easy running matters" },
      {
        type: "p",
        text: "Easy running builds your heart, lungs and the small blood vessels that feed your muscles, with little stress on your body. That lets you run more often, recover faster and stay healthy. Research on endurance athletes, notably by Stephen Seiler, found they spend roughly 80% of their training at low intensity. Most recreational runners do the opposite and run every run moderately hard.",
      },
      { type: "h2", text: "Three ways to find your easy pace" },
      {
        type: "ol",
        items: [
          "The talk test: if you can speak in full sentences, you're easy. If you can only say a few words, slow down.",
          "Effort: about 3 to 4 out of 10. It should feel like you could keep going for a long time.",
          "Heart rate: roughly 60 to 70% of your maximum heart rate, often called zone 2. Wrist heart rate can be noisy, so use it as a guide, not a rule.",
        ],
      },
      {
        type: "table",
        caption: "Easy pace from your recent 5K time (approximate)",
        head: ["5K time", "5K pace", "Easy pace"],
        rows: [
          ["22:00", "7:05 /mi (4:24 /km)", "8:05–9:05 /mi (5:01–5:39 /km)"],
          ["26:00", "8:22 /mi (5:12 /km)", "9:22–10:22 /mi (5:49–6:27 /km)"],
          ["30:00", "9:39 /mi (6:00 /km)", "10:39–11:39 /mi (6:37–7:15 /km)"],
          ["35:00", "11:16 /mi (7:00 /km)", "12:16–13:16 /mi (7:37–8:15 /km)"],
        ],
      },
      { type: "h2", text: "Easy pace changes day to day" },
      {
        type: "p",
        text: "Heat, hills, wind, poor sleep and stress all make the same pace feel harder. On those days, go by effort and let the pace slow. An easy run that feels easy is doing its job, whatever the watch says.",
      },
      { type: "h2", text: "Common questions about slow running" },
      {
        type: "p",
        text: "Slowing down feels wrong at first. Many runners find they have to add walk breaks to keep their effort easy, and that's fine. Within a few weeks, the same easy effort usually gets faster, which is a sign your aerobic fitness is improving.",
      },
    ],
    faqs: [
      {
        q: "How slow should an easy run be?",
        a: "Slow enough to talk in full sentences. For most runners that's 1 to 2 minutes per mile slower than 5K race pace.",
      },
      {
        q: "Is zone 2 the same as an easy run?",
        a: "Roughly. Zone 2 usually means about 60 to 70% of maximum heart rate, which lines up with a conversational, easy effort for most people.",
      },
      {
        q: "Can I walk during an easy run?",
        a: "Yes. If walking keeps your effort easy, walk. It's especially helpful for newer runners and on hills or hot days.",
      },
    ],
  },
  {
    slug: "ai-running-coach",
    title: "What is an AI running coach?",
    seoTitle: "What Is an AI Running Coach? How It Works and Who It's For",
    description:
      "What an AI running coach is, how it builds and adapts a training plan, how it compares with a static plan or a human coach, and who it suits best.",
    answer:
      "An AI running coach is an app that builds a personal training plan from your goal, fitness and schedule, then adjusts it as your training goes, for example when you miss a run, feel tired or something hurts. It sits between a fixed training plan, which never changes, and a human coach, which costs far more.",
    category: "Kiki",
    minutes: 5,
    updated,
    blocks: [
      { type: "h2", text: "How an AI running coach works" },
      {
        type: "ol",
        items: [
          "You share your goal (a first 5K, a marathon, a faster time or simply staying fit), your current running, which days you can train and how you like to be coached.",
          "It builds a day-by-day plan around those answers: easy runs, a weekly long run and, for experienced runners, faster sessions, with lighter weeks before race day.",
          "As you train, you log runs or sync them, and tell the coach how things are going. It adjusts the upcoming days so the plan stays realistic.",
        ],
      },
      { type: "h2", text: "AI coach vs static plan vs human coach" },
      {
        type: "table",
        head: ["", "Static plan", "AI running coach", "Human coach"],
        rows: [
          ["Built for you", "No, one size fits all", "Yes", "Yes"],
          ["Adapts when life happens", "No", "Yes, in seconds", "Yes, when they reply"],
          ["Available anytime", "Yes", "Yes", "Depends"],
          ["Watches your form in person", "No", "No", "Sometimes"],
          ["Typical cost", "Free to low", "Low monthly subscription", "Often $100+ a month"],
        ],
      },
      { type: "h2", text: "Who it's best for" },
      {
        type: "ul",
        items: [
          "Beginners who want clear, safe steps instead of guessing.",
          "Runners training for a race who need their plan to bend around work, travel and family.",
          "Experienced runners who want structure without paying for one-to-one coaching.",
        ],
      },
      { type: "h2", text: "What to look for" },
      {
        type: "ul",
        items: [
          "Plans that start from your actual fitness, not a template.",
          "Mostly easy running with gradual increases, which is how good coaches keep runners healthy.",
          "Easy ways to adjust a single day or the whole plan.",
          "Clear workouts with a simple target pace, not walls of jargon.",
          "A sensible stance on pain: rest first, and see a professional if it persists.",
        ],
      },
      { type: "h2", text: "How Kiki does it" },
      {
        type: "p",
        text: "Kiki asks a few questions, including your weekly distance and longest recent run if you already run, then builds your full plan in seconds. Each day shows one clear workout with a target pace. Tap Adjust when you're tired, short on time or sore, and Kiki makes targeted changes to the next few days, explaining what it changed. Record runs with GPS in the app, or sync them from Apple Health, Apple Watch and apps like Strava and Garmin Connect that save to Health.",
      },
    ],
    faqs: [
      {
        q: "Is an AI running coach safe for beginners?",
        a: "A good one is. Look for plans that keep most running easy, build gradually and ease off when you report pain. It's a training tool, not medical advice, so see a professional for injuries.",
      },
      {
        q: "Can an AI running coach replace a human coach?",
        a: "For many recreational runners, yes: it handles planning and adjustments well. A human coach still adds in-person form feedback and accountability some runners value.",
      },
      {
        q: "Does Kiki work with Apple Watch and Strava?",
        a: "Kiki reads runs from Apple Health. Runs recorded on Apple Watch, or in apps that save to Apple Health such as Strava and Garmin Connect, can check off your planned runs automatically.",
      },
    ],
  },
];

export function guide(slug: string) {
  return guides.find((g) => g.slug === slug);
}

/** "October 2, 2026" */
export function formatDate(iso: string) {
  return new Date(`${iso}T12:00:00Z`).toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" });
}
