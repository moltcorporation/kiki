# AGENTS.md

Kiki: AI running coach iOS app. Quiz onboarding → AI-generated training plan → paywall → daily coaching. Black/white brand, premium minimal UI.

## Brand
- Look: black/white UI, premium and minimal. Photography and video bring warmth (golden-hour running footage), never the UI chrome.
- Texture: gritty, asphalt-like film grain with a soft vignette (darker edges, gentle center glow). Used on the splash (`LaunchTexture`) and over the welcome video (`Grain`). Keep it subtle.
- Welcome screen: left-aligned on the 24pt margin (Nike Run Club pattern). "Kiki" wordmark top-left (28pt black italic over a soft corner vignette, away from the sun) so a new user learns the name; headline (44pt black italic) and actions at the bottom over a dark gradient. Footer spacing matches `OnboardingScaffold` (24pt sides, 4pt between actions, 8pt above the home indicator, 44pt tap targets).
- Website: dark by default (`--paper` #0B0C0E, `--ink` white), `.asphalt` texture on hero/feature bands, Inter (true black italic) for headlines. No pricing on the website.

- Surfaces: grayscale. Pages use `PageBackground()` (neutral `canvas` #FAFAFA with a very faint dark asphalt glow and grain rising from the bottom, the same on every page); cards are white `surface` with a soft shadow (`.elevatedCard()`); goal cards use `AsphaltBackground()`. Controls stay black and white. Secondary text uses `muted` (#666970, 5.5:1 on white; never the system `.secondary`, which is 3.4:1). Keep text at WCAG AA (4.5:1) or better.
- Voice: ask and speak like a coach would. Natural, concise, direct and simple: "Which race are you training for?", not "What distance is your race?". Short subtitles, no filler, no jargon. Keep it warm and positive (e.g. "Sign in", "Welcome back!").

- App chrome: every tab (Home, Plan, You) is built on `TabPage` (Design/TabPage.swift), so the top area is identical: a 34pt left-aligned title that scrolls with the content (no floating bar), 8pt below the safe area, 16pt above the first section, 28pt between sections. Home's title is the Kiki wordmark (black italic, same size); Plan and You use plain titles. Sections are `TabSection` (title above a card); cards are `.elevatedCard()`, lists of workouts are `WorkoutListCard`. Only Home's goal card uses the asphalt texture. Every screen (tabs, onboarding, welcome) uses a 20pt side margin (`Metrics.screenMargin`), and the first element sits 8pt below the safe area (Apple HIG: stay in the safe area, standard margins, 8pt grid). Screen titles are our own `Text` in `.screenTitle`, not system large titles, so they align to the margin.

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
- Routing (`RootView`): onboarding (persisted in UserDefaults) → welcome → paywall (hard) → `MainTabView` (Today / Plan / You).
- Onboarding answers are only AI inputs: the main app never branches on goal (goal wording lives in `Plan.displayName`). Question options and inputs live in `Features/Shared/Questions.swift` and `Design/Inputs.swift`, shared by onboarding and the You tab (`ProfileFieldEditor`). "Change goal" reuses `OnboardingFlow` with `OnboardingModel(mode: .newGoal, profile:)`. Every answer must stay editable from You.
- Onboarding ↔ You tab: every onboarding answer must stay editable from the You tab. Options live in `Features/Shared/Questions.swift` and inputs in `Design/Inputs.swift` (shared by both); goal edits reuse the onboarding steps via `OnboardingModel(mode: .editGoal(step))`. Keep the two in sync both ways: when you change an onboarding question, cross-check `YouView` (rows), `ProfileFieldEditor` (titles, name field) and `GoalDetailView` (goal rows); when you change an editor in the You tab, cross-check the matching onboarding step.
- `APIClient` never sends cookies (Better Auth rejects cookie requests without an Origin); auth is the bearer token only.
- API base URL comes from the `KIKI_API_BASE_URL` build setting: Debug = `http://localhost:3000`, Release = `https://kikirunning.com`.
- RevenueCat: Debug uses the Test Store key (simulated purchases), Release uses the `appl_` key. Custom paywall (`PaywallView`), Customer Center in the You tab.
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
- Account deletion must stay reachable in-app (You tab and the paywall menu).

## Open items
- TestFlight build, App Store listing, screenshots, privacy label.
- On the first submission, attach both subscriptions on the version page in ASC.
