import "server-only";

export const ENTITLEMENT_ID = "premium";

/**
 * Launch switch: while false, nothing is behind the paywall (adjustments
 * and new plans are free for everyone). RevenueCat still knows every user.
 * Turn on together with `Config.paywallEnabled` in the app.
 */
export const PAYWALL_ENABLED = false;

/**
 * Whether the user has an active Kiki subscription (including free trials),
 * checked against RevenueCat. The App User ID in RevenueCat is our user ID.
 * Fails open on RevenueCat outages so paying runners are never locked out.
 */
export async function isSubscribed(userId: string): Promise<boolean> {
  const key = process.env.REVENUECAT_SECRET_KEY;
  if (!key) return process.env.NODE_ENV !== "production";

  try {
    const res = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
      { headers: { Authorization: `Bearer ${key}` }, cache: "no-store" },
    );
    if (!res.ok) {
      console.error(`RevenueCat lookup failed: ${res.status}`);
      return true;
    }
    const data = (await res.json()) as {
      subscriber?: { entitlements?: Record<string, { expires_date: string | null }> };
    };
    const entitlement = data.subscriber?.entitlements?.[ENTITLEMENT_ID];
    return (
      !!entitlement &&
      (!entitlement.expires_date || new Date(entitlement.expires_date) > new Date())
    );
  } catch (error) {
    console.error("RevenueCat lookup error", error);
    return true;
  }
}
