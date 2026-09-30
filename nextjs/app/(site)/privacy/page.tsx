import type { Metadata } from "next";
import { LegalPage } from "@/components/prose";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How Kiki collects, uses and protects your information.",
};

export default function PrivacyPage() {
  return (
    <LegalPage title="Privacy Policy" updated="September 30, 2026">
      <p>
        This Privacy Policy explains how {site.company} (&quot;we&quot;, &quot;us&quot;) collects,
        uses and shares information when you use the Kiki mobile app and the website at{" "}
        <a href={site.url}>kikirunning.com</a> (together, the &quot;Service&quot;). We only
        collect what we need to coach you well, and we never sell your personal information.
      </p>

      <h2>Information we collect</h2>
      <h3>Account information</h3>
      <p>
        You create an account with Sign in with Apple. We receive the email address (or a private
        relay address, if you choose to hide your email) and name that Apple shares with us.
      </p>

      <h3>Training profile</h3>
      <p>
        To build your plan we ask about your goal (such as a race, its distance, date and goal
        time), your running experience, current weekly distance, the days you can train and how
        you like to be coached. You may optionally share your first name, age, height and weight,
        which are used only to tailor your training. If you tell Kiki about pain or an injury
        when adjusting your plan, we use that to adapt your training.
      </p>

      <h3>Runs and feedback</h3>
      <p>
        When you log a run we store its date, distance, duration, pace and any effort rating, how
        you felt and notes you add.
      </p>

      <h3>Location</h3>
      <p>
        If you record a run with Kiki and grant location permission, we collect precise location
        while the run is being recorded to measure distance, pace and your route. We do not
        collect location at any other time. Your route is stored with the run so you can view it
        later, and you can delete any run.
      </p>

      <h3>Usage, device and diagnostics data</h3>
      <p>
        We collect information about how you use the app (for example, screens viewed and
        features used), device information (such as model, operating system and app version) and
        crash and error reports, to improve the Service and fix problems.
      </p>

      <h3>Advertising and attribution data</h3>
      <p>
        With your permission through Apple&apos;s App Tracking Transparency prompt, we use your
        device&apos;s advertising identifier to measure which marketing campaigns lead to installs
        and subscriptions. If you decline, we do not access the advertising identifier. You can
        change this anytime in Settings › Privacy &amp; Security › Tracking.
      </p>

      <h3>Purchases</h3>
      <p>
        Subscriptions are processed by Apple. We receive information about your subscription
        status (such as plan, trial and renewal dates) but never your payment card details.
      </p>

      <h3>Agreement records</h3>
      <p>
        When you agree to our Terms and Privacy Policy, we record the date, the version you agreed
        to and your app version.
      </p>

      <h2>How we use information</h2>
      <ul>
        <li>To create, personalize and adapt your training plan.</li>
        <li>To record and display your runs and progress.</li>
        <li>To provide your account, subscription and customer support.</li>
        <li>To send reminders you&apos;ve allowed, such as workout and trial reminders.</li>
        <li>To understand usage, measure marketing, and improve and secure the Service.</li>
        <li>To comply with legal obligations.</li>
      </ul>

      <h2>AI processing</h2>
      <p>
        Your training profile, plan and recent run feedback are sent to AI model providers
        (currently Google and Anthropic, through Vercel&apos;s AI Gateway) to generate and adjust
        your plan. We share only what&apos;s needed to coach you, and these providers process it
        on our behalf. Under their API terms, they do not use this data to train their models.
      </p>

      <h2>How we share information</h2>
      <p>We share information only with service providers that help us run Kiki:</p>
      <ul>
        <li><strong>Vercel</strong> and <strong>Neon</strong>: hosting and database.</li>
        <li><strong>Google</strong> and <strong>Anthropic</strong>: AI plan generation.</li>
        <li><strong>RevenueCat</strong>: subscription management.</li>
        <li><strong>PostHog</strong>: product analytics and error tracking.</li>
        <li><strong>AppsFlyer</strong>: install and campaign attribution.</li>
        <li><strong>Apple</strong>: sign-in and payments.</li>
      </ul>
      <p>
        We may also disclose information if required by law, to protect rights and safety, or as
        part of a merger or acquisition. We do not sell personal information or share it for
        cross-context behavioral advertising beyond the attribution described above.
      </p>

      <h2>Retention and deletion</h2>
      <p>
        We keep your information while your account is active. You can delete your account at
        any time in the app under You › Delete account, which permanently deletes your
        profile, plans and runs from our systems. Some information may remain in backups for a
        limited time or where we&apos;re legally required to keep it. To cancel a subscription,
        use your Apple ID subscription settings; deleting your account does not cancel it.
      </p>

      <h2>Your rights</h2>
      <p>
        Depending on where you live (including the EU, UK and California), you may have the right
        to access, correct, delete or export your personal information, and to object to or
        restrict certain processing. Email <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>{" "}
        and we&apos;ll respond within the time required by law.
      </p>

      <h2>Security</h2>
      <p>
        We use industry-standard safeguards, including encryption in transit and at rest. No
        method of transmission or storage is completely secure, but we work hard to protect your
        information.
      </p>

      <h2>Children</h2>
      <p>
        Kiki is not directed to children under 13 (or the minimum age in your country), and we do
        not knowingly collect their personal information.
      </p>

      <h2>International transfers</h2>
      <p>
        We are based in the United States and process information there. Where required, we rely
        on appropriate safeguards for international transfers.
      </p>

      <h2>Changes</h2>
      <p>
        We may update this policy. If changes are significant, we&apos;ll let you know in the app
        or by email before they take effect.
      </p>

      <h2>Contact</h2>
      <p>
        Questions? Email <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>.
      </p>
    </LegalPage>
  );
}
