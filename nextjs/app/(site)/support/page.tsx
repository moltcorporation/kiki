import type { Metadata } from "next";
import { LegalPage } from "@/components/prose";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Support",
  description: "Get help with Kiki, the AI running coach for iPhone: changing your plan, Apple Health, subscriptions and your account.",
  alternates: { canonical: "/support" },
};

export default function SupportPage() {
  return (
    <LegalPage title="Support" updated="October 2, 2026">
      <p>
        We&apos;re here to help. Email{" "}
        <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a> and we&apos;ll get back to
        you within one business day.
      </p>

      <h2>Common questions</h2>
      <h3>How do I change my plan?</h3>
      <p>
        On the Home tab, tap <strong>Adjust day</strong> on today&apos;s run, or{" "}
        <strong>Adjust plan</strong> on your goal card. Pick an option (tired, too hard, can&apos;t
        make it, something hurts, make it easier, push me harder) or tell Kiki in your own words.
        Your upcoming workouts update in seconds.
      </p>

      <h3>How do I start a plan for a different race or goal?</h3>
      <p>
        Go to the <strong>Profile</strong> tab and tap your goal card. You can change your race,
        date or goal time, or set a new goal, and Kiki builds a fresh plan.
      </p>

      <h3>How do I connect Apple Health, Apple Watch or Strava?</h3>
      <p>
        Go to <strong>Profile › Apple Health</strong> and allow access. Runs from Apple Watch, and
        from apps that save to Apple Health such as Strava and Garmin Connect, then check off your
        planned runs automatically.
      </p>

      <h3>How do I cancel my subscription?</h3>
      <p>
        Open the Settings app on your iPhone › your name › Subscriptions › Kiki › Cancel
        Subscription. You can also manage it from Kiki under <strong>Profile › Subscription</strong>.
      </p>

      <h3>How do I restore my purchase on a new phone?</h3>
      <p>
        Sign in with the same Apple ID, then tap <strong>Profile › Restore purchases</strong>.
      </p>

      <h3>How do I delete my account?</h3>
      <p>
        In Kiki, go to <strong>Profile › Delete account</strong>. This permanently removes your
        profile, plans and runs. Remember to cancel your subscription separately in your Apple ID
        settings.
      </p>
    </LegalPage>
  );
}
