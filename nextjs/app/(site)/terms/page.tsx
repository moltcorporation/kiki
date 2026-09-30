import type { Metadata } from "next";
import { LegalPage } from "@/components/prose";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Terms of Service",
  description: "The terms that apply to your use of Kiki.",
};

export default function TermsPage() {
  return (
    <LegalPage title="Terms of Service" updated="September 29, 2026">
      <p>
        These Terms of Service (&quot;Terms&quot;) govern your use of the Kiki app and website
        (the &quot;Service&quot;) provided by {site.company} (&quot;we&quot;, &quot;us&quot;). By
        using the Service you agree to these Terms. If you don&apos;t agree, please don&apos;t use
        the Service.
      </p>

      <h2>Health and safety</h2>
      <p>
        <strong>
          Kiki provides general fitness and training information. It is not medical advice and is
          not a substitute for a doctor, physical therapist or other qualified professional.
        </strong>{" "}
        Consult a physician before starting any exercise program, especially if you have a medical
        condition, injury, or are pregnant. Stop running and seek medical attention if you feel
        pain, dizziness, chest discomfort or shortness of breath. Training plans and adjustments
        are generated with the help of artificial intelligence and may not be appropriate for
        everyone. You are responsible for deciding what is safe for you, and you run at your own
        risk. Always follow traffic laws and stay aware of your surroundings when running.
      </p>

      <h2>Your account</h2>
      <p>
        You must be at least 13 years old (or the minimum age in your country) to use Kiki. You
        are responsible for activity on your account and for keeping your sign-in methods secure.
        You can delete your account at any time in the app.
      </p>

      <h2>Subscriptions and free trials</h2>
      <ul>
        <li>
          Kiki is offered as an auto-renewing monthly or yearly subscription. Prices vary by
          region and are shown in the app before purchase.
        </li>
        <li>
          New subscribers may be offered a free trial. Unless you cancel at least 24 hours before
          the trial ends, your subscription starts and you&apos;ll be charged.
        </li>
        <li>
          Payment is charged to your Apple ID account at confirmation of purchase (or at the end
          of the free trial). Subscriptions renew automatically unless cancelled at least 24 hours
          before the end of the current period.
        </li>
        <li>
          Manage or cancel your subscription anytime in your Apple ID account settings. Deleting
          the app or your Kiki account does not cancel a subscription.
        </li>
        <li>
          Refunds are handled by Apple under its policies. You can request one at{" "}
          <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>.
        </li>
      </ul>

      <h2>Acceptable use</h2>
      <p>
        Don&apos;t misuse the Service: no reverse engineering, interfering with its operation,
        accessing it through automated means, violating any law, or using it to harm others.
      </p>

      <h2>Your content</h2>
      <p>
        You own the information you add to Kiki, such as your runs and notes. You give us
        permission to use it to provide and improve the Service as described in our{" "}
        <a href="/privacy">Privacy Policy</a>.
      </p>

      <h2>Our intellectual property</h2>
      <p>
        The Service, including its software, design and content, belongs to us and our licensors.
        We grant you a personal, non-transferable license to use the app on Apple devices you own
        or control, subject to these Terms and Apple&apos;s Licensed Application End User License
        Agreement.
      </p>

      <h2>Changes and availability</h2>
      <p>
        We may change or discontinue features and may update these Terms. If a change is
        significant, we&apos;ll notify you in advance. Continuing to use the Service after changes
        take effect means you accept them.
      </p>

      <h2>Disclaimers</h2>
      <p>
        The Service is provided &quot;as is&quot; and &quot;as available&quot; without warranties
        of any kind, to the fullest extent permitted by law. We don&apos;t guarantee any
        particular training result, race time or that the Service will be uninterrupted or
        error-free.
      </p>

      <h2>Limitation of liability</h2>
      <p>
        To the fullest extent permitted by law, {site.company} will not be liable for any
        indirect, incidental, special, consequential or punitive damages, or any personal injury
        arising from your use of the Service. Our total liability for any claim is limited to the
        amount you paid us in the 12 months before the claim.
      </p>

      <h2>Termination</h2>
      <p>
        You can stop using Kiki at any time. We may suspend or end access if you violate these
        Terms.
      </p>

      <h2>Governing law</h2>
      <p>
        These Terms are governed by the laws of the State of Delaware, USA, without regard to
        conflict-of-law rules, except where the law of your country requires otherwise.
      </p>

      <h2>Apple</h2>
      <p>
        These Terms are between you and us, not Apple. Apple is not responsible for the Service or
        its content, has no obligation to provide maintenance or support, and is a third-party
        beneficiary of these Terms with the right to enforce them against you.
      </p>

      <h2>Contact</h2>
      <p>
        Questions about these Terms? Email{" "}
        <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>.
      </p>
    </LegalPage>
  );
}
