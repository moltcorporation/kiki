# AGENTS.md

Kiki: AI running coach iOS app. Quiz onboarding → AI-generated training plan → paywall → daily coaching. Black/white brand, premium minimal UI.

## Brand
- Look: black/white UI, premium and minimal. Photography and video bring warmth (golden-hour running footage), never the UI chrome.
- Texture: gritty, asphalt-like film grain with a soft vignette (darker edges, gentle center glow). Used on the splash (`LaunchTexture`) and over the welcome video (`Grain`). Keep it subtle.
- Welcome screen: the Kiki wordmark centered at the top (over a soft vignette); centered at the bottom over a dark gradient: the headline (44pt black italic), Get started, and an "Already have an account? Sign in" text link.
- Website: dark by default (`--paper` #0B0C0E, `--ink` white), `.asphalt` texture on hero/feature bands, Inter (true black italic) for headlines. No pricing on the website.
- Voice: ask and speak like a coach would. Natural, concise, direct and simple: "Which race are you training for?", not "What distance is your race?". Short subtitles, no filler, no jargon. Keep it warm and positive (e.g. "Sign in", "Welcome back!").

### Design system (iOS, `ios/kiki/Design/`)
Every screen is built from these files. Never use raw numbers, hex colors, fixed font sizes or one-off card styles in feature code: if something is missing, add a token or component here first, then use it. Changing a value here restyles the whole app. `DesignCatalog.swift` previews every component (light and dark).
- `Tokens.swift`: `Spacing` (4pt scale: xxs 2 … xxxl 32), `Metrics` (20pt screen margin, 8pt top inset, 58pt large-title inset matching Apple's large titles (Plan, Profile; Home's wordmark stays at 8pt), 18pt below a pushed screen's nav bar (matches Settings > General), 28pt section spacing, 12pt section header spacing, 20pt card padding, 56/48pt buttons, 44pt tap target), `Radius` (card 24, bubble 20, control 16, inner 12), `Elevation` (`.card`, `.raised`), color roles (`hairline`, `track`, `destructive`), `Haptics`.
- Colors (Assets, light + dark): `ink` text/controls, `paper` text on ink, `canvas` page, `surface` cards and controls, `wash` small fills on cards (icon circles), `muted` secondary text (5.5:1, never `.secondary`). UI is grayscale; the only color is the `glow` token in `Tokens.swift` (volt green light on Home's goal card). Keep text at WCAG AA.
- `Typography.swift`: `display`/`wordmark` (black italic, the Kiki voice), `screenTitle` (34 bold), `heroTitle`, `cardTitle`/`sheetTitle`, `sectionTitle` (20 semibold), `rowTitle` (17 semibold), `body`, `detail` (15, with `muted`), `eyebrow` (13 semibold, with `muted`), `metric(_:)`, `.heroMetricFont()`. All follow Dynamic Type. Use weight, not ALL CAPS, for emphasis.
- `Surfaces.swift`: one surface model. Every page sits on `PageBackground()` (canvas with a faint asphalt glow from the bottom). Content goes on `Card { }` / `.elevatedCard()` (white surface, soft shadow). Controls (options, fields, tiles) use `.controlSurface(isSelected:)` (white + hairline, ink outline when selected). Only Home's goal card is dark (`AsphaltBackground`); everything else (Today's workout, the Plan tab's stats card) stays white. If a dark card is ever needed, use `.invertedColorScheme()`, never `inverted` flags.
- `Pages.swift`: every screen is a `TabPage` (tab roots: `TabPage("Title")`, a 34pt left-aligned title that scrolls away, no nav bar; Home uses `TabPage(.wordmark)`, the 28pt Kiki wordmark centered at the top with the goal card as the first thing below it, no heading), a `DetailPage` (pushed screens and full sheets: inline nav title, page background; the tab bar hides while pushed: put `.hidesTabBar(!path.isEmpty)` on each tab root, never hide it from the pushed screen, which makes it pop back in late), or a `FlowPage` (full-screen flow steps: `PageHeader` + content + actions; onboarding uses it via `OnboardingScaffold`). Group content with `PageSection` (title above a card) or `ListSection` (title above a `ListCard`). Pin buttons with `.bottomActions { }`. Compact sheets use `CompactSheet` (header + hairline, fits content).
- `Rows.swift`: one row anatomy. Lists are a `ListCard` (adds inset dividers between rows automatically) of `ListRow`s: circled `RowIcon`, title (`.content` semibold, `.setting` regular), gray subtitles, gray value, chevron when it opens something. `SettingsRow` / `SettingsToggleRow` for settings. `InfoRow`/`InfoList` for benefit lists.
- `Buttons.swift`: `PrimaryButton` (one per screen), `SecondaryButton`, `TextButton` (Skip, Not now), `CircleButton` (icon beside a pill), `BackButton`. `.controlSize(.small)` for 48pt buttons inside cards. Custom tappables use `.buttonStyle(.haptic)`.
- `Inputs.swift`: `OptionCard`/`ChoiceList` (list choices, radio or checkbox), `SelectableTile` (grid choices, filled when selected), `.inputField()` and `LabeledField` for text, `RulerPicker`, `DurationWheel`, `RunDaysSelector`, `InputHint`.
- Home's Today is its own `TodayCard` (title; distance and target pace, or the logged run; how it should feel; chevron). Every other list of workouts uses `WeekSchedule` (`Features/Plan`): the Plan tab's weeks, Home's Upcoming, the adjust result and onboarding's first week (`isNavigable: false` where there's nowhere to go). Like a calendar list: equal-height day rows split by hairlines, a date column (today in an ink circle), and one line per workout. Planned: a wash block with an ink accent bar, title, and the amount on the right. Done: no block, gray, struck through (no icon). Skipped: the same with "Skipped" in place of the amount. Rest: just "Rest" in gray. No icons. Each workout is its own block so press-and-hold to move or edit can be added later.
- `Content.swift`: `KikiLogo`, `Pill`, `MetricView`, `CoachBubble`/`UserBubble`, `MessageCard` (status and empty states).

### Logo specs
- Wordmark: "Kiki" (one word, capital K, never all caps). SF Pro, Black (900) weight, italic; default tracking. SwiftUI: `.font(.system(size: …, weight: .black).italic())`.
- Colors: Ink `#15181D` on light, white `#FFFFFF` on dark. No other logo colors.
- App icon: white "K" in the same type on the asphalt texture (`#15181D` base). K width = 58% of the canvas, centered by its visible bounds (~21% clear each side). 1024×1024 RGB PNG, no alpha, square corners (iOS masks them).
- Masters (repo root): `kiki-app-icon-1024.png`, `kiki-app-icon-4096.png`. Regenerate every copy from them: iOS `AppIcon`, `KikiIcon` (in-app `KikiLogo`), site `app/favicon.ico` (16/32/48, RGBA), `app/icon.png` (256), `app/apple-icon.png` (180), `public/kiki-icon.png`.
- Outside the app, render the type (don't retype it in another font): iOS assets `LaunchWordmark`; site `public/kiki-wordmark.png` (white).

## Layout
- `nextjs/` Next.js 16 app: marketing site (`app/(site)`), REST API (`app/api`), durable AI workflows (`workflows/`). Deployed on Vercel (project `kiki`, team `moltcorporation`), domain kikirunning.com. Push to `main` = production deploy.
- `ios/` SwiftUI app (iOS 26.5+, iPhone only, portrait). Targets: `kiki` (bundle `com.moltcorporation.kiki`), `KikiWidgets` (Live Activity). `ios/Shared/` is compiled into both. Folders are file-system synchronized: new files are picked up automatically.

## Backend
- pnpm. `pnpm dev`, `pnpm build`, `pnpm lint`, `npx tsc --noEmit` (run `npx next typegen` first if route types are stale).
- DB: Neon Postgres (project "Kiki", `summer-wave-37335605`) via Drizzle. `db/schema.ts` is the only schema source. Don't modify `db/index.ts` or `drizzle.config.ts`. Schema auto-pushes on merge via `.github/workflows/push-db-schema.yml`; locally: `pnpm exec drizzle-kit push`. neon-http driver: no interactive transactions, use `db.batch`.
- Units: distances in meters, durations in seconds, paces in s/km, calendar dates as `YYYY-MM-DD` strings.
- Auth: Better Auth (`lib/auth.ts`), **Sign in with Apple only** (native ID token, audience = bundle ID), `bearer` plugin. iOS sends `Authorization: Bearer <token>`. `withUser()` in `lib/api.ts` wraps every API route.
- Apple token revocation (5.1.1(v)): after sign-in the app posts the authorization code to `/api/me/apple-token`; `lib/apple.ts` exchanges it for a refresh token (stored in `account.refreshToken`) and `DELETE /api/me` revokes it. SIWA key ID `NZ56QW5STV`.
- AI: AI SDK + AI Gateway, model `google/gemini-3.8-flash` with `anthropic/claude-sonnet-5.5` fallback, structured output (`Output.object` + Zod). A plan is ONE AI call; adjustments use a separate prompt. Prompts, coaching rules, concise-writing rules and safety normalization (weekly growth cap, run days only, goal finale) are in `lib/training/coach.ts`.
- Goals: `goalKind` is `start` (run 30 min non-stop), `race`, `faster` (time trial finale) or `fit` (no finale). `plan.raceDate` is the plan's end date for every goal. No phases/peak/taper in UI or output; keep wording beginner-friendly and jargon-free.
- Workflows (Vercel Workflow): `generatePlanWorkflow` (load context, one AI step, save) and `adjustPlanWorkflow`. The AI work runs inside `"use step"` functions. `app/.well-known/workflow/` is generated (gitignored).
- Consent: new accounts tick "I agree to Kiki's Terms of Service and Privacy Policy" (clickwrap) on the onboarding account step; the welcome "Sign in" opens a styled bottom sheet (`SignInSheet`: "Sign in with Apple" plus a "By continuing, you agree…" notice, no checkbox), and `ConsentGate` asks once if the server has no agreement on record. Agreements are logged in the append-only `consent` table (`POST /api/me/consent`) with the legal pages' "last updated" date (`Config.legalVersion`) for the record. No re-consent on Terms changes (the Terms cover updates).
- Subscription gate: `lib/subscription.ts` checks the RevenueCat v1 API (entitlement `premium`). Coach adjustments require it; plan creation allows 3 free.

## iOS
- Build: `xcodebuild -project ios/kiki.xcodeproj -scheme kiki -destination 'platform=iOS Simulator,name=iPhone 17' build`.
- Default actor isolation is MainActor; Codable models are `nonisolated`.
- Data: `TrainingStore` = disk cache + optimistic updates + persistent outbox (runs and workout status). Client-generated UUIDs make writes idempotent.
- Routing (`RootView`): onboarding (persisted in UserDefaults) → welcome → paywall (hard) → `MainTabView` (Home / Plan / Profile).
- Onboarding answers are only AI inputs: the main app never branches on goal (goal wording lives in `Plan.displayName`). Question options and inputs live in `Features/Shared/Questions.swift` and `Design/Inputs.swift`, shared by onboarding and the Profile tab (`ProfileFieldEditor`). "Change goal" reuses `OnboardingFlow` with `OnboardingModel(mode: .newGoal, profile:)`. Every answer must stay editable from You.
- Onboarding ↔ Profile tab: every onboarding answer must stay editable from the Profile tab. Options live in `Features/Shared/Questions.swift` and inputs in `Design/Inputs.swift` (shared by both); goal edits reuse the onboarding steps via `OnboardingModel(mode: .editGoal(step))`. Keep the two in sync both ways: when you change an onboarding question, cross-check `YouView` (rows), `ProfileFieldEditor` (titles, name field) and `GoalDetailView` (goal rows); when you change an editor in the Profile tab, cross-check the matching onboarding step.
- `APIClient` never sends cookies (Better Auth rejects cookie requests without an Origin); auth is the bearer token only.
- API base URL comes from the `KIKI_API_BASE_URL` build setting: Debug = `http://localhost:3000`, Release = `https://kikirunning.com`.
- RevenueCat: Debug uses the Test Store key (simulated purchases), Release uses the `appl_` key. Custom paywall (`PaywallView`), Customer Center in the Profile tab.
- SDK identity: `Identity.identify` / `ensureIdentified` sets the same user ID in PostHog, RevenueCat (`logIn` + AppsFlyer/PostHog attribution) and AppsFlyer (`customerUserID`).
- AppsFlyer on-device events (`Attribution` in `Analytics.swift`): `af_complete_registration` (new users), `af_start_trial`, `af_subscribe`. They feed SKAN conversion values for Meta/TikTok; no revenue (RevenueCat sends revenue S2S). Campaigns optimize for StartTrial.
- AppsFlyer SDK 7: `initialize(devKey:appId:)` + `registerSessionReadyListener`. The ATT prompt is requested inside the listener on app open, then `start()`.
- Simulator testing without Apple sign-in: launch with `SIMCTL_CHILD_KIKI_DEBUG_SESSION_TOKEN` and `SIMCTL_CHILD_KIKI_DEBUG_USER_ID` (DEBUG only). Drive the UI with the AXe CLI (`axe tap --label`, `axe describe-ui`).

## Services
- App Store Connect: app ID `6817469393`, team `46696JNF4G`. Subscription group "Kiki Pro": `kiki_premium_yearly` ($59.99), `kiki_premium_monthly` ($11.99), 7-day free trial, all territories. Use the `asc` CLI (skills in `~/.agents/skills/asc-*`).
- RevenueCat: project `proj49f9be7f`, iOS app `app7a71f33a94`, entitlement `premium` ("Kiki Pro"), offering `default` (`$rc_annual`, `$rc_monthly`). AppsFlyer and PostHog integrations are enabled (default event names, no sandbox).
- PostHog: project 134644, US cloud. iOS app analytics + error tracking (session replay off) and server-side API error capture. Not used on the website.
- AppsFlyer: app `id6817469393`.
- Video generation: Seedance 2.5 on Replicate. See `replicate-seedance-instructions.md`.
- Image generation: Nano Banana Pro on Replicate. See `replicate-nano-banana-instructions.md`.

## Env (`nextjs/.env.local`, Vercel)
`DATABASE_URL`, `BETTER_AUTH_SECRET`, `BETTER_AUTH_URL`, `AI_GATEWAY_API_KEY` (local only; Vercel uses OIDC), `REVENUECAT_SECRET_KEY`, `APPLE_PRIVATE_KEY`, `APPLE_KEY_ID`, `APPLE_TEAM_ID`, `POSTHOG_PROJECT_TOKEN`, `POSTHOG_HOST`, optional `NEXT_PUBLIC_APP_STORE_URL`. See `nextjs/.env.example`. Never commit `.env*`.

## Rules
- Contact email everywhere: hello@moltcorporation.com. Company: Moltcorp Inc.
- No fabricated testimonials or user counts (App Review / FTC).
- Keep it minimal: haptics on every button, black/white only, respect Dynamic Type and VoiceOver.
- Account deletion must stay reachable in-app (Profile tab and the paywall menu).

## Open items
- TestFlight build, App Store listing, screenshots, privacy label.
- On the first submission, attach both subscriptions on the version page in ASC.
