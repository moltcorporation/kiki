import Foundation

/// A short guide in the Learn tab. The library is hardcoded below; add or
/// edit articles here. Keep them short, practical and jargon-free.
struct Article: Identifiable, Hashable {
    enum Category: String, CaseIterable, Identifiable {
        case basics, form, races, raceDay, strength, science

        var id: String { rawValue }

        /// Section title on the Learn tab.
        var title: String {
            switch self {
            case .basics: "Running basics"
            case .form: "Running form"
            case .races: "Training for a race"
            case .raceDay: "Race day"
            case .strength: "Strength & mobility"
            case .science: "The science"
            }
        }

        /// Filter chip label.
        var chip: String {
            switch self {
            case .basics: "Basics"
            case .form: "Form"
            case .races: "Races"
            case .raceDay: "Race day"
            case .strength: "Strength"
            case .science: "Science"
            }
        }
    }

    enum Block: Hashable {
        case paragraph(String)
        case heading(String)
        case bullets([String])
    }

    let id: String
    let category: Category
    let title: String
    /// A one-line summary (for previews and sharing).
    let summary: String
    let icon: String
    let minutes: Int
    let body: [Block]
    let takeaways: [String]
}

extension Article {
    static let library: [Article] = [
        // MARK: Running basics
        Article(
            id: "easy-runs", category: .basics,
            title: "Why easy runs should feel easy",
            summary: "Most of your plan is easy running. Here's why slowing down is what makes you faster.",
            icon: "tortoise", minutes: 3,
            body: [
                .paragraph("Most runners run their easy days too fast. It feels productive, but it leaves you tired for the runs that matter and raises your risk of injury."),
                .heading("What easy running does"),
                .paragraph("Easy running builds your heart, lungs and legs with very little wear and tear. It's how you add miles safely, week after week. Elite runners do about 80% of their running at an easy effort."),
                .heading("How easy is easy?"),
                .paragraph("You should be able to talk in full sentences. If you're breathing too hard to chat, slow down, or take a short walk break. There's no shame in a slow pace."),
            ],
            takeaways: ["Easy days should feel easy: you can talk in full sentences.", "Easy running builds fitness with less risk of injury.", "Save your effort for the harder days in your plan."]
        ),
        Article(
            id: "run-walk", category: .basics,
            title: "Run/walk: the smart way to build up",
            summary: "Mixing running and walking builds fitness faster than you'd think.",
            icon: "figure.walk", minutes: 2,
            body: [
                .paragraph("Run/walk isn't cheating. Short walk breaks let your body recover, so you can run longer in total and finish feeling good."),
                .heading("How it works"),
                .paragraph("Run for a set time, walk for a short break, and repeat. Your plan starts with short runs and longer walks, then slowly shifts the balance until you're running the whole way."),
                .paragraph("Take the walk breaks from the start, not only when you're tired. That's what makes them work."),
            ],
            takeaways: ["Walk breaks help you run more, not less.", "Start the breaks early, before you're tired.", "Your plan gradually swaps walking for running."]
        ),
        Article(
            id: "easy-pace", category: .basics,
            title: "How to find your easy pace",
            summary: "Forget the watch for a minute: your breathing is the best guide.",
            icon: "gauge.with.dots.needle.33percent", minutes: 2,
            body: [
                .paragraph("Your easy pace isn't a fixed number. It changes with heat, hills, sleep and stress, so go by feel first."),
                .heading("The talk test"),
                .paragraph("If you can say a full sentence without gasping, you're at an easy pace. If you can only say a few words, slow down."),
                .paragraph("The pace ranges in your plan are a guide. On a hot or tired day, it's fine to run slower than the range."),
            ],
            takeaways: ["Easy pace = you can talk in full sentences.", "It changes day to day, and that's normal.", "When in doubt, go slower."]
        ),
        Article(
            id: "shoes", category: .basics,
            title: "Choosing the right running shoes",
            summary: "Comfort beats everything else when picking a shoe.",
            icon: "shoe", minutes: 2,
            body: [
                .paragraph("The best running shoe is the one that feels comfortable on your feet from the first step. Ignore hype and pick what feels good."),
                .heading("What to look for"),
                .bullets(["About a thumb's width of space past your longest toe.", "A snug heel that doesn't slip.", "No pinching or pressure points when you jog."]),
                .paragraph("Most shoes last around 300 to 500 miles (500 to 800 km). If your legs start aching on easy runs, your shoes may be worn out."),
            ],
            takeaways: ["Choose comfort over looks or hype.", "Leave a thumb's width at the toe.", "Replace shoes every 300–500 miles."]
        ),
        Article(
            id: "how-often", category: .basics,
            title: "How often should you run?",
            summary: "Consistency matters more than any single run.",
            icon: "calendar", minutes: 2,
            body: [
                .paragraph("Three runs a week is a great start for most people. It gives your body time to recover between runs, which is when you actually get fitter."),
                .paragraph("As you get stronger, adding a run or a little more distance helps. Building slowly, week by week, is what keeps you healthy."),
                .paragraph("Rest days are part of the plan, not a break from it."),
            ],
            takeaways: ["Three runs a week is a strong start.", "You get fitter while you rest.", "Build slowly to stay healthy."]
        ),
        Article(
            id: "missed-run", category: .basics,
            title: "Missed a run? Here's what to do",
            summary: "One missed run won't change your fitness. Here's how to get back on track.",
            icon: "arrow.uturn.backward", minutes: 2,
            body: [
                .paragraph("Life happens. Missing a run, or even a few days, won't undo your progress. What matters is the weeks and months of running, not one day."),
                .heading("Don't make it up"),
                .paragraph("Skip it and carry on with your plan. Squeezing two runs together, or adding the missed miles to another day, raises your risk of getting hurt."),
                .paragraph("If you've missed a week or more, tell Kiki with Adjust plan and your plan will ease you back in."),
            ],
            takeaways: ["One missed run doesn't hurt your fitness.", "Don't double up to make up for it.", "Missed a week or more? Use Adjust plan."]
        ),
        Article(
            id: "weather", category: .basics,
            title: "Running in the heat and cold",
            summary: "Adjust your pace and clothes, not your plan.",
            icon: "thermometer.sun", minutes: 2,
            body: [
                .heading("In the heat"),
                .paragraph("Heat makes every pace feel harder. Slow down, run early or late in the day, and drink water before and after. Running by feel matters more than pace on hot days."),
                .heading("In the cold"),
                .paragraph("Dress as if it's 10–15°F (about 5–8°C) warmer than it is; you'll warm up fast. Cover your hands and ears, and warm up indoors with a few minutes of walking if it's very cold."),
            ],
            takeaways: ["Run slower in the heat.", "Dress for 10–15°F warmer in the cold.", "Go by effort, not pace."]
        ),

        // MARK: Running form
        Article(
            id: "form-fixes", category: .form,
            title: "Simple fixes for better running form",
            summary: "Three small changes that make running feel easier.",
            icon: "figure.run", minutes: 2,
            body: [
                .paragraph("There's no single perfect running form. But a few simple cues help most runners feel lighter and more relaxed."),
                .bullets(["Stand tall: imagine a string pulling the top of your head up.", "Relax your shoulders and hands, as if holding a chip you don't want to break.", "Land with your foot under your body, not far out in front."]),
                .paragraph("Pick one cue per run. Trying to fix everything at once makes running feel stiff."),
            ],
            takeaways: ["Run tall and relaxed.", "Land with your foot under your body.", "Focus on one cue at a time."]
        ),
        Article(
            id: "breathing", category: .form,
            title: "How to breathe while running",
            summary: "Breathe through your mouth and nose, and let your body set the rhythm.",
            icon: "wind", minutes: 2,
            body: [
                .paragraph("Breathe through both your nose and mouth. Your muscles need lots of oxygen, and your mouth lets more in."),
                .paragraph("Breathing hard on easy runs is a sign to slow down, not to breathe differently. If you're gasping, take a short walk until your breathing settles."),
                .paragraph("A side stitch usually eases if you slow down, breathe out fully and press gently on the sore spot."),
            ],
            takeaways: ["Breathe through your nose and mouth.", "Gasping on an easy run means slow down.", "For a stitch, slow down and breathe out fully."]
        ),
        Article(
            id: "cadence", category: .form,
            title: "Cadence, made simple",
            summary: "Shorter, quicker steps can make running feel smoother.",
            icon: "metronome", minutes: 2,
            body: [
                .paragraph("Cadence is how many steps you take per minute. Many new runners take long, slow strides that land out in front of the body and feel jarring."),
                .paragraph("Try taking slightly shorter, quicker steps at the same pace. It often feels lighter and puts less stress on your knees."),
                .paragraph("Change it a little at a time. There's no magic number you need to hit."),
            ],
            takeaways: ["Shorter, quicker steps feel lighter.", "Don't over-stride out in front of you.", "Change it gradually; there's no magic number."]
        ),
        Article(
            id: "hills", category: .form,
            title: "Running up and down hills",
            summary: "Keep the effort steady, not the pace.",
            icon: "mountain.2", minutes: 2,
            body: [
                .heading("Going up"),
                .paragraph("Shorten your stride, pump your arms and let your pace slow. Aim to keep the same effort you had on flat ground. Walking steep hills is completely fine."),
                .heading("Coming down"),
                .paragraph("Lean slightly forward, take quick light steps and let gravity do the work. Don't brake hard with long strides; that's tough on your knees."),
            ],
            takeaways: ["Keep your effort steady on hills.", "Short steps uphill, quick light steps downhill.", "Walking steep hills is fine."]
        ),

        // MARK: Training for a race
        Article(
            id: "first-5k", category: .races,
            title: "Training for your first 5K",
            summary: "3.1 miles is a great first goal. Here's how to get there.",
            icon: "flag", minutes: 2,
            body: [
                .paragraph("A 5K is 3.1 miles (5 km). Most beginners can get there in 6 to 10 weeks with three runs a week."),
                .paragraph("Start with run/walk, keep almost every run easy, and build slowly. You don't need to run fast to finish strong."),
                .paragraph("On race day, start slower than you think you should. Finishing feeling good is a win."),
            ],
            takeaways: ["6–10 weeks of three runs a week is plenty.", "Keep almost every run easy.", "Start the race slower than you think."]
        ),
        Article(
            id: "10k", category: .races,
            title: "Stepping up to a 10K",
            summary: "Double the distance with a longer weekly run.",
            icon: "flag.2.crossed", minutes: 2,
            body: [
                .paragraph("A 10K is 6.2 miles (10 km). If you can run a 5K, you're well on your way."),
                .paragraph("The key is one longer run each week that grows a little at a time. Keep it slow and steady. Your other runs stay short and easy."),
                .paragraph("Once you're comfortable, a short faster session can help you get quicker, but it's optional for your first 10K."),
            ],
            takeaways: ["Build one longer run each week.", "Keep your longer run slow.", "Speed work is optional for a first 10K."]
        ),
        Article(
            id: "half", category: .races,
            title: "Half marathon training basics",
            summary: "13.1 miles takes patience. Your long run is the key.",
            icon: "medal", minutes: 3,
            body: [
                .paragraph("A half marathon is 13.1 miles (21.1 km). Plans usually take 10 to 16 weeks, depending on where you start."),
                .heading("The long run"),
                .paragraph("Your weekly long run builds the endurance you need. It grows slowly, up to about 10 to 12 miles. Run it at an easy, chatty pace."),
                .heading("Practice race day"),
                .paragraph("Use long runs to try your race-day breakfast, drinks and gear. Nothing new on race day."),
            ],
            takeaways: ["The weekly long run is the key workout.", "Long runs should be easy and slow.", "Practice your race-day food and gear."]
        ),
        Article(
            id: "marathon", category: .races,
            title: "Marathon training basics",
            summary: "26.2 miles is a big goal. Respect the build-up.",
            icon: "medal.star", minutes: 3,
            body: [
                .paragraph("A marathon is 26.2 miles (42.2 km). Most plans take 16 to 20 weeks, and it helps to have run a shorter race first."),
                .heading("What matters most"),
                .bullets(["A long run that grows to around 18–20 miles.", "Mostly easy running, so you stay healthy.", "Eating and drinking during long runs, so you learn what works."]),
                .paragraph("The last two weeks are lighter so you arrive fresh. Trust it; the hard work is already done."),
            ],
            takeaways: ["Plan for 16–20 weeks of training.", "Practice fueling on your long runs.", "Lighter final weeks help you arrive fresh."]
        ),

        // MARK: Race day
        Article(
            id: "first-race", category: .raceDay,
            title: "Your first race: what to expect",
            summary: "A little planning makes race morning calm and fun.",
            icon: "flag.checkered", minutes: 3,
            body: [
                .heading("The day before"),
                .paragraph("Lay out your clothes, shoes and bib. Wear things you've run in before. Eat a normal dinner and get to bed at a sensible time."),
                .heading("Race morning"),
                .paragraph("Arrive early. Lines for the bathroom are long. Eat a familiar breakfast two to three hours before the start."),
                .heading("During the race"),
                .paragraph("Start slower than feels natural; the excitement makes everyone go out too fast. Walk through water stations if it helps. Then enjoy it."),
            ],
            takeaways: ["Nothing new on race day.", "Arrive early.", "Start slower than feels natural."]
        ),
        Article(
            id: "eat-before", category: .raceDay,
            title: "What to eat before a long run",
            summary: "A simple, familiar meal a couple of hours before.",
            icon: "fork.knife", minutes: 2,
            body: [
                .paragraph("For runs over an hour, eat something simple two to three hours before: toast with peanut butter, a bagel, oatmeal or a banana."),
                .paragraph("Choose foods that are easy on your stomach. Skip very fatty, spicy or high-fiber meals right before a run."),
                .paragraph("For runs over about 75 minutes, bring a small snack or energy gel and practice using it on training runs."),
            ],
            takeaways: ["Eat 2–3 hours before long runs.", "Keep it simple and familiar.", "Practice mid-run snacks in training."]
        ),
        Article(
            id: "pacing-race", category: .raceDay,
            title: "How to pace your race",
            summary: "Start controlled, finish strong.",
            icon: "stopwatch", minutes: 2,
            body: [
                .paragraph("The most common race mistake is starting too fast. Adrenaline makes a fast pace feel easy, and you pay for it later."),
                .paragraph("Run the first part a little slower than your goal pace. If you feel good past the halfway point, gradually speed up."),
                .paragraph("Finishing strong feels much better than hanging on."),
            ],
            takeaways: ["Don't start too fast.", "Speed up only after halfway.", "Aim to finish strong."]
        ),
        Article(
            id: "race-week", category: .raceDay,
            title: "Race week: rest up",
            summary: "Less running this week makes you faster on race day.",
            icon: "bed.double", minutes: 2,
            body: [
                .paragraph("In the final week, your plan runs less. That's on purpose: your legs recover so you feel fresh and strong on race day."),
                .paragraph("You might feel restless or sluggish. That's normal. Don't add extra runs to feel ready; the fitness is already there."),
                .paragraph("Sleep well, eat normally and keep your shoes and kit ready."),
            ],
            takeaways: ["Running less before a race is planned.", "Feeling restless is normal.", "Don't add extra runs in race week."]
        ),
        Article(
            id: "after-race", category: .raceDay,
            title: "After the race: recovery",
            summary: "Rest, eat and give your legs a few easy days.",
            icon: "heart", minutes: 2,
            body: [
                .paragraph("Right after, keep walking for a few minutes, drink water and eat something within an hour."),
                .paragraph("Take a few days off or do only easy walking. Your muscles need time to repair, especially after a half or full marathon."),
                .paragraph("When you start again, keep runs short and easy for a week or two."),
            ],
            takeaways: ["Walk, drink and eat soon after finishing.", "Rest for a few days.", "Ease back in with short, easy runs."]
        ),

        // MARK: Strength & mobility
        Article(
            id: "strength", category: .strength,
            title: "10-minute strength routine for runners",
            summary: "Twice a week, no equipment needed.",
            icon: "dumbbell", minutes: 3,
            body: [
                .paragraph("Strong legs and hips help you run better and stay injury-free. Do this twice a week, on easy days or rest days."),
                .bullets(["Squats: 2 × 12", "Lunges: 2 × 10 each leg", "Glute bridges: 2 × 15", "Calf raises: 2 × 15", "Plank: 2 × 30 seconds"]),
                .paragraph("Move slowly and with control. It should feel like work, but never painful."),
            ],
            takeaways: ["Two short sessions a week is enough.", "Focus on legs, hips and core.", "Move with control; no pain."]
        ),
        Article(
            id: "stretching", category: .strength,
            title: "Do runners need to stretch?",
            summary: "Warm up before, stretch gently after if you like.",
            icon: "figure.flexibility", minutes: 2,
            body: [
                .paragraph("Before a run, a few minutes of brisk walking or easy jogging warms you up better than holding stretches."),
                .paragraph("After a run, gentle stretching can feel good and help you relax. Hold each stretch for about 30 seconds, without bouncing."),
                .paragraph("If something feels tight every run, regular gentle stretching or strength work can help."),
            ],
            takeaways: ["Warm up by walking or jogging easily.", "Stretch after runs if it feels good.", "Never stretch into pain."]
        ),
        Article(
            id: "foam-rolling", category: .strength,
            title: "Foam rolling: does it help?",
            summary: "It can ease tightness. Gentle is best.",
            icon: "cylinder", minutes: 2,
            body: [
                .paragraph("Foam rolling can make tight muscles feel looser and help you move more easily. It doesn't fix injuries, but many runners find it helpful."),
                .paragraph("Roll slowly over calves, thighs and hips for about a minute each. Stay off joints and bones, and keep the pressure comfortable."),
            ],
            takeaways: ["It can ease tightness.", "Roll slowly, about a minute per area.", "Avoid joints and painful pressure."]
        ),

        // MARK: The science
        Article(
            id: "rest", category: .science,
            title: "What actually happens when you rest",
            summary: "Your body gets fitter between runs, not during them.",
            icon: "moon", minutes: 2,
            body: [
                .paragraph("A run is a small stress on your body. During rest, your body repairs and gets a little stronger, ready for the next run."),
                .paragraph("Without enough rest, that repair doesn't finish, and you end up tired instead of fitter. That's why rest days are built into your plan."),
            ],
            takeaways: ["You get fitter while you rest.", "Rest days are part of training.", "Tired all the time? You may need more rest."]
        ),
        Article(
            id: "plan-builds-fitness", category: .science,
            title: "How your plan builds your fitness",
            summary: "Small steps, every week, add up to a big change.",
            icon: "chart.line.uptrend.xyaxis", minutes: 2,
            body: [
                .paragraph("Your plan adds a little more running each week, usually no more than about 10%. Small steps give your body time to adapt."),
                .paragraph("Every few weeks, there's a lighter week. It lets your body catch up, so you come back stronger."),
                .paragraph("The plan also ends with lighter days before your goal, so you arrive fresh."),
            ],
            takeaways: ["Your plan builds slowly on purpose.", "Lighter weeks help you absorb training.", "Consistency beats big jumps."]
        ),
        Article(
            id: "sore-or-hurt", category: .science,
            title: "Sore or injured? How to tell",
            summary: "Some soreness is normal. Sharp or worsening pain isn't.",
            icon: "bandage", minutes: 2,
            body: [
                .paragraph("Feeling a little sore a day or two after a run is normal, especially when you're new. It feels dull, is on both sides, and fades as you warm up."),
                .paragraph("Pain that's sharp, on one side, gets worse as you run, or makes you limp is different. Stop running and rest."),
                .paragraph("If pain lasts more than a few days, see a doctor or physical therapist. Use Adjust plan to tell Kiki, and your plan will ease off."),
            ],
            takeaways: ["Dull, even soreness that eases is normal.", "Sharp or worsening pain: stop and rest.", "Pain lasting days: see a professional."]
        ),
        Article(
            id: "sleep", category: .science,
            title: "Sleep: the free performance boost",
            summary: "Better sleep means better runs.",
            icon: "bed.double.fill", minutes: 2,
            body: [
                .paragraph("Your body does much of its repair while you sleep. Short sleep makes runs feel harder and slows your progress."),
                .paragraph("Aim for 7 to 9 hours. Keep a regular bedtime, a cool dark room, and screens away for a bit before bed."),
            ],
            takeaways: ["Aim for 7–9 hours a night.", "Sleep is when your body repairs.", "Regular bedtimes help most."]
        ),
    ]
}

/// Articles the runner has opened, kept on this device.
enum ReadArticles {
    private static let key = "learn.read"

    static var ids: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func markRead(_ id: String) {
        var read = ids
        guard read.insert(id).inserted else { return }
        UserDefaults.standard.set(Array(read), forKey: key)
    }
}
