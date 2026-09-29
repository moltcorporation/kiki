import type { Metadata } from "next";
import { LegalPage } from "@/components/prose";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Support",
  description: "Get help with Kiki.",
};

export default function SupportPage() {
  return (
    <LegalPage title="Support" updated="September 29, 2026">
      <p>
        We&apos;re here to help. Email{" "}
        <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a> and we&apos;ll get back to
        you within one business day.
      </p>

      <h2>Common questions</h2>
      <h3>How do I change my plan?</h3>
      <p>
        Open a workout to move or skip it, or tap <strong>Adjust plan</strong> and tell Kiki
        what&apos;s going on (tired, busy, injured, too easy or too hard). Your upcoming workouts
        update in seconds.
      </p>

      <h3>How do I start a new plan for a different race?</h3>
      <p>Go to Settings › Race &amp; goal and enter your new race. Kiki builds a fresh plan.</p>

      <h3>How do I cancel my subscription?</h3>
      <p>
        Open the Settings app on your iPhone › your name › Subscriptions › Kiki › Cancel
        Subscription. You can also manage it from Kiki under Settings › Subscription.
      </p>

      <h3>How do I restore my purchase on a new phone?</h3>
      <p>
        Sign in with the same Apple ID, or tap <strong>Restore purchases</strong> on the
        subscription screen.
      </p>

      <h3>How do I delete my account?</h3>
      <p>
        In Kiki, go to Settings › Delete account. This permanently removes your profile, plans and
        runs. Remember to cancel your subscription separately in your Apple ID settings.
      </p>
    </LegalPage>
  );
}
