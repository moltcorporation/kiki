export const site = {
  name: "Kiki",
  url: "https://kikirunning.com",
  tagline: "Your AI running coach",
  description:
    "Kiki builds a training plan around your race, your schedule and your body, then adapts it like a real coach whenever life happens.",
  company: "Moltcorp Inc.",
  supportEmail: "hello@moltcorporation.com",
  /** Set once the app is live on the App Store. */
  appStoreUrl: process.env.NEXT_PUBLIC_APP_STORE_URL || null,
  pricing: {
    monthly: "$11.99",
    yearly: "$59.99",
    yearlyPerMonth: "$4.99",
    trialDays: 7,
  },
};
